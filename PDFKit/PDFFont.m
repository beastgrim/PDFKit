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
const char *kMissingWidth = "MissingWidth";
const char *kFirstChar = "FirstChar"; // (Required except for the standard 14 fonts) The first character code defined in the font’s Widths array.
const char *kLastChar = "LastChar"; // (Required except for the standard 14 fonts) The last character code defined in the font’s Widths array.

const char *kW = "W";   // A description of the widths for the glyphs in the CIDFont. The array’s elements have a variable format that can specify individual widths for consecutive CIDs or one width for a range of CIDs (see “Glyph Metrics in CIDFonts” on page 340). Default value: none (the DW value is used for all glyphs).
const char *kDW = "DW"; // The default width for glyphs in the CIDFont (see “Glyph Met- rics in CIDFonts” on page 340). Default value: 1000.
const char *kAvgWidth = "AvgWidth";
const char *kFontFile3 = "FontFile3";
const char *kFontFile2 = "FontFile2";
const char *kDescendantFonts = "DescendantFonts"; // A CID-keyed font, then, is the combination of a CMap with one or more CIDFonts, simple fonts, or composite fonts containing glyph descriptions. In PDF, a CID-keyed font is represented as a Type 0 font. It contains an Encoding entry whose value is a CMap dictionary, and its DescendantFonts array refer- ences the CIDFont or font dictionaries with which the CMap has been combined.
const char *kCIDSystemInfo = "CIDSystemInfo"; // CIDSystemInfo entry is a dictionary that specifies the CIDFont’s character collection. Note that the CIDFont need not contain glyph descriptions for all the CIDs in a collection; it can contain a subset. In a CMap, the CIDSystemInfo entry is either a single dictionary or an array of dictionaries, depending on whether it associates codes with a single character collection or with multiple character collections; see Section 5.6.4, “CMaps.”
const char *kFlags = "Flags";   // The value of the Flags entry in a font descriptor is an unsigned 32-bit integer containing flags specifying various characteristics of the font. Bit positions within the flag word are numbered from 1 (low-order) to 32 (high-order).
/* Flags description
 1  FixedPitch  All glyphs have the same width (as opposed to proportional or variable-pitch fonts, which have different widths).
 2  Serif       Glyphs have serifs, which are short strokes drawn at an angle on the top and bottom of glyph stems (as opposed to sans serif fonts, which do not).
 3  Symbolic    Font contains characters outside the Adobe standard Latin character set. This flag and the Nonsymbolic flag cannot both be set or both be clear (see below).
 4  Script      Glyphs resemble cursive handwriting.
 6  Nonsymbolic Font uses the Adobe standard Latin character set or a subset of it (see below).
 7  Italic      Glyphs have dominant vertical strokes that are slanted.
 17 AllCap      Font contains no lowercase letters; typically used for display purposes such as
 18 SmallCap    Font contains both uppercase and lowercase letters. The uppercase letters are similar to ones in the regular version of the same typeface family. The glyphs for the lowercase letters have the same shapes as the corresponding uppercase letters, but they are sized and their proportions adjusted so that they have the same size and stroke weight as lowercase glyphs in the same typeface family.
 19 ForceBold
 */

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
    CGFloat avgWidth;
    CGPDFInteger _missingWidth;
    CGPDFInteger _flags;
    CharacterEncoding encoding;
    BOOL useDecode;
    BOOL twoBytesDecoding;
    NSString *_encodingName;
}

@synthesize type = _type, name = _name, spaceWidth = _spaceWidth, xHeight = _xHeight, capHeight = _capHeight, leading = _leading, firstChar = _firstChar, lastChar = _lastChar, widths = _widths, fontBBox = _fontBBox, bBoxRect = _bBoxRect, charSet = _charSet, cidWidths = _cidWidths, charToUnicode = _charToUnicode, ascent = _ascent;
CGPDFReal widthOfCharCode(uint16_t code, void *userInfo, void *renderState);
CGPDFReal xOffsetAfterDrawingCode(uint16_t code, CGPDFReal Tj, void *userInfo, void *renderState);
CGPDFReal fontHeight(void *pdfFont, void *renderState);


