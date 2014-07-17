//
//  BFPaperTableViewCell.m
//  BFPaperKit
//
//  Created by Bence Feher on 7/11/14.
//  Copyright (c) 2014 Bence Feher. All rights reserved.
//

#import "BFPaperTableViewCell.h"

@interface BFPaperTableViewCell ()
@property CGPoint tapPoint;
@property CALayer *backgroundColorFadeLayer;
@property CALayer *animationLayer;
@property CAShapeLayer *maskLayer;
@property BOOL beganHighlight;
@property BOOL beganSelection;
@property BOOL haveTapped;
@property BOOL letGo;
@property BOOL growthFinished;
@end

@implementation BFPaperTableViewCell
// Constants used for tweaking the look/feel of:
// -animation durations:
static CGFloat const bfPaperCell_animationDurationConstant       = 0.2f;
static CGFloat const bfPaperCell_tapCircleGrowthDurationConstant = bfPaperCell_animationDurationConstant * 2;
// -the tap-circle's size:
static CGFloat const bfPaperCell_tapCircleDiameterStartValue     = 5.f;    // for the mask
// -the tap-circle's beauty:
static CGFloat const bfPaperCell_tapFillConstant                 = 0.16f;  // or 0.12f if you like a bit darker
static CGFloat const bfPaperCell_clearBGTapFillConstant          = 0.1f;  // or 0.1f if you like a bit darker
static CGFloat const bfPaperCell_clearBGFadeConstant             = 0.12f;  // or 0.1f if you like a bit darker

#define BFPAPERCELL__DUMB_TAP_FILL_COLOR             [UIColor colorWithWhite:0.2 alpha:bfPaperCell_tapFillConstant]
#define BFPAPERCELL__CLEAR_BG_DUMB_TAP_FILL_COLOR    [UIColor colorWithWhite:0.3 alpha:bfPaperCell_clearBGTapFillConstant]
#define BFPAPERCELL__CLEAR_BG_DUMB_FADE_COLOR        [UIColor colorWithWhite:0.3 alpha:1]


#pragma mark - Default Initializers
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        NSLog(@"Initing with style");
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
    NSLog(@"awaking from Nib");
    [self setup];
}


#pragma mark - Setup
- (void)setup
{
    // Defaults:
    self.usesSmartColor = YES;
    self.tapCircleColor = nil;
    self.backgroundFadeColor = nil;
    self.tapCircleDiameter = -1.f;
    self.rippleFromTapLocation = YES;
    
    self.layer.masksToBounds = YES;
    self.clipsToBounds = YES;

    self.textLabel.text = @"BFPaperTableViewCell";
    self.textLabel.backgroundColor = [UIColor clearColor];
    
    self.maskLayer.frame = self.frame;
    
    CGRect endRect = CGRectMake(self.contentView.bounds.origin.x, self.contentView.bounds.origin.y , self.contentView.frame.size.width, self.contentView.frame.size.height);
    
    // Setup animation layer:
    self.animationLayer = [[CALayer alloc] init];
    self.animationLayer.frame = endRect;
    [self.contentView.layer insertSublayer:self.animationLayer atIndex:0];
    
    // Setup background fade layer:
    self.backgroundColorFadeLayer = [[CALayer alloc] init];
    self.backgroundColorFadeLayer.frame = endRect;
    self.backgroundColorFadeLayer.backgroundColor = self.backgroundFadeColor.CGColor;
    [self.contentView.layer insertSublayer:self.backgroundColorFadeLayer atIndex:0];

    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:nil];
    tapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:tapGestureRecognizer];
}



#pragma Parent Overides
/*- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    if (self.beganSelection) {
        return;
    }
    self.beganSelection = YES;
    self.beganHighlight = NO;

    // Configure the view for the selected state
    NSLog(@"selecting now");
    
//    [self shrinkTapCircle];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    if (self.beganHighlight
        ||
        !self.haveTapped) {
        return;
    }
    self.beganHighlight = YES;
    self.beganSelection = NO;
    
    // Configure the view for the highlighted state
    NSLog(@"highlighting now");
    
//    [self growTapCircle];
}*/

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];

    self.letGo = NO;
    self.growthFinished = NO;

    [self growTapCircle];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    self.letGo = YES;
    
    if (self.growthFinished) {
        [self growTapCircleABit];
    }
    [self fadeTapCircleOut];
    [self fadeBGOutAndBringShadowBackToStart];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];

    self.letGo = YES;
    
    if (self.growthFinished) {
        [self growTapCircleABit];
    }
    [self fadeTapCircleOut];
    [self fadeBGOutAndBringShadowBackToStart];
}


#pragma mark - Setters and Getters
- (void)setUsesSmartColor:(BOOL)usesSmartColor
{
    _usesSmartColor = usesSmartColor;
    self.tapCircleColor = nil;
    self.backgroundFadeColor = nil;
}


