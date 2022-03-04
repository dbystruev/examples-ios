//
//  ViewController.swift
//  DiathekeEmbeddedDemo
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
import CubicsvrConfig
import DiathekesvrConfig
import Cobaltmobile
import NIOSSL
import LunasvrConfig


class ViewController: UIViewController {
    
    fileprivate let LOCALHOST = "127.0.0.1"
    fileprivate let CUBICSVR_PORT = 9000
    fileprivate let DIATHEKESVR_PORT = 8181
    fileprivate let LUNASVR_PORT = 9001
    
    fileprivate var cobaltMobile: CobaltmobileCobaltFactoryProtocol?
    fileprivate var cubicServer: CobaltmobileServerProtocol?
    fileprivate var diathekeServer: CobaltmobileServerProtocol?
    
    // MARK: - UserDefaults
    
    fileprivate let UD_DIATHEKE_CONFIG_KEY = "diathekesvr_config"
    fileprivate let UD_CUBIC_CONFIG_KEY = "cubicsvr_config"
    fileprivate let UD_LUNA_CONFIG_KEY = "lunasvr_config"
    
    // MARK: - Outlets
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var licenseButton: UIBarButtonItem!
    @IBOutlet weak var chooseModelButton: UIBarButtonItem!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var recordDurationLabel: UILabel!

    // MARK: - Private properties
    
    fileprivate var lunaServerIsRunning = false
    
    fileprivate var diathekeServerConfig: DiathekesvrConfig!
    fileprivate var cubicServerConfig: CubicsvrConfig!
    fileprivate var lunaServerConfig: LunasvrConfig!
    
    fileprivate var client: Diatheke.Client!                    // Diatheke Client
    
    fileprivate var player: AVAudioPlayer?                      // Audio player for TTS
    fileprivate var recorder = Recorder()                       // Audio recorder for ASR
    
    fileprivate var messages: [Message] = []                    // Messages TableView Data Source
    
    fileprivate var tokenData: Cobaltspeech_Diatheke_TokenData? // Current Session Token
    
