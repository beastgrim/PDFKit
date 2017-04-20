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
            drawResultsView.isOpaque = false
            drawResultsView.backgroundColor = UIColor.clear
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        openTestPDF()
    }

    
    fileprivate func openTestPDF() {
//        guard let pdfPath = Bundle.main.path(forResource: "test", ofType: "pdf") else {
//        guard let pdfPath = Bundle.main.path(forResource: "unsearch", ofType: "pdf") else {
//        guard let pdfPath = Bundle.main.path(forResource: "crash", ofType: "pdf") else {
//        guard let pdfPath = Bundle.main.path(forResource: "failsearch_resolved", ofType: "pdf") else {
//        guard let pdfPath = Bundle.main.path(forResource: "failhighlight", ofType: "pdf") else {
//        guard let pdfPath = Bundle.main.path(forResource: "check", ofType: "pdf") else {
//        guard let pdfPath = Bundle.main.path(forResource: "failsearch", ofType: "pdf") else {
        guard let pdfPath = Bundle.main.path(forResource: "offset", ofType: "pdf") else {
        return
        }
        guard let pdfData = try? Data(contentsOf: URL(fileURLWithPath: pdfPath)) else {
            return
        }
        guard let document = PDFDocument(data: pdfData) else {
            return
        }
        
        let pageIndex = 9
        
        if let pdfPageView = document.view(forPageNumber: pageIndex) {
            pdfPageView.layer.borderColor = UIColor.black.cgColor
            pdfPageView.layer.borderWidth = 4;
            drawResultsView.pageSize = pdfPageView.bounds.size;
            view.addSubview(pdfPageView)
        }

        let results = document.searchText("о", onPage: UInt(pageIndex))
        
        view.bringSubview(toFront: drawResultsView)
        drawResultsView.layer.borderWidth = 2
        drawResultsView.layer.borderColor = UIColor.blue.cgColor
        drawResultsView.searchResults = results
        drawResultsView.frame = document.cropBoxRect(forPage: pageIndex)
        
        NSLog("Success open PDF, number pages is \(document.numberOfPages). Results count: \(results.count)")
    }
    
    

}

