//
//  ModelsDownloadQueueManager.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 10.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import Foundation

public protocol ModelsDownloadQueueManagerDelegate: AnyObject {
    
    func downloadManagerDidChangeStatus(for model: LocalModel)
    func progressChange(index: Int, progress: Float)
    
}

public class ModelsDownloadQueueManager {
    
    public static let shared = ModelsDownloadQueueManager()
    
    public weak var delegate: ModelsDownloadQueueManagerDelegate?
    
    private var downloadingModel: LocalModel?
    
    private let cubicModelDownloader = ModelDownloader(productType: .cubic,
                                                       modelsRootPath: FileManager.default.cubicModelsDirectoryURL)
    
    private let diathekeModelDownloader = ModelDownloader(productType: .diatheke,
                                                          modelsRootPath: FileManager.default.diathekeModelsDirectoryURL)
    
    private let lunaModelDownloader = ModelDownloader(productType: .luna, modelsRootPath: FileManager.default.lunaModelsDirectoryURL)
    
    private func modelDownloaderForProduct(_ product: ServerProductType) -> ModelDownloader? {
        switch product {
        case .cubic:
            return cubicModelDownloader
        case .diatheke:
            return diathekeModelDownloader
        case .luna:
            return lunaModelDownloader
        }
    }
    

    public var cubicModels: [LocalModel] = []
    public var diathekeModels: [LocalModel] = []
    public var lunaModels: [LocalModel] = []
    
    private var modelId: String?
    
    init() {
        self.cubicModels = ModelStorage.shared.loadCubicModelsFromStorage()
        self.diathekeModels = ModelStorage.shared.loadDiathekeModelsFromStorage()
        self.lunaModels = ModelStorage.shared.loadLunaModelsFromStorage()
        
        for model in cubicModels {
            switch model.status {
            case .unzipping:
                model.status = .unzippingCancelled
            case .loading, .paused, .pending, .autoPaused:
                model.status = .notLoaded
            default:
                break
            }
        }
        
        for model in diathekeModels {
            switch model.status {
            case .unzipping:
                model.status = .unzippingCancelled
            case .loading, .paused, .pending, .autoPaused:
                model.status = .notLoaded
            default:
                break
            }
        }
        
        for model in lunaModels {
            switch model.status {
            case .unzipping:
                model.status = .unzippingCancelled
            case .loading, .paused, .pending, .autoPaused:
                model.status = .notLoaded
            default:
                break
            }
        }
        
        self.cubicModelDownloader.delegate = self
        self.diathekeModelDownloader.delegate = self
        self.lunaModelDownloader.delegate = self
        
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func pause() {
        if let model = self.downloadingModel, let productType = ServerProductType(rawValue: model.productType) {
            self.modelDownloaderForProduct(productType)?.pauseDownload()
            model.status = .paused
            delegate?.downloadManagerDidChangeStatus(for: model)
        }
    }
    
    func cancel() {
        if let model = self.downloadingModel, let productType = ServerProductType(rawValue: model.productType) {
            self.modelDownloaderForProduct(productType)?.cancelDownload()
            model.status = .notLoaded
        }
        
        downloadIfExistPending()
    }
    
    func saveCubicModels() {
        ModelStorage.shared.saveCubicModelsToStorage(models: self.cubicModels)
    }
    
    func saveDiathekeModels() {
        ModelStorage.shared.saveDiathekeModelsToStorage(models: self.diathekeModels)
    }
    
    func saveLunaModels() {
        ModelStorage.shared.saveLunaModelsToStorage(models: self.lunaModels)
    }
    
    func downloadIfExistPending() {
        if let model = self.cubicModels.first(where: { $0.status == .pending }) {
            self.download(model: model)
            return
        }
        
        if let model = self.diathekeModels.first(where: { $0.status == .pending }) {
            self.download(model: model)
        }
        
        if let model = self.lunaModels.first(where: { $0.status == .pending }) {
            self.download(model: model)
        }
    }
    
    func removeZip(model: LocalModel) {
        if let zipPath = model.zipPath {
            do {
                try FileManager.default.removeItem(atPath: zipPath)
            } catch let e {
                print(e.localizedDescription)
            }
            
            model.zipPath = nil
        }
    }
    
    func removeCubicModel(atIndex: Int) {
        let model = self.cubicModels[atIndex]
        
        if let status = model.status {
            switch status {
            case .loading, .paused:
                self.cancel()
            case .unzipping:
                self.unzipCancel()
                self.removeZip(model: model)
            default:
                break
            }
        }
        
        if model.id != "" {
            let modelDirectoryPath = FileManager.default.getCubicModelDirectory(path: model.id)
            try? FileManager.default.removeItem(at: modelDirectoryPath)
        }
        
        cubicModels.remove(at: atIndex)
        saveCubicModels()
    }
    
    func removeDiathekeModel(atIndex: Int) {
        let model = self.diathekeModels[atIndex]
        
        if let status = model.status {
            switch status {
            case .loading, .paused:
                self.cancel()
            case .unzipping:
                self.unzipCancel()
                self.removeZip(model: model)
            default:
                break
            }
        }
        
        if model.id != "" {
            let modelDirectoryPath = FileManager.default.getDiathekeModelDirectory(path: model.id)
            try? FileManager.default.removeItem(at: modelDirectoryPath)
        }
        
        diathekeModels.remove(at: atIndex)
        saveDiathekeModels()
    }
    
    func removeLunaModel(atIndex: Int) {
        let model = self.lunaModels[atIndex]
        
        if let status = model.status {
            switch status {
            case .loading, .paused:
                self.cancel()
            case .unzipping:
                self.unzipCancel()
                self.removeZip(model: model)
            default:
                break
            }
        }
        
        if model.id != "" {
            let modelDirectoryPath = FileManager.default.getLunaModelDirectory(path: model.id)
            try? FileManager.default.removeItem(at: modelDirectoryPath)
        }
        
        lunaModels.remove(at: atIndex)
        saveLunaModels()
    }
    
    func unzipCancel() {
        if let model = self.downloadingModel {
            model.status = .unzippingCancelled
            self.downloadingModel = nil
            delegate?.downloadManagerDidChangeStatus(for: model)
        }
    }

    func addCubicModel(_ model: LocalModel) {
        cubicModels.append(model)
        download(model: model)
    }
    
    func addDiathekeModel(_ model: LocalModel) {
        diathekeModels.append(model)
        download(model: model)
    }
    
    func addLunaModel(_ model: LocalModel) {
        lunaModels.append(model)
        download(model: model)
    }

    func download(model: LocalModel, resume: Data? = nil) {
        if self.downloadingModel != nil && self.downloadingModel?.name != model.name {
            model.status = .pending
        } else if let productType = ServerProductType(rawValue: model.productType) {
            model.status = .loading
            model.task = self.modelDownloaderForProduct(productType)?.download(id: model.id,
                                                                               url: model.url,
                                                                               resume: resume)
            downloadingModel = model
        }
        
        saveCubicModels()
        saveDiathekeModels()
        saveLunaModels()
        delegate?.downloadManagerDidChangeStatus(for: model)
    }
    
    func continueDownload() {
        if let model = self.downloadingModel, let productType = ServerProductType(rawValue: model.productType) {
            model.status = .loading
            self.modelDownloaderForProduct(productType)?.continueDownload()
            delegate?.downloadManagerDidChangeStatus(for: model)
        }
    }
    
    func unzip(model: LocalModel) {
        if self.downloadingModel != nil {
            model.status = .pending
        } else {
            model.status = .unzipping
            if let zipPath =  model.zipPath, let productType = ServerProductType(rawValue: model.productType) {
                self.modelDownloaderForProduct(productType)?.unzipWithProgress(zipUrl: URL(fileURLWithPath: zipPath))
            }
            downloadingModel = model
        }
        
        delegate?.downloadManagerDidChangeStatus(for: model)
    }
    
}

// MARK: - Application lifecycle

extension ModelsDownloadQueueManager {
    
