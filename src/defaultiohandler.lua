_ENV = module()

-- A default implementation of the iohandler interface, mapping to basic console
-- interactions using io.stdin and stdout.

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
    local ch = io.stdin:read(1)
    return ch:byte(1, 1)
end

return _ENV
