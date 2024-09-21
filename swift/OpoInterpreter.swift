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

private let kDaysFrom1900to1970: Double = 25567

private func editValue(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    let raw: EditOperation.Raw = L.todecodable(1)!
    let details: EditOperation.Details
    switch raw.type {
    case .text:
        details = .text(EditOperation.TextDetails(initialValue: raw.initialValue, maxLen: Int(raw.max!)))
    case .password:
        details = .password(EditOperation.TextDetails(initialValue: raw.initialValue, maxLen: Int(raw.max!)))
    case .integer:
        details = .integer(EditOperation.IntDetails(initialValue: Int(raw.initialValue)!,
                                                    min: Int(raw.min!),
                                                    max: Int(raw.max!)))
    case .float:
        details = .float(EditOperation.FloatDetails(initialValue: Double(raw.initialValue)!,
                                                    min: raw.min!,
                                                    max: raw.max!))
    case .date:
        let date = Date(timeIntervalSince1970: (Double(raw.initialValue)! - kDaysFrom1900to1970) * 86400)
        let min = Date(timeIntervalSince1970: (raw.min! - kDaysFrom1900to1970) * 86400)
        let max = Date(timeIntervalSince1970: (raw.max! - kDaysFrom1900to1970) * 86400)
        details = .date(EditOperation.DateDetails(initialValue: date, min: min, max: max))
    case .time:
        let flags = raw.timeFlags!
        let timeType: EditOperation.TimeType = (flags & 2) != 0 ? .duration : .absolute
        details = .time(EditOperation.TimeDetails(initialValue: Int(raw.initialValue)!,
                                                  min: Int(raw.min!),
                                                  max: Int(raw.max!),
                                                  timeType: timeType,
                                                  display24hour: (flags & 8) != 0,
                                                  includeSeconds: (flags & 1) != 0))
    }
    let op = EditOperation(prompt: raw.prompt,
                           allowCancel: raw.allowCancel,
                           screenRect: raw.screenRect,
                           details: details)

    var result = iohandler.editValue(op)

    if raw.type == .date, let date = result as? Date {
        // Convert from Date back to seconds since 1900
        result = Int((date.timeIntervalSince1970 / 86400) + kDaysFrom1900to1970)
    }
    L.push(any: result)
    return 1
}

private func textEditor(_ L: LuaState!) -> CInt {
    let iohandler = getInterpreterUpval(L).iohandler
    if L.isnoneornil(1) {
        iohandler.textEditor(nil)
    } else {
        guard let info: TextFieldInfo = L.todecodable(1) else {
            print("Failed to decode TextFieldInfo!")
            return 0
        }
        iohandler.textEditor(info)
    }
    return 0
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
               let srcid = L.toint(-1, key: "srcid") {
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
// graphicsop("cursor", [cursor])
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
    case "cursor":
        if L.isnil(2) {
            return doGraphicsOp(L, iohandler, .cursor(nil))
        }
        guard let cursor: Graphics.Cursor = L.todecodable(2) else {
            print("Bad cursor arg!")
            return 0
        }
        return doGraphicsOp(L, iohandler, .cursor(cursor))
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

// asyncRequest(requestName, requestTable)
// asyncRequest("getevent", { var = ..., ev = ... })
// asyncRequest("keya", { var = ..., k = ... })
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
    case "keya":
        type = .keya
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

    iohandler.asyncRequest(handle: requestHandle, type: type)
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
        iohandler.cancelRequest(handle: Int32(requestHandle))
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
    ts.tm_hour = getTimeField(L, "hour") ?? 0
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

public class OpoInterpreter: PsiLuaEnv {

    public var iohandler: OpoIoHandler

    override init() {
        iohandler = DummyIoHandler() // For now...
        super.init()
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
        // This creates the iohandler table, which we then add to
        makeFsIoHandlerBridge(self.iohandler)

        let val = Unmanaged<OpoInterpreter>.passUnretained(self)
        lua_pushlightuserdata(L, val.toOpaque())
        let fns: [String: lua_CFunction] = [
            "editValue": { L in return autoreleasepool { return editValue(L) } },
            "textEditor": { L in return autoreleasepool { return textEditor(L) } },
            // "print": { L in return autoreleasepool { return print_lua(L) } },
            "beep": { L in return autoreleasepool { return beep(L) } },
            "draw": { L in return autoreleasepool { return draw(L) } },
            "graphicsop": { L in return autoreleasepool { return graphicsop(L) } },
            "getScreenInfo": { L in return autoreleasepool { return getScreenInfo(L) } },
            "asyncRequest": { L in return autoreleasepool { return asyncRequest(L) } },
            "waitForAnyRequest": { L in return autoreleasepool { return waitForAnyRequest(L) } },
            "checkCompletions": { L in return autoreleasepool { return checkCompletions(L) } },
            "testEvent": { L in return autoreleasepool { return testEvent(L) } },
            "cancelRequest": { L in return autoreleasepool { return cancelRequest(L) } },
            "createBitmap": { L in return autoreleasepool { return createBitmap(L) } },
            "createWindow": { L in return autoreleasepool { return createWindow(L) } },
            "getTime": { L in return autoreleasepool { return getTime(L) } },
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

        require("runtime")
        L.rawget(-1, key: "runOpo")
        lua_remove(L, -2) // runtime
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
                // 0x404 is actually just the generic "cmd" event, but since we don't support changing files, quit
                // is the only thing it can be and doesn't require further elaboration.
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
        case "keya":
            switch response.value {
            case .keypressevent(let event):
                var k = Array<Int>(repeating: 0, count: 2)
                k[0] = event.keycode.toCharcode()!
                k[1] = event.modifiers.rawValue | (event.isRepeat ? 0x100 : 0)
                lua_getfield(L, 1, "ev") // Pushes eventArray (as an Addr)
                luaL_getmetafield(L, -1, "writeArray") // Addr:writeArray
                lua_insert(L, -2) // put writeArray below eventArray
                L.push(k) // k as a table
                L.push(0) // DataTypes.EWord
                let _ = logpcall(3, 0)
            case .cancelled, .interrupt:
                break
            default:
                print("Warning unhandled response type for keya \(response.value)")
            }
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

    // Safe to call from any thread
    func interrupt() {
        lua_sethook(L, stop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT, 1)
    }

}
