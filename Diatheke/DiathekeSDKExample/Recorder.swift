//
//  Recorder.swift
//  DiathekeSDKExample
//
//  Created by Eduard Miniakhmetov on 23.10.2020.
//  Copyright (2020) Cobalt Speech and Language Inc.

//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation
import AVFoundation

class Recorder {
    
    /// Stream audio sample duration. It defines how large the buffer is (in seconds) that is periodically sent over the server.
    private let SAMPLE_DURATION: Double = 0.3
    
    private let RECORDING_SETTINGS_NUMBER_OF_CHANNELS: AVAudioChannelCount = 1
    private let RECORDING_SETTINGS_PCM_BIT_DEPTH: UInt32 = 16
    
    private let audioEngine = AVAudioEngine()
    
    /// Sample rate of selected model
    var modelSampleRate: UInt32 = 16000
    
    /// Handler for data chunk prepared for ASR
    var sendAudioChunkBlock: ((Data) -> ())?

    /// ProcessBuffer function converts audio chunk buffer to the format required for ASR and calls handler function
    fileprivate func processBuffer(_ buffer: AVAudioPCMBuffer,
                                   time: AVAudioTime,
                                   format: AVAudioFormat,
                                   downFormat: AVAudioFormat) {
        let converter = AVAudioConverter(from: format, to: downFormat)
        let newBuffer = AVAudioPCMBuffer(pcmFormat: downFormat,
                                         frameCapacity: AVAudioFrameCount(downFormat.sampleRate * SAMPLE_DURATION))

        let inputBlock: AVAudioConverterInputBlock = { (inNumPackets, outStatus) -> AVAudioBuffer? in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            let audioBuffer: AVAudioBuffer = buffer
            return audioBuffer
        }
                                       
        if let newBuffer = newBuffer {
            var error: NSError?
            converter?.convert(to: newBuffer, error: &error, withInputFrom: inputBlock)
            let data = Data(buffer: newBuffer, time: time)
            self.sendAudioChunkBlock?(data)
        }
    }
    
    /// Starts recording
    func recordSpeech() throws {
        let node = audioEngine.inputNode

        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: AVAudioSession.sharedInstance().sampleRate,
                                         channels: RECORDING_SETTINGS_NUMBER_OF_CHANNELS,
                                         interleaved: true) else {
            return
        }
        
        // Define the audio format to convert for recognition
                
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: modelSampleRate,
            AVNumberOfChannelsKey: RECORDING_SETTINGS_NUMBER_OF_CHANNELS,
            AVLinearPCMBitDepthKey: RECORDING_SETTINGS_PCM_BIT_DEPTH,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        guard let downFormat = AVAudioFormat(settings: settings) else { return }
        audioEngine.connect(audioEngine.inputNode, to: audioEngine.mainMixerNode, format: format)

        // Set up preparing audio data chunks during record and send them for recognition
        
        node.installTap(onBus: 0,
                        bufferSize: AVAudioFrameCount(format.sampleRate * SAMPLE_DURATION),
                        format: format) { (buffer, time) in
            self.processBuffer(buffer, time: time, format: format, downFormat: downFormat)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Stops recording
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            self.audioEngine.stop()
        }
    }
    
}

// Data extension to init Data from AVAudioPCMBuffer

fileprivate extension Data {
    
    init(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }

}
