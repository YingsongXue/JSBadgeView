/*
 Copyright (c) 2014 Xue Yingsong.
 
 Thanks to Javier Soto.
 Source: https://github.com/JaviSoto/JSBadgeView
 
 Keyworlds: BadgeView BadgeNumber Badge

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "JSBadgeView.h"

#import <QuartzCore/QuartzCore.h>
#include <mach-o/dyld.h>

//#if !__has_feature(objc_arc)
//#error JSBadgeView must be compiled with ARC.
//#endif

//Compatible for ARC or NOARC
#if !defined(__clang__) || __clang_major__ < 3
    #ifndef __bridge
        #define __bridge
    #endif

    #ifndef __bridge_retain
        #define __bridge_retain
    #endif

    #ifndef __bridge_retained
        #define __bridge_retained
    #endif

    #ifndef __autoreleasing
        #define __autoreleasing
    #endif

    #ifndef __strong
        #define __strong
    #endif

    #ifndef __unsafe_unretained
        #define __unsafe_unretained
    #endif

    #ifndef __weak
        #define __weak
    #endif
#endif

#if __has_feature(objc_arc)
    #define SAFE_ARC_PROP_RETAIN strong
    #define SAFE_ARC_RETAIN(x) (x)
    #define SAFE_ARC_RELEASE(x)
    #define SAFE_ARC_AUTORELEASE(x) (x)
    #define SAFE_ARC_BLOCK_COPY(x) (x)
    #define SAFE_ARC_BLOCK_RELEASE(x)
    #define SAFE_ARC_SUPER_DEALLOC()
    #define SAFE_ARC_AUTORELEASE_POOL_START() @autoreleasepool {
    #define SAFE_ARC_AUTORELEASE_POOL_END() }
#else
    #define SAFE_ARC_PROP_RETAIN retain
    #define SAFE_ARC_RETAIN(x) ([(x) retain])
    #define SAFE_ARC_RELEASE(x) ([(x) release])
    #define SAFE_ARC_AUTORELEASE(x) ([(x) autorelease])
    #define SAFE_ARC_BLOCK_COPY(x) (Block_copy(x))
    #define SAFE_ARC_BLOCK_RELEASE(x) (Block_release(x))
    #define SAFE_ARC_SUPER_DEALLOC() ([super dealloc])
    #define SAFE_ARC_AUTORELEASE_POOL_START() NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    #define SAFE_ARC_AUTORELEASE_POOL_END() [pool release];
#endif

// Silencing some deprecation warnings if your deployment target is iOS7 that can only be fixed by using methods that
// Are only available on iOS7.
// Soon JSBadgeView will require iOS 7 and we'll be able to use the new methods.
#if  __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
    #define JSBadgeViewSilenceDeprecatedMethodStart()   _Pragma("clang diagnostic push") \
                                                        _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
    #define JSBadgeViewSilenceDeprecatedMethodEnd()     _Pragma("clang diagnostic pop")
#else
    #define JSBadgeViewSilenceDeprecatedMethodStart()
    #define JSBadgeViewSilenceDeprecatedMethodEnd()
#endif

static const CGFloat JSBadgeViewShadowRadius = 1.0f;
static const CGFloat JSBadgeViewHeight = 16.0f;
static const CGFloat JSBadgeViewTextSideMargin = 8.0f;
static const CGFloat JSBadgeViewCornerRadius = 10.0f;

// add for iOS 6 compatible
#define kDefaultBadgeTextColor [UIColor whiteColor]
#define kDefaultBadgeBackgroundColor [UIColor redColor]
#define kDefaultOverlayColor [UIColor colorWithWhite:1.0f alpha:0.3]
#define kDefaultBadgeTextFont [UIFont boldSystemFontOfSize:[UIFont systemFontSize]]
#define kDefaultBadgeShadowColor [UIColor clearColor]
static const JSBadgeViewAlignment *kDefaultBadgeAlignment = JSBadgeViewAlignmentTopRight;

// Thanks to Peter Steinberger: https://gist.github.com/steipete/6526860
static BOOL JSBadgeViewIsUIKitFlatMode(void)
{
    static BOOL isUIKitFlatMode = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.2
#endif
#ifndef UIKitVersionNumber_iOS_7_0
#define UIKitVersionNumber_iOS_7_0 0xB57
#endif
        // We get the modern UIKit if system is running >= iOS 7 and we were linked with >= SDK 7.
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
            isUIKitFlatMode = (NSVersionOfLinkTimeLibrary("UIKit") >> 16) >= UIKitVersionNumber_iOS_7_0;
        }
    });

    return isUIKitFlatMode;
}

@implementation JSBadgeView

- (void)dealloc
{
    SAFE_ARC_RELEASE(_badgeText);
    SAFE_ARC_RELEASE(_badgeTextColor);
    SAFE_ARC_RELEASE(_badgeTextShadowColor);
    SAFE_ARC_RELEASE(_badgeTextFont);
    SAFE_ARC_RELEASE(_badgeBackgroundColor);
    SAFE_ARC_RELEASE(_badgeOverlayColor);
    SAFE_ARC_RELEASE(_badgeShadowColor);
    SAFE_ARC_RELEASE(_badgeStrokeColor);
    
    SAFE_ARC_SUPER_DEALLOC();
}

+ (void)applyCommonStyle
{
    JSBadgeView *badgeViewAppearanceProxy = JSBadgeView.appearance;

    badgeViewAppearanceProxy.backgroundColor = UIColor.clearColor;
    badgeViewAppearanceProxy.badgeAlignment = JSBadgeViewAlignmentTopRight;
    badgeViewAppearanceProxy.badgeBackgroundColor = UIColor.redColor;
    badgeViewAppearanceProxy.badgeTextFont = [UIFont boldSystemFontOfSize:UIFont.systemFontSize];
    badgeViewAppearanceProxy.badgeTextColor = UIColor.whiteColor;
}

+ (void)applyLegacyStyle
{
    JSBadgeView *badgeViewAppearanceProxy = JSBadgeView.appearance;

    badgeViewAppearanceProxy.badgeOverlayColor = [UIColor colorWithWhite:1.0f alpha:0.3];
    badgeViewAppearanceProxy.badgeTextShadowColor = UIColor.clearColor;
    badgeViewAppearanceProxy.badgeShadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    badgeViewAppearanceProxy.badgeShadowSize = CGSizeMake(0.0f, 3.0f);
    badgeViewAppearanceProxy.badgeStrokeWidth = 2.0f;
    badgeViewAppearanceProxy.badgeStrokeColor = UIColor.whiteColor;
}

+ (void)applyIOS7Style
{
    JSBadgeView *badgeViewAppearanceProxy = JSBadgeView.appearance;

    badgeViewAppearanceProxy.badgeOverlayColor = UIColor.clearColor;
    badgeViewAppearanceProxy.badgeTextShadowColor = UIColor.clearColor;
    badgeViewAppearanceProxy.badgeShadowColor = UIColor.clearColor;
    badgeViewAppearanceProxy.badgeStrokeWidth = 0.0f;
    badgeViewAppearanceProxy.badgeStrokeColor = badgeViewAppearanceProxy.badgeBackgroundColor;
}

+ (void)initialize
{
    if (self == JSBadgeView.class)
    {
        if (JSBadgeViewIsUIKitFlatMode())
        {
            [self applyCommonStyle];
            [self applyIOS7Style];
        }
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self initConfig];
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self initConfig];
    }
    
    return self;
}

- (id)initWithParentView:(UIView *)parentView alignment:(JSBadgeViewAlignment)alignment
{
    if ((self = [self initWithFrame:CGRectZero]))
    {
        self.badgeAlignment = alignment;
        [parentView addSubview:self];
        [self initConfig];
    }
    
    return self;
}

- (void)initConfig
{
    if(!JSBadgeViewIsUIKitFlatMode())
    {
        self.backgroundColor = [UIColor clearColor];
        
        self.badgeAlignment = kDefaultBadgeAlignment;
        
        self.badgeBackgroundColor = kDefaultBadgeBackgroundColor;
        self.badgeOverlayColor = kDefaultOverlayColor;
        self.badgeTextColor = kDefaultBadgeTextColor;
        self.badgeTextShadowColor = kDefaultBadgeShadowColor;
        self.badgeTextFont = kDefaultBadgeTextFont;
    }
}

#pragma mark - Layout

- (CGFloat)marginToDrawInside
{
    return self.badgeStrokeWidth * 2.0f;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect newFrame = self.frame;
    const CGRect superviewBounds = CGRectIsEmpty(_frameToPositionInRelationWith) ? self.superview.bounds : _frameToPositionInRelationWith;
    
    const CGFloat textWidth = [self sizeOfTextForCurrentSettings].width;

    const CGFloat marginToDrawInside = [self marginToDrawInside];
    const CGFloat viewWidth = textWidth + JSBadgeViewTextSideMargin + (marginToDrawInside * 2);
    const CGFloat viewHeight = JSBadgeViewHeight + (marginToDrawInside * 2);
    
    const CGFloat superviewWidth = superviewBounds.size.width;
    const CGFloat superviewHeight = superviewBounds.size.height;
    
    newFrame.size.width = viewWidth;
    newFrame.size.height = viewHeight;
    
    switch (self.badgeAlignment) {
        case JSBadgeViewAlignmentTopLeft:
            newFrame.origin.x = -viewWidth / 2.0f;
            newFrame.origin.y = -viewHeight / 2.0f;
            break;
        case JSBadgeViewAlignmentTopRight:
            newFrame.origin.x = superviewWidth - (viewWidth / 2.0f);
            newFrame.origin.y = -viewHeight / 2.0f;
            break;
        case JSBadgeViewAlignmentTopCenter:
            newFrame.origin.x = (superviewWidth - viewWidth) / 2.0f;
            newFrame.origin.y = -viewHeight / 2.0f;
            break;
        case JSBadgeViewAlignmentCenterLeft:
            newFrame.origin.x = -viewWidth / 2.0f;
            newFrame.origin.y = (superviewHeight - viewHeight) / 2.0f;
            break;
        case JSBadgeViewAlignmentCenterRight:
            newFrame.origin.x = superviewWidth - (viewWidth / 2.0f);
            newFrame.origin.y = (superviewHeight - viewHeight) / 2.0f;
            break;
        case JSBadgeViewAlignmentBottomLeft:
            newFrame.origin.x = -viewWidth / 2.0f;
            newFrame.origin.y = superviewHeight - (viewHeight / 2.0f);
            break;
        case JSBadgeViewAlignmentBottomRight:
            newFrame.origin.x = superviewWidth - (viewWidth / 2.0f);
            newFrame.origin.y = superviewHeight - (viewHeight / 2.0f);
            break;
        case JSBadgeViewAlignmentBottomCenter:
            newFrame.origin.x = (superviewWidth - viewWidth) / 2.0f;
            newFrame.origin.y = superviewHeight - (viewHeight / 2.0f);
            break;
        case JSBadgeViewAlignmentCenter:
            newFrame.origin.x = (superviewWidth - viewWidth) / 2.0f;
            newFrame.origin.y = (superviewHeight - viewHeight) / 2.0f;
            break;
        default:
            NSAssert(NO, @"Unimplemented JSBadgeAligment type %lul", (unsigned long)self.badgeAlignment);
    }
    
    newFrame.origin.x += _badgePositionAdjustment.x;
    newFrame.origin.y += _badgePositionAdjustment.y;
    
    // Do not set frame directly so we do not interfere with any potential transform set on the view.
    self.bounds = CGRectIntegral(CGRectMake(0, 0, CGRectGetWidth(newFrame), CGRectGetHeight(newFrame)));
    self.center = CGPointMake(ceilf(CGRectGetMidX(newFrame)), ceilf(CGRectGetMidY(newFrame)));
    
    [self setNeedsDisplay];
}

#pragma mark - Private

- (CGSize)sizeOfTextForCurrentSettings
{
    JSBadgeViewSilenceDeprecatedMethodStart();
    return [self.badgeText sizeWithFont:self.badgeTextFont];
    JSBadgeViewSilenceDeprecatedMethodEnd();
}

#pragma mark - Setters

- (void)setBadgeAlignment:(JSBadgeViewAlignment)badgeAlignment
{
    if (badgeAlignment != _badgeAlignment)
    {
        _badgeAlignment = badgeAlignment;

        [self setNeedsLayout];
    }
}

- (void)setBadgePositionAdjustment:(CGPoint)badgePositionAdjustment
{
    _badgePositionAdjustment = badgePositionAdjustment;
    
    [self setNeedsLayout];
}

- (void)setBadgeText:(NSString *)badgeText
{
    if (badgeText != _badgeText)
    {
        SAFE_ARC_RELEASE(_badgeText);
        _badgeText = [badgeText copy];
        
        [self setNeedsLayout];
    }
}

- (void)setBadgeTextColor:(UIColor *)badgeTextColor
{
    if (badgeTextColor != _badgeTextColor)
    {
        SAFE_ARC_RELEASE(_badgeTextColor);
        _badgeTextColor = SAFE_ARC_RETAIN(badgeTextColor);
        
        [self setNeedsDisplay];
    }
}

- (void)setBadgeTextShadowColor:(UIColor *)badgeTextShadowColor
{
    if (badgeTextShadowColor != _badgeTextShadowColor)
    {
        SAFE_ARC_RELEASE(_badgeTextShadowColor);
        _badgeTextShadowColor = SAFE_ARC_RETAIN(badgeTextShadowColor);
        
        [self setNeedsDisplay];
    }
}

- (void)setBadgeTextShadowOffset:(CGSize)badgeTextShadowOffset
{
    _badgeTextShadowOffset = badgeTextShadowOffset;
    
    [self setNeedsDisplay];
}

- (void)setBadgeTextFont:(UIFont *)badgeTextFont
{
    if (badgeTextFont != _badgeTextFont)
    {
        SAFE_ARC_RELEASE(_badgeTextFont);
        _badgeTextFont = SAFE_ARC_RETAIN(badgeTextFont);
        
        [self setNeedsDisplay];
    }
}

- (void)setBadgeBackgroundColor:(UIColor *)badgeBackgroundColor
{
    if (badgeBackgroundColor != _badgeBackgroundColor)
    {
        SAFE_ARC_RELEASE(_badgeStrokeColor);
        _badgeBackgroundColor = SAFE_ARC_RETAIN(badgeBackgroundColor);
        
        [self setNeedsDisplay];
    }
}

- (void)setBadgeStrokeWidth:(CGFloat)badgeStrokeWidth
{
    if (badgeStrokeWidth != _badgeStrokeWidth)
    {
        _badgeStrokeWidth = badgeStrokeWidth;

        [self setNeedsLayout];
        [self setNeedsDisplay];
    }
}

- (void)setBadgeStrokeColor:(UIColor *)badgeStrokeColor
{
    if (badgeStrokeColor != _badgeStrokeColor)
    {
        SAFE_ARC_RELEASE(_badgeStrokeColor);
        _badgeStrokeColor = SAFE_ARC_RETAIN(badgeStrokeColor);
        
        [self setNeedsDisplay];
    }
}

- (void)setBadgeShadowColor:(UIColor *)badgeShadowColor
{
    if (badgeShadowColor != _badgeShadowColor)
    {
        SAFE_ARC_RELEASE(_badgeShadowColor);
        _badgeShadowColor = SAFE_ARC_RETAIN(badgeShadowColor);
        
        [self setNeedsDisplay];
    }
}

- (void)setBadgeShadowSize:(CGSize)badgeShadowSize
{
    if (!CGSizeEqualToSize(badgeShadowSize, _badgeShadowSize))
    {
        _badgeShadowSize = badgeShadowSize;

        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    const BOOL anyTextToDraw = (self.badgeText.length > 0);
    
    if (anyTextToDraw)
    {
        CGContextRef ctx = UIGraphicsGetCurrentContext();

        const CGFloat marginToDrawInside = [self marginToDrawInside];
        const CGRect rectToDraw = CGRectInset(rect, marginToDrawInside, marginToDrawInside);
        
        UIBezierPath *borderPath = [UIBezierPath bezierPathWithRoundedRect:rectToDraw byRoundingCorners:(UIRectCorner)UIRectCornerAllCorners cornerRadii:CGSizeMake(JSBadgeViewCornerRadius, JSBadgeViewCornerRadius)];
        
        /* Background and shadow */
        CGContextSaveGState(ctx);
        {
            CGContextAddPath(ctx, borderPath.CGPath);
            
            CGContextSetFillColorWithColor(ctx, self.badgeBackgroundColor.CGColor);
            CGContextSetShadowWithColor(ctx, self.badgeShadowSize, JSBadgeViewShadowRadius, self.badgeShadowColor.CGColor);
            
            CGContextDrawPath(ctx, kCGPathFill);
        }
        CGContextRestoreGState(ctx);
        
        const BOOL colorForOverlayPresent = self.badgeOverlayColor && ![self.badgeOverlayColor isEqual:[UIColor clearColor]];
        
        if (colorForOverlayPresent)
        {
            /* Gradient overlay */
            CGContextSaveGState(ctx);
            {
                CGContextAddPath(ctx, borderPath.CGPath);
                CGContextClip(ctx);
                
                const CGFloat height = rectToDraw.size.height;
                const CGFloat width = rectToDraw.size.width;
                
                const CGRect rectForOverlayCircle = CGRectMake(rectToDraw.origin.x,
                                                               rectToDraw.origin.y - ceilf(height * 0.5),
                                                               width,
                                                               height);

                CGContextAddEllipseInRect(ctx, rectForOverlayCircle);
                CGContextSetFillColorWithColor(ctx, self.badgeOverlayColor.CGColor);

                CGContextDrawPath(ctx, kCGPathFill);
            }
            CGContextRestoreGState(ctx);
        }
        
        /* Stroke */
        CGContextSaveGState(ctx);
        {
            CGContextAddPath(ctx, borderPath.CGPath);
            
            CGContextSetLineWidth(ctx, self.badgeStrokeWidth);
            CGContextSetStrokeColorWithColor(ctx, self.badgeStrokeColor.CGColor);
            
            CGContextDrawPath(ctx, kCGPathStroke);
        }
        CGContextRestoreGState(ctx);
        
        /* Text */

        CGContextSaveGState(ctx);
        {
            CGContextSetFillColorWithColor(ctx, self.badgeTextColor.CGColor);
            CGContextSetShadowWithColor(ctx, self.badgeTextShadowOffset, 1.0, self.badgeTextShadowColor.CGColor);
            
            CGRect textFrame = rectToDraw;
            const CGSize textSize = [self sizeOfTextForCurrentSettings];
            
            textFrame.size.height = textSize.height;
            textFrame.origin.y = rectToDraw.origin.y + ceilf((rectToDraw.size.height - textFrame.size.height) / 2.0f);

            JSBadgeViewSilenceDeprecatedMethodStart();
            [self.badgeText drawInRect:textFrame
                              withFont:self.badgeTextFont
                         lineBreakMode:NSLineBreakByClipping
                             alignment:NSTextAlignmentCenter];
            JSBadgeViewSilenceDeprecatedMethodEnd();
        }
        CGContextRestoreGState(ctx);
    }
}

@end
