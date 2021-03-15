//
//  ViewController.swift
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
import Foundation
import Cubic

fileprivate struct Configuration: Codable {
    
    var host: String
    var port: Int
    
}

class ViewController: UIViewController, UIGestureRecognizerDelegate, AudioRecorderDelegate {
    
    fileprivate let RECORDSESSION_RESULTS_DELIMITER = "\n"
   
    fileprivate var configuration = Configuration(host: "demo.cobaltspeech.com", port: 2727)
    
    @IBOutlet weak var resultTextView: TextView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet var settingsBarButtonItem: UIBarButtonItem!
    @IBOutlet var tlsBarItem: UIBarButtonItem!
    @IBOutlet weak var clearButton: UIButton!
    
    var activityIndicator = UIActivityIndicatorView(style: .medium)
    var activityBarItem: UIBarButtonItem!
    
    var models: [Cobaltspeech_Cubic_Model] = []
    
    var currentResult: String = ""
    var partialResult: String = ""
    
    var selectedModelIndex: Int? {
        didSet {
            if let selectedModelIndex = selectedModelIndex {
                audioRecorder.setModelId(models[selectedModelIndex].id)
                audioRecorder.modelSampleRate = models[selectedModelIndex].attributes.sampleRate
            }
        }
    }
    
    var audioRecorder: AudioRecorder!
    var client: Client!
    
    // MARK: - ViewController lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.hidesWhenStopped = true
        activityBarItem = UIBarButtonItem(customView: activityIndicator)

        createCubicManager(useTLS: true)
    }
   
    // MARK: - Private methods
    
    fileprivate func clearResults() {
        DispatchQueue.main.async {
            self.resultTextView.text = ""
            self.currentResult = ""
            self.partialResult = ""
        }
    }
    
    fileprivate func listModels() {
        client.listModels(success: { (models) in
            self.clearResults()
            
            if let models = models {
                self.models = models
                
                if models.count > 0 {
                    self.selectedModelIndex = 0
                }
                
                self.setRecordButtonEnabled(isEnabled: true)
            } else {
                self.setRecordButtonEnabled(isEnabled: false)
            }
            
            DispatchQueue.main.async {
                self.settingsBarButtonItem.isEnabled = true
                self.navigationItem.rightBarButtonItems?[0] = self.settingsBarButtonItem
            }
        }) { (error) in
            print(error)
            self.models = []
            
            DispatchQueue.main.async {
                self.resultTextView.text = NSLocalizedString("no_connection", comment: "")
                self.settingsBarButtonItem.isEnabled = false
                self.navigationItem.rightBarButtonItems?[0] = self.settingsBarButtonItem
            }
            
            self.setRecordButtonEnabled(isEnabled: false)
        }
    }
    
    fileprivate func createCubicManager(useTLS: Bool) {
        client = Client(host: configuration.host, port: configuration.port, useTLS: useTLS)
        audioRecorder = AudioRecorder(client: client)
        audioRecorder.delegate = self
        navigationItem.rightBarButtonItems?[0] = activityBarItem
        activityIndicator.startAnimating()
        setRecordButtonEnabled(isEnabled: false)
        resultTextView.text = ""

        listModels()
    }
    
    fileprivate func setRecordButtonEnabled(isEnabled: Bool) {
        DispatchQueue.main.async {
            self.recordButton.isEnabled = isEnabled
        }
    }
    
    fileprivate func connectAction(alertController: UIAlertController?, useTLS: Bool) {
        guard let textField = alertController?.textFields?[0] else { return }
        
        guard let url = textField.text else {
            showInvalidURLMessage()
            return
        }
        
        let items = url.split(separator: ":")
        
        guard items.count == 2, let port = Int(items[1]) else {
            showInvalidURLMessage()
            return
        }
        
        configuration.host = String(items[0])
        configuration.port = port
                
        createCubicManager(useTLS: useTLS)
    }
    
    fileprivate func showInvalidURLMessage() {
        resultTextView.text = NSLocalizedString("invalid_url", comment: "")
    }
    
    // MARK: - Actions
    
    @IBAction func urlButtonTapped(_ sender: Any) {
        let alertController =
            UIAlertController(title: NSLocalizedString("alert.cubic_url_title", comment: ""),
                              message: NSLocalizedString("alert.cubic_url_message", comment: ""),
                              preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.text = "\(self.configuration.host):\(self.configuration.port)"
        }
        
        let connectAction = UIAlertAction(title: NSLocalizedString("button.connect", comment: ""), style: .default) { [weak alertController] (action) in
            self.tlsBarItem.image = UIImage(systemName: "lock.slash")
            self.connectAction(alertController: alertController, useTLS: false)
        }
        
        alertController.addAction(connectAction)
        
        let secureConnectAction = UIAlertAction(title: NSLocalizedString("button.connect.tls", comment: ""), style: .default) { [weak alertController] (action) in
            self.tlsBarItem.image = UIImage(systemName: "lock")
            self.connectAction(alertController: alertController, useTLS: true)
        }
        
        alertController.addAction(secureConnectAction)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("button.cancel", comment: ""),
                                         style: .cancel,
                                         handler: nil)
        
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func recordClickDown(sender:UIButton)  {
        if audioRecorder.isAuthorized() {
            if !currentResult.isEmpty {
                currentResult = currentResult + RECORDSESSION_RESULTS_DELIMITER
            }

            self.recordButton.tintColor = UIColor.red
            self.audioRecorder.startStream()
        } else {
            self.audioRecorder.requestAccess { (granted) in
                 print("recordClick \(granted)")
            }
        }
    }
    
    @IBAction func recordClickUp(sender:UIButton)  {
        self.audioRecorder.stopStream()
        self.recordButton.tintColor = self.view.tintColor
    }
    
    @IBAction func clearButtonTapped(_ sender: Any) {
        clearResults()
    }
    
    // MARK: - Response processing
    
    private func printResult(response: Cobaltspeech_Cubic_RecognitionResponse?) {
        guard let response = response else { return }
        
        for result in response.results {
            guard let firstAlternative = result.alternatives.first else { continue }
            
            var spaceDelimiter = ""
            
            if !currentResult.isEmpty && !currentResult.hasSuffix(RECORDSESSION_RESULTS_DELIMITER) {
                spaceDelimiter = " "
            }
            
            if result.isPartial {
                partialResult = firstAlternative.transcript
                resultTextView.text = currentResult + spaceDelimiter + partialResult
            } else {
                partialResult = ""
                currentResult = currentResult + spaceDelimiter + firstAlternative.transcript
                resultTextView.text = currentResult
            }
        }
    }

    func audioRecorderDidReceiveRecognitionResponse(_ response: Cobaltspeech_Cubic_RecognitionResponse) {
        DispatchQueue.main.async {
            self.printResult(response: response)
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let settingsViewController = segue.destination as? SettingsViewController {
            settingsViewController.delegate = self
            settingsViewController.models = models
            settingsViewController.selectedModelIndex = selectedModelIndex
        }
    }
    
}

extension ViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        clearButton.isHidden = textView.text.isEmpty
    }
    
}

// MARK: - SettingsViewControllerDelegate methods

extension ViewController: SettingsViewControllerDelegate {
    
    func settingsViewControllerDidChangeModelType(at index: Int) {
        selectedModelIndex = index
    }
    
}

class TextView: UITextView {
    
    override var text: String! {
        didSet {
            delegate?.textViewDidChange?(self)
        }
    }
    
}
