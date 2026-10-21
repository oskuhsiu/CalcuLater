#import "LessonIntroView.h"
#import "Lesson.h"
#import "ChildUIKit.h"
#import "SoundManager.h"
#import <math.h>

/// A real five-/ten-frame: an empty space is never presented as another object.
@interface CLIntroFrameView : UIView
@property (nonatomic) NSInteger capacity;
- (CGPoint)centerForIndex:(NSInteger)index;
@end

@implementation CLIntroFrameView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.isAccessibilityElement = NO;
        self.userInteractionEnabled = NO;
        _capacity = 10;
    }
    return self;
}
- (void)setCapacity:(NSInteger)capacity {
    _capacity = capacity;
    [self setNeedsDisplay];
}
- (CGPoint)centerForIndex:(NSInteger)index {
    CGFloat cellWidth = self.bounds.size.width / 5.0;
    CGFloat cellHeight = self.bounds.size.height / (self.capacity == 10 ? 2.0 : 1.0);
    return CGPointMake((index % 5 + 0.5) * cellWidth, (index / 5 + 0.5) * cellHeight);
}
- (void)drawRect:(CGRect)rect {
    [[ChildUI.brownText colorWithAlphaComponent:0.25] setStroke];
    UIBezierPath *outline = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 1, 1) cornerRadius:12];
    outline.lineWidth = 2;
    [outline stroke];
    UIBezierPath *grid = [UIBezierPath bezierPath];
    for (NSInteger column = 1; column < 5; column++) {
        CGFloat x = column * self.bounds.size.width / 5.0;
        [grid moveToPoint:CGPointMake(x, 2)];
        [grid addLineToPoint:CGPointMake(x, self.bounds.size.height - 2)];
    }
    if (self.capacity == 10) {
        [grid moveToPoint:CGPointMake(2, self.bounds.size.height / 2)];
        [grid addLineToPoint:CGPointMake(self.bounds.size.width - 2, self.bounds.size.height / 2)];
    }
    grid.lineWidth = 1;
    [grid stroke];
}
@end

@interface CLIntroDotView : UIView
@property (nonatomic, strong) UIColor *fillColor;
@property (nonatomic) BOOL crossedOut;
@end

@implementation CLIntroDotView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.isAccessibilityElement = NO;
        self.userInteractionEnabled = NO;
    }
    return self;
}
- (void)setFillColor:(UIColor *)fillColor { _fillColor = fillColor; [self setNeedsDisplay]; }
- (void)setCrossedOut:(BOOL)crossedOut { _crossedOut = crossedOut; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGRect circle = CGRectInset(self.bounds, 2, 2);
    [(self.crossedOut ? ChildUI.creamBackground : self.fillColor) setFill];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:circle];
    [path fill];
    [ChildUI.brownText setStroke];
    path.lineWidth = 1.4;
    [path stroke];
    if (self.crossedOut) {
        UIBezierPath *slash = [UIBezierPath bezierPath];
        [slash moveToPoint:CGPointMake(4, self.bounds.size.height - 4)];
        [slash addLineToPoint:CGPointMake(self.bounds.size.width - 4, 4)];
        slash.lineWidth = 2.2;
        [slash stroke];
    }
}
@end

@interface LessonIntroView ()
@property (nonatomic, strong) Lesson *lesson;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UILabel *problemLabel;
@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) UILabel *narration;
@property (nonatomic, strong) UIStackView *buttonStack;
@property (nonatomic, strong) NSLayoutConstraint *buttonStackHeight;
@property (nonatomic, strong) ChildButton *replayButton;
@property (nonatomic, strong) ChildButton *startButton;
@property (nonatomic, strong) CLIntroFrameView *firstFrame;
@property (nonatomic, strong) CLIntroFrameView *secondFrame;
@property (nonatomic, strong) UILabel *firstCountLabel;
@property (nonatomic, strong) UILabel *secondCountLabel;
@property (nonatomic, strong) NSMutableArray<CLIntroDotView *> *dots;
@property (nonatomic, strong, nullable) NSTimer *stepTimer;
@property (nonatomic) BOOL playbackRequested;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL finished;
@property (nonatomic) NSInteger step;
@property (nonatomic) CGSize lastStageSize;
@end

