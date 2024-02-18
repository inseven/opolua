// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
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
private let kDefaultEpocEncoding: LuaStringEncoding = .stringEncoding(.windowsCP1252)
// And SIBO uses CP850 (which is handled completely differently and has an inconsistent name to boot)
private let kSiboEncoding: LuaStringEncoding = .cfStringEncoding(.dosLatin1)

private extension LuaState {
    func toAppInfo(_ index: CInt) -> OpoInterpreter.AppInfo? {
        let L = self
        if isnoneornil(index) {
            return nil
        }
        let era: OpoInterpreter.AppEra = L.getdecodable(index, key: "era") ?? .er5
        let encoding = era == .er5 ? kDefaultEpocEncoding : kSiboEncoding
        L.rawget(index, key: "captions")
        var captions: [OpoInterpreter.LocalizedString] = []
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
        return OpoInterpreter.AppInfo(captions: captions, uid3: UInt32(uid3), icons: icons, era: era)
    }
}

private func traceHandler(_ L: LuaState!) -> CInt {
    L.settop(1)
    if L.type(1) != .table {
        // Create a table
        lua_newtable(L)
        // We shouldn't be getting eg raw numbers-as-leave-codes being thrown here
        let msg = L.tostring(1) ?? "(No error message)"
        L.rawset(-1, key: "msg", value: msg)
        lua_remove(L, 1)
    }

    // Position 1 is now definitely a table. See if needs a stacktrace.
    if L.tostring(1, key: "luaStack") == nil {
        luaL_traceback(L, L, nil, 1)
        L.rawset(-2, key: "luaStack")
    }
    return 1
}

private func getInterpreterUpval(_ L: LuaState!) -> OpoInterpreter {
    let rawPtr = lua_topointer(L, lua_upvalueindex(1))!
    return Unmanaged<OpoInterpreter>.fromOpaque(rawPtr).takeUnretainedValue()
}

// private func print_lua(_ L: LuaState!) -> CInt {
//     let iohandler = getInterpreterUpval(L).iohandler
//     iohandler.printValue(L.tostring(1, convert: true) ?? "<<STRING DECODE ERR>>")
//     return 0
// }

private func beep(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    if let err = iohandler.beep(frequency: lua_tonumber(L, 1), duration: lua_tonumber(L, 2)) {
        L.pushnil()
        L.push(err.detailIfPresent)
        return 2
    } else {
        L.push(true)
        return 1
    }
}

private func editValue(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    let params = L.todecodable(1, type: EditParams.self)!
    let result = iohandler.editValue(params)
    L.push(result)
    return 1
}

