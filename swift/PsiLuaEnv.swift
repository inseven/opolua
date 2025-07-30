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
import CLua

// ER5 always uses CP1252 afaics, which also works for our ASCII-only error messages
public let kDefaultEpocEncoding: LuaStringEncoding = .stringEncoding(.windowsCP1252)
// And SIBO uses CP850 (which is handled completely differently and has an inconsistent name to boot)
public let kSiboEncoding: LuaStringEncoding = .cfStringEncoding(.dosLatin1)

public class PsiLuaEnv {

    internal let L: LuaState

    public init() {
        L = LuaState(libraries: [.package, .table, .io, .os, .string, .math, .utf8, .debug])
        L.setDefaultStringEncoding(kDefaultEpocEncoding)

        let srcRoot = Bundle.main.url(forResource: "init",
                                      withExtension: "lua",
                                      subdirectory: "src")!.deletingLastPathComponent()
        L.setRequireRoot(srcRoot.path)

        // Finally, run init.lua
        require("init")
        L.pop()
        assert(L.gettop() == 0) // In case we failed to balance stack during init
    }

    deinit {
        L.close()
    }

    private func logpcall(_ nargs: CInt, _ nret: CInt) -> Bool {
        do {
            try L.pcall(nargs: nargs, nret: nret)
            return true
        } catch {
            print("Error: \(error.localizedDescription)")
            return false
        }
    }

    internal func require(_ library: String) {
        L.getglobal("require")
        L.push(utf8String: library)
        guard logpcall(1, 1) else {
            fatalError("Failed to load \(library).lua!")
        }
    }

    public struct LocalizedString {
        public var value: String
        public var locale: Locale

        public init(_ value: String, locale: Locale) {
            self.value = value
            self.locale = locale
        }
    }

    public enum AppEra: String, Codable {
        case sibo
        case er5
    }

    public struct AppInfo {
        public let captions: [LocalizedString]
        public let uid3: UInt32
        public let icons: [Graphics.MaskedBitmap]
        public let era: AppEra
    }

    public func appInfo(for path: String) -> AppInfo? {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        require("aif")
        L.rawget(-1, utf8Key: "parseAif")
        L.remove(-2) // aif module
        L.push(data)
        guard logpcall(1, 1) else { return nil }

        return L.toAppInfo(-1)
    }

    public func getMbmBitmaps(path: String) -> [Graphics.Bitmap]? {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        require("recognizer")
        L.rawget(-1, key: "getMbmBitmaps")
        L.remove(-2) // recognizer module
        L.push(data)
        guard logpcall(1, 1) else { return nil }
        // top of stack should now be bitmap array
        let result: [Graphics.Bitmap]? = L.todecodable(-1)
        return result
    }

    public struct UnknownEpocFile: Codable {
        public let uid1: UInt32
        public let uid2: UInt32
        public let uid3: UInt32
    }

    public struct MbmFile: Codable {
        public let bitmaps: [Graphics.Bitmap]
    }

    public struct OplFile: Codable {
        public let text: String
    }

    public struct SoundFile: Codable {
        public let data: Data
    }

    public struct OpaFile {
        public let uid3: UInt32
        public let appInfo: AppInfo? // For SIBO-era apps
        public let era: AppEra
    }

    public struct OpoFile : Codable {
        public let era: AppEra
    }

    public struct ResourceFile: Codable {
        public let idOffset: UInt32?
    }

    public enum FileType: String, Codable {
        case unknown
        case aif
        case database
        case mbm
        case opl
        case opa
        case opo
        case resource
        case sound
        case sis
    }

    public enum FileInfo {
        case unknown
        case unknownEpoc(UnknownEpocFile)
        case aif(AppInfo)
        case database
        case mbm(MbmFile)
        case opl(OplFile)
        case opa(OpaFile)
        case opo(OpoFile)
        case resource(ResourceFile)
        case sound(SoundFile)
        case sis(Sis.File)
    }

    public func recognize(path: String) -> FileType {
        guard let data = FileManager.default.contents(atPath: path) else {
            return .unknown
        }
        return self.recognize(data: data)
    }

