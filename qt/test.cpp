// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include <QDateTime>
#include <QTest>
#include <QTimeZone>
#include <time.h>

#include "luasupport.h"
#include "oplruntime.h"
#include "oplfns.h"

class OpoLuaTests: public QObject
{
    Q_OBJECT

private slots:
    void run_unittest();
    void run_tcompiler();
    void test_clockFormat();
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

static QString clockFmt(const char* fmt, OplClockType type, OplDateFormat df, bool system24hour)
{
    char buf[255];
    time_t tt{};
    struct tm t{};
    // if (testTime.isValid()) {
    //     tt = (time_t)testTime.toSecsSinceEpoch();
    // } else {
        QDateTime dt(QDate(1993, 3, 9), QTime(20, 30, 05), QTimeZone::systemTimeZone());
        tt = (time_t)dt.toSecsSinceEpoch();
    // }
    localtime_r(&tt, &t);

    OplClockFormatSettings settings = {
        .type = type,
        .dateFormat = df,
        .timeSeparator = ":",
        .dateSeparator = "/",
        .amText = "am",
        .pmText = "pm",
        .system24hour = system24hour,
    };
    bool ok = oplFormatClock(buf, sizeof(buf), fmt, &t, &settings);
    if (ok) {
        return QString::fromLocal8Bit(buf, -1);
    } else {
        return QString();
    }
}

static QString clockFmt3(const char* fmt, OplDateFormat df = EuropeanFormat, bool system24hour = false)
{
    return clockFmt(fmt, customFormatS3a, df, system24hour);
}

static QString clockFmt5(const char* fmt, OplDateFormat df = EuropeanFormat, bool system24hour = false)
{
    return clockFmt(fmt, customFormatS5, df, system24hour);
}

#define CHECK_CLOCK_3(args, expected) \
    QCOMPARE(clockFmt3 args, expected)

#define CHECK_CLOCK_5(args, expected) \
    QCOMPARE(clockFmt5 args, expected)

// For formats that behave the same on 3 and 5
#define CHECK_CLOCK_X(args, expected) do { \
    CHECK_CLOCK_3(args, expected); \
    CHECK_CLOCK_5(args, expected); \
} while (0)

void OpoLuaTests::run_unittest()
{
    QCOMPARE(runCommand({ "unittest" }), 0);
}

void OpoLuaTests::run_tcompiler()
{
    QCOMPARE(runCommand({ "tcompiler" }), 0);
}

void OpoLuaTests::test_clockFormat()
{
    CHECK_CLOCK_3(("%D%/%M/%Y"), "09/03/1993");
    CHECK_CLOCK_5(("%F%D/%M/%Y"), "09/03/1993");

    CHECK_CLOCK_3(("%*D/%*M/%*Y"), "9/3/93");
    CHECK_CLOCK_X(("%1/%2/%3"), "09/03/1993");
    CHECK_CLOCK_X(("%1/%2/%3", AmericanFormat), "03/09/1993");
    CHECK_CLOCK_X(("%1/%2/%3", JapaneseFormat), "1993/03/09");
    CHECK_CLOCK_3(("%P%1/%2/%3"), "09/3/1993"); // %P = short 2nd part
    CHECK_CLOCK_3(("%U%1/%2/%3", JapaneseFormat), "1993/03/9"); // %U = short 3rd part

    CHECK_CLOCK_X(("%4/%5", EuropeanFormat), "09/03");
    CHECK_CLOCK_X(("%4/%5", AmericanFormat), "03/09");
    CHECK_CLOCK_X(("%4/%5", JapaneseFormat), "03/09");
    CHECK_CLOCK_3(("%O%4/%5", EuropeanFormat), "09/March");
    CHECK_CLOCK_3(("%O%4/%5", AmericanFormat), "March/09");

    CHECK_CLOCK_3(("%H%:%T:%S"), "20:30:05");
    CHECK_CLOCK_5(("%H%:1%T:%S"), "20:30:05");

    CHECK_CLOCK_3(("%I:%T%A"), "08:30pm");
    CHECK_CLOCK_5(("%I:%T%A"), "8:30 pm"); // On 5 %I always suppresses leading zero
    CHECK_CLOCK_3(("%*I:%T%*A"), "8:30p");
    CHECK_CLOCK_5(("%I:%T%*A"), "8:30pm"); // And adds a space unless A is abbreviated

    CHECK_CLOCK_3(("%*I%:%T%A"), "8:30pm");
    CHECK_CLOCK_5(("%*I%:1%T%*A"), "8:30pm");
    CHECK_CLOCK_3(("%4/%5"), "09/03");
    CHECK_CLOCK_3(("%G%4/%5"), "9/03");
    CHECK_CLOCK_3(("%P%4/%5"), "09/3");
    CHECK_CLOCK_X(("Nothing but %%!"), "Nothing but %!");
    CHECK_CLOCK_3(("%F%1%G%1%G%1"), "TuesdayTueTuesday");
    CHECK_CLOCK_3(("%*6:%T%*7", EuropeanFormat, false), "8:30p");
    CHECK_CLOCK_3(("%6:%T%7", EuropeanFormat, true), "20:30");

    CHECK_CLOCK_5(("%J:%T%B", EuropeanFormat, false), "8:30 pm");
    CHECK_CLOCK_5(("%J:%T%*B", EuropeanFormat, false), "8:30pm");
    CHECK_CLOCK_5(("%J:%T%B", EuropeanFormat, true), "20:30");

    CHECK_CLOCK_5(("%-A%I:%T:%S%+A"), "8:30:05 pm");
    CHECK_CLOCK_5(("%Z %*Z"), "068 68");
    CHECK_CLOCK_5(("%F%E %*D%X %N %Y"), "Tuesday 9 March 1993");
    CHECK_CLOCK_5(("%E %D%X%N%Y%1 %2 %3"), "Tuesday 09 March 1993");
    CHECK_CLOCK_5(("%*E %*D%X%*N%*Y%1 %2 %3"), "Tue 9 Mar 93");

    CHECK_CLOCK_3(("%!%B%C"), "%!%B%C"); // Invalid sequences are printed verbatim
    CHECK_CLOCK_5(("%!%G"), "!G"); // ...unlike on the Series 5
    CHECK_CLOCK_5(("%*-A"), "-A");
    CHECK_CLOCK_5(("a%-*Aa"), ""); // Invalid
    CHECK_CLOCK_5(("%*-A"), "-A");

    CHECK_CLOCK_3(("a%"), "a%");
    CHECK_CLOCK_5(("a%"), "a");
}

QTEST_GUILESS_MAIN(OpoLuaTests)
#include "test.moc"
