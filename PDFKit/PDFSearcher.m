//
//  PDFReader.m
//  EO2
//
//  Created by FLS on 15/06/16.
//  Copyright © 2016 Luxoft. All rights reserved.
//

#import "PDFSearcher.h"
#import "PDFKit-Swift.h"
#import "PDFFont.h"
#import "RenderingState.h"


void arrayCallback(CGPDFScannerRef inScanner, void *userInfo);
void stringCallback(CGPDFScannerRef inScanner, void *userInfo);
void fontInfoCallback(CGPDFScannerRef inScanner, void *userInfo);
void endTextCallback(CGPDFScannerRef inScanner, void *userInfo);

void textPositionCallback(CGPDFScannerRef inScanner, void *userInfo);
void textMatrixCallback(CGPDFScannerRef inScanner, void *userInfo);

CGPDFStringRef getString(CGPDFScannerRef pdfScanner);
CGPDFArrayRef getArray(CGPDFScannerRef pdfScanner);
CGPDFObjectRef getObject(CGPDFArrayRef pdfArray, int index);
CGPDFStringRef getStringValue(CGPDFObjectRef pdfObject);
float getNumericalValue(CGPDFObjectRef pdfObject, CGPDFObjectType type);

void didScanFont(const char *key, CGPDFObjectRef object, void *collection);
void printPDFObject(CGPDFObjectRef pdfObject);

@interface PDFSearcher ()

@property (nonatomic, retain) NSMutableString *fontInfo;
@property (nonatomic, retain) NSMutableSet <NSString*> *fontNames;
@property (nonatomic, retain) NSMutableDictionary <NSString*, ToUnicodeMapper*> *mapperByFontName;
@property (nonatomic, retain) NSMutableDictionary <NSString*, PDFFont*> *fontByFontName;

@property (nonatomic, readonly) RenderingState *renderingState;
@property (nonatomic, retain) NSMutableArray <RenderingState*> *renderingStateStack;
@end


@implementation PDFSearcher
{
    CGPDFOperatorTableRef table;
    NSMutableArray *fontDataArray;
    NSData *CIDToUnicodeData;
    NSString *currentFontName;
    CGFloat currentFontSize;
    NSMutableArray *positioningByLocation;
}

@synthesize fontInfo;

- (instancetype) init {
    if (self = [super init]) {
        fontDataArray = [NSMutableArray new];
        table = CGPDFOperatorTableCreate();
        fontInfo = [NSMutableString stringWithUTF8String:"FONT INFO:\n"];
        _unicodeContent = [NSMutableString stringWithUTF8String:"UNICODE CONTENT:\n"];
        _fontNames = [NSMutableSet new];
        _mapperByFontName = [NSMutableDictionary new];
        _fontByFontName = [NSMutableDictionary new];
        _renderingStateStack = [NSMutableArray new];
        [_renderingStateStack addObject:[RenderingState new]];
        
        CGPDFOperatorTableSetCallback(table, "TJ", arrayCallback);      // when pdf print strings and spaces
        CGPDFOperatorTableSetCallback(table, "Tj", stringCallback);     // when pdf print strings
        // Text position
        CGPDFOperatorTableSetCallback(table, "Tm", textMatrixCallback); // handle text position
        CGPDFOperatorTableSetCallback(table, "Td", newLineWithLeading); // handle string position
        CGPDFOperatorTableSetCallback(table, "TD", newLineSetLeading);  // handle string position
        CGPDFOperatorTableSetCallback(table, "T*", newLine);            // handle string position
        CGPDFOperatorTableSetCallback(table, "BT", newParagraph);       // PDF start print text
        CGPDFOperatorTableSetCallback(table, "ET", endTextCallback);    // PDF end print text
        // Font
        CGPDFOperatorTableSetCallback(table, "Tf", fontInfoCallback);   // handle switches to new font
        
        // Graphics state operators
        CGPDFOperatorTableSetCallback(table, "cm", applyTransformation);
        CGPDFOperatorTableSetCallback(table, "q", pushRenderingState);
        CGPDFOperatorTableSetCallback(table, "Q", popRenderingState);
    }
    return self;
}

- (void)dealloc {
    CGPDFOperatorTableRelease(table);
}


