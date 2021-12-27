//
//  EditorController.swift
//  SourceKittenDaemon
//
//  Created by Benedikt Terhechte on 03/12/15.
//  Copyright © 2015 Benedikt Terhechte. All rights reserved.
//

import AppKit

@objc class EditorController: NSViewController {
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var textView: HighlightingTextView!
    @IBOutlet var logView: NSTextView!
    @IBOutlet var waitWindow: NSWindow!
    
    private var completer: Completer?
    private var files: [String] = []
    
    override func awakeFromNib() {
        self.textView.setSyntaxHighlighter(SwiftSyntaxHighligher.self)
        self.textView.autoCompleteDelegate = self
        self.outlineView.delegate = self
        self.outlineView.dataSource = self
        self.logView.string = "Completer Communication Log"
    }
    
    override func viewDidAppear() {
        self.openXcodeProject(self)
    }
    
    @IBAction func saveCurrentFile(_ sender: Any?) {
        let contents = self.textView.string
        guard let file = self.textView.editingFile
            else {
                NSSound.beep()
                print("No editable file, or empty file")
                return
        }
        try? contents.data(using: .utf8)?.write(to: file as URL, options: Data.WritingOptions.atomic)
    }
    
    @IBAction func openXcodeProject(_ sender: Any?) {
        let openDialog = NSOpenPanel()
        openDialog.canChooseFiles = true
        openDialog.canChooseDirectories = false
        openDialog.allowedFileTypes = ["xcodeproj"]
        openDialog.title = "Open Xcode Project"
        openDialog.prompt = "Open Xcode Project"
        
        openDialog.beginSheetModal(for: self.view.window!) { result in
            guard result == .OK else { return }
            guard let url = openDialog.url else { return }
            
            // lock the UI
            self.lockUI()
            
            let creationAction = {
                self.completer = Completer(project: url as NSURL, completion: { (result: Result) -> () in
                    switch result {
                    case .Started:
                        // Read the project files
                        self.readProject()
                        
                        // Unlock the UI
                        self.unlockUI()
                        
                    case .Error(let error):
                        // display the error
                        self.displayError(error)
                    default:()
                    }
                })
                self.completer?.debugDelegate = self
            }
            
            if let currentCompleter = self.completer {
                currentCompleter.stop({ (result) -> () in
                    creationAction()
                })
            } else {
                creationAction()
            }
        }
    }
    
    private func readProject() {
        guard let completer = self.completer
            else { return }
        completer.projectFiles { (result) -> () in
            switch result {
            case Result.Error(let error):
                self.displayError(error)
            case Result.Files(let files):
                self.files = files
                self.outlineView.reloadData()
            default: ()
            }
        }
    }
    
    func displayError(_ error: Swift.Error) {
        guard let error = error as? CompletionError else { return }
        switch error {
        case .Error(message: let msg):
            let alert = NSAlert()
            alert.messageText = msg
            alert.runModal()
        }
    }
    
    func terminate() {
        self.completer?.stop({ (result) -> () in
        })
    }
    
    private func lockUI() {
        self.view.window?.beginSheet(self.waitWindow, completionHandler: nil)
    }
    
    private func unlockUI() {
        self.view.window?.endSheet(self.waitWindow)
    }
    
    private func loadFile(_ filePath: String) {
        let url = NSURL(fileURLWithPath: filePath)
        self.textView.editingFile = url
        
        // read the file and set the contents
        do {
            let contents = try String(contentsOfFile: filePath)
            self.textView.string = contents
        } catch let error {
            self.displayError(CompletionError.Error(message: "\(error)"))
        }
    }
}

extension EditorController: CompleterDebugDelegate {
    func startedCompleter(_ command: String) {
        let currentString = self.logView.string
        self.logView.string = "Started: \(command)\n--------\n\(currentString)"
    }
    
    func calledURL(_ url: NSURL, withHeaders headers: [String: String]) {
        let currentString = self.logView.string
        self.logView.string = "Get: \(url)\nHeaders: \(headers)\n--------\n\(currentString)"
    }
}

extension EditorController: AutoCompleteDelegate {
    func calculateCompletions(_ file: NSURL, content: String, offset: Int, completion: @escaping ([String]?) -> ()) {
        // write into temporaryfile
        let temporaryFileName = NSTemporaryDirectory() + "/" + ProcessInfo.processInfo.globallyUniqueString + ".swift"
        
        FileManager.default.createFile(atPath: temporaryFileName, contents: content.data(using: .utf8) , attributes: [:])
        
        self.completer?.calculateCompletions(NSURL(fileURLWithPath: temporaryFileName), offset: offset + 1,
            completion: { (result) -> () in
            switch result {
            case Result.Error(let error):
                self.displayError(error)
            case Result.Completions(let completions):
                completion(completions)
            default: ()
            }
        })
    }
}

extension EditorController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        // root = nil
        if item == nil {
            return self.files.count
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return self.files[index]
        }
        // should never end here
        fatalError("No children for files")
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if item == nil {
            return "Files"
        }
        guard let name = item as? String,
            let lastItem = (name as NSString).pathComponents.last
            else { return nil }
        return lastItem
    }
}

extension EditorController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        // open the file
        guard let filePath = item as? String
            else { return false }
        self.loadFile(filePath)
        return true
    }
}
