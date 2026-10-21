#import "ChildUIKit.h"

@implementation ChildUI

+ (UIColor *)creamBackground {
    return [UIColor colorWithRed:1.00 green:0.98 blue:0.94 alpha:1.0];
}

+ (UIColor *)skyBackground {
    return [UIColor colorWithRed:0.91 green:0.95 blue:0.98 alpha:1.0];
}

+ (UIColor *)brownText {
    return [UIColor colorWithRed:0.24 green:0.18 blue:0.12 alpha:1.0];
}

+ (UIColor *)calmGreen {
    return [UIColor colorWithRed:0.16 green:0.55 blue:0.36 alpha:1.0];
}

+ (UIColor *)pinkAccent     { return [UIColor colorWithRed:1.00 green:0.56 blue:0.64 alpha:1.0]; }
+ (UIColor *)pumpkinOrange  { return [UIColor colorWithRed:1.00 green:0.72 blue:0.38 alpha:1.0]; }
+ (UIColor *)eggYolk        { return [UIColor colorWithRed:1.00 green:0.85 blue:0.24 alpha:1.0]; }
+ (UIColor *)mintGreen      { return [UIColor colorWithRed:0.48 green:0.83 blue:0.54 alpha:1.0]; }
+ (UIColor *)skyBlue        { return [UIColor colorWithRed:0.37 green:0.77 blue:0.90 alpha:1.0]; }
+ (UIColor *)lavender       { return [UIColor colorWithRed:0.71 green:0.55 blue:1.00 alpha:1.0]; }

+ (UIColor *)correctGreen   { return [UIColor colorWithRed:0.36 green:0.80 blue:0.50 alpha:1.0]; }
+ (UIColor *)wrongPink      { return [UIColor colorWithRed:1.00 green:0.64 blue:0.70 alpha:1.0]; }

+ (UIColor *)candyColorAtIndex:(NSInteger)index {
    static NSArray<UIColor *> *colors = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        colors = @[
            ChildUI.pinkAccent,
            ChildUI.pumpkinOrange,
            ChildUI.eggYolk,
            ChildUI.mintGreen,
            ChildUI.skyBlue,
            ChildUI.lavender,
        ];
    });
    NSInteger n = (NSInteger)colors.count;
    NSInteger idx = ((index % n) + n) % n;
    return colors[idx];
}

+ (UIFont *)roundedMonoFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *base = [UIFont monospacedDigitSystemFontOfSize:size weight:weight];
    UIFontDescriptor *desc = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    if (desc) {
        return [UIFont fontWithDescriptor:desc size:size];
    }
    return base;
}

+ (UIFont *)roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *desc = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    if (desc) {
        return [UIFont fontWithDescriptor:desc size:size];
    }
    return base;
}

+ (UIFont *)scaledRoundedFontOfSize:(CGFloat)size
                            weight:(UIFontWeight)weight
                         textStyle:(UIFontTextStyle)textStyle
                  maximumPointSize:(CGFloat)maximumPointSize {
    UIFont *base = [self roundedFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:base
                                                       maximumPointSize:MAX(size, maximumPointSize)];
}

+ (UIFont *)scaledRoundedMonoFontOfSize:(CGFloat)size
                                weight:(UIFontWeight)weight
                             textStyle:(UIFontTextStyle)textStyle
                      maximumPointSize:(CGFloat)maximumPointSize {
    UIFont *base = [self roundedMonoFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:base
                                                       maximumPointSize:MAX(size, maximumPointSize)];
}

+ (BOOL)motionEnabled {
    return !UIAccessibilityIsReduceMotionEnabled();
}

+ (void)applySoftShadowOnLayer:(CALayer *)layer {
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = 0.10;
    layer.shadowRadius = 12.0;
    layer.shadowOffset = CGSizeMake(0, 4);
    layer.masksToBounds = NO;
}

@end


#pragma mark - ChildButton

@implementation ChildButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self observeMotionPreference];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self observeMotionPreference];
    return self;
}

- (void)observeMotionPreference {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(motionPreferenceChanged:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)buttonWithTitle:(NSString *)title backgroundColor:(UIColor *)bg {
    ChildButton *btn = [ChildButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    // White fails contrast on the candy palette. Keep text legible even when disabled.
    [btn setTitleColor:ChildUI.brownText forState:UIControlStateNormal];
    [btn setTitleColor:ChildUI.brownText forState:UIControlStateHighlighted];
    [btn setTitleColor:ChildUI.brownText forState:UIControlStateDisabled];
    btn.titleLabel.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightBold];
    btn.titleLabel.adjustsFontSizeToFitWidth = YES;
    btn.titleLabel.minimumScaleFactor = 0.75;
    btn.backgroundColor = bg;
    btn.layer.cornerRadius = 20.0;
    [ChildUI applySoftShadowOnLayer:btn.layer];
    return btn;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (!self.enabled || !ChildUI.motionEnabled || !self.window) {
        [self restoreRestingTransform];
        return;
    }
    [UIView animateWithDuration:highlighted ? 0.10 : 0.18
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    if (!enabled) [self restoreRestingTransform];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    if (hidden) [self restoreRestingTransform];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self restoreRestingTransform];
}

- (void)motionPreferenceChanged:(NSNotification *)notification {
    if (!ChildUI.motionEnabled) [self restoreRestingTransform];
}

- (void)restoreRestingTransform {
    [self.layer removeAllAnimations];
    self.transform = CGAffineTransformIdentity;
}

@end
