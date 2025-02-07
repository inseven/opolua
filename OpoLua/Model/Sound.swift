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

import AudioUnit
import AVFoundation
import Combine
import CoreAudio
import Foundation

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

    static func beep(frequency: Double, duration: Double, sampleRate: Double = 44100.0) throws {
        let tone = Tone(sampleRate: sampleRate, frequency: frequency, duration: duration)

        let semaphore = DispatchSemaphore(value: 0)
        let audioComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                                  componentSubType: AudioOutSubType,
                                                                  componentManufacturer: kAudioUnitManufacturer_Apple,
                                                                  componentFlags: 0,
                                                                  componentFlagsMask: 0)
        let audioUnit = try AUAudioUnit(componentDescription: audioComponentDescription)
        let bus0 = audioUnit.inputBusses[0]
        let audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                        sampleRate: Double(sampleRate),
                                        channels:AVAudioChannelCount(2),
                                        interleaved: true)
        try bus0.setFormat(audioFormat ?? AVAudioFormat())
        audioUnit.outputProvider = { actionFlags, timestamp, frameCount, inputBusNumber, inputDataList -> AUAudioUnitStatus in

            let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
            guard inputDataPtr.count > 0 else {
                actionFlags.pointee.insert(AudioUnitRenderActionFlags.unitRenderAction_OutputIsSilence)
                actionFlags.pointee.insert(AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete)
                semaphore.signal()
                return kAudioServicesNoError
            }

            let bufferSize = Int(inputDataPtr[0].mDataByteSize)
            if var buffer = UnsafeMutableRawPointer(inputDataPtr[0].mData) {  // TODO: Guard this?
                for i in 0 ..< frameCount {

                    guard let x = tone.next() else {
                        actionFlags.pointee.insert(AudioUnitRenderActionFlags.unitRenderAction_OutputIsSilence)
                        actionFlags.pointee.insert(AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete)
                        semaphore.signal()
                        return kAudioServicesNoError
                    }

                    if i < (bufferSize / 2) {
                        buffer.assumingMemoryBound(to: Int16.self).pointee = x; buffer += 2  // L
                        buffer.assumingMemoryBound(to: Int16.self).pointee = x; buffer += 2  // R
                    }

                }
            }
            return kAudioServicesNoError
        }
        audioUnit.isOutputEnabled = true

        try audioUnit.allocateRenderResources()
        try audioUnit.startHardware()

        semaphore.wait()
        audioUnit.stopHardware()
    }

    // See https://www.reddit.com/r/iOSProgramming/comments/pgi1zl/how_to_play_raw_audio_in/
    static var audioStreamBasicDescription: AudioStreamBasicDescription = {
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = 8000
        asbd.mFormatID = kAudioFormatALaw
        asbd.mFormatFlags = 0
        asbd.mFramesPerPacket = 1
        asbd.mChannelsPerFrame = 1
        asbd.mBitsPerChannel = 8 * UInt32(MemoryLayout<UInt8>.size)
        asbd.mReserved = 0
        asbd.mBytesPerFrame = asbd.mChannelsPerFrame * UInt32(MemoryLayout<UInt8>.size) // channels * sizeof(data type)
        asbd.mBytesPerPacket = asbd.mBytesPerFrame * asbd.mFramesPerPacket // mBytesPerFrame * mFramesPerPacket
        return asbd
    }()

    static var audioFormat: AVAudioFormat = {
        let audioFormat = AVAudioFormat(streamDescription: &audioStreamBasicDescription)!
        return audioFormat
    }()

    private static func _play(data: Data, cancelToken: CancelToken) throws {
        var iterator = data.makeIterator()
        let semaphore = DispatchSemaphore(value: 0)
        let audioComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                                  componentSubType: AudioOutSubType,
                                                                  componentManufacturer: kAudioUnitManufacturer_Apple,
                                                                  componentFlags: 0,
                                                                  componentFlagsMask: 0)
        let audioUnit = try AUAudioUnit(componentDescription: audioComponentDescription)
        let bus0 = audioUnit.inputBusses[0]
        try bus0.setFormat(self.audioFormat)
        audioUnit.outputProvider = { actionFlags, timestamp, frameCount, inputBusNumber, inputDataList -> AUAudioUnitStatus in

            guard !cancelToken.isCancelled else {
                semaphore.signal()
                return kAudioServicesNoError
            }

            let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
            guard inputDataPtr.count > 0 else {
                actionFlags.pointee.insert(AudioUnitRenderActionFlags.unitRenderAction_OutputIsSilence)
                actionFlags.pointee.insert(AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete)
                semaphore.signal()
                return kAudioServicesNoError
            }

            let bufferSize = Int(inputDataPtr[0].mDataByteSize)
            if var buffer = UnsafeMutableRawPointer(inputDataPtr[0].mData) {  // TODO: Guard this?
                for i in 0 ..< frameCount {

                    guard let x = iterator.next() else {
                        actionFlags.pointee.insert(AudioUnitRenderActionFlags.unitRenderAction_OutputIsSilence)
                        actionFlags.pointee.insert(AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete)
                        semaphore.signal()
                        return kAudioServicesNoError
                    }

                    if i < bufferSize {
                        buffer.assumingMemoryBound(to: UInt8.self).pointee = x; buffer += 1
                    }

                }
            }
            return kAudioServicesNoError
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
