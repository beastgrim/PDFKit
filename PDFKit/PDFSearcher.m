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


void stringAndSpacesCallback(CGPDFScannerRef inScanner, void *userInfo);
void stringCallback(CGPDFScannerRef inScanner, void *userInfo);
void fontInfoCallback(CGPDFScannerRef inScanner, void *userInfo);
void endTextCallback(CGPDFScannerRef inScanner, void *userInfo);

void textPositionCallback(CGPDFScannerRef inScanner, void *userInfo);
void textMatrixCallback(CGPDFScannerRef inScanner, void *userInfo);
void printStringNewLineSetSpacing(CGPDFScannerRef scanner, void *info);
void setTextLeading(CGPDFScannerRef pdfScanner, void *userInfo);

void characterSpacing(CGPDFScannerRef pdfScanner, void *userInfo);
void wordSpacing(CGPDFScannerRef pdfScanner, void *userInfo);

CGPDFStringRef getString(CGPDFScannerRef pdfScanner);
CGPDFArrayRef getArray(CGPDFScannerRef pdfScanner);
CGPDFObjectRef getObject(CGPDFArrayRef pdfArray, int index);
CGPDFStringRef getStringValue(CGPDFObjectRef pdfObject);
float getNumericalValue(CGPDFObjectRef pdfObject, CGPDFObjectType type);

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
    NSMutableArray *positioningByLocation;
}

@synthesize fontInfo;

