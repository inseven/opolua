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

TARGET = qluac
CONFIG -= qt debug_and_release debug_and_release_target
CONFIG += cmdline sdk_no_version_check

!windows:DEFINES += LUA_USE_POSIX

SOURCES += qluac.c ../dependencies/LuaSwift/Sources/CLua/loadfile.c

INCLUDEPATH += ../dependencies/LuaSwift/Sources/CLua/lua
