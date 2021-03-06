//
//  LiveUrlTableCellView.swift
//  iina+
//
//  Created by xjbeta on 2018/8/12.
//  Copyright © 2018 xjbeta. All rights reserved.
//

import Cocoa

class LiveUrlTableCellView: NSTableCellView {

    var isSelected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let selectionRect = NSInsetRect(bounds, 0, 0)
        let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 3, yRadius: 3)
        if isSelected {
            NSColor.customHighlightColor.setFill()
        } else {
            NSColor.white.setFill()
        }
        selectionPath.fill()
        
    }
    
}
