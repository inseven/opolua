// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include <QApplication>
#include "luasupport.h"
#include "mainwindow.h"
#include "oplapplication.h"
#include "oplruntime.h"

int main(int argc, char *argv[])
{

    // for (int i = 0; i < argc; i++) {
    //     qDebug("param %d: %s", i, argv[i]);
    // }

    OplApplication a(argc, argv);

    MainWindow w;
    w.show();

    // w.getRuntime().run(QDir(":/welcome/c"), "C:\\System\\Apps\\Welcome\\Welcome.app");

    // w.getRuntime().run(QDir("/Users/tomsci/Library/Containers/com.me.tomsci.OpoLua/Data/Documents/JUMPY!.system/c"),
    //     "C:\\System\\Apps\\Jumpy!\\Jumpy!.app");

    // w.getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/graphics.opo");
    // w.getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/getevent.opo");
    // w.getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/gstyle.opo");
    // w.getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/input.opo");
    // w.getRuntime().runOpo("/Users/tomsci/Documents/Dev/opl/opolua/examples/Tests/dialog.opo");

    // w.getRuntime().runInstaller("/Users/tomsci/Documents/Dev/opl/JUMPY!.SIS", "/Users/tomsci/Documents/Dev/opl/JUMPY!.oplapp");
    // w.getRuntime().runInstaller("/Users/tomsci/Documents/Dev/opl/FCCrossword.sis", "/Users/tomsci/Documents/Dev/opl/FCCrossword_C");

    return a.exec();
}
