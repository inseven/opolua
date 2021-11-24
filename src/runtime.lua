_ENV = module()

local ops = require("ops")
local newStack = require("stack").newStack

Runtime = {}
Runtime.__index = Runtime

local sbyte = string.byte
local fmt = string.format

function Runtime:nextOp()
    local ip = self.ip
    local opCode = sbyte(self.data, ip+1)
    local op = ops.codes[opCode]
    if not op then
        printf("No op for code 0x%02X at 0x%08X\n", opCode, ip)
    end
    self.ip = ip + 1
    return opCode, op

end

function Runtime:ipUnpack(packFmt)
    local result, nextPos = string.unpack(packFmt, self.data, self.ip + 1)
    self.ip = nextPos - 1
    return result
end

function Runtime:ipString()
    return self:ipUnpack("s1")
end

function Runtime:IP8()
    return self:ipUnpack("B")
end

function Runtime:IPs8()
    return self:ipUnpack("b")
end

function Runtime:IPs16()
    return self:ipUnpack("<h")
end

function Runtime:IP16()
    return self:ipUnpack("<H")
end

function Runtime:IP32()
    return self:ipUnpack("<I4")
end

function Runtime:IPs32()
    return self:ipUnpack("<i4")
end

function Runtime:IPReal()
    return self:ipUnpack("<d")
end

-- Returns a function which tracks a value using a unique upval
-- call fn() to get the val, call fn(newVal) to set it
local function makeVar()
    local makerFn = function()
        local val
        local fn = function(newVal)
            if newVal ~= nil then
                val = newVal
            else
                return val
            end
        end
        return fn
    end
    return makerFn()
end

-- To get the var at the given (1-based) pos, do arrayVar()[pos]. This will do
-- the bounds check and create a var if necessary. It is an error to assign
-- directly to the array, do arrayVar()[pos](newVal) instead - ie get the val,
-- then assign to it using the function syntax.
local ArrayMt = {
    __index = function(val, k)
        local len = rawget(val, "len")
        assert(len, "Array length has not been set!")
        assert(k > 0 and k <= len, KOplErrSubs)
        local result = makeVar()
        rawset(val, k, result)
        -- And default initialize the array value
        result(DefaultSimpleTypes[rawget(val, "type")])
        return result
    end,
    __newindex = function(val, k, v)
        error("Runtime should never be assigning to a array var index!")
    end
}

local function newArrayVal(valueType, len)
    return setmetatable({ type = valueType, len = len }, ArrayMt)
end

function Runtime:getLocalVar(index, type, frame)
    -- ie things where index is just an offset from iFrameCell
    assert(type, "getLocalVar requires a type argument!")
    if not frame then
        frame = self.frame
    end
    local vars = frame.vars
    local var = vars[index]
    if not var then
        var = makeVar()
        vars[index] = var
    end
    if var() == nil then
        assert(frame.proc.fn == nil, "Cannot have an uninitialized local var in a Lua frame!")
        -- Even though the caller might be a LeftSide op and thus is about to
        -- assign to the var, so initialising the var might not actually be
        -- necessary, we'll do it anyway just to simplify the interface
        if isArrayType(type) then
            -- Have to apply array fixup (ie find array length from proc definition)
            local arrayFixupIndex = (type == DataTypes.EStringArray) and index - 3 or index - 2
            local len = assert(frame.proc.arrays[arrayFixupIndex], "Failed to find array fixup!")
            var(newArrayVal(type & 0xF, len))
        else
            var(DefaultSimpleTypes[type])
        end
    end
    return var
end

function Runtime:popParameter(stack)
    local type = stack:pop()
    assert(DataTypes[type], "Expected parameter type on stack")
    assert(not isArrayType(type), "Can't pass arrays on the stack?")
    local var = makeVar()
    local val = stack:pop()
    var(val)
    return var
end

function Runtime:getIndirectVar(index)
    -- Yep, magic numbers abound...
    local arrIdx = (index - (self.frame.proc.iTotalTableSize + 18)) // 2
    local result = self.frame.indirects[arrIdx + 1]
    if not result then
        -- for i, var in ipairs(self.frame.indirects) do
        --     printf("Indirect %i: %s\n", i, var())
        -- end
        error(string.format("Failed to resolve indirect index 0x%04x", index))
    end
    assert(result(), "Indirect has not yet been initialised?")
    return result
end

function Runtime:getVar(index, type, indirect)
    if indirect then
        return self:getIndirectVar(index)
    else
        return self:getLocalVar(index, type)
    end
end