    public func recognize(data: Data) -> FileType {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        require("recognizer")
        L.rawget(-1, key: "recognize")
        L.remove(-2) // recognizer module
        L.push(data)
        guard logpcall(1, 1) else {
            return .unknown
        }
        guard let type = L.tostring(-1, key: "type") else {
            return .unknown
        }
        return FileType(rawValue: type) ?? .unknown
    }

    public func getFileInfo(path: String) -> FileInfo {
        guard let data = FileManager.default.contents(atPath: path) else {
            return .unknown
        }
        return getFileInfo(data: data)
    }

    public func getFileInfo(data: Data) -> FileInfo {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        require("recognizer")
        L.rawget(-1, key: "recognize")
        L.remove(-2) // recognizer module
        L.push(data)
        guard logpcall(1, 1) else {
            return .unknown
        }
        guard let typeStr = L.tostring(-1, key: "type") else {
            return .unknown
        }
        guard let type = FileType(rawValue: typeStr) else {
            fatalError("Unhandled type \(typeStr)")
        }

        switch type {
        case .aif:
            if let info = L.toAppInfo(-1) {
                return .aif(info)
            }
        case .database:
            return .database
        case .mbm:
            if let info: MbmFile = L.todecodable(-1) {
                return .mbm(info)
            }
        case .opl:
            if let info: OplFile = L.todecodable(-1) {
                return .opl(info)
            }
        case .opa:
            if let appInfo: AppInfo = L.toAppInfo(-1) {
                let opa = OpaFile(uid3: appInfo.uid3, appInfo: appInfo, era: appInfo.era)
                return .opa(opa)
            } else if let eraString = L.tostring(-1, key: "era"),
                      let era = AppEra(rawValue: eraString),
                      let uid3Int = L.toint(-1, key: "uid3"),
                      let uid3 = UInt32(exactly: uid3Int) {
                return .opa(OpaFile(uid3: uid3, appInfo: nil, era: era))
            }
        case .opo:
            if let info: OpoFile = L.todecodable(-1) {
                return .opo(info)
            }
        case .resource:
            if let info: ResourceFile = L.todecodable(-1) {
                return .resource(info)
            }
        case .sis:
            if let info: Sis.File = L.todecodable(-1) {
                return .sis(info)
            }
        case .sound:
            if let info: SoundFile = L.todecodable(-1) {
                return .sound(info)
            }
        case .unknown:
            if let info: UnknownEpocFile = L.todecodable(-1) {
                return .unknownEpoc(info)
            }
        }
        return .unknown
    }

    public enum OpoArgumentType: Int {
        case Word = 0
        case Long = 1
        case Real = 2
        case String = 3
        case WordArray = 0x80
        case ELongArray = 0x81
        case ERealArray = 0x82
        case EStringArray = 0x83
    }

    public struct OpoProcedure {
        public let name: String
        public let arguments: [OpoArgumentType]
    }

    public func getProcedures(opoFile: String) -> [OpoProcedure]? {
        guard let data = FileManager.default.contents(atPath: opoFile) else {
            return nil
        }
        require("opofile")
        L.rawget(-1, key: "parseOpo")
        L.remove(-2) // opofile
        L.push(data)
        guard logpcall(1, 1) else {
            return nil
        }
        var procs: [OpoProcedure] = []
        for _ in L.ipairs(-1) {
            let name = L.tostring(-1, key: "name")!
            var args: [OpoArgumentType] = []
            if L.rawget(-1, key: "params") == .table {
                for _ in L.ipairs(-1) {
                    // insert at front because params are listed bass-ackwards
                    args.insert(OpoArgumentType(rawValue: L.toint(-1)!)!, at: 0)
                }
            }
            L.pop() // params
            procs.append(OpoProcedure(name: name, arguments: args))
        }
        L.pop() // procs
        return procs
    }

