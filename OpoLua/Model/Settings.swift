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

class Settings {

    private enum Key: String {
        case theme
    }

    let userDefaults = UserDefaults()

    let locationsKey = "Locations"

    // TODO: Should be immutable.
    var locations: [ExternalLocation]

    enum Theme: Int, CaseIterable, Identifiable {

        var id: Self { self }

        case series5 = 0
        case series7 = 1
    }

    init() {
        do {
            locations = try userDefaults.secureLocations(forKey: locationsKey)
        } catch {
            print("Failed to load locations with error \(error).")
            locations = []
        }
    }

    private func integer(for key: Key) -> Int {
        return self.userDefaults.integer(forKey: key.rawValue)
    }

    private func set(_ value: Int, for key: Key) {
        self.userDefaults.set(value, forKey: key.rawValue)
    }

    func addLocation(_ url: URL) throws {
        locations.append(try ExternalLocation(url: url))
        try userDefaults.set(secureLocations: locations, forKey: locationsKey)
    }

    func removeLocation(_ location: ExternalLocation) throws {
        try location.cleanup()
        locations.removeAll { $0.url == location.url }
        try userDefaults.set(secureLocations: locations, forKey: locationsKey)
    }

    var theme: Settings.Theme {
        get {
            Theme.init(rawValue: self.integer(for: .theme))!
        }
        set {
            self.set(newValue.rawValue, for: .theme)
        }
    }

}

extension Settings.Theme {

    var localizedDescription: String {
        switch self {
        case .series5:
            return "Series 5"
        case .series7:
            return "Series 7"
        }
    }

    var color: UIColor {
        switch self {
        case .series5:
            return UIColor(named: "Series5Color")!
        case .series7:
            return UIColor(named: "Series7Color")!
        }
    }

}
