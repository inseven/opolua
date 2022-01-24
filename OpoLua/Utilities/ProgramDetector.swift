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

protocol ProgramDetectorDelegate: AnyObject {

    func programDetector(_ programDetector: ProgramDetector, didUpdateItems items: [Directory.Item])
    func programDetector(_ programDetector: ProgramDetector, didFailWithError error: Error)

}

class ProgramDetector {

    private var locations: [URL]
    let updateQueue = DispatchQueue(label: "ProgramDetector.updateQueue")

    weak var delegate: ProgramDetectorDelegate?

    init(locations: [URL]) {
        self.locations = locations
    }

    func updateQueue_update() {
        dispatchPrecondition(condition: .onQueue(updateQueue))
        print("Fetching items...")
        do {
            var items: [Directory.Item] = []
            for location in locations {
                items = items + (try Directory.items(for: location))
            }
            items = items.filter { item in
                switch item.type {
                case .object:
                    return true
                case .directory:
                    return false
                case .application(_):
                    return true
                case .system(_, _):
                    return true
                case .installer:
                    return false
                case .applicationInformation(_):
                    return false
                case .image:
                    return false
                case .sound:
                    return false
                case .help:
                    return false
                case .unknown:
                    return false
                }
            }
            DispatchQueue.main.async {
                print("Succeeded!")
                self.delegate?.programDetector(self, didUpdateItems: items)
            }
        } catch {
            print("Failed!")
            DispatchQueue.main.async {
                self.delegate?.programDetector(self, didFailWithError: error)
            }
        }

    }

    func update() {
        updateQueue.async {
            self.updateQueue_update()
        }
    }

}
