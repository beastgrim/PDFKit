//
//  PDFFont.h
//  PDFKit
//
//  Created by FLS on 01/07/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class RenderingState;

struct CGPDFIntegerArray {
    CGPDFInteger *values;
    size_t size;
};

typedef NS_ENUM (NSInteger, PDFFontType) {
    PDFFontTypeUnknown = 0,
    PDFFontType1,
    PDFFontType2,
    PDFFontType3
};

@interface PDFFont : NSObject <NSCopying>

@property (nonatomic, readonly) PDFFontType type;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) CGFloat spaceWidth;

@property (nonatomic, readonly) CGFloat xHeight;
@property (nonatomic, readonly) CGFloat capHeight;
@property (nonatomic, readonly) CGFloat leading;
@property (nonatomic, readonly) CGPDFInteger firstChar;
@property (nonatomic, readonly) CGPDFInteger lastChar;
@property (nonatomic, readonly) struct CGPDFIntegerArray widths;
@property (nonatomic, readonly) struct CGPDFIntegerArray fontBBox;
@property (nonatomic, readonly) CGRect bBoxRect;


- (instancetype) initWithName:(NSString *)name fontDict:(CGPDFDictionaryRef)fontDict;
- (instancetype) initWithName:(NSString *)name defaultWidth:(CGFloat)defWidth widths:(NSMutableDictionary*)widths;

- (CGPDFInteger) widthOfChar:(CGPDFInteger)charCode;
- (CGPDFInteger) widthOfPDFString:(CGPDFStringRef)pdfString renderingState:(RenderingState*)renderingState;

- (NSString *)stringWithPDFString:(CGPDFStringRef)pdfString;

@end
