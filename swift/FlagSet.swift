// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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

protocol FlagEnum: RawRepresentable, Hashable, CaseIterable {}

// In theory inheriting RawRepresentable should get Codable support for free,
// but I cannot get it to work :-(
struct FlagSet<T>: Equatable, Codable where T: FlagEnum, T.RawValue: Codable & BinaryInteger {

    var rawValue: T.RawValue

    init() {
        self.rawValue = 0
    }

    init(rawValue: T.RawValue) {
        self.rawValue = rawValue
    }

    init(_ set: Set<T>) {
        var val: T.RawValue = 0
        for flag in set {
            val = val | flag.rawValue
        }
        self.rawValue = val
    }

    func set() -> Set<T> {
        var result = Set<T>()
        for caseVal in T.allCases {
            if self.contains(caseVal) {
                result.insert(caseVal)
            }
        }
        return result
    }

    func contains(_ flag: T) -> Bool {
        return (rawValue & flag.rawValue) == flag.rawValue
    }

    mutating func insert(_ flag: T) {
        rawValue = rawValue | flag.rawValue
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(T.RawValue.self)
        self.init(rawValue: value)
    }

    func encode(to encoder: Encoder) throws {
        var cont = encoder.singleValueContainer()
        try cont.encode(self.rawValue)
    }

}
