// Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe
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

import SwiftUI

import Diligence

struct AboutView: View {

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                HeaderSection {
                    Diligence.Icon("Icon")
                    ApplicationNameTitle()
                }
                BuildSection("inseven/opolua")
                Section {
                    Link("InSeven Limited", url: URL(string: "https://inseven.co.uk")!)
                    Link("Privacy Policy", url: URL(string: "https://opolua.org/privacy-policy")!)
                    Link("GitHub", url: URL(string: "https://github.com/inseven/opolua")!)
                    Link("Support", url: URL(address: "support@opolua.org", subject: "OpoLua Support")!)
                }
                CreditSection("Developers", [
                    Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk")),
                    Credit("Tom Sutcliffe", url: URL(string: "https://github.com/tomsci")),
                ])
                CreditSection("Thanks", [
                    "Sara Frederixon",
                    "Sarah Barbour",
                    "Shawn Leedy",
                ])
                LicenseSection("Licenses", [
                    License(name: "Diligence", author: "InSeven Limited", filename: "Diligence.txt"),
                    License(name: "Lua", author: "Lua.org, PUC-Rio", filename: "Lua.txt"),
                    License(name: "OpoLua", author: "Jason Morley, Tom Sutcliffe", filename: "License.txt"),
                ])
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Done")
                    .bold()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
