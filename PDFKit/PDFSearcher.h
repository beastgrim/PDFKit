//
//  PDFReader.h
//  EO2
//
//  Created by FLS on 15/06/16.
//  Copyright © 2016 Luxoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "PDFPage.h"

@interface PDFSearcher : NSObject

@property (nonatomic, retain) NSMutableString * unicodeContent;

- (PDFPage*)pageInfoForPDFPage:(CGPDFPageRef)inPage;
- (BOOL) page:(CGPDFPageRef)inPage containsString:(NSString *)inSearchString;

@end
