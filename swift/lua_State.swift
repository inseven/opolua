//
//  lua_State.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import Foundation

typealias LuaState = UnsafeMutablePointer<lua_State>

extension UnsafeMutablePointer where Pointee == lua_State {

    func todata(_ index: Int32) -> Data? {
        let L = self
        if lua_type(L, index) == LUA_TSTRING {
            var len: Int = 0
            let ptr = lua_tolstring(L, index, &len)!
            let buf = UnsafeBufferPointer(start: ptr, count: len)
            return Data(buffer: buf)
        } else {
            return nil
        }
    }

    func tostring(_ index: Int32, encoding: String.Encoding) -> String? {
        if let data = todata(index) {
            return String(data: data, encoding: encoding)
        } else {
            return nil
        }
    }

    func toint(_ index: Int32) -> Int? {
        let L = self
        var isnum: Int32 = 0
        let ret = lua_tointegerx(L, index, &isnum)
        if isnum == 0 {
            return nil
        } else {
            return Int(ret)
        }
    }

    func toint(_ index: Int32, key: String) -> Int? {
        let L = self
        let _ = lua_getfield(L, index, key)
        let result = toint(-1)
        pop()
        return result
    }

    func tostringarray(_ index: Int32, encoding: String.Encoding) -> [String] {
        let L = self
        var i: lua_Integer = 1
        var result: [String] = []
        while true {
            var str: String?
            if lua_rawgeti(L, index, i) == LUA_TSTRING {
                str = tostring(-1, encoding: encoding)
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

    func tostring(_ index: Int32, key: String, encoding: String.Encoding) -> String? {
        let L = self
        let t = lua_getfield(L, index, key)
        var result: String? = nil
        if t == LUA_TSTRING {
            result = tostring(-1, encoding: encoding)
        }
        pop()
        return result
    }

    func ipairs(_ index: Int32, _ closure: (lua_Integer) -> Void) {
        let L = self
        var i: lua_Integer = 1
        let top = lua_gettop(L)
        while true {
            if lua_rawgeti(L, index, i) == LUA_TNIL {
                lua_pop(L, 1)
                return
            }
            closure(i)
            i = i + 1
            lua_settop(L, top)
        }
    }

    func push(_ int: Int) {
        lua_pushinteger(self, lua_Integer(int))
    }

    func push(_ string: String, encoding: String.Encoding) {
        guard let data = string.data(using: encoding) else {
            assertionFailure("Cannot represent string in the given encoding?!")
            lua_pushnil(self)
            return
        }
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> Void in
            let chars = buf.bindMemory(to: CChar.self)
            lua_pushlstring(self, chars.baseAddress, chars.count)
        }
    }

    func pop(_ nitems: Int32 = 1) {
        lua_pop(self, nitems)
    }
}
