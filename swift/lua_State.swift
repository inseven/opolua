// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

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
        if type(index) == .string {
            var len: Int = 0
            let ptr = lua_tolstring(L, index, &len)!
            let buf = UnsafeBufferPointer(start: ptr, count: len)
            return Data(buffer: buf)
        } else {
            return nil
        }
    }

    // If convert is true, any value that is not a string will be converted to
    // one (invoking __tostring metamethods if necessary)
    func tostring(_ index: Int32, encoding: String.Encoding, convert: Bool = false) -> String? {
        if let data = todata(index) {
           return String(data: data, encoding: encoding)
        } else if convert {
            var len: Int = 0
            let ptr = luaL_tolstring(self, index, &len)!
            let buf = UnsafeBufferPointer(start: ptr, count: len)
            let result = String(data: Data(buffer: buf), encoding: encoding)
            pop() // the val from luaL_tolstring
            return result
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

    func toboolean(_ index: Int32) -> Bool {
        let b = lua_toboolean(self, index)
        return b != 0
    }

    func tostringarray(_ index: Int32, encoding: String.Encoding, convert: Bool = false) -> [String]? {
        guard type(index) == .table else {
            return nil
        }
        var result: [String] = []
        for _ in ipairs(index) {
            if let val = tostring(-1, encoding: encoding, convert: convert) {
                result.append(val)
            } else {
                break
            }
        }
        return result
    }

    func getfield<T>(_ index: Int32, key: String, _ accessor: (Int32) -> T?) -> T? {
        let _ = lua_getfield(self, index, key)
        let result = accessor(-1)
        pop()
        return result
    }

    func setfuncs(_ fns: [(String, lua_CFunction)], nup: Int32) {
        // It's easier to just do what luaL_setfuncs does rather than massage
        // fns in to a format that would work with it
        for (name, fn) in fns {
            for _ in 0 ..< nup {
                // copy upvalues to the top
                lua_pushvalue(self, -nup)
            }
            lua_pushcclosure(self, fn, nup)
            lua_setfield(self, -(nup + 2), name)
        }
        pop(nup)
    }

    // Convenience dict fns (assumes key is an ascii string)

    func toint(_ index: Int32, key: String) -> Int? {
        return getfield(index, key: key, self.toint)
    }

    func tonumber(_ index: Int32, key: String) -> Double? {
        return getfield(index, key: key, self.tonumber)
    }

    func toboolean(_ index: Int32, key: String) -> Bool {
        return getfield(index, key: key, self.toboolean) ?? false
    }

    func todata(_ index: Int32, key: String) -> Data? {
        return getfield(index, key: key, self.todata)
    }

    func tostring(_ index: Int32, key: String, encoding: String.Encoding, convert: Bool = false) -> String? {
        return getfield(index, key: key, { tostring($0, encoding: encoding, convert: convert) })
    }

    func tostringarray(_ index: Int32, key: String, encoding: String.Encoding, convert: Bool = false) -> [String]? {
        return getfield(index, key: key, { tostringarray($0, encoding: encoding, convert: convert) })
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

    func push(_ bool: Bool) {
        lua_pushboolean(self, bool ? 1 : 0)
    }

    func push(_ int: Int) {
        lua_pushinteger(self, lua_Integer(int))
    }

    func push(_ int: lua_Integer) {
        lua_pushinteger(self, int)
    }

    func push(_ double: Double) {
        lua_pushnumber(self, double)
    }

    func push(_ string: String, encoding: String.Encoding) {
        guard let data = string.data(using: encoding) else {
            assertionFailure("Cannot represent string in the given encoding?!")
            pushnil()
            return
        }
        push(data)
    }

    func push(_ data: Data) {
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> Void in
            let chars = buf.bindMemory(to: CChar.self)
            lua_pushlstring(self, chars.baseAddress, chars.count)
        }
    }

    func pushnil() {
        lua_pushnil(self)
    }

    func pop(_ nitems: Int32 = 1) {
        lua_pop(self, nitems)
    }
}
