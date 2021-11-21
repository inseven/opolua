//
//  OPLObject.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 21/11/2021.
//

import Foundation

class OPLObject {
    
    let url: URL
    
    var name: String {
        return FileManager.default.displayName(atPath: url.path)
    }
    
    var procedures: [OpoInterpreter.Procedure]? {
        return OpoInterpreter().getProcedures(file: url.path)
    }
    
    init(url: URL) {
        self.url = url
    }
        
}
