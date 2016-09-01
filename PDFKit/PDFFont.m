//
//  PDFFont.m
//  PDFKit
//
//  Created by FLS on 01/07/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import "PDFFont.h"
#import "PDFKit-Swift.h"
#import "RenderingState.h"

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
const char *kAscent = "Ascent"; // (Required) The maximum height above the baseline reached by glyphs in this font, excluding the height of glyphs for accented characters.
const char *kMaxWidth = "MaxWidth"; // (Optional) The maximum width of glyphs in the font. Default value: 0.
const char *kWidths = "Widths"; // (Required except for the standard 14 fonts; indirect reference preferred) An array of (LastChar − FirstChar + 1) widths, each element being the glyph width for the character whose code is FirstChar plus the array index. For character codes outside the range FirstChar to LastChar, the value of MissingWidth from the FontDescriptor entry for this font is used. The glyph widths are measured in units in which 1000 units corresponds to 1 unit in text space. These widths must be consistent with the actual widths given in the font program itself. (See implementation note 43 in Appendix H.) For more information on glyph widths and other glyph metrics, see Section 5.1.3, “Glyph Positioning and Metrics.”
const char *kFirstChar = "FirstChar"; // (Required except for the standard 14 fonts) The first character code defined in the font’s Widths array.
const char *kLastChar = "LastChar"; // (Required except for the standard 14 fonts) The last character code defined in the font’s Widths array.

const char *kW = "W";   // A description of the widths for the glyphs in the CIDFont. The array’s elements have a variable format that can specify individual widths for consecutive CIDs or one width for a range of CIDs (see “Glyph Metrics in CIDFonts” on page 340). Default value: none (the DW value is used for all glyphs).
const char *kDW = "DW"; // The default width for glyphs in the CIDFont (see “Glyph Met- rics in CIDFonts” on page 340). Default value: 1000.
const char *kFontFile3 = "FontFile3";
const char *kDescendantFonts = "DescendantFonts"; // A CID-keyed font, then, is the combination of a CMap with one or more CIDFonts, simple fonts, or composite fonts containing glyph descriptions. In PDF, a CID-keyed font is represented as a Type 0 font. It contains an Encoding entry whose value is a CMap dictionary, and its DescendantFonts array refer- ences the CIDFont or font dictionaries with which the CMap has been combined.
const char *kCIDSystemInfo = "CIDSystemInfo"; // CIDSystemInfo entry is a dictionary that specifies the CIDFont’s character collection. Note that the CIDFont need not contain glyph descriptions for all the CIDs in a collection; it can contain a subset. In a CMap, the CIDSystemInfo entry is either a single dictionary or an array of dictionaries, depending on whether it associates codes with a single character collection or with multiple character collections; see Section 5.6.4, “CMaps.”


typedef enum {
    UnknownEncoding = 0,
    StandardEncoding, // Defined in Type1 font programs
    MacRomanEncoding,
    WinAnsiEncoding,
    PDFDocEncoding,
    MacExpertEncoding,
    
} CharacterEncoding;


@interface PDFFont ()

@property (nonatomic, retain) NSMutableArray *charSet;
@property (nonatomic) NSMutableDictionary <NSNumber*,NSNumber*> *cidWidths;
@property (nonatomic) NSMutableDictionary <NSNumber*,NSString*> *charToUnicode;

@end

@implementation PDFFont {
    CGFloat defaultWidth;
    CharacterEncoding encoding;
}

@synthesize type = _type, name = _name, spaceWidth = _spaceWidth, xHeight = _xHeight, capHeight = _capHeight, leading = _leading, firstChar = _firstChar, lastChar = _lastChar, widths = _widths, fontBBox = _fontBBox, bBoxRect = _bBoxRect, charSet = _charSet, cidWidths = _cidWidths, charToUnicode = _charToUnicode, ascent = _ascent;
CGPDFInteger widthOfCharCode(unsigned char code, void *userInfo, void *renderState);
CGPDFReal fontHeight(void *pdfFont, void *renderState);