private func draw(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    var ops: [Graphics.DrawCommand] = []
    for _ in L.ipairs(1) {
        let id = Graphics.DrawableId(value: L.toint(-1, key: "id") ?? 1)
        let t = L.tostring(-1, key: "type") ?? ""
        let origin = L.todecodable(-1, type: Graphics.Point.self) ?? .zero
        guard let color: Graphics.Color = L.getdecodable(-1, key: "color") else {
            print("missing color")
            continue
        }
        guard let bgcolor: Graphics.Color = L.getdecodable(-1, key: "bgcolor") else {
            print("missing bgcolor")
            continue
        }
        var mode = Graphics.Mode(rawValue: L.toint(-1, key: "mode") ?? 0) ?? .set
        let penWidth = L.toint(-1, key: "penwidth") ?? 1
        let greyMode: Graphics.GreyMode = L.getdecodable(-1, key: "greyMode") ?? .normal
        let optype: Graphics.DrawCommand.OpType
        switch (t) {
        case "fill":
            let size = Graphics.Size(width: L.toint(-1, key: "width") ?? 0, height: L.toint(-1, key: "height") ?? 0)
            optype = .fill(size)
        case "invert":
            let size = Graphics.Size(width: L.toint(-1, key: "width") ?? 0, height: L.toint(-1, key: "height") ?? 0)
            optype = .invert(size)
        case "circle":
            optype = .circle(L.toint(-1, key: "r") ?? 0, L.toboolean(-1, key: "fill"))
        case "ellipse":
            optype = .ellipse(L.toint(-1, key: "hradius") ?? 0, L.toint(-1, key: "vradius") ?? 0, L.toboolean(-1, key: "fill"))
        case "line":
            optype = .line(Graphics.Point(x: L.toint(-1, key: "x2") ?? 0, y: L.toint(-1, key: "y2") ?? 0))
        case "box":
            let size = Graphics.Size(width: L.toint(-1, key: "width") ?? 0, height: L.toint(-1, key: "height") ?? 0)
            optype = .box(size)
        case "bitblt":
            if let bitmap: Graphics.Bitmap = L.getdecodable(-1, key: "bitmap") {
                optype = .bitblt(bitmap)
            } else {
                print("Missing params in bitblt!")
                continue
            }
        case "copy":
            if let width = L.toint(-1, key: "width"),
               let height = L.toint(-1, key: "height"),
               let srcx = L.toint(-1, key: "srcx"),
               let srcy = L.toint(-1, key: "srcy"),
               let srcid = L.toint(-1, key: "srcid"),
               let _ = L.toint(-1, key: "mode") {
                let size = Graphics.Size(width: width, height: height)
                let rect = Graphics.Rect(origin: Graphics.Point(x: srcx, y: srcy), size: size)
                let drawable = Graphics.DrawableId(value: srcid)
                let info = Graphics.CopySource(drawableId: drawable, rect: rect)
                let maskInfo: Graphics.CopySource?
                let maskId = L.toint(-1, key: "mask") ?? 0
                if maskId > 0 {
                    let maskDrawable = Graphics.DrawableId(value: maskId)
                    maskInfo = Graphics.CopySource(drawableId: maskDrawable, rect: rect)
                } else {
                    maskInfo = nil
                }
                optype = .copy(info, maskInfo)
            } else {
                print("Missing params in copy!")
                continue
            }
        case "scroll":
            let dx = L.toint(-1, key: "dx") ?? 0
            let dy = L.toint(-1, key: "dy") ?? 0
            guard let rect: Graphics.Rect = L.getdecodable(-1, key: "rect") else {
                print("Bad rect param in scroll!")
                continue
            }
            optype = .scroll(dx, dy, rect)
        case "patt":
            if let srcid = L.toint(-1, key: "srcid"),
               let w = L.toint(-1, key: "width"),
               let h = L.toint(-1, key: "height") {
                let size = Graphics.Size(width: w, height: h)
                let rect = Graphics.Rect(origin: origin, size: size)
                let drawable = Graphics.DrawableId(value: srcid)
                let info = Graphics.CopySource(drawableId: drawable, rect: rect)
                optype = .pattern(info)
            } else {
                print("Missing params in patt!")
                continue
            }
        case "text":
            let str = L.tostring(-1, key: "string") ?? ""
            mode = Graphics.Mode(rawValue: L.toint(-1, key: "tmode") ?? 0) ?? .set
            let xstyle: Graphics.XStyle? = L.getdecodable(-1, key: "xflags")
            if let fontInfo: Graphics.FontInfo = L.getdecodable(-1, key: "fontinfo") {
                optype = .text(str, fontInfo, xstyle)
            } else {
                print("Bad text params!")
                continue
            }
        case "border":
            let size = Graphics.Size(width: L.toint(-1, key: "width") ?? 0, height: L.toint(-1, key: "height") ?? 0)
            let rect = Graphics.Rect(origin: origin, size: size)
            let type = L.toint(-1, key: "btype") ?? 0
            if let borderType = Graphics.BorderType(rawValue: type) {
                optype = .border(rect, borderType)
            } else {
                print("Unknown border type \(type)")
                continue
            }
        default:
            print("Unknown Graphics.DrawCommand.OpType \(t)")
            continue
        }
        ops.append(Graphics.DrawCommand(drawableId: id, type: optype, mode: mode, origin: origin, color: color,
                                        bgcolor: bgcolor, penWidth: penWidth, greyMode: greyMode))
    }
    iohandler.draw(operations: ops)
    return 0
}

func doGraphicsOp(_ L: LuaState!, _ iohandler: OpoIoHandler, _ op: Graphics.Operation) -> CInt {
    let result = iohandler.graphicsop(op)
    switch result {
    case .nothing:
        return 0
    case .textMetrics(let metrics):
        L.push(metrics.size.width)
        L.push(metrics.size.height)
        L.push(metrics.ascent)
        L.push(metrics.descent)
        return 4
    case .peekedData(let data):
        L.push(data)
        return 1
    }
}

