# Copyright (c) 2025 Jason Morley, Tom Sutcliffe
# See LICENSE file for license information.

# message($$QMAKESPEC)

VERSION = 1.2.0

QT += core gui widgets multimedia

greaterThan(QT_MAJOR_VERSION, 5): QT += core5compat

CONFIG += c++17 sdk_no_version_check debug

!windows:DEFINES += LUA_USE_POSIX

macx {
    TARGET = OpoLua
    QMAKE_APPLICATION_BUNDLE_NAME = "OpoLua"
    QMAKE_INFO_PLIST = Info.plist
    ICON = AppIcon.icns
}

windows {
    QMAKE_TARGET_PRODUCT = "OpoLua"
    QMAKE_TARGET_COPYRIGHT = "Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe"
    QMAKE_TARGET_DESCRIPTION = "OpoLua OPL Emulator v$$VERSION"
    RC_ICONS = "AppIcon.ico"
}

DEFINES += OPOLUA_VERSION=$$VERSION

HEADERS += \
    aboutwindow.h \
    asynchandle.h \
    clockwidget.h \
    filesystem.h \
    logwindow.h \
    luasupport.h \
    mainwindow.h \
    oplapplication.h \
    oplkeycode.h \
    oplruntime.h \
    oplruntimegui.h \
    oplscreenwidget.h

SOURCES += \
    aboutwindow.cpp \
    clockwidget.cpp \
    filesystem.cpp \
    logwindow.cpp \
    lua.cpp \
    luasupport.cpp \
    main.cpp \
    mainwindow.cpp \
    oplapplication.cpp \
    oplkeycode.cpp \
    oplruntime.cpp \
    oplruntimegui.cpp \
    oplscreenwidget.cpp

INCLUDEPATH += ../LuaSwift/Sources/CLua/lua

FORMS += \
    aboutwindow.ui \
    logwindow.ui \
    mainwindow.ui

RESOURCES += \
    opolua.qrc

!isEmpty(target.path): INSTALLS += target

linux {
    appReg.path = /usr/share/applications
    appReg.files = org.opolua.opolua-qt.desktop

    mimeTypes.path = /usr/share/mime/packages
    mimeTypes.files = sis-installer.xml opolua.xml

    icons.path = /usr/share/pixmaps
    icons.files = opolua.png

    INSTALLS += appReg mimeTypes icons
}