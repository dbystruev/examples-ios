//
//  ModelDownloader.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 10.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import Foundation
import Zip

public protocol ModelDownloaderDelegate: AnyObject {
    
    func modelDownloader(_ downloader: ModelDownloader, didChangeStatus status: ModelDownloaderStatus, withProgress progress: Float)
    func modelDownloader(_ downloader: ModelDownloader, didFinishDownloadingToPath path: String)
    func modelDownloader(_ downloader: ModelDownloader, didUnzipToPath path: String)
    func modelDownloader(_ downloader: ModelDownloader, didCompleteWithError error: Error?, resumeData: Data?)
    func modelDownloader(_ downloader: ModelDownloader, didCancelLoadingWithResumeData resumeData: Data?)
    
}

public enum ModelDownloaderStatus {
    case downloading, unzipping
}

public class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    
    public weak var delegate: ModelDownloaderDelegate?
    
    private var task: URLSessionDownloadTask?
    public private(set) var productType: ServerProductType
    private var modelsRootPath: URL
    
    public init(productType: ServerProductType, modelsRootPath: URL) {
        self.productType = productType
        self.modelsRootPath = modelsRootPath
    }
    
    func unzipWithProgress(zipUrl: URL) {
        DispatchQueue.global().async {
            let destinationURL = zipUrl.deletingPathExtension()
            do {
                try FileManager.default.createDirectory(at: destinationURL,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
                try Zip.unzipFile(zipUrl, destination: destinationURL, overwrite: true, password: nil, progress: { (progress) in
                    if progress == 1 {
                        let fileName = zipUrl.lastPathComponent.replacingOccurrences(of: ".zip", with: "")
                        DispatchQueue.main.async {
                            self.delegate?.modelDownloader(self, didUnzipToPath: fileName)
                        }
                    }
                }, fileOutputHandler: nil)
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    func download(id: String, url: URL, resume: Data? = nil) -> URLSessionDownloadTask {
        let urlSession = URLSession(configuration: .default,
                                    delegate: self,
                                    delegateQueue: nil)

        let task = resume != nil ? urlSession.downloadTask(withResumeData: resume!) : urlSession.downloadTask(with: url)
        
        self.task = task
        task.resume()
        return task
    }
    
    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let pr =  Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        self.delegate?.modelDownloader(self, didChangeStatus: .downloading, withProgress: pr)
    }
    
    public func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        if !FileManager.default.directoryExists(path: modelsRootPath.path) {
            do {
                try FileManager.default.createDirectory(at: modelsRootPath, withIntermediateDirectories: true)
            } catch {
                self.delegate?.modelDownloader(self, didCompleteWithError: error, resumeData: nil)
            }
        }

        let zipFilename = UUID().uuidString + ".zip"
        let movedZipPath = modelsRootPath.appendingPathComponent(zipFilename)
        do {
            try FileManager.default.moveItem(at: location, to: movedZipPath)
            self.delegate?.modelDownloader(self, didFinishDownloadingToPath: movedZipPath.path)
        } catch {
            print(error)
        }
        
        unzipWithProgress(zipUrl: movedZipPath)
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        self.delegate?.modelDownloader(self, didCompleteWithError: error, resumeData: nil)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, let _ = task.response {
            let userInfo = (error as NSError).userInfo
            let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            DispatchQueue.main.async {
                self.delegate?.modelDownloader(self, didCompleteWithError: error, resumeData: resumeData)
            }
        } else {
            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.modelDownloader(self, didCompleteWithError: error, resumeData: nil)
                }
            }
        }
    }

    func pauseDownload() {
        self.task?.suspend()
    }
    
    func continueDownload() {
        self.task?.resume()
    }
    
    func cancelDownload() {
        self.task?.cancel(byProducingResumeData: { data in
            self.delegate?.modelDownloader(self, didCancelLoadingWithResumeData: data)
        })
    }
    
}