// graphicsop(cmd, ...)
// graphicsop("close", drawableId)
// graphicsop("show", drawableId, flag)
// graphicsop("order", drawableId, pos)
// graphicsop("textsize", str, font, style)
// graphicsop("busy", drawableId, delay)
// graphicsop("giprint", drawableId)
// graphicsop("setwin", drawableId, x, y, [w, h])
// graphicsop("sprite", windowId, id, [sprite])
// graphicsop("title", appTitle)
// graphicsop("clock", drawableId, [{mode=, x=, y=}])
// graphicsop("peekline", drawableId, x, y, numPixels, mode)
private func graphicsop(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    let cmd = L.tostring(1) ?? ""
    switch cmd {
    case "close":
        if let id = L.toint(2) {
            let drawableId = Graphics.DrawableId(value: id)
            return doGraphicsOp(L, iohandler, .close(drawableId))
        } else {
            print("Bad drawableId to close graphicsop!")
        }
    case "show":
        if let id = L.toint(2) {
            let drawableId = Graphics.DrawableId(value: id)
            let flag = L.toboolean(3)
            return doGraphicsOp(L, iohandler, .show(drawableId, flag))
        } else {
            print("Bad drawableId to show graphicsop!")
        }
    case "order":
        if let id = L.toint(2),
           let position = L.toint(3) {
            let drawableId = Graphics.DrawableId(value: id)
            return doGraphicsOp(L, iohandler, .order(drawableId, position))
        } else {
            print("order graphicsop missing arguments!")
        }
    case "textsize":
        let str = L.tostring(2) ?? ""
        var flags = Graphics.FontFlags(rawValue: L.toint(4) ?? 0)
        if L.toboolean(3, key: "bold") {
            flags.insert(.boldHint)
        }
        if let fontName = L.tostring(3, key: "face"),
           let face = Graphics.FontFace(rawValue: fontName),
           let size = L.toint(3, key: "size"),
           let uid = L.toint(3, key: "uid") {
            let info = Graphics.FontInfo(uid: UInt32(uid), face: face, size: size, flags: flags)
            return doGraphicsOp(L, iohandler, .textSize(str, info))
        } else {
            print("Bad args to textsize!")
        }
    case "busy":
        let id = L.toint(2) ?? 0
        let drawableId = Graphics.DrawableId(value: id)
        let delay = (L.toint(3) ?? 0) * 500
        return doGraphicsOp(L, iohandler, .busy(drawableId, delay))
    case "giprint":
        let id = L.toint(2) ?? 0
        let drawableId = Graphics.DrawableId(value: id)
        return doGraphicsOp(L, iohandler, .giprint(drawableId))
    case "setwin":
        if let id = L.toint(2),
           let x = L.toint(3),
           let y = L.toint(4) {
            let drawableId = Graphics.DrawableId(value: id)
            let pos = Graphics.Point(x: x, y: y)
            let size: Graphics.Size?
            if let w = L.toint(5), let h = L.toint(6) {
                size = Graphics.Size(width: w, height: h)
            } else {
                size = nil
            }
            return doGraphicsOp(L, iohandler, .setwin(drawableId, pos, size))
        } else {
            print("Bad args to setwin")
        }
    case "sprite":
        guard let winId = L.toint(2),
              let spriteId = L.toint(3)
        else {
            print("Bad id for sprite")
            break
        }
        let window = Graphics.DrawableId(value: winId)
        let sprite: Graphics.Sprite? = L.todecodable(4)
        return doGraphicsOp(L, iohandler, .sprite(window, spriteId, sprite))
    case "clock":
        let drawableId = Graphics.DrawableId(value: L.toint(2) ?? 0)
        let clockInfo: Graphics.ClockInfo? = L.todecodable(3)
        return doGraphicsOp(L, iohandler, .clock(drawableId, clockInfo))
    case "peekline":
        if let id = L.toint(2),
           let x = L.toint(3),
           let y = L.toint(4),
           let numPixels = L.toint(5),
           let rawMode = L.toint(6),
           let mode = Graphics.PeekMode(rawValue: rawMode) {
            let drawableId = Graphics.DrawableId(value: id)
            let pos = Graphics.Point(x: x, y: y)
            return doGraphicsOp(L, iohandler, .peekline(drawableId, pos, numPixels, mode))
        } else {
            print("Missing peekline params!")
            break
        }
    default:
        print("Unknown graphicsop \(cmd)!")
    }
    return 0
}

private func getScreenInfo(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    let (sz, mode) = iohandler.getScreenInfo()
    L.push(sz.width)
    L.push(sz.height)
    L.push(mode.rawValue)
    return 3
}

