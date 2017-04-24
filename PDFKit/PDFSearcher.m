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


#define PDFKit_DEBUG_MODE 0

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
void setRenderingMode(CGPDFScannerRef pdfScanner, void *userInfo);
void newLine(CGPDFScannerRef inScanner, void *userInfo);
void newLineSetLeading(CGPDFScannerRef inScanner, void *userInfo);
void newLineWithLeading(CGPDFScannerRef inScanner, void *userInfo);
void startTextCallback(CGPDFScannerRef inScanner, void *userInfo);
void pushRenderingState(CGPDFScannerRef pdfScanner, void *userInfo);
void popRenderingState(CGPDFScannerRef pdfScanner, void *userInfo);
void applyTransformation(CGPDFScannerRef pdfScanner, void *userInfo);
void printStringNewLine(CGPDFScannerRef pdfScanner, void *userInfo);
void setHorizontalScale(CGPDFScannerRef pdfScanner, void *userInfo);
void setTextRise(CGPDFScannerRef pdfScanner, void *userInfo);
void test(CGPDFScannerRef pdfScanner, void *userInfo);
BOOL isSpace(float width, PDFSearcher *scanner);


CGPDFStringRef getString(CGPDFScannerRef pdfScanner);
CGPDFArrayRef getArray(CGPDFScannerRef pdfScanner);
CGPDFObjectRef getObject(CGPDFArrayRef pdfArray, int index);
CGPDFStringRef getStringValue(CGPDFObjectRef pdfObject);
CGPDFReal getNumber(CGPDFScannerRef pdfScanner);
CGPDFReal popNumber(CGPDFScannerRef pdfScanner);
CGAffineTransform getTransform(CGPDFScannerRef pdfScanner);
float getNumericalValue(CGPDFObjectRef pdfObject, CGPDFObjectType type);

void printPDFObject(CGPDFObjectRef pdfObject);

@interface PDFSearcher ()

@property (nonatomic, retain) NSMutableString *fontInfo;
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
    NSString *searchStr;
    NSMutableArray <NSValue*> *searchResults;
    NSInteger foundIndex;
    NSInteger searchLength;
    CGRect searchRect;
}

@synthesize fontInfo, fontByFontName = _fontByFontName, renderingStateStack = _renderingStateStack, unicodeContent = _unicodeContent;

- (instancetype) init {
    if (self = [super init]) {
        fontDataArray = [NSMutableArray new];
        table = CGPDFOperatorTableCreate();
        fontInfo = [NSMutableString stringWithUTF8String:"FONT INFO:\n"];
        _unicodeContent = [NSMutableString new];
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
        CGPDFOperatorTableSetCallback(table, "Tr", setRenderingMode);   // Set the text rendering mode, Tmode , to render, which is an integer. Initial value: 0.
        CGPDFOperatorTableSetCallback(table, "Ts", setTextRise);    // Set the text rise, Trise , to rise, which is a number expressed in unscaled text space units. Initial value: 0.

        // Clipping paths
//        CGPDFOperatorTableSetCallback(table, "W", test);
//        CGPDFOperatorTableSetCallback(table, "W*", test);

        // Type 3 fonts
        CGPDFOperatorTableSetCallback(table, "d0", test);
        CGPDFOperatorTableSetCallback(table, "d1", test);

        // Graphics state operators (Special graphics state)
        CGPDFOperatorTableSetCallback(table, "Q", popRenderingState);   // Restore the graphics state by removing the most recently saved state from the stack and making it the current state (see “Graphics State Stack” on page 152).
        CGPDFOperatorTableSetCallback(table, "q", pushRenderingState);  // Save the current graphics state on the graphics state stack (see “Graphics State Stack” on page 152).
        CGPDFOperatorTableSetCallback(table, "cm", applyTransformation);    // Modify the current transformation matrix (CTM) by concatenating the specified matrix (see Section 4.2.1, “Coordinate Spaces”). Although the operands specify a matrix, they are written as six separate numbers, not as an array.
    }
    return self;
}

- (void)dealloc {
    CGPDFOperatorTableRelease(table);
}


#pragma mark - Public

