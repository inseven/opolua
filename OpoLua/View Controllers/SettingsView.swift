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

struct SettingsView: View {

    enum SheetType: Identifiable {

        var id: Self { self }

        case about
    }

    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var settings: Settings

    @State var sheet: SheetType?

    func themeBinding(value: Settings.Theme) -> Binding<Bool> {
        return Binding {
            return settings.theme == value
        } set: { newState in
            if newState {
                settings.theme = value
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Theme") {
                    ForEach(Settings.Theme.allCases) { theme in
                        Toggle(isOn: themeBinding(value: theme)) {
                            Text(theme.localizedDescription)
                        }
                        .toggleStyle(ColoredCheckbox(color: Color(uiColor: theme.color)))
                    }
                }
                Section {
                    Button("About \(UIApplication.shared.displayName!)...") {
                        sheet = .about
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Done")
                    .bold()
            })
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .about:
                    AboutView()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

}