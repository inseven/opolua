// Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe
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
import CoreGraphics

enum OpoLuaError: Error {

    case fileExists
    case locationExists
    case secureAccess
    case unsupportedFile
    case exceededMaximumDirectoryCount
    case cancelled

}

extension OpoLuaError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .fileExists:
            return "File already exists."
        case .locationExists:
            return "Location already exists."
        case .secureAccess:
            return "Failed to prepare file for secure access."
        case .unsupportedFile:
            return "Unsupported file."
        case .exceededMaximumDirectoryCount:
            return "Exceeded the maximum number of directories; disabling monitoring."
        case .cancelled:
            return "Cancelled."
        }
    }

}