- (instancetype)initWithName:(NSString *)name fontDict:(CGPDFDictionaryRef)fontDict {
    
    if (self = [super init]) {
        _name = name;
        _cidWidths = [NSMutableDictionary new];
        _charToUnicode = [NSMutableDictionary new];
        defaultWidth = 1000;
        
        const char *subtype;
        if (CGPDFDictionaryGetName(fontDict, kSubtype, &subtype)) {
            if (strcmp(subtype, "Type0") == 0) {
                _type = PDFFontType0;
                
                CGPDFArrayRef DescendantFonts;
                if (CGPDFDictionaryGetArray(fontDict, kDescendantFonts, &DescendantFonts)) {
                    [self handleDescendantFonts:DescendantFonts];
                }
            } else if (strcmp(subtype, "Type1") == 0) {
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
                
                for (NSNumber *code in mapper.map.allKeys) {
                    [_charToUnicode setObject:mapper.map[code] forKey:code];
                }
            }
        }
        
        
        // try get encoding if no mapper
        CGPDFDictionaryRef encodingDict;
        if (CGPDFDictionaryGetDictionary(fontDict, kEncodingKey, &encodingDict)) {
            
            NSDictionary *standartCirillicGlifs = [ToUnicodeMapper standardCyrillicGlyphNames];
            
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

                        NSString *key = [NSString stringWithFormat:@"%s", glif];

                        _charToUnicode[@(curDifIndex)] = standartCirillicGlifs[key];
                        curDifIndex++;
                    }
                }
            }

        }
        
        CGPDFDictionaryRef fontDecriptor;
        if (CGPDFDictionaryGetDictionary(fontDict, kFontDescriptorKey, &fontDecriptor)) {
            // try get Font File stream
            CGPDFObjectRef FontFile;
            if (CGPDFDictionaryGetObject(fontDecriptor, kFontFile3, &FontFile)) {
                
                CGPDFStreamRef FontFileStream;
                if (CGPDFObjectGetValue(toUnicodeObj, kCGPDFObjectTypeStream, &FontFileStream)) {
                    
                    CFDataRef dataRef = CGPDFStreamCopyData(FontFileStream, NULL);
                    NSData *data = (__bridge NSData*)dataRef;
                    ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];

                    for (NSNumber *code in mapper.map.allKeys) {
                        [_charToUnicode setObject:mapper.map[code] forKey:code];
                    }
//                    NSLog(@"FontFile stream: %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
                }
            }
            
            /* for future use
            CGPDFReal XHeight;
            if (CGPDFDictionaryGetNumber(fontDecriptor, kXHeight, &XHeight)) {
                NSLog(@"XHeight %f", XHeight);
            }
            CGPDFReal Leading;
            if (CGPDFDictionaryGetNumber(fontDecriptor, kLeading, &Leading)) {
                NSLog(@"Leading %f", Leading);
            } */
            CGPDFReal Ascent;
            if (CGPDFDictionaryGetNumber(fontDecriptor, kAscent, &Ascent)) {
                _ascent = Ascent;
            }
            CGPDFReal CapHeight;
            if (CGPDFDictionaryGetNumber(fontDecriptor, kCapHeight, &CapHeight)) {
                _capHeight = CapHeight;
            }
            CGPDFArrayRef FontBBox;
            if (CGPDFDictionaryGetArray(fontDecriptor, kFontBBox, &FontBBox)) {
                size_t count = CGPDFArrayGetCount(FontBBox);

                _fontBBox.size = count;
                _fontBBox.values = malloc(sizeof(CGPDFInteger)*count);
                for (size_t i = 0; i < count; i++) {
                    CGPDFInteger val;
                    CGPDFArrayGetInteger(FontBBox, i, &val);
                    _fontBBox.values[i] = val;
                }
            }

            /* for future use
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
            _firstChar = FirstChar;
        }
        CGPDFInteger LastChar;
        if (CGPDFDictionaryGetInteger(fontDict, kLastChar, &LastChar)) {
            _lastChar = LastChar;
        }
        
        
        CGPDFArrayRef Widths;
        if (CGPDFDictionaryGetArray(fontDict, kWidths, &Widths)) {
            size_t count = CGPDFArrayGetCount(Widths);
            _widths.size = count;
            _widths.values = malloc(sizeof(CGPDFInteger)*count);
            for (size_t i = 0; i < count; i++) {
                CGPDFInteger val;
                CGPDFArrayGetInteger(Widths, i, &val);
                _widths.values[i] = val;
            }
        }
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

- (void) handleDescendantFonts:(CGPDFArrayRef)descendantFonts {
    
    size_t count = CGPDFArrayGetCount(descendantFonts);
    
    for (size_t i = 0; i < count; i++) {
        CGPDFObjectRef obj;
        CGPDFArrayGetObject(descendantFonts, i, &obj);

        if (CGPDFObjectGetType(obj) == kCGPDFObjectTypeDictionary) {
            CGPDFDictionaryRef fontDict;
            CGPDFObjectGetValue(obj, kCGPDFObjectTypeDictionary, &fontDict);
            
            CGPDFDictionaryRef CIDSystemInfo;
            if (CGPDFDictionaryGetDictionary(fontDict, kCIDSystemInfo, &CIDSystemInfo)) {

            }
            
            // try get toUnicode map
            CGPDFStreamRef toUnicodeStream;
            if (CGPDFDictionaryGetStream(fontDict, kToUnicodeKey, &toUnicodeStream)) {
                
                CFDataRef dataRef = CGPDFStreamCopyData(toUnicodeStream, NULL);
                NSData *data = (__bridge NSData*)dataRef;
                ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
                
                for (NSNumber *code in mapper.map.allKeys) {
                    [_charToUnicode setObject:mapper.map[code] forKey:code];
                }
            }
            
            // try get chars widths
            CGPDFArrayRef widths;
            if (CGPDFDictionaryGetArray(fontDict, kW, &widths)) {
                [self setWidthsWithArray:widths];
            }
            // default width
            CGPDFInteger defaultWidthValue;
            if (CGPDFDictionaryGetInteger(fontDict, kDW, &defaultWidthValue)) {
                defaultWidth = defaultWidthValue;
            }
            
            CGPDFDictionaryRef fontDecriptor;
            if (CGPDFDictionaryGetDictionary(fontDict, kFontDescriptorKey, &fontDecriptor)) {
                
                // try get Font File stream
                CGPDFObjectRef FontFile;
                if (CGPDFDictionaryGetObject(fontDecriptor, kFontFile3, &FontFile)) {
                    
                    CGPDFStreamRef FontFileStream;
                    if (CGPDFObjectGetValue(FontFile, kCGPDFObjectTypeStream, &FontFileStream)) {
                        
                        CFDataRef dataRef = CGPDFStreamCopyData(FontFileStream, NULL);
                        NSData *data = (__bridge NSData*)dataRef;
                        ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
                        
                        NSLog(@"FontFile stream: %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
                        if (data.length > 0 && mapper == nil) {
                            NSLog(@"Error decode FontFile3 stream!");
                        }
                    }
                }
    
            }

        }
    }
}

- (void)setWidthsWithArray:(CGPDFArrayRef)widthsArray
{
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
                    [_cidWidths setObject:val forKey:key];
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


#pragma mark - Public

- (void)decodePDFString:(CGPDFStringRef)pdfString renderingState:(RenderingState*)renderingState callback:(void(^)(NSString * character, CGSize size))callback {
    
    const unsigned char * characterCodes = CGPDFStringGetBytePtr(pdfString);
    size_t count = CGPDFStringGetLength(pdfString);

    for (int i = 0; i < count; i++) {
        
        const unsigned char code = characterCodes[i];
        if (code == 0) continue;

        const uint16_t code2 = characterCodes[1] + (characterCodes[0] << 8);  // 16 byte code

        NSString *letter = _charToUnicode[@(code)];
        CGPDFReal width = widthOfCharCode(code, (__bridge void *)(self), (__bridge void *)(renderingState));
        CGPDFReal height = fontHeight((__bridge void *)(self), (__bridge void *)(renderingState));
        
        if (letter) {
            callback(letter, CGSizeMake(width, height));
            
        } else if (count == 2) {
            
            letter = _charToUnicode[@(code2)];
            if (letter) {
                callback(letter, CGSizeMake(width, height));
                return;
            }
        } else {
            
            if (code == 32) {
                callback(@" ", CGSizeMake(width, width));
            } else {
                letter = [NSString stringWithFormat:@"%c", characterCodes[i]];
                NSLog(@"WARNING CODE %d - '%@'", code, letter);
                callback(letter, CGSizeMake(width, height));
            }
        }
    }
    
}

CGPDFInteger widthOfCharCode(unsigned char code, void *userInfo, void *renderState) {
    PDFFont *font = (__bridge PDFFont *)(userInfo);
    RenderingState *renderingState = (__bridge RenderingState *)(renderState);
    
    size_t countCodes = font.widths.size;

    size_t charIndex = code - font.firstChar;
    if (countCodes > charIndex) {
        CGPDFInteger w0 = font.widths.values[charIndex];
        
        /* Right way parsing text positiong after drawing glif
         tx = ((w0 - (Tj/1000))*Tfs + Tc + Tw)*Th
         ty = (w1 -(Tj/1000))*Tfs + Tc + Tw
         
         where:
         w0 and w1 are the glyph’s horizontal and vertical displacements
         Tj is a position adjustment specified by a number in a TJ array, if any
         Tfs and Th are the current text font size and horizontal scaling parameters in the graphics state
         Tc and Tw are the current character and word spacing parameters in the graphics state, if applicable
         */
        
        CGPDFReal Tfs = renderingState.fontSize;
        CGPDFReal Tc = renderingState.characterSpacing;
        
        CGPDFReal Tw = 0.0;
        if (code == 32) {
            Tw = renderingState.wordSpacing; // Word spacing works the same way as character spacing, but applies only to the space character, code 32.
        }
        CGPDFReal Th = renderingState.horizontalScaling / 100.0;
        CGPDFReal width = (w0*Tfs + Tc + Tw)*Th;
        
        
