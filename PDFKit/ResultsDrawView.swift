//
//  ResultsDrawView.swift
//  PDFKit
//
//  Created by FLS on 29/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

import UIKit

class ResultsDrawView: UIView {

    var searchResults = [SearchResults]() {
        didSet {
            setNeedsDisplay()
        }
    }
    var pageSize: CGSize = CGSizeZero
    var scale: CGFloat = 1
    

    private var drawAtttributes = [NSFontAttributeName: UIFont.systemFontOfSize(12), NSBackgroundColorAttributeName: UIColor.yellowColor().colorWithAlphaComponent(0.9), NSForegroundColorAttributeName: UIColor.blackColor().colorWithAlphaComponent(0.5)]
    

    override func drawRect(rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()

//        let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 160)
//        CGContextConcatCTM(ctx, transform)
        CGContextSetLineWidth(ctx, 2)
        
        for res in searchResults {
            UIColor.redColor().set()
            
//            let x = res.textRect.origin.x*scale
//            let y = rect.height - res.textRect.origin.y*scale + 155
//            let width = res.textRect.size.width
//            let height = res.textRect.size.height
//            CGContextFillRect(ctx, CGRectMake(x, y+height+2, width, 2))
            
            var textRect = res.textRect
            textRect.origin.y = res.textRect.origin.y*scale - res.textRect.size.height + 3 // - font size + padding
            CGContextStrokeRect(ctx, textRect)
            
//            if let text = res.nextText {
//                drawAtttributes[NSFontAttributeName] = UIFont.systemFontOfSize(round(height))
//                (text as NSString).drawInRect(CGRectMake(x, y, 200, height+4), withAttributes: drawAtttributes)
//            }
        }
    }


}
