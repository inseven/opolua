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

// ER5 always uses CP1252 afaics, which also works for our ASCII-only error messages
private let kEnc = String.Encoding.windowsCP1252

extension String: Pushable {
    func push(state L: LuaState!) {
        L.push(self, encoding: kEnc)
    }
}

extension UnsafeMutablePointer where Pointee == lua_State {

    func tostring(_ index: Int32, convert: Bool = false) -> String? {
        return tostring(index, encoding: kEnc, convert: convert)
    }
    func tostringarray(_ index: Int32) -> [String]? {
        return tostringarray(index, encoding: kEnc)
    }
    func tostring(_ index: Int32, key: String, convert: Bool = false) -> String? {
        return tostring(index, key: key, encoding: kEnc, convert: convert)
    }
    func tostringarray(_ index: Int32, key: String, convert: Bool = false) -> [String]? {
        return tostringarray(index, key: key, encoding: kEnc, convert: convert)
    }

    func toColor(_ idx: Int32, key: String) -> Graphics.Color? {
        let L = self
        if lua_getfield(L, idx, key) == LUA_TTABLE {
            lua_rawgeti(L, -1, 1)
            let r = UInt8(L.toint(-1) ?? 0)
            L.pop()
            lua_rawgeti(L, -1, 2)
            let g = UInt8(L.toint(-1) ?? 0)
            L.pop()
            lua_rawgeti(L, -1, 3)
            let b = UInt8(L.toint(-1) ?? 0)
            L.pop(2)
            return Graphics.Color(r: r, g: g, b: b)
        } else {
            L.pop()
            return nil
        }
    }

}

private func searcher(_ L: LuaState!) -> Int32 {
    guard let module = L.tostring(1, encoding: .utf8) else {
        L.pushnil()
        return 1
    }

    let parts = module.split(separator: ".", omittingEmptySubsequences: false)
    let subdir = parts.count > 1 ? parts[0...parts.count-2].joined(separator: "/") : nil
    let name = String(parts.last!)

    if let url = Bundle.main.url(forResource: name, withExtension: "lua", subdirectory: subdir),
       let data = FileManager.default.contents(atPath: url.path) {
        let shortPath = "@" + url.lastPathComponent
        var err: Int32 = 0
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Void in
            let chars = ptr.bindMemory(to: CChar.self)
            err = luaL_loadbufferx(L, chars.baseAddress, chars.count, shortPath, "t")
        }
        if err == 0 {
            return 1
        } else {
            return lua_error(L) // errors with the string error pushed by luaL_loadbufferx
        }
    } else {
        L.push("\n\tno resource '\(module)'")
        return 1
    }
}

private func traceHandler(_ L: LuaState!) -> Int32 {
    var msg = lua_tostring(L, 1)
    if msg == nil {  /* is error object not a string? */
        if luaL_callmeta(L, 1, "__tostring") != 0 &&  /* does it have a metamethod */
            lua_type(L, -1) == LUA_TSTRING { /* that produces a string? */
            return 1  /* that is the message */
        } else {
            let t = String(utf8String: luaL_typename(L, 1))!
            msg = lua_pushstring(L, "(error object is a \(t) value)")
        }
    }
    luaL_traceback(L, L, msg, 1)  /* append a standard traceback */
    return 1  /* return the traceback */
}

private func getInterpreterUpval(_ L: LuaState!) -> OpoInterpreter {
    let rawPtr = lua_topointer(L, lua_upvalueindex(1))!
    return Unmanaged<OpoInterpreter>.fromOpaque(rawPtr).takeUnretainedValue()
}

// private func print_lua(_ L: LuaState!) -> Int32 {
//     let iohandler = getInterpreterUpval(L).iohandler
//     iohandler.printValue(L.tostring(1, convert: true) ?? "<<STRING DECODE ERR>>")
//     return 0
// }

private func beep(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.beep(frequency: lua_tonumber(L, 1), duration: lua_tonumber(L, 2))
    return 0
}

