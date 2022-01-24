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

import Foundation
import SwiftUI
import UIKit

class Settings: ObservableObject {

    enum ClockType: String {
        case analog
        case digital
    }

    private enum Key: String {
        case theme = "Theme"
        case showWallpaper = "ShowWallpaper"
        case locations = "Locations"
        case clockType = "Clock"
        case showLibraryFiles = "ShowLibraryFiles"
        case showLibraryScripts = "ShowLibraryScripts"
        case showLibraryTests = "ShowLibraryTests"
    }

    let userDefaults = UserDefaults()

    // TODO: Should be immutable.
    var locations: [SecureLocation] = []

    enum Theme: Int, CaseIterable, Identifiable {

        var id: Self { self }

        case series5 = 0
        case series7 = 1
    }

    init() {
        do {
            locations = try secureLocations(for: .locations)
        } catch {
            print("Failed to load locations with error \(error).")
        }
    }

    private func object(for key: Key) -> Any? {
        return self.userDefaults.object(forKey: key.rawValue)
    }

    private func array(for key: Key) -> [Any]? {
        return self.userDefaults.array(forKey: key.rawValue)
    }

    private func integer(for key: Key, default defaultValue: Int = 0) -> Int {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let value = self.userDefaults.object(forKey: key.rawValue) as? Int else {
            return defaultValue
        }
        return value
    }

    private func bool(for key: Key, default defaultValue: Bool = false) -> Bool {
        guard let value = self.userDefaults.object(forKey: key.rawValue) as? Bool else {
            return defaultValue
        }
        return value
    }

    private func string(for key: Key) -> String? {
        return self.userDefaults.string(forKey: key.rawValue)
    }

    private func secureLocations(for key: Key) throws -> [SecureLocation] {
        guard let urls = array(for: key) as? [Data] else {
            print("Failed to load security scoped URLs for '\(key)'.")
            return []
        }
        return try urls.map { try SecureLocation(data: $0) }
    }

    private func set(_ value: Any?, for key: Key) {
        self.userDefaults.set(value, forKey: key.rawValue)
    }

    private func set(_ value: Int, for key: Key) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.userDefaults.set(value, forKey: key.rawValue)
        self.objectWillChange.send()
    }

    private func set(_ value: Bool, for key: Key) {
        self.userDefaults.set(value, forKey: key.rawValue)
    }

    private func set(secureLocations: [SecureLocation], for key: Key) throws {
        let bookmarks = try secureLocations.map { try $0.dataRepresentation() }
        self.set(bookmarks, for: key)
    }

    func addLocation(_ url: URL) throws {
        locations.append(try SecureLocation(url: url))
        try set(secureLocations: locations, for: .locations)
        self.objectWillChange.send()
    }

    func removeLocation(_ location: SecureLocation) throws {
        try location.cleanup()
        locations.removeAll { $0.url == location.url }
        try set(secureLocations: locations, for: .locations)
        self.objectWillChange.send()
    }

    var theme: Settings.Theme {
        get {
            return Theme.init(rawValue: self.integer(for: .theme, default: Theme.series7.rawValue)) ?? .series7
        }
        set {
            self.set(newValue.rawValue, for: .theme)
            self.objectWillChange.send()
        }
    }

    var showWallpaper: Bool {
        get {
            return self.bool(for: .showWallpaper, default: true)
        }
        set {
            self.set(newValue, for: .showWallpaper)
            self.objectWillChange.send()
        }
    }

    var clockType: ClockType {
        get {
            return ClockType.init(rawValue: self.string(for: .clockType) ?? ClockType.analog.rawValue) ?? .analog
        }
        set {
            self.set(newValue.rawValue, for: .clockType)
            self.objectWillChange.send()
        }
    }

    var showLibraryFiles: Bool {
        get {
            return self.bool(for: .showLibraryFiles, default: true)
        }
        set {
            self.set(newValue, for: .showLibraryFiles)
            self.objectWillChange.send()
        }
    }

    var showLibraryScripts: Bool {
        get {
            return self.bool(for: .showLibraryScripts, default: true)
        }
        set {
            self.set(newValue, for: .showLibraryScripts)
            self.objectWillChange.send()
        }
    }

    var showLibraryTests: Bool {
        get {
            return self.bool(for: .showLibraryTests, default: false)
        }
        set {
            self.set(newValue, for: .showLibraryTests)
            self.objectWillChange.send()
        }
    }

}

extension Settings.Theme {

    var color: UIColor {
        switch self {
        case .series5:
            return .series5
        case .series7:
            return .series7
        }
    }

    var wallpaper: UIImage {
        switch self {
        case .series5:
            return .epocLogo
        case .series7:
            return .epocLogoC
        }
    }

}
