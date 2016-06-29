//
//  SearchResults.m
//  PDFKit
//
//  Created by FLS on 29/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import "SearchResults.h"

@implementation SearchResults

- (instancetype)initWithRect:(CGRect)rect {
    if (self = [super init]) {
        _textRect = rect;
//        _nextText = @"test";
    }
    return self;
}


- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@ Text: %@\n", [super description], NSStringFromCGRect(_textRect), _nextText];
}

@end
