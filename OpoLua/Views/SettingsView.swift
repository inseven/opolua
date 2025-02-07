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

import SwiftUI

import Diligence

struct SettingsView: View {

    enum SheetType: Identifiable {

        var id: Self { self }

        case about
    }

    @Environment(\.dismiss) private var dismiss

    @ObservedObject var settings: Settings

    @State var sheet: SheetType?

    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        Text("Series 5").tag(Settings.Theme.series5)
                        Text("Series 7").tag(Settings.Theme.series7)
                    }
                    Picker("Clock", selection: $settings.clockType) {
                        Text("Analog").tag(Settings.ClockType.analog)
                        Text("Digital").tag(Settings.ClockType.digital)
                    }
                }
                Section("Wallpaper") {
                    Toggle("Show Wallpaper", isOn: $settings.showWallpaper)
                    if settings.showWallpaper {
                        Toggle("Show in Dark Mode", isOn: $settings.showWallpaperInDarkMode)
                    }
                }
                Section("Examples") {
                    Toggle("Show Files", isOn: $settings.showLibraryFiles)
                    Toggle("Show Scripts", isOn: $settings.showLibraryScripts)
                    Toggle("Show Tests", isOn: $settings.showLibraryTests)
                }
#if DEBUG
                Section("Debug") {
                    Toggle("Always Show Error Details", isOn: $settings.alwaysShowErrorDetails)
                }
#endif
#if !targetEnvironment(macCatalyst)
                Section {
                    Button("About \(Bundle.main.displayName!)...") {
                        sheet = .about
                    }
                    .foregroundColor(.primary)
                }
#endif
            }
            .tint(Color(uiColor: settings.theme.color))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .about:
                    AboutView(Legal.contents)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

}
