#include <math.h>
#import "MascotView.h"
#import "ChildUIKit.h"

@interface MascotView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, copy) NSArray<UIImage *> *frames;
@property (nonatomic, assign) MascotEmotion currentEmotion;
@property (nonatomic, assign) BOOL idleRequested;
@property (nonatomic, assign) BOOL emotionMotionRequested;
@property (nonatomic, assign) BOOL applicationActive;
@end

@implementation MascotView

- (instancetype)initWithVariant:(MascotVariant)variant {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _variant = variant;
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self commonInit];
    return self;
}

- (void)commonInit {
    self.backgroundColor = UIColor.clearColor;
    [ChildUI applySoftShadowOnLayer:self.layer];
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"梅西老師";
    self.accessibilityLanguage = @"zh-TW";
    self.accessibilityTraits = UIAccessibilityTraitImage;

    _imageView = [[UIImageView alloc] init];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.layer.cornerRadius = 18.0;
    _imageView.layer.masksToBounds = YES;
    _imageView.isAccessibilityElement = NO;
    [self addSubview:_imageView];
    [NSLayoutConstraint activateConstraints:@[
        [_imageView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_imageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_imageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    _applicationActive = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    _idleRequested = YES;
    [self loadFrames];
    [self setEmotion:MascotEmotionIdle];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(motionPreferenceChanged:)
                   name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(applicationWillResignActive:)
                   name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(applicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    self.imageView.layer.cornerRadius = MIN(28.0, side * 0.18);
}

- (void)setVariant:(MascotVariant)variant {
    _variant = variant;
    [self loadFrames];
    [self applyCurrentEmotionAnimated:NO];
}

- (void)loadFrames {
    NSString *prefix = self.variant == MascotVariantDesk ? @"teacher_desk_" : @"teacher_";
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    for (NSInteger i = 1; i <= 3; i++) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"%@%ld", prefix, (long)i]];
        if (image) [images addObject:image];
    }
    self.frames = images;
}

- (BOOL)canAnimate {
    if (!self.window || !self.applicationActive || !ChildUI.motionEnabled) return NO;
    for (UIView *view = self; view; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) return NO;
    }
    return YES;
}

#pragma mark - Emotion

- (void)setEmotion:(MascotEmotion)emotion {
    self.currentEmotion = emotion;
    self.emotionMotionRequested = YES;
    [self applyCurrentEmotionAnimated:YES];
}

- (void)applyCurrentEmotionAnimated:(BOOL)animated {
    [self.imageView.layer removeAllAnimations];
    self.imageView.transform = CGAffineTransformIdentity;
    UIImage *frame0 = self.frames.firstObject;
    UIImage *frame1 = self.frames.count > 1 ? self.frames[1] : frame0;
    UIImage *frame2 = self.frames.count > 2 ? self.frames[2] : frame1;
    self.imageView.image = frame0;

    NSString *keyPath = @"transform.scale";
    NSArray<NSNumber *> *values = nil;
    NSTimeInterval duration = 0.6;
    BOOL repeats = NO;
    switch (self.currentEmotion) {
        case MascotEmotionIdle:
            self.accessibilityValue = @"陪你一起練習";
            break;
        case MascotEmotionHappy:
            self.imageView.image = frame1;
            self.accessibilityValue = @"開心地鼓勵你";
            values = @[@1.0, @1.12, @0.98, @1.0];
            break;
        case MascotEmotionThinking:
            self.accessibilityValue = @"陪你一起想一想";
            keyPath = @"transform.rotation.z";
            values = @[@0, @-0.08, @-0.08, @0];
            break;
        case MascotEmotionCheering:
            self.imageView.image = frame2;
            self.accessibilityValue = @"為你的努力加油";
            values = @[@1.0, @1.20, @0.98, @1.0];
            duration = 0.75;
            break;
        case MascotEmotionShake:
            self.accessibilityValue = @"沒關係，再試一次";
            keyPath = @"transform.rotation.z";
            values = @[@0, @-0.08, @0.08, @-0.04, @0.04, @0];
            duration = 0.45;
            break;
        case MascotEmotionTalking:
            self.accessibilityValue = @"正在說明";
            if (self.frames.count >= 2) {
                keyPath = @"transform.rotation.z";
                values = @[@0, @0.05, @0, @-0.05, @0];
                duration = 1.2;
                repeats = YES;
            }
            break;
    }
    if (!animated || !self.emotionMotionRequested || ![self canAnimate] || values.count == 0) return;
    // Presentation-only animations have no completion that can outlive a newer emotion.
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    animation.values = values;
    animation.duration = duration;
    if (repeats) animation.repeatCount = HUGE_VALF;
    [self.imageView.layer addAnimation:animation forKey:@"emotion"];
}

#pragma mark - Visibility and motion

- (void)startIdleAnimation {
    self.idleRequested = YES;
    [self refreshVisibleAnimations];
}

- (void)stopAllAnimations {
    self.idleRequested = NO;
    self.emotionMotionRequested = NO;
    [self removeMotionAnimations];
}

- (void)removeMotionAnimations {
    [self.layer removeAllAnimations];
    [self.imageView.layer removeAllAnimations];
    self.transform = CGAffineTransformIdentity;
    self.imageView.transform = CGAffineTransformIdentity;
}

- (void)refreshVisibleAnimations {
    if (![self canAnimate]) {
        [self removeMotionAnimations];
        return;
    }
    if (self.idleRequested && ![self.layer animationForKey:@"idleBob"]) {
        CABasicAnimation *bob = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        bob.fromValue = @0;
        bob.toValue = @-4;
        bob.duration = 1.4;
        bob.autoreverses = YES;
        bob.repeatCount = HUGE_VALF;
        [self.layer addAnimation:bob forKey:@"idleBob"];
    }
    if (self.emotionMotionRequested && self.currentEmotion == MascotEmotionTalking
        && ![self.imageView.layer animationForKey:@"emotion"]) {
        [self applyCurrentEmotionAnimated:YES];
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self refreshVisibleAnimations];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    [self refreshVisibleAnimations];
}

- (void)setAlpha:(CGFloat)alpha {
    [super setAlpha:alpha];
    [self refreshVisibleAnimations];
}

- (void)motionPreferenceChanged:(NSNotification *)notification {
    [self refreshVisibleAnimations];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    self.applicationActive = NO;
    [self removeMotionAnimations];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    self.applicationActive = YES;
    [self refreshVisibleAnimations];
}

@end
