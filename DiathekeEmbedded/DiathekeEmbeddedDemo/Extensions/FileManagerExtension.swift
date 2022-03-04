//
//  FileManagerExtension.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 10.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import Foundation

extension FileManager {
    
    public var documentsDirectoryURL: URL {
        get {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return paths.first!
        }
    }
    
    private func buildAndCreateDirectoryURL(_ url: URL) -> URL {
        if !directoryExists(path: url.path) {
            do {
                try createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                print(error)
            }
        }
        
        return url
    }
    
    private func serverDirectoryURL(_ product: String) -> URL {
        return buildAndCreateDirectoryURL(documentsDirectoryURL.appendingPathComponent(product))
    }
    
    private func resourcesDirectoryURL(product: String, resource: String) -> URL {
        let serverDirectoryURL = serverDirectoryURL(product)
        let resourceDirectoryURL = serverDirectoryURL.appendingPathComponent(resource)
        return buildAndCreateDirectoryURL(resourceDirectoryURL)
    }
    
    private func modelsDirectoryURL(_ product: String) -> URL {
        let url = serverDirectoryURL(product).appendingPathComponent(Constants.MODELS_DIRECTORY)
        return buildAndCreateDirectoryURL(url)
    }
    
    
    public var cubicDirectoryURL: URL {
        get {
            return serverDirectoryURL(Constants.CUBICSVR_DIRECTORY)
        }
    }
    
    public var cubicModelsDirectoryURL: URL {
        get {
            return resourcesDirectoryURL(product: Constants.CUBICSVR_DIRECTORY, resource: Constants.MODELS_DIRECTORY)
        }
    }
    
    public var cubicLicenseDirectoryURL: URL {
        get {
            return resourcesDirectoryURL(product: Constants.CUBICSVR_DIRECTORY, resource: Constants.LICENSES_DIRECTORY)
        }
    }
    
    public var lunaDirectoryURL: URL {
        get {
            return serverDirectoryURL(Constants.LUNASVR_DIRECTORY)
        }
    }
    
    public var lunaModelsDirectoryURL: URL {
        get {
            return resourcesDirectoryURL(product: Constants.LUNASVR_DIRECTORY, resource: Constants.MODELS_DIRECTORY)
        }
    }
    
    public var diathekeDirectoryURL: URL {
        get {
            return serverDirectoryURL(Constants.DIATHEKESVR_DIRECTORY)
        }
    }
    
    public var diathekeModelsDirectoryURL: URL {
        get {
            return resourcesDirectoryURL(product: Constants.DIATHEKESVR_DIRECTORY, resource: Constants.MODELS_DIRECTORY)
        }
    }
    
    public var diathekeLicenseDirectoryURL: URL {
        get {
            return resourcesDirectoryURL(product: Constants.DIATHEKESVR_DIRECTORY, resource: Constants.LICENSES_DIRECTORY)
        }
    }
    
    public func getCubicModelDirectory(path: String) -> URL {
        return cubicModelsDirectoryURL.appendingPathComponent(path)
    }
    
    public func getLunaModelDirectory(path: String) -> URL {
        return lunaModelsDirectoryURL.appendingPathComponent(path)
    }
    
    public func getDiathekeModelDirectory(path: String) -> URL {
        return diathekeModelsDirectoryURL.appendingPathComponent(path)
    }
    
    func directoryExists(path: String) -> Bool {
        var isDirectory = ObjCBool(true)
        let directoryExists = fileExists(atPath: path, isDirectory: &isDirectory)
        
        return directoryExists && isDirectory.boolValue
    }

    func findModelConfig(at directory: URL) -> URL? {
        if let enumerator = self.enumerator(at: directory,
                                            includingPropertiesForKeys: [.isRegularFileKey],
                                            options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if fileAttributes.isRegularFile == true && fileURL.lastPathComponent == "model.config" {
                        return fileURL
                    }
                } catch {
                    print(error)
                }
            }
        }
        
        return nil
    }

}