#pragma mark - Gesture Recognizer Delegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    
    CGPoint location = [touch locationInView:self];
    //NSLog(@"location: x = %0.2f, y = %0.2f", location.x, location.y);
    self.tapPoint = location;
    
    self.haveTapped = YES;
    
    return NO;  // Disallow recognition of tap gestures. We just needed this to grab that tasty tap location.
}


#pragma mark - Animation:
- (void)growTapCircle
{
    NSLog(@"expanding a tap circle");
    // Spawn a growing circle that "ripples" through the button:
    
    CGRect endRect = CGRectMake(self.bounds.origin.x, self.bounds.origin.y , self.frame.size.width, self.frame.size.height);
    
    self.animationLayer.frame = endRect;
    
    // Set the fill color for the tap circle (self.animationLayer's fill color):
    if (!self.tapCircleColor) {
        self.tapCircleColor = self.usesSmartColor ? [self.textLabel.textColor colorWithAlphaComponent:bfPaperCell_clearBGTapFillConstant] : BFPAPERCELL__CLEAR_BG_DUMB_TAP_FILL_COLOR;
    }
        
    if (!self.backgroundFadeColor) {
        self.backgroundFadeColor = self.usesSmartColor ? self.textLabel.textColor : BFPAPERCELL__CLEAR_BG_DUMB_FADE_COLOR;
    }
        
        // Setup background fade layer:
    self.backgroundColorFadeLayer.frame = endRect;
    self.backgroundColorFadeLayer.backgroundColor = self.backgroundFadeColor.CGColor;
        
        // Fade the background color a bit darker:
    CABasicAnimation *fadeBackgroundDarker = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeBackgroundDarker.duration = bfPaperCell_animationDurationConstant;
    fadeBackgroundDarker.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    fadeBackgroundDarker.fromValue = [NSNumber numberWithFloat:0.f];
    fadeBackgroundDarker.toValue = [NSNumber numberWithFloat:bfPaperCell_clearBGFadeConstant];
    fadeBackgroundDarker.fillMode = kCAFillModeForwards;
    fadeBackgroundDarker.removedOnCompletion = NO;
    [self.backgroundColorFadeLayer addAnimation:fadeBackgroundDarker forKey:@"animateOpacity"];
    
    // Set animation layer's background color:
    self.animationLayer.backgroundColor = self.tapCircleColor.CGColor;
    self.animationLayer.borderColor = [UIColor clearColor].CGColor;
    self.animationLayer.borderWidth = 0;
    
    
    // Animation Mask Rects
    CGPoint origin = self.rippleFromTapLocation ? self.tapPoint : CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    NSLog(@"self.center: (x%0.2f, y%0.2f)", self.center.x, self.center.y);
    UIBezierPath *startingTapCirclePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(origin.x - (bfPaperCell_tapCircleDiameterStartValue / 2.f), origin.y - (bfPaperCell_tapCircleDiameterStartValue / 2.f), bfPaperCell_tapCircleDiameterStartValue, bfPaperCell_tapCircleDiameterStartValue) cornerRadius:bfPaperCell_tapCircleDiameterStartValue / 2.f];
    
    CGFloat tapCircleDiameterEndValue = (self.tapCircleDiameter < 0) ? MAX(self.frame.size.width, self.frame.size.height) : self.tapCircleDiameter;
    UIBezierPath *endTapCirclePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(origin.x - (tapCircleDiameterEndValue/ 2.f), origin.y - (tapCircleDiameterEndValue/ 2.f), tapCircleDiameterEndValue, tapCircleDiameterEndValue) cornerRadius:tapCircleDiameterEndValue/ 2.f];
    
    // Animation Mask Layer:
    CAShapeLayer *animationMaskLayer = [CAShapeLayer layer];
    animationMaskLayer.path = endTapCirclePath.CGPath;
    animationMaskLayer.fillColor = [UIColor blackColor].CGColor;
    animationMaskLayer.strokeColor = [UIColor clearColor].CGColor;
    animationMaskLayer.borderColor = [UIColor clearColor].CGColor;
    animationMaskLayer.borderWidth = 0;
    
    self.animationLayer.mask = animationMaskLayer;
    
    // Grow tap-circle animation:
    CABasicAnimation *tapCircleGrowthAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    tapCircleGrowthAnimation.delegate = self;
    [tapCircleGrowthAnimation setValue:@"tapGrowth" forKey:@"id"];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:)];
    tapCircleGrowthAnimation.duration = bfPaperCell_tapCircleGrowthDurationConstant;
    tapCircleGrowthAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    tapCircleGrowthAnimation.fromValue = (__bridge id)startingTapCirclePath.CGPath;
    tapCircleGrowthAnimation.toValue = (__bridge id)endTapCirclePath.CGPath;
    tapCircleGrowthAnimation.fillMode = kCAFillModeForwards;
    tapCircleGrowthAnimation.removedOnCompletion = NO;
    
    // Fade in self.animationLayer:
    CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeIn.duration = bfPaperCell_animationDurationConstant;
    fadeIn.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    fadeIn.fromValue = [NSNumber numberWithFloat:0.f];
    fadeIn.toValue = [NSNumber numberWithFloat:1.f];
    fadeIn.fillMode = kCAFillModeForwards;
    fadeIn.removedOnCompletion = NO;
    
    
    [animationMaskLayer addAnimation:tapCircleGrowthAnimation forKey:@"animatePath"];
    [self.animationLayer addAnimation:fadeIn forKey:@"opacityAnimation"];
}


