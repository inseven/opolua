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

struct Graphics {

    struct Size: Equatable, Comparable, Codable {

        static func < (lhs: Graphics.Size, rhs: Graphics.Size) -> Bool {
            lhs.width < rhs.width && lhs.height < rhs.height
        }

        let width: Int
        let height: Int

        enum CodingKeys: String, CodingKey {
            case width = "w"
            case height = "h"
        }

        static let icon = Self(width: 48, height: 48)
        static let zero = Self(width: 0, height: 0)
    }

    struct Point: Equatable, Codable {
        
        static func +(lhs: Graphics.Point, rhs: Graphics.Point) -> Graphics.Point {
            return Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
        }

        static func -(lhs: Graphics.Point, rhs: Graphics.Point) -> Graphics.Point {
            return Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
        }

        let x: Int
        let y: Int

        static let zero = Self(x: 0, y: 0)
    }

    struct Rect: Equatable, Codable {

        let origin: Point
        let size: Size
        var minX: Int { return origin.x }
        var minY: Int { return origin.y }
        var width: Int { return size.width }
        var height: Int { return size.height }

        init(origin: Point, size: Size) {
            self.origin = origin
            self.size = size
        }

        init(x: Int, y: Int, width: Int, height: Int) {
            self.init(origin: .init(x: x, y: y), size: .init(width: width, height: height))
        }

        enum CodingKeys: String, CodingKey {
            case x
            case y
            case width = "w"
            case height = "h"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            let x = try values.decode(Int.self, forKey: .x)
            let y = try values.decode(Int.self, forKey: .y)
            let w = try values.decode(Int.self, forKey: .width)
            let h = try values.decode(Int.self, forKey: .height)
            self.origin = Point(x: x, y: y)
            self.size = Size(width: w, height: h)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(minX, forKey: .x)
            try container.encode(minY, forKey: .y)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
        }
    }

    struct Color: Equatable, Codable {
        let r: UInt8
        let g: UInt8
        let b: UInt8

        static let black = Self(r: 0, g: 0, b: 0)
        static let white = Self(r: 255, g: 255, b: 255)
    }

    struct Bitmap: Codable {
        enum Mode: Int, Codable {
            case gray2 = 0 // ie 1bpp
            case gray4 = 1 // ie 2bpp
            case gray16 = 2 // ie 4bpp grayscale
            case gray256 = 3 // ie 8bpp grayscale
            case color16 = 4 // ie 4bpp color
            case color256 = 5 // ie 8bpp color
            case color64K = 6 // 16bpp color
            case color16M = 7 // 24bpp color
            case color4K = 9 // ie 12bpp color
        }
        let mode: Mode
        let width: Int
        let height: Int
        let stride: Int
        let imgData: Data
        // TODO palette info also needed, in due course

        var size: Size {
            return Size(width: width, height: height)
        }
        var isColor: Bool {
            return mode.isColor
        }
    }

    struct MaskedBitmap {
        let bitmap: Bitmap
        let mask: Bitmap?
    }

    struct DrawableId: Hashable, Codable {
        let value: Int

        init(value: Int) {
            self.value = value
        }

        init(from decoder: Decoder) throws {
            self.value = try decoder.singleValueContainer().decode(Int.self)
        }

        func encode(to encoder: Encoder) throws {
            var cont = encoder.singleValueContainer()
            try cont.encode(self.value)
        }

        static var defaultWindow: DrawableId {
            return .init(value: 1)
        }
    }

    struct CopySource {
        let drawableId: DrawableId
        let rect: Rect
        let extra: AnyObject? // a CGImage, in the ProgramViewController impl
    }

    enum FontFace: String {
        case arial
        case times
        case courier
        case tiny
        case squashed
        case digit
        case eiksym
    }

    enum FontFlag: Int, FlagEnum {
        // These are gSTYLE values
        case bold = 1
        case underlined = 2
        case inverse = 4
        case doubleHeight = 8
        case mono = 16
        case italic = 32
        // extras we define
        case boldHint = 64 // Indicates the font is inherently bold
    }
    typealias FontFlags = FlagSet<FontFlag>

    struct FontInfo {
        let uid: UInt32
        let face: FontFace
        let size: Int
        let flags: FontFlags
    }

    enum Mode: Int {
        case set = 0
        case clear = 1
        case invert = 2
        case replace = 3 // Only applicable for copy, pattern and text operations
    }

    enum BorderType: Int {
        // gBORDER
        case singlePixel = 0x0
        case singlePixelShadow = 0x1
        case singlePixelShadowRounded = 0x201
        case clearSinglePixelShadow = 0x2
        case clearSinglePixelShadowRounded = 0x202
        case doublePixelShadow = 0x3
        case doublePixelShadowRounded = 0x203
        case clearDoublePixelShadow = 0x4
        case clearDoublePixelShadowRounded = 0x204

