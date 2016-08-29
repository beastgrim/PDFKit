//
//  ToUnicodeMapper.swift
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

import Foundation

class ToUnicodeMapper: NSObject {
    
    static let standardCyrillicGlyphNames: [String:String] = ["afii10017":"А",
                                                              "afii10018":"Б",
                                                              "afii10019":"В",
                                                              "afii10020":"Г",
                                                              "afii10021":"Д",
                                                              "afii10022":"Е",
                                                              "afii10023":"Ё",
                                                              "afii10024":"Ж",
                                                              "afii10025":"З",
                                                              "afii10026":"И",
                                                              "afii10027":"Й",
                                                              "afii10028":"К",
                                                              "afii10029":"Л",
                                                              "afii10030":"М",
                                                              "afii10031":"Н",
                                                              "afii10032":"О",
                                                              "afii10033":"П",
                                                              "afii10034":"Р",
                                                              "afii10035":"С",
                                                              "afii10036":"Т",
                                                              "afii10037":"У",
                                                              "afii10038":"Ф",
                                                              "afii10039":"Х",
                                                              "afii10040":"Ц",
                                                              "afii10041":"Ч",
                                                              "afii10042":"Ш",
                                                              "afii10043":"Щ",
                                                              "afii10044":"Ъ",
                                                              "afii10045":"Ы",
                                                              "afii10046":"Ь",
                                                              "afii10047":"Э",
                                                              "afii10048":"Ю",
                                                              "afii10049":"Я",
                                                              
                                                              
                                                              "afii10065":"а",
                                                              "afii10066":"б",
                                                              "afii10067":"в",
                                                              "afii10068":"г",
                                                              "afii10069":"д",
                                                              "afii10070":"е",
                                                              "afii10071":"ё",
                                                              "afii10072":"ж",
                                                              "afii10073":"з",
                                                              "afii10074":"и",
                                                              "afii10075":"й",
                                                              "afii10076":"к",
                                                              "afii10077":"л",
                                                              "afii10078":"м",
                                                              "afii10079":"н",
                                                              "afii10080":"о",
                                                              "afii10081":"п",
                                                              "afii10082":"р",
                                                              "afii10083":"с",
                                                              "afii10084":"т",
                                                              "afii10085":"у",
                                                              "afii10086":"ф",
                                                              "afii10087":"х",
                                                              "afii10088":"ц",
                                                              "afii10089":"ч",
                                                              "afii10090":"ш",
                                                              "afii10091":"щ",
                                                              "afii10092":"ъ",
                                                              "afii10093":"ы",
                                                              "afii10094":"ь",
                                                              "afii10095":"э",
                                                              "afii10096":"ю",
                                                              "afii10097":"я",
                                                              
                                                              "space":" ",
                                                              "exclam":"!",
                                                              "quotedbl":"\"",
                                                              "numbersign":"#",
                                                              "dollar":"$",
                                                              "percent":"%",
                                                              "ampersand":"&",
                                                              "quotesingle":"'",
                                                              "parenleft":"(",
                                                              "parenright":")",
                                                              "asterisk":"*",
                                                              "plus":"+",
                                                              "comma":",",
                                                              "hyphen":"-",
                                                              "period":".",
                                                              "slash":"/",
                                                              "zero":"0",
                                                              "one":"1",
                                                              "two":"2",
                                                              "three":"3",
                                                              "four":"4",
                                                              "five":"5",
                                                              "six":"6",
                                                              "seven":"7",
                                                              "eight":"8",
                                                              "nine":"9",
                                                              "colon":":",
                                                              "semicolon":";",
                                                              "less":"<",
                                                              "equal":"=",
                                                              "greater":">",
                                                              "question":"?",
                                                              "at":"@",
                                                              
                                                              "guillemotleft":"«",
                                                              "guillemotright":"»"
                                                              
    
    
        ];

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

        var mapCopy = fontMap

        while let start = mapCopy.rangeOfString("beginbfrange"), let end = mapCopy.rangeOfString("endbfrange") {
            var data = mapCopy.substringWithRange(start.endIndex ..< end.startIndex)
            data = data.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            
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
                        if uniChar+count < Int(UInt16.max) {
                            self.map[i] = "\(Character(UnicodeScalar(uniChar+count)))"
                        } else {
                            NSLog("error: value is outside of Unicode codespace")
                        }
                        count += 1
                    }
                } else {
                    continue
                }
            }
            
            mapCopy = mapCopy.substringFromIndex(end.endIndex)
        }
        
        mapCopy = fontMap
        while let start = mapCopy.rangeOfString("beginbfchar"), let end = mapCopy.rangeOfString("endbfchar") {
            var data = mapCopy.substringWithRange(start.endIndex ..< end.startIndex)
            data = data.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            
            let lines = data.componentsSeparatedByString("\n")
            let regex = try! NSRegularExpression(pattern: "<(\\w+)>", options: .CaseInsensitive)
            
            for line in lines {
                
                let results = regex.matchesInString(line, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, line.characters.count))
                
                if results.count == 2 {
                    let codeStr = (line as NSString).substringWithRange(NSMakeRange(results[0].range.location+1, results[0].range.length-2))
                    let code = strtol(codeStr, nil, 16)
                    
                    let unicodeStr = (line as NSString).substringWithRange(NSMakeRange(results[1].range.location+1, results[1].range.length-2))
                    let uniChar = strtol(unicodeStr, nil, 16)
                    
                    if uniChar < Int(UInt16.max) {
                        self.map[code] = "\(Character(UnicodeScalar(uniChar)))"
                    } else {
                        NSLog("error: value is outside of Unicode codespace")
                    }
                } else {
                    continue
                }
            }
            
            mapCopy = mapCopy.substringFromIndex(end.endIndex)
        }
        
        map[0] = ""
    }
}