    fileprivate var audioData: Data?                            // TTS audio data/
    fileprivate var asrStream: ASRStream?
    fileprivate var ttsStream: TTSStream?
    fileprivate var transcribeStream: TranscribeStream?
    
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
                    self.title = "Local Demo - \(model.name)"
                }
                self.recorder.modelSampleRate = model.asrSampleRate
                self.createSession(for: model)
            } else {
                DispatchQueue.main.async {
                    self.recordButton.isEnabled = false
                    self.textField.isEnabled = false
                    self.title = "Local Demo"
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
    
    fileprivate func createOrRestoreLunaServerConfig() {
        if let configStr = UserDefaults.standard.string(forKey: UD_LUNA_CONFIG_KEY) {
            self.lunaServerConfig = LunasvrConfig(tomlString: configStr)
        }
        
        if self.lunaServerConfig == nil {
            self.lunaServerConfig = LunasvrConfig()
        }
    }
    
    fileprivate func createOrRestoreDiathekeServerConfig() {
        if let configStr = UserDefaults.standard.string(forKey: UD_DIATHEKE_CONFIG_KEY) {
            self.diathekeServerConfig = DiathekesvrConfig(tomlString: configStr)
        }
        
        if self.diathekeServerConfig == nil {
            self.diathekeServerConfig = DiathekesvrConfig()
        }
    }
    
    fileprivate func createOrRestoreCubicServerConfig() {
        if let configStr = UserDefaults.standard.string(forKey: UD_CUBIC_CONFIG_KEY) {
            self.cubicServerConfig = CubicsvrConfig(tomlString: configStr)
        }
        
        if self.cubicServerConfig == nil {
            self.cubicServerConfig = CubicsvrConfig()
        }
    }
    
    fileprivate func restartServers() {
        createOrRestoreLunaServerConfig()
        
        if let lunaServerConfigURL = saveLunaServerConfig() {
            if let lunaServetConfigTOML = try? String(contentsOfFile: lunaServerConfigURL.path) {
                print(lunaServetConfigTOML)
            }
            if lunaServerConfig.models.count > 0 && !lunaServerIsRunning {
                DispatchQueue.global().async {
                    self.lunaServerIsRunning = true
                    LunaWrapper().startServer(lunaServerConfigURL.path)
                }
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(8)) {
            self.restartDiathekeServer()
        }
    }
    
    fileprivate func restartDiathekeServer() {
        // stop all running servers
        
        if diathekeServer != nil {
            diathekeServer?.stop()
            diathekeServer = nil
        }
        
        if cubicServer != nil {
            cubicServer?.stop()
            cubicServer = nil
        }

        // restore the latest Cubic server config file from UserDefaults or create a new one
        createOrRestoreCubicServerConfig()
        
        // set GRPC address for Cubic server
        cubicServerConfig.server.grpc.Address = ":\(CUBICSVR_PORT)"

        // save the updated config as TOML file
        if let cubicServerConfigURL = saveCubicServerConfig() {
            if let cubicServerConfigTOML = try? String(contentsOfFile: cubicServerConfigURL.path) {
                print(cubicServerConfigTOML)
            }
            
            // create Cubic server
            do {
                cubicServer = try cobaltMobile?.cubic(cubicServerConfigURL.path)
            } catch {
                print(error)
            }
            
            // start Cubic server
            cubicServer?.start()
        }
        
        // restore the latest Diatheke server config file from UserDefaults or create a new one
        createOrRestoreDiathekeServerConfig()
        
        // set GRPC address for Diatheke server
        diathekeServerConfig.server.grpc.Address = ":\(DIATHEKESVR_PORT)"
        // set Cubic server endpoint for Diatheke server
        diathekeServerConfig.services.cubic.Address = "\(LOCALHOST):\(CUBICSVR_PORT)"
        // all servers run on the same device so connection between them should be insecure
        diathekeServerConfig.services.cubic.Insecure = true
        // enable Cubic server for Diatheke
        if cubicServerConfig.models.count > 0 {
            diathekeServerConfig.services.cubic.Enabled = true
        }
        
        diathekeServerConfig.services.luna.Insecure = true
        diathekeServerConfig.services.luna.Address = "127.0.0.1:9001"
        
        if lunaServerConfig.models.count > 0 {
            diathekeServerConfig.services.luna.Enabled = true
        }

        // save the updatd config as TOML file
        if let diathekeServerConfigURL = saveDiathekeServerConfig() {
            if let diathekeServerConfigTOML = try? String(contentsOfFile: diathekeServerConfigURL.path) {
                print(diathekeServerConfigTOML)
            }
            
            if diathekeServerConfig.models.count > 0 {
                // create Diatheke server
                do {
                    diathekeServer = try cobaltMobile?.diatheke(diathekeServerConfigURL.path)
                } catch {
                    print(error)
                }
                
                // start Diatheke server
                diathekeServer?.start()
              
                // connect Client to Diatheke server
                connect()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cobaltMobile = CobaltmobileNew()
        
        restartServers()
        
        recorder.sendAudioChunkBlock = { data in
            self.asrStream?.sendAudio(data: data, completion: { (error) in
                if let error = error {
                    print(error)
                }
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let modelsViewController = segue.destination as? ModelsViewController else {
            return
        }
        
        modelsViewController.delegate = self
        
        if segue.identifier == "DiathekeModelsSegue" {
            modelsViewController.productType = .diatheke
        } else if segue.identifier == "CubicModelsSegue" {
            modelsViewController.productType = .cubic
        } else if segue.identifier == "LunaModelsSegue" {
            modelsViewController.productType = .luna
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
        client = Diatheke.Client(host: "127.0.0.1", port: 8181, useTLS: false)

        client.listModels { (modelInfo) in
            self.models = modelInfo
            
            if let selectedModel = ModelsDownloadQueueManager.shared.diathekeModels.first(where: { model in
                return model.status == .ready && model.selected
            }) {
                if let diathekeModel = modelInfo.first(where: { diathekeModelInfo in
                    return diathekeModelInfo.id == selectedModel.id
                }) {
                    self.model = diathekeModel
                    return
                }
            }
            
            self.model = modelInfo.first
        } failure: { (error) in
            self.client = nil
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
               // askToReconnect()
                return
            }
        }
        
        if case NIO.ChannelError.connectTimeout(_) = error {
            //askToReconnect()
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
            case .reply(var replyAction):
                let message = Message(text: replyAction.text, type: .reply)
                self.messages.append(message)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                self.audioData = Data()
            
                replyAction.lunaModel = ""
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
            case .transcribe(let transcribeAction):
                self.transcribeStream = self.client.newTranscribeStream(action: transcribeAction, transcribeResultHandler: { transcribeResult in
                    guard !transcribeResult.isPartial else {
                        return
                    }
                    
                    let message = Message(text: transcribeResult.text, type: .transcribeResult)
                    self.messages.append(message)
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }, completion: { error in
                    if let error = error {
                        print("Transcribe error received: \(error)")
                    }
                })
            }
        }
    }
   
    /// Plays TTS audio
    private func playAudio(data: Data) {
        let arFileManager = AudioRecordingFileManager()
        if let wavFile = try? arFileManager.createWavFile(using: data) {
            player = try? AVAudioPlayer(contentsOf: wavFile)
            guard let player = player else { return }
            player.prepareToPlay()
            player.play()
        }
    }

    // MARK: - Actions
    
    @discardableResult
    private func saveDiathekeServerConfig() -> URL? {
        let configPath = FileManager.default.diathekeDirectoryURL.appendingPathComponent(Constants.DIATHEKESVR_CONFIG_FILE_DEFAULT_NAME)
        
        if let configStr = diathekeServerConfig.save(configPath) {
            print("Diatheke config saved")
            print(configStr)
            UserDefaults.standard.set(configStr, forKey: UD_DIATHEKE_CONFIG_KEY)
            return configPath
        } else {
            return nil
        }
    }
    
    @discardableResult
    private func saveCubicServerConfig() -> URL? {
        let configPath = FileManager.default.cubicDirectoryURL.appendingPathComponent(Constants.CUBICSVR_CONFIG_FILE_DEFAULT_NAME)
        
        if let configStr = cubicServerConfig.save(configPath) {
            print("Cubic config saved")
            print(configStr)
            UserDefaults.standard.set(configStr, forKey: UD_CUBIC_CONFIG_KEY)
            return configPath
        } else {
            return nil
        }
    }
    
    @discardableResult
    private func saveLunaServerConfig() -> URL? {
        let configPath = FileManager.default.lunaDirectoryURL.appendingPathComponent(Constants.LUNASVR_CONFIG_FILE_DEFAULT_NAME)
        
        lunaServerConfig.server.grpc.Address = "127.0.0.1:9001"
        
        for i in 0..<lunaServerConfig.models.count {
            let path = lunaServerConfig.models[i].Path
            if let range = path.range(of: "models") {
                let subpath = path[range.lowerBound..<path.endIndex]
                lunaServerConfig.models[i].Path = FileManager.default.lunaDirectoryURL.appendingPathComponent(String(subpath)).path
            }
        }
        
        if let configStr = lunaServerConfig.save(configPath) {
            print("Luna config saved")
            print(configStr)
            UserDefaults.standard.set(configStr, forKey: UD_LUNA_CONFIG_KEY)
            return configPath
        } else {
            return nil
        }
    }
    
    private func downloadCubicLicense(from url: URL) {
        let urlRequest = URLRequest(url: url)
        let _ = URLSession(configuration: .default).downloadTask(with: urlRequest) { url, response, error in
            if let error = error {
                print(error)
                return
            }
            
            guard let url = url else {
                return
            }
            
            let licenseFileURL = FileManager.default.cubicLicenseDirectoryURL.appendingPathComponent(Constants.CUBICSVR_LICENSE_FILE_DEFAULT_NAME)
            do {
                if FileManager.default.fileExists(atPath: licenseFileURL.path) {
                    try FileManager.default.removeItem(at: licenseFileURL)
                }
                
                try FileManager.default.moveItem(at: url, to: licenseFileURL)
                
                self.cubicServerConfig.license.KeyFile = "\(Constants.LICENSES_DIRECTORY)/\(Constants.CUBICSVR_LICENSE_FILE_DEFAULT_NAME)"
                self.saveCubicServerConfig()
            } catch {
                print(error)
            }
        }.resume()
    }
    
    private func downloadDiathekeLicense(from url: URL) {
        let urlRequest = URLRequest(url: url)
        let _ = URLSession(configuration: .default).downloadTask(with: urlRequest) { url, response, error in
            if let error = error {
                print(error)
                return
            }
            
            guard let url = url else {
                return
            }

            let licenseFileURL =  FileManager.default.diathekeLicenseDirectoryURL.appendingPathComponent(Constants.DIATHEKESVR_LICENSE_FILE_DEFAULT_NAME)
    
            do {
                if FileManager.default.fileExists(atPath: licenseFileURL.path) {
                    try FileManager.default.removeItem(at: licenseFileURL)
                }
                try FileManager.default.moveItem(at: url, to: licenseFileURL)
                
                self.diathekeServerConfig.license.KeyFile = "\(Constants.LICENSES_DIRECTORY)/\(Constants.DIATHEKESVR_LICENSE_FILE_DEFAULT_NAME)"
                self.saveDiathekeServerConfig()
            } catch let e {
                print(e)
            }
        }.resume()
    }
    
    fileprivate func showLicenseDialog(product: ServerProductType) {
        let ac = UIAlertController(title: "Download License", message: nil, preferredStyle: .alert)
        ac.addTextField { textField in
            textField.placeholder = "Paste license file URL here"
        }
        
        let downloadAction = UIAlertAction(title: "Download", style: .default) { action in
            guard let urlString = ac.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            guard let url = URL(string: urlString) else { return }
            switch product {
            case .cubic:
                self.downloadCubicLicense(from: url)
            case .diatheke:
                self.downloadDiathekeLicense(from: url)
            case .luna:
                break
            }
        }
        
        ac.addAction(downloadAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        ac.addAction(cancelAction)
        
        present(ac, animated: true, completion: nil)
    }
    
    @IBAction func licenseButtonTapped(_ sender: Any) {
        let ac = UIAlertController(title: "Download license for:", message: nil, preferredStyle: .actionSheet)
        
        let diathekeAction = UIAlertAction(title: "Diatheke", style: .default) { action in
            DispatchQueue.main.async {
                self.showLicenseDialog(product: .diatheke)
            }
        }
        
        let cubicAction = UIAlertAction(title: "Cubic", style: .default) { action in
            DispatchQueue.main.async {
                self.showLicenseDialog(product: .cubic)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        ac.addAction(cubicAction)
        ac.addAction(diathekeAction)
        ac.addAction(cancelAction)
        
        present(ac, animated: true)
    }
    
    
    @IBAction func chooseModelButtonTapped(_ sender: Any) {
        let ac = UIAlertController(title: "Choose a product you want to manage models for", message: nil, preferredStyle: .actionSheet)
        
        let diathekeAction = UIAlertAction(title: "Diatheke", style: .default) { action in
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "DiathekeModelsSegue", sender: self)
            }
        }
        
        let cubicAction = UIAlertAction(title: "Cubic", style: .default) { action in
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "CubicModelsSegue", sender: self)
            }
        }
        
        let lunaAction = UIAlertAction(title: "Luna", style: .default) { action in
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "LunaModelsSegue", sender: self)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        ac.addAction(lunaAction)
        ac.addAction(cubicAction)
        ac.addAction(diathekeAction)
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

extension ViewController: ModelsViewControllerDelegate {
    
    func modelsViewControllerDidUpdateModels(_ models: [LocalModel]) {
        restartServers()
    }
    
    func modelsViewControllerDidSelectModel(_ model: LocalModel?) {
    
    }
    
    func modelsViewControllerDidRemoveModel(with id: String, for product: String) {
        guard let productType = ServerProductType(rawValue: product) else {
            return
        }
        
        switch productType {
        case .cubic:
            cubicServerConfig.removeModel(id: id)
            saveCubicServerConfig()
        case .diatheke:
            diathekeServerConfig.removeModel(id: id)
            saveDiathekeServerConfig()
        case .luna:
            lunaServerConfig.removeModel(id: id)
            saveLunaServerConfig()
        }
    }
    
    func modelsViewControllerDidAddModel(_ model: LocalModel) {
        guard let productType = ServerProductType(rawValue: model.productType) else {
            return
        }
        
        guard let path = model.path else { return }
        
        switch productType {
        case .cubic:
            cubicServerConfig.addModel(id: model.id,
                                       name: model.name,
                                       path: Constants.MODELS_DIRECTORY + "/" + path)
            
            saveCubicServerConfig()
        case .luna:
            lunaServerConfig.addModel(id: model.id, name: model.name, path: Constants.MODELS_DIRECTORY + "/" + path)
            saveLunaServerConfig()
        case .diatheke:
            let cubicModels = ModelsDownloadQueueManager.shared.cubicModels.filter({ model in
                return model.status == .ready
            })
            
            let lunaModelID = ModelsDownloadQueueManager.shared.lunaModels.filter { model in
                return model.status == .ready
            }.first?.id
            
            if cubicModels.isEmpty {
                addDiathekeModelToConfig(model: model, cubicModelID: nil, lunaModelID: lunaModelID)
                return
            }
            
            let ac = UIAlertController(title: nil,
                                       message: "Do you want to set up Cubic model for the downloaded Diatheke model?",
                                       preferredStyle: .actionSheet)
            for cubicModel in cubicModels {
                let action = UIAlertAction(title: cubicModel.name, style: .default) { action in
                    self.addDiathekeModelToConfig(model: model, cubicModelID: cubicModel.id, lunaModelID: lunaModelID)
                }
                
                ac.addAction(action)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
                self.addDiathekeModelToConfig(model: model, cubicModelID: nil, lunaModelID: lunaModelID)
            }
            
            ac.addAction(cancelAction)
            
            let topMostVC = UIApplication.shared.topViewController() ?? self
            
            DispatchQueue.main.async {
                topMostVC.present(ac, animated: true, completion: nil)
            }
        }
    }
    
    fileprivate func addDiathekeModelToConfig(model: LocalModel, cubicModelID: String?, lunaModelID: String?) {
        guard let path = model.path else { return }
        
        self.diathekeServerConfig.addModel(id: model.id,
                                      name: model.name,
                                      path: Constants.MODELS_DIRECTORY + "/" + path,
                                      language: "en_US",
                                      cubicModelID: cubicModelID,
                                      lunaModelID: lunaModelID,
                                      transcibeModelID: nil)
        self.saveDiathekeServerConfig()
        
        restartServers()
    }
    
}
