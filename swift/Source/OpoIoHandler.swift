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
import Lua

public struct Graphics {

    public struct Size: Equatable, Comparable, Codable {

        enum CodingKeys: String, CodingKey {
            case width = "w"
            case height = "h"
        }

        public static func < (lhs: Graphics.Size, rhs: Graphics.Size) -> Bool {
            lhs.width < rhs.width && lhs.height < rhs.height
        }

        public static let icon = Self(width: 48, height: 48)
        public static let zero = Self(width: 0, height: 0)

        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }

    }

    public struct Point: Equatable, Codable {

        public static func +(lhs: Graphics.Point, rhs: Graphics.Point) -> Graphics.Point {
            return Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
        }

        public static func -(lhs: Graphics.Point, rhs: Graphics.Point) -> Graphics.Point {
            return Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
        }

        public static let zero = Self(x: 0, y: 0)

        public let x: Int
        public let y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct Rect: Equatable, Codable {

        public let origin: Point
        public let size: Size
        
        public var minX: Int {
            return origin.x
        }
        
        public var minY: Int {
            return origin.y
        }
        
        public var midX: Float {
            return Float(origin.x) + Float(width) / 2
        }
        
        public var midY: Float {
            return Float(origin.y) + Float(height) / 2
        }
        
        public var width: Int {
            return size.width
        }
        
        public var height: Int {
            return size.height
        }

        public var maxX: Int {
            return origin.x + size.width
        }

        public var maxY: Int {
            return origin.y + size.height
        }

        public init(origin: Point, size: Size) {
            self.origin = origin
            self.size = size
        }

        public init(x: Int, y: Int, width: Int, height: Int) {
            self.init(origin: .init(x: x, y: y), size: .init(width: width, height: height))
        }

        enum CodingKeys: String, CodingKey {
            case x
            case y
            case width = "w"
            case height = "h"
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            let x = try values.decode(Int.self, forKey: .x)
            let y = try values.decode(Int.self, forKey: .y)
            let w = try values.decode(Int.self, forKey: .width)
            let h = try values.decode(Int.self, forKey: .height)
            self.origin = Point(x: x, y: y)
            self.size = Size(width: w, height: h)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(minX, forKey: .x)
            try container.encode(minY, forKey: .y)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
        }
    }

    public struct Color: Equatable, Codable {
        let r: UInt8
        let g: UInt8
        let b: UInt8

        public static let black = Self(r: 0, g: 0, b: 0)
        public static let white = Self(r: 255, g: 255, b: 255)
        public static let midGray = Self(r: 0x80, g: 0x80, b: 0x80)
        public static let alphaMask: UInt32 = 0xFF000000

        var greyValue: UInt8 {
            return UInt8((Int(r) + Int(g) + Int(b)) / 3)
        }

        public var pixelValue: UInt32 {
            return UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16) | Self.alphaMask
        }

    }

    public struct Bitmap: Codable {

        public enum Mode: Int, Codable {
            case gray2 = 0 // ie 1bpp
            case gray4 = 1 // ie 2bpp
            case gray16 = 2 // ie 4bpp grayscale
            case gray256 = 3 // ie 8bpp grayscale
            case color16 = 4 // ie 4bpp color
            case color256 = 5 // ie 8bpp color
            case color64K = 6 // 16bpp color
            case color16M = 7 // 24bpp color?
            case colorRGB = 8 // 32bpp?
            case color4K = 9 // ie 12bpp color
        }

        public let width: Int
        public let height: Int
        public let isColor: Bool
        public let normalizedImgData: Data

        public var size: Size {
            return Size(width: width, height: height)
        }
        public var stride: Int {
            return isColor ? 4 * width : width
        }
    }

    public struct MaskedBitmap: Codable {
        public let bitmap: Bitmap
        public let mask: Bitmap?
    }

    public struct DrawableId: Hashable, Codable {

        public let value: Int

        init(value: Int) {
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            self.value = try decoder.singleValueContainer().decode(Int.self)
        }

        public func encode(to encoder: Encoder) throws {
            var cont = encoder.singleValueContainer()
            try cont.encode(self.value)
        }

        public static var defaultWindow: DrawableId {
            return .init(value: 1)
        }
    }

    public struct CopySource {
        public let drawableId: DrawableId
        public let rect: Rect
    }

    enum FontFace: String, Codable {
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

    public struct FontInfo: Codable {
        let uid: UInt32
        let face: FontFace
        let size: Int
        let flags: FontFlags
    }

    public enum Mode: Int {
        case set = 0
        case clear = 1
        case invert = 2
        case replace = 3 // Only applicable for copy, pattern and text operations
    }

    public enum GreyMode: Int, Codable {
        case normal = 0
        case greyPlaneOnly = 1
        case bothPlanes = 2
    }

    public struct DrawCommand {
        public enum OpType {
            case fill(Size)
            case circle(Int, Bool) // radius, fill
            case ellipse(Int, Int, Bool) // hRadius, vRadius, fill
            case line(Point)
            case box(Size)
            case bitblt(Bitmap)
            case copy(CopySource, CopySource?) // second arg is optional mask
            case mcopy(DrawableId, [Rect], [Point])
            case pattern(CopySource)
            case scroll(Int, Int, Rect) // dx, dy, rect
            case border(Rect, Int) // border type
            case invert(Size)
        }
        public let drawableId: DrawableId
        public let type: OpType
        public let mode: Mode
        public let origin: Point
        public let color: Color
        public let bgcolor: Color
        public let penWidth: Int
        public let greyMode: GreyMode

        public init(drawableId: DrawableId,
                    type: OpType,
                    mode: Mode,
                    origin: Point,
                    color: Color,
                    bgcolor: Color,
                    penWidth: Int,
                    greyMode: GreyMode) {
            self.drawableId = drawableId
            self.type = type
            self.mode = mode
            self.origin = origin
            self.color = color
            self.bgcolor = bgcolor
            self.penWidth = penWidth
            self.greyMode = greyMode
        }
    }

    public struct Sprite: Codable {
        public struct Frame: Codable {
            public let offset: Point
            public let bitmap: DrawableId
            public let mask: DrawableId
            public let invertMask: Bool
            public let time: TimeInterval

            public init(offset: Point, bitmap: DrawableId, mask: DrawableId, invertMask: Bool, time: TimeInterval) {
                self.offset = offset
                self.bitmap = bitmap
                self.mask = mask
                self.invertMask = invertMask
                self.time = time
            }
        }
        public let origin: Point
        public let frames: [Frame]

        public init(origin: Point, frames: [Frame]) {
            self.origin = origin
            self.frames = frames
        }
    }

    public struct ClockInfo: Codable {
        public enum Mode: Int, Codable {
            case systemSetting = 6
            case analog = 7
            case digital = 8
        }
        public let mode: Mode
        public let position: Point
        // TODO offset, format, etc

        public init(mode: Mode, position: Point) {
            self.mode = mode
            self.position = position
        }
    }

    public struct TextMetrics {
        let size: Graphics.Size
        let ascent: Int
        let descent: Int
    }

    public enum PeekMode: Int {
        case oneBitBlack = -1
        case oneBitWhite = 0
        case twoBit = 1
        case fourBit = 2
    }

    public enum CursorFlag: Int, FlagEnum {
        case notFlashing = 2
        case grey = 4
    }

    public struct Cursor: Codable {
        public let id: DrawableId
        public let rect: Rect
        public let flags: FlagSet<CursorFlag>

        public init(id: DrawableId, rect: Rect, flags: FlagSet<CursorFlag>) {
            self.id = id
            self.rect = rect
            self.flags = flags
        }
    }

    public struct FontMetrics: Codable {
        public let height: Int
        public let maxwidth: Int
        public let ascent: Int
        public let descent: Int
        public let widths: [Int] // Always 256 elements

        public init(height: Int, maxwidth: Int, ascent: Int, descent: Int, widths: [Int]) {
            self.height = height
            self.maxwidth = maxwidth
            self.ascent = ascent
            self.descent = descent
            self.widths = widths
        }
    }

    public enum Operation {
        case close(DrawableId)
        case createBitmap(DrawableId, Size, Bitmap.Mode)
        case createWindow(DrawableId, Rect, Bitmap.Mode, Int) // Int is shadow size in pixels
        case loadFont(DrawableId, UInt32) // returns .fontMetrics or .error
        case order(DrawableId, Int) // drawableId, position
        case rank(DrawableId)
        case show(DrawableId, Bool) // drawableId, visible flag
        case busy(DrawableId, Int) // drawableId, delay (in ms)
        case giprint(DrawableId)
        case setwin(DrawableId, Point, Size?) // drawableId, pos, size
        case sprite(DrawableId, Int, Sprite?) // Int is handle, sprite is nil when sprite is closed
        case clock(DrawableId, ClockInfo?)
        case peekline(DrawableId, Point, Int, PeekMode) // drawableId, pos, numPixels, peekMode
        case getimg(DrawableId, Rect)
        case cursor(Cursor?)
    }

    public enum Result {
        case nothing
        case data(Data)
        case rank(Int)
        case error(Error)
        case fontMetrics(FontMetrics)
    }

    public enum Error: Int, RawPushable {
        case invalidArguments = -2
        case badDrawable = -118
        case invalidWindow = -119
    }
}

