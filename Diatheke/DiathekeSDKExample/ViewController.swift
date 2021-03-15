//
//  ViewController.swift
//  DiathekeSDKExample
//
//  Created by Eduard Miniakhmetov on 20.04.2020.
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

import UIKit
import Diatheke
import GRPC
import AVFoundation
import NIO

enum MessageType: String {
    
    case user = "UserMessageCell"
    case reply = "ServerMessageCell"
    case command = "CommandCell"
    case error = "ErrorCell"
    case commandResult = "CommandResultCell"
    
}

struct Message {
    
    var text: String
    var type: MessageType
    
}

class ViewController: UIViewController {
    
    // MARK: - UserDefaults Keys
    
    fileprivate let udHostKey = "host"
    fileprivate let udPortKey = "port"
    fileprivate let udUseTLSKey = "useTLS"
    
    // MARK: - Outlets
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var chooseModelButton: UIBarButtonItem!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var recordDurationLabel: UILabel!
    @IBOutlet weak var bottomViewBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Private properties
    
    fileprivate var client: Client!                             // Diatheke Client
    fileprivate var host: String?                               // Connection host (100.78.103.101)
    fileprivate var port: Int?                                  // Connection port (9071)
    fileprivate var useTLS = false
    
    fileprivate var player: AVAudioPlayer?                      // Audio player for TTS
    fileprivate var recorder = Recorder()                       // Audio recorder for ASR
    
    fileprivate var messages: [Message] = []                    // Messages TableView Data Source
    
    fileprivate var tokenData: Cobaltspeech_Diatheke_TokenData? // Current Session Token
    
    fileprivate var audioData: Data?                            // TTS audio data
    fileprivate var asrStream: ASRStream?
    fileprivate var ttsStream: TTSStream?
    
    fileprivate var models: [Cobaltspeech_Diatheke_ModelInfo] = []
    
    fileprivate var model: Cobaltspeech_Diatheke_ModelInfo? {
        didSet {
            self.messages.removeAll()
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            
            if let model = model {
                DispatchQueue.main.async {
                    self.recordButton.isEnabled = true
                    self.textField.isEnabled = true
                    self.title = "Diatheke Demo - \(model.name)"
                }
                self.recorder.modelSampleRate = model.asrSampleRate
                self.createSession(for: model)
            } else {
                DispatchQueue.main.async {
                    self.recordButton.isEnabled = false
                    self.textField.isEnabled = false
                    self.title = "Diatheke Demo"
                }
            }
        }
    }

