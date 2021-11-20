//
//  OpoIoHandler.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 18/11/2021.
//

import Foundation

class DialogItem {
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
    var value: String
    let alignment: Alignment? // For .text
    let min: Double? // For .long, .float, .time, .date
    let max: Double? // Ditto, plus .edit (meaning max number of characters)
    let choices: [String]? // For .choice

    init(type: ItemType, prompt: String, value: String, alignment: Alignment? = nil, min: Double? = nil, max: Double? = nil, choices: [String]? = nil) {
        self.type = type
        self.prompt = prompt
        self.value = value
        self.alignment = alignment
        self.min = min
        self.max = max
        self.choices = choices
    }
}

struct DialogButton {
    let key: Int
    let text: String
}

class Dialog {
    struct Flags: OptionSet {
        let rawValue: Int
        // Values as defined by dINIT() API 
        static let buttonsOnRight = Flags(rawValue: 1)
        static let noTitleBar = Flags(rawValue: 2)
        static let fullscreen = Flags(rawValue: 4)
        static let noDrag = Flags(rawValue: 8)
        static let packDense = Flags(rawValue: 16)
    }

    let title: String
    let items: [DialogItem]
    let buttons: [DialogButton]
    let flags: Flags

    init(title: String, items: [DialogItem], buttons: [DialogButton], flags: Flags) {
        self.title = title
        self.items = items
        self.buttons = buttons
        self.flags = flags
    }
}

struct Menu {
    struct Command {
        let text: String
        let keycode: Int
    }
    struct Card {
        let title: String
        let items: [Command]
    }
    struct Result {
        let selected: Int // Zero if menu cancelled, otherwise keycode of selected command
        let highlighted: Int // Index of highlighted item (even if cancelled)
    }
    let items: [Card]
    let highlight: Int // What item should start highlighted
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

    // return 0 means cancelled (eg escape pressed)
    // If there's buttons, non-zero return is the key of the
    // selected button.
    // If there aren't any buttons, the return value should be the 1-based index
    // of the line that was highlighted when the dialog was dismissed
    func dialog(_ d: Dialog) -> Int

    func menu(_ m: Menu) -> Menu.Result

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

    func dialog(_ d: Dialog) -> Int {
        return 0
    }

    func menu(_ m: Menu) -> Menu.Result {
        return Menu.Result(selected: 0, highlighted: 0)
    }
}
