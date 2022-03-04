//
//  ModelCells.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 10.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import UIKit

protocol ModelTableViewCellDelegate {
    
    func download(model: LocalModel)
    func pause()
    func cancel()
    func downloadContinue(model: LocalModel)
    func unzip(model: LocalModel)
    
}

protocol ModelTableViewCellItem {
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate)
    
}

class UnzipCancelModelTableViewCell: UITableViewCell, ModelTableViewCellItem {
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var actionButton:UIButton!
    
    var model: LocalModel!
    var delegate: ModelTableViewCellDelegate?
    
    @IBAction func onAction(_ sender: Any) {
        delegate?.download(model: model)
    }
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate) {
        self.delegate = delegate
        self.model = model
        self.name.text = model.name
    }
    
}

class NotLoadedModelTableViewCell: UITableViewCell, ModelTableViewCellItem {
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    var model: LocalModel!
    var delegate: ModelTableViewCellDelegate?
    
    @IBAction func onAction(_ sender: Any) {
        delegate?.download(model: model)
    }
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate) {
        self.delegate = delegate
        self.model = model
        self.name.text = model.name
    }
    
}

class LoadingModelTableViewCell: UITableViewCell, ModelTableViewCellItem {
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var actionButton: CircularProgressBar!
    
    var model: LocalModel!
    var delegate: ModelTableViewCellDelegate?
    
    @IBAction func onAction(_ sender: Any) {
        delegate?.pause()
    }
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate) {
        self.delegate = delegate
        self.model = model
        self.name.text = model.name
        self.actionButton.setProgress(value: model.progress)
    }
    
    func updateProgressBar() {
        self.actionButton.setProgress(value: model.progress)
    }

}

class PauseModelTableViewCell: UITableViewCell, ModelTableViewCellItem {
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var actionButton: CircularProgressBar!
    
    var model: LocalModel!
    var delegate: ModelTableViewCellDelegate?
    
    @IBAction func onAction(_ sender: Any) {
        delegate?.downloadContinue(model: model)
    }
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate) {
        self.delegate = delegate
        self.model = model
        self.name.text = model.name
        self.actionButton.setProgress(value: model.progress)
    }
    
}

class PendingModelTableViewCell: UITableViewCell, ModelTableViewCellItem {
    
    @IBOutlet weak var name: UILabel!
    
    var model: LocalModel!
    var delegate: ModelTableViewCellDelegate?
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate) {
        self.delegate = delegate
        self.model = model
        self.name.text = model.name
    }
    
}

class UnzipingModelTableViewCell: UITableViewCell, ModelTableViewCellItem {
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var actionButton: CircularProgressBar!
    
    var model: LocalModel!
    var delegate: ModelTableViewCellDelegate?
    
    @IBAction func onAction(_ sender: Any) {
        delegate?.unzip(model: model)
    }
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate) {
        self.delegate = delegate
        self.model = model
        self.name.text = model.name
        self.actionButton.setProgress(value: model.progress)
    }
    
    func updateProgressBar() {
        self.actionButton.setProgress(value: model.progress)
    }
    
}

class ModelTableViewCell: UITableViewCell, ModelTableViewCellItem {
    
    @IBOutlet weak var name: UILabel!
    
    var model: LocalModel!
    var delegate: ModelTableViewCellDelegate?
    
    func bind(model: LocalModel, _ delegate: ModelTableViewCellDelegate) {
        self.delegate = delegate
        self.model = model
        self.name.text = model.name
        self.accessoryType = model.selected ? .checkmark : .none
    }
    
}