#pragma mark - Public
- (PDFPage*)pageInfoForPDFPage:(CGPDFPageRef)inPage {
    [self fontCollectionWithPage:inPage];
    
    positioningByLocation = [NSMutableArray new];
    
    CGPDFContentStreamRef contentStream = CGPDFContentStreamCreateWithPage(inPage);
    CGPDFScannerRef scanner = CGPDFScannerCreate(contentStream, table, (__bridge void * _Nullable)(self));
    CGPDFScannerScan(scanner);
    CGPDFScannerRelease(scanner);
    CGPDFContentStreamRelease(contentStream);
    
    return [[PDFPage alloc] initWithContent:_unicodeContent textPositions:positioningByLocation];
}

-(BOOL)page:(CGPDFPageRef)inPage containsString:(NSString *)inSearchString;
{
    [self fontCollectionWithPage:inPage];
    
    positioningByLocation = [NSMutableArray new];
    
    CGPDFContentStreamRef contentStream = CGPDFContentStreamCreateWithPage(inPage);
    CGPDFScannerRef scanner = CGPDFScannerCreate(contentStream, table, (__bridge void * _Nullable)(self));
    bool ret = CGPDFScannerScan(scanner);
    CGPDFScannerRelease(scanner);
    CGPDFContentStreamRelease(contentStream);
    
    
//    NSLog(@"%@", fontInfo);
    NSLog(@"%@", _unicodeContent);
    return ret && ([[_unicodeContent uppercaseString]
             rangeOfString:[inSearchString uppercaseString]].location != NSNotFound);
}

- (NSString *)stringWithPDFString:(CGPDFStringRef)pdfString
{
    if (currentFontName == nil) return (NSString *)CFBridgingRelease(CGPDFStringCopyTextString(pdfString));
    
    ToUnicodeMapper *mapper = _mapperByFontName[currentFontName];
    
    if (mapper) {
        // Character codes
        const unsigned char * characterCodes = CGPDFStringGetBytePtr(pdfString);
        int count = CGPDFStringGetLength(pdfString);
        NSMutableString *string = [NSMutableString string];
        uint16_t code2 = characterCodes[1] + (characterCodes[0] << 8);  // 16 byte code
        
        for (int i = 0; i < count; i++) {
            
            char code = characterCodes[i];

            NSString *letter = mapper.map[@(code)];
            if (letter) {
                [string appendFormat:@"%@", letter];
            } else {
                NSString *letter = mapper.map[@(code2)];
                return letter;
            }

//            NSLog(@"Map charCode %d to letter %@", code, letter);
//            void *gid = malloc(2);
//            NSData *charData = [CIDToUnicodeData subdataWithRange:NSMakeRange(code * 2, 2)];
//            [CIDToUnicodeData getBytes:gid range:NSMakeRange(code * 2, 2)];
//            NSLog(@"Char code %d charData %@", code, charData);
//            unichar value = (unichar)gid;
//            [string appendFormat:@"%C", value];
        }
        
        return string;
    }
    
    return (NSString *)CFBridgingRelease(CGPDFStringCopyTextString(pdfString));
}

const char *kTypeKey = "Type";
const char *kFontSubtypeKey = "Subtype";
const char *kBaseFontKey = "BaseFont";
const char *kFontDescriptorKey = "FontDescriptor";
const char *kEncodingKey = "Encoding";
const char *kToUnicodeKey = "ToUnicode";
const char *kFirstCharKey = "FirstChar";
const char *kLastCharKey = "LastChar";
const char *kWidthsKey = "Widths";

const char *kFontKey = "Font";
const char *kBaseEncodingKey = "BaseEncoding";

#pragma mark - Base
- (void) saveTextPositionWithMatrix:(CGAffineTransform)transform {
    CGPoint origin = CGPointMake(transform.tx, transform.ty);
    NSInteger location = _unicodeContent.length;
    TextPosition *lastPos = [positioningByLocation lastObject];

    TextPosition *textPos = [TextPosition new];
    textPos.location = location;
    textPos.origin = origin;
    textPos.fontName = currentFontName;
    textPos.fontSize = CGSizeMake(currentFontSize*transform.a, currentFontSize*transform.d);
    textPos.transform = transform;
    
    if (lastPos && lastPos.location == location) {  // replace last position
        [positioningByLocation replaceObjectAtIndex:positioningByLocation.count-1 withObject:textPos];
    } else {
        [positioningByLocation addObject:textPos];
    }
}

#pragma mark - Fonts
void handleFontDictionary(const char *key, CGPDFObjectRef ob, void *info);
void printPDFKeys(const char *key, CGPDFObjectRef ob, void *info);
void printCGPDFDictionary(const char *key, CGPDFObjectRef ob, void *info);

