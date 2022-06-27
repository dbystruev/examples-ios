//
//  AudioRecorder.swift
//  CubicExample
//
//  Created by Eduard Miniakhmetov on 20.03.2020.
//  Copyright © 2020 Cobalt Speech and Language Inc. All rights reserved.
//
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
import Cubic
import GRPC

protocol AudioRecorderDelegate: AnyObject {
    
    func audioRecorderDidReceiveRecognitionResponse(_ response: Cobaltspeech_Cubic_RecognitionResponse)
    
}

public class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    
    /// Stream audio sample duration. It defines how large the buffer is (in seconds) that is periodically sent over the server.
    private let SAMPLE_DURATION: Double = 0.3
    
    /// Sample rate of selected model
    var modelSampleRate: UInt32 = 16000
    
    /// Delegate object to receive recognition result messages
    weak var delegate: AudioRecorderDelegate?
    
    private var client: Client!
    
    /// Recognition configuration
    private var config: Cobaltspeech_Cubic_RecognitionConfig!
    
    /// This streaming call is used during an active audio record session
    private var call: BidirectionalStreamingCall<Cobaltspeech_Cubic_StreamingRecognizeRequest, Cobaltspeech_Cubic_RecognitionResponse>?
    
    /// Initializes audio recorder with Cubic client
    /// - Parameter client: preliminarity created Cubic client
    public init(client: Client) {
        self.client = client
        
        // Set up default recognition config
        
        config = Cobaltspeech_Cubic_RecognitionConfig()
        config.idleTimeout.seconds = 5
        config.audioEncoding = .rawLinear16
        config.enableWordConfidence = true
        config.enableWordTimeOffsets = true
    }
    
    private var audioRecorder: AVAudioRecorder!
    private var audioEngine: AVAudioEngine!
    private var audioFile: AVAudioFile!
    private var outref: ExtAudioFileRef?
    
    // MARK: Private methods
    
    fileprivate func getDocumentsDirectory() -> URL {
       let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
       let documentsDirectory = paths[0]
       return documentsDirectory
    }
    
    fileprivate func getFileURL(_ name: String = "") -> URL {
        return getDocumentsDirectory().appendingPathComponent("record\(name).wav")
    }
    
    /// Starts streaming recognize process at the beginning of the audio recording sesison
    /// - Parameters:
    ///   - config: recognition configuration
    ///   - success: successful response completion handler
    ///   - failure: fail completion handler
    fileprivate func startStream(config: Cobaltspeech_Cubic_RecognitionConfig,
                            success: @escaping (_ response: Cobaltspeech_Cubic_RecognitionResponse) -> (),
                            failure: CubicFailureCallback?) {
        call = self.client.streamingRecognize(handler: { (result) in
            success(result)
        })
        
        var request = Cobaltspeech_Cubic_StreamingRecognizeRequest()
        request.config = config

        call?.sendMessage(request).whenComplete({ (result) in
            switch result {
            case.failure(let error):
                failure?(error)
            default:
                break
            }
        })
    }
    
    /// Sends the next prepared audio chunk for recognition as part of the current streaming call
    /// - Parameters:
    ///   - audioData: audio data chunk
    ///   - config: recognition configuration
    ///   - failure: fail completion hadnler
    fileprivate func sendStreamPartToServer(_ audioData: Data,
                                            config: Cobaltspeech_Cubic_RecognitionConfig,
                                            failure: CubicFailureCallback?) {
        var request = Cobaltspeech_Cubic_StreamingRecognizeRequest()
        request.config = config
        request.audio.data = audioData
      
        call?.sendMessage(request).whenComplete({ (result) in
            switch result {
            case .failure(let error):
                failure?(error)
            default:
                break
            }
        })
    }
    
    /// Prepares an audio data chunk from the current audio buffer and send it for recognition
    /// - Parameters:
    ///   - buffer: audio buffer
    ///   - time: audio buffer time
    ///   - format: recorder audio format
    ///   - downFormat: audio format for recognition
    fileprivate func processBuffer(_ buffer: AVAudioPCMBuffer,
                                   time: AVAudioTime,
                                   format: AVAudioFormat,
                                   downFormat: AVAudioFormat) {
        let converter = AVAudioConverter(from: format, to: downFormat)
        let newBuffer = AVAudioPCMBuffer(pcmFormat: downFormat,
                                         frameCapacity: AVAudioFrameCount(downFormat.sampleRate * SAMPLE_DURATION))

        let inputBlock: AVAudioConverterInputBlock = { (inNumPackets, outStatus) -> AVAudioBuffer? in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            let audioBuffer : AVAudioBuffer = buffer
            return audioBuffer
        }
                                       
        if let newBuffer = newBuffer {
            var error: NSError?
            converter?.convert(to: newBuffer, error: &error, withInputFrom: inputBlock)
            let data = Data(buffer: newBuffer, time: time)
           
            self.sendStreamPartToServer(data, config: self.config) { (error) in
                print(error.localizedDescription)
            }

            _ = ExtAudioFileWrite(self.outref!, newBuffer.frameLength, newBuffer.audioBufferList)
        }
    }
    
    /// Closes current recognition call stream
    /// - Parameter failure: fail completion handler
    fileprivate func stopStream(failure: CubicFailureCallback?) {
        call?.sendEnd().whenFailure { (error) in
            failure?(error)
        }
    }
    
    /// Stops recording audio
    fileprivate func finishRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    /// Starts recording audio and sets up prepares data chunks from recorded audio buffer
    fileprivate func startAudioEngine() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try AVAudioSession.sharedInstance().setActive(true)
            
            if audioEngine == nil {
                audioEngine = AVAudioEngine()
            }
            
            // Set up the recorded audio format for the current device
            
            guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                             sampleRate: AVAudioSession.sharedInstance().sampleRate,
                                             channels: 1,
                                             interleaved: true) else {
                return
            }
            
            // Define the audio format to convert for recognition
                    
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: modelSampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            guard let downFormat = AVAudioFormat(settings: settings) else { return }
            audioEngine.connect(audioEngine.inputNode, to: audioEngine.mainMixerNode, format: format)

            let fileURL = getFileURL()
            
            _ = ExtAudioFileCreateWithURL(fileURL as CFURL,
                kAudioFileWAVEType,
                downFormat.streamDescription,
                nil,
                AudioFileFlags.eraseFile.rawValue,
                &outref)
            
            // Set up preparing audio data chunks during record and send them for recognition

            audioEngine.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(format.sampleRate * SAMPLE_DURATION), format: format) { (buffer, time) in
                self.processBuffer(buffer, time: time, format: format, downFormat: downFormat)
            }

            try audioEngine.start()
        } catch let error {
            print(error.localizedDescription)
            return
        }
        
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
    }
    
    /// Stops the current audio session
    fileprivate func stopAudioEngine() {
        if audioEngine != nil && audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            ExtAudioFileDispose(self.outref!)
            try! AVAudioSession.sharedInstance().setActive(false)
        }
    }
    
    // MARK: - Public methods
    
    /// Sets model ID for current recognition configuration
    /// - Parameter id: model's ID
    func setModelId(_ id: String) {
        config.modelID = id
    }
    
    /// Checks the authorization status for using microphone on the current device
    /// - Returns: `true` if authorized, `false` otherwise
    func isAuthorized() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == .authorized
    }
    
    /// Requests access to record audio on the current device
    /// - Parameter completionHandler: request completion handler
    /// - Returns: `true` is access was granted by user, `false` otherwise
    func requestAccess(completionHandler: @escaping((_ granted: Bool) -> ())) {
        AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: completionHandler)
    }
    
    /// Starts streaming recognize process at the beginning of the audio recording sesison
    func startStream() {
        startStream(config: config, success: { (response) in
            self.delegate?.audioRecorderDidReceiveRecognitionResponse(response)
        }) { (error) in
            print(error.localizedDescription)
        }

        self.startAudioEngine()
    }
    
    /// Stops streaming recognize process at the end of the audio recording sesison
    func stopStream() {
        stopAudioEngine()
        
        stopStream { (error) in
            print(error.localizedDescription)
        }
    }

}

fileprivate extension Data {
    
    init(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }

}
