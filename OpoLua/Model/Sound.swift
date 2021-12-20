// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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
import AudioUnit
import AVFoundation

class Sound {
    
    static let sampleRate: Double = 44100.0

    static func beep(frequency: Double, duration: Double) throws {
        let tone = Tone(sampleRate: self.sampleRate, frequency: frequency, duration: duration)

        let semaphore = DispatchSemaphore(value: 0)
        let audioComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                                  componentSubType: kAudioUnitSubType_RemoteIO,
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

}
