_ENV = module()

-- A default implementation of the iohandler interface, mapping to basic console
-- interactions using io.stdin and stdout.

local fmt = string.format

local statusRequests = {}

function print(val)
    printf("%s", val)
end

function readLine(escapeShouldErrorEmptyInput)
    local line = io.stdin:read()
    -- We don't support pressing esc to clear the line, oh well
    if escapeShouldErrorEmptyInput and line:byte(1, 1) == 27 then
        -- Close enough...
        error(KOplErrEsc)
    end
    return line
end

function alert(lines, buttons)
    printf("---ALERT---\n%s\n", lines[1])
    if lines[2] then
        printf("%s\n", lines[2])
    end
    printf("[1]: %s\n", buttons[1] or "Continue")
    if buttons[2] then
        printf("[2]: %s\n", buttons[2])
    end
    if buttons[3] then
        printf("[3]: %s\n", buttons[3])
    end
    local choice = tonumber(io.stdin:read())
    if choice == nil or buttons[choice] == nil then
        choice = 1
    end
    return choice
end

function getch()
    -- Can't really do this with what Lua's io provides, as stdin is always in line mode
    printf("GET called:")
    local ch = io.stdin:read(1)
    return ch:byte(1, 1)
end

function beep(freq, duration)
    printf("BEEP %gkHz for %gs", freq, duration)
end


function dialog(d)
    printf("---DIALOG---\n%s\n", d.title)
    for i, item in ipairs(d.items) do
        -- printf("ITEM:%d\n", item.type)
        printf("% 2d. ", i)
        if item.prompt and #item.prompt > 0 then
            printf("%s: ", item.prompt)
        end
        if item.type == dItemTypes.dCHOICE then
            printf("%s: %s (default=%d)\n", item.prompt, table.concat(item.choices, " / "), item.value)
        elseif item.value then
            printf("%s\n", item.value)
        else        end
    end
    for _, button in ipairs(d.buttons or {}) do
        printf("[Button %d]: %s\n", button.key, button.text)
    end
    -- TODO some actual editing support?
    printf("---END DIALOG---\n")
    return 0 -- meaning cancelled
end

function menu(m)
    local function fmtCode(code)
        local keycode = math.abs(code) & 0xFF
        if keycode >= string.byte("A") and keycode <= string.byte("Z") then
            return string.format("Ctrl-Shift-%s", string.char(keycode):upper())
        elseif keycode > 32 then
            return string.format("Ctrl-%s", string.char(keycode):upper())
        else
            return tostring(keycode)
        end
    end
    local function printCard(idx, card, lvl)
        local indent = string.rep(" ", lvl * 4)
        for i, item in ipairs(card) do
            local hightlightIdx = idx and 256 * (idx - 1) + (i - 1)
            printf("%s%s. %s [%s]\n", indent, hightlightIdx or "", item.text, fmtCode(item.keycode))
            if item.submenu then
                printCard(nil, item.submenu, lvl + 1)
            end
            if item.keycode < 0 then
                -- separator after
                printf("--\n")
            end
        end
    end

    printf("---MENU---\n")
    for menuIdx, card in ipairs(m) do
        printf("%s:\n", card.title)
        printCard(menuIdx, card, 0)
    end
    printf("---END MENU---\n")
    return 0, 0 -- ie cancelled
end

local function describeOp(op)
    local ret = fmt("%s x=%d y=%d", op.type, op.x, op.y)
    if op.type == "circle" then
        ret = ret .. fmt(" radius=%d fill=%d", op.r, op.fill)
    elseif op.type == "line" then
        ret = ret .. fmt(" x2=%d y2=%d", op.x2, op.y2)
    end
    return ret
end

function graphics(ops)
    for _, op in ipairs(ops) do
        printf("%s\n", describeOp(op))
    end
end

function getScreenSize()
    return 640, 240
end

local fsmaps = {}

function fsmap(devicePath, hostPath)
    table.insert(fsmaps, { devicePath = devicePath, hostPath = hostPath })
end

local function mapDevicePath(path) 
    for _, m in ipairs(fsmaps) do
        if path:sub(1, #m.devicePath) == m.devicePath then
            return m.hostPath .. path:sub(#m.devicePath + 1):gsub("\\", "/")
        end
    end
    error("No device path mapping for "..path)
end

local function fileErrToOpl(errno)
    if errno == 2 then -- ENOENT = 2
        return KOplErrNotExists
    else
        return KOplErrNotReady
    end
end

function fsop(cmd, path, ...)
    local filename = mapDevicePath(path)
    if cmd == "exists" then
        -- printf("exists %s\n", filename)
        local f = io.open(filename, "r")
        if f then
            f:close()
            return KOplErrExists
        else
            return KOplErrNotExists
        end
    elseif cmd == "delete" then
        printf("delete %s\n", filename)
        local ok, err, errno = os.remove(filename)
        return ok and KErrNone or fileErrToOpl(errno)
    elseif cmd == "mkdir" then
        printf("mkdir %s\n", filename)
        local ret, err = os.execute(fmt('mkdir -p "%s"', filename))
        -- Not handling the already exists case, because mkdir -p doesn't. Don't care.
        if ret then
            return KErrNone
        else
            return KOplErrNotReady
        end
    elseif cmd == "write" then
        printf("write %s\n", filename)
        local data = ...
        local f, err, errno = io.open(filename, "wb")
        if f then
            f:write(data)
            f:close()
            return KErrNone
        else
            return fileErrToOpl(errno)
        end
    elseif cmd == "read" then
        local f, err, errno = io.open(filename, "rb")
        if f then
            local data = f:read("a")
            f:close()
            return data
        else
            return nil, fileErrToOpl(errno)
        end
    else
        error("Unrecognised fsop "..cmd)
    end
end

function asyncRequest(name, statusVar, ...)
    local req = { name = name, statusVar = statusVar }
    if name == "getevent" then
        req.eventArray = ...
    else
        error("Unknown asyncRequest "..name)
    end
    statusRequests[name] = req
end

function waitForAnyRequest()
    -- This is a very cut-down implementation that doesn't handle much
    local eventRequest = statusRequests["getevent"]
    if not eventRequest then
        error("No outstanding requests we can complete, gonna error instead")
    end

    local ch = getch()
    eventRequest.eventArray[1](ch)
    eventRequest.statusVar(0)
    statusRequests["getevent"] = nil
end

return _ENV