/* Create a font dictionary given a PDF page */
- (void)fontCollectionWithPage:(CGPDFPageRef)page {
    CGPDFDictionaryRef dict = CGPDFPageGetDictionary(page);
    if (!dict) 	{
        NSLog(@"Scanner: fontCollectionWithPage: page dictionary missing");
        return;
    }
    
    CGPDFDictionaryRef resources;
    if (!CGPDFDictionaryGetDictionary(dict, "Resources", &resources)) {
        NSLog(@"Scanner: fontCollectionWithPage: page dictionary missing Resources dictionary");
        return;
    }
    
    CGPDFDictionaryRef fonts;
    if (!CGPDFDictionaryGetDictionary(resources, "Font", &fonts)) {
        return;
    }
    
    CGPDFDictionaryApplyFunction(fonts, handleFontDictionary, (__bridge void * _Nullable)(self));
}

void printPDFKeys(const char *key, CGPDFObjectRef ob, void *info) {
    NSLog(@"key = %s", key);
}

void handleFontDictionary(const char *key, CGPDFObjectRef ob, void *info) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)info;
    
    if (CGPDFObjectGetType(ob) != kCGPDFObjectTypeDictionary) return;
    
    CGPDFDictionaryRef fontDict;
    if (CGPDFObjectGetValue(ob, kCGPDFObjectTypeDictionary, &fontDict)) {
        //        CGPDFDictionaryApplyFunction(fontDict, didScanFont, info);
    }
    
    NSLog(@"PRINT FONT: %s", key);
    printPDFObject(ob);
    
    NSString *fontName = [NSString stringWithFormat:@"%s", key];
    PDFFont *font = [[PDFFont alloc] initWithName:fontName fontDict:fontDict];
    searcher.fontByFontName[fontName] = font;
    
    CGPDFObjectRef toUnicodeObj;
    if (!CGPDFDictionaryGetObject(fontDict, kToUnicodeKey, &toUnicodeObj)) return;
    
    CGPDFStreamRef toUnicodeStream;
    if (!CGPDFObjectGetValue(toUnicodeObj, kCGPDFObjectTypeStream, &toUnicodeStream)) return;
    
    CFDataRef dataRef = CGPDFStreamCopyData(toUnicodeStream, NULL);
    NSData *data = (__bridge NSData*)dataRef;
    ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
    
    if (mapper) {
        NSLog(@"\n\nDID HANDLE FONT: [%s]\n\nMapData: %@\nMAP: %@", key, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], mapper.map);
        searcher.mapperByFontName[fontName] = mapper;
    }
}

/* Applier function for font dictionaries */
void didScanFont(const char *key, CGPDFObjectRef object, void *collection)
{
    if (CGPDFObjectGetType(object) != kCGPDFObjectTypeDictionary) return;
    CGPDFDictionaryRef fontDict;
    if (!CGPDFObjectGetValue(object, kCGPDFObjectTypeDictionary, &fontDict)) return;
    
    printf("Font: %s\n", key);
    CGPDFDictionaryApplyFunction(fontDict, printPDFKeys, nil);
    
    const char *type = nil;
    CGPDFDictionaryGetName(fontDict, kTypeKey, &type);
    if (!type || strcmp(type, kFontKey) != 0) return;
    const char *subtype = nil;
    CGPDFDictionaryGetName(fontDict, kFontSubtypeKey, &subtype);
    const char *toUnicode = nil;
    CGPDFDictionaryGetName(fontDict, kToUnicodeKey, &subtype);

    const char *encodingName = nil;
    if (!CGPDFDictionaryGetName(fontDict, kEncodingKey, &encodingName))
    {
        CGPDFDictionaryRef encodingDict = nil;
        CGPDFDictionaryGetDictionary(fontDict, kEncodingKey, &encodingDict);
        printf("ENCODING INFO KEYS:\n");
        CGPDFDictionaryApplyFunction(encodingDict, printPDFKeys, nil);
        
        printf("Encoding Name: %s\n", encodingName);
        printf("Type: %s\n", type);
        printf("Subtype: %s\n", subtype);
        printf("ToUnicode: %s\n", toUnicode);

        // TODO: Also get differences from font encoding dictionary
    }
    
}

#pragma mark - PDF protocol

#pragma mark - Text Positioning
void newLine(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    [searcher.renderingState newLine];
    [searcher saveTextPositionWithMatrix:searcher.renderingState.textMatrix];
}

