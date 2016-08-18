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
const char *kSubtype = "Subtype";


const char *kXHeight = "XHeight"; // (Optional) The font’s x height: the vertical coordinate of the top of flat non- ascending lowercase letters (like the letter x), measured from the baseline. Default value: 0.
const char *kFontBBox = "FontBBox"; // (Required) A rectangle (see Section 3.8.3, “Rectangles”), expressed in the glyph coordinate system, specifying the font bounding box. This is the small- est rectangle enclosing the shape that would result if all of the glyphs of the font were placed with their origins coincident and then filled.
const char *kLeading = "Leading"; // (Optional) The desired spacing between baselines of consecutive lines of text. Default value: 0.
const char *kCapHeight = "CapHeight"; // (Required) The vertical coordinate of the top of flat capital letters, measured from the baseline.
const char *kMaxWidth = "MaxWidth"; // (Optional) The maximum width of glyphs in the font. Default value: 0.
const char *kWidths = "Widths"; // (Required except for the standard 14 fonts; indirect reference preferred) An array of (LastChar − FirstChar + 1) widths, each element being the glyph width for the character whose code is FirstChar plus the array index. For character codes outside the range FirstChar to LastChar, the value of MissingWidth from the FontDescriptor entry for this font is used. The glyph widths are measured in units in which 1000 units corresponds to 1 unit in text space. These widths must be consistent with the actual widths given in the font program itself. (See implementation note 43 in Appendix H.) For more information on glyph widths and other glyph metrics, see Section 5.1.3, “Glyph Positioning and Metrics.”
const char *kFirstChar = "FirstChar"; // (Required except for the standard 14 fonts) The first character code defined in the font’s Widths array.
const char *kLastChar = "LastChar"; // (Required except for the standard 14 fonts) The last character code defined in the font’s Widths array.


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
        
        const char *subtype;
        if (CGPDFDictionaryGetName(fontDict, kSubtype, &subtype)) {
            if (strcmp(subtype, "Type1") == 0) {
                _type = PDFFontType1;
            } else if (strcmp(subtype, "Type2") == 0) {
                _type = PDFFontType2;
            } else if (strcmp(subtype, "Type3") == 0) {
                _type = PDFFontType3;
            }
        }
        
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
        
        CGPDFDictionaryRef fontDecriptor;
        if (CGPDFDictionaryGetDictionary(fontDict, kFontDescriptorKey, &fontDecriptor)) {
            
            CGPDFReal XHeight;
            if (CGPDFDictionaryGetNumber(fontDecriptor, kXHeight, &XHeight)) {
                NSLog(@"XHeight %f", XHeight);
            }
            CGPDFReal Leading;
            if (CGPDFDictionaryGetNumber(fontDecriptor, kLeading, &Leading)) {
                NSLog(@"Leading %f", Leading);
            }
            CGPDFReal CapHeight;
            if (CGPDFDictionaryGetNumber(fontDecriptor, kCapHeight, &CapHeight)) {
                NSLog(@"CapHeight %f", CapHeight);
            }
            CGPDFArrayRef FontBBox;
            if (CGPDFDictionaryGetArray(fontDecriptor, kFontBBox, &FontBBox)) {
                size_t count = CGPDFArrayGetCount(FontBBox);
                NSLog(@"FontBBox %zu", count);
                _fontBBox.size = count;
                _fontBBox.values = malloc(sizeof(CGPDFInteger)*count);
                for (size_t i = 0; i < count; i++) {
                    CGPDFInteger val;
                    CGPDFArrayGetInteger(FontBBox, i, &val);
                    _fontBBox.values[i] = val;
                }
            }

            /*
            CGPDFStringRef charSet;
            if (CGPDFDictionaryGetString(fontDecriptor, kCharSetKey, &charSet)) {
                
                NSString *data = CFBridgingRelease(CGPDFStringCopyTextString(charSet));
                if (data.length) { data = [data substringFromIndex:1];  }
                NSLog(@"CharSet %@", data);
                _charSet = [data componentsSeparatedByString:@"/"];
            } */
        }
        
        CGPDFInteger FirstChar;
        if (CGPDFDictionaryGetInteger(fontDict, kFirstChar, &FirstChar)) {
            NSLog(@"FirstChar %ld", FirstChar);
            _firstChar = FirstChar;
        }
        CGPDFInteger LastChar;
        if (CGPDFDictionaryGetInteger(fontDict, kLastChar, &LastChar)) {
            NSLog(@"LastChar %ld", LastChar);
            _lastChar = LastChar;
        }
        
        
        CGPDFArrayRef Widths;
        if (CGPDFDictionaryGetArray(fontDict, kWidths, &Widths)) {
            size_t count = CGPDFArrayGetCount(Widths);
            NSLog(@"Widths %zu", count);
            _widths.size = count;
            _widths.values = malloc(sizeof(CGPDFInteger)*count);
            for (size_t i = 0; i < count; i++) {
                CGPDFInteger val;
                CGPDFArrayGetInteger(Widths, i, &val);
                _widths.values[i] = val;
            }
        }
        
        CGPDFArrayRef widthsArray;
        if (CGPDFDictionaryGetArray(fontDict, kWidths, &widthsArray)) {
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
        
//        CGPDFInteger defaultWidthValue;
//        if (CGPDFDictionaryGetInteger(fontDict, "DW", &defaultWidthValue)) {
//            defaultWidth = defaultWidthValue;
//        }
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

- (void)dealloc {
    if (_fontBBox.size > 0 && _fontBBox.values != nil) {
        free(_fontBBox.values);
        _fontBBox.values = nil;
        _fontBBox.size = 0;
    }
    if (_widths.size > 0 && _widths.values != nil) {
        free(_widths.values);
        _widths.values = nil;
        _widths.size = 0;
    }
}

#pragma mark - Base

- (void)setWidthsFrom:(CGPDFInteger)cid to:(CGPDFInteger)maxCid width:(CGPDFInteger)width {
    while (cid <= maxCid) {
        [widths setObject:[NSNumber numberWithInt:(int)width] forKey:[NSNumber numberWithInt:(int)cid++]];
    }
}

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
- (CGPDFInteger)widthOfChar:(CGPDFInteger)charCode {
    if (_widths.size > charCode) {
        return _widths.values[charCode];
    }
    NSLog(@"widthOfChar %ld not found!", charCode);
    return defaultWidth;
}
- (CGPDFInteger)widthOfPDFString:(CGPDFStringRef)pdfString {
    const unsigned char * characterCodes = CGPDFStringGetBytePtr(pdfString);
    int count = CGPDFStringGetLength(pdfString);
    CGPDFInteger result = 0;
    size_t countCodes = _widths.size;
    for (int i = 0; i < count; i++) {
        char code = characterCodes[i];
        size_t charIndex = code - _firstChar;
        if (countCodes > charIndex) {
            CGPDFInteger val = _widths.values[code];
            result += val;
            
//            NSNumber *w = widths[[NSNumber numberWithInt:(int)code]];
            NSLog(@"Find width of char %d: %ld", code, val);
        } else {
            NSLog(@"Error get char width index: %zu, charCode %d widthLength %zu", charIndex, code, countCodes);
        }
    }
    return result ?: 500;
}

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

- (CGRect)bBoxRect {
    if (_fontBBox.size == 4) {
        CGFloat lowerLeftX = _fontBBox.values[0];
        CGFloat lowerLeftY = _fontBBox.values[1];
        CGFloat upperRightX = _fontBBox.values[2];
        CGFloat upperRightY = _fontBBox.values[3];
        CGFloat width = upperRightX - lowerLeftX;
        CGFloat height = upperRightY - lowerLeftY;
        CGFloat x = lowerLeftX;
        CGFloat y = upperRightY;
        
        return CGRectMake(x, y, width, height);
    }
    return CGRectZero;
}

#pragma mark - Helpers

- (void)setWidthsWithBase:(CGPDFInteger)base array:(CGPDFArrayRef)array {
    NSInteger count = CGPDFArrayGetCount(array);
    CGPDFInteger width;
    
    for (int index = 0; index < count ; index++) {
        if (CGPDFArrayGetInteger(array, index, &width)) {
            [widths setObject:[NSNumber numberWithInt:(int)width] forKey:[NSNumber numberWithInt:(int)base + index]];
        }
    }
}

- (CGPDFReal) getRealForDict:(CGPDFDictionaryRef)dictRef forKey:(const char*)key {
    CGPDFReal result;
    if (CGPDFDictionaryGetNumber(dictRef, key, &result)) {
        NSLog(@"Get real %s = %f", key, result);
        return result;
    }
    return 0;
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
