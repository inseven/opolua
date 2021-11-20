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

function Runtime:addModule(name, procTable)
    local mod = {
        [1] = name:upper()
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

function Runtime:pushNewFrame(stack, proc)
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

    for i = 1, #proc.params do
        local var = self:popParameter(stack)
        table.insert(frame.indirects, 1, var)
    end
    frame.returnStackSize = stack:getSize()

    for _, external in ipairs(proc.externals) do
        -- Now resolve externals in the new fn by walking up the frame procs until
        -- we find a global with a matching name
        local parentFrame = frame
        local found
        while not found do
            parentFrame = parentFrame.prevFrame
            assert(parentFrame, "Failed to resolve external "..external.name)
            local parentProc = parentFrame.proc
            found = parentProc.globals[external.name]
        end
        table.insert(frame.indirects, self:getLocalVar(found.offset, found.type, parentFrame))
        -- DEBUG
        -- printf("Fixed up external offset=0x%04X to indirect #%d\n", found.offset, #frame.indirects)
        -- for i, var in ipairs(self.frame.indirects) do
        --     printf("Indirect %i: %s\n", i, var())
        -- end

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

function newRuntime(handler)
    return setmetatable({
        modules = {},
        ioh = handler or require("defaultiohandler"),
    }, Runtime)
end

function printInstruction(currentOpIdx, opCode, op, extra)
    printf("%08X: %02X [%s] %s\n", currentOpIdx, opCode, op, extra or "")
end

function Runtime:dumpProc(procName)
    local proc = self:findProc(procName)
    self.ip = proc.codeOffset
    local endIdx = proc.codeOffset + proc.codeSize
    self:pushNewFrame(nil, proc)
    while self.ip < endIdx do
        local currentOpIdx = self.ip
        local opCode, op = self:nextOp()
        local opFn = ops[op]
        if not opFn then
            printf("No implementation of op %s\n", op)
            return
        end
        local extra = ops[op](nil, self)
        printInstruction(currentOpIdx, opCode, op, extra)
    end
    self:setFrame(nil)
end

local function run(self, stack)
    while self.ip do
        self.lastIp = self.ip
        local opCode, op = self:nextOp()
        local opFn = ops[op]
        if not opFn then
            error(fmt("No implementation of op %s at codeOffset 0x%08X in %s\n", op, self.lastIp, self.frame.proc.name))
        end
        if instructionDebug then
            local savedIp = self.ip
            local extra = ops[op](nil, self)
            self.ip = savedIp
            printInstruction(self.lastIp, opCode, op, extra)
        end
        ops[op](stack, self)
    end
end

function Runtime:unhandledErr(err)
    printf("Error from instruction at 0x%08X: %s", self.lastIp, tostring(err))
    if type(err) == "number" then
        local errStr = Errors[err]
        if errStr then
            printf(" (%s)", errStr)
        end
    end
    printf("\n")
    self:setFrame(nil)
    return false
end

function Runtime:runProc(proc, instructionDebug)
    assert(self.frame == nil, "Cannnot call runProc while still executing something else!")
    assert(#proc.params == 0, "Cannot run a procedure that expects arguments")
    self.ip = proc.codeOffset
    self.errorValue = KErrNone
    local stack = newStack()
    self:pushNewFrame(stack, proc) -- sets self.frame and self.ip
    while self.ip do
        local ok, err = pcall(run, self, stack)
        if not ok then
            self.errorLocation = fmt("Error in %s\\%s", self:moduleForProc(self.frame.proc)[1], self.frame.proc.name)
            if type(err) == "number" then
                self.errorValue = err
                -- An error code that might potentially be handled by a Trap or OnErr
                if self.trap then
                    self.trap = false
                    stack:popTo(self.frame.returnStackSize)
                    -- And continue to next instruction
                else
                    -- See if this frame *or any parent* has an error handler
                    while true do
                        if self.frame.errIp then
                            stack:popTo(self.frame.returnStackSize)
                            self.ip = self.frame.errIp
                            break
                        else
                            local prevFrame = self.frame.prevFrame
                            self:setFrame(prevFrame)
                            if prevFrame then
                                -- And loop again
                            else
                                return self:unhandledErr(err)
                            end
                        end
                    end
                end
            else
                return self:unhandledErr(err)
            end
        end
    end
    assert(self.frame == nil, "Frame was not nil on runProc exit!")
    return true -- no error
end

return _ENV