- (NSArray<NSValue *> *)searchString:(NSString *)inSearchString inPage:(CGPDFPageRef)inPage {
    searchResults = [NSMutableArray new];
    if (inSearchString.length > 0) {
        searchStr = [inSearchString uppercaseString];
        searchLength = searchStr.length;
        CGRect cropBoxRect = CGPDFPageGetBoxRect(inPage, kCGPDFCropBox);
        CGRect mediaBoxRect = CGPDFPageGetBoxRect(inPage, kCGPDFMediaBox);

        // Initial value: a matrix that transforms default user coordinates to device coordinates.
        CGFloat tx = cropBoxRect.origin.x;
        CGFloat ty = cropBoxRect.origin.y;
        self.renderingState.ctm = CGAffineTransformMake(1, 0, 0, -1, 0, cropBoxRect.size.height);
        self.renderingState.ctm = CGAffineTransformTranslate(self.renderingState.ctm, -tx*2, 0);
        self.renderingState.ctm = CGAffineTransformScale(self.renderingState.ctm, 1, 1);
        
        [self fontCollectionWithPage:inPage];
        
        CGPDFContentStreamRef contentStream = CGPDFContentStreamCreateWithPage(inPage);
        CGPDFScannerRef scanner = CGPDFScannerCreate(contentStream, table, (__bridge void * _Nullable)(self));
        CGPDFScannerScan(scanner);
        CGPDFScannerRelease(scanner);
        CGPDFContentStreamRelease(contentStream);
    }
    
    return searchResults;
}


const char *kTypeKey = "Type";
const char *kFontSubtypeKey = "Subtype";
const char *kBaseFontKey = "BaseFont";
const char *kFirstCharKey = "FirstChar";
const char *kLastCharKey = "LastChar";
const char *kWidthsKey = "Widths";

const char *kFontKey = "Font";

#pragma mark - Base

- (PDFFont*)currentFont {
    return _fontByFontName[currentFontName];
}

- (void) handlePdfString:(CGPDFStringRef)pdfString withTj:(CGPDFReal)tj {
    
    PDFFont *font = [self currentFont];
    RenderingState *renderState = self.renderingState;
    NSMutableString *text = [NSMutableString new];
    __block CGPDFReal totalWidth = 0.0;
    
    __weak typeof(self) weakSelf = self;
    [font decodePDFString:pdfString withTj:tj renderingState:renderState callback:^(NSString *character, CGSize glifSize) {
        [weakSelf.unicodeContent appendFormat:@"%@", character];
        
        [text appendString:character];
        
#if PDFKit_DEBUG_MODE == 1
        CGAffineTransform trm = [weakSelf getTextRenderingMatrix];
        CGFloat botX = trm.tx;
        CGFloat botY = trm.ty;
        
        [weakSelf translateTextPosition:CGSizeMake(glifSize.width, -glifSize.height)];
        trm = [weakSelf getTextRenderingMatrix];
        CGFloat upX = trm.tx;
        CGFloat upY = trm.ty;

        searchRect = CGRectMake(botX, botY, upX-botX, upY-botY);
        [weakSelf translateTextPosition:CGSizeMake(-glifSize.width, glifSize.height)];

        [weakSelf savePDFSearchRect:searchRect];
        [weakSelf translateTextPositionWithGlifSize:glifSize tj:tj];
        totalWidth += glifSize.width;
#else
        NSRange currentRange = NSMakeRange(foundIndex, 1);
        BOOL isNextCharFound = [[character uppercaseString] isEqualToString:[searchStr substringWithRange:currentRange]];
        BOOL textMatrixShouldBeUpdated = YES;
        
        if (isNextCharFound) {
            foundIndex++;
            
            if (foundIndex == 1) {  // save X position and HEIGHT of search text
                
                CGAffineTransform trm = [weakSelf getTextRenderingMatrix];
                
                searchRect = CGRectZero;
                searchRect.origin.x = trm.tx;
                searchRect.origin.y = trm.ty;
            }
            
            if (foundIndex == searchLength) {       // save result and start new search
                
                [weakSelf translateTextPosition:glifSize];
                CGAffineTransform trm = [weakSelf getTextRenderingMatrix];

                CGFloat offsetX = trm.tx - searchRect.origin.x;
                if (offsetX < 0) { // we are maybe on other line
                    NSLog(@"WARNING: start X of serach text is greater then end X of search text!");
                }
                searchRect.size.width = MAX(5, offsetX);
                searchRect.size.height = searchRect.origin.y - trm.ty;
                // return Y position back
                [weakSelf translateTextPosition:CGSizeMake(0, -glifSize.height)];

                [weakSelf savePDFSearchRect:searchRect];
                foundIndex = 0;
                
                [weakSelf translateTextPositionWithTj:tj];
                
                textMatrixShouldBeUpdated = NO;
            }
            
        } else {    // reset search
            foundIndex = 0;
        }
        if (textMatrixShouldBeUpdated) {
            [weakSelf translateTextPositionWithGlifSize:glifSize tj:tj];
        }
#endif
        
    } stringWidthCallback:^(CGFloat width) {
        
        // not working yet
//        renderState.textMatrix = tm;
//        [weakSelf translateTextPosition:CGSizeMake(width, 0)];
//        NSLog(@"Totlal string width: %@ %f, by chars width: %f", text, width, totalWidth);
    }];
}