        // gXBORDER type=1
        case series3singlePixelShadow = 0x10001
        case series3singlePixelShadowRounded = 0x10201
        case series3clearSinglePixelShadow = 0x10002
        case series3doublePixelShadow = 0x10003
        case series3doublePixelShadowRounded = 0x10203
        case series3clearDoublePixelShadow = 0x10004


        // gXBORDER type=2
        case shallowSunken = 0x20042
        case deepSunken = 0x20044
        case deepSunkenWithOutline = 0x20054
        case shallowRaised = 0x20082
        case deepRaised = 0x20084
        case deepRaisedWithOutline = 0x20094
        case verticalBar = 0x20022
        case horizontalBar = 0x2002A
    }

    struct DrawCommand {
        enum OpType {
            case fill(Size)
            case circle(Int, Bool) // radius, fill
            case ellipse(Int, Int, Bool) // hRadius, vRadius, fill
            case line(Point)
            case box(Size)
            case bitblt(Bitmap)
            case copy(CopySource, CopySource?) // second arg is optional mask
            case pattern(CopySource)
            case scroll(Int, Int, Rect) // dx, dy, rect
            case text(String, FontInfo)
            case border(Rect, BorderType)
            case invert(Size)
        }
        let drawableId: DrawableId
        let type: OpType
        let mode: Mode
        let origin: Point
        let color: Color
        let bgcolor: Color
        let penWidth: Int
    }

    struct Sprite: Codable {
        struct Frame: Codable {
            let offset: Point
            let bitmap: DrawableId
            let mask: DrawableId
            let invertMask: Bool
            let time: TimeInterval
        }
        let origin: Point
        let frames: [Frame]
    }

    struct ClockInfo: Codable {
        enum Mode: Int, Codable {
            case systemSetting = 6
            case analog = 7
            case digital = 8
        }
        let mode: Mode
        let position: Point
        // TODO offset, format, etc
    }

    struct TextMetrics {
        let size: Graphics.Size
        let ascent: Int
        let descent: Int
    }

    enum PeekMode: Int {
        case oneBitBlack = -1
        case oneBitWhite = 0
        case twoBit = 1
        case fourBit = 2
    }

    enum Operation {
        case close(DrawableId)
        case createBitmap(Size, Bitmap.Mode) // returns handle
        case createWindow(Rect, Bitmap.Mode, Int) // Int is shadow size in pixels. returns handle
        case order(DrawableId, Int) // drawableId, position
        case show(DrawableId, Bool) // drawableId, visible flag
        case textSize(String, FontInfo) // returns TextMetrics
        case busy(DrawableId, Int) // drawableId, delay (in ms)
        case giprint(DrawableId)
        case setwin(DrawableId, Point, Size?) // drawableId, pos, size
        case sprite(DrawableId, Int, Sprite?) // Int is handle, sprite is nil when sprite is closed
        case clock(DrawableId, ClockInfo?)
        case peekline(DrawableId, Point, Int, PeekMode) // drawableId, pos, numPixels, peekMode
    }

    enum Result {
        case nothing
        case handle(DrawableId)
        case textMetrics(TextMetrics)
        case peekedData(Data)
    }
}

extension Graphics.Bitmap.Mode {

    var isColor: Bool {
        return rawValue >= Self.color16.rawValue
    }

}

struct Fs {
    struct Operation {
        enum OpType {
            case exists // return notFound or alreadyExists (any access issue should result in notFound)
            case isdir // as per exists
            case delete // return none, notFound, notReady
            case mkdir // return none, alreadyExists, notReady
            case rmdir // return none, notFound, inUse if it isn't empty, notReady
            case write(Data) // return none, notReady
            case read // return none, notFound, notReady
            case dir // return .strings(paths)
            case rename(String) // return none, notFound, notReady, alreadyExists
            case stat
        }
        let path: String
        let type: OpType
    }

    struct Stat {
        let size: UInt64
        let lastModified: Date
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
        case stat(Stat)
        case strings([String])
    }
}

enum Modifier: Int, FlagEnum {
    case shift = 2
    case control = 4
    case capsLock = 16
    case fn = 32
}
typealias Modifiers = FlagSet<Modifier>