private func fsop(_ L: LuaState!) -> CInt {
    let interpreter = getInterpreterUpval(L)
    let iohandler = interpreter.iohandler
    guard let cmd = L.tostring(1) else {
        return 0
    }
    guard let path = L.tostring(2) else {
        return 0
    }
    let op: Fs.Operation.OpType
    switch cmd {
    case "exists":
        op = .exists
    case "stat":
        op = .stat
    case "isdir":
        op = .isdir
    case "delete":
        op = .delete
    case "mkdir":
        op = .mkdir
    case "rmdir":
        op = .rmdir
    case "write":
        guard let data = L.todata(3) else {
            return 0
        }
        op = .write(Data(data))

        // Special case writing to the clipboard
        if path.caseInsensitiveCompare("c:\\system\\data\\clpboard.cbd") == .orderedSame {
            switch interpreter.getFileInfo(data: Data(data)) {
            case .text(let text):
                iohandler.setConfig(key: .clipboard, value: text.text)
            default:
                print("Failed to parse clipboard data from \(path)")
            }
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
    case .err(let err):
        if err != .none {
            print("Error \(err) for cmd \(op) path \(path)")
        }
        if cmd == "read" || cmd == "dir" || cmd == "stat" {
            L.pushnil()
            L.push(err.rawValue)
            return 2
        } else {
            L.push(err.rawValue)
            return 1
        }
    case .data(let data):
        L.push(data)
        return 1
    case .strings(let strings):
        lua_createtable(L, CInt(strings.count), 0)
        for (i, string) in strings.enumerated() {
            L.rawset(-1, key: i + 1, value: string)
        }
        return 1
    case .stat(let stat):
        lua_newtable(L)
        L.rawset(-1, key: "size", value: Int64(stat.size))
        L.rawset(-1, key: "lastModified", value: stat.lastModified.timeIntervalSince1970)
        return 1
    }
}

// asyncRequest(requestName, requestTable)
// asyncRequest("getevent", { var = ..., ev = ... })
// asyncRequest("after", { var = ..., period = ... })
// asyncRequest("at", { var = ..., time = ...})
// asyncRequest("playsound", { var = ..., data = ... })
private func asyncRequest(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    guard let name = L.tostring(1) else { return 0 }
    L.settop(2)
    lua_remove(L, 1) // Removes name, so requestTable is now at position 1
    L.rawset(-1, key: "type", value: name) // requestTable.type = name
    L.rawget(1, key: "var") // Put var at 2 for compat with code below

    let type: Async.RequestType
    switch name {
    case "getevent":
        type = .getevent
    case "after":
        guard let period = L.toint(1, key: "period") else {
            print("Bad param to after asyncRequest")
            return 0
        }
        let interval = Double(period) / 1000
        type = .after(interval)
    case "at":
        guard let time = L.toint(1, key: "time") else {
            print("Bad param to at asyncRequest")
            return 0
        }
        let date = Date(timeIntervalSince1970: Double(time))
        type = .at(date)
    case "playsound":
        guard let data = L.todata(1, key: "data") else {
            print("Bad param to playsound asyncRequest")
            return 0
        }
        type = .playsound(Data(data))
    default:
        fatalError("Unhandled asyncRequest type \(name)")
    }

    // Use registry ref to map swift int to requestTable
    // Then set registry[statusVar:uniqueKey()] = requestTable
    // That way both Lua and swift sides can look up the request

    lua_pushvalue(L, 1) // dup requestTable
    let requestHandle = luaL_ref(L, LUA_REGISTRYINDEX) // pop dup, registry[requestHandle] = requestTable
    L.rawset(1, key: "ref", value: requestHandle) // requestTable.ref = requestHandle

    lua_pushvalue(L, 2) // dup statusVar
    luaL_callmeta(L, -1, "uniqueKey")
    lua_remove(L, -2) // remove the dup statusVar
    lua_pushvalue(L, 1) // dup requestTable
    L.rawset(LUA_REGISTRYINDEX) // registry[statusVar:uniqueKey()] = requestTable

    let req = Async.Request(type: type, handle: requestHandle)

    iohandler.asyncRequest(req)
    return 0
}

// As per init.lua
private let KOplErrIOCancelled = -48
private let KStopErr = -999

private func checkCompletions(_ L: LuaState!) -> CInt {
    let interpreter = getInterpreterUpval(L)
    let iohandler = interpreter.iohandler
    var count = 0
    while true {
        if let response = iohandler.anyRequest() {
            interpreter.completeRequest(L, response)
            count = count + 1
        } else {
            break
        }
    }
    L.push(count)
    return 1
}

private func waitForAnyRequest(_ L: LuaState!) -> CInt {
    let interpreter = getInterpreterUpval(L)
    let iohandler = interpreter.iohandler
    let response = iohandler.waitForAnyRequest()
    if case .interrupt = response.value {
        L.push(false)
    } else {
        interpreter.completeRequest(L, response)
    }
    L.push(true)
    return 1
}

private func cancelRequest(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    L.settop(1)
    luaL_callmeta(L, -1, "uniqueKey")
    let t = lua_gettable(L, LUA_REGISTRYINDEX) // 2: registry[statusVar:uniqueKey()] -> requestTable
    if t == LUA_TNIL {
        // Request must've already been completed in waitForAnyRequest
        return 0
    } else {
        assert(t == LUA_TTABLE, "Unexpected type for registry requestTable!")
    }
    L.rawget(2, key: "ref")
    if let requestHandle = L.toint(-1) {
        iohandler.cancelRequest(Int32(requestHandle))
    } else {
        print("Bad type for requestTable.ref!")
    }
    return 0
}

private func testEvent(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    L.push(iohandler.testEvent())
    return 1
}

private func createBitmap(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    guard let id = L.toint(1),
          let width = L.toint(2),
          let height = L.toint(3),
          let modeVal = L.toint(4),
          let mode = Graphics.Bitmap.Mode(rawValue: modeVal) else {
        print("Bad parameters to createBitmap")
        return 0
    }
    let drawableId = Graphics.DrawableId(value: id)
    let size = Graphics.Size(width: width, height: height)
    return doGraphicsOp(L, iohandler, .createBitmap(drawableId, size, mode))
}

private func createWindow(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    guard let id = L.toint(1),
          let x = L.toint(2), let y = L.toint(3),
          let width = L.toint(4), let height = L.toint(5),
          let flags = L.toint(6),
          let mode = Graphics.Bitmap.Mode(rawValue: flags & 0xF) else {
        return 0
    }

    var shadow = 0
    if flags & 0xF0 != 0 {
        shadow = 2 * ((flags & 0xF00) >> 8)
    }
    let drawableId = Graphics.DrawableId(value: id)
    let rect = Graphics.Rect(x: x, y: y, width: width, height: height)
    return doGraphicsOp(L, iohandler, .createWindow(drawableId, rect, mode, shadow))
}

private func getTime(_ L: LuaState!) -> CInt {
    let dt = Date()
    L.push(dt.timeIntervalSince1970)
    return 1
}

private func key(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    if let event = iohandler.key(), let charcode = event.keycode.toCharcode() {
        L.push(charcode)
        L.push(event.modifiers.rawValue)
    } else {
        L.push(0)
        L.push(0)
    }
    return 2
}

private func keysDown(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    let keys = iohandler.keysDown()
    lua_createtable(L, 0, CInt(keys.count))
    for key in keys {
        L.rawset(-1, key: key.rawValue, value: true)
    }
    return 1
}

private func opsync(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.opsync()
    return 0
}

private func getConfig(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    if let keyName = L.tostring(1),
       let key = ConfigName(rawValue: keyName) {
        L.push(iohandler.getConfig(key: key))
        return 1
    } else {
        print("Bad keyname to getConfig")
        return 0
    }    
}

private func setConfig(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    if let keyName = L.tostring(1),
       let key = ConfigName(rawValue: keyName),
       let val = L.tostring(2) {
        iohandler.setConfig(key: key, value: val)
    } else {
        print("Bad key/val to setConfig")
    }    
    return 0
}

private func setAppTitle(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    if let title = L.tostring(1) {
        iohandler.setAppTitle(title)
    }
    return 0
}

private func displayTaskList(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.displayTaskList()
    return 0
}

private func setForeground(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.setForeground()
    return 0
}

private func setBackground(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.setBackground()
    return 0
}

private func stop(_ L: LuaState!, _: UnsafeMutablePointer<lua_Debug>!) {
    print("Stop hook called, exiting interpreter with error(KStopErr)")
    lua_sethook(L, nil, 0, 0)
    L.push(KStopErr)
    lua_error(L)
}

private func runApp(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    guard let prog = L.tostring(1), let doc = L.tostring(2) else {
        return 0
    }
    let result = iohandler.runApp(name: prog, document: doc)
    L.push(result)
    return 1
}

private func getTimeField(_ L: LuaState!, _ key: String) -> Int32? {
    guard let result = L.toint(-1, key: key) else {
        return nil
    }
    if result < -Int32.max/2 || result > Int32.max/2 {
        return nil // Should really error here...
    }
    return Int32(result)
}

private func utctime(_ L: LuaState!) -> CInt {
    // Really annoying Lua can't/won't use timegm...
    var ts = tm()
    luaL_checktype(L, 1, LUA_TTABLE)
    L.settop(1)  /* make sure table is at the top */
    ts.tm_sec = getTimeField(L, "sec") ?? 0
    ts.tm_min = getTimeField(L, "min") ?? 0
    ts.tm_hour = getTimeField(L, "hour") ?? 12
    guard let day = getTimeField(L, "day"),
          let mon = getTimeField(L, "month"),
          let year = getTimeField(L, "year")
    else {
        L.pushnil()
        L.push("missing field!")
        return 2
    }
    ts.tm_mday = day
    ts.tm_mon = mon - 1
    ts.tm_year = year - 1900
    let t = timegm(&ts)
    if t == -1 {
        L.pushnil()
        L.push("time result cannot be represented")
        return 2
    }
    L.push(t)
    return 1
}

private func setEra(_ L: LuaState!) -> CInt {
    if let era: OpoInterpreter.AppEra = L.todecodable(1) {
        switch era {
        case .sibo:
            L.setDefaultStringEncoding(kSiboEncoding)
        case .er5:
            L.setDefaultStringEncoding(kDefaultEpocEncoding)
        }
    }
    return 0
}

private extension Error {
    var detailIfPresent: String {
        if let err = self as? OpoInterpreter.InterpreterError {
            return err.detail
        } else {
            return self.localizedDescription
        }
    }
}

class OpoInterpreter {

    private let L: LuaState
    var iohandler: OpoIoHandler

    init() {
        iohandler = DummyIoHandler() // For now...
        L = LuaState(libraries: [.package, .table, .io, .os, .string, .math, .utf8, .debug])
        L.setDefaultStringEncoding(kDefaultEpocEncoding)

        L.setRequireRoot(nil)
        L.addModules(lua_sources)

        // Finally, run init.lua
        L.getglobal("require")
        L.push("init")
        guard logpcall(1, 0) else {
            fatalError("Failed to load init.lua!")
        }

        assert(L.gettop() == 0) // In case we failed to balance stack during init
    }

    deinit {
        L.close()
    }

    // throws an InterpreterError or subclass thereof
    func pcall(_ narg: CInt, _ nret: CInt) throws {
        let base = L.gettop() - narg // Where the function is, and where the msghandler will be
        lua_pushcfunction(L, traceHandler)
        lua_insert(L, base)
        let err = lua_pcall(L, narg, nret, base);
        lua_remove(L, base) // remove msghandler
        if err != 0 {
            assert(L.type(-1) == .table) // Otherwise our traceHandler isn't doing its job
            let msg = L.tostring(-1, key: "msg")!
            var detail = msg
            if let opoStack = L.tostring(-1, key: "opoStack") {
                detail = "\(detail)\n\(opoStack)"
            }
            if let luaStack = L.tostring(-1, key: "luaStack") {
                detail = "\(detail)\n\(luaStack)"
            }
            print(detail)
            let error: InterpreterError
            if let operation = L.tostring(-1, key: "unimplemented") {
                if operation == "database.loadBinary" {
                    // Special case as it's such a significant issue
                    error = BinaryDatabaseError(message: msg, detail: detail, operation: operation)
                } else {
                    error = UnimplementedOperationError(message: msg, detail: detail, operation: operation)
                }
            } else if L.toboolean(-1, key: "notOpl") {
                error = NativeBinaryError(message: msg, detail: detail)
            } else {
                error = InterpreterError(message: msg, detail: detail)
            }
            L.pop() // the error object
            throw error
        }
    }

    func logpcall(_ narg: CInt, _ nret: CInt) -> Bool {
        do {
            try pcall(narg, nret)
            return true
        } catch {
            print("Error: \(error.detailIfPresent)")
            return false
        }
    }

    func makeIoHandlerBridge() {
        lua_newtable(L)
        let val = Unmanaged<OpoInterpreter>.passUnretained(self)
        lua_pushlightuserdata(L, val.toOpaque())
        let fns: [String: lua_CFunction] = [
            "editValue": { L in return autoreleasepool { return editValue(L) } },
            // "print": { L in return autoreleasepool { return print_lua(L) } },
            "beep": { L in return autoreleasepool { return beep(L) } },
            "draw": { L in return autoreleasepool { return draw(L) } },
            "graphicsop": { L in return autoreleasepool { return graphicsop(L) } },
            "getScreenInfo": { L in return autoreleasepool { return getScreenInfo(L) } },
            "fsop": { L in return autoreleasepool { return fsop(L) } },
            "asyncRequest": { L in return autoreleasepool { return asyncRequest(L) } },
            "waitForAnyRequest": { L in return autoreleasepool { return waitForAnyRequest(L) } },
            "checkCompletions": { L in return autoreleasepool { return checkCompletions(L) } },
            "testEvent": { L in return autoreleasepool { return testEvent(L) } },
            "cancelRequest": { L in return autoreleasepool { return cancelRequest(L) } },
            "createBitmap": { L in return autoreleasepool { return createBitmap(L) } },
            "createWindow": { L in return autoreleasepool { return createWindow(L) } },
            "getTime": { L in return autoreleasepool { return getTime(L) } },
            "key": { L in return autoreleasepool { return key(L) } },
            "keysDown": { L in return autoreleasepool { return keysDown(L) } },
            "opsync": { L in return autoreleasepool { return opsync(L) } },
            "getConfig": { L in return autoreleasepool { return getConfig(L) } },
            "setConfig": { L in return autoreleasepool { return setConfig(L) } },
            "setAppTitle": { L in return autoreleasepool { return setAppTitle(L) } },
            "displayTaskList": { L in return autoreleasepool { return displayTaskList(L) } },
            "setForeground": { L in return autoreleasepool { return setForeground(L) } },
            "setBackground": { L in return autoreleasepool { return setBackground(L) } },
            "runApp": { L in return autoreleasepool { return runApp(L) } },
            "utctime": { L in return autoreleasepool { return utctime(L) } },
            "setEra": { L in return autoreleasepool { return setEra(L) } },
        ]
        L.setfuncs(fns, nup: 1)
    }

    enum ValType: Int {
        case Word = 0
        case Long = 1
        case Real = 2
        case String = 3
        case WordArray = 0x80
        case ELongArray = 0x81
        case ERealArray = 0x82
        case EStringArray = 0x83
    }

    struct Procedure {
        let name: String
        let arguments: [ValType]
    }

    func getProcedures(file: String) -> [Procedure]? {
        guard let data = FileManager.default.contents(atPath: file) else {
            return nil
        }
        L.getglobal("require")
        L.push("opofile")
        guard logpcall(1, 1) else { return nil }
        L.rawget(-1, key: "parseOpo")
        L.push(data)
        guard logpcall(1, 1) else {
            L.pop() // opofile
            return nil
        }
        var procs: [Procedure] = []
        for _ in L.ipairs(-1) {
            let name = L.tostring(-1, key: "name")!
            var args: [ValType] = []
            if L.rawget(-1, key: "params") == .table {
                for _ in L.ipairs(-1) {
                    // insert at front because params are listed bass-ackwards
                    args.insert(ValType(rawValue: L.toint(-1)!)!, at: 0)
                }
            }
            L.pop() // params
            procs.append(Procedure(name: name, arguments: args))
        }
        L.pop(2) // procs, opofile
        return procs
    }

    struct LocalizedString {
        var value: String
        var locale: Locale

        init(_ value: String, locale: Locale) {
            self.value = value
            self.locale = locale
        }
    }

    enum AppEra: String, Codable {
        case sibo
        case er5
    }

    struct AppInfo {
        let captions: [LocalizedString]
        let uid3: UInt32
        let icons: [Graphics.MaskedBitmap]
        let era: AppEra
    }

    func appInfo(for path: String) -> AppInfo? {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        L.getglobal("require")
        L.push("aif")
        guard logpcall(1, 1) else { return nil }
        L.rawget(-1, key: "parseAif")
        lua_remove(L, -2) // aif module
        L.push(data)
        guard logpcall(1, 1) else { return nil }

        return L.toAppInfo(-1)
    }

    func getMbmBitmaps(path: String) -> [Graphics.Bitmap]? {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        L.getglobal("require")
        L.push("recognizer")
        guard logpcall(1, 1) else { return nil }
        L.rawget(-1, key: "getMbmBitmaps")
        lua_remove(L, -2) // recognizer module
        L.push(data)
        guard logpcall(1, 1) else { return nil }
        // top of stack should now be bitmap array
        let result: [Graphics.Bitmap]? = L.todecodable(-1)
        return result
    }

    class InterpreterError: LocalizedError {

        let message: String // One-line description of the error
        let detail: String // Includes all of message, leave code, lua stack trace, opo stacktrace (as appropriate)

        init(message: String) {
            self.message = message
            self.detail = message
        }

        init(message: String, detail: String) {
            self.message = message
            self.detail = detail
        }

        var errorDescription: String? {
            return "The program encountered an internal error."
        }

    }

    class LeaveError: InterpreterError {

        let code: Int

        init(message: String, detail: String, leaveCode: Int) {
            self.code = leaveCode
            super.init(message: message, detail: detail)
        }

    }

    class UnimplementedOperationError: InterpreterError {

        let operation: String

        init(message: String, detail: String, operation: String) {
            self.operation = operation
            super.init(message: message, detail: detail)
        }

        override var errorDescription: String? {
            return "The program attempted to use the unimplemented operation '\(operation)'."
        }

    }

    class BinaryDatabaseError: UnimplementedOperationError {

        override var errorDescription: String? {
            return "Database operations are currently unsupported."
        }

    }

    class NativeBinaryError : InterpreterError {

        override var errorDescription: String? {
            return "This is not an OPL program, and cannot be run."
        }

    }

    func run(devicePath: String, procedureName: String? = nil) throws {
        L.settop(0)

        L.getglobal("require")
        L.push("runtime")
        guard logpcall(1, 1) else { fatalError("Couldn't load runtime") }
        L.rawget(-1, key: "runOpo")
        L.push(devicePath)
        if let proc = procedureName {
            L.push(proc)
        } else {
            L.pushnil()
        }
        makeIoHandlerBridge()
        try pcall(3, 0) // runOpo(devicePath, proc, iohandler)
    }

    // Pen events actually use TEventModifers not TOplModifiers (despite what the documentation says)
    private static func modifiersToTEventModifiers(_ modifiers: Modifiers) -> Int {
        var result: Int = 0
        if modifiers.contains(.shift) {
            result |= 0x500 // EModifierLeftShift | EModifierShift
        }
        if modifiers.contains(.control) {
            result |= 0xA0 // EModifierLeftCtrl | EModifierCtrl
        }
        if modifiers.contains(.capsLock) {
            result |= 0x4000 // EModifierCapsLock
        }
        if modifiers.contains(.fn) {
            result |= 0x2800 // EModifierLeftFunc | EModifierFunc
        }
        return result
    }

    func completeRequest(_ L: LuaState!, _ response: Async.Response) {
        L.settop(0)
        let t = L.rawget(LUA_REGISTRYINDEX, key: response.handle) // 1: registry[requestHandle] -> requestTable
        assert(t == .table, "Failed to locate requestTable for requestHandle \(response.handle)!")

        // Deal with writing any result data

        let type = L.tostring(1, key: "type") ?? ""
        func timestampToInt32(_ timestamp: TimeInterval) -> Int {
            let microsecs = Int(timestamp * 1000000)
            let us32 = UInt32(microsecs % Int(UInt32.max))
            let intVal = Int32(bitPattern: us32)
            return Int(intVal)
        }
        switch type {
        case "getevent":
            var ev = Array<Int>(repeating: 0, count: 9)
            switch (response.value) {
            case .keypressevent(let event):
                // print("keypress \(event.keycode) t=\(event.timestamp) scan=\(event.keycode.toScancode())")
                // Remember, ev[0] here means ev[1] in the OPL docs because they're one-based
                ev[0] = event.modifiedKeycode()!
                ev[1] = timestampToInt32(event.timestamp)
                ev[2] = event.keycode.toScancode()
                ev[3] = event.modifiers.rawValue
                ev[4] = event.isRepeat ? 1 : 0
            case .keydownevent(let event):
                // print("keydown \(event.keycode) t=\(event.timestamp) scan=\(event.keycode.toScancode())")
                ev[0] = 0x406
                ev[1] = timestampToInt32(event.timestamp)
                ev[2] = event.keycode.toScancode()
                ev[3] = event.modifiers.rawValue
            case .keyupevent(let event):
                // print("keyup \(event.keycode) t=\(event.timestamp) scan=\(event.keycode.toScancode())")
                ev[0] = 0x407
                ev[1] = timestampToInt32(event.timestamp)
                ev[2] = event.keycode.toScancode()
                ev[3] = event.modifiers.rawValue
            case .penevent(let event):
                ev[0] = 0x408
                ev[1] = timestampToInt32(event.timestamp)
                ev[2] = event.windowId.value
                ev[3] = event.type.rawValue
                ev[4] = Self.modifiersToTEventModifiers(event.modifiers)
                ev[5] = event.x
                ev[6] = event.y
                ev[7] = event.screenx
                ev[8] = event.screeny
            case .pendownevent(let event):
                ev[0] = 0x409
                ev[1] = timestampToInt32(event.timestamp)
                ev[2] = event.windowId.value
            case .penupevent(let event):
                ev[0] = 0x40A
                ev[1] = timestampToInt32(event.timestamp)
                ev[2] = event.windowId.value
            case .foregrounded(let event):
                ev[0] = 0x401
                ev[1] = timestampToInt32(event.timestamp)
            case .backgrounded(let event):
                ev[0] = 0x402
                ev[1] = timestampToInt32(event.timestamp)
            case .quitevent:
                ev[0] = 0x404
            case .cancelled, .completed, .interrupt:
                break // No completion data for these
            }
            lua_getfield(L, 1, "ev") // Pushes eventArray (as an Addr)
            luaL_getmetafield(L, -1, "writeArray") // Addr:writeArray
            lua_insert(L, -2) // put writeArray below eventArray
            L.push(ev) // ev as a table
            L.push(1) // DataTypes.ELong
            let _ = logpcall(3, 0)
        default:
            break // No data for these
        }

        // Mark statusVar as completed
        let val: Int
        switch (response.value) {
        case .cancelled:
            val = KOplErrIOCancelled
        default:
            val = 0 // Assuming everything is a success completion atm...
        }

        // print("Completing \(type) with value \(val)")

        lua_getfield(L, 1, "var") // statusVar
        L.push(val)
        lua_call(L, 1, 0)

        // Finally, free up requestHandle
        lua_getfield(L, 1, "var")
        luaL_callmeta(L, -1, "uniqueKey")
        lua_pushnil(L)
        lua_settable(L, LUA_REGISTRYINDEX) // registry[statusVar:uniqueKey()] = nil
        luaL_unref(L, LUA_REGISTRYINDEX, response.handle) // registry[requestHandle] = nil

        // And if the caller specified a custom completion fn, call that once everything else has been done
        if lua_getfield(L, 1, "completion") == LUA_TFUNCTION {
            lua_call(L, 0, 0)
        } else {
            lua_pop(L, 1)
        }

        L.settop(0)
    }

    func installSisFile(path: String) throws {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw InterpreterError(message: "Couldn't read \(path)")
        }
        lua_getglobal(L, "require")
        L.push("runtime")
        guard logpcall(1, 1) else { fatalError("Couldn't load runtime") }
        lua_getfield(L, -1, "installSis")
        L.push(data)
        makeIoHandlerBridge()
        try pcall(2, 0)
    }

    // Safe to call from any thread
    func interrupt() {
        lua_sethook(L, stop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT, 1)
    }

    struct UnknownEpocFile: Codable {
        let uid1: UInt32
        let uid2: UInt32
        let uid3: UInt32
    }

    struct MbmFile: Codable {
        let bitmaps: [Graphics.Bitmap]
    }

    struct OplFile: Codable {
        let text: String
    }

    struct SoundFile: Codable {
        let data: Data
    }

    struct TextFile: Codable {
        let text: String
    }

    enum FileType: String, Codable {
        case unknown
        case aif
        case mbm
        case opl
        case sound
        case text
    }

    enum FileInfo {
        case unknown
        case unknownEpoc(UnknownEpocFile)
        case aif(AppInfo)
        case mbm(MbmFile)
        case opl(OplFile)
        case sound(SoundFile)
        case text(TextFile)
    }

    func recognize(path: String) -> FileType {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        // Let's not bother with the optimisation recognizers technically had to only read the first N bytes of a file.
        // Epoc files are tiny by modern standards and it simplifies the code to just read the entire file.
        guard let data = FileManager.default.contents(atPath: path) else {
            return .unknown
        }
        L.getglobal("require")
        L.push("recognizer")
        guard logpcall(1, 1) else {
            return .unknown
        }
        L.rawget(-1, key: "recognize")
        lua_remove(L, -2) // recognizer module
        L.push(data)
        L.push(true) // allData
        guard logpcall(2, 1) else {
            return .unknown
        }
        guard let type = L.tostring(-1) else {
            return .unknown
        }
        return FileType(rawValue: type) ?? .unknown
    }

    func getFileInfo(path: String) -> FileInfo {
        guard let data = FileManager.default.contents(atPath: path) else {
            return .unknown
        }
        return getFileInfo(data: data)
    }

    func getFileInfo(data: Data) -> FileInfo {
        let top = L.gettop()
        defer {
            L.settop(top)
        }
        L.getglobal("require")
        L.push("recognizer")
        guard logpcall(1, 1) else {
            return .unknown
        }
        L.rawget(-1, key: "recognize")
        lua_remove(L, -2) // recognizer module
        L.push(data)
        L.push(true) // allData
        guard logpcall(2, 2) else {
            return .unknown
        }
        guard let type = L.tostring(-2) else {
            return .unknown
        }

        switch type {
        case "aif":
            if let info = L.toAppInfo(-1) {
                return .aif(info)
            }
        case "mbm":
            if let info: MbmFile = L.todecodable(-1) {
                return .mbm(info)
            }
        case "opl":
            if let info: OplFile = L.todecodable(-1) {
                return .opl(info)
            }
        case "sound":
            if let info: SoundFile = L.todecodable(-1) {
                return .sound(info)
            }
        case "unknown":
            if let info: UnknownEpocFile = L.todecodable(-1) {
                return .unknownEpoc(info)
            }
        case "text":
            if let text = L.tostring(-1) {
                return .text(TextFile(text: text))
            }
        default:
            break
        }
        return .unknown
    }
}
