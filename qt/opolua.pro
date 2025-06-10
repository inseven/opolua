# message($$QMAKESPEC)

QT += core gui widgets multimedia

greaterThan(QT_MAJOR_VERSION, 5): QT += core5compat

CONFIG += c++17 sdk_no_version_check debug

!windows:DEFINES += LUA_USE_POSIX

macx {
    TARGET = OpoLua
    QMAKE_APPLICATION_BUNDLE_NAME = "OpoLua Qt"
    QMAKE_INFO_PLIST = Info.plist
}

VERSION = 1.2.0

HEADERS += \
    asynchandle.h \
    clockwidget.h \
    luasupport.h \
    filesystem.h \
    mainwindow.h \
    oplapplication.h \
    oplkeycode.h \
    oplruntime.h \
    oplscreenwidget.h

SOURCES += \
    clockwidget.cpp \
    lua.cpp \
    luasupport.cpp \
    filesystem.cpp \
    main.cpp \
    mainwindow.cpp \
    oplapplication.cpp \
    oplkeycode.cpp \
    oplruntime.cpp \
    oplscreenwidget.cpp

INCLUDEPATH += ../LuaSwift/Sources/CLua/lua

FORMS += \
    mainwindow.ui

RESOURCES += \
    opolua.qrc

!isEmpty(target.path): INSTALLS += target