//        NSString *letter = font.mapper.map[@(code)];
//        if (!letter) {
//            letter = font.glifNameByCode[@(code)];
//            NSDictionary *cirillicMap = [ToUnicodeMapper standardCyrillicGlyphNames];
//            letter = cirillicMap[letter];
//        }
        return width;
        
    } else if (code == 0) {
        return 0;
    } else {
        NSNumber *width = [font.cidWidths objectForKey:[NSNumber numberWithInteger:code]];
        if (width == nil) {
            NSLog(@"ERROR: [%@] get char width index: %zu, charCode %d widthsLength %zu", font.name, charIndex, code, countCodes);
            return font->defaultWidth;
        }
        
        return width.floatValue;
    }
}

CGPDFReal fontHeight(void *pdfFont, void *renderState) {
    PDFFont *font = (__bridge PDFFont *)(pdfFont);
    RenderingState *renderingState = (__bridge RenderingState *)(renderState);
    
    CGPDFReal Tfs = renderingState.fontSize;
    CGPDFReal scale = 1; // renderingState.textMatrix.d ?: 0;
    CGPDFReal Th = renderingState.horizontalScaling / 100.0;
    CGPDFReal ascent = font.ascent ?: 10000;

    CGPDFReal result = (ascent / 1000.0 * scale * Tfs) * Th;

    return result;
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
- (void)setWidthsFrom:(CGPDFInteger)cid to:(CGPDFInteger)maxCid width:(CGPDFInteger)width {
    while (cid <= maxCid) {
        [self.cidWidths setObject:[NSNumber numberWithInt:(int)width] forKey:[NSNumber numberWithInt:(int)cid++]];
    }
}

- (void)setWidthsWithBase:(CGPDFInteger)base array:(CGPDFArrayRef)array
{
    NSInteger count = CGPDFArrayGetCount(array);
    CGPDFInteger width;
    
    for (int index = 0; index < count ; index++)
    {
        if (CGPDFArrayGetInteger(array, index, &width))
        {
            [self.cidWidths setObject:[NSNumber numberWithInt:(int)width] forKey:[NSNumber numberWithInt:(int)base + index]];
        }
    }
}

#pragma mark - 
- (NSUInteger)hash {
    return [_name hash];
}

- (BOOL)isEqual:(id)object {
    return [_name isEqual:object];
}

@end