#pragma mark -

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
            
            CGPDFObjectRef baseEncodingObj;
            if (CGPDFDictionaryGetObject(encodingDict, kBaseEncodingKey, &baseEncodingObj)) {
                
                char * baseEncoding;
                CGPDFObjectGetValue(baseEncodingObj, kCGPDFObjectTypeName, &baseEncoding);
                
                [self setEncodingNamed:[NSString stringWithFormat:@"%s", baseEncoding]];
            }
            
            CGPDFArrayRef differences;
            if (CGPDFDictionaryGetArray(encodingDict, kDifferencesKey, &differences)) {
    
                [self decodeDifferences:differences];
            }
        }
        const char * encodingName;
        if (CGPDFDictionaryGetName(fontDict, kEncodingKey, &encodingName)) {
            _encodingName = [NSString stringWithFormat:@"%s", encodingName];
        }
        
        CGPDFDictionaryRef fontDecriptor;
        if (CGPDFDictionaryGetDictionary(fontDict, kFontDescriptorKey, &fontDecriptor)) {
            
            CGPDFInteger missingWidth;
            if (CGPDFDictionaryGetInteger(fontDecriptor, kMissingWidth, &missingWidth)) {
                _missingWidth = missingWidth;
            }
            CGPDFInteger flags;
            if (CGPDFDictionaryGetInteger(fontDecriptor, kFlags, &flags)) {
                _flags = flags;
            }
            // try get Font File stream
            CGPDFObjectRef FontFile2;
            if (CGPDFDictionaryGetObject(fontDecriptor, kFontFile2, &FontFile2)) {
                
                CGPDFStreamRef FontFileStream;
                if (CGPDFObjectGetValue(FontFile2, kCGPDFObjectTypeStream, &FontFileStream)) {
                    
                    CFDataRef dataRef = CGPDFStreamCopyData(FontFileStream, NULL);
                    NSData *data = (__bridge NSData*)dataRef;
                    ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
                    
                    for (NSNumber *code in mapper.map.allKeys) {
                        [_charToUnicode setObject:mapper.map[code] forKey:code];
                    }
//                    NSLog(@"FontFile stream: %@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
                }
            }
            CGPDFObjectRef FontFile3;
            if (CGPDFDictionaryGetObject(fontDecriptor, kFontFile3, &FontFile3)) {
                
                CGPDFStreamRef FontFileStream;
                if (CGPDFObjectGetValue(FontFile3, kCGPDFObjectTypeStream, &FontFileStream)) {
                    
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
    //*
    printf("Init font %s toUnicodeMap %ld cidWidths: %s\n", name.UTF8String, (unsigned long)_charToUnicode.count, self.cidWidths.description.UTF8String);
    printf("Widths: \n");
    for (int i = 0; i < _widths.size; i++) {
        NSString *letter = _charToUnicode[@(i)];
        printf("\t[%d]\t'%s'\t%ld\n", i, letter.UTF8String, _widths.values[i]);
    } //*/

    useDecode = _charToUnicode.count > 0;
    
    // When the current font is a Type 0 font whose Encoding entry is Identity−H or Identity−V, the string to be shown is inter- preted as pairs of bytes representing CIDs, high-order byte first.
    twoBytesDecoding = self.type == PDFFontType0 && [_encodingName hasPrefix:@"Identity"];
    
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

- (void) decodeDifferences:(CGPDFArrayRef)array {
    NSDictionary *standartCirillicGlifs = [ToUnicodeMapper standardCyrillicGlyphNames];

    NSInteger curDifIndex = 0;
    
    for (int i = 0; i < CGPDFArrayGetCount(array); i++) {
        
        CGPDFObjectRef obj;
        CGPDFArrayGetObject(array, i, &obj);
        
        CGPDFObjectType type = CGPDFObjectGetType(obj);
        
        if (type == kCGPDFObjectTypeInteger) {
            CGPDFInteger val;
            CGPDFObjectGetValue(obj, kCGPDFObjectTypeInteger, &val);
            curDifIndex = val;
            
        } else if (type == kCGPDFObjectTypeName) {
            char * glif;
            CGPDFObjectGetValue(obj, kCGPDFObjectTypeName, &glif);
            
            NSString *key = [NSString stringWithFormat:@"%s", glif];
            
            if ([key hasPrefix:@"uni"]) {
                NSString * codeStr = [key substringFromIndex:3];
                unichar code = strtol([codeStr UTF8String], nil, 16);
                _charToUnicode[@(curDifIndex)] = [NSString stringWithFormat:@"%C", code];
            } else if (key.length == 1) {
                _charToUnicode[@(curDifIndex)] = key;
            } else {
                _charToUnicode[@(curDifIndex)] = standartCirillicGlifs[key];
            }
            
            curDifIndex++;
        }
    }
}


#pragma mark Encoding
- (void)setEncodingNamed:(NSString *)encodingName {
    
    if ([encodingName isEqualToString:@"MacRomanEncoding"]) {
        encoding = MacRomanEncoding;
        
    } else if ([encodingName isEqualToString:@"WinAnsiEncoding"]) {
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
                
                // avarage width
                CGPDFInteger avgWidthValue;
                if (CGPDFDictionaryGetInteger(fontDecriptor, kAvgWidth, &avgWidthValue)) {
                    avgWidth = avgWidthValue;
                }
                
                // try get Font File stream
                CGPDFObjectRef FontFile;
                if (CGPDFDictionaryGetObject(fontDecriptor, kFontFile3, &FontFile)) {
                    
                    CGPDFStreamRef FontFileStream;
                    if (CGPDFObjectGetValue(FontFile, kCGPDFObjectTypeStream, &FontFileStream)) {
                        
                        CFDataRef dataRef = CGPDFStreamCopyData(FontFileStream, NULL);
                        NSData *data = (__bridge NSData*)dataRef;
                        ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
                        
                        for (NSNumber *code in mapper.map.allKeys) {
                            [_charToUnicode setObject:mapper.map[code] forKey:code];
                        }
                        NSLog(@"FontFile3 stream(%ld bytes): %@", (unsigned long)data.length, [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
                    }
                    
                } else if (CGPDFDictionaryGetObject(fontDecriptor, kFontFile2, &FontFile)) {
                    
                    CGPDFStreamRef FontFileStream;
                    if (CGPDFObjectGetValue(FontFile, kCGPDFObjectTypeStream, &FontFileStream)) {
                        
                        CFDataRef dataRef = CGPDFStreamCopyData(FontFileStream, NULL);
                        NSData *data = (__bridge NSData*)dataRef;
                        ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
                        
                        for (NSNumber *code in mapper.map.allKeys) {
                            [_charToUnicode setObject:mapper.map[code] forKey:code];
                        }
                        NSLog(@"FontFile2 stream(%ld bytes): %@", (unsigned long)data.length, [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
                    }
                }
    
            }

        }
    }
}

- (void)setWidthsWithArray:(CGPDFArrayRef)widthsArray
{
    /*
        C [w1 w2 ... wn]
        Cfirst Clast w
     In the first format, c is an integer specifying a starting CID value; it is followed by an array of n numbers that specify the widths for n consecutive CIDs, starting with c. The second format defines the same width, w, for all CIDs in the range
     cfirst to clast .
     
     The following is an example of a W entry:
     /W [   120 [400 325 500]
            7080 8032 1000
        ]
     In this example, the glyphs for the characters having CIDs 120, 121, and 122 are 400, 325, and 500 units wide, respectively. CIDs in the range 7080 through 8032 all have a width of 1000 units.
    */
    NSUInteger length = CGPDFArrayGetCount(widthsArray);
    int idx = 0;
    
    while (idx < length)
    {
        CGPDFInteger baseCid = 0;
        if (!CGPDFArrayGetInteger(widthsArray, idx++, &baseCid)) {
            NSLog(@"ERROR: parsing Widths of CID font. Current idx:%uld/%lud", idx, length);
            break;
        }
        
        CGPDFObjectRef integerOrArray = nil;
        CGPDFArrayGetObject(widthsArray, idx++, &integerOrArray);
        CGPDFObjectType type = CGPDFObjectGetType(integerOrArray);
        
        if (type == kCGPDFObjectTypeInteger)
        {
            // [ first last width ]             cfirst clast w
            CGPDFInteger maxCid;
            CGPDFInteger glyphWidth;
            CGPDFObjectGetValue(integerOrArray, kCGPDFObjectTypeInteger, &maxCid);
            CGPDFArrayGetInteger(widthsArray, idx++, &glyphWidth);
            [self setWidthsFrom:baseCid to:maxCid width:glyphWidth];
        }
        else if (type == kCGPDFObjectTypeArray)
        {
            // [ first list-of-widths ]         c [w1 w2 ... wn]
            CGPDFArrayRef glyphWidths;
            CGPDFObjectGetValue(integerOrArray, kCGPDFObjectTypeArray, &glyphWidths);
            [self setWidthsWithBase:baseCid array:glyphWidths];
        } else {
            NSLog(@"ERROR: unexpected type occured while parse the Width array");
        }
    }
}


#pragma mark - Public

- (void)decodePDFString:(CGPDFStringRef)pdfString renderingState:(RenderingState *)renderingState callback:(void (^)(NSString *, CGSize))callback {
    [self decodePDFString:pdfString withTj:0 renderingState:renderingState callback:callback];
}
- (void)decodePDFString:(CGPDFStringRef)pdfString withTj:(CGPDFReal)Tj renderingState:(RenderingState*)renderingState callback:(void(^)(NSString * character, CGSize glifSize))callback {
    [self decodePDFString:pdfString withTj:0 renderingState:renderingState callback:callback stringWidthCallback:nil];
}

- (void)decodePDFString:(CGPDFStringRef)pdfString withTj:(CGPDFReal)Tj renderingState:(RenderingState*)renderingState callback:(void(^)(NSString * character, CGSize size))callback stringWidthCallback:(void(^)(CGFloat width))stringWithCallback {
    
    const unsigned char * characterCodes = CGPDFStringGetBytePtr(pdfString);
    size_t count = CGPDFStringGetLength(pdfString);
    CGPDFReal totalStringWidth = 0.0;

    if (twoBytesDecoding) {
        
        if (count%2 == 0) {

            for (int i = 0; i < count; i++) {

                const uint16_t code = characterCodes[i+1] + (characterCodes[i] << 8);  // 16 byte code
                CGPDFReal width = widthOfCharCode(code, (__bridge void *)(self), (__bridge void *)(renderingState));
                CGPDFReal height = fontHeight((__bridge void *)(self), (__bridge void *)(renderingState));
                
                CGPDFReal widthWithSpace = xOffsetAfterDrawingCode(code, Tj, (__bridge void *)(self), (__bridge void *)(renderingState));
                totalStringWidth += widthWithSpace;
                
                // The glyph widths are measured in units in which 1000 units corresponds to 1 unit in text space.
                CGSize size = CGSizeMake(width/1000.0, height/1000.0);
                
                
                if (useDecode) {
                    NSString *letter = _charToUnicode[@(code)];

                    if (letter) {
                        callback(letter, size);
                        ++i; continue;
                        
                    } else {    // english letters
                        
                        letter = [NSString stringWithFormat:@"%c", code];
                        NSLog(@"WARNING CODE [%@] %d - '%@'", self.name, code, letter);
                        callback(letter, size);
                    }
                    
                } else {
                    NSString *letter = [NSString stringWithFormat:@"%c", code];
                    callback(letter, size);
                }
            }
            
            if (stringWithCallback) {
                // The glyph widths are measured in units in which 1000 units corresponds to 1 unit in text space.
                stringWithCallback(totalStringWidth/1000.0);
            }
        } else {
            NSLog(@"ERROR: pdfString uses 2 bytes decoding but count id not even");
            return;
        }
        
    } else {
        
        for (int i = 0; i < count; i++) {
            
            const unsigned char code = characterCodes[i];
            if (code == 0) continue;
            
            
            CGPDFReal width = widthOfCharCode(code, (__bridge void *)(self), (__bridge void *)(renderingState));
            CGPDFReal height = fontHeight((__bridge void *)(self), (__bridge void *)(renderingState));
            
            CGPDFReal widthWithSpace = xOffsetAfterDrawingCode(code, Tj, (__bridge void *)(self), (__bridge void *)(renderingState));
            totalStringWidth += widthWithSpace;
            
            // The glyph widths are measured in units in which 1000 units corresponds to 1 unit in text space.
            CGSize size = CGSizeMake(width/1000.0, height/1000.0);
            
            if (useDecode) {
                NSString *letter = _charToUnicode[@(code)];
                
                if (letter) {
                    callback(letter, size);
                    
                } else {
                    const uint16_t code2 = characterCodes[i+1] + (characterCodes[i] << 8);  // 16 byte code
                    
                    if (i+1 < count && _charToUnicode[@(code2)]) {
                        letter = _charToUnicode[@(code2)];
                        callback(letter, size);
                        ++i; continue;
                        
                    } else {    // maybe english letters
                        
                        letter = [NSString stringWithFormat:@"%c", code];
                        NSLog(@"WARNING CODE [%@] %d - '%@'", self.name, code, letter);
                        callback(letter, size);
                    }
                }
                
            } else {
                NSString *letter = [NSString stringWithFormat:@"%c", code];
                callback(letter, size);
            }
            
        }
        
        if (stringWithCallback) {
            // The glyph widths are measured in units in which 1000 units corresponds to 1 unit in text space.
            stringWithCallback(totalStringWidth/1000.0);
        }
    }

}

CGPDFReal xOffsetAfterDrawingCode(uint16_t code, CGPDFReal Tj, void *userInfo, void *renderState) {
    PDFFont *font = (__bridge PDFFont *)(userInfo);
    RenderingState *renderingState = (__bridge RenderingState *)(renderState);
    
    size_t countCodes = font.widths.size;
    uint16_t charIndex = code - font.firstChar;
    CGPDFInteger w0 = 0;
    
    if ((code > font.lastChar || code < font.firstChar) && font->_missingWidth > 0) {
        // For character codes outside the range FirstChar to LastChar, the value of MissingWidth from the FontDescriptor entry for this font is used.
        w0 = font->_missingWidth;
    } else if (countCodes > charIndex) {
        w0 = font.widths.values[charIndex];
    } else {
        NSNumber *width = [font.cidWidths objectForKey:[NSNumber numberWithInteger:code]];
        if (width) {
            w0 = width.floatValue;
        } else {
            NSString *letter = font.charToUnicode[@(code)];
            NSLog(@"ERROR: [%@] get char width index: %zu, charCode %d:%@ widthsLength %zu", font.name, charIndex, code, letter, countCodes);
            w0 = font->defaultWidth;
        }
    }
    
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
    CGPDFReal Th = renderingState.horizontalScaling / 100.0;
    
    if (code == 32) {
        Tw = renderingState.wordSpacing; // Word spacing works the same way as character spacing, but applies only to the space character, code 32.
    } else if (w0 == 0) {
        NSLog(@"Warning: char width code %d is zero", code);
    }
    
    CGPDFReal tx = ((w0 - (Tj/1000.0))*Tfs + Tc + Tw)*Th;
    //    CGPDFReal width = (w0*Tfs + Tc + Tw)*Th;
    
    return tx;
}

CGPDFReal widthOfCharCode(uint16_t code, void *userInfo, void *renderState) {
    PDFFont *font = (__bridge PDFFont *)(userInfo);
    RenderingState *renderingState = (__bridge RenderingState *)(renderState);
    
    size_t countCodes = font.widths.size;
    uint16_t charIndex = code - font.firstChar;
    CGPDFInteger w0 = 0;
    
    if ((code > font.lastChar || code < font.firstChar) && font->_missingWidth > 0) {
        // For character codes outside the range FirstChar to LastChar, the value of MissingWidth from the FontDescriptor entry for this font is used.
        w0 = font->_missingWidth;
    } else if (countCodes > charIndex) {
        w0 = font.widths.values[charIndex];
    } else {
        NSNumber *width = [font.cidWidths objectForKey:[NSNumber numberWithInteger:code]];
        if (width) {
            w0 = width.floatValue;
        } else {
            NSString *letter = font.charToUnicode[@(code)];
            NSLog(@"ERROR: [%@] get char width index: %zu, charCode %d:%@ widthsLength %zu", font.name, charIndex, code, letter, countCodes);
            w0 = font->defaultWidth;
        }
    }
    

    
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
    CGPDFReal Tc = 0; // we will add char spacing when calculate TJ // renderingState.characterSpacing;
    CGPDFReal Tw = 0.0;
    CGPDFReal Th = renderingState.horizontalScaling / 100.0;
    CGPDFReal Tj = 0.0; // we want to know only glif width
    
    if (code == 32) {
        Tw = renderingState.wordSpacing; // Word spacing works the same way as character spacing, but applies only to the space character, code 32.
    } else if (w0 == 0) {
        NSLog(@"Warning: char width code %d is zero", code);
    }
    
    CGPDFReal tx = ((w0 - (Tj/1000.0))*Tfs + Tc + Tw)*Th;
//    CGPDFReal width = (w0*Tfs + Tc + Tw)*Th;
    
    return tx;
}

CGPDFReal fontHeight(void *pdfFont, void *renderState) {
    PDFFont *font = (__bridge PDFFont *)(pdfFont);
    RenderingState *renderingState = (__bridge RenderingState *)(renderState);
    CGAffineTransform tm = renderingState.textMatrix;

    CGPDFReal Tfs = renderingState.fontSize;
    CGPDFReal scale = sqrt(tm.b * tm.b + tm.d * tm.d);
    CGPDFReal Th = renderingState.horizontalScaling / 100.0;
    CGPDFReal ascent = MAX(font.xHeight, MAX(font.ascent, font.capHeight)) ?: 1000;
    
    CGAffineTransform t = renderingState.ctm;
    CGPDFReal globalYScale = sqrt(t.b * t.b + t.d * t.d);
    
    CGPDFReal result = (ascent * scale * Tfs) * Th * globalYScale;

    return ascent*Tfs;
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
        [self.cidWidths setObject:[NSNumber numberWithInteger:width] forKey:[NSNumber numberWithInteger:cid]];
        cid++;
    }
}

- (void)setWidthsWithBase:(CGPDFInteger)base array:(CGPDFArrayRef)array
{
    NSInteger count = CGPDFArrayGetCount(array);
    CGPDFInteger width;
    
    for (int index = 0; index < count ; index++)
    {
        if (CGPDFArrayGetInteger(array, index, &width)) {
            [self.cidWidths setObject:[NSNumber numberWithInteger:width] forKey:[NSNumber numberWithInteger:base + index]];
        } else {
            NSLog(@"ERROR: failed when get width of glif");
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