@implementation LessonIntroView

- (instancetype)initWithLesson:(Lesson *)lesson {
    if ((self = [super initWithFrame:CGRectZero])) {
        _lesson = lesson;
        _dots = [NSMutableArray array];
        self.backgroundColor = ChildUI.creamBackground;
        self.layer.cornerRadius = 28;
        [ChildUI applySoftShadowOnLayer:self.layer];
        [self setupUI];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillResignActive:)
                                                   name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(motionPreferenceChanged:)
                                                   name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [_stepTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (UILabel *)labelWithSize:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[UILabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                  scaledFontForFont:[ChildUI roundedFontOfSize:size weight:weight]];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = ChildUI.brownText;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = NO;
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self addSubview:self.scrollView];
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:content];

    self.headerLabel = [self labelWithSize:20 weight:UIFontWeightSemibold];
    self.headerLabel.text = @"先看梅西老師示範一次";
    self.problemLabel = [self labelWithSize:48 weight:UIFontWeightBold];
    self.problemLabel.font = [ChildUI roundedMonoFontOfSize:48 weight:UIFontWeightBold];
    self.problemLabel.numberOfLines = 1;
    self.problemLabel.adjustsFontSizeToFitWidth = YES;
    self.problemLabel.minimumScaleFactor = 0.65;
    self.problemLabel.accessibilityIdentifier = @"lessonIntro.equation";
    self.narration = [self labelWithSize:20 weight:UIFontWeightMedium];
    self.narration.accessibilityIdentifier = @"lessonIntro.narration";
    self.stage = [[UIView alloc] init];
    self.stage.isAccessibilityElement = YES;
    self.stage.accessibilityIdentifier = @"lessonIntro.stage";
    for (UIView *view in @[self.headerLabel, self.problemLabel, self.stage, self.narration]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:view];
    }

    self.firstFrame = [[CLIntroFrameView alloc] initWithFrame:CGRectZero];
    self.secondFrame = [[CLIntroFrameView alloc] initWithFrame:CGRectZero];
    self.firstCountLabel = [self labelWithSize:18 weight:UIFontWeightSemibold];
    self.secondCountLabel = [self labelWithSize:18 weight:UIFontWeightSemibold];
    // Grid annotations stay at a readable 18pt so they cannot collide with the
    // counted objects. The complete instruction is repeated in the scalable,
    // multiline narration and in the stage's VoiceOver summary.
    for (UILabel *label in @[self.firstCountLabel, self.secondCountLabel]) {
        label.font = [ChildUI roundedFontOfSize:18 weight:UIFontWeightSemibold];
        label.adjustsFontForContentSizeCategory = NO;
        label.numberOfLines = 1;
    }
    for (UIView *view in @[self.firstFrame, self.secondFrame, self.firstCountLabel, self.secondCountLabel]) {
        view.isAccessibilityElement = NO;
        [self.stage addSubview:view];
    }

    self.replayButton = [ChildButton buttonWithTitle:@"再看一次" backgroundColor:ChildUI.lavender];
    self.startButton = [ChildButton buttonWithTitle:@"開始練習" backgroundColor:ChildUI.mintGreen];
    self.replayButton.accessibilityIdentifier = @"lessonIntro.replay";
    self.startButton.accessibilityIdentifier = @"lessonIntro.start";
    [self.replayButton addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
    [self.startButton addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    self.buttonStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.replayButton, self.startButton]];
    self.buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.buttonStack.axis = UILayoutConstraintAxisVertical;
    self.buttonStack.distribution = UIStackViewDistributionFillEqually;
    self.buttonStack.spacing = 12;
    [self addSubview:self.buttonStack];
    self.buttonStackHeight = [self.buttonStack.heightAnchor constraintEqualToConstant:132];

    [NSLayoutConstraint activateConstraints:@[
        [self.buttonStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.buttonStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.buttonStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16],
        self.buttonStackHeight,
        [self.scrollView.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.buttonStack.topAnchor constant:-12],
        [content.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [content.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
        [self.headerLabel.topAnchor constraintEqualToAnchor:content.topAnchor constant:4],
        [self.headerLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.headerLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.problemLabel.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:8],
        [self.problemLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.problemLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.problemLabel.heightAnchor constraintEqualToConstant:62],
        [self.stage.topAnchor constraintEqualToAnchor:self.problemLabel.bottomAnchor constant:12],
        [self.stage.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.stage.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.stage.heightAnchor constraintEqualToConstant:244],
        [self.narration.topAnchor constraintEqualToAnchor:self.stage.bottomAnchor constant:12],
        [self.narration.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.narration.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.narration.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
    ]];
}

#pragma mark - Layout and lifecycle

- (void)layoutSubviews {
    CGFloat titleWidth = MAX([self.replayButton.titleLabel.text sizeWithAttributes:@{NSFontAttributeName:self.replayButton.titleLabel.font}].width,
                             [self.startButton.titleLabel.text sizeWithAttributes:@{NSFontAttributeName:self.startButton.titleLabel.font}].width);
    BOOL stackVertically = self.bounds.size.width - 32 < 2 * MAX(128, titleWidth + 32) + 12;
    CGFloat buttonHeight = MAX(60, ceil(self.startButton.titleLabel.font.lineHeight) + 24);
    UILayoutConstraintAxis axis = stackVertically ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    if (self.buttonStack.axis != axis) self.buttonStack.axis = axis;
    CGFloat footerHeight = stackVertically ? buttonHeight * 2 + 12 : buttonHeight;
    if (self.buttonStackHeight.constant != footerHeight) self.buttonStackHeight.constant = footerHeight;
    [super layoutSubviews];
    if (!CGSizeEqualToSize(self.lastStageSize, self.stage.bounds.size)) {
        self.lastStageSize = self.stage.bounds.size;
        [self renderStepAnimated:NO];
    }
    [self beginPlaybackIfReady];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self stopPlayback];
    else [self beginPlaybackIfReady];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    if (hidden) [self stopPlayback];
}

- (void)setAlpha:(CGFloat)alpha {
    [super setAlpha:alpha];
    if (alpha <= 0.01) [self stopPlayback];
}

- (BOOL)isEffectivelyVisible {
    if (!self.window) return NO;
    for (UIView *view = self; view; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) return NO;
    }
    return YES;
}

