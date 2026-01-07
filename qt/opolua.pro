# Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# message($$QMAKESPEC)

isEmpty(VERSION) {
    VERSION = 0.0.1
}

isEmpty(BUILD_NUMBER) {
    BUILD_NUMBER = 0
}

QT += core gui widgets multimedia

greaterThan(QT_MAJOR_VERSION, 5): QT += core5compat

CONFIG += c++17 sdk_no_version_check

!windows:DEFINES += LUA_USE_POSIX

macx {
    TARGET = OpoLua
    QMAKE_APPLICATION_BUNDLE_NAME = "OpoLua"
    plist.input = Info.plist.in
    plist.output = $$OUT_PWD/Info.plist
    QMAKE_SUBSTITUTES += plist
    QMAKE_INFO_PLIST = $$OUT_PWD/Info.plist
    ICON = AppIcon.icns
}

windows {
    QMAKE_TARGET_PRODUCT = "OpoLua"
    QMAKE_TARGET_COPYRIGHT = "Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe"
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
    oplscreenwidget.cpp \
    ../core/shared/src/oplfns.c

INCLUDEPATH += ../core/shared/include ../dependencies/LuaSwift/Sources/CLua/lua

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
