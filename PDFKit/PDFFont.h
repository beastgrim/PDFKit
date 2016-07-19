//
//  PDFFont.h
//  PDFKit
//
//  Created by FLS on 01/07/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface PDFFont : NSObject <NSCopying>

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) CGFloat spaceWidth;


- (instancetype) initWithName:(NSString *)name fontDict:(CGPDFDictionaryRef)fontDict;
- (instancetype) initWithName:(NSString *)name defaultWidth:(CGFloat)defWidth widths:(NSMutableDictionary*)widths;

@end
