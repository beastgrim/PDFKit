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
    

    override func drawRect(rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()

//        let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: rect.size.height)
//        CGContextConcatCTM(ctx, transform)
        let scale: CGFloat = 1;
        
        UIColor.redColor().set()
        for res in searchResults {
            let x = res.textRect.origin.x*scale
            let y = rect.height - res.textRect.origin.y*scale
            let width = res.textRect.size.width
            let height = res.textRect.size.height
            CGContextFillRect(ctx, CGRectMake(x, y+height+4, width, 2))
            
            if let text = res.nextText {
                (text as NSString).drawInRect(CGRectMake(x, y, 200, 16), withAttributes: [NSFontAttributeName: UIFont.systemFontOfSize(11)])
            }
        }
    }


}