    func becomeActive() {
        if let dm = self.downloadingModel, let productType = ServerProductType(rawValue: dm.productType) {
            dm.status = .loading
            self.modelDownloaderForProduct(productType)?.continueDownload()
        }
    }
    
    func resignActive() {
        if let dm = self.downloadingModel, let productType = ServerProductType(rawValue: dm.productType) {
            dm.status = .autoPaused
            self.modelDownloaderForProduct(productType)?.pauseDownload()
        }
    }
    
}

// MARK: - CubicDownloaderDelegate

extension ModelsDownloadQueueManager: ModelDownloaderDelegate {
    
    public func modelDownloader(_ downloader: ModelDownloader, didChangeStatus status: ModelDownloaderStatus, withProgress progress: Float) {
        if let model = self.downloadingModel {
            model.progress = progress
            model.status = status == .downloading ? .loading : .unzipping
            self.delegate?.progressChange(index: 0, progress: progress)
        }
    }
    
    public func modelDownloader(_ downloader: ModelDownloader, didFinishDownloadingToPath path: String) {
        if let model = self.downloadingModel {
            model.zipPath = path
            model.status = .unzipping
            saveCubicModels()
            saveDiathekeModels()
            saveLunaModels()
            delegate?.downloadManagerDidChangeStatus(for: model)
        }
    }
    
    public func modelDownloader(_ downloader: ModelDownloader, didUnzipToPath path: String) {
        if let model = self.downloadingModel {
            model.id = path
            removeZip(model: model)
            model.status = .ready
            
            if model.productType == ServerProductType.cubic.rawValue {
                model.path = path + "/" + model.url.deletingPathExtension().lastPathComponent + "/" + "model.config"
                model.selected = self.cubicModels.count == 1
                ModelStorage.shared.saveCubicModelsToStorage(models: cubicModels)
            } else if model.productType == ServerProductType.diatheke.rawValue {
                model.path = path + "/" + model.url.deletingPathExtension().lastPathComponent + "/" + "model_config.yaml"
                model.selected = self.diathekeModels.count == 1
                ModelStorage.shared.saveDiathekeModelsToStorage(models: diathekeModels)
            } else if model.productType == ServerProductType.luna.rawValue {
                model.path = path + "/" + model.url.deletingPathExtension().lastPathComponent + "/" + "local_synth.toml"
                model.selected = self.lunaModels.count == 1
                ModelStorage.shared.saveLunaModelsToStorage(models: lunaModels)
            }

            self.downloadingModel = nil
            downloadIfExistPending()
            
            delegate?.downloadManagerDidChangeStatus(for: model)
        }
    }
    
    public func modelDownloader(_ downloader: ModelDownloader, didCompleteWithError error: Error?, resumeData: Data?) {
        if let model = self.downloadingModel {
            self.downloadingModel = nil
            self.download(model: model, resume: resumeData)
            delegate?.downloadManagerDidChangeStatus(for: model)
        }
    }
    
    public func modelDownloader(_ downloader: ModelDownloader, didCancelLoadingWithResumeData resumeData: Data?) {
        if let model = self.downloadingModel {
            model.status = .notLoaded
            self.downloadingModel = nil
            delegate?.downloadManagerDidChangeStatus(for: model)
        }
    }
    
}
