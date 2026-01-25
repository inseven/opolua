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


# This project file is responsible for generating luafiles.qrc which includes
# either the raw files from LUA_FILES, or the compiled luac files, depending
# on the value of USE_LUAC (default is USE_LUAC=1).

TEMPLATE = aux

LUA_FILES = \
    ../core/src/aif.lua \
    ../core/src/cmdline.lua \
    ../core/src/compiler.lua \
    ../core/src/const.lua \
    ../core/src/cp1252.lua \
    ../core/src/crc.lua \
    ../core/src/database.lua \
    ../core/src/decompiler.lua \
    ../core/src/defaultiohandler.lua \
    ../core/src/dialog.lua \
    ../core/src/directfilestore.lua \
    ../core/src/editor.lua \
    ../core/src/fns.lua \
    ../core/src/font.lua \
    ../core/src/init_dump.lua \
    ../core/src/init.lua \
    ../core/src/launcher.lua \
    ../core/src/mbm.lua \
    ../core/src/memory.lua \
    ../core/src/menu.lua \
    ../core/src/opl.lua \
    ../core/src/opofile.lua \
    ../core/src/ops.lua \
    ../core/src/recognizer.lua \
    ../core/src/rsc.lua \
    ../core/src/runtime.lua \
    ../core/src/scrollbar.lua \
    ../core/src/sibosyscalls.lua \
    ../core/src/sis.lua \
    ../core/src/sound.lua \
    ../core/src/stack.lua \
    ../core/src/struct.lua \
    ../core/src/unittest.lua \
    ../core/src/includes/bmp_oxh.lua \
    ../core/src/includes/const_oph.lua \
    ../core/src/includes/date_oxh.lua \
    ../core/src/includes/dbase_oxh.lua \
    ../core/src/includes/printer_oxh.lua \
    ../core/src/includes/sysram1_oxh.lua \
    ../core/src/includes/system_oxh.lua \
    ../core/src/includes/systinfo_oxh.lua \
    ../core/src/includes/toolbar_oph.lua \
    ../core/src/modules/toolbar.lua \
    ../core/src/opx/alarm.lua \
    ../core/src/opx/bmp.lua \
    ../core/src/opx/date.lua \
    ../core/src/opx/dbase.lua \
    ../core/src/opx/gprinter.lua \
    ../core/src/opx/printer.lua \
    ../core/src/opx/sysram1.lua \
    ../core/src/opx/system.lua \
    ../core/src/opx/systinfo.lua \
    ../bin/compile.lua \
    ../bin/dumpaif.lua \
    ../bin/dumpdb.lua \
    ../bin/dumpdfs.lua \
    ../bin/dumpfont.lua \
    ../bin/dumpmbm.lua \
    ../bin/dumpopo.lua \
    ../bin/dumprsc.lua \
    ../bin/dumpsis.lua \
    ../bin/makesis.lua \
    ../bin/opltotext.lua \
    ../bin/recognize.lua \
    ../bin/runopo.lua

LUA_QRC = $$OUT_PWD/luafiles.qrc

isEmpty(USE_LUAC) {
    USE_LUAC = 1
}

# This function figures out the right resource-filesystem path for a given file,
# based on just knowing where things live in the source filesystem (which is a
# bit of a hack, but it's easier to do it like this).
defineReplace(getLuaAlias) {
    repl = $$replace(1, "../core/src/", "")
    repl = $$replace(repl, "../bin/", "")
    return ($$repl)
}

defineReplace(getLuacOutputFilename) {
    repl = $$getLuaAlias($$1)
    repl = "luac/$${repl}c"
    # message("getLuacOutputFilename $$1 -> $$repl")
    return($$repl)
}

equals(USE_LUAC, 1) {
    # Compile LUA_FILES
    message("Using luac")
    mkpath($$OUT_PWD/luac/includes)
    mkpath($$OUT_PWD/luac/modules)
    mkpath($$OUT_PWD/luac/opx)
    compilelua.input = LUA_FILES
    compilelua.output_function = getLuacOutputFilename
    compilelua.commands = $$OUT_PWD/qluac ${QMAKE_FILE_IN} ${QMAKE_FILE_OUT}
    compilelua.CONFIG += no_link target_predeps
    QMAKE_EXTRA_COMPILERS += compilelua
} else {
    message("Not using luac")
}

# Generate the .qrc resource file for the compiled .luac files (or the .lua files)

makeLuacManifest.target = makeLuacManifest
makeLuacManifest.commands = $$OUT_PWD/qluac manifest $$LUA_QRC /lua

for (file, LUA_FILES) {
    alias = $$getLuaAlias($$file)
    equals(USE_LUAC, 1) {
        luacFile = $$getLuacOutputFilename($$file)
        path = $$relative_path($$OUT_PWD/$$luacFile, $$PWD)
    } else {
        path = $$file
    }
    # message("makeLuacManifest.commands += $$alias = $$path")
    makeLuacManifest.commands += $$alias $$path
}

QMAKE_EXTRA_TARGETS += makeLuacManifest
PRE_TARGETDEPS += makeLuacManifest
