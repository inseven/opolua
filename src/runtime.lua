--[[

Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

_ENV = module()

local ops = require("ops")
local newStack = require("stack").newStack
local database = require("database")
local memory = require("memory")

Runtime = class {}

local sbyte = string.byte
local fmt = string.format

function Runtime:nextOp()
    local ip = self.ip
    local opCode = sbyte(self.data, ip+1)
    local op = self.opcodes[opCode]
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

local Chunk = memory.Chunk
local Addr = memory.Addr

database.makeVar = function(type)
    -- All database strings have max len 255
    return Chunk():makeNewVariable(0, type, 255)
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
        local stringMaxLen = nil
        if type & 0xF == DataTypes.EString then
            local stringFixupIndex = index - 1
            stringMaxLen = assert(frame.proc.strings[stringFixupIndex], "Failed to find string fixup!")
        end
        local arrayLen = nil
        if isArrayType(type) then
            -- Have to apply array fixup (ie find array length from proc definition)
            local arrayFixupIndex = (type == DataTypes.EStringArray) and index - 3 or index - 2
            arrayLen = assert(frame.proc.arrays[arrayFixupIndex], "Failed to find array fixup!")
        end

        var = self.chunk:getVariableAtOffset(frame.framePtr + index, type)
        var:fixup(stringMaxLen, arrayLen)
        vars[index] = var
    end
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
    return result
end

function Runtime:getVar(index, type, indirect)
    if indirect then
        return self:getIndirectVar(index)
    else
        return self:getLocalVar(index, type)
    end
end

-- Only for things that need to simulate a var (such as for making sync versions of async requests)
function Runtime:makeTemporaryVar(type, len, stringMaxLen)
    local result = Chunk():makeNewVariable(0, type, stringMaxLen, len)
    return result
end

function Runtime:addModule(path, procTable, opxTable, uid3)
    printf("addModule: %s\n", path)
    local name = oplpath.splitext(oplpath.basename(path)):upper()
    local mod = {
        -- Since 'name' isn't a legal procname (they're always uppercase in
        -- definitions, even though they're not necessarily when they are
        -- called) it is safe to use the same namespace as for the module's
        -- procnames.
        name = name,
        path = path,
        opxTable = opxTable,
        uid3 = uid3,
    }
    for _, proc in ipairs(procTable) do
        mod[proc.name] = proc
        proc.module = mod
        if proc.globals then
            -- runtime expects to be able to do by name lookups in globals...
            for _, global in ipairs(proc.globals) do
                local nameForLookupByName = global.name
                if isArrayType(global.type) then
                    -- Array variable names live in a separate namespace to scalars,
                    -- for the purposes of global variable lookup, the simplest
                    -- solution is to disambiguate them here.
                    nameForLookupByName = nameForLookupByName.."[]"
                end
                proc.globals[nameForLookupByName] = global
            end
        end
    end
    table.insert(self.modules, mod)
    if not self.cwd then
        assert(oplpath.isabs(path), "Bad path for initial module!")
        local drive, dir, base, ext = oplpath.parse(path)
        self.cwd = drive.."\\"
        self:setResource("cmdlinedoc", oplpath.join(drive..dir, base))
    end
end

function Runtime:unloadModule(path)
    local canonPath = oplpath.canon(path)
    for i, mod in ipairs(self.modules) do
        if oplpath.canon(mod.path) == canonPath then
            table.remove(self.modules, i)
            return
        end
    end
    printf("No loaded module found for %s!\n", path)
    error(KErrNotExists)
end

function Runtime:findProc(procName)
    -- procName must be upper cased
    for _, mod in ipairs(self.modules) do
        local proc = mod[procName]
        if proc then
            return proc
        end
    end
    printf("No proc named %s found in loaded modules\n", procName)
    error(KErrNoProc)
end

local function quoteVal(val)
    if type(val) == "string" then
        return string.format('"%s"', hexEscape(val))
    else
        return tostring(val)
    end
end

function Runtime:pushNewFrame(stack, proc, numParams)
    assert(numParams, "Must specify numParams!")
    if proc.params then
        assert(#proc.params == numParams, "Wrong number of arguments for proc "..proc.name)
    end

    local frame = {
        frameAllocs = {}, -- used for params and declareGlobal()
        returnIP = self.ip,
        proc = proc,
        prevFrame = self.frame,
        vars = {},
        indirects = {},
        globals = proc.globals or {}, -- Lua procs don't have a 'globals'
        dataSize = proc.iDataSize or 0,
    }
    frame.framePtr = assert(self.chunk:allocz(math.max(4, frame.dataSize)), "Failed to allocate stack frame memory!")
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
        local type = stack:pop()
        local val = stack:pop()
        assert(DataTypes[type], "Expected parameter type on stack")
        assert(not isArrayType(type), "Can't pass arrays on the stack?")
        local var = self.chunk:allocVariable(type, type == DataTypes.EString and #val)
        var(val)
        table.insert(frame.indirects, 1, var)
        table.insert(frame.frameAllocs, var)
    end
    frame.returnStackSize = stack:getSize()
    if self.callTrace then
        local args = {}
        for i, var in ipairs(frame.indirects) do
            args[i] = quoteVal(var())
        end
        printf("+%s(%s) initstacksz=%d\n", proc.name, table.concat(args, ", "), frame.returnStackSize)
    end

    for _, external in ipairs(proc.externals or {}) do
        -- Now resolve externals in the new fn by walking up the frame procs until
        -- we find a global with a matching name and type
        local parentFrame = frame
        local found
        local nameForLookup = external.name
        if isArrayType(external.type) then
            nameForLookup = nameForLookup.."[]"
        end
        while not found do
            parentFrame = parentFrame.prevFrame
            assert(parentFrame, "Failed to resolve external "..nameForLookup)
            local parentProc = parentFrame.proc
            found = parentFrame.globals[nameForLookup]
        end
        assert(found.type == external.type, "Mismatching types on resolved external "..nameForLookup)
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
        local args = {}
        for i, var in ipairs(frame.indirects) do
            args[i] = var()
        end
        local result = proc.fn(table.unpack(args))
        self:returnFromFrame(stack, result or 0)
    end
end

function Runtime:popFrame(stack)
    -- print("Popping frame:", self.frame.proc.name)
    local frame = self.frame
    local prevFrame = frame.prevFrame
    if frame.returnStackSize then
        -- This will only be null if there was an error setting up the stack
        -- frame, in which case not popping anything is the right thing to do
        stack:popTo(frame.returnStackSize)
    end
    if frame.framePtr then
        self.chunk:free(frame.framePtr)
    end
    for _, var in ipairs(frame.frameAllocs) do
        var:free()
    end
    self:setFrame(prevFrame, frame.returnIP)
    return prevFrame
end

function Runtime:returnFromFrame(stack, val)
    if self.callTrace then
        printf("-%s() -> %s\n", self.frame.proc.name, quoteVal(val))
    end
    local prevFrame = self:popFrame(stack)
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
    local proc = self.frame.proc
    assert(ip, "Cannot set a nil ip!")
    if ip < proc.codeOffset or ip >= proc.codeOffset + proc.codeSize then
        error(fmt("Cannot jump to 0x%08X which is outside the current proc %s 0x%08X+%X",
            ip, proc.name, proc.codeOffset, proc.codeSize))
    end
    self.ip = ip
end

function Runtime:setTrap(flag)
    self.trap = flag
    if flag then
        -- Setting trap also clears current error
        self.errorValue = 0
    end
end

function Runtime:setHaltOnAnyError(flag)
    self.haltOnAnyError = flag
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

function Runtime:newGraphicsContext(width, height, isWindow, displayMode)
    local graphics = self:getGraphics()

    -- Enforce the max 64 windows limit
    if isWindow then
        local limit = self:isSibo() and 8 or 64
        if self:getResource("infowin") then
            -- I don't think that the info window counts towards the window limit, since on the Psion it's not
            -- implemented as an OPL window (but it is in our impl).
            limit = limit + 1
        end
        local count = 0
        for k, v in pairs(graphics) do
            if type(k) == "number" and v.isWindow then
                count = count + 1
            end
        end
        if count >= limit then
            print("Max number of open windows exceeded")
            error(KErrMaxDraw)
        end
    end

    -- #graphics+1 will always be the first free id, which is the same
    -- strategy as the Series 5 appears to use.
    local id = #graphics + 1
    local newCtx = {
        id = id,
        displayMode = displayMode,
        mode = 0, -- set
        tmode = 0, -- set
        color = { r = 0, g = 0, b = 0 }, -- black
        bgcolor = { r = 255, g = 255, b = 255 }, -- white
        width = width,
        height = height,
        pos = { x = 0, y = 0 },
        isWindow = isWindow,
        fontUid = KDefaultFontUid,
        style = 0, -- normal text style
        penwidth = 1,
    }
    graphics[id] = newCtx
    self:setResource("ginfo", nil)
    return newCtx
end

function Runtime:getGraphics()
    if not self.graphics then
        local w, h, mode, device = self.ioh.getDeviceInfo()
        self.graphics = {
            screenWidth = w,
            screenHeight = h,
            screenMode = mode,
            sprites = {},
        }
        self.deviceName = device
        local id = self:gCREATE(0, 0, w, h, true, mode)
        assert(id == KDefaultWin)
        self:FONT(KFontCourierNormal11, 0)
    end
    return self.graphics
end

-- Since there's no text equivalent to gX, gY
function Runtime:getTextCursorXY()
    local screen = self:getGraphics().screen
    return screen.cursorx + 1, screen.cursory + 1
end

function Runtime:getScreenInfo()
    local graphics = self:getGraphics()
    return graphics.screenWidth, graphics.screenHeight, graphics.screenMode
end

function Runtime:isColor()
    local _, _, displayMode = self:getScreenInfo()
    return displayMode >= KColorgCreate256ColorMode
end

function Runtime:getDeviceName()
    if not self.graphics then
        self:getGraphics()
    end
    return self.deviceName
end

function Runtime:getGraphicsContext(id)
    local graphics = self:getGraphics()
    if id then
        return graphics[id]
    else
        return graphics.current
    end
end

function Runtime:setGraphicsContext(id)
    -- printf("setGraphicsContext %d\n", id)
    local graphics = self:getGraphics()
    local context = graphics[id]
    assert(context, KErrDrawNotOpen)
    graphics.current = context
end

function Runtime:closeGraphicsContext(id)
    local graphics = self:getGraphics()
    if id == graphics.current.id then
        graphics.current = graphics[1]
    end
    graphics[id] = nil
    self:flushGraphicsOps()
    -- Clean up any native resources dependant on this window
    local cursor = self:getResource("cursor")
    if cursor and cursor.id == id then
        self:setResource("cursor", nil)
        self.ioh.graphicsop("cursor", nil)
    end
    local textfield = self:getResource("textfield")
    if textfield and textfield.id == id then
        self:setResource("textfield", nil)
        self.ioh.textEditor(nil)
    end
    self.ioh.graphicsop("close", id)
end

function Runtime:saveGraphicsState()
    local ctx = self:getGraphicsContext()
    return {
        id = ctx.id,
        mode = ctx.mode,
        tmode = ctx.tmode,
        color = ctx.color,
        bgcolor = ctx.bgcolor,
        pos = { x = ctx.pos.x, y = ctx.pos.y },
        fontUid = ctx.fontUid,
        style = ctx.style,
        flush = self:getGraphicsAutoFlush(),
    }
end

function Runtime:restoreGraphicsState(state)
    local ctx = self:getGraphicsContext(state.id)
    ctx.mode = state.mode
    ctx.tmode = state.tmode
    ctx.color = state.color
    ctx.bgcolor = state.bgcolor
    ctx.pos = { x = state.pos.x, y = state.pos.y }
    ctx.fontUid = state.fontUid
    ctx.style = state.style
    self:setGraphicsContext(state.id)
    self:setGraphicsAutoFlush(state.flush)
end

function Runtime:getFont(fontId)
    if fontId == nil then
        fontId = self:getGraphicsContext().fontUid
    end
    local uid = FontAliases[fontId] or fontId
    local fonts = self:getResource("fonts")
    if not fonts then
        fonts = {}
        self:setResource("fonts", fonts)
    end
    if fonts[uid] then
        return fonts[uid]
    end

    local ctx = self:newGraphicsContext(1, 1, false, KColorgCreate2GrayMode)
    local metrics, err = self:iohandler().graphicsop("loadfont", ctx.id, uid)
    if metrics == nil then
        self:closeGraphicsContext(ctx.id)
        return nil
    end

    ctx.width = metrics.maxwidth * 32
    ctx.height = metrics.height * 8
    metrics.id = ctx.id
    metrics.uid = uid

    fonts[uid] = metrics
    return metrics
end

function Runtime:drawCmd(type, op)
    if not op then op = {} end
    local graphics = self:getGraphics()
    local context = graphics.current
    op.id = context.id
    op.type = type
    if not op.mode then
        op.mode = context.mode
    end
    if not op.color then
        op.color = context.color
    end
    if not op.bgcolor then
        op.bgcolor = context.bgcolor
    end
    if not op.x then
        op.x = context.pos.x
    end
    if not op.y then
        op.y = context.pos.y
    end
    op.penwidth = context.penwidth
    op.greyMode = context.greyMode

    if type == "text" then
        op.tmode = context.tmode
        op.fontinfo = {
            uid = context.font.uid,
            face = context.font.face,
            size = context.font.size,
            flags = context.style,
        }
        if context.font.bold then
            op.fontinfo.flags = op.fontinfo.flags | 64 -- boldHint
        end
    end

    if graphics.buffer then
        table.insert(graphics.buffer, op)
    else
        local err = self.ioh.draw({ op }) or KErrNone
        if err ~= KErrNone then
            error(err)
        end
    end
end

function Runtime:flushGraphicsOps()
    local graphics = self.graphics
    if graphics and graphics.buffer and graphics.buffer[1] then
        local err = self.ioh.draw(graphics.buffer) or KErrNone
        graphics.buffer = {}
        if err ~= KErrNone then
            error(err)
        end
    end
end

function Runtime:setGraphicsAutoFlush(flag)
    local graphics = self:getGraphics()
    if flag then
        self:flushGraphicsOps()
        graphics.buffer = nil
    else
        if not graphics.buffer then
            graphics.buffer = {}
        end
    end
end

function Runtime:getGraphicsAutoFlush()
    return self:getGraphics().buffer == nil
end

function Runtime:declareTextEditor(windowId, editorType, controlRect, cursorRect, userFocusRequested)
    if windowId == nil then
        self:setResource("textfield", nil)
        self.ioh.textEditor(nil)
        return
    end

    local win = self:getGraphicsContext(windowId)

    local info = {
        id = windowId,
        controlRect = {
            x = win.winX + controlRect.x,
            y = win.winY + controlRect.y,
            w = controlRect.w,
            h = controlRect.h,
        },
        type = editorType,
        cursorRect = {
            x = win.winX + cursorRect.x,
            y = win.winY + cursorRect.y,
            w = cursorRect.w,
            h = cursorRect.h,
        },
        windowRect = {
            x = win.winX,
            y = win.winY,
            w = win.width,
            h = win.height,
        },
        userFocusRequested = userFocusRequested,
    }
    local current = self:getResource("textfield")
    local function rectEqual(a, b)
        return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
    end
    if current and current.windowId == info.windowId and current.type == info.type
        and current.userFocusRequested == info.userFocusRequested
        and rectEqual(current.controlRect, info.controlRect)
        and rectEqual(current.cursorRect, info.cursorRect)
        and rectEqual(current.windowRect, info.windowRect) then
        -- no changes
        return
    end

    self:setResource("textfield", info)
    self.ioh.textEditor(info)
end

-- op==nil is used for dbase.opx functions like DbGetFieldCount which take a database path but the file is allowed to
-- be open with any mode
function Runtime:newDb(path, op)
    local readonly = op == nil or op == "OpenR"
    local isCreate = op == "Create"

    -- TODO make this check at table granularity not file, AND share self.tables if already open

    -- Check if there are already any other open handles to this db
    -- if op then
    --     local cpath = oplpath.canon(path)
    --     for _, db in pairs(self.dbs.open) do
    --         if oplpath.canon(db:getPath()) == cpath then
    --             if not readonly or db:isWriteable() then
    --                 error(KErrInUse)
    --             end
    --         end
    --     end
    -- end

    local db = database.new(path, readonly)
    -- See if db already exists
    local dbData, err = self.ioh.fsop("read", path)
    if dbData then
        db:load(dbData)
    elseif err == KErrNotExists and isCreate then
        -- This is fine
    else
        error(err)
    end
    return db
end

function Runtime:openDb(logName, tableSpec, variables, op)
    assert(self.dbs.open[logName] == nil, KErrOpen)
    printf("parseTableSpec: %s\n", tableSpec)
    local path, tableName, fieldNames, filterPredicate, sortSpec = database.parseTableSpec(tableSpec)
    path = self:abs(path)

    local db = self:newDb(path, op)

    if op == "Create" then
        if fieldNames == nil then
            -- SIBO-style call where field names are derived from the variable names
            fieldNames = {}
            for i, var in ipairs(variables) do
                fieldNames[i] = var.name:gsub("[%%&$]$", {
                    ["%"] = "i",
                    ["&"] = "a",
                    ["$"] = "s",
                })
            end
        end

        -- "*" is not valid for create, only open
        assert(not (#fieldNames == 1 and fieldNames[1] == "*"), KErrInvalidArgs)
        local types = {}
        for i, var in ipairs(variables) do
            types[i] = var.type
        end
        db:createTable(tableName, fieldNames, types)
    end

    db:setView(tableName, fieldNames, variables, filterPredicate, sortSpec)
    self.dbs.open[logName] = db
    self.dbs.current = logName
end

function Runtime:getDb(logName)
    local db = self.dbs.open[logName or self.dbs.current]
    assert(db, KErrClosed)
    return db
end

function Runtime:useDb(logName)
    self:getDb(logName) -- Check it's valid
    self.dbs.current = logName
end

function Runtime:closeDb()
    self:saveDbIfModified()
    self.dbs.open[self.dbs.current] = nil
    self.dbs.current = nil
end

function Runtime:saveDb(db)
    local data = db:save()
    local err = self.ioh.fsop("write", db:getPath(), data)
    assert(err == KErrNone, err)
end

function Runtime:saveDbIfModified()
    local db = self:getDb()
    if db:isModified() and not db:inTransaction() then
        self:saveDb(db)
    end
end

function Runtime:newFileHandle()
    local h = #self.files + 1
    local f = {
        h = h,
    }
    self.files[h] = f
    return f
end

function Runtime:getFile(handle)
    local f = self.files[handle]
    return f
end

function Runtime:closeFile(handle)
    self.files[handle] = nil
end

function Runtime:setResource(name, val)
    -- print("setResource", name, val)
    self.resources[name] = val
end

function Runtime:getResource(name)
    return self.resources[name]
end

function Runtime:newOplModule(moduleName)
    local module = newModuleInstance(moduleName)
    -- All "OPL modules" get the OPL API imported
    setmetatable(module, {__index = self.opl})
    return module
end

-- For requiring modules written using opl.lua, such as menu.lua or scrollbar.lua
function Runtime:require(moduleName)
    if self.luaModules[moduleName] == nil then
        self.luaModules[moduleName] = self:newOplModule(moduleName)
    end
    return self.luaModules[moduleName]
end

function newModuleInstance(moduleName)
    -- Because opl.lua uses a shared upvalue for its runtime pointer, we need to
    -- give each runtime its own copy of the module, meaning we can't just
    -- require() it and we have to abuse the fact that we know
    -- OpoInterpreter.swift keeps package.searchers[2] as "the thing to call to
    -- load a .lua file" just like the stock Lua runtime does.

    -- Also check preloads first, because that's what compiled-in modules use.
    local preload = package.preload[moduleName]
    if type(preload) == "function" then
        local instance = preload(moduleName)
        return instance
    end

    local loader = package.searchers[2](moduleName)
    assert(type(loader) == "function", loader)
    local instance = loader()
    return instance
end

function newRuntime(handler, era)
    if not era then
        era = "er5"
    end
    local codes = ops["codes_"..era]
    assert(codes, "Unrecognised era " .. era)
    local rt = Runtime {
        opcodes = codes,
        frameBase = 0, -- Where in the chunk we start the stack frames' memory
        chunk = Chunk { address = 0 },
        dbs = {
            open = {},
        },
        era = era,
        modules = {},
        luaModules = {}, -- modules that use opl.lua thus have to be tracked per-runtime
        files = {},
        ioh = handler or require("defaultiohandler"),
        resources = {}, -- keyed by string, anything that code wants to use to provide singleton/mutex/etc semantics
        signal = 0,
        trap = false,
        -- callTrace = true,
    }
    if era == "sibo" then
        rt.chunk:setSize(65536)
    else
        rt.chunk:setSize(16 * 1024 * 1024)
    end

    local opl = newModuleInstance("opl")
    rt.opl = opl
    opl._setRuntime(rt)
    -- And make all the opl functions accessible as eg runtime:gCLS()
    for name, fn in pairs(opl) do
        if type(fn) == "function" and not name:match("^_") then
            assert(rt[name] == nil, "Overlapping function names between Runtime and opl.lua!")
            rt[name] = function(self, ...) return opl[name](...) end
        end
    end
    return rt
end

-- Returns true when emulating SIBO (Series 3c)
function Runtime:isSibo()
    return self.era == "sibo"
end

-- Returns the datatype for parameters to opcodes that deal with addresses
-- eg IoSeek's addr parameter is an int on SIBO and a long on ER5
function Runtime:addressType()
    if self:isSibo() then
        return DataTypes.EWord
    else
        return DataTypes.ELong
    end
end

function Runtime:decodeNextInstruction()
    local currentIp = self.ip
    local opCode = sbyte(self.data, currentIp + 1)
    if not opCode then
        return fmt("%08X: ???", currentIp)
    end
    local op = self.opcodes[opCode]
    self.ip = currentIp + 1
    local opDump = op and op.."_dump"
    local extra = ops[opDump] and ops[opDump](self)
    if op == "CallFunction_sibo" then
        -- Special case how this is displayed, because CallFunction is not itself sibo specific (although the function
        -- being called may be)
        op = "CallFunction"
    end
    return fmt("%08X: %02X [%s]%s", currentIp, opCode, op or "?", extra and (" "..extra) or "")
end

function Runtime:dumpRawBytesUntil(newIp)
    while self.ip < newIp do
        local val = string.unpack("b", self.data, 1 + self.ip)
        local valu = string.unpack("B", self.data, 1 + self.ip)
        local ch = string.char(valu):gsub("[\x00-\x1F\x7F-\xFF]", "?")
        printf("%08X: %02X (%d) '%s'\n", self.ip, valu, val, ch)
        self.ip = self.ip + 1
    end
end

function Runtime:dumpProc(procName, startAddr)
    local proc = self:findProc(procName)
    local endIdx = proc.codeOffset + proc.codeSize
    self:pushNewFrame(nil, proc, #proc.params)
    if startAddr then
        self.ip = startAddr
    end
    local realCodeStart = proc.codeOffset
    while self.ip < endIdx do
        if self.ip == realCodeStart and string.unpack("B", self.data, 1 + self.ip) == 0xBF then
            -- Workaround for a main proc starting with a goto that jumps over some non-code
            -- data.
            local jmp = string.unpack("<i2", self.data, 1 + self.ip + 1)
            local newIp = self.ip + jmp
            print(self:decodeNextInstruction()) -- prints the goto
            self:dumpRawBytesUntil(newIp)
            realCodeStart = newIp
        elseif self.ip == realCodeStart and string.unpack("c3", self.data, 1 + self.ip) == "\x4F\x00\x5B" then
            -- Similarly, workaround a [StackByteAsWord] 0, [BranchIfFalse]
            local jmp = string.unpack("<i2", self.data, 1 + self.ip + 3)
            local newIp = self.ip + 2 + jmp
            print(self:decodeNextInstruction()) -- StackByteAsWord
            print(self:decodeNextInstruction()) -- BranchIfFalse
            self:dumpRawBytesUntil(newIp)
            realCodeStart = newIp
        elseif self.ip == realCodeStart and self.data:sub(1 + self.ip, self.ip + 10):match("[\x00\x08]..\x4F.\x40%\x5B..%\x2B") then
            -- Another variant which does a CompareEqualInt against an extern
            -- variable that's (afaics) always going to be zero.

            -- Simple[In]DirectRightSideInt, StackByteAsWord, CompareEqualInt, BranchIfFalse, ConstantString
            print(self:decodeNextInstruction()) -- SimpleInDirectRightSideInt
            print(self:decodeNextInstruction()) -- StackByteAsWord
            print(self:decodeNextInstruction()) -- CompareEqualInt
            local jmp = string.unpack("<i2", self.data, 1 + self.ip + 1)
            local newIp = self.ip + jmp            
            print(self:decodeNextInstruction()) -- BranchIfFalse
            self:dumpRawBytesUntil(newIp)
        else
            print(self:decodeNextInstruction())
        end
    end
    self:setFrame(nil)
end

local function run(self, stack)
    local opsync = self.ioh.opsync
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
            print(self:decodeNextInstruction(), fmt("stack=%d", stack.n))
            self.ip = savedIp
        end
        ops[op](stack, self)
        opsync()
    end
end

function Runtime:setInstructionDebug(flag)
    self.instructionDebug = flag
end

function Runtime:setCallTrace(flag)
    self.callTrace = flag
end

ErrObj = class {
    __tostring = function(self)
        return fmt("%s\n%s\n%s", self.msg, self.opoStack, self.luaStack)
    end
}

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
        local modName = self.frame.proc.module.name
        local info
        if self.frame.proc.fn then
            info = fmt("%s\\%s: [Lua] %s", modName, self.frame.proc.name, self.frame.lastPcallSite or "?")
        elseif self.frame.lastIp then
            self.ip = self.frame.lastIp
            info = fmt("%s\\%s:%s", modName, self.frame.proc.name, self:decodeNextInstruction())
        else
            info = fmt("%s\\%s", modName, self.frame.proc.name)
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

function Runtime:getOpoStacktrace()
    local err = {}
    addStacktraceToError(self, err, nil)
    return "    "..err.opoStack:gsub("\n", "\n    ")
end

function traceback(msgOrCode)
    local t = type(msgOrCode)
    local err = t == "table" and msgOrCode or {}
    setmetatable(err, ErrObj)
    if t == "number" then
        err.code = msgOrCode
        err.msg = fmt("%d (%s)", err.code, Errors[err.code] or "?")
    elseif t == "string" then
        err.msg = msgOrCode
    elseif t == "table" then
        if not err.msg then
            -- Can't assert here, that's really confusing from inside an error handler
            err.msg = "Missing msg in error!"
            print(err.msg)
        end
    end

    if err.luaStack == nil then
        err.luaStack = debug.traceback(nil, 2)
    end

    return err
end

function Runtime:pcallProc(procName, ...)
    local callingFrame = self.frame
    assert(callingFrame == nil or callingFrame.proc.fn, "Cannnot callProc while still executing something else!")

    local proc = self:findProc(procName)
    local args = table.pack(...)
    assert(args.n == #proc.params, "Wrong number of arguments in call to "..procName)

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
            -- print(err)
            self.errorLocation = fmt("Error in %s\\%s", self.frame.proc.module.name, self.frame.proc.name)

            if err.code and err.code == KStopErr then
                printf("Interrupted!\n%s\n", err)
            end

            if err.code and err.code ~= KStopErr and not self.haltOnAnyError then
                self.errorValue = err.code
                -- An error code that might potentially be handled by a Trap or OnErr
                if self.trap then
                    self.trap = false
                    -- And continue to next instruction
                else
                    -- See if this frame or any parent frame up to callingFrame has an error handler
                    while true do
                        if self.frame.errIp then
                            self.ip = self.frame.errIp
                            -- Jumping to an error handler nukes all temporaries on the stack
                            stack:popTo(self.frame.returnStackSize)
                            break
                        else
                            local prevFrame = self:popFrame(stack)
                            if prevFrame ~= callingFrame then
                                -- And loop again
                            else
                                return err
                            end
                        end
                    end
                end
            else
                repeat
                    local prevFrame = self:popFrame(stack)
                until prevFrame == callingFrame
                return err
            end
        end
    end
    assert(self.frame == callingFrame, "Frame was not restored on pcallProc exit!")
    -- memory.printStats()
    return nil -- no error
end

function Runtime:callProc(procName, ...)
    local err = self:pcallProc(procName, ...)
    if err then
        error(err)
    end
end

function Runtime:loadModule(path)
    local origPath = path
    printf("Runtime:loadModule(%s)\n", origPath)
    -- First see if this is a real module
    local data = self.ioh.fsop("read", path)
    if not data then
        path = origPath..".opm"
        data = self.ioh.fsop("read", path)
    end
    if not data then
        path = origPath..".opo"
        data = self.ioh.fsop("read", path)
    end
    if data then
        local procTable, opxTable = require("opofile").parseOpo(data, self.instructionDebug)
        self:addModule(path, procTable, opxTable)
        return
    end

    -- If not, see if we have a built-in
    path = origPath
    local modName = oplpath.splitext(oplpath.basename(path:lower()))
    local ok, mod = pcall(self.newOplModule, self, "modules."..modName)

    if not ok then
        printf("Module %s (from %s) not found\n", modName, path)
        error(KErrNoMod)
    end

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
    -- finally, import all the helper fns from opl.lua into mod's environment
    for name, fn in pairs(self.opl) do
        if not name:match("^_") then
            mod[name] = fn
        end
    end
end

function Runtime:declareGlobal(name, arrayLen)
    local frame = self.frame
    name = name:upper()
    assert(self.ip == nil and frame.proc.fn, "Can only declareGlobal from within a Lua module!")

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
    local type = valType
    if arrayLen then
        type = valType | 0x80
        name = name.."[]"
    end

    -- We define our indexes (which are how externals map to locals) as simply
    -- being the position of the item in the frame vars table. We can skip
    -- figuring out a byte-exact frame index because nothing actually needs to
    -- know it.
    local index = #frame.vars + 1

    -- For simplicity we'll assume any strings should be 255 max len
    local var = self.chunk:allocVariable(type, 255, arrayLen)
    frame.globals[name] = { offset = index, type = type }
    frame.vars[index] = var
    table.insert(frame.frameAllocs, var)

    return var
end

function Runtime:waitForAnyRequest()
    if self.signal > 0 then
        self.signal = self.signal - 1
        return
    end
    -- Have to make sure all ops are flushed before blocking
    self:flushGraphicsOps()
    local ok = self.ioh.waitForAnyRequest()
    -- A wait technically decrements the signal count, but completing it would
    -- increment it again hence a call to iohandler.waitForAnyRequest() that
    -- returns leaves the signal count unchanged.
    assert(ok, KStopErr)
end

function Runtime:waitForRequest(stat)
    local waits = -1
    repeat
        waits = waits + 1
        self:waitForAnyRequest()
    until not stat:isPending()
    -- And balance any waits we did for things that weren't stat
    self:requestSignal(waits)
end

function Runtime:checkCompletions()
    self.signal = self.signal + self.ioh.checkCompletions()
end

function Runtime:requestComplete(stat, ret)
    stat(ret)
    self:requestSignal()
end

function Runtime:requestSignal(num)
    self.signal = self.signal + (num or 1)
end

function Runtime:getPath()
    return self.modules[1].path
end

function Runtime:getCwd()
    return self.cwd
end

function Runtime:setCwd(cwd)
    assert(oplpath.isabs(cwd), "Cannot set a non-absolute CWD!")
    assert(cwd:match("\\$"), "Cannot set a non-dir path as CWD!")
    self.cwd = cwd
end

function Runtime:abs(path)
    -- The empty path should never be made into anything else, I don't think?
    -- This is different to the beheviour of oplpath.abs() (which is also used by PARSE$) which
    -- does support resolving the empty path.
    assert(path ~= "", KErrName)

    return oplpath.abs(path, self.cwd)
end

local function globToMatch(glob)
    local m = glob:gsub("[.+%%^$%(%)%[%]-]", "%%%0"):gsub("%?", "."):gsub("%*", ".*")
    return m:upper()
end

function Runtime:ls(path)
    local contents, err = self.ioh.fsop("dir", oplpath.join(path, ""))
    if contents then
        table.sort(contents, function(lhs, rhs) return oplpath.canon(lhs) < oplpath.canon(rhs) end)
    end
    return contents, err
end

function Runtime:isdir(path)
    local stat = self.ioh.fsop("stat", path)
    return stat and stat.isDir
end

function Runtime:getDisks()
    local result = assert(self.ioh.fsop("disks", ""))
    table.sort(result)
    return result
end

function Runtime:dir(path)
    -- printf("dir: %s\n", path)
    if path == "" then
        local result = self.dirResults and self.dirResults[1]
        if result then
            table.remove(self.dirResults, 1)
        end
        return result or ""
    end

    local dir, filenameFilter = oplpath.split(self:abs(path))
    local contents = assert(self:ls(dir))
    if #filenameFilter > 0 then
        local filtered = {}
        local m = "^"..globToMatch(filenameFilter).."$"
        for i, path in ipairs(contents) do
            local _, name = oplpath.split(path)
            -- printf("Checking %s against match %s\n", name, m)
            if name:upper():match(m) then
                table.insert(filtered, path)
            end
        end
        self.dirResults = filtered
    else
        self.dirResults = contents
    end
    return self:dir("")
end


function Runtime:addrFromInt(addr)
    -- if type(addr) == "number" then
    if ~addr then
        local offset = self.chunk:checkRange(addr)
        addr = Addr { chunk = self.chunk, offset = offset }
    end
    return addr
end

function Runtime:addrAsVariable(addr, type)
    return self:addrFromInt(addr):asVariable(type)
end

function Runtime:realloc(addr, sz)
    -- printf("Runtime:realloc(%s, %d)\n", addr, sz) --, self:getOpoStacktrace())
    if addr ~= 0 then
        local offset = self.chunk:checkRange(addr)
        local newOffset = self.chunk:realloc(offset, sz)
        if newOffset then
            return self.chunk.address + newOffset
        else
            return 0
        end
    else
        local offset = self.chunk:alloc(sz)
        assert(offset, KErrNoMemory)
        return self.chunk.address + offset
    end
end

function Runtime:allocLen(addr)
    local offset = self.chunk:checkRange(addr)
    return self.chunk:getAllocLen(offset)
end

function Runtime:adjustAlloc(addr, offset, sz)
    local chunk = self.chunk
    local cell = chunk:checkRange(addr)
    local allocLen = chunk:getAllocLen(cell)
    -- printf("adjustAlloc(0x%X, %X, %d)\n", cell, offset, sz)
    assert(offset >= 0, "Bad offset to adjustAlloc")
    if sz == 0 then
        -- nothing to do?
        return addr
    elseif sz < 0 then
        sz = -sz -- Makes logic easier to understand below
        assert(offset - sz < allocLen)
        -- close gap at offset, ie copy everything from offset+sz to offset
        chunk:memmove(cell + offset, cell + offset + sz, allocLen - offset - sz)
        return chunk.address + chunk:realloc(cell, allocLen - sz)
    else
        -- Add gap at offset
        local newCell = chunk:realloc(cell, allocLen + sz)
        if newCell then
            chunk:memmove(newCell + offset + sz, newCell + offset, allocLen - offset)
            return chunk.address + newCell
        else
            return 0
        end
    end
end

function Runtime:getAppUid()
    -- This is defined (by me) as the OPO uid3 of the first module added to the runtime. It doesn't account for AIF
    -- files, and may be nil.
    local firstMod = self.modules[1]
    return firstMod and firstMod.uid3
end

function runOpo(fileName, procName, iohandler, verbose)
    local data, err = iohandler.fsop("read", fileName)
    if not data then
        error("Failed to read opo file data")
    end
    runOpoFileData(fileName, data, procName, iohandler, verbose)
end

function runOpoFileData(fileName, data, procName, iohandler, verbose)
    -- parseOpo will bail if the UID1 is wrong, but with a less useful error
    if string.unpack("<I4", data) == KDynamicLibraryUid or data:sub(1, 16) == "ImageFileType**\0" then
        error({ msg = "File is a native binary and not compiled OPL.", notOpl = true })
    end

    local module = require("opofile").parseOpo2(data, verbose)
    iohandler.setEra(module.era) -- Needed to set the default string encoding
    local rt = newRuntime(iohandler, module.era)
    rt:setInstructionDebug(verbose)
    -- rt:setHaltOnAnyError(true) -- DEBUG
    rt:addModule(fileName, module.procTable, module.opxTable, module.uid3)
    local procToCall = procName and procName:upper() or module.procTable[1].name
    local err = rt:pcallProc(procToCall)
    if err and err.code == KStopErr then
        -- Don't care about the distinction
        err = nil
    end
    if err then
        error(err)
    end
end

function installSis(filename, data, iohandler)
    return require("sis").installSis(filename, data, iohandler, true, false)
end

function uninstallSis(stubList, uid, iohandler)
    local sis = require("sis")
    local stubMap = sis.stubArrayToUidMap(stubList)
    sis.uninstallSis(stubMap, uid, iohandler)
end

function runLauncherCmd(iohandler, cmd, ...)
    local rt = newRuntime(iohandler)
    rt:setCwd("C:\\")
    local fn = rt:require("launcher")[cmd]
    return fn(...)
end

return _ENV
