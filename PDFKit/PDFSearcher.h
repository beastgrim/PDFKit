//
//  PDFReader.h
//  EO2
//
//  Created by FLS on 15/06/16.
//  Copyright © 2016 Luxoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface PDFSearcher : NSObject

@property (nonatomic, retain) NSMutableString * unicodeContent;

- (NSArray <NSValue *> *)searchString:(NSString *)inSearchString inPage:(CGPDFPageRef)inPage;

@end
