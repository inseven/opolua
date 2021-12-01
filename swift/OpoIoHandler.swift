// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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
        var value: String
        let alignment: Alignment? // For .text
        let min: Double? // For .long, .float, .time, .date
        let max: Double? // Ditto, plus .edit (meaning max number of characters)
        let choices: [String]? // For .choice
        let selectable: Bool
    }

    struct Button {
        enum Flag : Int, FlagEnum {
            case isCancelButton = 0x10000
            case noShortcutLabel = 0x100
            case bareShortcutKey = 0x200 // Ie just 'Q' instead of assume 'ctrl-Q'
        }
        static let FlagsKeyMask: Int = 0x300
        typealias Flags = Set<Flag>

        let key: Int
        let text: String
        let flags: Flags
    }

    struct Result {
        let result: Int
        let values: [String] // Must be same length as Dialog.items
    }

    let title: String
    var items: [Item]
    let buttons: [Button]
    let flags: Flags
}

struct Menu {
    struct Item {

        struct Flags: OptionSet {

            let rawValue: Int

            static let dimmed = Flags(rawValue: 0x1000)
            static let checkbox = Flags(rawValue: 0x800)
            static let optionStart = Flags(rawValue: 0x100) // plus checkbox
            static let optionMiddle = Flags(rawValue: 0x200) // plus checkbox
            static let optionEnd = Flags(rawValue: 0x300) // plus checkbox
            static let checked = Flags(rawValue: 0x2000) // for option or checkbox
            static let inteterminate = Flags(rawValue: 0x4000) // for option or checkbox
            static let separatorAfter = Flags(rawValue: 0x10000)
        }

        let text: String
        let keycode: Int
        let submenu: Menu?
        let flags: Flags
    }

    struct Bar {
        let menus: [Menu]
        let highlight: Int // What item should start highlighted
    }

    struct Result {

        static let none = Result(selected: 0, highlighted: 0)

        let selected: Int // Zero if menu cancelled, otherwise keycode of selected command
        let highlighted: Int // Index of highlighted item (even if cancelled)
    }

    let title: String
    let items: [Item]
}

struct Graphics {
    struct Size {
        let width: Int
        let height: Int
    }
    struct Point {
        let x: Int
        let y: Int
    }
    struct Rect {
        let origin: Point
        let size: Size
        var width: Int { return size.width }
        var height: Int { return size.height }
    }

    struct Color {
        let r: UInt8
        let g: UInt8
        let b: UInt8
    }

    struct PixelData {
        let size: Size
        let bpp: Int
        let stride: Int
        let data: Data
        // TODO colour depth and/or palette info also needed, in due course
    }

    struct CopySource {
        let displayId: Int
        let rect: Rect
        let extra: AnyObject?
    }

    struct Operation {
        enum OpType {
            case cls
            case circle(Int, Bool) // radius, fill
            case line(Int, Int) // x2, y2
            case bitblt(PixelData)
            case copy(CopySource)
        }
        let displayId: Int
        let type: OpType
        let origin: Point
        let color: Color
        let bgcolor: Color
    }
}

extension Graphics.Rect {
    init(x: Int, y: Int, width: Int, height: Int) {
        self.init(origin: Graphics.Point(x: x, y: y), size: Graphics.Size(width: width, height: height))
    }
}

struct Fs {
    struct Operation {
        enum OpType {
            case exists // return notFound or alreadyExists (any access issue should result in notFound)
            case delete // return none, notFound, notReady
            case mkdir // return none, alreadyExists, notReady
            case rmdir // return none, notFound, inUse if it isn't empty, notReady
            case write(Data) // return none, notReady
            case read // return none, notFound, accessDenied
        }
        let path: String
        let type: OpType
    }

    enum Err: Int {
        case none = 0
        case inUse = -9
        case notFound = -33
        case alreadyExists = -32
        case notReady = -62 // For any op outside our sandbox
        //case accessDenied = -39
    }

    enum Result {
        case err(Err)
        case data(Data)
    }
}

struct Async {
    enum RequestType {
        case getevent
        // This is going to seem like overkill if we never end up implementing any other events...
    }
    struct Request {
        let type: RequestType
        let requestHandle: Int32
    }
    struct KeyPressEvent {
        let timestamp: Int // Microseconds since boot, or something
        let keycode: Int
        let scancode: Int
        let modifiers: Int
        let isRepeat: Bool
    }
    struct KeyUpDownEvent {
        let timestamp: Int // Microseconds since boot, or something
        let scancode: Int
        let modifiers: Int
    }
    enum PenEventType: Int {
        case down = 0
        case up = 1
        case drag = 6
    }
    struct PenEvent {
        let timestamp: Int // Microseconds since boot, or something
        let windowId: Int
        let type: PenEventType
        let modifiers: Int
        let x: Int
        let y: Int
    }
    enum ResponseValue {
        case keypressevent(KeyPressEvent)
        case keydownevent(KeyUpDownEvent)
        case keyupevent(KeyUpDownEvent)
        case penevent(PenEvent)
    }
    struct Response {
        let type: RequestType
        let requestHandle: Int32
        let value: ResponseValue
    }
}

protocol OpoIoHandler {

    func printValue(_ val: String) -> Void

    // nil return means escape (must only return nil if escapeShouldErrorEmptyInput is true)
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String?

    // lines is 1-2 strings, buttons is 0-3 strings.
    // return should be 1, 2, or 3
    func alert(lines: [String], buttons: [String]) -> Int

    // return char code
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

    func draw(operations: [Graphics.Operation])

    func getScreenSize() -> Graphics.Size

    func fsop(_ op: Fs.Operation) -> Fs.Result

    func asyncRequest(_ request: Async.Request)
    func waitForAnyRequest() -> Async.Response

    func createBitmap(width: Int, height: Int) -> Int?
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

    func draw(operations: [Graphics.Operation]) {
    }

    func getScreenSize() -> Graphics.Size {
        return Graphics.Size(width: 640, height: 240)
    }

    func fsop(_ op: Fs.Operation) -> Fs.Result {
        return .err(.notReady)
    }

    func asyncRequest(_ request: Async.Request) {
    }

    func waitForAnyRequest() -> Async.Response {
        fatalError("No support for waitForAnyRequest in DummyIoHandler")
    }

    func createBitmap(width: Int, height: Int) -> Int? {
        return nil
    }

}
