//
//  PDFDocument.h
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReaderContentView.h"
#import "PDFFont.h"

@interface PDFDocument : NSObject

@property (nonatomic, readonly) NSInteger numberOfPages;

- (instancetype __nullable)initWithCGPDFDocumentRef:(CGPDFDocumentRef __nonnull)newDocumentRef;
- (instancetype __nullable)initWithData:(NSData* __nonnull)pdfData;


- (NSArray <NSValue*> * __nonnull) searchText:(NSString * __nonnull)text onPage:(NSUInteger)pageNumber;
- (ReaderContentView* __nullable) viewForPageNumber:(NSInteger)pageNumber;

@end
