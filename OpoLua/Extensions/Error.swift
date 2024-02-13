// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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

extension Error {

    private static func description(details: String) -> String {
        return "## Description\n\n_Please provide details of the program you were running, and what you were doing when you encountered the error._\n\n## Details\n\n```\n\(details)\n```"
    }

    var gitHubIssueUrl: URL? {
        if let _ = self as? OpoInterpreter.BinaryDatabaseError {
            return nil
        } else if let _ = self as? OpoInterpreter.LeaveError {
            return nil
        } else if let _ = self as? OpoInterpreter.NativeBinaryError {
            return nil
        } else if let unimplementedOperation = self as? OpoInterpreter.UnimplementedOperationError {
            return URL.gitHubIssue(title: "Unimplemented Operation: \(unimplementedOperation.operation)",
                                   description: Self.description(details: unimplementedOperation.detail),
                                   labels: ["facerake", "bug"])
        } else if let interpreterError = self as? OpoInterpreter.InterpreterError {
            return URL.gitHubIssue(title: "Internal Error: \(interpreterError.message)",
                                   description: Self.description(details: interpreterError.detail),
                                   labels: ["internal-error", "bug"])
        }
        return nil
    }

}
