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

+ (instancetype)buttonWithTitle:(NSString *)title backgroundColor:(UIColor *)bg {
    ChildButton *btn = [ChildButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightBold];
    btn.backgroundColor = bg;
    btn.layer.cornerRadius = 20.0;
    [ChildUI applySoftShadowOnLayer:btn.layer];
    [btn addTarget:btn action:@selector(_pressDown) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:btn action:@selector(_pressUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return btn;
}

- (void)_pressDown {
    [UIView animateWithDuration:0.10 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:nil];
}

- (void)_pressUp {
    [UIView animateWithDuration:0.20 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5
                        options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
