// Copyright (c) 2022 Jason Morley, Tom Sutcliffe
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

let L = luaL_newstate()!
L.setStringEncoding(.utf8)

func testBasic() {
    defer { lua_settop(L, 0) }
    struct Basic: Codable, Equatable {
        let int: Int
        let str: String
        let bool: Bool
        let arr: [Int]
    }

    let expected = Basic(int: 1234, str: "abc", bool: true, arr: [1,2,3])
    lua_newtable(L)
    L.setfield("int", expected.int)
    L.setfield("str", expected.str)
    L.setfield("bool", expected.bool)
    L.setfield("arr", expected.arr)

    let decoded = L.tovalue(-1, Basic.self)!
    assert(decoded == expected)
    assert(lua_gettop(L) == 1)
}

func testArray() {
    defer { lua_settop(L, 0) }
    let expected = [ "aa", "b", "ccc" ]
    L.push(expected)
    let decoded = L.tovalue(-1, [String].self)!
    assert(decoded == expected)

    let decodedOpt = L.tovalue(-1, [String?].self)!
    assert(decodedOpt == expected)
}

func testCond() {
    defer { lua_settop(L, 0) }
    struct Cond: Codable, Equatable {
        let maybe: String?
    }
    let yarp = Cond(maybe: "yarp")
    lua_newtable(L)
    L.setfield("maybe", "yarp")
    var decoded = L.tovalue(-1, Cond.self)!
    assert(decoded == yarp)

    let narp = Cond(maybe: nil)
    lua_newtable(L)
    decoded = L.tovalue(-1, Cond.self)!
    assert(decoded == narp)
}

func testLim() {
    defer { lua_settop(L, 0) }
    struct Smol: Codable, Equatable {
        let int: Int8
    }
    lua_newtable(L)
    L.setfield("int", 1234)
    assert(L.tovalue(-1, Smol.self) == nil)

    var err: Error? = nil
    do {
        let _ = try LuaDecoder(state: L, stringEncoding: .utf8, index: -1).decode(Smol.self)
    } catch {
        err = error
    }
    assert(err is DecodingError)
}

func testDict() {
    defer { lua_settop(L, 0) }
    lua_newtable(L)
    let expected = ["aa": 11, "b": 2, "cccc": 33]
    L.push(expected)
    let decoded = L.tovalue(-1, [String: Int].self)
    assert(decoded == expected)
}

func testDrawable() {
    defer { lua_settop(L, 0) }
    struct DrawableId: Hashable, Codable {
        let value: Int
        init(value: Int) {
            self.value = value
        }
        init(from decoder: Decoder) throws {
            self.value = try decoder.singleValueContainer().decode(Int.self)
        }
    }
    let expected = DrawableId(value: 13)
    L.push(expected.value)
    let decoded = L.tovalue(-1, DrawableId.self)!
    assert(decoded == expected)
}

func testFlags() {
    defer { lua_settop(L, 0) }
    enum Fleg: Int, FlagEnum {
        case a = 1
        case b = 2
        case c = 4
    }
    typealias Flegs = FlagSet<Fleg>
    let expected = Flegs(rawValue: 6)
    assert(expected.contains(.b))
    assert(!expected.contains(.a))
    L.push(expected.rawValue)
    let decoded = L.tovalue(-1, Flegs.self)!
    assert(decoded == expected)
}

testBasic()
testArray()
testCond()
testLim()
testDict()
testDrawable()
testFlags()