extension Graphics.Bitmap.Mode {

    public var isColor: Bool {
        return rawValue >= Self.color16.rawValue
    }

}

extension Graphics.GreyMode {
    public var drawGreyPlane: Bool {
        return self == .greyPlaneOnly || self == .bothPlanes
    }
    public var drawNormalPlane: Bool {
        return self == .normal || self == .bothPlanes
    }
}

public struct Fs {
    public struct Operation {
        public enum OpType {
            case delete // return .success, notFound, accessDenied if readonly, notReady
            case mkdir // return .success, alreadyExists, accessDenied if readonly, notReady
            case rmdir // return .success, notFound, inUse if it isn't empty, pathNotFound if it's not a dir, accessDenied if readonly, notReady
            case write(Data) // return .success, accessDenied if readonly, notReady
            case read // return .data() or notFound, notReady
            case dir // return .strings(paths)
            case rename(String) // return .success, notFound, accessDenied if readonly, notReady, alreadyExists
            case stat // return stat, or notFound or notReady
            case exists // return .success or .notFound
            case disks // return .strings(diskList)
        }
        public let path: String
        public let type: OpType
    }

    public struct Stat {
        public let size: UInt64
        public let lastModified: Date
        public let isDirectory: Bool

        public init(size: UInt64, lastModified: Date, isDirectory: Bool) {
            self.size = size
            self.lastModified = lastModified
            self.isDirectory = isDirectory
        }
    }