    internal static let fsop: lua_CFunction = { (L: LuaState!) -> CInt in
        let wrapper: Wrapper<FileSystemIoHandler> = L.touserdata(lua_upvalueindex(1))!
        let iohandler = wrapper.value

        guard let cmd = L.tostring(1) else {
            return 0
        }
        guard let path = L.tostring(2) else {
            return 0
        }

        let cmdReturnsResult = cmd == "read" || cmd == "dir" || cmd == "stat" || cmd == "disks"

        let op: Fs.Operation.OpType
        switch cmd {
        case "stat":
            op = .stat
        case "exists":
            op = .exists
        case "disks":
            op = .disks
        case "delete":
            op = .delete
        case "mkdir":
            op = .mkdir
        case "rmdir":
            op = .rmdir
        case "write":
            if let data = L.todata(3) {
                op = .write(Data(data))
            } else {
                return 0
            }
        case "read":
            op = .read
        case "dir":
            op = .dir
        case "rename":
            guard let dest = L.tostring(3) else {
                print("Missing param to rename")
                L.push(Fs.Err.notReady.rawValue)
                return 1
            }
            op = .rename(dest)
        default:
            print("Unimplemented fsop \(cmd)!")
            L.push(Fs.Err.notReady.rawValue)
            return 1
        }

        let result = iohandler.fsop(Fs.Operation(path: path, type: op))
        switch (result) {
        case .success:
            L.push(0)
            return 1
        case .err(let err):
            print("Error \(err) for cmd \(op) path \(path)")
            if cmdReturnsResult {
                L.pushnil()
                L.push(err.rawValue)
                return 2
            } else {
                L.push(err.rawValue)
                return 1
            }
        case .epocError(let err):
            print("Error \(err) for cmd \(op) path \(path)")
            if cmdReturnsResult {
                L.pushnil()
                L.push(err)
                return 2
            } else {
                L.push(err)
                return 1
            }
        case .data(let data):
            L.push(data)
            return 1
        case .strings(let strings):
            L.newtable(narr: CInt(strings.count), nrec: 0)
            for (i, string) in strings.enumerated() {
                L.rawset(-1, key: i + 1, value: string)
            }
            return 1
        case .stat(let stat):
            L.newtable()
            L.rawset(-1, key: "size", value: Int64(stat.size))
            L.rawset(-1, key: "lastModified", value: stat.lastModified.timeIntervalSince1970)
            L.rawset(-1, key: "isDir", value: stat.isDirectory)
            return 1
        }
    }

