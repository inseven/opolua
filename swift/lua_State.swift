//
//  lua_State.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import Foundation

typealias LuaState = UnsafeMutablePointer<lua_State>

extension UnsafeMutablePointer where Pointee == lua_State {

    func tostring(_ index: Int32) -> String? {
        let L = self
        let ret = luaL_tolstring(L, index, nil)! // luaL_tolstring never returns NULL
        let result = String(validatingUTF8: ret) // But it might not be valid UTF-8
        lua_pop(L, 1)
        return result
    }

    func tostringarray(_ index: Int32) -> [String] {
        let L = self
        var i: lua_Integer = 1
        var result: [String] = []
        while true {
            var str: String?
            if lua_rawgeti(L, index, i) == LUA_TSTRING {
                str = tostring(-1)
            }
            lua_pop(L, 1)
            if let str = str {
                result.append(str)
                i = i + 1
            } else {
                break
            }
        }
        return result
    }
}