void newLineSetLeading(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    CGPDFReal tx, ty;
    CGPDFScannerPopNumber(inScanner, &ty);
    CGPDFScannerPopNumber(inScanner, &tx);
    [searcher.renderingState newLineWithLeading:-ty indent:tx save:YES];
    [searcher saveTextPositionWithMatrix:searcher.renderingState.textMatrix];
}

void newLineWithLeading(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;

    CGPDFReal tx, ty;
    CGPDFScannerPopNumber(inScanner, &ty);
    CGPDFScannerPopNumber(inScanner, &tx);
    [searcher.renderingState newLineWithLeading:-ty indent:tx save:NO];
    [searcher saveTextPositionWithMatrix:searcher.renderingState.textMatrix];
}

void newParagraph(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setTextMatrix:CGAffineTransformIdentity replaceLineMatrix:YES];
    [searcher saveTextPositionWithMatrix:searcher.renderingState.textMatrix];
}

void textMatrixCallback(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;

    [searcher.renderingState setTextMatrix:getTransform(inScanner) replaceLineMatrix:YES];
    [searcher saveTextPositionWithMatrix:searcher.renderingState.textMatrix];
}

#pragma mark Font info
void fontInfoCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    
    CGPDFReal fontSize;
    const char *fontName;
    CGPDFScannerPopNumber(inScanner, &fontSize);
    CGPDFScannerPopName(inScanner, &fontName);
    NSLog(@"Font size %f", fontSize);
    searcher->currentFontName = [NSString stringWithFormat:@"%s", fontName];
    searcher->currentFontSize = fontSize;
}

void endTextCallback(CGPDFScannerRef inScanner, void *userInfo) {
//    PDFSearcher * searcher = (PDFSearcher *)userInfo;

}


#pragma mark Get text bytes

void arrayCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    CGPDFArrayRef array = getArray(inScanner);
    
    for (int i = 0; i < CGPDFArrayGetCount(array); i++) {
        CGPDFObjectRef pdfObject = getObject(array, i);
        CGPDFObjectType valueType = CGPDFObjectGetType(pdfObject);
        
        if (valueType == kCGPDFObjectTypeString) {  // did scan string
            
            CGPDFStringRef string = getStringValue(pdfObject);
            [searcher.unicodeContent appendFormat:@"%@", [searcher stringWithPDFString:string]];
            
        } else {    // did scan space
//            PDFFont *font = searcher.fontByFontName[searcher->currentFontName];
            
            float val = getNumericalValue(pdfObject, valueType);
            
            float width = val * (searcher->currentFontSize / 1000);
            
            [searcher translateTextPosition:CGSizeMake(-width, 0)];

            if (isSpace(val, searcher)) {
                // separate string if needed
            }
            NSLog(@"Width %f, convert %f", val, width);
        }
    }
}

void stringCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    
    CGPDFStringRef string = getString(inScanner);
    [searcher.unicodeContent appendFormat:@"%@", [searcher stringWithPDFString:string]];
}


#pragma mark - Text Position Work
- (void)setTextMatrix:(CGAffineTransform)matrix replaceLineMatrix:(BOOL)replace {
    self.renderingState.textMatrix = matrix;
    if (replace) {
        self.renderingState.lineMatrix = matrix;
    }
}
- (void)translateTextPosition:(CGSize)size {
    self.renderingState.textMatrix = CGAffineTransformTranslate(self.renderingState.textMatrix, size.width, size.height);
}

#pragma mark Graphics state operators
- (RenderingState *)renderingState {
    return [_renderingStateStack lastObject];
}

void pushRenderingState(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    RenderingState *state = [searcher.renderingState copy];
    [searcher.renderingStateStack addObject:state];
}

void popRenderingState(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingStateStack removeLastObject];
}
/* Update CTM */
void applyTransformation(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    
    RenderingState *state = searcher.renderingState;
    state.ctm = CGAffineTransformConcat(getTransform(pdfScanner), state.ctm);
}

#pragma mark - Helpers

BOOL isSpace(float width, PDFSearcher *scanner) {
    PDFFont *font = scanner.fontByFontName[scanner->currentFontName];
    return fabs(width) >= font.spaceWidth;
}

CGPDFObjectRef getObject(CGPDFArrayRef pdfArray, int index) {
    CGPDFObjectRef pdfObject;
    CGPDFArrayGetObject(pdfArray, index, &pdfObject);
    return pdfObject;
}

