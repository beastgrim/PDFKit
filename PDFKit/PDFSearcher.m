//
//  PDFReader.m
//  EO2
//
//  Created by FLS on 15/06/16.
//  Copyright © 2016 Luxoft. All rights reserved.
//

#import "PDFSearcher.h"
#import "PDFKit-Swift.h"


void arrayCallback(CGPDFScannerRef inScanner, void *userInfo);
void stringCallback(CGPDFScannerRef inScanner, void *userInfo);
void fontInfoCallback(CGPDFScannerRef inScanner, void *userInfo);
void endTextCallback(CGPDFScannerRef inScanner, void *userInfo);
void startTextCallback(CGPDFScannerRef inScanner, void *userInfo);

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
        _unicodeContent = [NSMutableString stringWithUTF8String:"UNICODE CONTENT:\n"];
        _fontNames = [NSMutableSet new];
        _mapperByFontName = [NSMutableDictionary new];
        
        CGPDFOperatorTableSetCallback(table, "TJ", arrayCallback);      // when pdf print strings and spaces
        CGPDFOperatorTableSetCallback(table, "Tj", stringCallback);     // when pdf print strings
        CGPDFOperatorTableSetCallback(table, "Td", textPositionCallback); // handle string position
        CGPDFOperatorTableSetCallback(table, "TD", textPositionCallback); // handle string position
        CGPDFOperatorTableSetCallback(table, "Tm", textMatrixCallback); // handle string position
        CGPDFOperatorTableSetCallback(table, "T*", textPositionCallback); // handle string position
        CGPDFOperatorTableSetCallback(table, "Tf", fontInfoCallback);   // handle switches to new font
        CGPDFOperatorTableSetCallback(table, "ET", endTextCallback);    // PDF end print text
        CGPDFOperatorTableSetCallback(table, "BT", startTextCallback);  // PDF start print text
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
void textPositionCallback(CGPDFScannerRef inScanner, void *userInfo) {
//    PDFSearcher * searcher = (PDFSearcher *)userInfo;

    CGPDFObjectRef obj;
    
    while (CGPDFScannerPopObject(inScanner, &obj)) {
        
        CGPDFObjectType type = CGPDFObjectGetType(obj);
        
        if (type == kCGPDFObjectTypeReal) {
            CGPDFReal floatVal;
            CGPDFObjectGetValue(obj, kCGPDFObjectTypeReal, &floatVal);
            
        }
    }
}

void textMatrixCallback(CGPDFScannerRef inScanner, void *userInfo) {
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;

    CGAffineTransform transform = getTransform(inScanner);
    CGPoint origin = CGPointMake(transform.tx, transform.ty);
        
    TextPosition *textPos = [TextPosition new];
    textPos.location = searcher.unicodeContent.length;
    textPos.origin = origin;
    textPos.fontName = searcher->currentFontName;
    textPos.fontSize = CGSizeMake(6, 8);
    [searcher->positioningByLocation addObject:textPos];
}