// editValue("text", value, prompt, true, [min, max])
private func editValue(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    let type = EditParams.InputType(rawValue: L.tostring(1) ?? "text") ?? .text
    let initialValue = L.tostring(2) ?? ""
    let prompt = L.tostring(3)
    let allowCancel = L.toboolean(4)
    let params = EditParams(type: type, initialValue: initialValue, prompt: prompt, allowCancel: allowCancel)
    let result = iohandler.editValue(params)
    L.push(result)
    return 1
}

private func draw(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    var ops: [Graphics.DrawCommand] = []
    for _ in L.ipairs(1, requiredType: .table) {
        let id = Graphics.DrawableId(value: L.toint(-1, key: "id") ?? 1)
        let t = L.tostring(-1, key: "type") ?? ""
        let x = L.toint(-1, key: "x") ?? 0
        let y = L.toint(-1, key: "y") ?? 0
        let origin = Graphics.Point(x: x, y: y)
        guard let color = L.toColor(-1, key: "color") else {
            print("missing color")
            continue
        }
        guard let bgcolor = L.toColor(-1, key: "bgcolor") else {
            print("missing bgcolor")
            continue
        }
        var mode = Graphics.Mode(rawValue: L.toint(-1, key: "mode") ?? 0) ?? .set
        let penWidth = L.toint(-1, key: "penwidth") ?? 1
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
            if let width = L.toint(-1, key: "bmpWidth"),
               let height = L.toint(-1, key: "bmpHeight"),
               let mode = Graphics.Bitmap.Mode(rawValue: L.toint(-1, key: "bmpMode") ?? 0),
               let stride = L.toint(-1, key: "bmpStride"),
               let data = L.todata(-1, key: "bmpData") {
                let size = Graphics.Size(width: width, height: height)
                let info = Graphics.Bitmap(mode: mode, size: size, stride: stride, data: data)
                optype = .bitblt(info)
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
                let info = Graphics.CopySource(drawableId: drawable, rect: rect, extra: nil)
                let maskInfo: Graphics.CopySource?
                let maskId = L.toint(-1, key: "mask") ?? 0
                if maskId > 0 {
                    let maskDrawable = Graphics.DrawableId(value: maskId)
                    maskInfo = Graphics.CopySource(drawableId: maskDrawable, rect: rect, extra: nil)
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
            lua_getfield(L, -1, "rect")
            let x = L.toint(-1, key: "x") ?? 0
            let y = L.toint(-1, key: "y") ?? 0
            let w = L.toint(-1, key: "w") ?? 0
            let h = L.toint(-1, key: "h") ?? 0
            let rect = Graphics.Rect(x: x, y: y, width: w, height: h)
            optype = .scroll(dx, dy, rect)
        case "patt":
            if let srcid = L.toint(-1, key: "srcid"),
               let w = L.toint(-1, key: "width"),
               let h = L.toint(-1, key: "height") {
                let size = Graphics.Size(width: w, height: h)
                let rect = Graphics.Rect(origin: origin, size: size)
                let drawable = Graphics.DrawableId(value: srcid)
                let info = Graphics.CopySource(drawableId: drawable, rect: rect, extra: nil)
                optype = .pattern(info)
            } else {
                print("Missing params in patt!")
                continue
            }
        case "text":
            let str = L.tostring(-1, key: "string") ?? ""
            var flags = Graphics.FontFlags(flags: L.toint(-1, key: "style") ?? 0)
            mode = Graphics.Mode(rawValue: L.toint(-1, key: "tmode") ?? 0) ?? .set
            let face = Graphics.FontFace(rawValue: L.tostring(-1, key: "fontface") ?? "arial") ?? .arial
            let uid = UInt32(L.toint(-1, key: "fontuid") ?? 0)
            if L.toboolean(-1, key: "fontbold") {
                flags.insert(.boldHint)
            }
            let sz = L.toint(-1, key: "fontsize") ?? 15
            let fontInfo = Graphics.FontInfo(uid: uid, face: face, size: sz, flags: flags)
            optype = .text(str, fontInfo)
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
        ops.append(Graphics.DrawCommand(drawableId: id, type: optype, mode: mode, origin: origin, color: color, bgcolor: bgcolor, penWidth: penWidth))
    }
    iohandler.draw(operations: ops)
    return 0
}

func doGraphicsOp(_ L: LuaState!, _ iohandler: OpoIoHandler, _ op: Graphics.Operation) -> Int32 {
    let result = iohandler.graphicsop(op)
    switch result {
    case .nothing:
        return 0
    case .handle(let h):
        L.push(h.value)
        return 1
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
// graphicsop("clock", drawableId, [mode, x, y])
// graphicsop("peekline", drawableId, x, y, numPixels, mode)
private func graphicsop(_ L: LuaState!) -> Int32 {
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
        var flags = Graphics.FontFlags(flags: L.toint(4) ?? 0)
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
        if L.type(4) == .nilType {
            return doGraphicsOp(L, iohandler, .sprite(window, spriteId, nil))
        }
        guard L.type(4) == .table,
              let x = L.toint(4, key: "x"),
              let y = L.toint(4, key: "y"),
              lua_getfield(L, 4, "frames") == LUA_TTABLE
            else {
                print("Bad args to sprite")
                break
            }
        var frames: [Graphics.Sprite.Frame] = []
        for _ in L.ipairs(-1, requiredType: .table) {
            if let dx = L.toint(-1, key: "dx"),
               let dy = L.toint(-1, key: "dy"),
               let bitmap = L.toint(-1, key: "bitmap"),
               let mask = L.toint(-1, key: "mask"),
               let time = L.toint(-1, key: "time") {
                let invert = L.toboolean(-1, key: "invert")
                let offset = Graphics.Point(x: dx, y: dy)
                let bitmapId = Graphics.DrawableId(value: bitmap)
                let maskId = Graphics.DrawableId(value: mask)
                let frame = Graphics.Sprite.Frame(offset: offset, bitmap: bitmapId, mask: maskId, invertMask: invert, time: Double(time) / 1000000)
                frames.append(frame)
            } else {
                print("Missing frame params!")
                break
            }
        }
        L.pop() // frames
        let origin = Graphics.Point(x: x, y: y)
        let sprite = Graphics.Sprite(origin: origin, frames: frames)
        return doGraphicsOp(L, iohandler, .sprite(window, spriteId, sprite))
    case "clock":
        let drawableId = Graphics.DrawableId(value: L.toint(2) ?? 0)
        let clockInfo: Graphics.ClockInfo?
        if let modeVal = L.toint(3),
           let mode = Graphics.ClockInfo.Mode(rawValue: modeVal),
           let x = L.toint(4),
           let y = L.toint(5) {
            let pos = Graphics.Point(x: x, y: y)
            clockInfo = Graphics.ClockInfo(mode: mode, position: pos)
        } else {
            clockInfo = nil
        }
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

private func getScreenInfo(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    let (sz, mode) = iohandler.getScreenInfo()
    L.push(sz.width)
    L.push(sz.height)
    L.push(mode.rawValue)
    return 3
}

private func fsop(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
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
        if let data = L.todata(3) {
            op = .write(data)
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
        lua_createtable(L, Int32(strings.count), 0)
        for (i, string) in strings.enumerated() {
            L.push(string)
            lua_rawseti(L, -2, lua_Integer(i + 1))
        }
        return 1
    case .stat(let stat):
        lua_newtable(L)
        L.setfield("size", stat.size)
        L.setfield("lastModified", stat.lastModified.timeIntervalSince1970)
        return 1
    }
}

// asyncRequest(requestName, requestTable)
// asyncRequest("getevent", { var = ..., ev = ... })
// asyncRequest("after", { var = ..., period = ... })
// asyncRequest("at", { var = ..., time = ...})
// asyncRequest("playsound", { var = ..., data = ... })
private func asyncRequest(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    guard let name = L.tostring(1) else { return 0 }
    lua_settop(L, 2)
    lua_remove(L, 1) // Removes name, so requestTable is now at position 1
    L.setfield("type", name) // requestTable.type = name
    lua_getfield(L, 1, "var") // Put var at 2 for compat with code below

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
        type = .playsound(data)
    default:
        fatalError("Unhandled asyncRequest type \(name)")
    }

    // Use registry ref to map swift int to statusVar
    // Then set registry[statusVar] = requestTable
    // That way both Lua and swift sides can look up the request

    lua_pushvalue(L, 2) // dup statusVar
    let requestHandle = luaL_ref(L, LUA_REGISTRYINDEX) // pop dup, registry[requestHandle] = statusVar
    lua_pushinteger(L, lua_Integer(requestHandle))
    lua_setfield(L, 1, "ref") // requestTable.ref = requestHandle

    lua_pushvalue(L, 2) // dup statusVar
    lua_pushvalue(L, 1) // dup requestTable
    lua_settable(L, LUA_REGISTRYINDEX) // registry[statusVar] = requestTable

    let req = Async.Request(type: type, handle: requestHandle)

    iohandler.asyncRequest(req)
    return 0
}

// As per init.lua
private let KOplErrIOCancelled = -48
private let KStopErr = -999

private func checkCompletions(_ L: LuaState!) -> Int32 {
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

private func waitForAnyRequest(_ L: LuaState!) -> Int32 {
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

private func cancelRequest(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    lua_settop(L, 1)
    let t = lua_gettable(L, LUA_REGISTRYINDEX) // 1: registry[statusVar] -> requestTable
    if t == LUA_TNIL {
        // Request must've already been completed in waitForAnyRequest
        return 0
    } else {
        assert(t == LUA_TTABLE, "Unexpected type for registry requestTable!")
    }
    lua_getfield(L, 1, "ref")
    if let requestHandle = L.toint(-1) {
        iohandler.cancelRequest(Int32(requestHandle))
    } else {
        print("Bad type for requestTable.ref!")
    }
    return 0
}

private func testEvent(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    L.push(iohandler.testEvent())
    return 1
}

private func createBitmap(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    guard let width = L.toint(1),
          let height = L.toint(2),
          let modeVal = L.toint(3),
          let mode = Graphics.Bitmap.Mode(rawValue: modeVal) else {
        print("Bad parameters to createBitmap")
        return 0
    }
    let size = Graphics.Size(width: width, height: height)
    return doGraphicsOp(L, iohandler, .createBitmap(size, mode))
}

private func createWindow(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    guard let x = L.toint(1), let y = L.toint(2),
          let width = L.toint(3), let height = L.toint(4),
          let flags = L.toint(5),
          let mode = Graphics.Bitmap.Mode(rawValue: flags & 0xF) else {
        return 0
    }

    var shadow = 0
    if flags & 0xF0 != 0 {
        shadow = 2 * ((flags & 0xF00) >> 8)
    }
    let rect = Graphics.Rect(x: x, y: y, width: width, height: height)
    return doGraphicsOp(L, iohandler, .createWindow(rect, mode, shadow))
}

private func getTime(_ L: LuaState!) -> Int32 {
    let dt = Date()
    L.push(dt.timeIntervalSince1970)
    return 1
}

private func key(_ L: LuaState!) -> Int32 {
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

private func opsync(_ L: LuaState!) -> Int32 {
    let interpreter = getInterpreterUpval(L)
    interpreter.syncOpTimer()
    return 0
}

private func getConfig(_ L: LuaState!) -> Int32 {
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

private func setConfig(_ L: LuaState!) -> Int32 {
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

private func setAppTitle(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    if let title = L.tostring(1) {
        iohandler.setAppTitle(title)
    }
    return 0
}

private func displayTaskList(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.displayTaskList()
    return 0
}

private func setForeground(_ L: LuaState!) -> Int32 {
    let iohandler = getInterpreterUpval(L).iohandler
    iohandler.setForeground()
    return 0
}

private func setBackground(_ L: LuaState!) -> Int32 {
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

class OpoInterpreter {

    static let kOpTime: TimeInterval = 3.5 / 1000000 // Make this bigger to slow the interpreter down

    private let L: LuaState
    var iohandler: OpoIoHandler
    var lastOpTime = Date()

    init() {
        iohandler = DummyIoHandler() // For now...
        L = luaL_newstate()
        let libs: [(String, lua_CFunction)] = [
            ("_G", luaopen_base),
            (LUA_LOADLIBNAME, luaopen_package),
            (LUA_TABLIBNAME, luaopen_table),
            (LUA_IOLIBNAME, luaopen_io),
            (LUA_OSLIBNAME, luaopen_os),
            (LUA_STRLIBNAME, luaopen_string),
            (LUA_MATHLIBNAME, luaopen_math),
            (LUA_UTF8LIBNAME, luaopen_utf8),
            (LUA_DBLIBNAME, luaopen_debug)
        ]
        for (name, fn) in libs {
            luaL_requiref(L, name, fn, 1)
            lua_pop(L, 1)
        }

        // Now configure the require path
        lua_getglobal(L, "package")
        lua_getfield(L, -1, "searchers")
        lua_pushcfunction(L, searcher)
        lua_rawseti(L, -2, 2) // 2nd searcher is the .lua lookup one
        lua_pushnil(L)
        lua_rawseti(L, -2, 3) // And prevent 3 (or 4) from being used
        lua_pop(L, 2) // searchers, package

        // Finally, run init.lua
        lua_getglobal(L, "require")
        L.push("init")
        guard logpcall(1, 0) else {
            fatalError("Failed to load init.lua!")
        }

        assert(lua_gettop(L) == 0) // In case we failed to balance stack during init
    }

    deinit {
        lua_close(L)
    }

    // Returns nil on success, otherwise err string
    func pcall(_ narg: Int32, _ nret: Int32) -> String? {
        let base = lua_gettop(L) - narg // Where the function is, and where the msghandler will be
        lua_pushcfunction(L, traceHandler)
        lua_insert(L, base)
        let err = lua_pcall(L, narg, nret, base);
        lua_remove(L, base)
        if err != 0 {
            let errStr = L.tostring(-1, convert: true)!
            L.pop()
            return errStr
        }
        return nil
    }

    func logpcall(_ narg: Int32, _ nret: Int32) -> Bool {
        if let err = pcall(narg, nret) {
            print("Error: \(err)")
            return false
        } else {
            return true
        }
    }

    func makeIoHandlerBridge() {
        lua_newtable(L)
        let val = Unmanaged<OpoInterpreter>.passUnretained(self)
        lua_pushlightuserdata(L, val.toOpaque())
        let fns: [(String, lua_CFunction)] = [
            ("editValue", editValue),
            // ("print", print_lua),
            ("beep", beep),
            ("draw", draw),
            ("graphicsop", graphicsop),
            ("getScreenInfo", getScreenInfo),
            ("fsop", fsop),
            ("asyncRequest", asyncRequest),
            ("waitForAnyRequest", waitForAnyRequest),
            ("checkCompletions", checkCompletions),
            ("testEvent", testEvent),
            ("cancelRequest", cancelRequest),
            ("createBitmap", createBitmap),
            ("createWindow", createWindow),
            ("getTime", getTime),
            ("key", key),
            ("opsync", opsync),
            ("getConfig", getConfig),
            ("setConfig", setConfig),
            ("setAppTitle", setAppTitle),
            ("displayTaskList", displayTaskList),
            ("setForeground", setForeground),
            ("setBackground", setBackground),
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
        lua_getglobal(L, "require")
        L.push("opofile")
        guard logpcall(1, 1) else { return nil }
        lua_getfield(L, -1, "parseOpo")
        L.push(data)
        guard logpcall(1, 1) else {
            L.pop() // opofile
            return nil
        }
        var procs: [Procedure] = []
        for _ in L.ipairs(-1, requiredType: .table) {
            let name = L.tostring(-1, key: "name")!
            var args: [ValType] = []
            if lua_getfield(L, -1, "params") == LUA_TTABLE {
                for _ in L.ipairs(-1, requiredType: .number) {
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

    struct AppInfo {

        let captions: [LocalizedString]
        let uid3: UInt32
        let icons: [Graphics.MaskedBitmap]
    }

    func getAppInfo(aifPath: String) -> AppInfo? {
        let top = lua_gettop(L)
        defer {
            lua_settop(L, top)
        }
        guard let data = FileManager.default.contents(atPath: aifPath) else {
            return nil
        }
        lua_getglobal(L, "require")
        L.push("aif")
        guard logpcall(1, 1) else { return nil }
        lua_getfield(L, -1, "parseAif")
        lua_remove(L, -2) // aif module
        L.push(data)
        guard logpcall(1, 1) else { return nil }

        lua_getfield(L, -1, "captions")
        var captions: [LocalizedString] = []
        for (languageIndex, captionIndex) in L.pairs(-1) {
            guard let language = L.tostring(languageIndex),
                  let caption = L.tostring(captionIndex)
            else {
                return nil
            }
            captions.append(LocalizedString(caption, locale: Locale(identifier: language)))
        }
        L.pop()

        guard let uid3 = L.toint(-1, key: "uid3") else { return nil }

        lua_getfield(L, -1, "icons")
        var icons: [Graphics.MaskedBitmap] = []
        func getBitmap() -> Graphics.Bitmap? {
            if let width = L.toint(-1, key: "width"),
               let height = L.toint(-1, key: "height"),
               let modeVal = L.toint(-1, key: "drawableMode"),
               let mode = Graphics.Bitmap.Mode(rawValue: modeVal),
               let stride = L.toint(-1, key: "stride"),
               let data = L.todata(-1, key: "imgData") {
                let size = Graphics.Size(width: width, height: height)
                return Graphics.Bitmap(mode: mode, size: size, stride: stride, data: data)
            }
            return nil
        }
        for _ in L.ipairs(-1, requiredType: .table) {
            if let bmp = getBitmap() {
                var mask: Graphics.Bitmap? = nil
                if lua_getfield(L, -1, "mask") == LUA_TTABLE {
                    mask = getBitmap()
                }
                L.pop()
                icons.append(Graphics.MaskedBitmap(bitmap: bmp, mask: mask))
            }
        }
        return AppInfo(captions: captions, uid3: UInt32(uid3), icons: icons)
    }

    func getMbmBitmaps(path: String) -> [Graphics.Bitmap]? {
        let top = lua_gettop(L)
        defer {
            lua_settop(L, top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        lua_getglobal(L, "require")
        L.push("mbm")
        guard logpcall(1, 1) else { return nil }
        lua_getfield(L, -1, "parseMbmHeader")
        lua_remove(L, -2) // mbm module
        L.push(data)
        guard logpcall(1, 1) else { return nil }
        // top of stack should now be bitmap array
        var result: [Graphics.Bitmap] = []
        for _ in L.ipairs(-1, requiredType: .table) {
            if luaL_callmeta(L, -1, "getImageData") == 0 {
                continue
            }
            let data = L.todata(-1)
            L.pop()
            if let width = L.toint(-1, key: "width"),
               let height = L.toint(-1, key: "height"),
               let mode = Graphics.Bitmap.Mode(rawValue: L.toint(-1, key: "drawableMode") ?? 0),
               let stride = L.toint(-1, key: "stride"),
               let data = data {
                let size = Graphics.Size(width: width, height: height)
                let bmp = Graphics.Bitmap(mode: mode, size: size, stride: stride, data: data)
                result.append(bmp)
            }
        }
        return result
    }

    struct Error {
        let code: Int?
        let opoStack: String?
        let luaStack: String
        let description: String
    }
    enum Result {
        case none
        case error(Error)
    }

    func run(devicePath: String, procedureName: String? = nil) -> Result {
        lua_settop(L, 0)

        lua_getglobal(L, "require")
        L.push("runtime")
        guard logpcall(1, 1) else { fatalError("Couldn't load runtime") }
        lua_getfield(L, -1, "runOpo")
        L.push(devicePath)
        if let proc = procedureName {
            L.push(proc)
        } else {
            L.pushnil()
        }
        makeIoHandlerBridge()
        let err = pcall(3, 1) // runOpo(devicePath, proc, iohandler)
        if let err = err {
            return .error(Error(code: nil, opoStack: nil, luaStack: err, description: err))
        } else {
            let t = L.type(-1)
            let result: Result
            switch(L.type(-1)) {
            case nil:
                result = .none
            case .nilType:
                result = .none
            case .table:
                // An error
                let code = L.toint(-1, key: "code")
                let opoStack = L.tostring(-1, key: "opoStack")
                let luaStack = L.tostring(-1, key: "luaStack") ?? "Missing Lua stack trace!"
                let description = L.tostring(-1, convert: true) ?? "Missing description!"
                result = .error(Error(code: code, opoStack: opoStack, luaStack: luaStack, description: description))
            default:
                print("Unexpected return type \(t!.rawValue)")
                result = .none
            }
            L.pop()
            return result
        }
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
        lua_settop(L, 0)
        var t = lua_rawgeti(L, LUA_REGISTRYINDEX, lua_Integer(response.handle)) // 1: registry[requestHandle] -> statusVar
        assert(t == LUA_TTABLE, "Failed to locate statusVar for requestHandle \(response.handle)!")
        lua_pushvalue(L, 1) // 2: statusVar
        t = lua_gettable(L, LUA_REGISTRYINDEX) // 2: registry[statusVar] -> requestTable
        assert(t == LUA_TTABLE, "Failed to locate requestTable for requestHandle \(response.handle)!")

        // Deal with writing any result data

        let type = L.tostring(2, key: "type") ?? ""
        func timestampToInt32(_ timestamp: TimeInterval) -> Int {
            let microsecs = Int(timestamp * 1000000)
            let us32 = UInt32(microsecs % Int(UInt32.max))
            let intVal = Int32(bitPattern: us32)
            return Int(intVal)
        }
        switch type {
        case "getevent":
            var ev = Array<Int>(repeating: 0, count: 16)
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
            lua_getfield(L, 2, "ev") // Pushes eventArray (AddrSlice)
            luaL_getmetafield(L, -1, "writeArray") // AddrSlice:writeArray
            lua_insert(L, -2) // put writeArray below eventArray
            L.push(ev) // ev as a table
            L.push(1) // DataTypes.ELong
            lua_call(L, 3, 0)
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

        lua_pushvalue(L, 1) // statusVar
        L.push(val)
        lua_call(L, 1, 0) 

        // Finally, free up requestHandle
        lua_settop(L, 1) // 1: statusVar
        lua_pushnil(L)
        lua_settable(L, LUA_REGISTRYINDEX) // registry[statusVar] = nil
        luaL_unref(L, LUA_REGISTRYINDEX, response.handle) // registry[requestHandle] = nil
    }

    func installSisFile(path: String) -> Result {
        let top = lua_gettop(L)
        defer {
            lua_settop(L, top)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return .error(Error(code: nil, opoStack: nil, luaStack: "", description:
                "Couldn't read \(path)"))
        }
        lua_getglobal(L, "require")
        L.push("runtime")
        guard logpcall(1, 1) else { fatalError("Couldn't load runtime") }
        lua_getfield(L, -1, "installSis")
        L.push(data)
        makeIoHandlerBridge()
        if let err = pcall(2, 0) { // installSis(data, iohandler)
            return .error(Error(code: nil, opoStack: nil, luaStack: err, description: err))
        } else {
            return .none
        }
    }

    func syncOpTimer() {
        Thread.sleep(until: lastOpTime.addingTimeInterval(Self.kOpTime))
        lastOpTime = Date()
    }

    // Safe to call from any thread
    func interrupt() {
        lua_sethook(L, stop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT, 1)
    }
}