CGPDFStringRef getString(CGPDFScannerRef pdfScanner) {
    CGPDFStringRef pdfString;
    CGPDFScannerPopString(pdfScanner, &pdfString);
    return pdfString;
}
CGPDFStringRef getStringValue(CGPDFObjectRef pdfObject) {
    CGPDFStringRef string;
    CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeString, &string);
    return string;
}
CGPDFArrayRef getArray(CGPDFScannerRef pdfScanner) {
    CGPDFArrayRef pdfArray;
    CGPDFScannerPopArray(pdfScanner, &pdfArray);
    return pdfArray;
}

float getNumericalValue(CGPDFObjectRef pdfObject, CGPDFObjectType type) {
    if (type == kCGPDFObjectTypeReal) {
        CGPDFReal tx;
        CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeReal, &tx);
        return tx;
    }
    else if (type == kCGPDFObjectTypeInteger) {
        CGPDFInteger tx;
        CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeInteger, &tx);
        return tx;
    }
    
    return 0;
}

void printPDFObject(CGPDFObjectRef pdfObject) {
    
    CGPDFObjectType type = CGPDFObjectGetType(pdfObject);

    switch (type) {
        case kCGPDFObjectTypeName: {
            char * name;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeName, &name);
            printf("Type: name, Value: %s\n", name);
            
        } break;
            
        case kCGPDFObjectTypeInteger: {
            CGPDFInteger intiger;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeInteger, &intiger);
            printf("Type: intiger, Value: %ld\n", intiger);
        } break;
            
        case kCGPDFObjectTypeReal: {
            CGPDFReal real;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeReal, &real);
            printf("Type: real, Value: %f\n", real);
        } break;
            
        case kCGPDFObjectTypeDictionary: {
            printf("\nType: dictionary, VALUES: \n");

            CGPDFDictionaryRef dict;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeDictionary, &dict);
            CGPDFDictionaryApplyFunction(dict, printCGPDFDictionary, nil);
            printf("\n");

        } break;
            
        case kCGPDFObjectTypeNull: {
            printf("Type: Null, Value: null\n");

        } break;
            
        case kCGPDFObjectTypeArray: {
            CGPDFArrayRef array;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeArray, &array);
            printf("\nType: array, VALUES: \n");

            for (int i = 0; i < CGPDFArrayGetCount(array); i++) {
                printf("\t[%d]: ", i);
                CGPDFObjectRef object = nil;
                if (CGPDFArrayGetObject(array, i, &object)) {
                    printPDFObject(object);
                    printf("\n");
                } else {
                    printf("fail get object\n");
                }
            }
            printf("\n");
        }
            
        case kCGPDFObjectTypeBoolean: {
            CGPDFBoolean b;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeBoolean, &b);
            printf("Type: bool, Value: %d\n", b);

        } break;
            
        case kCGPDFObjectTypeString: {
            CGPDFStringRef str;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeString, &str);
            NSString *data = CFBridgingRelease(CGPDFStringCopyTextString(str));
            printf("Type: string, Value: %s\n", data.UTF8String);

        } break;
            
        case kCGPDFObjectTypeStream: {
            CGPDFStreamRef stream;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeStream, &stream);

            CGPDFDataFormat *format = NULL;
            CFDataRef xmlData = CGPDFStreamCopyData(stream, format);
            NSData * data = (__bridge NSData*)xmlData;
 
            printf("Type: stream, Size: %lu bytes\n", (unsigned long)data.length);

        } break;
            
        default: {
            printf("Type: UNKNOWN");
        } break;
    }
}

void printCGPDFDictionary(const char *key, CGPDFObjectRef ob, void *info) {
    printf("\t[%s]: ", key);
    printPDFObject(ob);
}

CGPDFReal popNumber(CGPDFScannerRef pdfScanner) {
    CGPDFReal value;
    CGPDFScannerPopNumber(pdfScanner, &value);
    return value;
}

CGAffineTransform getTransform(CGPDFScannerRef pdfScanner) {
    CGAffineTransform transform;
    transform.ty = popNumber(pdfScanner);
    transform.tx = popNumber(pdfScanner);
    transform.d = popNumber(pdfScanner);
    transform.c = popNumber(pdfScanner);
    transform.b = popNumber(pdfScanner);
    transform.a = popNumber(pdfScanner);
    NSLog(@"Transform x:%f y:%f a:%f b:%f c:%f d:%f", transform.ty, transform.tx, transform.a, transform.b, transform.c, transform.d);
    return transform;
}

@end
