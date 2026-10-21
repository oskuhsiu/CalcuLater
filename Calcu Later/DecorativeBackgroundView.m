#import "DecorativeBackgroundView.h"
#import "ChildUIKit.h"

@interface DecorativeBackgroundView ()
@property (nonatomic, assign) BackgroundTheme theme;
@property (nonatomic, assign) CGSize builtSize;  // 已依此 size 擺好裝飾；size 變動時重建
@end

@implementation DecorativeBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self excludeDecorationFromInteraction];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self excludeDecorationFromInteraction];
    return self;
}

- (void)excludeDecorationFromInteraction {
    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = NO;
    self.accessibilityElementsHidden = YES;
}

+ (instancetype)backgroundWithTheme:(BackgroundTheme)theme {
    DecorativeBackgroundView *v = [[self alloc] initWithFrame:CGRectZero];
    v.theme = theme;
    [v applyBaseColor];
    return v;
}

+ (instancetype)installInViewController:(UIViewController *)vc theme:(BackgroundTheme)theme {
    DecorativeBackgroundView *bg = [self backgroundWithTheme:theme];
    bg.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view insertSubview:bg atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [bg.topAnchor constraintEqualToAnchor:vc.view.topAnchor],
        [bg.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor],
        [bg.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor],
        [bg.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor],
    ]];
    return bg;
}

- (void)applyBaseColor {
    switch (self.theme) {
        case BackgroundThemeMainMenu:
            self.backgroundColor = [self rgb:0xE8F4FB];  // 淡天藍
            break;
        case BackgroundThemeLessons:
            self.backgroundColor = [self rgb:0xFFF6E5];  // 米黃便條
            break;
        case BackgroundThemeDrill:
            self.backgroundColor = [self rgb:0xEAF7EE];  // 淡薄荷
            break;
        case BackgroundThemeMultiplication:
            self.backgroundColor = [self rgb:0xFFF3E0];  // 淡橘奶
            break;
        case BackgroundThemeSettings:
            self.backgroundColor = [self rgb:0xF1ECFB];  // 淡薰衣草
            break;
    }
}

- (UIColor *)rgb:(NSUInteger)hex {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize sz = self.bounds.size;
    if (sz.width <= 0 || sz.height <= 0) return;
    // 1pt 內視為相同；旋轉、Split View、多工切窗造成的尺寸變動會重建（避免裝飾固定在舊絕對座標）。
    if (fabs(sz.width - self.builtSize.width) < 1.0 && fabs(sz.height - self.builtSize.height) < 1.0) {
        return;
    }
    for (UIView *v in [self.subviews copy]) [v removeFromSuperview];
    self.builtSize = sz;
    [self build];
}

- (void)build {
    switch (self.theme) {
        case BackgroundThemeMainMenu:       [self buildMainMenu]; break;
        case BackgroundThemeLessons:        [self buildLessons]; break;
        case BackgroundThemeDrill:          [self buildDrill]; break;
        case BackgroundThemeMultiplication: [self buildMultiplication]; break;
        case BackgroundThemeSettings:       [self buildSettings]; break;
    }
}

#pragma mark - Helpers

/// 加一個淡淡的數字/符號標籤（裝飾用、低 alpha、輕微旋轉）。
- (void)addSticker:(NSString *)text
            fontSize:(CGFloat)fontSize
              color:(UIColor *)color
              alpha:(CGFloat)alpha
              cxRel:(CGFloat)cxRel
              cyRel:(CGFloat)cyRel
            rotate:(CGFloat)rotate {
    UILabel *l = [[UILabel alloc] init];
    l.isAccessibilityElement = NO;
    l.text = text;
    l.font = [ChildUI roundedMonoFontOfSize:fontSize weight:UIFontWeightBold];
    l.textColor = color;
    l.alpha = alpha;
    [l sizeToFit];
    l.center = CGPointMake(CGRectGetWidth(self.bounds) * cxRel,
                           CGRectGetHeight(self.bounds) * cyRel);
    l.transform = CGAffineTransformMakeRotation(rotate);
    [self addSubview:l];
}

/// 加一朵雲（柔白橢圓組）。
- (void)addCloudAt:(CGPoint)center size:(CGFloat)size alpha:(CGFloat)alpha {
    UIColor *white = [[UIColor whiteColor] colorWithAlphaComponent:alpha];
    CGFloat w = size, h = size * 0.6;
    UIView *base = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    base.backgroundColor = white;
    base.layer.cornerRadius = h * 0.5;
    base.center = center;
    [self addSubview:base];

    UIView *bump1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, h * 1.0, h * 1.0)];
    bump1.backgroundColor = white;
    bump1.layer.cornerRadius = h * 0.5;
    bump1.center = CGPointMake(center.x - w * 0.2, center.y - h * 0.25);
    [self addSubview:bump1];

    UIView *bump2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, h * 0.9, h * 0.9)];
    bump2.backgroundColor = white;
    bump2.layer.cornerRadius = h * 0.45;
    bump2.center = CGPointMake(center.x + w * 0.15, center.y - h * 0.30);
    [self addSubview:bump2];
}

