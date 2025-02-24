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

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

protocol SettingsObserver: NSObject {

    func settings(_ settings: Settings, didAddIndexableUrl indexableUrl: URL)
    func settings(_ settings: Settings, didRemoveIndexableUrl indexableUrl: URL)
    
}

class Settings: ObservableObject {

    enum ClockType: String {
        case analog
        case digital
    }

    enum Theme: Int, CaseIterable, Identifiable {

        var id: Self { self }

        case series5 = 0
        case series7 = 1
    }

    private enum Key: String {
        case theme = "Theme"
        case showWallpaper = "ShowWallpaper"
        case showWallpaperInDarkMode = "ShowWallpaperInDarkMode"
        case locations = "Locations"
        case clockType = "Clock"
        case showLibraryFiles = "ShowLibraryFiles"
        case showLibraryScripts = "ShowLibraryScripts"
        case showLibraryTests = "ShowLibraryTests"
        case alwaysShowErrorDetails = "AlwaysShowErrorDetails"
    }

    private let userDefaults = UserDefaults()
    private var observers: [SettingsObserver] = []

    private var _theme = Theme.series7

    private var _showWallpaper = true
    private var _showWallpaperInDarkMode = false

    private var _showLibraryFiles = true
    private var _showLibraryScripts = true
    private var _showLibraryTests = false

    private var _locations: [SecureLocation] = []

    var locations: [URL] {
        get {
            return _locations.map { $0.url }
        }
    }

    init() {
        do {
            _locations = try secureLocations(for: .locations)
        } catch {
            print("Failed to load locations with error \(error).")
        }

        _theme = Theme.init(rawValue: self.integer(for: .theme, default: _theme.rawValue)) ?? _theme

        _showWallpaper = self.bool(for: .showWallpaper, default: _showWallpaper)
        _showWallpaperInDarkMode = self.bool(for: .showWallpaperInDarkMode, default: _showWallpaperInDarkMode)

        _showLibraryFiles = self.bool(for: .showLibraryFiles, default: _showLibraryFiles)
        _showLibraryScripts = self.bool(for: .showLibraryScripts, default: _showLibraryScripts)
        _showLibraryTests = self.bool(for: .showLibraryTests, default: _showLibraryTests)
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

    func addObserver(_ observer: SettingsObserver) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.observers.append(observer)
    }

    func removeObserver(_ observer: SettingsObserver) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.observers.removeAll { $0.isEqual(observer) }
    }

    func addLocation(_ url: URL) throws {
        dispatchPrecondition(condition: .onQueue(.main))

        // Ensure the location is unique.
        guard !_locations.contains(where: { $0.url == url }) else {
            throw OpoLuaError.locationExists
        }

        _locations.append(try SecureLocation(url: url))
        try set(secureLocations: _locations, for: .locations)

        self.objectWillChange.send()
        for observer in self.observers {
            observer.settings(self, didAddIndexableUrl: url)
        }
    }

    func removeLocation(_ url: URL) throws {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let location = _locations.first(where: { $0.url == url }) else {
            return
        }

        try location.cleanup()
        _locations.removeAll { $0.url == location.url }
        try set(secureLocations: _locations, for: .locations)

        self.objectWillChange.send()
        for observer in self.observers {
            observer.settings(self, didRemoveIndexableUrl: location.url)
        }
    }

    var theme: Settings.Theme {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _theme
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            guard _theme != newValue else {
                return
            }
            _theme = newValue
            self.set(_theme.rawValue, for: .theme)
            self.objectWillChange.send()
        }
    }

    var showWallpaper: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _showWallpaper
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            guard _showWallpaper != newValue else {
                return
            }
            _showWallpaper = newValue
            self.set(_showWallpaper, for: .showWallpaper)
            self.objectWillChange.send()
        }
    }

    var showWallpaperInDarkMode: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _showWallpaperInDarkMode
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            guard _showWallpaperInDarkMode != newValue else {
                return
            }
            _showWallpaperInDarkMode = newValue
            self.set(_showWallpaperInDarkMode, for: .showWallpaperInDarkMode)
            self.objectWillChange.send()
        }
    }

#if canImport(UIKit)
    func showWallpaper(in userInterfaceStyle: UIUserInterfaceStyle) -> Bool {
        switch userInterfaceStyle {
        case .light:
            return showWallpaper
        case .dark:
            return showWallpaper && showWallpaperInDarkMode
        default:
            return false
        }
    }
#endif

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
            dispatchPrecondition(condition: .onQueue(.main))
            return _showLibraryFiles
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            guard _showLibraryFiles != newValue else {
                return
            }
            _showLibraryFiles = newValue
            self.set(_showLibraryFiles, for: .showLibraryFiles)
            self.objectWillChange.send()
            for observer in observers {
                if _showLibraryFiles {
                    observer.settings(self, didAddIndexableUrl: Bundle.main.filesUrl)
                } else {
                    observer.settings(self, didRemoveIndexableUrl: Bundle.main.filesUrl)
                }
            }
        }
    }

    var showLibraryScripts: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _showLibraryScripts
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            guard _showLibraryScripts != newValue else {
                return
            }
            _showLibraryScripts = newValue
            self.set(_showLibraryScripts, for: .showLibraryScripts)
            self.objectWillChange.send()
            for observer in observers {
                if _showLibraryScripts {
                    observer.settings(self, didAddIndexableUrl: Bundle.main.scriptsUrl)
                } else {
                    observer.settings(self, didRemoveIndexableUrl: Bundle.main.scriptsUrl)
                }
            }
        }
    }

    var showLibraryTests: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _showLibraryTests
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            guard _showLibraryTests != newValue else {
                return
            }
            _showLibraryTests = newValue
            self.set(_showLibraryTests, for: .showLibraryTests)
            self.objectWillChange.send()
            for observer in observers {
                if _showLibraryTests {
                    observer.settings(self, didAddIndexableUrl: Bundle.main.testsUrl)
                } else {
                    observer.settings(self, didRemoveIndexableUrl: Bundle.main.testsUrl)
                }
            }
        }
    }

    var alwaysShowErrorDetails: Bool {
        get {
            return self.bool(for: .alwaysShowErrorDetails, default: false)
        }
        set {
            self.set(newValue, for: .alwaysShowErrorDetails)
            self.objectWillChange.send()
        }
    }

    var indexableUrls: [URL] {
        dispatchPrecondition(condition: .onQueue(.main))
        var indexableUrls: [URL] = []
        indexableUrls.append(FileManager.default.documentsUrl)
        if self.showLibraryFiles {
            indexableUrls.append(Bundle.main.filesUrl)
        }
        if self.showLibraryScripts {
            indexableUrls.append(Bundle.main.scriptsUrl)
        }
        if self.showLibraryTests {
            indexableUrls.append(Bundle.main.testsUrl)
        }
        for location in self._locations {
            indexableUrls.append(location.url)
        }
        return indexableUrls
    }

}

extension Settings.Theme {

#if canImport(UIKit)
    var color: UIColor {
        switch self {
        case .series5:
            return .series5
        case .series7:
            return .series7
        }
    }
#endif

    var wallpaper: CommonImage {
        switch self {
        case .series5:
            return .epocLogo()
        case .series7:
            return .epocLogoC()
        }
    }

}
