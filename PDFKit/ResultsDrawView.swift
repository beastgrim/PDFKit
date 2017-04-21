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
    var pageSize: CGSize = CGSize.zero
    var scale: CGFloat = 1
    

    fileprivate var drawAtttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 12), NSBackgroundColorAttributeName: UIColor.yellow.withAlphaComponent(0.9), NSForegroundColorAttributeName: UIColor.black.withAlphaComponent(0.5)]
    

    override func draw(_ rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setLineWidth(0.5)
        
        for (_,res) in searchResults.enumerated() {

            var textRect = res.cgRectValue
            textRect.origin.y -= textRect.size.height - 2
            
            let stoke = false
            
            if stoke {
                ctx.setStrokeColor(UIColor(colorLiteralRed: 1, green: 0, blue: 0, alpha: 0.38).cgColor.components!)
                ctx.stroke(textRect)
            } else {
                ctx.setFillColor(UIColor(colorLiteralRed: 1, green: 0, blue: 0, alpha: 0.38).cgColor.components!)
                ctx.fill(textRect)
            }
            
//            (i.description as NSString).drawInRect(textRect, withAttributes: [NSForegroundColorAttributeName: UIColor.redColor(), NSFontAttributeName: UIFont.boldSystemFontOfSize(16)])
        }
    }


}
