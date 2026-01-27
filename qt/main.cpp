/*
 * Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <QApplication>
#include "luasupport.h"
#include "mainwindow.h"
#include "oplapplication.h"
#include "oplruntimegui.h"

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
    "makesis",
    "opltotext",
    "recognize",
    "runopo",
    "unittest",
};

int main(int argc, char *argv[])
{

    // for (int i = 0; i < argc; i++) {
    //     qDebug("param %d: %s", i, argv[i]);
    // }

    if (argc == 2 && strcmp(argv[1], "register") == 0) {
        return OplApplication::registerApp();
    } else if (argc == 2 && strcmp(argv[1], "unregister") == 0) {
        OplApplication::unregisterApp();
        return 0;
    }

    if (argc > 1 && strcmp(argv[1], "open") != 0) {
        QCoreApplication app(argc, argv);
        auto args = QCoreApplication::arguments();
        if (args.count() < 2 || !validCmds.contains(args[1])) {
            qDebug("Syntax: %s <cmd> [<args>...]", qPrintable(args[0]));
            qDebug("where <cmd> is one of:");
            qDebug("    open");
            qDebug("    register");
            qDebug("    unregister");
            for (const QString& cmd : validCmds) {
                qDebug("    %s", qPrintable(cmd));
            }
            qDebug("%s", "");
            qDebug("Run %s <cmd> --help for the syntax of individual commands.", qPrintable(args[0]));
            return 1;
        }
        args.removeAt(0);
        return runCommand(args);
    }

    OplApplication a(argc, argv);

    MainWindow* w = new MainWindow();

    auto args = QCoreApplication::arguments();
    QString device;
    int scale = 0;
    // 0 is app path, 1 will be "open" (or nothing)
    for (int i = 2; i < args.count(); i++) {
        if (args[i] == "--device" || args[i] == "-d") {
            if (i + 1 < args.count()) {
                args.removeAt(i);
                device = args[i];
                args.removeAt(i);
                i--;
            } else {
                qWarning("Syntax: opolua open --device <devicetype>");
                return 1;
            }
        } else if (args[i] == "--scale" || args[i] == "-s") {
            if (i + 1 < args.count()) {
                args.removeAt(i);
                scale = args[i].toInt();
                args.removeAt(i);
                i--;
            } else {
                qWarning("Syntax: opolua open --scale 1|2|3|4");
                return 1;
            }
        }
    }
    if (args.count() == 3 && args[1] == "open") {
        w->show();
        if (!device.isEmpty()) {
            w->getRuntime().setDeviceType(OplRuntime::toDeviceType(device));
            // Allow for eg a series 3 device type even when running a er5-era test file
            w->getRuntime().setIgnoreOpoEra(true);
        }
        if (scale >= 1 && scale <= 4) {
            w->setScale(scale);
        }
        w->openFile(QFileInfo(args[2]).canonicalFilePath());
    } else {
        w->showLauncher();
    }

    return a.exec();
}