- (void)removeAnimationsInView:(UIView *)view {
    [view.layer removeAllAnimations];
    for (UIView *child in view.subviews) [self removeAnimationsInView:child];
}

- (void)stopPlayback {
    self.playbackRequested = NO;
    self.playing = NO;
    [self.stepTimer invalidate];
    self.stepTimer = nil;
    [self removeAnimationsInView:self];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self stopPlayback];
}

- (void)motionPreferenceChanged:(NSNotification *)notification {
    [self removeAnimationsInView:self];
    [self renderStepAnimated:NO];
}

#pragma mark - Playback

- (void)startTapped {
    if (self.finished) return;
    self.finished = YES;
    self.startButton.enabled = NO;
    self.replayButton.enabled = NO;
    [self stopPlayback];
    [self.delegate lessonIntroDidFinish:self];
}

- (void)play {
    if (self.finished) return;
    [self stopPlayback];
    self.step = 0;
    for (UIView *dot in self.dots) [dot removeFromSuperview];
    [self.dots removeAllObjects];
    self.playbackRequested = YES;
    [self.scrollView setContentOffset:CGPointZero animated:NO];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self beginPlaybackIfReady];
}

- (void)beginPlaybackIfReady {
    if (!self.playbackRequested || self.playing || self.finished || ![self isEffectivelyVisible]) return;
    if (self.stage.bounds.size.width <= 0 || self.stage.bounds.size.height <= 0) return;
    self.playing = YES;
    if (self.lesson.kind == LessonKindMultiplication) { [self startTapped]; return; }
    [self renderStepAnimated:NO];
    [self scheduleNextStep];
}

- (NSInteger)lastStep {
    return self.lesson.kind == LessonKindMakeTen ? 4 : 3;
}