#pragma mark Font info
void fontInfoCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher * searcher = (__bridge PDFSearcher *)userInfo;
    
    CGPDFObjectRef obj;
    bool success = CGPDFScannerPopObject(inScanner, &obj);
    CGPDFObjectType type = CGPDFObjectGetType(obj);
    while (success) {
        //        successInt = CGPDFScannerPopInteger(inScanner, &intiger);
        [searcher.fontInfo appendFormat:@"Type: %d ", type];

        switch (type) {
            case kCGPDFObjectTypeName: {
                char * name;
                CGPDFObjectGetValue(obj, kCGPDFObjectTypeName, &name);
                NSString *fontName = [NSString stringWithFormat:@"%s", name];
                
                if (![searcher->currentFontName isEqualToString:fontName]) {
                    [searcher.fontInfo appendFormat:@"Name: %s", name];
                    [searcher.unicodeContent appendFormat:@"\n[NEW FONT: %s]", name];
                    searcher->currentFontName = [NSString stringWithFormat:@"%s", name];
                }
                
            } break;
                
            case kCGPDFObjectTypeInteger: {
                CGPDFInteger intiger;
                CGPDFObjectGetValue(obj, kCGPDFObjectTypeInteger, &intiger);
//                [searcher.unicodeContent appendFormat:@"[INT: %ld]", intiger];
                [searcher.fontInfo appendFormat:@"Int: %ld", intiger];
            } break;
                
            case kCGPDFObjectTypeReal: {
                CGPDFReal real;
                CGPDFObjectGetValue(obj, kCGPDFObjectTypeReal, &real);
                [searcher.fontInfo appendFormat:@"Int: %f", real];
            } break;
                
            case kCGPDFObjectTypeDictionary: {
                
                CGPDFDictionaryRef fontDict;
                CGPDFObjectGetValue(obj, kCGPDFObjectTypeDictionary, &fontDict);
                CGPDFDictionaryApplyFunction(fontDict, didScanFont, nil);

                const char *typeName = nil;
                CGPDFDictionaryGetName(fontDict, kTypeKey, &typeName);
                const char *subtype = nil;
                CGPDFDictionaryGetName(fontDict, kFontSubtypeKey, &subtype);
//                const char *toUnicode = nil;
                CGPDFDictionaryGetName(fontDict, kToUnicodeKey, &subtype);
                
                const char *encodingName = nil;
                if (!CGPDFDictionaryGetName(fontDict, kEncodingKey, &encodingName))
                {
                    CGPDFDictionaryRef encodingDict = nil;
                    CGPDFDictionaryGetDictionary(fontDict, kEncodingKey, &encodingDict);
//                    printf("ENCODING INFO KEYS:\n");
                    CGPDFDictionaryApplyFunction(encodingDict, printPDFKeys, nil);
                    
//                    printf("Encoding Name: %s\n", encodingName);
//                    printf("Type: %s\n", typeName);
//                    printf("Subtype: %s\n", subtype);
//                    printf("ToUnicode: %s\n", toUnicode);
                    
                    // TODO: Also get differences from font encoding dictionary
                }
                [searcher.unicodeContent appendFormat:@"\n[NEW FONT: NAME: %s, TYPE: %s]", encodingName, typeName];
            }
                
            default: {
                NSLog(@"Uncautch type %d", type);

            } break;
        }
        
        [searcher.fontInfo appendFormat:@"\n"];

        success = CGPDFScannerPopObject(inScanner, &obj);
        type = CGPDFObjectGetType(obj);
    }
    
    // stop grab font info
    [searcher.fontInfo appendFormat:@"\n"];
}

void endTextCallback(CGPDFScannerRef inScanner, void *userInfo) {
//    PDFSearcher * searcher = (PDFSearcher *)userInfo;

}

void startTextCallback(CGPDFScannerRef inScanner, void *userInfo) {
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
        
        if (valueType == kCGPDFObjectTypeString) {
            
            CGPDFStringRef string = getStringValue(pdfObject);
            [searcher.unicodeContent appendFormat:@"%@", [searcher stringWithPDFString:string]];
        }
        else {
            float val = getNumericalValue(pdfObject, valueType);
            for (int count = 0; count < (int)val; count++) {
//                [searcher.unicodeContent appendFormat:@"."];
            }
        }
    }
}

void stringCallback(CGPDFScannerRef inScanner, void *userInfo)
{
    PDFSearcher *searcher = (__bridge PDFSearcher *)userInfo;
    
    CGPDFStringRef string = getString(inScanner);
    [searcher.unicodeContent appendFormat:@"%@", [searcher stringWithPDFString:string]];
}


#pragma mark - Helpers

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

void handleFontDictionary(const char *key, CGPDFObjectRef ob, void *info) {
    PDFSearcher *searcher = (__bridge PDFSearcher *)info;
    
    if (CGPDFObjectGetType(ob) != kCGPDFObjectTypeDictionary) return;
    
    CGPDFDictionaryRef fontDict;
    if (CGPDFObjectGetValue(ob, kCGPDFObjectTypeDictionary, &fontDict)) {
        CGPDFDictionaryApplyFunction(fontDict, didScanFont, info);
    }
    
    CGPDFObjectRef toUnicodeObj;
    if (!CGPDFDictionaryGetObject(fontDict, kToUnicodeKey, &toUnicodeObj)) return;
    
    CGPDFStreamRef toUnicodeStream;
    if (!CGPDFObjectGetValue(toUnicodeObj, kCGPDFObjectTypeStream, &toUnicodeStream)) return;
    
    CFDataRef dataRef = CGPDFStreamCopyData(toUnicodeStream, NULL);
    NSData *data = (__bridge NSData*)dataRef;
    ToUnicodeMapper *mapper = [[ToUnicodeMapper alloc] initWithData:data];
    
    if (mapper) {
        NSLog(@"\n\nDID HANDLE FONT: [%s]\n\nMapData: %@\nMAP: %@", key, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], mapper.map);
        searcher.mapperByFontName[[NSString stringWithFormat:@"%s",key]] = mapper;
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
    return transform;
}

@end
