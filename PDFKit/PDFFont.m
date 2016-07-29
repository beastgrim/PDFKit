//
//  PDFFont.m
//  PDFKit
//
//  Created by FLS on 01/07/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import "PDFFont.h"
#import "PDFKit-Swift.h"

const char *kEncodingKey = "Encoding";
const char *kBaseEncodingKey = "BaseEncoding";
const char *kToUnicodeKey = "ToUnicode";
const char *kDifferencesKey = "Differences";
const char *kFontDescriptorKey = "FontDescriptor";
const char *kCharSetKey = "CharSet";


typedef enum {
    UnknownEncoding = 0,
    StandardEncoding, // Defined in Type1 font programs
    MacRomanEncoding,
    WinAnsiEncoding,
    PDFDocEncoding,
    MacExpertEncoding,
    
} CharacterEncoding;


@interface PDFFont ()

@property (nonatomic, retain) ToUnicodeMapper *mapper;
@property (nonatomic, retain) NSMutableDictionary *glifNameByCode;
@property (nonatomic, retain) NSMutableArray *charSet;

@end

@implementation PDFFont {
    CGFloat defaultWidth;
    NSMutableDictionary *widths;
    CharacterEncoding encoding;
}


- (instancetype)initWithName:(NSString *)name fontDict:(CGPDFDictionaryRef)fontDict {
    if (self = [super init]) {
        _name = name;
        widths = [NSMutableDictionary new];
        defaultWidth = 1000;
        
        
        // try get toUnicode map
        CGPDFObjectRef toUnicodeObj;
        if (CGPDFDictionaryGetObject(fontDict, kToUnicodeKey, &toUnicodeObj)) {
            
            CGPDFStreamRef toUnicodeStream;
            if (CGPDFObjectGetValue(toUnicodeObj, kCGPDFObjectTypeStream, &toUnicodeStream)) {
                
                CFDataRef dataRef = CGPDFStreamCopyData(toUnicodeStream, NULL);
                NSData *data = (__bridge NSData*)dataRef;
                ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
                
                if (mapper) {
                    NSLog(@"\n\nDID HANDLE FONT: [%@]\n\nMapData: %@\nMAP: %@", name, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], mapper.map);
                    _mapper = mapper;
                }
            }
        }
        
        
        // try get encoding if no mapper
        CGPDFDictionaryRef encodingDict;
        if (CGPDFDictionaryGetDictionary(fontDict, kEncodingKey, &encodingDict) && _mapper == nil) {
            
            _glifNameByCode = [NSMutableDictionary new];
            
            CGPDFObjectRef baseEncodingObj;
            if (CGPDFDictionaryGetObject(encodingDict, kBaseEncodingKey, &baseEncodingObj)) {
                
                char * baseEncoding;
                CGPDFObjectGetValue(baseEncodingObj, kCGPDFObjectTypeName, &baseEncoding);
                
                [self setEncodingNamed:[NSString stringWithFormat:@"%s", baseEncoding]];
            }
            
            CGPDFArrayRef differences;
            if (CGPDFDictionaryGetArray(encodingDict, kDifferencesKey, &differences)) {
                
                NSInteger curDifIndex = 0;

                for (int i = 0; i < CGPDFArrayGetCount(differences); i++) {

                    CGPDFObjectRef obj;
                    CGPDFArrayGetObject(differences, i, &obj);
                    
                    CGPDFObjectType type = CGPDFObjectGetType(obj);
                    
                    if (type == kCGPDFObjectTypeInteger) {
                        CGPDFInteger val;
                        CGPDFObjectGetValue(obj, kCGPDFObjectTypeInteger, &val);
                        curDifIndex = val;
                        
                    } else if (type == kCGPDFObjectTypeName) {
                        char * glif;
                        CGPDFObjectGetValue(obj, kCGPDFObjectTypeName, &glif);

                        _glifNameByCode[@(curDifIndex)] = [NSString stringWithFormat:@"%s", glif];
                        curDifIndex++;
                    }
                }
            }

        }
        
//        CGPDFDictionaryRef fontDecriptor;
//        if (CGPDFDictionaryGetDictionary(fontDict, kFontDescriptorKey, &fontDecriptor)) {
//            
//            
//            CGPDFStringRef charSet;
//            if (CGPDFDictionaryGetString(fontDecriptor, kCharSetKey, &charSet)) {
//                
//                NSString *data = CFBridgingRelease(CGPDFStringCopyTextString(charSet));
//                if (data.length) { data = [data substringFromIndex:1];  }
//                NSLog(@"CharSet %@", data);
//                _charSet = [data componentsSeparatedByString:@"/"];
//            }
//        }
        
        
        
        CGPDFArrayRef widthsArray;
        if (CGPDFDictionaryGetArray(fontDict, "W", &widthsArray)) {
            NSUInteger length = CGPDFArrayGetCount(widthsArray);
            int idx = 0;
            CGPDFObjectRef nextObject = nil;
            
            while (idx < length)
            {
                CGPDFInteger baseCid = 0;
                CGPDFArrayGetInteger(widthsArray, idx++, &baseCid);
                
                CGPDFObjectRef integerOrArray = nil;
                CGPDFInteger firstCharacter = 0;
                CGPDFArrayGetObject(widthsArray, idx++, &integerOrArray);
                
                if (CGPDFObjectGetType(integerOrArray) == kCGPDFObjectTypeInteger)
                {
                    // [ first last width ]
                    CGPDFInteger maxCid;
                    CGPDFInteger glyphWidth;
                    CGPDFObjectGetValue(integerOrArray, kCGPDFObjectTypeInteger, &maxCid);
                    CGPDFArrayGetInteger(widthsArray, idx++, &glyphWidth);
                    [self setWidthsFrom:baseCid to:maxCid width:glyphWidth];
                    
                    // If the second item is an array, the sequence
                    // defines widths on the form [ first list-of-widths ]
                    CGPDFArrayRef characterWidths;
                    
                    if (!CGPDFObjectGetValue(nextObject, kCGPDFObjectTypeArray, &characterWidths))
                    {
                        break;
                    }
                    
                    NSUInteger widthsCount = CGPDFArrayGetCount(characterWidths);
                    
                    for (int index = 0; index < widthsCount ; index++)
                    {
                        CGPDFInteger width;
                        
                        if (CGPDFArrayGetInteger(characterWidths, index, &width))
                        {
                            NSNumber *key = [NSNumber numberWithInt: (int)firstCharacter + index];
                            NSNumber *val = [NSNumber numberWithInt: (int)width];
                            [widths setObject:val forKey:key];
                        }
                    }
                }
                else
                {
                    // [ first list-of-widths ]
                    CGPDFArrayRef glyphWidths;
                    CGPDFObjectGetValue(integerOrArray, kCGPDFObjectTypeArray, &glyphWidths);
                    [self setWidthsWithBase:baseCid array:glyphWidths];
                }
            }
        }
        
        CGPDFInteger defaultWidthValue;
        if (CGPDFDictionaryGetInteger(fontDict, "DW", &defaultWidthValue)) {
            defaultWidth = defaultWidthValue;
        }
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name defaultWidth:(CGFloat)defWidth widths:(NSMutableDictionary *)allWidths {
    if (self = [super init]) {
        _name = name;
        defaultWidth = defWidth;
        widths = allWidths;
    }
    return self;
}

#pragma mark - Base

#pragma mark Encoding
- (void)setEncodingNamed:(NSString *)encodingName {
    
    if ([@"MacRomanEncoding" isEqualToString:encodingName]) {
        encoding = MacRomanEncoding;
        
    } else if ([@"WinAnsiEncoding" isEqualToString:encodingName]) {
        encoding = WinAnsiEncoding;
        
    } else {
        encoding = UnknownEncoding;
    }
}

#pragma mark - Public
- (NSString *)stringWithPDFString:(CGPDFStringRef)pdfString {
    
    if (_mapper) {
        // Character codes
        const unsigned char * characterCodes = CGPDFStringGetBytePtr(pdfString);
        int count = CGPDFStringGetLength(pdfString);
        NSMutableString *string = [NSMutableString string];
        uint16_t code2 = characterCodes[1] + (characterCodes[0] << 8);  // 16 byte code
        
        for (int i = 0; i < count; i++) {
            
            char code = characterCodes[i];
            
            NSString *letter = _mapper.map[@(code)];
            if (letter) {
                [string appendFormat:@"%@", letter];
            } else {
                NSString *letter = _mapper.map[@(code2)];
                return letter;
            }
        }
        
        return string;
        
    } else if (_glifNameByCode) {
        
        int length = CGPDFStringGetLength(pdfString);
        const unsigned char * characterCodes = CGPDFStringGetBytePtr(pdfString);

        NSMutableString *string = [NSMutableString string];

        for (int i = 0; i < length; i++) {
            uint8_t code = characterCodes[i];
            
            NSDictionary *cirillicMap = [ToUnicodeMapper standardCyrillicGlyphNames];
            NSString *glif = _glifNameByCode[@(code)];
            
            if (glif) {
                if (glif.length == 1) {
                    [string appendString:glif];

                } else {
                    [string appendFormat:@"%@", cirillicMap[glif] ?: @"?"];
                }

            } else {
                
                NSLog(@"UNCNOWN CODE %d", code);
                [string appendFormat:@" "];
            }
        }
        
        return string;
    }
    
    return (NSString *)CFBridgingRelease(CGPDFStringCopyTextString(pdfString));
}

#pragma mark - Helpers

- (void)setWidthsFrom:(CGPDFInteger)cid to:(CGPDFInteger)maxCid width:(CGPDFInteger)width {
    while (cid <= maxCid) {
        [widths setObject:[NSNumber numberWithInt:(int)width] forKey:[NSNumber numberWithInt:(int)cid++]];
    }
}
- (void)setWidthsWithBase:(CGPDFInteger)base array:(CGPDFArrayRef)array {
    NSInteger count = CGPDFArrayGetCount(array);
    CGPDFInteger width;
    
    for (int index = 0; index < count ; index++) {
        if (CGPDFArrayGetInteger(array, index, &width)) {
            [widths setObject:[NSNumber numberWithInt:(int)width] forKey:[NSNumber numberWithInt:(int)base + index]];
        }
    }
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone {
    
    PDFFont *copy = [[PDFFont alloc] initWithName:_name defaultWidth:defaultWidth widths:widths];
    return copy;
}

#pragma mark - 
- (NSUInteger)hash {
    return [_name hash];
}

- (BOOL)isEqual:(id)object {
    return [_name isEqual:object];
}

@end