- (void) translateTextPositionWithTj:(CGFloat)tj {
    RenderingState *renderState = self.renderingState;

    CGPDFReal w0 = 0.0;
    CGPDFReal Tfs = renderState.fontSize;
    CGPDFReal Tc = renderState.characterSpacing;
    CGPDFReal Tw = 0.0; // word spacing applied on glif width with char code 32
    CGPDFReal Th = renderState.horizontalScaling/100;
    CGPDFReal tx = ((w0 - (tj/1000.0))*Tfs + Tc + Tw)*Th;
    
    [self translateTextPosition:CGSizeMake(tx, 0)];
}

- (void) translateTextPositionWithGlifSize:(CGSize)size tj:(CGFloat)tj {

    [self translateTextPosition:CGSizeMake(size.width, 0)];
    [self translateTextPositionWithTj:tj];
}

- (void) savePDFSearchRect:(CGRect)rect {
    [searchResults addObject:[NSValue valueWithCGRect:rect]];
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

    //
    NSLog(@"PRINT FONT: %s", key);
    printPDFObject(ob); //*/

    NSString *fontName = [NSString stringWithFormat:@"%s", key];
    PDFFont *font = [[PDFFont alloc] initWithName:fontName fontDict:fontDict];
    searcher.fontByFontName[fontName] = font;
}


#pragma mark - PDF protocol

#pragma mark - Text Positioning
// T*
void newLine(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.unicodeContent appendFormat:@"\n"];
    [searcher.renderingState newLine];
}
// TD
void newLineSetLeading(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    CGPDFReal tx, ty;
    CGPDFScannerPopNumber(inScanner, &ty);
    CGPDFScannerPopNumber(inScanner, &tx);
    [searcher.unicodeContent appendFormat:@"\n"];
    [searcher.renderingState newLineWithLeading:-ty indent:tx save:YES];
}
// Td
void newLineWithLeading(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;

    CGPDFReal tx, ty;
    CGPDFScannerPopNumber(inScanner, &ty);
    CGPDFScannerPopNumber(inScanner, &tx);
    [searcher.unicodeContent appendFormat:@"\n"];
    [searcher.renderingState newLineWithLeading:-ty indent:tx save:NO];
}
// Tm
void textMatrixCallback(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    CGAffineTransform transform = getTransform(inScanner);

    [searcher.renderingState setTextMatrix:transform replaceLineMatrix:YES];
}

/* cm Update CTM */
void applyTransformation(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    RenderingState *state = searcher.renderingState;
    
    CGAffineTransform tf = getTransform(pdfScanner);
    state.ctm = CGAffineTransformConcat(tf, state.ctm);
}

#pragma mark Font info
void fontInfoCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    CGPDFReal fontSize;
    CGPDFScannerPopNumber(inScanner, &fontSize);
    const char *font_name;
    CGPDFScannerPopName(inScanner, &font_name);
//    NSLog(@"Font: %s size: %f", fontName, fontSize);
    NSString *fontName = [NSString stringWithFormat:@"%s", font_name];
//    [searcher.unicodeContent appendFormat:@"[%@]", fontName];
    searcher->currentFontName = fontName;
    searcher.renderingState.fontSize = fontSize;
    PDFFont *font = searcher.fontByFontName[fontName];
    searcher.renderingState.font = font;
}
// BT
void startTextCallback(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.renderingState setTextMatrix:CGAffineTransformIdentity replaceLineMatrix:YES];
}
// ET
void endTextCallback(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    [searcher.unicodeContent appendFormat:@"\n"];
}


#pragma mark Get text bytes

void stringAndSpacesCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    RenderingState *renderState = searcher.renderingState;
    CGPDFArrayRef array = getArray(inScanner);
    
