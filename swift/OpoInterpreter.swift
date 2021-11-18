//
//  OpoInterpreter.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import Foundation

private func traceHandler(_ L: OpaquePointer?) -> Int32 {
    var msg = lua_tostring(L, 1)
    if msg == nil {  /* is error object not a string? */
        if luaL_callmeta(L, 1, "__tostring") != 0 &&  /* does it have a metamethod */
            lua_type(L, -1) == LUA_TSTRING { /* that produces a string? */
            return 1  /* that is the message */
        } else {
            let t = String(utf8String: luaL_typename(L, 1))!
            msg = lua_pushstring(L, "(error object is a \(t) value)")
        }
    }
    luaL_traceback(L, L, msg, 1)  /* append a standard traceback */
    return 1  /* return the traceback */
}

private func getInterpreterUpval(_ L: OpaquePointer?) -> OpoInterpreter {
    let rawPtr = lua_topointer(L, lua_upvalueindex(1))!
    return Unmanaged<OpoInterpreter>.fromOpaque(rawPtr).takeUnretainedValue()
}

private func alert(_ L: OpaquePointer?) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    let luaHelper = lua_State(L)
    let lines = luaHelper.tostringarray(1)
    let buttons = luaHelper.tostringarray(2)
    let ret = iohandler.alert(lines: lines, buttons: buttons)
    lua_pushinteger(L, Int64(ret))
    return 1
}

private func getch(_ L: OpaquePointer?) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    lua_pushinteger(L, Int64(iohandler.getch()))
    return 1
}

private func print_lua(_ L: OpaquePointer?) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.print(lua_State(L).tostring(1) ?? "")
    return 0
}

class OpoInterpreter {
    private let L: OpaquePointer
    var iohandler: OpoIoHandler

    init() {
        iohandler = DummyIoHandler() // For now...
        L = luaL_newstate()
        let libs: [(String, lua_CFunction)] = [
            ("_G", luaopen_base),
            (LUA_LOADLIBNAME, luaopen_package),
            (LUA_TABLIBNAME, luaopen_table),
            (LUA_IOLIBNAME, luaopen_io),
            (LUA_STRLIBNAME, luaopen_string),
            (LUA_MATHLIBNAME, luaopen_math),
            (LUA_UTF8LIBNAME, luaopen_utf8),
            (LUA_DBLIBNAME, luaopen_debug)
        ]
        for (name, fn) in libs {
            luaL_requiref(L, name, fn, 1)
            lua_pop(L, 1)
        }

        // Now configure the require path
        let resources = Bundle.main.resourcePath!
        let searchPath = resources + "/?.lua"
        lua_getglobal(L, "package")
        lua_pushstring(L, searchPath)
        lua_setfield(L, -2, "path")
        lua_pop(L, 1) // package

        // Finally, run init.lua
        let err = luaL_dofile(L, resources + "/init.lua")
        if err != 0 {
            let errStr = String(validatingUTF8: lua_tostring(L, -1))!
            print(errStr)
            lua_pop(L, 1)
        }

        assert(lua_gettop(L) == 0) // In case we failed to balance stack during init
    }

    deinit {
        lua_close(L)
    }

    func pcall(_ narg: Int32, _ nret: Int32) -> Bool {
        let base = lua_gettop(L) - narg // Where the function is, and where the msghandler will be
        lua_pushcfunction(L, traceHandler)
        lua_insert(L, base)
        let err = lua_pcall(L, narg, nret, base);
        lua_remove(L, base)
        if err != 0 {
            let errStr = String(validatingUTF8: lua_tostring(L, -1))!
            print("Error: \(errStr)")
            lua_pop(L, 1)
            return false
        }
        return true
    }

    func makeIoHandlerBridge() {
        lua_newtable(L)
        let val = Unmanaged<OpoInterpreter>.passUnretained(self)
        func pushFn(_ name: String, _ fn: @escaping lua_CFunction) {
            lua_pushlightuserdata(L, val.toOpaque())
            lua_pushcclosure(L, fn, 1)
            lua_setfield(L, -2, name)
        }
        pushFn("alert", alert)
        pushFn("getch", getch)
        pushFn("print", print_lua)
    }

    func run(file: String) {
        guard luaL_dofile(L, Bundle.main.path(forResource: "runopo", ofType: "lua")!) == 0 else {
            fatalError(String(validatingUTF8: lua_tostring(L, -1))!)
        }
        lua_settop(L, 0)
        lua_getglobal(L, "runOpo")
        lua_pushstring(L, file)
        lua_pushnil(L)
        makeIoHandlerBridge()
        let _ = pcall(3, 0) // runOpo(file, nil, iohandler)
    }
}
