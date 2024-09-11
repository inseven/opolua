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

import Diligence

public struct Legal {

    public static let contents = Contents(repository: "inseven/opolua",
                                          copyright: "Copyright © 2021-2024\nJason Morley, Tom Sutcliffe") {
        let subject = "OpoLua Support (\(Bundle.main.version ?? "Unknown Version"))"
        Action("Website", url: URL(string: "https://opolua.org")!)
        Action("Privacy Policy", url: URL(string: "https://opolua.org/privacy-policy")!)
        Action("GitHub", url: URL(string: "https://github.com/inseven/opolua")!)
        Action("Support", url: URL(address: "support@opolua.org", subject: subject)!)
    } acknowledgements: {
        Acknowledgements("Developers") {
            Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk/about"))
            Credit("Tom Sutcliffe", url: URL(string: "https://github.com/tomsci"))
        }
        Acknowledgements("Thanks") {
            Credit("Lukas Fittl")
            Credit("Sara Frederixon")
            Credit("Sarah Barbour")
            Credit("Shawn Leedy")
        }
    } licenses: {
        License(name: "Lua", author: "Lua.org, PUC-Rio", filename: "Lua.txt")
        License(name: "OpoLua", author: "Jason Morley, Tom Sutcliffe", filename: "License.txt")
    }

}
