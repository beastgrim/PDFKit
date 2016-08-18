//
//  PDFPage.h
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "PDFFont.h"

@interface TextPosition : NSObject

@property (nonatomic) CGPoint origin;
@property (nonatomic) NSUInteger location;
@property (nonatomic, copy) NSString *fontName;
@property (nonatomic) CGSize fontSize;
@property (nonatomic) CGAffineTransform transform;

@end


@interface PDFPage : NSObject

@property (nonatomic, readonly) NSString *unicodeContent;
@property (nonatomic, readonly) NSArray <TextPosition*> * positionsByLocation;
@property (nonatomic, readonly) CGSize pageSize;
@property (nonatomic) NSArray <PDFFont*> * fonts;

- (instancetype) initWithSize:(CGSize)pageSize content:(NSString*)content textPositions:(NSArray <TextPosition*>*)positionsByLocation;

- (CGRect) rectForTextRange:(NSRange)range;
@end
