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

class CanvasSprite {

    struct Frame {
        let offset: Graphics.Point
        let bitmap: Drawable // Strictly this will always be a Canvas, but close enough
        let mask: Drawable
        let invertMask: Bool
        let time: TimeInterval
    }

    let origin: Graphics.Point
    let frames: [Frame]

    private var currentFrameIndex: Int = 0
    private var currentFrameRemaingTime: TimeInterval

    var currentFrame: Frame? {
        // There can be a lack of a current frame if the sprite has not yet got any frames with valid bitmaps set
        if currentFrameIndex < frames.count {
            return frames[currentFrameIndex]
        } else {
            return nil
        }
    }

    init(origin: Graphics.Point, frames: [Frame]) {
        self.origin = origin
        self.frames = frames
        if frames.count > 0 {
            currentFrameRemaingTime = frames[0].time
        } else {
            currentFrameRemaingTime = 0
        }
    }

    func update(elapsedTime: TimeInterval) -> Bool {
        if self.currentFrame == nil {
            return false
        }
        currentFrameRemaingTime = currentFrameRemaingTime - elapsedTime
        if currentFrameRemaingTime <= 0 {
            currentFrameIndex = (currentFrameIndex + 1) % frames.count
            currentFrameRemaingTime = self.currentFrame!.time
            return true
        } else {
            return false
        }
    }

}