    public func installSisFile(path: String, handler: SisInstallIoHandler) throws {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw LuaArgumentError(errorString: "Couldn't read \(path)")
        }
        try installSisFile(path: path, data: data, handler: handler)
    }

    public func installSisFile(path: String? = nil, data: Data, handler: SisInstallIoHandler) throws {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        require("runtime")
        L.rawget(-1, utf8Key: "installSis")
        L.push(path)
        L.push(data)
        makeSisInstallIoHandlerBridge(handler)
        do {
            try L.pcall(nargs: 3, nret: 1)
        } catch {
            throw Sis.InstallError.internalError(String(describing: error))
        }
        switch L.type(-1) {
        case .table:
            guard let err: Sis.InstallError = L.todecodable(-1) else {
                throw Sis.InstallError.internalError("Failed to decode SisInstallError from installSis result")
            }
            throw err
        case .none, .nil:
            break
        default:
            throw Sis.InstallError.internalError(L.tostring(-1, convert: true) ?? "Bad error string")
        }
    }

    public func uninstallSisFile(stubs: [Sis.Stub], uid: UInt32, handler: FileSystemIoHandler) throws {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        require("runtime")
        L.rawget(-1, utf8Key: "uninstallSis")
        try! L.push(encodable: stubs)
        L.push(uid)
        makeFsIoHandlerBridge(handler)
        try L.pcall(nargs: 3, nret: 0)
    }

    internal func makeFsIoHandlerBridge(_ handler: FileSystemIoHandler) {
        L.newtable()
        L.push(Wrapper<FileSystemIoHandler>(value: handler))
        let fns: [String: lua_CFunction] = [
            "fsop": { L in return autoreleasepool { return PsiLuaEnv.fsop(L) } },
        ]
        L.setfuncs(fns, nup: 1)
    }

    internal func makeSisInstallIoHandlerBridge(_ handler: SisInstallIoHandler) {
        makeFsIoHandlerBridge(handler)
        L.push(Wrapper<SisInstallIoHandler>(value: handler))
        let fns: [String: lua_CFunction] = [
            "sisGetStubs": { L in return autoreleasepool { return PsiLuaEnv.sisGetStubs(L) } },
            "sisInstallBegin": { L in return autoreleasepool { return PsiLuaEnv.sisInstallBegin(L) } },
            "sisInstallComplete": { L in return autoreleasepool { return PsiLuaEnv.sisInstallComplete(L) } },
            "sisInstallRollback": { L in return autoreleasepool { return PsiLuaEnv.sisInstallRollback(L) } },
            "sisInstallQuery": { L in return autoreleasepool { return PsiLuaEnv.sisInstallQuery(L) } },
            "sisInstallRun": { L in return autoreleasepool { return PsiLuaEnv.sisInstallRun(L) } },
        ]
        L.setfuncs(fns, nup: 1)
    }

    internal static let sisGetStubs: lua_CFunction = { (L: LuaState!) -> CInt in
        let wrapper: Wrapper<SisInstallIoHandler> = L.touserdata(lua_upvalueindex(1))!
        let iohandler = wrapper.value
        let result = iohandler.sisGetStubs()
        switch result {
        case .stubs(let stubs):
            try! L.push(encodable: stubs)
            return 1
        case .epocError(let err):
            L.pushnil()
            L.push(err)
            return 2
        case .notImplemented:
            L.push("notimplemented")
            return 1
        }
    }

    internal static let sisInstallBegin: lua_CFunction = { (L: LuaState!) -> CInt in
        let wrapper: Wrapper<SisInstallIoHandler> = L.touserdata(lua_upvalueindex(1))!
        let iohandler = wrapper.value
        guard let info: Sis.File = L.todecodable(1) else {
            print("Bad SIS info!")
            return 0
        }
        guard let context: Sis.BeginContext = L.todecodable(2) else {
            print("Bad BeginContext!")
            return 0
        }
        let result = iohandler.sisInstallBegin(sis: info, context: context)
        L.push(result)
        return 1
    }

    internal static let sisInstallRollback: lua_CFunction = { (L: LuaState!) -> CInt in
        let wrapper: Wrapper<SisInstallIoHandler> = L.touserdata(lua_upvalueindex(1))!
        let iohandler = wrapper.value
        guard let info: Sis.File = L.todecodable(1) else {
            print("Bad SIS info!")
            return 0
        }
        let result = iohandler.sisInstallRollback(sis: info)
        L.push(result)
        return 1
    }

    internal static let sisInstallComplete: lua_CFunction = { (L: LuaState!) -> CInt in
        let wrapper: Wrapper<SisInstallIoHandler> = L.touserdata(lua_upvalueindex(1))!
        let iohandler = wrapper.value
        guard let info: Sis.File = L.todecodable(1) else {
            print("Bad SIS info!")
            return 0
        }
        iohandler.sisInstallComplete(sis: info)
        return 0
    }

    internal static let sisInstallQuery: lua_CFunction = { (L: LuaState!) -> CInt in
        let wrapper: Wrapper<SisInstallIoHandler> = L.touserdata(lua_upvalueindex(1))!
        let iohandler = wrapper.value
        guard let info: Sis.File = L.todecodable(1) else {
            print("Bad SIS info!")
            return 0
        }
        guard let text = L.tostring(2) else {
            print("Bad text!")
            return 0
        }
        let fixLineEndings = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard let queryString = L.tostring(3),
              let queryType = Sis.QueryType(rawValue: queryString)
        else {
            print("Unknown queryType \(L.tostring(3, convert: true)!)")
            return 0
        }
        let result = iohandler.sisInstallQuery(sis: info, text: fixLineEndings, type: queryType)
        L.push(result)
        return 1
    }

    internal static let sisInstallRun: lua_CFunction = { (L: LuaState!) -> CInt in
        let iohandler: Wrapper<SisInstallIoHandler> = L.touserdata(lua_upvalueindex(1))!
        guard let info: Sis.File = L.todecodable(1) else {
            print("Bad SIS info!")
            return 0
        }
        guard let path = L.tostring(2),
              let flags = L.toint(3) else {
            print("Bad sisInstallRun params")
            return 0
        }
        iohandler.value.sisInstallRun(sis: info, path: path, flags: Sis.RunFlags(rawValue: flags))
        return 0
    }

}

fileprivate class Wrapper<T>: PushableWithMetatable {
    init(value: T) {
        self.value = value
    }
    static var metatable: Metatable<Wrapper<T>> {
        return .init()
    }

    let value: T
}

