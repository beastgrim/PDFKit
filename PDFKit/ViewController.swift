//
//  ViewController.swift
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var textView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        openTestPDF()
    }

    
    private func openTestPDF() {
        guard let pdfPath = NSBundle.mainBundle().pathForResource("test", ofType: "pdf") else {
            return
        }
        guard let pdfData = NSData(contentsOfFile: pdfPath) else {
            return
        }
        guard let document = PDFDocument(data: pdfData) else {
            return
        }
        
        let results = document.searchText("кто", onPage: 0)
        
        (view as? ResultsDrawView)?.searchResults = results
        
        print("Success open PDF, number pages is \(document.numberOfPages). Results: \(results)")
    }
    
    

}

