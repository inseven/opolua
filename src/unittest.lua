#!/usr/bin/env lua

-- Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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

    checkQuery("FIELDS thingfrom TO woop", {
        FIELDS = "thingfrom",
        TO = "woop",
    })

    checkQuery("select text from texts where ID='         0' and TType=' order by ' order by id, l", {
        SELECT = "text",
        FROM = "texts",
        WHERE = "ID='         0' and TType=' order by '",
        ["ORDER BY"] = "id, l",
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

    checkSpec('"dbname.db" SELECT name,number FROM phoneBook ORDER BY name ASC, number DESC',
        "dbname.db",
        "phoneBook",
        { "name", "number" },
        {
            { name = "name", ascending = true },
            { name = "number", ascending = false },
        }
    )

    checkSpec([["C:\System\Apps\biklog5\biklog5.ini" SELECT name,string,integer,long,float FROM deftable]],
        [[C:\System\Apps\biklog5\biklog5.ini]],
        "deftable",
        { "name", "string", "integer", "long", "float" }
    )

    local exp = database.parseWhere("ID='0' and TType='NOTES'")
    assertEquals(exp({ID="0", TTYPE="NOTES"}), true)
    assertEquals(exp({ID="1", TTYPE="NOTES"}), false)

    local likeExp = database.parseWhere("foo LIKE '*b?r'")
    assertEquals(likeExp({FOO="abar"}), true)
    assertEquals(likeExp({FOO="barr"}), false)
    assertEquals(likeExp({FOO="foobor"}), true)

    likeExp = database.parseWhere("FOO LIKE 'd?om%'")
    assertEquals(likeExp({FOO="doom%"}), true)
    assertEquals(likeExp({FOO="dom%"}), false)

    print("All tests passed.")
end

function checkSpec(spec, expectedPath, expectedTableName, expectedFields, expectedSort)
    local path, tableName, fields, filterPredicate, sortSpec = database.parseTableSpec(spec)
    assertEquals(path, expectedPath)
    assertEquals(tableName, expectedTableName)
    assertEquals(fields, expectedFields)
    assertEquals(sortSpec, expectedSort)
end

pcallMain()