internal extension LuaState {
    func toAppInfo(_ index: CInt) -> PsiLuaEnv.AppInfo? {
        let L = self
        if isnoneornil(index) {
            return nil
        }
        let era: PsiLuaEnv.AppEra = L.getdecodable(index, key: "era") ?? .er5
        let encoding = era == .er5 ? kDefaultEpocEncoding : kSiboEncoding
        L.rawget(index, key: "captions")
        var captions: [PsiLuaEnv.LocalizedString] = []
        for (languageIndex, captionIndex) in L.pairs(-1) {
            guard let language = L.tostring(languageIndex),
                  let caption = L.tostring(captionIndex, encoding: encoding)
            else {
                return nil
            }
            captions.append(.init(caption, locale: Locale(identifier: language)))
        }
        L.pop()

        guard let uid3 = L.toint(index, key: "uid3") else {
            return nil
        }

        L.rawget(index, key: "icons")
        var icons: [Graphics.MaskedBitmap] = []
        // Need to refactor the Lua data structure before we can make MaskedBitmap decodable
        for _ in L.ipairs(-1) {
            if let bmp = L.todecodable(-1, type: Graphics.Bitmap.self) {
                var mask: Graphics.Bitmap? = nil
                if L.rawget(-1, key: "mask") == .table {
                    mask = L.todecodable(-1)
                }
                L.pop()
                icons.append(Graphics.MaskedBitmap(bitmap: bmp, mask: mask))
            }
        }
        L.pop() // icons
        return PsiLuaEnv.AppInfo(captions: captions, uid3: UInt32(uid3), icons: icons, era: era)
    }
}

extension Sis.InstallError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .userCancelled: return "SisInstallError.userCancelled"
        case .epocError(let err, let context): return "SisInstallError.epocError(\(err), \(context ?? "''"))"
        case .isStub: return "SisInstallError.isStub"
        case .internalError(let err): return "SisInstallError.internalError(\(err))"
        }
    }
}

extension Sis.InstallError: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case code
        case context
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(String.self, forKey: .type)
        switch type {
        case "usercancel":
            self = .userCancelled
        case "epocerr":
            let code: Int32 = try values.decode(Int32.self, forKey: .code)
            let path = try values.decode(String?.self, forKey: .context)
            self = .epocError(code, path)
        case "internal":
            let details = try values.decode(String.self, forKey: .context)
            self = .internalError(details)
        case "stub":
            self = .isStub
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unhandled type \(type)"))
        }

    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .userCancelled:
            try container.encode("usercancel", forKey: .type)
        case .epocError(let err, let path):
            try container.encode("epocerr", forKey: .type)
            try container.encode(err, forKey: .code)
            try container.encode(path, forKey: .context)
        case .internalError(let details):
            try container.encode("internal", forKey: .type)
            try container.encode(details, forKey: .context)
        case .isStub:
            try container.encode("stub", forKey: .type)
        }
    }

}

extension Sis.BeginResult: Pushable {
    public func push(onto L: LuaState) {
        L.newtable()
        switch self {
        case .skipInstall:
            L.rawset(-1, key: "type", value: "skip")
        case .userCancelled:
            L.rawset(-1, key: "type", value: "usercancel")
        case .epocError(let err):
            L.rawset(-1, key: "type", value: "epocerr")
            L.rawset(-1, key: "code", value: err)
        case .install(let lang, let drive):
            L.rawset(-1, key: "type", value: "install")
            L.rawset(-1, key: "lang", value: lang)
            L.rawset(-1, key: "drive", value: drive)
        }
    }
}

extension Sis.InstallError: Pushable {
    public func push(onto state: LuaState) {
        try! state.push(encodable: self)
    }
}

extension Sis.Version: Comparable {
    public static func < (lhs: Sis.Version, rhs: Sis.Version) -> Bool {
        return lhs.major < rhs.major || (lhs.major == rhs.major && lhs.minor < rhs.minor)
    }

    public static func == (lhs: Sis.Version, rhs: Sis.Version) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor
    }
}

extension Sis.Version: CustomStringConvertible {
    public var description: String {
        return String(format: "%d.%02d", major, minor)
    }
}