- (void)animationDidStop:(CAAnimation *)theAnimation2 finished:(BOOL)flag
{
    NSLog(@"animation ENDED");
    self.growthFinished = YES;
}


- (void)fadeBGOutAndBringShadowBackToStart
{
    NSLog(@"fading bg");
    
    CABasicAnimation *removeFadeBackgroundDarker = [CABasicAnimation animationWithKeyPath:@"opacity"];
    removeFadeBackgroundDarker.duration = bfPaperCell_animationDurationConstant;
    removeFadeBackgroundDarker.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    removeFadeBackgroundDarker.fromValue = [NSNumber numberWithFloat:bfPaperCell_clearBGFadeConstant];
    removeFadeBackgroundDarker.toValue = [NSNumber numberWithFloat:0.f];
    removeFadeBackgroundDarker.fillMode = kCAFillModeForwards;
    removeFadeBackgroundDarker.removedOnCompletion = NO;
        
    [self.backgroundColorFadeLayer addAnimation:removeFadeBackgroundDarker forKey:@"removeBGShade"];
}


- (void)growTapCircleABit
{
    NSLog(@"expanding a bit more");
    
    // Animation Mask Rects
    CGFloat newTapCircleStartValue = (self.tapCircleDiameter < 0) ? MAX(self.frame.size.width, self.frame.size.height) : self.tapCircleDiameter;
    
    CGPoint origin = self.rippleFromTapLocation ? self.tapPoint : CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    UIBezierPath *startingTapCirclePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(origin.x - (newTapCircleStartValue / 2.f), origin.y - (newTapCircleStartValue / 2.f), newTapCircleStartValue, newTapCircleStartValue) cornerRadius:newTapCircleStartValue / 2.f];
    
    CGFloat tapCircleDiameterEndValue = (self.tapCircleDiameter < 0) ? MAX(self.frame.size.width, self.frame.size.height) : self.tapCircleDiameter;
    tapCircleDiameterEndValue += 40.f;
    UIBezierPath *endTapCirclePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(origin.x - (tapCircleDiameterEndValue/ 2.f), origin.y - (tapCircleDiameterEndValue/ 2.f), tapCircleDiameterEndValue, tapCircleDiameterEndValue) cornerRadius:tapCircleDiameterEndValue/ 2.f];
    
    // Animation Mask Layer:
    CAShapeLayer *animationMaskLayer = [CAShapeLayer layer];
    animationMaskLayer.path = endTapCirclePath.CGPath;
    animationMaskLayer.fillColor = [UIColor blackColor].CGColor;
    animationMaskLayer.strokeColor = [UIColor clearColor].CGColor;
    animationMaskLayer.borderColor = [UIColor clearColor].CGColor;
    animationMaskLayer.borderWidth = 0;
    
    self.animationLayer.mask = animationMaskLayer;
    
    // Grow tap-circle animation:
    CABasicAnimation *tapCircleGrowthAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    tapCircleGrowthAnimation.duration = bfPaperCell_tapCircleGrowthDurationConstant;
    tapCircleGrowthAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    tapCircleGrowthAnimation.fromValue = (__bridge id)startingTapCirclePath.CGPath;
    tapCircleGrowthAnimation.toValue = (__bridge id)endTapCirclePath.CGPath;
    tapCircleGrowthAnimation.fillMode = kCAFillModeForwards;
    tapCircleGrowthAnimation.removedOnCompletion = NO;
    
    [animationMaskLayer addAnimation:tapCircleGrowthAnimation forKey:@"animatePath"];
}


- (void)fadeTapCircleOut
{
    NSLog(@"Fading away");
    // Fade out self.animationLayer:
    CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeOut.fromValue = [NSNumber numberWithFloat:self.animationLayer.opacity];
    fadeOut.toValue = [NSNumber numberWithFloat:0.f];
    fadeOut.duration = bfPaperCell_tapCircleGrowthDurationConstant;
    fadeOut.fillMode = kCAFillModeForwards;
    fadeOut.removedOnCompletion = NO;
    
    [self.animationLayer addAnimation:fadeOut forKey:@"opacityAnimation"];
}
#pragma mark -


@end
