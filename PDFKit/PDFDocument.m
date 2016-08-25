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

- (NSArray <NSValue*>*)searchText:(NSString *)text onPage:(NSUInteger)pageNumber {
    PDFSearcher *searh = [PDFSearcher new];
    NSArray <NSValue*>*results;
    
    if (pageNumber < _numberOfPages) {
        CGPDFPageRef page = [self pageWithIndex:pageNumber];
        results = [searh searchString:text inPage:page];
        NSLog(@"Searcher find text: %@", searh.unicodeContent);
    }
    
    return results ?: @[];
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

//- (NSArray<PDFFont *> *)getFontsForPageNumber:(NSInteger)pageNumber {
//    CGPDFPageRef page = [self pageWithIndex:pageNumber];
//    PDFSearcher *searh = [PDFSearcher new];
//    PDFPage * pageInfo = [searh pageInfoForPDFPage:page];
//
//    return pageInfo.fonts;
//}

@end
