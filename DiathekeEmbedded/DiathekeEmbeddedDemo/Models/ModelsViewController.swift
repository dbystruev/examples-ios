//
//  ModelsViewController.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 10.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import UIKit

protocol ModelsViewControllerDelegate: AnyObject {
    
    func modelsViewControllerDidUpdateModels(_ models: [LocalModel])
    func modelsViewControllerDidSelectModel(_ model: LocalModel?)
    func modelsViewControllerDidRemoveModel(with id: String, for product: String)
    func modelsViewControllerDidAddModel(_ model: LocalModel)
    
}

class ModelsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, ModelTableViewCellDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    public var productType: ServerProductType!
    
    private let downloadManager: ModelsDownloadQueueManager = ModelsDownloadQueueManager.shared
    
    var selectedModelIndex: Int?
    var delegate: ModelsViewControllerDelegate?
    
    var models: [LocalModel] {
        get {
            switch productType {
            case .cubic:
                return downloadManager.cubicModels
            case .diatheke:
                return downloadManager.diathekeModels
            case .luna:
                return downloadManager.lunaModels
            case .none:
                return []
            }
        }
        set {
            switch productType {
            case .cubic:
                downloadManager.cubicModels = newValue
            case .diatheke:
                downloadManager.diathekeModels = newValue
            case .luna:
                downloadManager.lunaModels = newValue
            case .none:
                break
            }
        }
    }
    
    func downloadContinue(model: LocalModel) {
        self.downloadManager.continueDownload()
    }
    
    func download(model: LocalModel) {
        self.downloadManager.download(model: model)
    }
    
    func unzip(model: LocalModel) {
        self.downloadManager.unzip(model: model)
    }
    
    func cancel() {
        self.downloadManager.cancel()
    }
    
    func pause() {
        self.downloadManager.pause()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.downloadManager.delegate = self
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.models.count > 0, let selectedModelIndex = selectedModelIndex {
            let indexPath = IndexPath(row: selectedModelIndex, section: 0)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .top)
            tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            delegate?.modelsViewControllerDidUpdateModels(models)
        }
    }
    
    @IBAction func urlButtonTapped(_ sender: Any) {
        let alertController =
            UIAlertController(title: "Model URL",
                              message: "Paste model URL here",
                              preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Model Name"
        }
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Model Url"
        }
        
        let connectAction = UIAlertAction(title: "Download", style: .default) { [weak alertController] (action) in
            self.downloadAction(alertController: alertController)
        }
        alertController.addAction(connectAction)
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .cancel,
                                         handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func showError() {
        let alertController =
            UIAlertController(title: "Error",
                              message: "Invalid URL",
                              preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Ok",
                                         style: .cancel,
                                         handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func verifyUrl(urlString: String?) -> Bool {
        if let urlString = urlString {
            if let url = NSURL(string: urlString) {
                return UIApplication.shared.canOpenURL(url as URL)
            }
        }
        
        return false
    }
    
    // MARK: - UITableViewDataSource methods
    
    private func downloadAction(alertController: UIAlertController?) {
        guard var name = alertController?.textFields?[0].text else { return }
        guard let urlString = alertController?.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }
        
        guard let url = URL(string: urlString) else { return }
        
        if name == "" {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            let someDateTime = formatter.string(from: Date())
            name = someDateTime
        }
        
        let model = LocalModel(productType: productType.rawValue, name: name, url: url)
        
        switch productType {
        case .cubic:
            self.downloadManager.addCubicModel(model)
        case .diatheke:
            self.downloadManager.addDiathekeModel(model)
        case .luna:
            self.downloadManager.addLunaModel(model)
        case .none:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }
    
    func identifierType(model: LocalModel) -> String {
        switch model.status {
        case .notLoaded:
            return "NotLoadedModelTableViewCell"
        case .pending:
            return "PendingModelTableViewCell"
        case .loading:
            return "LoadingModelTableViewCell"
        case .paused:
            return "PauseModelTableViewCell"
        case .unzipping:
            return "UnzipingModelTableViewCell"
        case .ready:
            return "ModelTableViewCell"
        case .unzippingCancelled:
            return "UnzipCancelModelTableViewCell"
        case .none, .autoPaused:
            
            return ""
        
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = models[indexPath.row]
        let identifier = identifierType(model:model)
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        
        if let modelCell = cell as? ModelTableViewCellItem {
            modelCell.bind(model: model ,self)
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = models[indexPath.row]
        
        guard model.status == .ready else { return }
        
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        if cell.accessoryType == .checkmark  {
            cell.accessoryType = .none
            delegate?.modelsViewControllerDidSelectModel(nil)
        } else {
            cell.accessoryType = .checkmark
            delegate?.modelsViewControllerDidSelectModel(model)
        }
        
        for i in 0..<models.count {
            models[i].selected = false
        }
        
        model.selected = true
        
        switch productType {
        case .cubic:
            downloadManager.saveCubicModels()
        case .diatheke:
            downloadManager.saveDiathekeModels()
        case .luna:
            downloadManager.saveLunaModels()
        case .none:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .normal, title:  "Delete", handler: { (ac: UIContextualAction, view: UIView, success: (Bool) -> Void) in
            self.delegate?.modelsViewControllerDidRemoveModel(with: self.models[indexPath.row].id,
                                                              for: self.models[indexPath.row].productType)
            
            switch self.productType {
            case .cubic:
                self.downloadManager.removeCubicModel(atIndex: indexPath.row)
            case .diatheke:
                self.downloadManager.removeDiathekeModel(atIndex: indexPath.row)
            case .luna:
                self.downloadManager.removeLunaModel(atIndex: indexPath.row)
            case .none:
                break
            }
            self.tableView.reloadData()
            success(true)
        })
        
        deleteAction.backgroundColor = .red
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
    }
    
}

extension ModelsViewController: ModelsDownloadQueueManagerDelegate {
    
    func downloadManagerDidChangeStatus(for model: LocalModel) {
        if model.status == .ready {
            self.delegate?.modelsViewControllerDidAddModel(model)
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    func progressChange(index: Int, progress: Float) {
        DispatchQueue.main.async {
            let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0))
            
            if let cell = cell as? LoadingModelTableViewCell {
                cell.updateProgressBar()
            }
                    
            if let cell = cell as? UnzipingModelTableViewCell {
                cell.updateProgressBar()
            }
        }
    }
    
}