/// 加一個太陽（圓 + 放射線）。
- (void)addSunAt:(CGPoint)center radius:(CGFloat)r alpha:(CGFloat)alpha {
    UIView *core = [[UIView alloc] initWithFrame:CGRectMake(0, 0, r * 2, r * 2)];
    core.backgroundColor = [[self rgb:0xFFD93D] colorWithAlphaComponent:alpha];
    core.layer.cornerRadius = r;
    core.center = center;
    [self addSubview:core];

    // 8 道光芒
    UIColor *rayColor = [[self rgb:0xFFB860] colorWithAlphaComponent:alpha * 0.6];
    for (NSInteger i = 0; i < 8; i++) {
        CGFloat angle = (CGFloat)i * M_PI / 4.0;
        CGFloat rayLen = r * 0.6;
        CGFloat rayW = 6.0;
        UIView *ray = [[UIView alloc] initWithFrame:CGRectMake(0, 0, rayW, rayLen)];
        ray.backgroundColor = rayColor;
        ray.layer.cornerRadius = rayW / 2.0;
        CGFloat dx = cos(angle) * (r + rayLen * 0.5 + 6);
        CGFloat dy = sin(angle) * (r + rayLen * 0.5 + 6);
        ray.center = CGPointMake(center.x + dx, center.y + dy);
        ray.transform = CGAffineTransformMakeRotation(angle + M_PI_2);
        [self addSubview:ray];
    }
}

/// 加一顆五角星（簡化版：使用 ★ 字元）。
- (void)addStarAt:(CGFloat)cxRel cyRel:(CGFloat)cyRel size:(CGFloat)size color:(UIColor *)color alpha:(CGFloat)alpha {
    UILabel *l = [[UILabel alloc] init];
    l.isAccessibilityElement = NO;
    l.text = @"★";
    l.font = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
    l.textColor = color;
    l.alpha = alpha;
    [l sizeToFit];
    l.center = CGPointMake(CGRectGetWidth(self.bounds) * cxRel,
                           CGRectGetHeight(self.bounds) * cyRel);
    [self addSubview:l];
}

#pragma mark - Themes

- (void)buildMainMenu {
    // 太陽（右上）
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    [self addSunAt:CGPointMake(W - 80, 100) radius:50 alpha:0.65];

    // 兩朵雲
    [self addCloudAt:CGPointMake(80, H * 0.18) size:130 alpha:0.75];
    [self addCloudAt:CGPointMake(W * 0.55, H * 0.10) size:100 alpha:0.55];
    [self addCloudAt:CGPointMake(W * 0.20, H * 0.55) size:90 alpha:0.50];

    // 飄浮數字（裝飾）
    UIColor *pink = [self rgb:0xFF8FA3];
    UIColor *blue = [self rgb:0x5EC5E5];
    UIColor *yellow = [self rgb:0xFFD93D];
    UIColor *purple = [self rgb:0xB68DFE];
    [self addSticker:@"3"  fontSize:64 color:pink   alpha:0.20 cxRel:0.12 cyRel:0.75 rotate:-0.18];
    [self addSticker:@"7"  fontSize:80 color:blue   alpha:0.18 cxRel:0.85 cyRel:0.65 rotate:0.15];
    [self addSticker:@"2"  fontSize:54 color:yellow alpha:0.30 cxRel:0.70 cyRel:0.85 rotate:-0.10];
    [self addSticker:@"+"  fontSize:90 color:purple alpha:0.15 cxRel:0.05 cyRel:0.45 rotate:0.20];
    [self addSticker:@"="  fontSize:70 color:pink   alpha:0.18 cxRel:0.95 cyRel:0.40 rotate:-0.12];
}

