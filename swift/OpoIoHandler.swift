//
//  OpoIoHandler.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 18/11/2021.
//

import Foundation

protocol OpoIoHandler {

    func print(_ val: String) -> Void

    // nil return means escape (must only return nil if escapeShouldErrorEmptyInput is true)
    func readLine(escapeShouldErrorEmptyInput: Bool) -> String?

    // lines is 1-2 strings, buttons is 0-3 strings.
    // return should be 1, 2, or 3
    func alert(lines: [String], buttons: [String]) -> Int

    // return char code (should probably be in ER5 charset...)
    func getch() -> Int

}

class DummyIoHandler : OpoIoHandler {

    func print(_ val: String) -> Void {
        Swift.print(val, terminator: "")
    }

    func readLine(escapeShouldErrorEmptyInput: Bool) -> String? {
        return ""
    }

    func alert(lines: [String], buttons: [String]) -> Int {
        return 1
    }

    func getch() -> Int {
        return 0
    }
}
