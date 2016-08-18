//
//  ViewController.swift
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var drawResultsView: ResultsDrawView! {
        didSet {
            drawResultsView.opaque = false
            drawResultsView.backgroundColor = UIColor.clearColor()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        openTestPDF()
    }

    
    private func openTestPDF() {
//        guard let pdfPath = NSBundle.mainBundle().pathForResource("Untitled", ofType: "pdf") else {
        guard let pdfPath = NSBundle.mainBundle().pathForResource("unsearch", ofType: "pdf") else {
            return
        }
        guard let pdfData = NSData(contentsOfFile: pdfPath) else {
            return
        }
        guard let document = PDFDocument(data: pdfData) else {
            return
        }
        
        let pageIndex = 1
        
        if let pdfPageView = document.viewForPageNumber(pageIndex) {
            drawResultsView.pageSize = pdfPageView.bounds.size;
            view.addSubview(pdfPageView)
        }
        let fonts = document.getFontsForPageNumber(pageIndex)
        for font in fonts {
            
            drawResultsView.fonts.append(font.bBoxRect)
        }

        let results = document.searchText("на", onPage: UInt(pageIndex))
        
        view.bringSubviewToFront(drawResultsView)
        drawResultsView.layer.borderWidth = 2
        drawResultsView.layer.borderColor = UIColor.blueColor().CGColor
        drawResultsView.searchResults = results
        
        
        print("Success open PDF, number pages is \(document.numberOfPages). Results: \(results)")
    }
    
    

}

