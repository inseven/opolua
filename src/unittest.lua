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

function checkParse(path, expected)
    local drv, dir, name, ext = oplpath.parse(path)
    assertEquals(drv..dir..name..ext, path)
    assertEquals({drv, dir, name, ext}, expected)
end

function checkSplitExt(path, expectedExt)
    local base, ext = oplpath.splitext(path)
    assertEquals(base..ext, path)
    assertEquals(ext, expectedExt)
end

function main()

    assertEquals(toint16(0x10123), 0x123)
    assertEquals(toint16(-1), -1)
    assertEquals(toint16(-32768), -32768)
    assertEquals(toint16(0xFFFF), -1)
    assertEquals(toint16(0xFFFE), -2)
    assertEquals(toint16(0x0FFFFFFE), -2)
    assertEquals(touint16(0xFFF0), 0xFFF0)

    checkSplitExt("", "")
    checkSplitExt(".", ".") -- I guess this should be treated as an empty extension...?
    checkSplitExt("foo.bar", ".bar")
    checkSplitExt("C:\\.foo", ".foo")
    checkSplitExt([[C:\a.b\foo]], "")
    checkSplitExt([[C:\a.b\foo.bar]], ".bar")

    checkParse("foo", {"", "", "foo", ""})
    checkParse([[C:\foo\bar.baz]], {"C:", [[\foo\]], "bar", ".baz"})
    checkParse([[C:woop]], {"C:", "", "woop", ""})
    checkParse([[C:woop.txt]], {"C:", "", "woop", ".txt"})

    assertEquals(oplpath.abs("woop", [[D:\System\Apps\woop\woop.app]]), [[D:\System\Apps\woop\woop]])
    assertEquals(oplpath.abs("C:woop", [[D:\System\Apps\woop\woop.app]]), [[C:\System\Apps\woop\woop]])
    assertEquals(oplpath.abs("C:woop", [[D:\System\Apps\woop\*.mbm]]), [[C:\System\Apps\woop\woop.mbm]])

    assertEquals(oplpath.join([[C:\]], "dir"), [[C:\dir]])
    assertEquals(oplpath.join([[C:\dir]], "sub"), [[C:\dir\sub]])
    assertEquals(oplpath.join([[C:\dir\]], "sub"), [[C:\dir\sub]])
    assertEquals(oplpath.join([[C:\dir]], ""), [[C:\dir\]])
    assertEquals(oplpath.join([[C:\dir\]], ""), [[C:\dir\]])
    assertEquals(oplpath.join("a", "b"), [[a\b]])

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

    checkSpec("", "", "Table1", nil, nil)

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

    local mbm = require("mbm")
    local rleEncode = mbm.rleEncode
    local function rleDecode(data, pixelSize)
        return mbm.rleDecode(data, 1, #data, pixelSize or 1)
    end

    local function checkRle(data, expected, pixelSize)
        local encoded = rleEncode(data, pixelSize or 1)
        assertEquals(hexEscape(encoded), hexEscape(expected))
        assertEquals(rleDecode(encoded, pixelSize), data)
    end

    checkRle("", "")
    checkRle("abcde", "\251abcde")
    checkRle("abccd", "\254ab\1c\255d")
    checkRle("aaa", "\2a")
    checkRle(string.rep("a", 128), "\127a")
    checkRle(string.rep("a", 129), "\127a\255a")
    checkRle(string.rep("a", 130), "\127a\1a")
    checkRle(string.rep("a", 131).."b", "\127a\2a\255b")

    checkRle("", "", 2)
    checkRle("aabbccddee", "\251aabbccddee", 2)
    checkRle("aabbccccdd", "\254aabb\1cc\255dd", 2)
    checkRle("aaaaaa", "\2aa", 2)
    checkRle(string.rep("aa", 128), "\127aa", 2)
    checkRle(string.rep("aa", 129), "\127aa\255aa", 2)
    checkRle(string.rep("aa", 130), "\127aa\1aa", 2)
    checkRle(string.rep("aa", 131).."bb", "\127aa\2aa\255bb", 2)

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
