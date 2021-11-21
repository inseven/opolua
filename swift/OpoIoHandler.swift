//
//  OpoIoHandler.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 18/11/2021.
//

import Foundation

protocol FlagEnum: RawRepresentable, Hashable, CaseIterable {}

extension Set where Element: FlagEnum, Element.RawValue : FixedWidthInteger {
    init(flags: Element.RawValue) {
        self.init()
        for caseVal in Element.allCases {
            if (flags & caseVal.rawValue) == caseVal.rawValue {
                insert(caseVal)
            }
        }
    }
}

struct Dialog {
    enum Flag : Int, FlagEnum {
        // Values as defined by dINIT() API 
        case buttonsOnRight = 1
        case noTitleBar = 2
        case fullscreen = 4
        case noDrag = 8
        case packDense = 16
    }
    typealias Flags = Set<Flag>

    struct Item {
        enum ItemType: Int {
            case text = 0
            case choice = 1
            case long = 2
            case float = 3
            case time = 4
            case date = 5
            case edit = 6
            case xinput = 8
            case checkbox = 12
            case separator = 13 // OPL uses empty dTEXT with the Text Separator flag set for this but we will make it distinct
        }
        enum Alignment: String {
            case left = "left"
            case center = "center"
            case right = "right"
        }
        let type: ItemType
        let prompt: String
        let value: String
        let alignment: Alignment? // For .text
        let min: Double? // For .long, .float, .time, .date
        let max: Double? // Ditto, plus .edit (meaning max number of characters)
        let choices: [String]? // For .choice
    }

    struct Button {
        let key: Int
        let text: String
    }

    struct Result {
        let result: Int
        let values: [String] // Must be same length as Dialog.items
    }

    let title: String
    let items: [Item]
    let buttons: [Button]
    let flags: Flags
}

struct Menu {
    struct Item {
        enum Flags : Int {
            case dimmed = 0x1000
            case checkbox = 0x800
            case optionStart = 0x100 // plus checkbox
            case optionMiddle = 0x200 // plus checkbox
            case optionEnd = 0x300 // plus checkbox
            case checked = 0x2000 // for option or checkbox
            case inteterminate = 0x4000 // for option or checkbox
            case separatorAfter = 0x10000
        }
        let text: String
        let keycode: Int
        let submenu: Menu?
        let flags: Int // Bitmask of Flags, OptionsSet is clunky
    }

    struct Bar {
        let menus: [Menu]
        let highlight: Int // What item should start highlighted
    }

    struct Result {
        let selected: Int // Zero if menu cancelled, otherwise keycode of selected command
        let highlighted: Int // Index of highlighted item (even if cancelled)
    }

    let title: String
    let items: [Item]
}

protocol OpoIoHandler {

    func printValue(_ val: String) -> Void

    // nil return means escape (must only return nil if escapeShouldErrorEmptyInput is true)
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String?

    // lines is 1-2 strings, buttons is 0-3 strings.
    // return should be 1, 2, or 3
    func alert(lines: [String], buttons: [String]) -> Int

    // return char code (should probably be in ER5 charset...)
    func getch() -> Int

    func beep(frequency: Double, duration: Double) -> Void

    // Meaning of the return value:
    //
    // result 0 means cancelled (eg escape pressed)
    // If there's buttons, non-zero result is the key of the
    // selected button.
    // If there aren't any buttons, result should be the 1-based index
    // of the line that was highlighted when the dialog was dismissed.
    //
    // values must have the same number of elements as d.items, and should
    // contain the final results of any editable fields.
    func dialog(_ d: Dialog) -> Dialog.Result

    func menu(_ m: Menu.Bar) -> Menu.Result

}

class DummyIoHandler : OpoIoHandler {

    func printValue(_ val: String) -> Void {
        print(val, terminator: "")
    }

    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? {
        return "123"
    }

    func alert(lines: [String], buttons: [String]) -> Int {
        return 1
    }

    func getch() -> Int {
        return 0
    }

    func beep(frequency: Double, duration: Double) -> Void {
        print("BEEP \(frequency)kHz \(duration)s")
    }

    func dialog(_ d: Dialog) -> Dialog.Result {
        return Dialog.Result(result: 0, values: [])
    }

    func menu(_ m: Menu.Bar) -> Menu.Result {
        return Menu.Result(selected: 0, highlighted: 0)
    }
}
