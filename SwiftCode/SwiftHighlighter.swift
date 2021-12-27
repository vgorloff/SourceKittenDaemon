//
//  GroovySyntaxHighligher.swift
//  SwiftEdit
//
//  Created by Scott Horn on 18/06/2014.
//  Copyright (c) 2014 Scott Horn. All rights reserved.
//

import Cocoa

let SWIFT_ELEMENT_TYPE_KEY = NSAttributedString.Key("swiftElementType")

class SyntaxHighligher: NSObject, NSTextStorageDelegate, NSLayoutManagerDelegate {
    var textStorage : NSTextStorage?
    let swiftStyles = [
        "COMMENT": NSColor.gray,
        "QUOTES": NSColor.magenta,
        "SINGLES_QUOTES": NSColor.green,
        "SLASHY_QUOTES": NSColor.orange,
        "DIGIT": NSColor.red,
        "OPERATION": NSColor.purple,
        "RESERVED_WORDS": NSColor.blue
    ]
    
    func reservedWords() -> [String] {
        return []
    }
    
    func reservedMatchers() -> [String] {
        return []
    }
    
    func completionChars() -> [Character] {
        return []
    }
    
    var matchers: [String] = []
    var regex : NSRegularExpression?
    var textView : NSTextView?
    var scrollView: NSScrollView?
    
    override init() {
        super.init()
        let reserved = self.reservedWords().joined(separator: "|")
        self.matchers = self.reservedMatchers() + ["RESERVED_WORDS", reserved]
        
        var regExItems: [String] = []
        for (idx, item) in matchers.enumerated() {
            if idx % 2 == 1 {
                regExItems.append(item)
            }
        }
        let regExString = "(" + regExItems.joined(separator: ")|(") + ")"
        do {
            try regex = NSRegularExpression(pattern: regExString, options: [])
        } catch _ {
            regex = nil
        }
    }
    
    convenience required init(textStorage: NSTextStorage, textView: NSTextView, scrollView: NSScrollView) {
        self.init()
        self.textStorage = textStorage
        self.scrollView = scrollView
        self.textView = textView
        
        textStorage.delegate = self
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self,
            selector: "textStorageDidProcessEditing:",
                                               name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)
        parse(nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func visibleRange() -> NSRange {
        let container = textView!.textContainer!
        let layoutManager = textView!.layoutManager!
        let textVisibleRect = scrollView!.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: textVisibleRect,
                                                  in: container)
        return layoutManager.characterRange(forGlyphRange: glyphRange,
            actualGlyphRange: nil)
    }
    
    func parse(_ sender: AnyObject?) {
        let range = visibleRange()
        let string = textStorage!.string
        let layoutManagerList = textStorage!.layoutManagers as [NSLayoutManager]
        for layoutManager in layoutManagerList {
            layoutManager.delegate = self
            layoutManager.removeTemporaryAttribute(SWIFT_ELEMENT_TYPE_KEY,
                forCharacterRange: range)
        }
        guard let r = regex else {return}
        
        r.enumerateMatches(in: string, options: [], range: range) { (match, flags, stop) -> Void in
            for matchIndex in 1 ..< match!.numberOfRanges {
                let matchRange = match!.range(at: matchIndex)
                if matchRange.location == NSNotFound {
                    continue
                }
                for layoutManager in layoutManagerList {
                    layoutManager.addTemporaryAttributes([SWIFT_ELEMENT_TYPE_KEY: self.matchers[(matchIndex - 1) * 2]],
                        forCharacterRange: matchRange)
                }
            }
        }
    }
    
    override func textStorageDidProcessEditing(_ aNotification: Notification) {
        DispatchQueue.main.async {
            self.parse(self)
        }
    }
    
    func layoutManager(_ layoutManager: NSLayoutManager, shouldUseTemporaryAttributes attrs: [NSAttributedString.Key : Any], forDrawingToScreen toScreen: Bool, atCharacterIndex charIndex: Int, effectiveRange effectiveCharRange: NSRangePointer?) -> [NSAttributedString.Key : Any]? {
        if toScreen {
            if let type = attrs[SWIFT_ELEMENT_TYPE_KEY] as? String {
                if let style = swiftStyles[type] {
                    return [.foregroundColor: style]
                }
            }
        }
        return attrs
    }

}

