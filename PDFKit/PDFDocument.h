//
//  PDFDocument.h
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SearchResults.h"
#import "ReaderContentView.h"

@interface PDFDocument : NSObject

@property (nonatomic, readonly) NSInteger numberOfPages;

- (instancetype __nullable)initWithData:(NSData* __nonnull)pdfData;
- (NSArray <SearchResults*> * __nonnull) searchText:(NSString * __nonnull)text;
- (NSArray <SearchResults*> * __nonnull) searchText:(NSString * __nonnull)text onPage:(NSUInteger)pageNumber;

- (ReaderContentView*) viewForPageNumber:(NSInteger)pageNumber;

@end
