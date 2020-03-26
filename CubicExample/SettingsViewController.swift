//
//  SettingsViewController.swift
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

import UIKit
import Cubic

protocol SettingsViewControllerDelegate: class {
    
    func settingsViewControllerDidChangeModelType(at index: Int)
    
}

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var models: [Cobaltspeech_Cubic_Model]!
    
    var selectedModelIndex: Int?
    
    var delegate: SettingsViewControllerDelegate?
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if models.count > 0, let selectedModelIndex = selectedModelIndex {
            let indexPath = IndexPath(row: selectedModelIndex, section: 0)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .top)
            tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    
    // MARK: - UITableViewDataSource methods

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ModelTypeCell", for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.text = models[indexPath.row].name
        return cell
    }
    
    // MARK: - UITableViewDeelegate methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        delegate?.settingsViewControllerDidChangeModelType(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
    }
    
}
