_ENV = module()

local ops = require("ops")
local newStack = require("stack").newStack

Runtime = {}
Runtime.__index = Runtime

local sbyte = string.byte

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

function Runtime:ipPack(packFmt)
    local result, nextPos = string.unpack(packFmt, self.data, self.ip+1)
    self.ip = nextPos - 1
    return result
end

function Runtime:ipString()
    return self:ipPack("s1")
end

function Runtime:ipByte()
    return self:ipPack("B")
end

function Runtime:ipWord()
    return self:ipPack("<H")
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

function Runtime:newFrame(stack, proc)
    local frame = {
        returnIP = self.ip,
        proc = proc,
        prevFrame = self.frame,
        returnStackSize = stack and stack:getSize(),
    }
    self.frame = frame
    self.ip = proc.codeOffset -- self.ip is always relative to self.frame.proc.data
    self.data = proc.data -- which for convenience is also accessible as self.data
    return frame
end

function Runtime:returnFromFrame(stack, val)
    local prevFrame = self.frame.prevFrame
    stack:popTo(self.frame.returnStackSize)
    if prevFrame then
        self.data = prevFrame.proc.data
        self.ip = self.frame.returnIP
        self.frame = prevFrame
        stack:push(val)
    else
        -- We're done, returned from the last frame
        self.ip = nil
        self.frame = nil
        self.data = nil
    end
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
    local frame = self:newFrame(nil, proc)
    while self.ip < endIdx do
        local currentOpIdx = self.ip
        local opCode, op = self:nextOp()
        local opFn = ops[op]
        if not opFn then
            printf("No implementation of op %s\n", op)
            return
        end
        local extra = ops[op](nil, self, frame)
        printInstruction(currentOpIdx, opCode, op, extra)
    end
end

function Runtime:runProc(proc, instructionDebug)
    assert(self.frame == nil, "Cannnot call runProc while still executing something else!")
    self.ip = proc.codeOffset
    local stack = newStack()
    self:newFrame(stack, proc) -- sets self.frame
    while self.ip do
        local currentOpIdx = self.ip
        local opCode, op = self:nextOp()
        local opFn = ops[op]
        if not opFn then
            printf("No implementation of op %s at codeOffset 0x%08X in %s\n", op, currentOpIdx, self.frame.proc.name)
            return
        end
        if instructionDebug then
            local savedIp = self.ip
            local extra = ops[op](nil, self, self.frame)
            self.ip = savedIp
            printInstruction(currentOpIdx, opCode, op, extra)
        end
        ops[op](stack, self, self.frame)
    end
end

return _ENV
