//
//  PDFPage.h
//  PDFKit
//
//  Created by FLS on 23/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>


@interface TextPosition : NSObject

@property (nonatomic) CGPoint origin;
@property (nonatomic) NSUInteger location;
@property (nonatomic, copy) NSString *fontName;
@property (nonatomic) CGSize fontSize;

@end


@interface PDFPage : NSObject

@property (nonatomic, readonly) NSString *unicodeContent;
@property (nonatomic, readonly) NSArray <TextPosition*> * positionsByLocation;

- (instancetype) initWithContent:(NSString*)content textPositions:(NSArray <TextPosition*>*)positionsByLocation;

- (CGRect) rectForTextRange:(NSRange)range;
@end