//    const unsigned char * characterCodes = CGPDFStringGetBytePtr(pdfString);
//    size_t count = CGPDFStringGetLength(pdfString);
    BOOL didScanSpace = false;
    CGPDFStringRef lastString = NULL;
    CGPDFInteger count = CGPDFArrayGetCount(array);
    
    for (int i = 0; i < count; i++) {
        CGPDFObjectRef pdfObject = getObject(array, i);
        CGPDFObjectType valueType = CGPDFObjectGetType(pdfObject);
        
        if (valueType == kCGPDFObjectTypeString) {  // did scan string
            
            if (lastString) {
                NSLog(@"ERRROR: TJ operator without space");
                [searcher handlePdfString:lastString withTj:0];
                lastString = NULL;
            }

            lastString = getStringValue(pdfObject);
            didScanSpace = false;

        } else {    // did scan space

            didScanSpace = true;
            
            CGPDFReal Tj = getNumericalValue(pdfObject, valueType);
  
            if (lastString) {
                [searcher handlePdfString:lastString withTj:Tj];
                lastString = NULL;
            } else {
                NSLog(@"ERROR: TJ operator without string");
                
                CGPDFReal Tfs = renderState.fontSize;
                CGPDFReal Tc = renderState.characterSpacing;
                CGPDFReal Tw = renderState.wordSpacing;
                CGPDFReal Th = renderState.horizontalScaling / 100.0;
                CGPDFReal w0 = 0.0;
                
                // tx = ((w0 - (Tj/1000))*Tfs + Tc + Tw)*Th
                CGPDFReal tx = ((w0 - (Tj/1000))*Tfs + Tc + Tw)*Th;
                
                [searcher translateTextPosition:CGSizeMake(tx, 0)];
            }
        }
    }
    
    if (lastString) {
        [searcher handlePdfString:lastString withTj:0];
    }
}

void stringCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    CGPDFStringRef string = getString(inScanner);
    
    [searcher handlePdfString:string withTj:0];
}

#pragma mark Text State
void characterSpacing(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    CGPDFReal spacing = getNumber(pdfScanner);
    [searcher.renderingState setCharacterSpacing:spacing];
}

void wordSpacing(CGPDFScannerRef pdfScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    CGPDFReal spacing = getNumber(pdfScanner);
    [searcher.renderingState setWordSpacing:spacing];
}

#pragma mark - Text Position Helpers
- (void)setTextMatrix:(CGAffineTransform)matrix replaceLineMatrix:(BOOL)replace {
    self.renderingState.textMatrix = matrix;
    if (replace) {
        self.renderingState.lineMatrix = matrix;
    }
}

- (void)translateTextPosition:(CGSize)size {
    self.renderingState.textMatrix = CGAffineTransformTranslate(self.renderingState.textMatrix, size.width, size.height);
}

- (CGAffineTransform)getTextRenderingMatrix {
    // Trm is a temporary matrix; conceptually, it is recomputed before each glyph is painted during a text-showing operation.
    RenderingState *renderState = self.renderingState;
    CGFloat a = renderState.fontSize * renderState.horizontalScaling;
    CGFloat b = 0;
    CGFloat c = 0;
    CGFloat d = renderState.fontSize;
    CGFloat tx = 0;
    CGFloat ty = renderState.textRise;
    CGAffineTransform fontTransform = CGAffineTransformMake(a, b, c, d, tx, ty);
    
    CGAffineTransform one = CGAffineTransformConcat(fontTransform, renderState.textMatrix);
    CGAffineTransform rm = CGAffineTransformConcat(one, renderState.ctm);
    
    return rm;
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
    CGPDFReal leading = getNumber(pdfScanner);
    searcher.renderingState.leadning = leading;
}

void setHorizontalScale(CGPDFScannerRef pdfScanner, void *userInfo) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    CGPDFReal horizontalScaling = getNumber(pdfScanner);
    searcher.renderingState.horizontalScaling = horizontalScaling;
}

void setTextRise(CGPDFScannerRef pdfScanner, void *userInfo) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    CGPDFReal textRise = getNumber(pdfScanner);
    searcher.renderingState.textRise = textRise;
}

void setRenderingMode(CGPDFScannerRef pdfScanner, void *userInfo) {
    CGPDFInteger mode;
    CGPDFScannerPopInteger(pdfScanner, &mode);
    
//    NSLog(@"Rendering mode is %ld", mode);
}


