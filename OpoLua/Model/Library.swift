//
//  Library.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 21/11/2021.
//

import Foundation

class Library {
    
    var objects: [OPLObject] = []
    
    init() {
        self.load()
    }
    
    private func load() {
        guard let programs = Bundle.main.urls(forResourcesWithExtension: "opo", subdirectory: "examples") else {
            return
        }
        objects = programs
            .map { OPLObject(url: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) != .orderedDescending }
    }
}
