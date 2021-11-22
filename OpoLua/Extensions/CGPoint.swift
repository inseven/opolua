//
//  CGPoint.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import CoreGraphics

extension CGPoint {

    func move(x: CGFloat, y: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + x, y: self.y + y)
    }

    func move(x: Int, y: Int) -> CGPoint {
        return move(x: CGFloat(x), y: CGFloat(y))
    }

    func scale(_ scale: CGFloat) -> CGPoint {
        return CGPoint(x: x * scale, y: y * scale)
    }

}