class SwiftSyntaxHighligher: SyntaxHighligher {
    
    override func completionChars() -> [Character] {
        // return the only char for which we offer completion right now
        return [Character.init(".")]
    }
    
    override func reservedMatchers() -> [String] {
        return [ "COMMENT", "/\\*(?s:.)*?(?:\\*/|\\z)",
            "COMMENT", "//.*",
            "QUOTES",  "(?ms:\"{3}(?!\\\"{1,3}).*?(?:\"{3}|\\z))|(?:\"{1}(?!\\\").*?(?:\"|\\Z))",
            "SINGLE_QUOTES", "(?ms:'{3}(?!'{1,3}).*?(?:'{3}|\\z))|(?:'[^'].*?(?:'|\\z))",
            "DIGIT", "(?<=\\b)(?:0x)?\\d+[efld]?",
            "OPERATION", "[\\w\\$&&[\\D]][\\w\\$]* *\\("]
    }
    
    override func reservedWords() -> [String] {
        return ["(?:\\bclass\\b)", "(?:\\bdeinit\\b)", "(?:\\benum\\b)", "(?:\\bextension\\b)", "(?:\\bfunc\\b)", "(?:\\bimport\\b)", "(?:\\binit\\b)", "(?:\\binternal\\b)", "(?:\\blet\\b)", "(?:\\boperator\\b)", "(?:\\bprivate\\b)", "(?:\\bprotocol\\b)", "(?:\\bpublic\\b)", "(?:\\bstatic\\b)", "(?:\\bstruct\\b)", "(?:\\bsubscript\\b)", "(?:\\btypealias\\b)", "(?:\\bvar\\b)", "(?:\\bbreak\\b)", "(?:\\bcase\\b)", "(?:\\bcontinue\\b)", "(?:\\bdefault\\b)", "(?:\\bdo\\b)", "(?:\\belse\\b)", "(?:\\bfallthrough\\b)", "(?:\\bfor\\b)", "(?:\\bif\\b)", "(?:\\bin\\b)", "(?:\\breturn\\b)", "(?:\\bswitch\\b)", "(?:\\bwhere\\b)", "(?:\\bwhile\\b)", "(?:\\bas\\b)", "(?:\\bdynamicType\\b)", "(?:\\bfalse\\b)", "(?:\\bis\\b)", "(?:\\bnil\\b)", "(?:\\bself\\b)", "(?:\\bSelf\\b)", "(?:\\bsuper\\b)", "(?:\\btrue\\b)", "(?:\\b__COLUMN__\\b)", "(?:\\b__FILE__\\b)", "(?:\\b__FUNCTION__\\b)", "(?:\\b__LINE__\\b)", "(?:\\bassociativity\\b)", "(?:\\bconvenience\\b)", "(?:\\bdynamic\\b)", "(?:\\bdidSet\\b)", "(?:\\bfinal\\b)", "(?:\\bget\\b)", "(?:\\binfix\\b)", "(?:\\binout\\b)", "(?:\\blazy\\b)", "(?:\\bleft\\b)", "(?:\\bmutating\\b)", "(?:\\bnone\\b)", "(?:\\bnonmutating\\b)", "(?:\\boptional\\b)", "(?:\\boverride\\b)", "(?:\\bpostfix\\b)", "(?:\\bprecedence\\b)", "(?:\\bprefix\\b)", "(?:\\bProtocol\\b)", "(?:\\brequired\\b)", "(?:\\bright\\b)", "(?:\\bset\\b)", "(?:\\bType\\b)", "(?:\\bunowned\\b)", "(?:\\bweak\\b)", "(?:\\bwillSet\\b)", "(?:\\bString\\b)", "(?:\\bInt\\b)", "(?:\\bInt32\\b)", "(?:\\bNSDate\\b)", "(?:\\bCGFloat\\b)", "(?:\\bDecoded\\b)", "(?:\\bArgo.decodable\\b)"];
    }
}

