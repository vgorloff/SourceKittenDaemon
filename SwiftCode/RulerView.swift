//
//  RulerView.swift
//  SwiftEdit
//
//  Created by Scott Horn on 14/06/2014.
//  Copyright (c) 2014 Scott Horn. All rights reserved.
//

import Cocoa

let DEFAULT_THICKNESS = 25.0
let RULER_MARGIN = 11.0

class RulerView: NSRulerView {
    var _lineIndices : [Int]?
    var lineIndices : [Int]? {
        get {
            if self._lineIndices == nil {
                calculateLines()
            }
            return self._lineIndices
        }
    }
    var textView : NSTextView? {
        return (self.clientView as? NSTextView) ?? nil
    }

    override var isOpaque: Bool { return false }
    override var clientView: NSView? {
        willSet {
            let oldView = self.clientView
            let center = NotificationCenter.default
            if let o = oldView as? NSTextView {
                if o != newValue {
                    center.removeObserver(self, name: NSText.didEndEditingNotification, object: o.textStorage)
                    center.removeObserver(self, name: NSView.boundsDidChangeNotification, object: scrollView!.contentView)
                }
            }
            if newValue is NSTextView {
                center.addObserver(self, selector: "textDidChange:", name: NSText.didChangeNotification, object: newValue)
                scrollView!.contentView.postsBoundsChangedNotifications = true
                center.addObserver(self, selector: "boundsDidChange:", name: NSView.boundsDidChangeNotification, object: scrollView!.contentView)
                invalidateLineIndices()
            }
        }
    }
    
    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation:orientation)
        self.clientView = scrollView!.documentView
        self.ruleThickness = CGFloat(DEFAULT_THICKNESS)
        needsDisplay = true
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func boundsDidChange(notification: NSNotification) {
        needsDisplay = true
    }

    func textDidChange(notification: NSNotification) {
        invalidateLineIndices()
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        //super.drawRect(dirtyRect)
        drawHashMarksAndLabels(in: dirtyRect)
    }
    
    func invalidateLineIndices() {
        _lineIndices = nil
    }
    
    func lineNumberForCharacterIndex(_ index: Int) -> Int {
        let lineIndices = self.lineIndices!
        var left = 0, right = lineIndices.count
        while right - left > 1 {
            let mid = (left + right) / 2
            let lineIndex = lineIndices[mid]
            if index < lineIndex {
                right = mid
            } else if index > lineIndex {
                left = mid
            } else {
                return mid + 1
            }
        }
        return left + 1
    }
    
    func calculateRuleThickness() -> CGFloat {
        let lineIndices = self.lineIndices!
        let digits : Int = Int(log10(Double(lineIndices.count))) + 1
        var maxDigits = ""
        for _ in 0 ..< digits {
            maxDigits += "8"
        }
        let digitWidth = (maxDigits as NSString).size(withAttributes: textAttributes()).width * 2 + CGFloat(RULER_MARGIN)
        let defaultThickness = CGFloat(DEFAULT_THICKNESS)
        return digitWidth > defaultThickness  ? digitWidth : defaultThickness
    }
    
    func calculateLines() {
        var lineIndices : [Int] = []
        if let textView = self.textView {
            let text = textView.string as NSString
            let textLength: Int = text.length
            var totalLines: Int = 0
            var charIndex: Int = 0
            repeat {
                lineIndices.append(charIndex)
                charIndex = NSMaxRange(text.lineRange(for: NSMakeRange(charIndex, 0)))
                totalLines += 1
            } while charIndex < textLength
            
            // Check for trailing return
            var lineEndIndex: Int = 0, contentEndIndex: Int = 0
            let lastObject = lineIndices[lineIndices.count - 1]
            text.getLineStart(nil, end: &lineEndIndex, contentsEnd: &contentEndIndex, for: NSMakeRange(lastObject, 0))
            if contentEndIndex < lineEndIndex {
                lineIndices.append(lineEndIndex)
            }
            self._lineIndices = lineIndices
            
            let ruleThickness = self.ruleThickness
            let newThickness = calculateRuleThickness()
            
            if fabs(ruleThickness - newThickness) > 1 {
                DispatchQueue.main.async {
                    self.updateThinkness(CGFloat(ceil(Double(newThickness))))
                }
            }
        }
    }
    
    func updateThinkness(_ thickness: CGFloat) {
        self.ruleThickness = thickness
        self.needsDisplay = true
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        if let textView = self.textView {
            
            // Make background
            let docRect = convert(self.clientView!.bounds, from: clientView)
            let y = docRect.origin.y
            let height = docRect.size.height
            let width = bounds.size.width
            NSColor(calibratedRed: 0.969, green: 0.969, blue: 0.969, alpha: 1).set()
            NSMakeRect(0, y, width, height).fill()
            
            // Code folding area
            //NSColor(calibratedRed: 0.969, green: 0.969, blue: 0.969, alpha: 1).set()
            NSMakeRect(width - 8, y, 8, height).fill()
            
            // Seperator/s
            NSColor(calibratedRed: 0.902, green: 0.902, blue: 0.902, alpha: 1).set()
            var line = NSBezierPath()
            line.move(to: NSMakePoint(width - 8.5, y))
            line.line(to: NSMakePoint(width - 8.5, y + height))
            line.lineWidth = 1.0
            line.stroke()
            
            line = NSBezierPath()
            line.move(to: NSMakePoint(width - 0.5, y))
            line.line(to: NSMakePoint(width - 0.5, y + height))
            line.lineWidth = 1.0
            line.stroke()
            
            let layoutManager = textView.layoutManager
            let container = textView.textContainer
            let nullRange = NSMakeRange(NSNotFound, 0)
            var lineRectCount: Int = 0
            
            let textVisibleRect = self.scrollView!.contentView.bounds
            let rulerBounds = bounds
            let textInset = textView.textContainerInset.height
            
            let glyphRange = layoutManager!.glyphRange(forBoundingRect: textVisibleRect, in: container!)
            let charRange = layoutManager!.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            
            let lineIndices = self.lineIndices!
            let startChange = lineNumberForCharacterIndex(charRange.location)
            let endChange = lineNumberForCharacterIndex(NSMaxRange(charRange))
            for lineNumber in startChange ... endChange {
                let charIndex = lineIndices[lineNumber - 1]
                let lineRectsForRange = layoutManager!.rectArray(
                    forCharacterRange: NSMakeRange(charIndex, 0),
                    withinSelectedCharacterRange: nullRange,
                    in: container!,
                    rectCount: &lineRectCount)!
                if lineRectCount > 0 {
                    let ypos = textInset + NSMinY(lineRectsForRange[0]) - NSMinY(textVisibleRect)
                    let labelText = NSString(format: "%ld", lineNumber)
                    let labelSize = labelText.size(withAttributes: textAttributes())
                    
                    let lineNumberRect = NSMakeRect( NSWidth(rulerBounds) - labelSize.width - CGFloat(RULER_MARGIN),
                                                     ypos + (NSHeight(lineRectsForRange[0]) - labelSize.height) / 2.0,
                                                     NSWidth(rulerBounds) - CGFloat(RULER_MARGIN) * 2.0,
                                                     NSHeight(lineRectsForRange[0]) )
                    
                    labelText.draw(in: lineNumberRect, withAttributes: textAttributes())
                }
                
                // we are past the visible range so exit for
                if charIndex > NSMaxRange(charRange) {
                    break
                }
            }
        }
    }
    
    
    func textAttributes() -> [NSAttributedStringKey: Any] {
        return [
            .font: NSFont.labelFont(ofSize: NSFont.systemFontSize(for: NSControl.ControlSize.mini)),
            .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1.0)
        ]
    }
}