- (void)scheduleNextStep {
    [self.stepTimer invalidate];
    self.stepTimer = nil;
    if (self.step >= [self lastStep]) { self.playing = NO; self.playbackRequested = NO; return; }
    __weak typeof(self) weakSelf = self;
    self.stepTimer = [NSTimer scheduledTimerWithTimeInterval:3.2 repeats:NO block:^(NSTimer *timer) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.playing || self.stepTimer != timer) return;
        if (![self isEffectivelyVisible]) { [self stopPlayback]; return; }
        self.step++;
        [self renderStepAnimated:!UIAccessibilityIsReduceMotionEnabled()];
        [[SoundManager sharedInstance] play:self.step == [self lastStep] ? SoundEffectCheer : SoundEffectReveal];
        [self scheduleNextStep];
    }];
}

#pragma mark - Countable teaching frames

- (void)exampleA:(NSInteger *)a b:(NSInteger *)b {
    switch (self.lesson.kind) {
        case LessonKindAddSimple: {
            BOOL firstLesson = [self.lesson.lessonID isEqualToString:@"L1"];
            *a = firstLesson ? 2 : 4; *b = firstLesson ? 3 : 5; break;
        }
        case LessonKindSubSimple: *a = 7; *b = 3; break;
        case LessonKindMakeTen: *a = 8; *b = 5; break;
        case LessonKindBreakTen: *a = 12; *b = 5; break;
        default: *a = 0; *b = 0; break;
    }
}

