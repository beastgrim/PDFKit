//
//  PDFPage.m
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import "PDFPage.h"
#import <UIKit/UIKit.h>

@implementation TextPosition

- (NSString *)description {
    return [NSString stringWithFormat:@"Position: %@ Location: %ld", NSStringFromCGPoint(_origin), (unsigned long)_location];
}
@end


@implementation PDFPage


- (instancetype)initWithContent:(NSString *)content textPositions:(NSArray <TextPosition*>*)positionsByLocation {
    self = [super init];
    if (self) {
        _unicodeContent = content;
        _positionsByLocation = positionsByLocation;
    }
    return self;
}


#pragma mark - Public

- (CGRect)rectForTextRange:(NSRange)range {
    
    if (range.location > _unicodeContent.length) return CGRectNull;
    
    TextPosition *tp = nil;
    for (TextPosition *pos in _positionsByLocation) {
        
        if (pos.location > range.location) {
            break;
        }
        
        tp = pos;
    }
        
    CGFloat offsetX = (range.location - tp.location)*tp.fontSize.width;
    CGFloat width = tp.fontSize.width*range.length;
    return CGRectMake(tp.origin.x + offsetX, tp.origin.y, width, tp.fontSize.height);
}

- (NSString *)description {
//    NSLog(@"UTF CONTENT:\n%@\nPOS MAP:\n%@", _unicodeContent, _positionsByLocation);
    return [NSString stringWithFormat:@"UTF CONTENT:\n%@\nPOS MAP:\n%@", _unicodeContent, _positionsByLocation];
}
@end
