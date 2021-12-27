//
//  GroovySyntaxHighligher.swift
//  SwiftEdit
//
//  Created by Scott Horn on 18/06/2014.
//  Copyright (c) 2014 Scott Horn. All rights reserved.
//

import Cocoa

private let SWIFT_ELEMENT_TYPE_KEY = NSAttributedString.Key("swiftElementType")

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
                                               selector: #selector(textStorageDidProcessEditing(_:)),
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