- (void)renderStepAnimated:(BOOL)animated {
    CGFloat width = self.stage.bounds.size.width;
    if (width <= 0 || self.lesson.kind == LessonKindMultiplication) return;
    NSInteger a = 0, b = 0;
    [self exampleA:&a b:&b];
    BOOL addition = self.lesson.kind == LessonKindAddSimple || self.lesson.kind == LessonKindMakeTen;
    NSInteger answer = addition ? a + b : a - b;
    NSInteger count = addition ? a + b : a;
    while (self.dots.count < count) {
        CLIntroDotView *dot = [[CLIntroDotView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        dot.accessibilityIdentifier = [NSString stringWithFormat:@"lessonIntro.dot.%lu", (unsigned long)self.dots.count];
        [self.stage addSubview:dot];
        [self.dots addObject:dot];
    }
    NSString *symbol = addition ? @"+" : @"−";
    self.problemLabel.text = self.step == [self lastStep]
        ? [NSString stringWithFormat:@"%ld %@ %ld = %ld", (long)a, symbol, (long)b, (long)answer]
        : [NSString stringWithFormat:@"%ld %@ %ld = ?", (long)a, symbol, (long)b];

    CGFloat frameWidth = MIN(250, width - 8);
    CGFloat x = (width - frameWidth) / 2;
    BOOL merged = self.lesson.kind == LessonKindAddSimple && self.step >= 2;
    BOOL singleFrame = merged || self.lesson.kind == LessonKindSubSimple;
    self.firstFrame.capacity = self.lesson.kind == LessonKindAddSimple && !merged ? 5 : 10;
    self.secondFrame.capacity = 5;
    CGRect firstRect = CGRectMake(x, singleFrame ? 82 : (self.firstFrame.capacity == 10 ? 26 : 46),
                                 frameWidth, self.firstFrame.capacity == 10 ? 84 : 44);
    CGRect secondRect = CGRectMake(x, 168, frameWidth, 44);
    self.firstCountLabel.frame = CGRectMake(0, singleFrame ? 52 : 0, width, 28);
    self.secondCountLabel.frame = CGRectMake(0, 132, width, 28);
    self.firstCountLabel.text = [NSString stringWithFormat:@"先有 %ld", (long)a];
    self.secondCountLabel.text = [NSString stringWithFormat:@"再加 %ld", (long)b];
    self.secondCountLabel.alpha = singleFrame || self.step == 0 ? 0 : 1;

    switch (self.lesson.kind) {
        case LessonKindAddSimple: {
            NSArray *lines = @[[NSString stringWithFormat:@"先數一數，有 %ld 個點點。", (long)a],
                               [NSString stringWithFormat:@"再放進 %ld 個藍色點點。", (long)b],
                               @"把兩邊合起來，一格放一個。",
                               [NSString stringWithFormat:@"一共 %ld 個！換你試試看。", (long)answer]];
            self.narration.text = lines[self.step];
            if (merged) self.firstCountLabel.text = [NSString stringWithFormat:@"%ld + %ld，一共 %ld", (long)a, (long)b, (long)answer];
            break;
        }
        case LessonKindSubSimple: {
            NSArray *lines = @[@"先數一數，這裡有 7 個點點。", @"劃掉 3 個，表示要拿走 3 個。", @"把劃掉的拿走，再數留下的。", @"剩下 4 個，所以 7 − 3 = 4。"];
            self.narration.text = lines[self.step];
            self.firstCountLabel.text = self.step < 2 ? @"原來有 7" : @"拿走 3，剩下 4";
            break;
        }
        case LessonKindMakeTen: {
            NSArray *lines = @[@"8 還差 2，就能填滿十格。", @"再加 5 個，要怎麼湊成 10 呢？", @"把 5 拆成 2 和 3，黃色的 2 要去補十。", @"把 2 移到空格，8 + 2 剛好是 10。", @"10 加剩下的 3，一共是 13！"];
            self.narration.text = lines[self.step];
            self.firstCountLabel.text = self.step < 3 ? @"8，還差 2 就滿十格" : @"8 + 2 = 10";
            self.secondCountLabel.text = self.step < 2 ? @"再加 5" : (self.step == 2 ? @"5 拆成 2 和 3" : @"剩下 3");
            break;
        }
        case LessonKindBreakTen: {
            NSArray *lines = @[@"先把 12 拆成 10 和 2。", @"從 10 裡劃掉 5 個，原本的 2 留著。", @"10 拿走 5，剩下 5。", @"剩下的 5 加原本的 2，一共是 7！"];
            self.narration.text = lines[self.step];
            self.firstCountLabel.text = self.step < 2 ? @"先看這 10 個" : @"10 − 5 = 5";
            self.secondCountLabel.text = @"原本的 2，留著不動";
            self.secondCountLabel.alpha = 1;
            break;
        }
        default: break;
    }
    self.stage.accessibilityLabel = [NSString stringWithFormat:@"%@。%@", self.firstCountLabel.text,
                                    self.secondCountLabel.alpha > 0 ? self.secondCountLabel.text : @""];
    self.stage.accessibilityValue = self.narration.text;

    void (^changes)(void) = ^{
        self.firstFrame.frame = firstRect;
        self.secondFrame.frame = secondRect;
        self.secondFrame.alpha = singleFrame || (self.step == 0 && self.lesson.kind != LessonKindBreakTen) ? 0 : 1;
        for (NSInteger index = 0; index < count; index++) {
            CLIntroDotView *dot = self.dots[index];
            CLIntroFrameView *target = self.firstFrame;
            NSInteger slot = index;
            dot.alpha = 1;
            dot.crossedOut = NO;
            dot.fillColor = index < a ? ChildUI.pinkAccent : ChildUI.skyBlue;
            if (self.lesson.kind == LessonKindAddSimple && !merged && index >= a) {
                target = self.secondFrame; slot = index - a; dot.alpha = self.step >= 1 ? 1 : 0;
            } else if (self.lesson.kind == LessonKindSubSimple && index >= a - b) {
                dot.crossedOut = self.step >= 1; dot.alpha = self.step >= 2 ? 0 : 1;
            } else if (self.lesson.kind == LessonKindMakeTen && index >= a) {
                NSInteger offset = index - a;
                BOOL transferred = offset < 10 - a;
                dot.fillColor = self.step >= 2 && transferred ? ChildUI.eggYolk : ChildUI.skyBlue;
                if (self.step >= 3 && transferred) { target = self.firstFrame; slot = a + offset; }
                else { target = self.secondFrame; slot = self.step >= 3 ? offset - (10 - a) : offset; }
                dot.alpha = self.step >= 1 ? 1 : 0;
            } else if (self.lesson.kind == LessonKindBreakTen) {
                if (index >= 10) { target = self.secondFrame; slot = index - 10; dot.fillColor = ChildUI.mintGreen; }
                else {
                    dot.fillColor = ChildUI.skyBlue;
                    if (index >= 10 - b) { dot.crossedOut = self.step >= 1; dot.alpha = self.step >= 2 ? 0 : 1; }
                }
            }
            CGPoint point = [target centerForIndex:slot];
            dot.center = CGPointMake(target.frame.origin.x + point.x, target.frame.origin.y + point.y);
        }
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.65 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes completion:nil];
    } else [UIView performWithoutAnimation:changes];
}

@end