    fileprivate var isRecording = false {
        didSet {
            guard isViewLoaded else { return }
            
            if isRecording {
                UIView.transition(with: recordButton,
                                  duration: 0.2,
                                  options: .transitionFlipFromBottom,
                                  animations: { self.recordButton.setImage(UIImage(named: "stop_record"), for: .normal) },
                                  completion: nil)
            
                
                textField.isHidden = true
                recordDurationLabel.isHidden = false
                
                
                recordDuration = 0
                recordDurationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer) in
                    self.recordDuration += timer.timeInterval
                })
            } else {
                UIView.transition(with: recordButton,
                                  duration: 0.2,
                                  options: .transitionFlipFromTop,
                                  animations: { self.recordButton.setImage(UIImage(named: "start_record"), for: .normal) },
                                  completion: nil)
                textField.isHidden = false
                recordDurationLabel.isHidden = true
                recordDurationTimer.invalidate()
            }
        }
    }
    
    fileprivate var recordDurationTimer: Timer!
    
    fileprivate var recordDuration: TimeInterval = 0 {
        didSet {
            let duration = Int(self.recordDuration)
            let seconds = duration % 60
            let minutes = (duration / 60) % 60
            let hours = (duration / 3600)
            DispatchQueue.main.async {
                self.recordDurationLabel.text = String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        restoreConnectionSettings()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasHidden(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        connect()
        
        recorder.sendAudioChunkBlock = { data in
            self.asrStream?.sendAudio(data: data, completion: { (error) in
                if let error = error {
                    print(error)
                }
            })
        }
    }
    
    /// Extracts last successful connection settings form UserDefaults
    fileprivate func restoreConnectionSettings() {
        host = UserDefaults.standard.string(forKey: udHostKey)
        port = UserDefaults.standard.integer(forKey: udPortKey)
        useTLS = UserDefaults.standard.bool(forKey: udUseTLSKey)
    }
    
    /// Saves last successful connection settings to UserDefaults
    fileprivate func saveConnectionSettings() {
        UserDefaults.standard.set(host, forKey: udHostKey)
        UserDefaults.standard.set(port, forKey: udPortKey)
        UserDefaults.standard.set(useTLS, forKey: udUseTLSKey)
    }
    
    fileprivate func askToReconnect() {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: "Diatheke",
                                       message: "Server is not available. Try to connect again?",
                                       preferredStyle: .alert)
            let connectAction = UIAlertAction(title: "Connect", style: .default) { (action) in
                self.reconnect()
            }
            ac.addAction(connectAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            ac.addAction(cancelAction)
            self.present(ac, animated: true)
        }
    }
    
    /// Clears all data and connects to new host
    fileprivate func reconnect() {
        messages.removeAll()
        models.removeAll()
        model = nil
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        self.connect()
    }
    
    /// Connects to new host and receives models
    fileprivate func connect() {
        DispatchQueue.main.async {
            self.chooseModelButton.isEnabled = false
        }

        guard let host = host, let port = port else { return }
        client = Client(host: host, port: port, useTLS: useTLS)
        client.listModels { (modelInfo) in
            self.saveConnectionSettings()
            self.models = modelInfo
            self.model = modelInfo.first
            DispatchQueue.main.async {
                self.chooseModelButton.isEnabled = true
            }
        } failure: { (error) in
            self.processError(error)
        }
    }
    
    /// Creates a new session for selected model
    fileprivate func createSession(for model: Cobaltspeech_Diatheke_ModelInfo) {
        let dispatchGroup = DispatchGroup()
        if let tokenData = tokenData {
            dispatchGroup.enter()
            client.deleteSession(tokenData).response.whenComplete { (result) in
                self.tokenData = nil
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            self.client.createSession(modelID: model.id) { (sessionOutput) in
                self.processActions(sessionOutput: sessionOutput)
            } failure: { (error) in
                self.processError(error)
            }
        }
    }
    
    /// Displays received error
    fileprivate func processError(_ error: Error) {
        print(error)
        
        if let grpcError = error as? GRPC.GRPCStatus {
            if grpcError.code == .unavailable {
                askToReconnect()
                return
            }
        }
        
        if case NIO.ChannelError.connectTimeout(_) = error {
            askToReconnect()
            return
        }
        
        let message = Message(text: "\(error)", type: .error)
        messages.append(message)
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    /// Saves new session token, displays received action message and performs actions corresponding to received session output actions
    fileprivate func processActions(sessionOutput: Cobaltspeech_Diatheke_SessionOutput) {
        tokenData = sessionOutput.token
        for actionData in sessionOutput.actionList {
            guard let action = actionData.action else {
                continue
            }
            switch action {
            case .command(let commandAction):
                var commandResult = Cobaltspeech_Diatheke_CommandResult()
                commandResult.id = commandAction.id
                self.client.processCommandResult(token: sessionOutput.token, commandResult: commandResult) { (sessionOutput) in
                    self.processActions(sessionOutput: sessionOutput)
                } failure: { (error) in
                    self.processError(error)
                }
            case .input(let waitForUserAction):
                print("Waiting for user action, immediate: \(waitForUserAction.immediate)")
            case .reply(let replyAction):
                let message = Message(text: replyAction.text, type: .reply)
                self.messages.append(message)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                self.audioData = Data()
                
                self.ttsStream = self.client.newTTSStream(replyAction: replyAction, dataChunkHandler: { (ttsAudio) in
                    if !ttsAudio.audio.isEmpty {
                        self.audioData?.append(ttsAudio.audio)
                    }
                }, completion: { (error) in
                    if let error = error {
                        print("TTS error received: \(error)")
                    } else if let audioData = self.audioData {
                        self.playAudio(data: audioData)
                    }
                })
            }
        }
    }
        
    /// Plays TTS audio
    private func playAudio(data: Data) {
        let arFileManager = ARFileManager()
        if let wavFile = try? arFileManager.createWavFile(using: data) {
            player = try? AVAudioPlayer(contentsOf: wavFile)
            guard let player = player else { return }
            player.prepareToPlay()
            player.play()
        }
    }
    
    @objc fileprivate func keyboardWasShown(notification: NSNotification) {
        let info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let guide = view.safeAreaLayoutGuide
        var bottomHeight: CGFloat = 0
        if let owningView = guide.owningView {
            bottomHeight = owningView.frame.height - guide.layoutFrame.origin.y - guide.layoutFrame.size.height
        }
        bottomViewBottomConstraint.constant = keyboardFrame.size.height - bottomHeight
        UIView.animate(withDuration: 0.1, animations: { () -> Void in
            self.view.layoutIfNeeded()
        })
    }
    
    @objc fileprivate func keyboardWasHidden(notification: NSNotification) {
        bottomViewBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.1, animations: { () -> Void in
            self.view.layoutIfNeeded()
        })
    }
    
    // MARK: - Actions
    
    @IBAction func settingsButtonTapped(_ sender: Any) {
        let ac = UIAlertController(title: "Connection settings", message: "Enter server URL", preferredStyle: .alert)
        ac.addTextField { (textField) in
            textField.placeholder = "Host"
            textField.text = self.host
        }
        ac.addTextField { (textField) in
            textField.placeholder = "Port"
            if let port = self.port {
                textField.text = String(port)
            }
        }
        let connectAction = UIAlertAction(title: "Connect", style: .default) { (action) in
            guard let hostTextField = ac.textFields?.first, let portTextField = ac.textFields?.last,
                  let host = hostTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let port = portTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let portInt = Int(port) else {
                return
            }
            
            self.host = host
            self.port = portInt
            self.useTLS = true
            self.reconnect()
        }
        ac.addAction(connectAction)
        let insecureConnectAction = UIAlertAction(title: "Insecure connect", style: .default) { (action) in
            guard let hostTextField = ac.textFields?.first, let portTextField = ac.textFields?.last,
                  let host = hostTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let port = portTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let portInt = Int(port) else {
                return
            }
            
            self.host = host
            self.port = portInt
            self.useTLS = false
            self.reconnect()
        }
        ac.addAction(insecureConnectAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        ac.addAction(cancelAction)
        present(ac, animated: true)
    }
    
    @IBAction func chooseModelButtonTapped(_ sender: Any) {
        guard models.count > 0 else {
            return
        }
        let ac = UIAlertController(title: "Choose Diatheke model", message: nil, preferredStyle: .actionSheet)
        for model in models {
            let action = UIAlertAction(title: model.name, style: .default) { (action) in
                if let index = ac.actions.firstIndex(of: action), index < self.models.count {
                    self.model = self.models[index]
                }
            }
            ac.addAction(action)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        ac.addAction(cancelAction)
        present(ac, animated: true)
    }
    
    @IBAction func recordButtonTapped(_ sender: Any) {
        if isRecording {
            recorder.stopRecording()
            self.asrStream?.result(completion: { (error) in
                if let error = error {
                    print(error)
                }
            })
            isRecording = false
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                if granted {
                    self.startNewRecording()
                } else {
                    print("Record permission denied")
                }
            }
        }
    }
    
    fileprivate func startNewRecording() {
        guard let tokenData = tokenData else { return }
        self.asrStream = client.newSessionASRStream(token: tokenData, asrResultHandler: { (result) in
            switch result {
            case .success(let asrResult):
                guard !asrResult.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let message = Message(text: asrResult.text, type: .user)
                self.messages.append(message)
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                
                self.client.processASRResult(token: self.tokenData!, asrResult: asrResult) { (sessionOutput) in
                    self.processActions(sessionOutput: sessionOutput)
                } failure: { (error) in
                    self.processError(error)
                }
            case .failure(let error):
                print("ASR result error received: \(error)")
            }
        }, completion: { (error) in
            if let error = error {
                print(error)
            } else {
                self.player?.stop()
                try? self.recorder.recordSpeech()
            }
        })
        isRecording = true
    }

}

extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return true
        }
        
        guard let tokenData = tokenData else { return true }
        
        let message = Message(text: text, type: .user)
        messages.append(message)
        
        tableView.reloadData()
        
        client.processText(token: tokenData, text: text) { (sessionOutput) in
            self.processActions(sessionOutput: sessionOutput)
        } failure: { (error) in
            self.processError(error)
        }
        
        textField.text = nil

        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        tableView.setContentOffset(CGPoint(x: 0, y: CGFloat.greatestFiniteMagnitude), animated: true)
    }
}


extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.item]

        
        let cellIdentifier = message.type.rawValue
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        
        if let label = cell.viewWithTag(100) as? UILabel {
            label.text = messages[indexPath.item].text
        }
        
        if let view = cell.viewWithTag(101) {
            view.layer.cornerRadius = 10
            if message.type == .user {
                view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner]
            } else if message.type == .reply {
                view.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
}