- (void)buildLessons {
    // 飄浮加減乘除（教室便條氛圍）
    UIColor *pink = [self rgb:0xFF8FA3];
    UIColor *orange = [self rgb:0xFFB860];
    UIColor *blue = [self rgb:0x5EC5E5];
    UIColor *green = [self rgb:0x7BD389];
    [self addSticker:@"+" fontSize:140 color:pink   alpha:0.10 cxRel:0.10 cyRel:0.18 rotate:-0.15];
    [self addSticker:@"−" fontSize:140 color:orange alpha:0.10 cxRel:0.85 cyRel:0.25 rotate:0.10];
    [self addSticker:@"×" fontSize:140 color:blue   alpha:0.10 cxRel:0.15 cyRel:0.78 rotate:0.20];
    [self addSticker:@"÷" fontSize:140 color:green  alpha:0.10 cxRel:0.88 cyRel:0.85 rotate:-0.12];
    [self addSticker:@"=" fontSize:100 color:pink   alpha:0.08 cxRel:0.50 cyRel:0.92 rotate:0.0];
    // 對角飄浮數字
    [self addSticker:@"8" fontSize:60 color:blue   alpha:0.16 cxRel:0.50 cyRel:0.30 rotate:0.10];
    [self addSticker:@"5" fontSize:48 color:orange alpha:0.18 cxRel:0.40 cyRel:0.62 rotate:-0.15];
}

- (void)buildDrill {
    // 練習氛圍：飄浮數字 + 星星
    UIColor *pink = [self rgb:0xFF8FA3];
    UIColor *blue = [self rgb:0x5EC5E5];
    UIColor *yellow = [self rgb:0xFFD93D];
    UIColor *green = [self rgb:0x7BD389];
    UIColor *purple = [self rgb:0xB68DFE];

    [self addSticker:@"12" fontSize:72 color:pink   alpha:0.13 cxRel:0.12 cyRel:0.22 rotate:-0.15];
    [self addSticker:@"35" fontSize:64 color:blue   alpha:0.13 cxRel:0.88 cyRel:0.30 rotate:0.10];
    [self addSticker:@"7"  fontSize:80 color:green  alpha:0.15 cxRel:0.18 cyRel:0.75 rotate:0.18];
    [self addSticker:@"99" fontSize:60 color:purple alpha:0.13 cxRel:0.82 cyRel:0.82 rotate:-0.12];
    [self addSticker:@"6"  fontSize:48 color:yellow alpha:0.22 cxRel:0.55 cyRel:0.45 rotate:0.0];

    [self addStarAt:0.08 cyRel:0.50 size:28 color:yellow alpha:0.45];
    [self addStarAt:0.92 cyRel:0.55 size:22 color:pink alpha:0.50];
    [self addStarAt:0.30 cyRel:0.92 size:20 color:purple alpha:0.45];
    [self addStarAt:0.72 cyRel:0.18 size:24 color:green alpha:0.45];
}

- (void)buildMultiplication {
    // 9×9 點點格紋 + ×符號
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    CGFloat cols = 9, rows = 12;
    CGFloat dotR = 3.0;
    UIColor *dotColor = [[self rgb:0xFFB860] colorWithAlphaComponent:0.25];
    for (NSInteger r = 0; r < rows; r++) {
        for (NSInteger c = 0; c < cols; c++) {
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, dotR*2, dotR*2)];
            dot.backgroundColor = dotColor;
            dot.layer.cornerRadius = dotR;
            dot.center = CGPointMake(W * (c + 0.5) / cols, H * (r + 0.5) / rows);
            [self addSubview:dot];
        }
    }
    UIColor *purple = [self rgb:0xB68DFE];
    UIColor *pink = [self rgb:0xFF8FA3];
    [self addSticker:@"×" fontSize:160 color:purple alpha:0.10 cxRel:0.15 cyRel:0.15 rotate:-0.15];
    [self addSticker:@"×" fontSize:160 color:pink   alpha:0.10 cxRel:0.85 cyRel:0.85 rotate:0.15];
    [self addStarAt:0.20 cyRel:0.85 size:28 color:[self rgb:0xFFD93D] alpha:0.55];
    [self addStarAt:0.85 cyRel:0.18 size:24 color:[self rgb:0xFF8FA3] alpha:0.50];
}

- (void)buildSettings {
    // 簡單的點點 / 齒輪輪廓
    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);
    CGFloat cols = 16, rows = 22;
    CGFloat dotR = 2.0;
    UIColor *dotColor = [[self rgb:0xB68DFE] colorWithAlphaComponent:0.22];
    for (NSInteger r = 0; r < rows; r++) {
        for (NSInteger c = 0; c < cols; c++) {
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, dotR*2, dotR*2)];
            dot.backgroundColor = dotColor;
            dot.layer.cornerRadius = dotR;
            dot.center = CGPointMake(W * (c + 0.5) / cols, H * (r + 0.5) / rows);
            [self addSubview:dot];
        }
    }
    UIImageView *gear = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"gearshape.fill"]];
    gear.tintColor = [[self rgb:0xB68DFE] colorWithAlphaComponent:0.16];
    gear.contentMode = UIViewContentModeScaleAspectFit;
    gear.frame = CGRectMake(W - 240, H - 240, 200, 200);
    [self addSubview:gear];
}

@end
