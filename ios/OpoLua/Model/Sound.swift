// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
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

import AudioUnit
import AVFoundation
import Combine
import CoreAudio
import Foundation

import OpoLuaCore

class PlaySoundRequest: Scheduler.Request {

    private let data: Data
    private var cancellable: Cancellable?

    init(handle: Async.RequestHandle, data: Data) {
        self.data = data
        super.init(handle: handle)
    }

    override func start() {
        cancellable = Sound.play(data: data) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    print("Play sound failed with error \(error).")
                    self.scheduler?.complete(request: self, response: .completed)
                }
            } else {
                guard let self = self else {
                    return
                }
                self.scheduler?.complete(request: self, response: .completed)
            }
        }
    }

    override func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }

    deinit {
        cancel()
    }

}

class Sound {

    class CancelToken: Cancellable {

        private let lock = NSLock()
        private var _isCancelled = false

        var isCancelled: Bool {
            return lock.withLock {
                return _isCancelled
            }
        }

        func cancel() {
            lock.withLock {
                _isCancelled = true
            }
        }

        deinit {
            cancel()
        }

    }

#if os(iOS)
    static let AudioOutSubType = kAudioUnitSubType_RemoteIO
#else
    static let AudioOutSubType = kAudioUnitSubType_DefaultOutput
#endif

    private static func _play(data: Data, cancelToken: CancelToken) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let audioComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                                  componentSubType: AudioOutSubType,
                                                                  componentManufacturer: kAudioUnitManufacturer_Apple,
                                                                  componentFlags: 0,
                                                                  componentFlagsMask: 0)
        let audioUnit = try AUAudioUnit(componentDescription: audioComponentDescription)
        let bus0 = audioUnit.inputBusses[0]
        let audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                        sampleRate: 8000,
                                        channels: 1,
                                        interleaved: true)
        try bus0.setFormat(audioFormat!)

        var dataIdx = 0
        data.withUnsafeBytes { dataPtr in
            audioUnit.outputProvider = { actionFlags, timestamp, frameCount, inputBusNumber, inputDataList -> AUAudioUnitStatus in

                if cancelToken.isCancelled {
                    semaphore.signal()
                    return kAudioServicesNoError
                }

                let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
                precondition(inputDataPtr.count == 1)
                let numBytes = min(min(Int(inputDataPtr[0].mDataByteSize), Int(frameCount) * MemoryLayout<UInt16>.size), dataPtr.count - dataIdx)
                inputDataPtr[0].mData!.copyMemory(from: dataPtr.baseAddress! + dataIdx, byteCount: numBytes)
                dataIdx += numBytes
                inputDataPtr[0].mDataByteSize = UInt32(numBytes)
                if dataIdx == dataPtr.count {
                    actionFlags.pointee.insert(AudioUnitRenderActionFlags.unitRenderAction_OutputIsSilence)
                    actionFlags.pointee.insert(AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete)
                    semaphore.signal()
                }
                return kAudioServicesNoError
            }
        }
        audioUnit.isOutputEnabled = true

        try audioUnit.allocateRenderResources()
        try audioUnit.startHardware()

        semaphore.wait()
        audioUnit.stopHardware()
    }

    static func play(data: Data, completion: @escaping (Error?) -> Void) -> Cancellable {
        let cancelToken = CancelToken()
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try self._play(data: data, cancelToken: cancelToken)
                completion(nil)
            } catch {
                completion(error)
            }
        }
        return cancelToken
    }

}
