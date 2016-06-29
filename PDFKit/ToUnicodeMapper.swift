//
//  ToUnicodeMapper.swift
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

import Foundation

class ToUnicodeMapper: NSObject {

    private let fontMap: String
    private(set) var map = [Int:String]()
    
    init?(data: NSData) {
        guard let fontMapString = NSString(data: data, encoding: NSASCIIStringEncoding) else {
            return nil
        }
        fontMap = fontMapString as String
        
        super.init()
        prepareData(fontMap)
    }
    
    private func prepareData(fontMap: String) {
        
        if let start = fontMap.rangeOfString("beginbfrange\n"), let stop = fontMap.rangeOfString("\nendbfrange") {
            var data = fontMap.substringToIndex(stop.startIndex)
            data = data.substringFromIndex(start.endIndex)
            
            let lines = data.componentsSeparatedByString("\n")
            let regex = try! NSRegularExpression(pattern: "<(\\w+)>", options: .CaseInsensitive)
            
            for line in lines {
                
                let results = regex.matchesInString(line, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, line.characters.count))
                
                if results.count == 3 {
                    let startIndexStr = (line as NSString).substringWithRange(NSMakeRange(results[0].range.location+1, results[0].range.length-2))
                    let endIndexStr = (line as NSString).substringWithRange(NSMakeRange(results[1].range.location+1, results[1].range.length-2))
                    let startIndex = strtol(startIndexStr, nil, 16)
                    let endIndex = strtol(endIndexStr, nil, 16)
                    
                    let unicodeStr = (line as NSString).substringWithRange(NSMakeRange(results[2].range.location+1, results[2].range.length-2))
                    let uniChar = strtol(unicodeStr, nil, 16)
                    
                    var count = 0
                    for i in startIndex...endIndex {
                        self.map[i] = "\(Character(UnicodeScalar(uniChar+count)))"
                        count += 1
                    }
                } else {
                    continue
                }
            }
            
        } else if let start = fontMap.rangeOfString("beginbfchar\n"), let stop = fontMap.rangeOfString("\nendbfchar") {
            var data = fontMap.substringToIndex(stop.startIndex)
            data = data.substringFromIndex(start.endIndex)
            
            let lines = data.componentsSeparatedByString("\n")
            let regex = try! NSRegularExpression(pattern: "<(\\w+)>", options: .CaseInsensitive)
            
            for line in lines {
                
                let results = regex.matchesInString(line, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, line.characters.count))
                
                if results.count == 2 {
                    let codeStr = (line as NSString).substringWithRange(NSMakeRange(results[0].range.location+1, results[0].range.length-2))
                    let code = strtol(codeStr, nil, 16)
                    
                    let unicodeStr = (line as NSString).substringWithRange(NSMakeRange(results[1].range.location+1, results[1].range.length-2))
                    let uniChar = strtol(unicodeStr, nil, 16)
                    
                    self.map[code] = "\(Character(UnicodeScalar(uniChar)))"
                    
                } else {
                    continue
                }
            }
        }
    }
}