- (instancetype) init {
    if (self = [super init]) {
        fontDataArray = [NSMutableArray new];
        table = CGPDFOperatorTableCreate();
        fontInfo = [NSMutableString stringWithUTF8String:"FONT INFO:\n"];
        _unicodeContent = [NSMutableString new];
        _fontNames = [NSMutableSet new];
        _mapperByFontName = [NSMutableDictionary new];
        _fontByFontName = [NSMutableDictionary new];
        _renderingStateStack = [NSMutableArray new];
        [_renderingStateStack addObject:[RenderingState new]];
        
        // Text showing
        CGPDFOperatorTableSetCallback(table, "TJ", stringAndSpacesCallback);      // Show one or more text strings, allowing individual glyph positioning (see imple- mentation note 40 in Appendix H). Each element of array can be a string or a number. If the element is a string, this operator shows the string. If it is a num- ber, the operator adjusts the text position by that amount; that is, it translates the text matrix, Tm. The number is expressed in thousandths of a unit of text space (see Section 5.3.3, “Text Space Details,” and implementation note 41 in Appendix H). This amount is subtracted from the current horizontal or vertical coordinate, depending on the writing mode. In the default coordinate system, a positive adjustment has the effect of moving the next glyph painted either to the left or down by the given amount. Figure 5.11 shows an example of the effect of passing offsets to TJ.
        CGPDFOperatorTableSetCallback(table, "Tj", stringCallback);     // Show a text string.
        CGPDFOperatorTableSetCallback(table, "\'", printStringNewLine); // Move to the next line and show a text string
        CGPDFOperatorTableSetCallback(table, "\"", printStringNewLineSetSpacing);   // Move to the next line and show a text string, using aw as the word spacing and ac as the character spacing (setting the corresponding parameters in the text state). aw and ac are numbers expressed in unscaled text space units.
        // Text objects
        CGPDFOperatorTableSetCallback(table, "BT", startTextCallback);  // PDF start print text
        CGPDFOperatorTableSetCallback(table, "ET", endTextCallback);    // PDF end print text
        // Text positioning
        CGPDFOperatorTableSetCallback(table, "Td", newLineWithLeading); // handle string position
        CGPDFOperatorTableSetCallback(table, "TD", newLineSetLeading);  // handle string position
        CGPDFOperatorTableSetCallback(table, "Tm", textMatrixCallback); // handle text position
        CGPDFOperatorTableSetCallback(table, "T*", newLine);            // handle string position
        // Text state
        CGPDFOperatorTableSetCallback(table, "Tc", characterSpacing);   // Set the character spacing, Tc, to charSpace, which is a number expressed in un- scaled text space units. Character spacing is used by the Tj, TJ, and ' operators. Initial value: 0.
        CGPDFOperatorTableSetCallback(table, "Tw", wordSpacing);   // Setthewordspacing,Tw,towordSpace,whichisanumberexpressedinunscaled text space units. Word spacing is used by the Tj, TJ, and ' operators. Initial value: 0.
        CGPDFOperatorTableSetCallback(table, "Tz", setHorizontalScale); // Set the horizontal scaling, Th , to (scale  ̃ 100). scale is a number specifying the percentage of the normal width. Initial value: 100 (normal width).
        CGPDFOperatorTableSetCallback(table, "TL", setTextLeading); // Set the text leading, Tl , to leading, which is a number expressed in unscaled text space units. Text leading is used only by the T*, ', and " operators. Initial value: 0.
        CGPDFOperatorTableSetCallback(table, "Tf", fontInfoCallback);   // Set the text font, Tf , to font and the text font size, Tfs , to size. font is the name of a font resource in the Font subdictionary of the current resource dictionary; size is a number representing a scale factor. There is no initial value for either font or size; they must be specified explicitly using Tf before any text is shown.
        CGPDFOperatorTableSetCallback(table, "Tr", test);   // Set the text rendering mode, Tmode , to render, which is an integer. Initial value: 0.
        CGPDFOperatorTableSetCallback(table, "Ts", setTextRise);    // Set the text rise, Trise , to rise, which is a number expressed in unscaled text space units. Initial value: 0.

        // Clipping paths
        CGPDFOperatorTableSetCallback(table, "W", test);
        CGPDFOperatorTableSetCallback(table, "W*", test);

        // Type 3 fonts
        CGPDFOperatorTableSetCallback(table, "d0", test);
        CGPDFOperatorTableSetCallback(table, "d1", test);

        // Graphics state operators (Special graphics state)
        CGPDFOperatorTableSetCallback(table, "Q", popRenderingState);
        CGPDFOperatorTableSetCallback(table, "q", pushRenderingState);
        CGPDFOperatorTableSetCallback(table, "cm", applyTransformation);
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
    
    CGRect cropBoxRect = CGPDFPageGetBoxRect(inPage, kCGPDFCropBox);
    PDFPage *page = [[PDFPage alloc] initWithSize:cropBoxRect.size content:_unicodeContent textPositions:positioningByLocation];
    page.fonts = _fontByFontName.allValues;
    return page;
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



const char *kTypeKey = "Type";
const char *kFontSubtypeKey = "Subtype";
const char *kBaseFontKey = "BaseFont";
const char *kFirstCharKey = "FirstChar";
const char *kLastCharKey = "LastChar";
const char *kWidthsKey = "Widths";

const char *kFontKey = "Font";

#pragma mark - Base
- (void) saveTextPositionWithMatrix:(CGAffineTransform)transform {
    CGPoint origin = CGPointMake(transform.tx, transform.ty);
    NSInteger location = _unicodeContent.length;
    TextPosition *lastPos = [positioningByLocation lastObject];
    CGFloat currentFontSize = self.renderingState.fontSize;
    
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

- (PDFFont*)currentFont {
    return _fontByFontName[currentFontName];
}

- (void) handlePdfString:(CGPDFStringRef)pdfString {
    
    PDFFont *font = [self currentFont];
    RenderingState *renderState = self.renderingState;
    
    CGPDFReal width = [font widthOfPDFString:pdfString renderingState:renderState] / 1000.0;
    NSString *result = [font stringWithPDFString:pdfString];
    
    [_unicodeContent appendFormat:@"%@", result];
    
    [self translateTextPosition:CGSizeMake(width, 0)];
    [self saveTextPositionWithMatrix:renderState.textMatrix];
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
    if (!CGPDFObjectGetValue(ob, kCGPDFObjectTypeDictionary, &fontDict)) {
        
        NSLog(@"ERROR GET FONT DICT");
        return;
    }
    
    NSLog(@"PRINT FONT: %s", key);
    printPDFObject(ob);
    
    NSString *fontName = [NSString stringWithFormat:@"%s", key];
    PDFFont *font = [[PDFFont alloc] initWithName:fontName fontDict:fontDict];
    searcher.fontByFontName[fontName] = font;
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

void textMatrixCallback(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    CGAffineTransform transform = getTransform(inScanner);

    NSLog(@"textMatrixCallback %f:%f", transform.tx, transform.ty);
    [searcher.renderingState setTextMatrix:transform replaceLineMatrix:YES];
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
    NSLog(@"Font: %s size: %f", fontName, fontSize);
    
//    [searcher.unicodeContent appendFormat:@"[%s]", fontName];
    searcher->currentFontName = [NSString stringWithFormat:@"%s", fontName];
    searcher.renderingState.fontSize = fontSize;
}

void startTextCallback(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setTextMatrix:CGAffineTransformIdentity replaceLineMatrix:YES];
    [searcher saveTextPositionWithMatrix:searcher.renderingState.textMatrix];
}

void endTextCallback(CGPDFScannerRef inScanner, void *userInfo) {
    static int count;
    count++;
    NSLog(@"Number endTextCallback %d", count);
//    PDFSearcher * searcher = (PDFSearcher *)userInfo;

}


#pragma mark Get text bytes

void stringAndSpacesCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    RenderingState *renderState = searcher.renderingState;
    CGPDFArrayRef array = getArray(inScanner);
    CGFloat currentFontSize = renderState.fontSize;
    
    for (int i = 0; i < CGPDFArrayGetCount(array); i++) {
        CGPDFObjectRef pdfObject = getObject(array, i);
        CGPDFObjectType valueType = CGPDFObjectGetType(pdfObject);
        
        if (valueType == kCGPDFObjectTypeString) {  // did scan string

            CGPDFStringRef string = getStringValue(pdfObject);
            [searcher handlePdfString:string];
            
        } else {    // did scan space

            CGPDFReal space = getNumericalValue(pdfObject, valueType);
            CGPDFReal Tfs = currentFontSize;
            CGPDFReal Tc = renderState.characterSpacing;
            CGPDFReal Tw = renderState.wordSpacing;
            CGPDFReal Th = renderState.horizontalScaling / 100.0;
         
            // tx = ((w0 - (Tj/1000))*Tfs + Tc + Tw)*Th
            CGPDFReal width = ((0 - (space / 1000.0))*Tfs + Tc + Tw)*Th;
  
            [searcher translateTextPosition:CGSizeMake(width, 0)];
            [searcher saveTextPositionWithMatrix:searcher.renderingState.textMatrix];
        }
    }
}

void stringCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    CGPDFStringRef string = getString(inScanner);
    
    [searcher handlePdfString:string];
}

#pragma mark - Text State
void characterSpacing(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setCharacterSpacing:getNumber(pdfScanner)];
    
}

