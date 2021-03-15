//
//  ARFileManager.swift
//  DiathekeSDKExample
//
//  Created by Eduard Miniakhmetov on 27.04.2020.
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

class ARFileManager {

     static let shared = ARFileManager()
     let fileManager = FileManager.default

     var documentDirectoryURL: URL? {
         return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
     }

     func createWavFile(using rawData: Data) throws -> URL {
          //Prepare Wav file header
          let waveHeaderFormate = createWaveHeader(data: rawData) as Data

          //Prepare Final Wav File Data
          let waveFileData = waveHeaderFormate + rawData

          //Store Wav file in document directory.
          return try storeAudioFile(data: waveFileData)
      }

      private func createWaveHeader(data: Data) -> NSData {

           let sampleRate:Int32 = 48000
           let chunkSize:Int32 = 36 + Int32(data.count)
           let subChunkSize:Int32 = 16
           let format:Int16 = 1
           let channels:Int16 = 1
           let bitsPerSample:Int16 = 16
           let byteRate:Int32 = sampleRate * Int32(channels * bitsPerSample / 8)
           let blockAlign: Int16 = channels * bitsPerSample / 8
           let dataSize:Int32 = Int32(data.count)

           let header = NSMutableData()

           header.append([UInt8]("RIFF".utf8), length: 4)
           header.append(intToByteArray(chunkSize), length: 4)

           //WAVE
           header.append([UInt8]("WAVE".utf8), length: 4)

           //FMT
           header.append([UInt8]("fmt ".utf8), length: 4)

           header.append(intToByteArray(subChunkSize), length: 4)
           header.append(shortToByteArray(format), length: 2)
           header.append(shortToByteArray(channels), length: 2)
           header.append(intToByteArray(sampleRate), length: 4)
           header.append(intToByteArray(byteRate), length: 4)
           header.append(shortToByteArray(blockAlign), length: 2)
           header.append(shortToByteArray(bitsPerSample), length: 2)

           header.append([UInt8]("data".utf8), length: 4)
           header.append(intToByteArray(dataSize), length: 4)

           return header
      }

     private func intToByteArray(_ i: Int32) -> [UInt8] {
           return [
             //little endian
             UInt8(truncatingIfNeeded: (i      ) & 0xff),
             UInt8(truncatingIfNeeded: (i >>  8) & 0xff),
             UInt8(truncatingIfNeeded: (i >> 16) & 0xff),
             UInt8(truncatingIfNeeded: (i >> 24) & 0xff)
            ]
      }

      private func shortToByteArray(_ i: Int16) -> [UInt8] {
             return [
                 //little endian
                 UInt8(truncatingIfNeeded: (i      ) & 0xff),
                 UInt8(truncatingIfNeeded: (i >>  8) & 0xff)
             ]
       }

    func storeAudioFile(data: Data) throws -> URL {
        let fileName = "Record-\(Date())"

        if let filePath = documentDirectoryURL?.appendingPathComponent("\(fileName).wav") {
            try data.write(to: filePath)
            return filePath //Save file's path respected to document directory.
        }
        
        return URL(fileURLWithPath: "")
    }
}