#pragma mark - Not emplemented
void test(CGPDFScannerRef pdfScanner, void *userInfo) {
//    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    NSLog(@"Warning: Test callback not emplemented");
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

void printPDFObjectWithOffset(CGPDFObjectRef pdfObject, uint8_t offset);
void printPDFObject(CGPDFObjectRef pdfObject) {
    printPDFObjectWithOffset(pdfObject, 0);
}
void printPDFObjectWithOffset(CGPDFObjectRef pdfObject, uint8_t offset) {

    const char *space = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";
    
    CGPDFObjectType type = CGPDFObjectGetType(pdfObject);

    switch (type) {
        case kCGPDFObjectTypeName: {
            char * name;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeName, &name);
            printf("%.*s'%s'\n", offset, space, name);
        } break;
            
        case kCGPDFObjectTypeInteger: {
            CGPDFInteger intiger;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeInteger, &intiger);
            printf("%.*s %ld\n", offset, space, intiger);
        } break;
            
        case kCGPDFObjectTypeReal: {
            CGPDFReal real;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeReal, &real);
            printf("%.*s %f\n", offset, space, real);
        } break;
            
        case kCGPDFObjectTypeDictionary: {
            uint8_t dictOffset = offset+1;
            printf("\n%.*s { \n", dictOffset, space);

            CGPDFDictionaryRef dict;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeDictionary, &dict);
            CGPDFDictionaryApplyFunction(dict, printCGPDFDictionary, &dictOffset);
            
            printf("\n%.*s} \n", dictOffset, space);

        } break;
            
        case kCGPDFObjectTypeNull: {
            printf("%.*s null\n", offset, space);

        } break;
            
        case kCGPDFObjectTypeArray: {
            
            CGPDFArrayRef array;
            uint8_t arrOffset = offset+2;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeArray, &array);
            printf("\n%.*s [\n", arrOffset, space);

            for (int i = 0; i < CGPDFArrayGetCount(array); i++) {
                printf("%.*s [%d]: ", arrOffset, space, i);
                CGPDFObjectRef object = nil;
                if (CGPDFArrayGetObject(array, i, &object)) {
                    
                    CGPDFObjectType type = CGPDFObjectGetType(object);
                    if (type == kCGPDFObjectTypeArray || type == kCGPDFObjectTypeDictionary) {
                        printPDFObjectWithOffset(object, arrOffset);
                    } else {
                        printPDFObjectWithOffset(object, 0);
                    }
                    printf("\n");
                } else {
                    printf("fail get object\n");
                }
            }
            printf("%.*s]\n", arrOffset, space);
        }
            
        case kCGPDFObjectTypeBoolean: {
            CGPDFBoolean b;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeBoolean, &b);
            printf("%.*s%s\n", offset, space, (b == 0 ? "false" : "true"));

        } break;
            
        case kCGPDFObjectTypeString: {
            CGPDFStringRef str;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeString, &str);
            NSString *data = CFBridgingRelease(CGPDFStringCopyTextString(str));
            printf("%.*s\"%s\"\n", offset, space, data.UTF8String);

        } break;
            
        case kCGPDFObjectTypeStream: {
            CGPDFStreamRef stream;
            CGPDFObjectGetValue(pdfObject, kCGPDFObjectTypeStream, &stream);

            CGPDFDataFormat *format = NULL;
            CFDataRef xmlData = CGPDFStreamCopyData(stream, format);
            NSData * data = (__bridge NSData*)xmlData;

            NSString *decoded = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            if (decoded) {
                printf("%.*sType: stream:\n%s\n", offset, space, decoded.UTF8String);
            } else {
                printf("%.*sType: stream, Size: %lu bytes\n", offset, space, (unsigned long)data.length);
            }

        } break;
            
        default: {
            printf("%.*sType: UNKNOWN", offset, space);
        } break;
    }
}

void printCGPDFDictionary(const char *key, CGPDFObjectRef obj, void *info) {
    uint8_t *offsetPointer = info;
    uint8_t offset = *offsetPointer;
    const char *space = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";

    printf("%.*s %s: ", offset, space, key);
    CGPDFObjectType type = CGPDFObjectGetType(obj);
    if (type == kCGPDFObjectTypeDictionary || type == kCGPDFObjectTypeArray) {
        printPDFObjectWithOffset(obj, offset+2);
    } else {
        printPDFObjectWithOffset(obj, 0);
    }
}

void printTransform(CGAffineTransform t) {
    printf("Transform: x: %f y: %f a: %f b: %f c: %f d: %f\n", t.tx, t.ty, t.a, t.b, t.c, t.d);
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

    return transform;
}

@end
