//
//  SearchResults.h
//  PDFKit
//
//  Created by FLS on 29/06/16.
//  Copyright © 2016 Evgeny Bogomolov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SearchResults : NSObject
@property (nonatomic, readonly) CGRect textRect;
@property (nonatomic) NSString  * _Nullable nextText;

+ (instancetype) __unavailable new;
- (instancetype) __unavailable init;

- (instancetype) initWithRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END