    public enum Err: Int, Codable {
        case general = -1
        case inUse = -9
        case notFound = -33
        case alreadyExists = -32
        case accessDenied = -39
        case pathNotFound = -42
        case notReady = -62 // For any op outside our sandbox
    }

    public enum Result {
        case success
        case err(Err)
        case data(Data)
        case stat(Stat)
        case strings([String])
        case epocError(Int32) // Not recommended to use this for OPL programs
    }
}

extension Fs.Operation {
    public func isReadonlyOperation() -> Bool {
        switch type {
        case .read: return true
        case .dir: return true
        case .stat: return true
        case .exists: return true
        case .disks: return true
        default: return false
        }
    }
}

public enum Modifier: Int, FlagEnum {
    case shift = 2
    case control = 4
    case capsLock = 16
    case fn = 32
}
public typealias Modifiers = FlagSet<Modifier>

public struct Async {

    public enum RequestType {
        case getevent
        case keya
        case playsound(Data)
        case after(TimeInterval)
        case at(Date)
    }

    public typealias RequestHandle = Int32

    public struct Request {
        let type: RequestType
        let handle: RequestHandle

        public init(type: RequestType, handle: RequestHandle) {
            self.type = type
            self.handle = handle
        }
    }

    public struct KeyPressEvent {
        public let timestamp: TimeInterval // Since boot
        public let keycode: OplKeyCode
        public let modifiers: Modifiers
        public let isRepeat: Bool

        public init(timestamp: TimeInterval, keycode: OplKeyCode, modifiers: Modifiers, isRepeat: Bool) {
            self.timestamp = timestamp
            self.keycode = keycode
            self.modifiers = modifiers
            self.isRepeat = isRepeat
        }
    }

    public struct KeyUpDownEvent {
        public let timestamp: TimeInterval // Since boot
        public let keycode: OplKeyCode
        public let modifiers: Modifiers

