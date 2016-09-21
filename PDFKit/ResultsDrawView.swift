//
//  ResultsDrawView.swift
//  PDFKit
//
//  Created by FLS on 29/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

import UIKit

class ResultsDrawView: UIView {

    var searchResults = [NSValue]() {
        didSet {
            setNeedsDisplay()
        }
    }
    var pageSize: CGSize = CGSizeZero
    var scale: CGFloat = 1
    

    private var drawAtttributes = [NSFontAttributeName: UIFont.systemFontOfSize(12), NSBackgroundColorAttributeName: UIColor.yellowColor().colorWithAlphaComponent(0.9), NSForegroundColorAttributeName: UIColor.blackColor().colorWithAlphaComponent(0.5)]
    

    override func drawRect(rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()!

        CGContextSetLineWidth(ctx, 2)
        
        for (_,res) in searchResults.enumerate() {

            var textRect = res.CGRectValue()
            textRect.origin.y -= textRect.size.height - 2

            CGContextSetFillColor(ctx, CGColorGetComponents(UIColor(colorLiteralRed: 0, green: 1, blue: 0, alpha: 0.38).CGColor))
            CGContextFillRect(ctx, textRect)
            
//            (i.description as NSString).drawInRect(textRect, withAttributes: [NSForegroundColorAttributeName: UIColor.redColor(), NSFontAttributeName: UIFont.boldSystemFontOfSize(16)])
        }
    }


}
