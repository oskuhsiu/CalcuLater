#import "MascotView.h"
#import "ChildUIKit.h"

@interface MascotView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSArray<UIImage *> *frames;
@property (nonatomic, assign) MascotEmotion currentEmotion;
@property (nonatomic, assign) BOOL idleRunning;
@end

@implementation MascotView

- (instancetype)initWithVariant:(MascotVariant)variant {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _variant = variant;
        self.backgroundColor = [UIColor clearColor];
        [ChildUI applySoftShadowOnLayer:self.layer];

        // 角色名：梅西老師（math 諧音）
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"梅西老師";

        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.layer.cornerRadius = 18.0;
        _imageView.layer.masksToBounds = YES;
        [self addSubview:_imageView];
        [NSLayoutConstraint activateConstraints:@[
            [_imageView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_imageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_imageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];

        [self loadFrames];
        [self setEmotion:MascotEmotionIdle];
        [self startIdleAnimation];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // cornerRadius 隨大小縮放，小頭像時更圓
    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    self.imageView.layer.cornerRadius = MIN(28.0, side * 0.18);
}

- (void)setVariant:(MascotVariant)variant {
    _variant = variant;
    [self loadFrames];
    [self setEmotion:self.currentEmotion];
}

- (void)loadFrames {
    NSString *prefix = (self.variant == MascotVariantDesk) ? @"teacher_desk_" : @"teacher_";
    NSMutableArray *imgs = [NSMutableArray array];
    for (NSInteger i = 1; i <= 3; i++) {
        NSString *name = [NSString stringWithFormat:@"%@%ld", prefix, (long)i];
        UIImage *img = [UIImage imageNamed:name];
        if (img) [imgs addObject:img];
    }
    self.frames = [imgs copy];
    if (self.frames.firstObject && !self.imageView.image) {
        self.imageView.image = self.frames.firstObject;
    }
}

#pragma mark - Emotion

- (void)setEmotion:(MascotEmotion)emotion {
    self.currentEmotion = emotion;
    [self.imageView.layer removeAllAnimations];
    self.imageView.transform = CGAffineTransformIdentity;

    UIImage *frame0 = self.frames.firstObject;
    UIImage *frame1 = self.frames.count > 1 ? self.frames[1] : frame0;
    UIImage *frame2 = self.frames.count > 2 ? self.frames[2] : frame1;

    switch (emotion) {
        case MascotEmotionIdle: {
            self.imageView.image = frame0;
            break;
        }

        case MascotEmotionHappy: {
            self.imageView.image = frame1;
            [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.45 initialSpringVelocity:0.7
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.imageView.transform = CGAffineTransformMakeScale(1.12, 1.12);
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 animations:^{
                    self.imageView.transform = CGAffineTransformIdentity;
                }];
            }];
            break;
        }

        case MascotEmotionThinking: {
            self.imageView.image = frame0;
            [UIView animateWithDuration:0.3 animations:^{
                self.imageView.transform = CGAffineTransformMakeRotation(-0.08);
            }];
            break;
        }

        case MascotEmotionCheering: {
            self.imageView.image = frame2;
            [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.4 initialSpringVelocity:0.9
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.imageView.transform = CGAffineTransformMakeScale(1.25, 1.25);
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.35 animations:^{
                    self.imageView.transform = CGAffineTransformIdentity;
                }];
            }];
            break;
        }

        case MascotEmotionShake: {
            CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
            shake.values = @[ @(0), @(-0.10), @(0.10), @(-0.06), @(0.06), @(0) ];
            shake.duration = 0.45;
            [self.imageView.layer addAnimation:shake forKey:@"shake"];
            break;
        }

        case MascotEmotionTalking: {
            // 框格輪流切換（教鞭擺動感）
            if (self.frames.count >= 2) {
                CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
                anim.values = @[ @(0), @(0.05), @(0), @(-0.05), @(0) ];
                anim.duration = 1.2;
                anim.repeatCount = INFINITY;
                [self.imageView.layer addAnimation:anim forKey:@"talking"];
            }
            break;
        }
    }
}

#pragma mark - Idle

- (void)startIdleAnimation {
    if (self.idleRunning) return;
    self.idleRunning = YES;
    [UIView animateWithDuration:1.4 delay:0
                        options:(UIViewAnimationOptionAutoreverse
                                 | UIViewAnimationOptionRepeat
                                 | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, -4);
    } completion:nil];
}

- (void)stopAllAnimations {
    self.idleRunning = NO;
    [self.layer removeAllAnimations];
    [self.imageView.layer removeAllAnimations];
    self.transform = CGAffineTransformIdentity;
    self.imageView.transform = CGAffineTransformIdentity;
}

@end
