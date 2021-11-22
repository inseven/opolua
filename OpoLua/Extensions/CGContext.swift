//
//  CGContext.swift
//  OpoLua
//
//  Created by Jason Barrie Morley on 22/11/2021.
//

import CoreGraphics

extension Graphics.Operation {

    var origin: CGPoint {
        return CGPoint(x: x, y: y)
    }

}

extension CGContext {

    func draw(_ operation: Graphics.Operation) {
        // TODO: Scale for the iOS screensize
        // TODO: Set the stroke and fill colours
        switch operation.type {
        case .circle(let radius, let fill):
            let path = CGMutablePath()
            path.addArc(center: operation.origin,
                        radius: CGFloat(radius),
                        startAngle: 0,
                        endAngle: Double.pi * 2,
                        clockwise: true)
            setLineWidth(1.0)
            addPath(path)
            strokePath()
            if fill {
                fillPath()
            }
            break
        case .line(let x, let y):
            let path = CGMutablePath()
            path.move(to: operation.origin)
            path.addLine(to: operation.origin.move(x: x, y: y))
            addPath(path)
            strokePath()
            break
        }
    }

}
