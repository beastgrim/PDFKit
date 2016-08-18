//
//  PDFDocument.m
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import "PDFDocument.h"
#import <CoreGraphics/CoreGraphics.h>
#import "PDFSearcher.h"

@implementation PDFDocument {
    CGPDFDocumentRef documentRef;
}

- (instancetype)initWithData:(NSData *)pdfData {
    if (self = [super init]) {
        CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)pdfData);
        documentRef = CGPDFDocumentCreateWithProvider(dataProvider);
        CGDataProviderRelease(dataProvider);
        
        if (documentRef == nil) { return nil; }
        _numberOfPages = CGPDFDocumentGetNumberOfPages(documentRef);        
    }
    return self;
}

- (NSArray <SearchResults*>*)searchText:(NSString *)text {
    PDFSearcher *searh = [PDFSearcher new];
        
    for (NSUInteger i = 0; i < _numberOfPages; i++) {
        CGPDFPageRef page = [self pageWithIndex:i];
        [searh page:page containsString:@""];
        NSLog(@"Searcher find text: %@", searh.unicodeContent);
    }
    return nil;
}

- (NSArray <SearchResults*>*)searchText:(NSString *)text onPage:(NSUInteger)pageNumber {
    PDFSearcher *searh = [PDFSearcher new];
    PDFPage *pageInfo;
    NSMutableArray <SearchResults*>*results = [NSMutableArray new];

    if (pageNumber < _numberOfPages) {
        CGPDFPageRef page = [self pageWithIndex:pageNumber];
        pageInfo = [searh pageInfoForPDFPage:page];
        
        NSError *err;
        NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:text options:NSRegularExpressionCaseInsensitive error:&err];
        NSString *content = pageInfo.unicodeContent;
        
        
        [regex enumerateMatchesInString:pageInfo.unicodeContent options:0 range:NSMakeRange(0, content.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
            
            NSRange range = result.range;
            
            CGRect textRect = [pageInfo rectForTextRange:range];
            
            SearchResults *searchResult = [[SearchResults alloc] initWithRect:textRect];
            
            NSUInteger length = range.location + 10 < content.length ?  10 : content.length - range.location;
            NSRange nextTextRange = NSMakeRange(range.location, length);
            searchResult.nextText = [[content substringWithRange:nextTextRange] copy];
            [results addObject:searchResult];
        }];
    }
    
    NSLog(@"Searcher find text: %@ PageInfo: %@", searh.unicodeContent, pageInfo);
    return results;
}

- (CGPDFPageRef)pageWithIndex:(NSInteger)index {
    if (index < _numberOfPages) {
        CGPDFPageRef PDFPageRef = CGPDFDocumentGetPage(documentRef, index+1);
        return PDFPageRef;
    }
    return nil;
}

- (ReaderContentView*) viewForPageNumber:(NSInteger)pageNumber {
    
    CGPDFPageRef page = [self pageWithIndex:pageNumber];
    if (page) {
        CGRect cropBoxRect = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
//        CGRect mediaBoxRect = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
        CGSize size = cropBoxRect.size;
        
        CGRect contentRect = {CGPointZero, size};
        ReaderContentView * contentView = [[ReaderContentView alloc] initWithFrame:contentRect PDFDocRef:documentRef fileURL:nil page:pageNumber+1 superviewWidth:[UIScreen mainScreen].bounds.size.width];
        return contentView;
    }
    return nil;
}

- (NSArray<PDFFont *> *)getFontsForPageNumber:(NSInteger)pageNumber {
    CGPDFPageRef page = [self pageWithIndex:pageNumber];
    PDFSearcher *searh = [PDFSearcher new];
    PDFPage * pageInfo = [searh pageInfoForPDFPage:page];

    return pageInfo.fonts;
}

@end
