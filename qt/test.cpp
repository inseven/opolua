// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include <QTest>

#include "luasupport.h"
#include "oplruntime.h"

class OpoLuaTests: public QObject
{
    Q_OBJECT

private slots:
    void run_unittest();
    void run_tcompiler();
};

// We want test failures that call os.exit(false) (due to cmdline.lua) to instead error
static int osExitError(lua_State* L)
{
    if (lua_isboolean(L, 1) && lua_toboolean(L, 1) == 0) {
        return luaL_error(L, "Erroring due to os.exit(false)");
    } else if (lua_isnumber(L, 1) && lua_tointeger(L, 1) != 0) {
        return luaL_error(L, "Errororing due to os.exit(%d)", lua_tointeger(L, 1));
    }
    return 0;
}

static int runCommand(const QStringList& args)
{
    auto cmdPath = QString(":/lua/") + args[0] + ".lua";
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    OplRuntime::configureLuaResourceSearcher(L);

    // Setup arg
    lua_newtable(L);
    pushValue(L, cmdPath);
    lua_rawseti(L, -2, 0);
    for (int i = 1; i < args.count(); i++) {
        pushValue(L, args[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    lua_pushcfunction(L, OplRuntime::dofile);
    lua_setglobal(L, "dofile");

    // Stub os.exit because cmdline.lua's pcallMain assumes it should use it
    lua_getglobal(L, "os");
    lua_pushcfunction(L, osExitError);
    lua_setfield(L, -2, "exit");

    int err = dofile(L, cmdPath);
    // qDebug("cmd returned %d", err);
    lua_close(L);
    return err;
}

void OpoLuaTests::run_unittest()
{
    QCOMPARE(runCommand({ "unittest" }), 0);
}

void OpoLuaTests::run_tcompiler()
{
    QCOMPARE(runCommand({ "tcompiler" }), 0);
}

QTEST_GUILESS_MAIN(OpoLuaTests)
#include "test.moc"
