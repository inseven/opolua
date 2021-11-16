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
local function makeVar(initialVal)
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
    local var = makerFn()
    if initialVal ~= nil then
        var(initialVal)
    end
    return var
end

function Runtime:getLocalVar(index, type, frame)
    -- ie things where index is just an offset from iFrameCell
    local vars = (frame or self.frame).vars
    local var = vars[index]
    if not var then
        local initialVal = nil
        if type then
            assert(type < DataTypes.EWordArray, "Array type storage not done yet!")
            if type == DataTypes.EString then
                initialVal = ""
            else
                initialVal = 0
            end
        end
        var = makeVar(initialVal)
        vars[index] = var
    end
    return var
end

function Runtime:popParameter(stack)
    local type = stack:pop()
    assert(DataTypes[type], "Expected parameter type on stack")
    local val = stack:pop()
    return makeVar(val)
end

function Runtime:getIndirectVar(index, type)
    -- Yep, magic numbers abound...
    local arrIdx = (index - (self.frame.proc.iTotalTableSize + 18)) // 2
    local result = self.frame.indirects[arrIdx + 1]
    if not result then
        for i, var in ipairs(self.frame.indirects) do
            printf("Indirect %i: %s\n", i, var())
        end
        error(string.format("Failed to resolve indirect index 0x%04x", index))
    end
    assert(result(), "Indirect has not yet been initialised?")
    return result
end

function Runtime:addModule(procTable)
    local mod = {}
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

    -- First, define all globals that this new fn declares
    for _, global in ipairs(proc.globals) do
        self:getLocalVar(global.offset, global.type)
    end

    -- Locals will get defined the first time they're accessed (COplRuntime
    -- relies on iFrameCell being zero-initialised for this).

    -- COplRuntime leaves parameters stored on the stack and allocates a
    -- pointer in iIndirectTbl to access them. Since they're accessed the
    -- same way as externals, we have to do something similar, although
    -- there's no need to actually keep them on the stack, it's easier if we
    -- pop them here. We're ignoring the type-checking extra values that
    -- were pushed onto the stack prior to the RunProcedure call.

    -- Args are pushed in reverse order, ie first arg is on top of stack
    for i = 1, #proc.params do
        local var = self:popParameter(stack)
        frame.indirects[i] = var
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
        table.insert(frame.indirects, self:getLocalVar(found.offset, nil, parentFrame))
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

function Runtime:getErrorValue()
    return self.errorValue
end

function Runtime:getIp()
    return self.ip
end

function Runtime:setIp(ip)
    -- TODO should check it's still within the current frame
    self.ip = ip
end

function Runtime:currentProc()
    assert(self.frame and self.frame.proc, "No current process!")
    return self.frame.proc
end

function newRuntime()
    return setmetatable({modules = {}}, Runtime)
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
            if type(err) == "number" and self.frame.errIp then
                self.errorValue = err
                self.ip = self.frame.errIp
                -- And keep going from there
            else
                printf("Error from instruction at 0x%08X: %s\n", self.lastIp, tostring(err))
                return false
            end
        end
    end
    return true -- no error
end

return _ENV
