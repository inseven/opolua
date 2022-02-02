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

extension LuaState {

    // MUST call this before calling any func that assumes a string encoding
    func setStringEncoding(_ encoding: String.Encoding) {
        let val = Int64(encoding.rawValue)
        lua_getextraspace(self).storeBytes(of: val, as: Int64.self)
    }

    func getStringEncoding() -> String.Encoding {
        return String.Encoding(rawValue: UInt(lua_getextraspace(self).load(as: Int64.self)))
    }

    func tostring(_ index: Int32, convert: Bool = false) -> String? {
        return tostring(index, encoding: getStringEncoding(), convert: convert)
    }

    func tostringarray(_ index: Int32) -> [String]? {
        return tostringarray(index, encoding: getStringEncoding())
    }

    func tostring(_ index: Int32, key: String, convert: Bool = false) -> String? {
        return tostring(index, key: key, encoding: getStringEncoding(), convert: convert)
    }

    func tostringarray(_ index: Int32, key: String, convert: Bool = false) -> [String]? {
        return tostringarray(index, key: key, encoding: getStringEncoding(), convert: convert)
    }

}
