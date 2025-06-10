// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include <QApplication>
#include "luasupport.h"
#include "mainwindow.h"
#include "oplapplication.h"
#include "oplruntime.h"

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

    int err = dofile(L, cmdPath);
    // qDebug("cmd returned %d", err);
    return err;
}

static QStringList validCmds = {
    "compile",
    "dumpaif",
    "dumpdb",
    "dumpdfs",
    "dumpmbm",
    "dumpopo",
    "dumprsc",
    "dumpsis",
    "opltotext",
    "recognize",
    "runopo",
};

int main(int argc, char *argv[])
{

    for (int i = 0; i < argc; i++) {
        qDebug("param %d: %s", i, argv[i]);
    }

    if (argc > 1 && strcmp(argv[1], "open") != 0) {
        QCoreApplication app(argc, argv);
        auto args = QCoreApplication::arguments();
        if (args.count() < 2 || !validCmds.contains(args[1])) {
            qDebug("Syntax: %s <cmd> [<args>...]", qPrintable(args[0]));
            qDebug("where <cmd> is one of:");
            qDebug("    open");
            for (const QString& cmd : validCmds) {
                qDebug("    %s", qPrintable(cmd));
            }
            qDebug("");
            qDebug("Run %s <cmd> --help for the syntax of individual commands.", qPrintable(args[0]));
            return 1;
        }
        args.removeAt(0);
        return runCommand(args);
    }

    OplApplication a(argc, argv);

    MainWindow* w = new MainWindow();

    auto args = QCoreApplication::arguments();
    if (args.count() == 3 && args[1] == "open") {
        w->show();
        w->onFileOpened(QFileInfo(args[2]).canonicalFilePath());
    } else {
        w->showLauncher();
    }

    // w->getRuntime().run(QDir(":/welcome/c"), "C:\\System\\Apps\\Welcome\\Welcome.app");

    // w->getRuntime().run(QDir("/Users/tomsci/Library/Containers/com.me.tomsci.OpoLua/Data/Documents/JUMPY!.system/c"),
    //     "C:\\System\\Apps\\Jumpy!\\Jumpy!.app");

    // w->getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/graphics.opo");
    // w->getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/getevent.opo");
    // w->getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/gstyle.opo");
    // w->getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/input.opo");
    // w->getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/dialog.opo");

    // w->getRuntime().runInstaller("/Users/tomsci/Documents/Dev/opl/JUMPY!.SIS", "/Users/tomsci/Documents/Dev/opl/JUMPY!.oplapp");
    // w->getRuntime().runInstaller("/Users/tomsci/Documents/Dev/opl/FCCrossword.sis", "/Users/tomsci/Documents/Dev/opl/FCCrossword_C");

    return a.exec();
}
