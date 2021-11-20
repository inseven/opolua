//
//  lua_State.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import Foundation

typealias LuaState = UnsafeMutablePointer<lua_State>

extension UnsafeMutablePointer where Pointee == lua_State {

    enum LuaType : Int32 {
        // Annoyingly can't use LUA_TNIL etc here because the bridge exposes them as `var LUA_TNIL: Int32 { get }`
        // which is not acceptable for an enum (which requires the rawValue to be a literal)
        case nilType = 0 // LUA_TNIL
        case boolean = 1 // LUA_TBOOLEAN
        case lightuserdata = 2 // LUA_TLIGHTUSERDATA
        case number = 3 // LUA_TNUMBER
        case string = 4 // LUA_STRING
        case table = 5 // LUA_TTABLE
        case function = 6 // LUA_TFUNCTION
        case userdata = 7 // LUA_TUSERDATA
        case thread = 8 // LUA_TTHREAD
    }

    // Empty Optional is used for LUA_TNONE ie not a valid index
    // (although this doesn't offer any additional validity checks against passing a nonsense index)
    func type(_ index: Int32) -> LuaType? {
        let t = lua_type(self, index)
        assert(t >= LUA_TNONE && t <= LUA_TTHREAD)
        return LuaType(rawValue: t)
    }

    func isnone(_ index: Int32) -> Bool {
        return type(index) == nil
    }

    func isnoneornil(_ index: Int32) -> Bool {
        if let t = type(index) {
            return t == .nilType
        } else {
            return true // ie is none
        }
    }

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

    func tonumber(_ index: Int32) -> Double? {
        let L = self
        var isnum: Int32 = 0
        let ret = lua_tonumberx(L, index, &isnum)
        if isnum == 0 {
            return nil
        } else {
            return ret
        }
    }

    func getfield<T>(_ index: Int32, key: String, _ accessor: (Int32) -> T?) -> T? {
        let _ = lua_getfield(self, index, key)
        let result = accessor(-1)
        pop()
        return result
    }

    // Convenience dict fns (assumes key is an ascii string)

    func toint(_ index: Int32, key: String) -> Int? {
        return getfield(index, key: key, self.toint)
    }

    func tonumber(_ index: Int32, key: String) -> Double? {
        return getfield(index, key: key, self.tonumber)
    }

    func tostring(_ index: Int32, key: String, encoding: String.Encoding) -> String? {
        return getfield(index, key: key, { tostring($0, encoding: encoding) })
    }

    // iterators

    private class IPairsIterator : Sequence, IteratorProtocol {
        let L: LuaState
        let index: Int32
        let top: Int32
        let requiredType: LuaState.LuaType?
        var i: lua_Integer
        init(_ L: LuaState, _ index: Int32, _ requiredType: LuaState.LuaType?) {
            precondition(requiredType != .nilType, "Cannot iterate with a required type of LUA_TNIL")
            precondition(L.type(index) == .table, "Cannot iterate something that isn't a table!")
            self.L = L
            self.index = index
            self.requiredType = requiredType
            top = lua_gettop(L)
            i = 0
        }
        func next() -> lua_Integer? {
            lua_settop(L, top)
            i = i + 1
            let t = lua_rawgeti(L, index, i)
            if let requiredType = self.requiredType {
                if t != requiredType.rawValue {
                    return nil
                }
            } else if t == LUA_TNIL {
                return nil
            }

            return i
        }
        deinit {
            lua_settop(L, top)
        }
    }

    // Return a for-iterator that iterates the integer keys in the table at the given index. Inside the loop block,
    // each element will on the top of the stack, ie access it using stack index -1.
    //
    // if requiredType is specified, iteration is halted once any value that
    // isn't of type requiredType is encountered. Eg for:
    // for i in L.ipairs(-1, requiredType: .number) { ... } { print(i, L.tonumber(-1)!) }
    // when the table at the top of the stack was { 11, 22, "whoops", 44 }
    // would result in:
    // --> 1 11
    // --> 2 22
    func ipairs(_ index: Int32, requiredType: LuaType? = nil) -> some Sequence {
        return IPairsIterator(self, index, requiredType)
    }

    private class PairsIterator : Sequence, IteratorProtocol {
        let L: LuaState
        let index: Int32
        let top: Int32
        init(_ L: LuaState, _ index: Int32) {
            self.L = L
            self.index = index
            top = lua_gettop(L)
            lua_pushnil(L) // initial k
        }
        func next() -> (Int32, Int32)? {
            lua_settop(L, top + 1) // Pop everything except k
            let t = lua_next(L, index)
            if t == 0 {
                // No more items
                return nil
            }
            return (top + 1, top + 2) // k and v indexes
        }
        deinit {
            lua_settop(L, top)
        }
    }

    // Returns a for iterator that iterates all keys in the table, in an unspecified order. Assuming value on top of
    // stack is a table { a = 1, b = 2, c = 3 } then the following code...
    //
    // for k, v in L.pairs(-1) {
    //     print(L.tostring(k, encoding: .utf8)!, L.toint(v)!)
    // }
    //
    // ...might output the following:
    // --> b 2
    // --> c 3
    // --> a 1
    func pairs(_ index: Int32) -> some Sequence {
        return PairsIterator(self, index)
    }

    func tostringarray(_ index: Int32, encoding: String.Encoding) -> [String]? {
        guard lua_type(self, index) == LUA_TTABLE else {
            return nil
        }
        var result: [String] = []
        for _ in ipairs(index) {
            if let val = tostring(-1, encoding: encoding) {
                result.append(val)
            } else {
                break
            }
        }
        return result
    }

    func push(_ int: Int) {
        lua_pushinteger(self, lua_Integer(int))
    }

    func push(_ int: lua_Integer) {
        lua_pushinteger(self, int)
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
