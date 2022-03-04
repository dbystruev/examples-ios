//
//  ModelStorage.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 10.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import Foundation

open class ModelStorage {
    
    private let CUBIC_MODELS_KEY = "cubic_models"
    private let DIATHEKE_MODELS_KEY = "diatheke_models"
    private let LUNA_MODELS_KEY = "luna_models"
    
    public static let shared = ModelStorage()
    
    private func save(models: [LocalModel], key: String) {
        let encoder = JSONEncoder()
        
        do {
            let data = try encoder.encode(models)
            let modelsData = String(data: data, encoding: String.Encoding.utf8)
            UserDefaults.standard.set(modelsData, forKey: key)
        } catch {
            print("\(Self.self) error: \(error)")
        }
    }
    
    private func load(key: String) -> [LocalModel] {
        do {
            guard let str = UserDefaults.standard.string(forKey: key), let data = str.data(using: .utf8) else {
                return []
            }
            
            let models = try JSONDecoder().decode([LocalModel].self, from: data)
            return models
        } catch {
            print(error.localizedDescription)
            return []
        }
    }
    
    public func saveCubicModelsToStorage(models: [LocalModel]) {
        save(models: models, key: CUBIC_MODELS_KEY)
    }
    
    public func loadCubicModelsFromStorage() -> [LocalModel] {
        return load(key: CUBIC_MODELS_KEY)
    }
    
    public func saveDiathekeModelsToStorage(models: [LocalModel]) {
        save(models: models, key: DIATHEKE_MODELS_KEY)
    }
    
    public func loadDiathekeModelsFromStorage() -> [LocalModel] {
        return load(key: DIATHEKE_MODELS_KEY)
    }
    
    public func loadLunaModelsFromStorage() -> [LocalModel] {
        return load(key: LUNA_MODELS_KEY)
    }
    
    public func saveLunaModelsToStorage(models: [LocalModel]) {
        save(models: models, key: LUNA_MODELS_KEY)
    }
    
}
