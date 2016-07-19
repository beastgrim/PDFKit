//
//	ReaderContentView.m
//	Reader v2.5.5
//
//	Created by Julius Oklamcak on 2011-07-01.
//	Copyright © 2011-2012 Julius Oklamcak. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderConstants.h"
#import "ReaderContentView.h"
#import "ReaderContentPage.h"

#import <QuartzCore/QuartzCore.h>

@interface ReaderContentView ()

@property (nonatomic, retain) ReaderContentPage *contentPage;
@property (nonatomic, retain) ReaderContentThumb *thumbView;

@end

@implementation ReaderContentView

#pragma mark Constants

#define PAGE_THUMB_LARGE 240
#define PAGE_THUMB_SMALL 144

#pragma mark Properties

@synthesize contentPage = _contentPage;
@synthesize thumbView = _thumbView;
@synthesize realPageHeight = _realPageHeight;
@synthesize realPageWidth = _realPageWidth;
@synthesize zoom = _zoom;

- (id)initWithFrame:(CGRect)aFrame PDFDocRef:(CGPDFDocumentRef)aPDFDocRef fileURL:(NSURL *)aFileURL
    page:(NSUInteger)aPage superviewWidth:(CGFloat)aSuperviewWidth
{
	if (self = [super initWithFrame:aFrame])
	{
		self.backgroundColor = [UIColor whiteColor];
		self.userInteractionEnabled = NO;
        self.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
        self.layer.shadowRadius = 4.0f;
        self.layer.shadowOpacity = 1.0f;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;

		self.contentPage = [[ReaderContentPage alloc] initWithPDFDocRef:aPDFDocRef page:aPage];
        self.realPageHeight = self.contentPage.bounds.size.height;
        self.realPageWidth = self.contentPage.bounds.size.width;
        self.zoom = aSuperviewWidth / self.realPageWidth;
        
		if (self.contentPage != nil) // Must have a valid and initialized content view
		{
			self.thumbView = [[ReaderContentThumb alloc] initWithFrame:self.contentPage.frame];

			[self addSubview:self.thumbView]; // Add the thumb view to the container view
			[self addSubview:self.contentPage]; // Add the content view to the container view
		}

		self.tag = aPage; // Tag the view with the page number
	}

	return self;
}

- (void)resizeContents:(CGFloat)scaleFactor
{
    self.contentPage.frame = CGRectMake(0, 0,
        self.contentPage.frame.size.width * scaleFactor, self.contentPage.frame.size.height * scaleFactor);
    self.thumbView.frame = CGRectMake(0, 0,
        self.thumbView.frame.size.width * scaleFactor, self.thumbView.frame.size.height * scaleFactor);
    if (self.thumbView.imageView.image)
    {
        [self.thumbView showImage:self.thumbView.imageView.image];
    }
}

- (void)dealloc
{
    self.contentPage = nil;
    self.thumbView = nil;
}

- (void)showPageThumb:(NSURL *)aFileURL page:(NSInteger)aPage documentId:(NSInteger)aDocumentId
{
//    BOOL large = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad); // Page thumb size

//	CGSize size = (large ? CGSizeMake(PAGE_THUMB_LARGE, PAGE_THUMB_LARGE)
//     : CGSizeMake(PAGE_THUMB_SMALL, PAGE_THUMB_SMALL));

//    ReaderThumbRequest *request = [[ReaderThumbRequest alloc] initWithView:self.thumbView
//        PDFDocRef:self.contentPage.PDFDocRef documentId:aDocumentId page:aPage size:size];
//	UIImage *image = [[ReaderThumbCache sharedInstance] thumbRequest:request priority:YES]; // Request the page thumb

//	if ([image isKindOfClass:[UIImage class]])
//    {
//        [self.thumbView showImage:image]; // Show image from cache
//    }
}

- (id)singleTap:(UITapGestureRecognizer *)recognizer
{
	return [self.contentPage singleTap:recognizer];
}

@end

#pragma mark -

//
//	ReaderContentThumb class implementation
//

@implementation ReaderContentThumb


#pragma mark ReaderContentThumb instance methods

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) // Superclass init
	{
		self.imageView.contentMode = UIViewContentModeScaleAspectFill;
		self.imageView.clipsToBounds = YES; // Needed for aspect fill
	}

	return self;
}

- (void)showImage:(UIImage *)image
{
    self.imageView.frame = self.frame;
	self.imageView.image = image; // Show image
}

@end
