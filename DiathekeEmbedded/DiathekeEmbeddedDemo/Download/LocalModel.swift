//
//  LocalModel.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 09.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
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

/// LocalModel represents ASR, Dialogue, and/or NLU models downloaded from
/// a source separate from the app code itself.
open class LocalModel: Codable {
    
    public var productType: String
    public var id: String = ""
    public let name: String
    public let url: URL
    public var zipPath: String?
    public var path: String?
    public var selected: Bool
    public var status: ModelStatus?
    public var progress: Float = 0
    public var task: URLSessionDownloadTask? = nil
    
    private func modelDirectory() -> String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    public init(productType: String, name: String, url: URL, path: String?, selected: Bool, status: ModelStatus, progress: Float) {
        self.productType = productType
        self.name = name
        self.url = url
        self.path = path
        self.selected = selected
        self.status = zipPath == nil ? ModelStatus.notLoaded : path != nil ? ModelStatus.ready : ModelStatus.ready
        self.progress = progress
        self.status = status
    }
    
    public init(productType: String, name: String, url: URL) {
        self.productType = productType
        self.name = name
        self.url = url
        self.path = nil
        self.selected = false
        self.status = .notLoaded
        self.progress = 0
        
    }
    
    private enum CodingKeys: String, CodingKey {
        case productType
        case id
        case name
        case url
        case path
        case selected
        case status
    }
    
}