struct Async {
    enum RequestType {
        case getevent
        case playsound(Data)
        case after(TimeInterval)
        case at(Date)
    }
    typealias RequestHandle = Int32
    struct Request {
        let type: RequestType
        let handle: RequestHandle
    }
    struct KeyPressEvent {
        let timestamp: TimeInterval // Since boot
        let keycode: OplKeyCode
        let modifiers: Modifiers
        let isRepeat: Bool
    }
    struct KeyUpDownEvent {
        let timestamp: TimeInterval // Since boot
        let keycode: OplKeyCode
        let modifiers: Modifiers
    }
    enum PenEventType: Int {
        case down = 0
        case up = 1
        case drag = 6
    }
    struct PenEvent {
        let timestamp: TimeInterval // Since boot
        let windowId: Graphics.DrawableId
        let type: PenEventType
        let modifiers: Modifiers
        let x: Int
        let y: Int
        let screenx: Int
        let screeny: Int
    }
    struct PenUpDownEvent {
        let timestamp: TimeInterval // Since boot
        let windowId: Graphics.DrawableId
    }
    struct ActivationEvent {
        let timestamp: TimeInterval // Since boot
    }
    enum ResponseValue {
        case cancelled
        case completed
        // case stopped // ie throw a KStopErr to unwind the thread, do not pass go do not collect £200.
        case keypressevent(KeyPressEvent)
        case keydownevent(KeyUpDownEvent)
        case keyupevent(KeyUpDownEvent)
        case penevent(PenEvent)
        case pendownevent(PenUpDownEvent)
        case penupevent(PenUpDownEvent)
        case foregrounded(ActivationEvent)
        case backgrounded(ActivationEvent)
        case quitevent
        case interrupt
    }
    struct Response {
        let handle: RequestHandle
        let value: ResponseValue
    }
}

extension Async.KeyPressEvent {
    func modifiedKeycode() -> Int? {
        if modifiers.contains(.control) && keycode.rawValue >= OplKeyCode.a.rawValue && keycode.rawValue <= OplKeyCode.z.rawValue {
            // OPL likes to send 1-26 for Ctrl-[Shift-]A thru Ctrl-[Shift-]Z
            return keycode.rawValue - (OplKeyCode.a.rawValue - 1)
        } else if modifiers.contains(.control) && keycode.rawValue >= OplKeyCode.num0.rawValue && keycode.rawValue <= OplKeyCode.num9.rawValue {
            // Ctrl-0 thru Ctrl-9 don't send keypress events at all because CTRL-x,y,z... is used
            // for inputting a key with code xyz.
            // But eg Ctrl-Fn-1 (for underscore) does.
            return nil
        } else {
            return keycode.rawValue
        }
    }
}

enum ConfigName: String, CaseIterable {
    case clockFormat // 0: analog, 1: digital
}

struct EditParams: Codable {
    enum InputType: String, Codable {
        case text
        case password
        case integer
        case float
        case date
        case time
    }

    let type: InputType
    let initialValue: String
    let prompt: String?
    let allowCancel: Bool
    let min: Int?
    let max: Int?
}

protocol OpoIoHandler {

    func printValue(_ val: String) -> Void

    func editValue(_ params: EditParams) -> String?

    func beep(frequency: Double, duration: Double) -> Error?

    func draw(operations: [Graphics.DrawCommand])
    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result

    func getScreenInfo() -> (Graphics.Size, Graphics.Bitmap.Mode)

    func fsop(_ op: Fs.Operation) -> Fs.Result

    func asyncRequest(_ request: Async.Request)
    func cancelRequest( _ requestHandle: Async.RequestHandle)
    func waitForAnyRequest() -> Async.Response
    func anyRequest() -> Async.Response?

    // Return true if there is an event waiting
    func testEvent() -> Bool

    func key() -> Async.KeyPressEvent?

    func setConfig(key: ConfigName, value: String)
    func getConfig(key: ConfigName) -> String

    func setAppTitle(_ title: String)
    func displayTaskList()
    func setForeground()
    func setBackground()
    func runApp(name: String, document: String) -> Int32?
}

class DummyIoHandler : OpoIoHandler {

    func printValue(_ val: String) -> Void {
        print(val, terminator: "")
    }

    func editValue(_ params: EditParams) -> String? {
        return "123"
    }

    func alert(lines: [String], buttons: [String]) -> Int {
        return 1
    }

    func getch() -> Int {
        return 0
    }

    func beep(frequency: Double, duration: Double) -> Error? {
        print("BEEP \(frequency)kHz \(duration)s")
        return nil
    }

    func draw(operations: [Graphics.DrawCommand]) {
    }

    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result {
        return .nothing
    }

    func getScreenInfo() -> (Graphics.Size, Graphics.Bitmap.Mode) {
        return (Graphics.Size(width: 640, height: 240), .gray4)
    }

    func fsop(_ op: Fs.Operation) -> Fs.Result {
        return .err(.notReady)
    }

    func asyncRequest(_ request: Async.Request) {
    }

    func cancelRequest(_ requestHandle: Async.RequestHandle) {
    }

    func waitForAnyRequest() -> Async.Response {
        fatalError("No support for waitForAnyRequest in DummyIoHandler")
    }

    func anyRequest() -> Async.Response? {
        return nil
    }

    func testEvent() -> Bool {
        return false
    }

    func key() -> Async.KeyPressEvent? {
        return nil
    }

    func setConfig(key: ConfigName, value: String) {
    }

    func getConfig(key: ConfigName) -> String {
        return ""
    }

    func setAppTitle(_ title: String) {
    }

    func displayTaskList() {
    }

    func setForeground() {
    }

    func setBackground() {
    }

    func runApp(name: String, document: String) -> Int32? {
        return nil
    }

}
