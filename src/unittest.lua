#!/usr/bin/env lua

-- Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

dofile(arg[0]:match("^(.-)[a-z]+%.lua$").."cmdline.lua")

function assertEquals(a, b)
    local adump, bdump = dump(a), dump(b)
    if adump ~= bdump then
        error(string.format("%s != %s", adump, bdump))
    end
end

function checkQuery(query, value)
    assertEquals(database.splitQuery(query), value)
end

function main()
    database = require("database")

    assertEquals(database.commaSplit(""), { "" })
    assertEquals(database.commaSplit("abc"), { "abc" })
    assertEquals(database.commaSplit("a, bb, ccc"), { "a", "bb", "ccc" })
    assertEquals(database.commaSplit(" a ,bb, ccc dd,"), { "a", "bb", "ccc dd", "" })

    checkQuery("SELECT foo FROM bar", {
        SELECT = "foo",
        FROM = "bar",
    })

    checkQuery(" select  foo  fROm  bar ", {
        SELECT = "foo",
        FROM = "bar",
    })

    checkQuery("SELECT name,number FROM phoneBook ORDER BY name ASC, number DESC", {
        SELECT = "name,number",
        FROM = "phoneBook",
        ["ORDER BY"] = "name ASC, number DESC",
    })

    checkSpec("clients SELECT name, tel FROM phone",
        "clients",
        "phone",
        { "name", "tel" }
    )

    checkSpec("clients FIELDS name(40), tel TO phone",
        "clients",
        "phone",
        { "name", "tel" }
    )

    checkSpec([["C:\System\Apps\biklog5\biklog5.ini" SELECT name,string,integer,long,float FROM deftable]],
        [[C:\System\Apps\biklog5\biklog5.ini]],
        "deftable",
        { "name", "string", "integer", "long", "float" }
    )

end

function checkSpec(spec, expectedPath, expectedTableName, expectedFields)
    local path, tableName, fields = database.parseTableSpec(spec)
    assertEquals(path, expectedPath)
    assertEquals(tableName, expectedTableName)
    assertEquals(fields, expectedFields)
end

pcallMain()
