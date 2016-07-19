//
//  PDFFont.m
//  PDFKit
//
//  Created by FLS on 01/07/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import "PDFFont.h"

@implementation PDFFont {
    CGFloat defaultWidth;
    NSMutableDictionary *widths;
}


- (instancetype)initWithName:(NSString *)name fontDict:(CGPDFDictionaryRef)fontDict {
    if (self = [super init]) {
        _name = name;
        widths = [NSMutableDictionary new];
        defaultWidth = 1000;
        
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