        public init(timestamp: TimeInterval, keycode: OplKeyCode, modifiers: Modifiers) {
            self.timestamp = timestamp
            self.keycode = keycode
            self.modifiers = modifiers
        }
    }

    public enum PenEventType: Int {
        case down = 0
        case up = 1
        case drag = 6
    }

    public struct PenEvent {
        public let timestamp: TimeInterval // Since boot
        public let windowId: Graphics.DrawableId
        public let type: PenEventType
        public let modifiers: Modifiers
        public let x: Int
        public let y: Int
        public let screenx: Int
        public let screeny: Int

        public init(timestamp: TimeInterval,
                    windowId: Graphics.DrawableId,
                    type: PenEventType,
                    modifiers: Modifiers,
                    x: Int,
                    y: Int,
                    screenx: Int,
                    screeny: Int) {
            self.timestamp = timestamp
            self.windowId = windowId
            self.type = type
            self.modifiers = modifiers
            self.x = x
            self.y = y
            self.screenx = screenx
            self.screeny = screeny
        }
    }

    public struct PenUpDownEvent {
        public let timestamp: TimeInterval // Since boot
        public let windowId: Graphics.DrawableId

        public init(timestamp: TimeInterval, windowId: Graphics.DrawableId) {
            self.timestamp = timestamp
            self.windowId = windowId
        }
    }

    public struct ActivationEvent {
        public let timestamp: TimeInterval // Since boot

        public init(timestamp: TimeInterval) {
            self.timestamp = timestamp
        }
    }

    public enum ResponseValue {
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

    public struct Response {
        
        let handle: RequestHandle
        let value: ResponseValue