function Runtime:addModule(path, procTable)
    local name = splitext(basename(path)):upper()
    local mod = {
        -- Since 'name' isn't a legal procname (they're always uppercase in
        -- definitions, even though they're not necessarily when they are
        -- called) it is safe to use the same namespace as for the module's
        -- procnames.
        name = name,
        path = path,
    }
    for _, proc in ipairs(procTable) do
        mod[proc.name] = proc
    end
    table.insert(self.modules, mod)
end

function Runtime:findProc(procName)
    -- procName must be upper cased
    for _, mod in ipairs(self.modules) do
        local proc = mod[procName]
        if proc then
            return proc
        end
    end
    error("No proc named "..procName.." found in loaded modules")
end

function Runtime:moduleForProc(proc)
    for _, mod in ipairs(self.modules) do
        for k, v in pairs(mod) do
            if v == proc then
                return mod
            end
        end
    end
    return nil
end

function Runtime:pushNewFrame(stack, proc, numParams)
    assert(numParams, "Must specify numParams!")
    if proc.params then
        assert(#proc.params == numParams, "Wrong number of arguments for proc "..proc.name)
    end

    local frame = {
        returnIP = self.ip,
        proc = proc,
        prevFrame = self.frame,
        vars = {},
        indirects = {},
    }
    self:setFrame(frame, proc.codeOffset)

    if not stack then
        -- Don't do any other runtime setup
        return
    end

    -- We don't need to define any globals, arrays or strings at this point,
    -- they are constructed when needed.

    -- COplRuntime leaves parameters stored on the stack and allocates a
    -- pointer in iIndirectTbl to access them. Since they're accessed the
    -- same way as externals, we have to do something similar, although
    -- there's no need to actually keep them on the stack, it's easier if we
    -- pop them here. We're ignoring the type-checking extra values that
    -- were pushed onto the stack prior to the RunProcedure call.

    for i = 1, numParams do
        local var = self:popParameter(stack)
        table.insert(frame.indirects, 1, var)
    end
    frame.returnStackSize = stack:getSize()

    for _, external in ipairs(proc.externals or {}) do
        -- Now resolve externals in the new fn by walking up the frame procs until
        -- we find a global with a matching name
        local parentFrame = frame
        local found
        while not found do
            parentFrame = parentFrame.prevFrame
            assert(parentFrame, "Failed to resolve external "..external.name)
            local parentProc = parentFrame.proc
            local globals
            if parentProc.fn then
                -- In Lua fns, globals are declared at runtime on a per-frame
                -- basis, rather than being a property of the proc
                globals = parentFrame.globals
            else
                globals = parentProc.globals
            end
            found = globals[external.name]
        end
        table.insert(frame.indirects, self:getLocalVar(found.offset, found.type, parentFrame))
        -- DEBUG
        -- printf("Fixed up external offset=0x%04X to indirect #%d\n", found.offset, #frame.indirects)
        -- for i, var in ipairs(self.frame.indirects) do
        --     printf("Indirect %i: %s\n", i, var())
        -- end
    end

    if proc.fn then
        -- It's a Lua-implemented proc meaning we don't just set ip and return
        -- to the event loop, we have to invoke it here. Conveniently
        -- frame.indirects contains exactly the proc args, in the right format.
        frame.globals = {}
        local args = {}
        for i, var in ipairs(frame.indirects) do
            args[i] = var()
        end
        local result = proc.fn(self, table.unpack(args))
        self:returnFromFrame(stack, result or 0)
    end
end

function Runtime:returnFromFrame(stack, val)
    local prevFrame = self.frame.prevFrame
    stack:popTo(self.frame.returnStackSize)
    self:setFrame(prevFrame, self.frame.returnIP)
    if prevFrame then
        stack:push(val)
    end
end

function Runtime:setFrame(newFrame, ip)
    if newFrame then
        self.frame = newFrame
        self.ip = ip -- self.ip is always relative to self.frame.proc.data
        self.data = newFrame.proc.data -- which for convenience is also accessible as self.data
    else
        self.frame = nil
        self.ip = nil
        self.data = nil
    end
end

function Runtime:setFrameErrIp(errIp)
    self.frame.errIp = errIp
end

function Runtime:getLastError()
    return self.errorValue, self.errorLocation
end

function Runtime:getIp()
    return self.ip
end

function Runtime:setIp(ip)
    -- TODO should check it's still within the current frame
    self.ip = ip
    if ip == nil then
        -- Allowed for eg by STOP cmd
        setFrame(nil)
    end
end

function Runtime:setTrap(flag)
    self.trap = flag
    if trap then
        -- Setting trap also clears current error
        self.errorValue = 0
    end
end

function Runtime:getTrap()
    return self.trap
end

function Runtime:iohandler()
    return self.ioh
end

function Runtime:currentProc()
    assert(self.frame and self.frame.proc, "No current process!")
    return self.frame.proc
end

function Runtime:setDialog(dlg)
    if dlg then
        dlg.frame = self.frame
    end
    self.dialog = dlg
end

function Runtime:getDialog()
    -- A dialog must always be setup and shown from the same frame
    assert(self.dialog and self.dialog.frame == self.frame, KOplStructure)
    return self.dialog
end

function Runtime:setMenu(m)
    if m then
        m.frame = self.frame
    end
    self.menu = m
end

function Runtime:getMenu()
    -- A menu must always be setup and shown from the same frame
    assert(self.menu and self.menu.frame == self.frame, KOplStructure)
    return self.menu
end

function Runtime:getGraphics()
    if not self.graphics then
        local w, h = self.ioh.getScreenSize()
        self.graphics = {
            [1] = {
                id = 1,
                mode = 0, -- set
                color = 0, -- black
                bgcolor = 255, -- white
                width = w,
                height = h,
                pos = { x = 0, y = 0 },
            },
        }
        self.graphics.current = self.graphics[1]
    end
    return self.graphics
end

function Runtime:graphicsOp(type, op)
    if not op then op = {} end
    local graphics = self:getGraphics()
    local context = graphics.current
    op.id = context.id
    op.type = type
    op.mode = context.mode
    op.color = context.color
    op.bgcolor = context.bgcolor
    op.x = context.pos.x
    op.y = context.pos.y

    if graphics.buffer then
        table.insert(graphics.buffer, op)
    else
        self.ioh.graphics({ op })
    end
end

function newRuntime(handler)
    return setmetatable({
        modules = {},
        ioh = handler or require("defaultiohandler"),
    }, Runtime)
end

function printInstruction(currentOpIdx, opCode, op, extra)
    printf("%08X: %02X [%s] %s\n", currentOpIdx, opCode, op, extra or "")
end

function Runtime:decodeNextInstruction()
    local currentIp = self.ip
    local opCode = sbyte(self.data, currentIp + 1)
    local op = ops.codes[opCode]
    self.ip = currentIp + 1
    local opDump = op and op.."_dump"
    local extra = ops[opDump] and ops[opDump](self)
    return fmt("%08X: %02X [%s] %s", currentIp, opCode, op or "?", extra or "")
end

function Runtime:dumpProc(procName, startAddr)
    local proc = self:findProc(procName)
    local endIdx = proc.codeOffset + proc.codeSize
    self:pushNewFrame(nil, proc, #proc.params)
    if startAddr then
        self.ip = startAddr
    end
    while self.ip < endIdx do
        print(self:decodeNextInstruction())
    end
    self:setFrame(nil)
end

local function run(self, stack)
    while self.ip do
        self.frame.lastIp = self.ip
        local opCode, op = self:nextOp()
        local opFn = ops[op]
        if not opFn then
            error(fmt("No implementation of op %s at codeOffset 0x%08X in %s\n", op, self.frame.lastIp, self.frame.proc.name))
        end
        if self.instructionDebug then
            local savedIp = self.ip
            self.ip = self.frame.lastIp
            print(self:decodeNextInstruction())
            self.ip = savedIp
        end
        ops[op](stack, self)
    end
end

function Runtime:setInstructionDebug(flag)
    self.instructionDebug = flag
end

ErrObj = {
    __tostring = function(self)
        return fmt("%s\n%s\n%s", self.msg or self.code, self.opoStack, self.luaStack)
    end
}
ErrObj.__index = ErrObj

local function findLocationOfFnOnStack(fn)
    local lvl = 2
    while true do
        local dbgInfo = debug.getinfo(lvl, "f")
        if dbgInfo == nil then
            -- fn not found on stack, shouldn't happen...
            return "?"
        elseif dbgInfo.func == fn then
            dbgInfo = debug.getinfo(lvl, "Sl")
            return fmt("%s:%d", dbgInfo.source:sub(2), dbgInfo.currentline)
        end
        lvl = lvl + 1
    end
end

local function addStacktraceToError(self, err, callingFrame)
    if callingFrame then
        -- Save caller info for later, when we're (potentially) adding this
        -- frame to a callstack in a subsequent higher-level error call. This
        -- avoids us having to do it every time there's a call to pcallProc
        -- which doesn't result in an error.
        assert(callingFrame.proc.fn, "There's a calling frame but no Lua fn?!")
        callingFrame.lastPcallSite = findLocationOfFnOnStack(callingFrame.proc.fn)
    end

    local frameDescs = {}
    local erroringFrame = self.frame
    local savedIp = self.ip
    -- In order to get instruction decode in the stacktrace we must swizzle
    -- frames around, but note we don't actually unwind them.
    while self.frame ~= callingFrame do
        local mod = self:moduleForProc(self.frame.proc)
        local info
        if self.frame.proc.fn then
            info = fmt("%s\\%s: [Lua] %s", mod.name, self.frame.proc.name, self.frame.lastPcallSite or "?")
        else
            self.ip = self.frame.lastIp
            info = fmt("%s\\%s:%s", mod.name, self.frame.proc.name, self:decodeNextInstruction())
        end
        table.insert(frameDescs, info)
        self:setFrame(self.frame.prevFrame)
    end
    self:setFrame(erroringFrame, savedIp) -- Restore correct stack frame
    local stack = table.concat(frameDescs, "\n")
    if err.opoStack then
        err.opoStack = err.opoStack.."\n"..stack
    else
        err.opoStack = stack
    end
end

local function traceback(msgOrCode)
    local t = type(msgOrCode)
    if t == "table" then
        -- We've already got the Lua stacktrace, nothing more to do here
        return msgOrCode
    end

    local err = setmetatable({
        code = t == "number" and msgOrCode,
        luaStack = debug.traceback(nil, 2),
    }, ErrObj)
    if err.code then
        err.msg = fmt("%d (%s)", err.code, Errors[err.code] or "?")
    else
        err.msg = msgOrCode
    end
    return err
end

function Runtime:pcallProc(procName, ...)
    local callingFrame = self.frame
    assert(callingFrame == nil or callingFrame.proc.fn, "Cannnot callProc while still executing something else!")

    local proc = self:findProc(procName)
    local args = table.pack(...)
    assert(args.n == #proc.params, "Wrong number of arguments in call to "..procName)

    self.ip = proc.codeOffset
    self.errorValue = KErrNone
    local stack = newStack()
    for i = 1, args.n do
        stack:push(args[i])
        stack:push(proc.params[i]) -- Hope this matches, should probably check...
    end

    self:pushNewFrame(stack, proc, args.n) -- sets self.frame and self.ip
    while self.ip do
        local ok, err = xpcall(run, traceback, self, stack)
        if not ok then
            addStacktraceToError(self, err, callingFrame)
            self.errorLocation = fmt("Error in %s\\%s", self:moduleForProc(self.frame.proc).name, self.frame.proc.name)
            if err.code then
                self.errorValue = err.code
                -- An error code that might potentially be handled by a Trap or OnErr
                if self.trap then
                    self.trap = false
                    stack:popTo(self.frame.returnStackSize)
                    -- And continue to next instruction
                else
                    -- See if this frame or any parent frame up to callingFrame has an error handler
                    while true do
                        if self.frame.errIp then
                            stack:popTo(self.frame.returnStackSize)
                            self.ip = self.frame.errIp
                            break
                        else
                            local prevFrame = self.frame.prevFrame
                            self:setFrame(prevFrame)
                            if prevFrame ~= callingFrame then
                                -- And loop again
                            else
                                return err
                            end
                        end
                    end
                end
            else
                self:setFrame(callingFrame)
                return err
            end
        end
    end
    assert(self.frame == callingFrame, "Frame was not restored on pcallProc exit!")
    return nil -- no error
end

function Runtime:callProc(procName, ...)
    local err = self:pcallProc(procName, ...)
    if err then
        error(err)
    end
end

function Runtime:loadModule(path)
    local modName = splitext(basename(path:lower()))
    local ok, mod = pcall(require, "modules."..modName)
    assert(ok, KOplErrNoMod)
    local procTable = {}
    for k, v in pairs(mod) do
        assert(type(v) == "function", "Unexpected top-level value in module that isn't a function")
        local proc = {
            name = k:upper(),
            fn = v
        }
        table.insert(procTable, proc)
    end
    self:addModule(path, procTable)
end

function Runtime:declareGlobal(name, arrayLen)
    local frame = self.frame
    name = name:upper()
    assert(self.ip == nil and frame.proc.fn and frame.globals, "Can only declareGlobal from within a Lua module!")

    local valType
    if name:match("%%$") then
        valType = DataTypes.EWord
    elseif name:match("&$") then
        valType = DataTypes.ELong
    elseif name:match("%$$") then
        valType = DataTypes.EString
    else -- no suffix means float
        valType = DataTypes.EReal
    end

    -- We define our indexes (which are how externals map to locals) as simply
    -- being the position of the item in the frame vars table. We can skip
    -- figuring out a byte-exact frame index because nothing actually needs to
    -- know it.
    local index = #frame.vars + 1

    local var = makeVar()
    frame.globals[name] = { offset = index, type = valType }
    frame.vars[index] = var

    if arrayLen then
        var(newArrayVal(valType, arrayLen))
    else
        var(DefaultSimpleTypes[valType])
    end
    return var
end

return _ENV
