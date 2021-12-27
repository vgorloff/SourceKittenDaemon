//
//  Completer.swift
//  SourceKittenDaemon
//
//  Created by Benedikt Terhechte on 05/12/15.
//  Copyright © 2015 Benedikt Terhechte. All rights reserved.
//

import AppKit

enum CompletionError: Swift.Error {
    case Error(message: String)
}

enum Result {
    case Started
    case Stopped
    case Files([String])
    case Completions([String])
    case Error(Swift.Error)
}

typealias Completion = (Result) -> ()

protocol CompleterDebugDelegate {
    func calledURL(_ url: NSURL, withHeaders headers: [String: String])
    func startedCompleter(_ command: String)
}

/**
 This class takes care of all the completer / sourcekittendaemon handling. It:
 - Searches the sourcekittendaemon binary in the SwiftCode binary
 - Starts an `NSTask` with the binary
 - Does the network requests against the sourcekittendaemon
 - Converts the results to the proper types
 - And offers rudimentary error handling via the `Result` type
 
 This can be considered the main component for connecting to the SourceKittenDaemon
 completion engine.
 */
class Completer {
    
    let port = "44876"
    
    let projectURL: NSURL
    let task: Process
    
    var debugDelegate: CompleterDebugDelegate? = nil
    
    /**
     Create a new Completer for an Xcode project
     - parameter project: The Xcode project to load
     - parameter finished: This will be called once the task is running and the server is started up
     */
    init(project: NSURL, completion: @escaping Completion) {
        self.projectURL = project
        
        /// Find the SourceKittenDaemon Binary in our bundle
        let bundle = Bundle.main
        guard let supportPath = bundle.sharedSupportPath
        else { fatalError("Could not find Support Path") }
        
        let daemonBinary = (supportPath as NSString).appendingPathComponent("sourcekittend")
        guard FileManager.default.fileExists(atPath: daemonBinary)
        else { fatalError("Could not find SourceKittenDaemon") }
        
        /// Start up the SourceKittenDaemon
        self.task = Process()
        self.task.launchPath = daemonBinary
        self.task.arguments = ["start", "--port", self.port, "--project", project.path!]
        
        /// Create an output pipe to read the sourcekittendaemon output
        let outputPipe = Pipe()
        self.task.standardOutput = outputPipe.fileHandleForWriting

        /// Wait until the server started up properly
        /// Read the server output to figure out if startup succeeded.
        var started = false
        DispatchQueue.global(qos: .userInteractive).async {
            var content: String = ""
            while true {
                
                let data = outputPipe.fileHandleForReading.readData(ofLength: 1)
                
                guard let dataString = String(data: data, encoding: .utf8)
                else { continue }
                content += dataString
                
                if content.range(of: "\\[INFO\\] Monitoring", options: .regularExpression) != nil &&
                    !started {
                    started = true
                    DispatchQueue.main.async {
                        self.debugDelegate?.startedCompleter(([daemonBinary] + self.task.arguments!).joined(separator: " "))
                        completion(Result.Started)
                    }
                }
                
                if content.range(of: "\\[ERR\\]", options: .regularExpression) != nil {
                    DispatchQueue.main.async {
                        completion(Result.Error(CompletionError.Error(message: "Failed to start the Daemon")))
                    }
                    return
                }
            }
        }
        
        self.task.launch()
    }
    
    /**
     Stop the completion server, kill the task. This will be performed when a new
     Xcode project is loaded */
    func stop(_ completed: @escaping Completion) {
        self.dataFromDaemon("/stop", headers: [:]) { (data) -> () in
            self.task.terminate()
            completed(Result.Stopped)
        }
    }
    
    /**
     Return all project files in the Xcode project
     */
    func projectFiles(completion: @escaping Completion) {
        self.dataFromDaemon("/files", headers: [:]) { (data) -> () in
            do {
                let files = try data() as? [String]
                completion(Result.Files(files!))
            } catch let error {
                completion(Result.Error(error))
            }
        }
    }
    
    /**
     Get the completions for the given file at the given offset
     - parameter temporaryFile: A temporary file containing the content to be completed upon
     - parameter offset: The cursor / byte position in the file for which we need completions
     */
    func calculateCompletions(_ temporaryFile: NSURL, offset: Int, completion: @escaping Completion) {
        // Create the arguments
        guard let temporaryFilePath = temporaryFile.path
        else {
            completion(Result.Error(CompletionError.Error(message: "No file path")))
            return
        }
        let attributes = ["X-Path": temporaryFilePath, "X-Offset": "\(offset)"]
        self.dataFromDaemon("/complete", headers: attributes) { (data) -> () in
            do {
                guard let completions = try data() as? [NSDictionary] else {
                    completion(Result.Error(CompletionError.Error(message: "Wrong Completion Return Type")))
                    return
                }
                var results = [String]()
                for c in completions {
                    guard let s = (c["name"] as? String) else { continue }
                    results.append(s)
                }
                completion(Result.Completions(results))
            } catch let error {
                completion(Result.Error(error))
            }
        }
    }
    
    /**
     This is the work horse that makes sure we're receiving valid data from the completer.
     It does not use the Result type as that would include too much knowledge into this function
     (i.e. do we have a files or a completion request). Instead it uses the throwing closure
     concept as explained here: http://appventure.me/2015/06/19/swift-try-catch-asynchronous-closures/
     */
    private func dataFromDaemon(_ path: String, headers: [String: String], completion: @escaping (() throws -> Any) -> () ) {
        guard let url = NSURL(string: "http://localhost:\(self.port)\(path)")
        else {
            completion({ throw CompletionError.Error(message: "Could not create completer URL") })
            return
        }
        
        self.debugDelegate?.calledURL(url, withHeaders: headers)
        
        let session = URLSession.shared
        
        let mutableRequest = NSMutableURLRequest(url: url as URL)
        headers.forEach { (h) -> () in
            mutableRequest.setValue(h.1, forHTTPHeaderField: h.0)
        }
        
        let task = session.dataTask(with: mutableRequest as URLRequest) { (data, response, error) -> Void in
            if let error = error {
                DispatchQueue.main.async {
                    completion({ throw CompletionError.Error(message: "error: \(error)") })
                }
                return
            }
            
            guard let data = data, let parsedData = try? JSONSerialization.jsonObject(with: data, options: [])
            else {
                DispatchQueue.main.async {
                    completion({ throw CompletionError.Error(message: "Invalid Json") })
                }
                return
            }
            
            // Detect errors
            if let parsedDict = parsedData as? [String: AnyObject], let jsonError = parsedDict["error"], parsedDict.count == 1 {
                DispatchQueue.main.async {
                    completion({ throw CompletionError.Error(message: "Error: \(jsonError)") })
                }
                return
            }
            
            DispatchQueue.main.async {
                completion({ return parsedData })
            }
        }

        task.resume()
    }
}
