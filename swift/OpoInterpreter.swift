//
//  OpoInterpreter.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import Foundation

func traceHandler(_ L: OpaquePointer?) -> Int32 {
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

class OpoInterpreter {
    private let L: OpaquePointer

    init() {
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

        // The default impl using io.stdin:read() isn't gonna go well, supply a dummy for now
        registerFunctionHandler(functionName: "Get") { L in
            print("Ignoring GET!")
            luaL_getmetafield(L, 1, "push")
            lua_pushvalue(L, 1)
            lua_pushinteger(L, 32) // space
            lua_call(L, 2, 0) // push(stack, 32)
            return 0
        }

        assert(lua_gettop(L) == 0) // In case we failed to balance stack during init
    }

    // TODO
    // func registerOpcodeHandler(opCodeName: String, handler: lua_CFunction) {
    // }

    func registerFunctionHandler(functionName: String, handler: @escaping lua_CFunction) {
        lua_getglobal(L, "_Fns")
        lua_pushcfunction(L, handler)
        lua_setfield(L, -2, functionName)
        lua_pop(L, 1)
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

    func run(file: String) {
        guard luaL_dofile(L, Bundle.main.path(forResource: "runopo", ofType: "lua")!) == 0 else {
            fatalError(String(validatingUTF8: lua_tostring(L, -1))!)
        }
        lua_settop(L, 0)
        lua_getglobal(L, "runOpo")
        lua_newtable(L)
        lua_pushstring(L, file)
        lua_rawseti(L, -2, 1)
        let _ = pcall(1, 0) // runOpo( {file} )
    }
}