        public init(handle: RequestHandle, value: ResponseValue) {
            self.handle = handle
            self.value = value
        }
    }

}

extension Async.KeyPressEvent {
    public func modifiedKeycode() -> Int? {
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

public enum ConfigName: String, CaseIterable {
    case clockFormat // 0: analog, 1: digital
    case locale // eg "en_GB"
}

public struct TextFieldInfo: Codable {
    public enum InputType: String, Codable {
        case text
        case integer
        case float
    }
    public let id: Graphics.DrawableId
    public let type: InputType
    public let controlRect: Graphics.Rect // bounding rect of the whole text field, in screen coords
    public let cursorRect: Graphics.Rect // location of cursor, in screen coords
    public let windowRect: Graphics.Rect // for convenience, in screen coords
    public let userFocusRequested: Bool // true if user tapped in the text field

    public init(id: Graphics.DrawableId,
                type: InputType,
                controlRect: Graphics.Rect,
                cursorRect: Graphics.Rect,
                windowRect: Graphics.Rect,
                userFocusRequested: Bool) {
        self.id = id
        self.type = type
        self.controlRect = controlRect
        self.cursorRect = cursorRect
        self.windowRect = windowRect
        self.userFocusRequested = userFocusRequested
    }
}

public protocol FileSystemIoHandler {

    func fsop(_ op: Fs.Operation) -> Fs.Result

}

public struct Sis {
    public struct Version: Codable, Hashable /* also Comparable, CustomStringConvertible */ {
        public let major: Int
        public let minor: Int

        public init(major: Int, minor: Int) {
            self.major = major
            self.minor = minor
        }
    }

    public struct File: Codable, Hashable {
        public let name: [String: String]
        public let uid: UInt32
        public let version: Version
        public let languages: [String]
    }

    public struct Installation: Codable {
        public let name: String
        public let uid: UInt32
        public let version: Version
        public let language: String
        public let drive: String
    }

    public struct Stub: Codable {
        public let path: String
        public let contents: Data

        public init(path: String, contents: Data) {
            self.path = path
            self.contents = contents
        }
    }

    public enum GetStubsResult {
        case notImplemented
        case epocError(Int32)
        case stubs([Sis.Stub])
    }

    public enum InstallError: Error, Equatable {
        case userCancelled
        case epocError(Int32, String?)
        case isStub
        case internalError(String)
    }

    public struct BeginContext: Codable {
        public let driveRequired: Bool
        public let replacing: Sis.Installation?
        public let isRoot: Bool
    }

    public struct BeginInstallData {
        public let drive: String
        public let stubDir: String? // nil means use default
        public let language: String

        public init(drive: String, stubDir: String?, language: String) {
            self.drive = drive
            self.stubDir = stubDir
            self.language = language
        }
    }

    public enum BeginResult {
        case skipInstall // Not an error
        case userCancelled
        case epocError(Int32)
        case install(BeginInstallData)
    }

    public enum QueryType: String {
        case `continue` // "Continue" button only
        case skip // "Yes"/"No" buttons, next install file skipped on "No"
        case abort // "Yes"/"No" buttons, abort install on "No"
        case exit // Same as abort but also do cleanup (?)
    }

    public enum RunFlag: Int, FlagEnum {
        case closeWhenComplete = 256
        case waitForClose = 512
    }
    public typealias RunFlags = FlagSet<RunFlag>

}

public protocol SisInstallIoHandler: FileSystemIoHandler {

    func sisGetStubs() -> Sis.GetStubsResult

    func sisInstallBegin(sis: Sis.File, context: Sis.BeginContext) -> Sis.BeginResult

    // Return true to continue, false if user selected "No"
    func sisInstallQuery(sis: Sis.File, text: String, type: Sis.QueryType) -> Bool

    // Called to indicate that an error occurred and the installation will now roll back. Return false to indicate
    // rollback is unnecessary (because for eg, the native code will take care of it).
    func sisInstallRollback(sis: Sis.File) -> Bool

    func sisInstallRun(sis: Sis.File, path: String, flags: Sis.RunFlags)

    func sisInstallComplete(sis: Sis.File)
}

public protocol OpoIoHandler: FileSystemIoHandler {

    func printValue(_ val: String) -> Void

    func textEditor(_ info: TextFieldInfo?)

    func draw(operations: [Graphics.DrawCommand]) -> Graphics.Error?
    func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result

    func getDeviceInfo() -> (Graphics.Size, Graphics.Bitmap.Mode, String)

    func asyncRequest(handle: Async.RequestHandle, type: Async.RequestType)
    func cancelRequest(handle: Async.RequestHandle)
    func waitForAnyRequest() -> Async.Response
    func anyRequest() -> Async.Response?

    // Return true if there is an event waiting
    func testEvent() -> Bool

    func keysDown() -> Set<OplKeyCode>

    func setConfig(key: ConfigName, value: String)
    func getConfig(key: ConfigName) -> String

    func setAppTitle(_ title: String)
    func displayTaskList()
    func setForeground()
    func setBackground()
    func runApp(name: String, document: String) -> Int32?

    func opsync()
}

public class DummyIoHandler : OpoIoHandler {

    public init() {
    }

    public func printValue(_ val: String) -> Void {
        print(val, terminator: "")
    }

    public func textEditor(_ info: TextFieldInfo?) {
    }

    func alert(lines: [String], buttons: [String]) -> Int {
        return 1
    }

    func getch() -> Int {
        return 0
    }

    public func draw(operations: [Graphics.DrawCommand]) -> Graphics.Error? {
        return nil
    }

    public func graphicsop(_ operation: Graphics.Operation) -> Graphics.Result {
        return .nothing
    }

    public func getDeviceInfo() -> (Graphics.Size, Graphics.Bitmap.Mode, String) {
        return (Graphics.Size(width: 640, height: 240), .gray4, "psion-series-5")
    }

    public func fsop(_ op: Fs.Operation) -> Fs.Result {
        return .err(.notReady)
    }

    public func asyncRequest(handle: Async.RequestHandle, type: Async.RequestType) {
    }

    public func cancelRequest(handle: Async.RequestHandle) {
    }

    public func waitForAnyRequest() -> Async.Response {
        fatalError("No support for waitForAnyRequest in DummyIoHandler")
    }

    public func anyRequest() -> Async.Response? {
        return nil
    }

    public func testEvent() -> Bool {
        return false
    }

    public func keysDown() -> Set<OplKeyCode> {
        return []
    }

    public func setConfig(key: ConfigName, value: String) {
    }

    public func getConfig(key: ConfigName) -> String {
        return ""
    }

    public func setAppTitle(_ title: String) {
    }

    public func displayTaskList() {
    }

    public func setForeground() {
    }

    public func setBackground() {
    }

    public func runApp(name: String, document: String) -> Int32? {
        return nil
    }

    public func opsync() {
    }
}