void wordSpacing(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setWordSpacing:getNumber(pdfScanner)];
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

void printStringNewLine(CGPDFScannerRef pdfScanner, void *userInfo) {
    newLine(pdfScanner, userInfo);
    stringCallback(pdfScanner, userInfo);
}

void printStringNewLineSetSpacing(CGPDFScannerRef pdfScanner, void *userInfo) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    
    [searcher.renderingState setWordSpacing:getNumber(pdfScanner)];
    [searcher.renderingState setCharacterSpacing:getNumber(pdfScanner)];
    
    newLine(pdfScanner, userInfo);
    stringCallback(pdfScanner, userInfo);
}

#pragma mark - Text parameters

void setTextLeading(CGPDFScannerRef pdfScanner, void *userInfo) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setLeadning:getNumber(pdfScanner)];
}

void setHorizontalScale(CGPDFScannerRef pdfScanner, void *userInfo) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setHorizontalScaling:getNumber(pdfScanner)];
}

void setTextRise(CGPDFScannerRef pdfScanner, void *userInfo) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setTextRise:getNumber(pdfScanner)];
}

void test(CGPDFScannerRef pdfScanner, void *userInfo) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    NSLog(@"Warning: Test callback not emplemented");
//    [searcher.renderingState setTextRise:getNumber(pdfScanner)];
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

CGPDFReal getNumber(CGPDFScannerRef pdfScanner) {
    CGPDFReal value;
    CGPDFScannerPopNumber(pdfScanner, &value);
    return value;
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
//    NSLog(@"Transform x:%f y:%f a:%f b:%f c:%f d:%f", transform.ty, transform.tx, transform.a, transform.b, transform.c, transform.d);
    return transform;
}

@end
