#import "LessonIntroView.h"
#import "Lesson.h"
#import "ArithmeticProblem.h"
#import "SpeechManager.h"
#import "ChildUIKit.h"
#import "SoundManager.h"
#import <math.h>

/// Auto Layout reaches this nested scroll/stack child after the intro's own
/// layout callback. Only the stage knows when its actual bounds have changed.
@interface CLIntroStageView : UIView
@property (nonatomic, copy) void (^sizeDidLayout)(void);
@property (nonatomic) CGSize lastLaidOutSize;
@end

@implementation CLIntroStageView
- (void)layoutSubviews {
    [super layoutSubviews];
    if (CGSizeEqualToSize(self.lastLaidOutSize, self.bounds.size)) return;
    // Cache before notifying: rendering its children can request another pass,
    // but an unchanged stage must not interrupt a child-requested Replay.
    self.lastLaidOutSize = self.bounds.size;
    if (self.sizeDidLayout) self.sizeDidLayout();
}
@end

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
@property (nonatomic) BOOL selectedForTen;
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
- (void)setSelectedForTen:(BOOL)selectedForTen { _selectedForTen = selectedForTen; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGRect circle = CGRectInset(self.bounds, 2, 2);
    [(self.crossedOut ? ChildUI.creamBackground : self.fillColor) setFill];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:circle];
    [path fill];
    [ChildUI.brownText setStroke];
    path.lineWidth = 1.4;
    [path stroke];
    if (self.selectedForTen) {
        // A second outline marks the selected set without relying on color.
        UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds, 5, 5)];
        ring.lineWidth = 1.4;
        [ring stroke];
    }
    if (self.crossedOut) {
        UIBezierPath *slash = [UIBezierPath bezierPath];
        [slash moveToPoint:CGPointMake(4, self.bounds.size.height - 4)];
        [slash addLineToPoint:CGPointMake(self.bounds.size.width - 4, 4)];
        slash.lineWidth = 2.2;
        [slash stroke];
    }
}
@end

/// Each leg belongs to one original counter. The schedule has no overlapping
/// transfer intervals, so a child can track and count every moved unit.
@interface CLIntroTransferLeg : NSObject
@property (nonatomic) NSInteger dotIndex;
@property (nonatomic) CGPoint fromCenter;
@property (nonatomic) CGPoint toCenter;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval duration;
@end
@implementation CLIntroTransferLeg
@end

static const CGFloat CLIntroCompactSourceY = 184;
static const CGFloat CLIntroAnnotationHeight = 30;
static const CGFloat CLIntroCompactAnnotationGap = 2;
static const NSTimeInterval CLIntroTransferMoveDuration = 0.70;
static const NSTimeInterval CLIntroTransferPauseDuration = 0.12;

@interface LessonIntroView ()
@property (nonatomic) LessonKind lessonKind;
@property (nonatomic) NSInteger a;
@property (nonatomic) NSInteger b;
@property (nonatomic) NSInteger answer;
@property (nonatomic) BOOL currentProblem;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UILabel *problemLabel;
@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) NSLayoutConstraint *stageHeight;
@property (nonatomic, strong) UILabel *narration;
@property (nonatomic, strong) UIStackView *buttonStack;
@property (nonatomic, strong) NSLayoutConstraint *buttonStackHeight;
@property (nonatomic, strong) ChildButton *previousButton;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) ChildButton *replayButton;
@property (nonatomic, strong) ChildButton *startButton;
@property (nonatomic, strong) ChildButton *readButton;
@property (nonatomic, strong) CLIntroFrameView *firstFrame;
@property (nonatomic, strong) CLIntroFrameView *secondFrame;
@property (nonatomic, strong) UILabel *firstCountLabel;
@property (nonatomic, strong) UILabel *secondCountLabel;
@property (nonatomic, strong) NSMutableArray<CLIntroDotView *> *dots;
@property (nonatomic, strong, nullable) UIViewPropertyAnimator *stepAnimator;
@property (nonatomic) LessonIntroPlaybackState playbackState;
@property (nonatomic) NSUInteger playbackGeneration;
@property (nonatomic) NSInteger playbackStepIndex;
@property (nonatomic) NSUInteger activeAnimationGeneration;
@property (nonatomic) BOOL finished;
@property (nonatomic) BOOL hasPresentedInitialScene;
@property (nonatomic) NSInteger step;
@property (nonatomic) CGSize lastBoundsSize;
- (BOOL)prepareStageDots;
- (void)settleStageAfterLayout;
@end

@implementation LessonIntroView

+ (BOOL)supportsProblem:(ArithmeticProblem *)problem lesson:(Lesson *)lesson {
    if (!problem || !lesson || problem.isMultiStep) return NO;
    NSInteger a = problem.number1, b = problem.number2;
    if (lesson.kind == LessonKindMakeTen) {
        // Bound operands before doing arithmetic, including for malformed input.
        if (a < 2 || a > 9 || b < 1 || b > 9) return NO;
        return [problem.operatorSymbol isEqualToString:@"+"] && a + b > 10
            && a + b <= 18 && problem.answer == a + b;
    }
    if (lesson.kind == LessonKindBreakTen) {
        if (a < 11 || a > 18 || b < 1 || b > 9 || b <= a % 10) return NO;
        BOOL subtraction = [problem.operatorSymbol isEqualToString:@"-"]
            || [problem.operatorSymbol isEqualToString:@"−"];
        return subtraction && problem.answer == a - b;
    }
    return NO;
}

- (instancetype)initWithProblem:(ArithmeticProblem *)problem lesson:(Lesson *)lesson {
    if (![LessonIntroView supportsProblem:problem lesson:lesson]) return nil;
    if ((self = [super initWithFrame:CGRectZero])) {
        // ArithmeticProblem is mutable. Retain only a validated value snapshot.
        _lessonKind = lesson.kind;
        _a = problem.number1;
        _b = problem.number2;
        _answer = problem.answer;
        _currentProblem = YES;
        [self finishInitialization];
    }
    return self;
}

- (instancetype)initWithLesson:(Lesson *)lesson {
    if ((self = [super initWithFrame:CGRectZero])) {
        _lessonKind = lesson.kind;
        switch (lesson.kind) {
            case LessonKindAddSimple:
                _a = [lesson.lessonID isEqualToString:@"L1"] ? 2 : 4;
                _b = [lesson.lessonID isEqualToString:@"L1"] ? 3 : 5;
                break;
            case LessonKindSubSimple: _a = 7; _b = 3; break;
            case LessonKindMakeTen: _a = 8; _b = 5; break;
            case LessonKindBreakTen: _a = 12; _b = 5; break;
            default: break;
        }
        _answer = [self isAddition] ? _a + _b : _a - _b;
        [self finishInitialization];
    }
    return self;
}

- (void)finishInitialization {
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

- (void)dealloc {
    if (_stepAnimator.state == UIViewAnimatingStateActive) [_stepAnimator stopAnimation:YES];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)isAddition { return self.lessonKind == LessonKindAddSimple || self.lessonKind == LessonKindMakeTen; }
- (BOOL)isTenStrategy { return self.lessonKind == LessonKindMakeTen || self.lessonKind == LessonKindBreakTen; }
- (NSInteger)currentStepIndex { return self.step; }
- (NSInteger)numberOfSteps { return self.lessonKind == LessonKindMakeTen ? 5 : 4; }
- (NSInteger)lastStep { return self.numberOfSteps - 1; }
- (NSString *)currentNarration { return self.narration.text ?: @""; }

- (UILabel *)labelWithSize:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[ChildWrappingLabel alloc] init];
    label.font = [ChildUI scaledRoundedFontOfSize:size weight:weight textStyle:UIFontTextStyleBody maximumPointSize:size * 1.65];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = ChildUI.brownText;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

- (ChildButton *)button:(NSString *)title color:(UIColor *)color action:(SEL)action identifier:(NSString *)identifier {
    ChildButton *button = [ChildButton buttonWithTitle:title backgroundColor:color];
    button.titleLabel.font = [ChildUI scaledRoundedFontOfSize:18 weight:UIFontWeightBold textStyle:UIFontTextStyleBody maximumPointSize:22];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.accessibilityIdentifier = identifier;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = NO;
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scrollView.accessibilityIdentifier = @"lessonIntro.content";
    [self addSubview:self.scrollView];
    UIStackView *content = [[UIStackView alloc] init];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 12;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:content];

    self.headerLabel = [self labelWithSize:20 weight:UIFontWeightSemibold];
    self.headerLabel.text = self.currentProblem ? @"一起看這一題" : @"先看梅西老師示範一次";
    self.headerLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.progressLabel = [self labelWithSize:17 weight:UIFontWeightMedium];
    self.progressLabel.accessibilityIdentifier = @"lessonIntro.progress";
    self.problemLabel = [self labelWithSize:48 weight:UIFontWeightBold];
    self.problemLabel.font = [ChildUI roundedMonoFontOfSize:48 weight:UIFontWeightBold];
    self.problemLabel.numberOfLines = 1;
    self.problemLabel.adjustsFontSizeToFitWidth = YES;
    self.problemLabel.minimumScaleFactor = 0.65;
    self.problemLabel.accessibilityIdentifier = @"lessonIntro.equation";
    self.narration = [self labelWithSize:20 weight:UIFontWeightMedium];
    self.narration.accessibilityIdentifier = @"lessonIntro.narration";
    CLIntroStageView *stage = [[CLIntroStageView alloc] init];
    __weak typeof(self) weakSelf = self;
    stage.sizeDidLayout = ^{ [weakSelf settleStageAfterLayout]; };
    self.stage = stage;
    self.stage.isAccessibilityElement = YES;
    self.stage.accessibilityIdentifier = @"lessonIntro.stage";
    self.readButton = [self button:@"聽聽這一步" color:ChildUI.skyBlue action:@selector(readCurrentStep) identifier:@"lessonIntro.read"];
    for (UIView *view in @[self.headerLabel, self.progressLabel, self.problemLabel, self.stage, self.narration, self.readButton]) {
        [content addArrangedSubview:view];
    }
    [self.problemLabel.heightAnchor constraintEqualToConstant:62].active = YES;
    self.stageHeight = [self.stage.heightAnchor constraintEqualToConstant:[self isTenStrategy] ? 292 : 244];
    self.stageHeight.active = YES;
    [self.readButton.heightAnchor constraintGreaterThanOrEqualToConstant:60].active = YES;

    self.firstFrame = [[CLIntroFrameView alloc] initWithFrame:CGRectZero];
    self.secondFrame = [[CLIntroFrameView alloc] initWithFrame:CGRectZero];
    self.firstCountLabel = [self labelWithSize:18 weight:UIFontWeightSemibold];
    self.secondCountLabel = [self labelWithSize:18 weight:UIFontWeightSemibold];
    // Annotations keep their own clear lane above each frame. Scalable full
    // instructions and the VoiceOver summary repeat all of this information.
    for (UILabel *label in @[self.firstCountLabel, self.secondCountLabel]) {
        label.font = [ChildUI roundedFontOfSize:18 weight:UIFontWeightSemibold];
        label.adjustsFontForContentSizeCategory = NO;
        label.numberOfLines = 1;
    }
    for (UIView *view in @[self.firstFrame, self.secondFrame, self.firstCountLabel, self.secondCountLabel]) {
        view.isAccessibilityElement = NO;
        [self.stage addSubview:view];
    }

    self.previousButton = [self button:@"上一步" color:ChildUI.lavender action:@selector(goToPreviousStep) identifier:@"lessonIntro.previous"];
    self.nextButton = [self button:@"下一步" color:ChildUI.mintGreen action:@selector(goToNextStep) identifier:@"lessonIntro.next"];
    self.replayButton = [self button:@"重看這步" color:ChildUI.lavender action:@selector(replayCurrentStep) identifier:@"lessonIntro.replay"];
    self.replayButton.accessibilityLabel = @"重看這一步";
    self.startButton = [self button:self.currentProblem ? @"回到題目" : @"開始練習" color:ChildUI.skyBlue
        action:@selector(startTapped) identifier:@"lessonIntro.start"];
    // Two equal pairs become a 2×2 footer on compact screens and a single row
    // on wider ones. Every control stays available and at least 60 points tall.
    NSMutableArray<UIStackView *> *pairs = [NSMutableArray array];
    for (NSArray<UIButton *> *buttons in @[@[self.previousButton, self.nextButton], @[self.replayButton, self.startButton]]) {
        UIStackView *pair = [[UIStackView alloc] initWithArrangedSubviews:buttons];
        pair.axis = UILayoutConstraintAxisHorizontal;
        pair.distribution = UIStackViewDistributionFillEqually;
        pair.spacing = 12;
        [pairs addObject:pair];
    }
    self.buttonStack = [[UIStackView alloc] initWithArrangedSubviews:pairs];
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
        [content.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:4],
        [content.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-12],
        [content.centerXAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.centerXAnchor],
        [content.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32],
        [self.scrollView.contentLayoutGuide.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
    ]];
    [self updateStepText];
}

#pragma mark - Layout and lifecycle

- (BOOL)usesSideBySideTenFramesAtWidth:(CGFloat)width {
    // Two full frames need 240 points each, a 24-point gutter and outer room.
    // Keep the 32-point counters and readable annotation lanes at every width.
    return [self isTenStrategy] && width >= 512;
}

- (void)layoutSubviews {
    CGFloat titleWidth = 0, lineHeight = 0;
    for (UIButton *button in @[self.previousButton, self.nextButton, self.replayButton, self.startButton]) {
        titleWidth = MAX(titleWidth, [button.titleLabel.text sizeWithAttributes:@{NSFontAttributeName:button.titleLabel.font}].width);
        lineHeight = MAX(lineHeight, button.titleLabel.font.lineHeight);
    }
    BOOL stackVertically = self.bounds.size.width - 32 < 4 * MAX(112, titleWidth + 24) + 36;
    CGFloat buttonHeight = MAX(60, ceil(lineHeight) + 24);
    self.buttonStack.axis = stackVertically ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.buttonStackHeight.constant = stackVertically ? buttonHeight * 2 + 12 : buttonHeight;
    BOOL sideBySide = [self usesSideBySideTenFramesAtWidth:self.bounds.size.width - 32];
    BOOL compactMakeTen = self.lessonKind == LessonKindMakeTen && !sideBySide;
    // The source annotation sits below its frame, leaving the inter-frame gap
    // exclusively for counters. Include its real bottom plus four points.
    CGFloat compactHeight = compactMakeTen
        ? CLIntroCompactSourceY + 100 + CLIntroCompactAnnotationGap + CLIntroAnnotationHeight + 4 : 292;
    self.stageHeight.constant = [self isTenStrategy] ? (sideBySide ? 138 : compactHeight) : 244;
    [super layoutSubviews];
    if (!CGSizeEqualToSize(self.lastBoundsSize, self.bounds.size)) {
        self.lastBoundsSize = self.bounds.size;
        // Height-only resizing must settle motion even if stage size is fixed.
        // If nested layout has not resized the stage yet, its callback will
        // render this same selected step again using the final child bounds.
        [self stopPlayback];
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self stopPlayback];
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
- (void)cancelStepAnimation {
    // Invalidate before stopping: even an already-queued callback from an old
    // animator must not certify this or a later selected step as completed.
    self.activeAnimationGeneration = 0;
    if (self.playbackState == LessonIntroPlaybackStateRunning) self.playbackState = LessonIntroPlaybackStateCancelled;
    UIViewPropertyAnimator *animator = self.stepAnimator;
    self.stepAnimator = nil;
    if (animator.state == UIViewAnimatingStateActive) [animator stopAnimation:YES];
    [self.stage.layer removeAllAnimations];
    for (UIView *view in self.stage.subviews) [view.layer removeAllAnimations];
}
- (void)stopPlayback {
    [self cancelStepAnimation];
    [SpeechManager.sharedInstance stop];
    [self renderStepAnimated:NO];
}
- (void)settleStageAfterLayout {
    [self cancelStepAnimation];
    [SpeechManager.sharedInstance stop];
    if (![self prepareStageDots]) return;
    // The child owns only its manual diagram layout. Do not reassign sibling
    // labels/buttons here: that can invalidate the surrounding stack mid-pass.
    [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step]; }];
    [self updateStageAccessibility];
}
- (void)applicationWillResignActive:(NSNotification *)notification { [self stopPlayback]; }
- (BOOL)prefersReducedMotion { return UIAccessibilityIsReduceMotionEnabled(); }
- (void)motionPreferenceChanged:(NSNotification *)notification {
    BOOL wasRunning = self.playbackState == LessonIntroPlaybackStateRunning;
    [self stopPlayback];
    if (wasRunning && [self prefersReducedMotion]) {
        self.playbackState = LessonIntroPlaybackStateReducedMotion;
        [self updateStageAccessibility];
    }
}

- (void)completeStepAnimation:(UIViewPropertyAnimator *)animator generation:(NSUInteger)generation
    step:(NSInteger)step position:(UIViewAnimatingPosition)position {
    if (!animator || animator != self.stepAnimator || generation != self.activeAnimationGeneration
        || generation != self.playbackGeneration || step != self.playbackStepIndex || step != self.step
        || self.playbackState != LessonIntroPlaybackStateRunning) return;
    self.activeAnimationGeneration = 0;
    self.stepAnimator = nil;
    self.playbackState = position == UIViewAnimatingPositionEnd
        ? LessonIntroPlaybackStateCompleted : LessonIntroPlaybackStateCancelled;
    if (position != UIViewAnimatingPositionEnd) {
        // Finishing at start/current is not natural completion. Preserve the
        // same cancel-and-settle contract without revealing a future step.
        [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step]; }];
    }
    [self updateStageAccessibility];
}

- (void)startStepAnimator:(UIViewPropertyAnimator *)animator {
    // This view exclusively owns its animator. Production cancellation uses
    // stopAnimation:YES, never finishAnimationAtPosition:End, so a matching
    // .end callback is evidence of a natural finish rather than forced settle.
    self.stepAnimator = animator;
    self.activeAnimationGeneration = self.playbackGeneration;
    NSUInteger generation = self.playbackGeneration;
    NSInteger step = self.playbackStepIndex;
    __weak typeof(self) weakSelf = self;
    __weak UIViewPropertyAnimator *weakAnimator = animator;
    [animator addCompletion:^(UIViewAnimatingPosition position) {
        [weakSelf completeStepAnimation:weakAnimator generation:generation step:step position:position];
    }];
    [animator startAnimation];
}

#pragma mark - Child-controlled steps

- (void)startTapped {
    if (self.finished) return;
    self.finished = YES;
    for (UIButton *button in @[self.previousButton, self.nextButton, self.replayButton, self.startButton, self.readButton]) button.enabled = NO;
    [self stopPlayback];
    [self.delegate lessonIntroDidFinish:self];
}
- (void)play {
    if (self.finished) return;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    if (self.lessonKind == LessonKindMultiplication && [self isEffectivelyVisible]) { [self startTapped]; return; }
    [self stopPlayback];
    if (!self.hasPresentedInitialScene && [self isTenStrategy] && [self isEffectivelyVisible]
        && !CGRectIsEmpty(self.stage.bounds) && !CGRectIsEmpty(self.scrollView.bounds)) {
        // A hidden/unattached preparation is not a presentation. Consume this
        // once even if the full scene cannot fit, so later appearances or
        // resizing never replace the child's inspection position.
        self.hasPresentedInitialScene = YES;
        if (self.step == 0) {
            [self.scrollView layoutIfNeeded];
            [self frameNewStepScene:[self visibleDiagramBoundsWithFrames:YES annotations:YES]
                frames:[self visibleDiagramBoundsWithFrames:YES annotations:NO]
                counters:[self visibleDiagramBoundsWithFrames:NO annotations:NO]];
        }
    }
}
- (void)goToPreviousStep {
    if (self.finished || self.step == 0) return;
    [self cancelStepAnimation];
    [SpeechManager.sharedInstance stop];
    self.step--;
    [self renderStepAnimated:NO];
    // This is an in-place step change. Moving VoiceOver focus to narration
    // below the diagram could override the child's chosen viewport.
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.currentNarration);
}
- (void)goToNextStep {
    if (self.finished) return;
    if (self.step == [self lastStep]) { [self startTapped]; return; }
    [self cancelStepAnimation];
    [SpeechManager.sharedInstance stop];
    self.step++;
    [self renderStepAnimated:YES frameNewStep:YES];
    [SoundManager.sharedInstance play:self.step == [self lastStep] ? SoundEffectCheer : SoundEffectReveal];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.currentNarration);
}
- (void)replayCurrentStep {
    if (self.finished) return;
    [self cancelStepAnimation];
    [SpeechManager.sharedInstance stop];
    [self renderStepAnimated:YES];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.currentNarration);
}
- (void)readCurrentStep {
    if (!self.finished) [SpeechManager.sharedInstance speak:self.currentNarration];
}

#pragma mark - One countable renderer

- (void)updateStepText {
    NSInteger a = self.a, b = self.b, answer = self.answer;
    NSString *symbol = [self isAddition] ? @"+" : @"−";
    self.problemLabel.text = self.step == [self lastStep]
        ? [NSString stringWithFormat:@"%ld %@ %ld = %ld", (long)a, symbol, (long)b, (long)answer]
        : [NSString stringWithFormat:@"%ld %@ %ld = ?", (long)a, symbol, (long)b];
    self.progressLabel.text = [NSString stringWithFormat:@"第 %ld 小步 · 共 %ld 步 · 不用急", (long)self.step + 1, (long)self.numberOfSteps];
    self.previousButton.enabled = self.step > 0 && !self.finished;
    [self.nextButton setTitle:self.step == [self lastStep] ? @"完成" : @"下一步" forState:UIControlStateNormal];
    self.firstCountLabel.text = [NSString stringWithFormat:@"先有 %ld", (long)a];
    self.secondCountLabel.text = [NSString stringWithFormat:@"再加 %ld", (long)b];
    switch (self.lessonKind) {
        case LessonKindAddSimple: {
            NSArray *lines = @[[NSString stringWithFormat:@"先數一數，有 %ld 個點點。", (long)a],
                [NSString stringWithFormat:@"再放進 %ld 個藍色點點。", (long)b],
                @"把兩邊合起來，一格放一個。",
                [NSString stringWithFormat:@"一共 %ld 個！換你試試看。", (long)answer]];
            self.narration.text = lines[self.step];
            if (self.step >= 2) self.firstCountLabel.text = [NSString stringWithFormat:@"%ld + %ld，一共 %ld", (long)a, (long)b, (long)answer];
            break;
        }
        case LessonKindSubSimple: {
            NSArray *lines = @[@"先數一數，這裡有 7 個點點。", @"劃掉 3 個，表示要拿走 3 個。", @"把劃掉的拿走，再數留下的。", @"剩下 4 個，所以 7 − 3 = 4。"];
            self.narration.text = lines[self.step];
            self.firstCountLabel.text = self.step < 2 ? @"原來有 7" : @"拿走 3，剩下 4";
            break;
        }
        case LessonKindMakeTen: {
            NSInteger need = 10 - a, rest = b - need;
            NSArray *lines = @[
                [NSString stringWithFormat:@"%ld 還差 %ld，就能填滿十格。", (long)a, (long)need],
                [NSString stringWithFormat:@"再加 %ld 個，一起數一數。要拿幾個去補十呢？", (long)b],
                [NSString stringWithFormat:@"把 %ld 拆成 %ld 和 %ld。有雙圈的 %ld 個要去補十，其餘 %ld 個留下。", (long)b, (long)need, (long)rest, (long)need, (long)rest],
                [NSString stringWithFormat:@"把 %ld 個移到空格，%ld + %ld = 10。留下的 %ld 個還在。", (long)need, (long)a, (long)need, (long)rest],
                [NSString stringWithFormat:@"10 加留下的 %ld，10 + %ld = %ld！", (long)rest, (long)rest, (long)answer]];
            self.narration.text = lines[self.step];
            self.firstCountLabel.text = self.step < 3
                ? [NSString stringWithFormat:@"%ld，還差 %ld 就滿十格", (long)a, (long)need]
                : [NSString stringWithFormat:@"%ld + %ld = 10", (long)a, (long)need];
            self.secondCountLabel.text = self.step < 2 ? [NSString stringWithFormat:@"再加 %ld", (long)b]
                : self.step == 2 ? [NSString stringWithFormat:@"%ld 拆成 %ld 和 %ld", (long)b, (long)need, (long)rest]
                : [NSString stringWithFormat:@"留下 %ld", (long)rest];
            break;
        }
        case LessonKindBreakTen: {
            NSInteger ones = a % 10, left = 10 - b;
            NSArray *lines = @[
                [NSString stringWithFormat:@"先把 %ld 拆成 10 和 %ld。", (long)a, (long)ones],
                [NSString stringWithFormat:@"從 10 裡劃掉 %ld 個，原本的 %ld 個留著。", (long)b, (long)ones],
                [NSString stringWithFormat:@"只拿走劃掉的 %ld 個。10 − %ld = %ld，原本的 %ld 個不動。", (long)b, (long)b, (long)left, (long)ones],
                [NSString stringWithFormat:@"留下的 %ld 加原本的 %ld，%ld + %ld = %ld！", (long)left, (long)ones, (long)left, (long)ones, (long)answer]];
            self.narration.text = lines[self.step];
            self.firstCountLabel.text = self.step < 2 ? @"先看這 10 個"
                : [NSString stringWithFormat:@"10 − %ld = %ld", (long)b, (long)left];
            self.secondCountLabel.text = [NSString stringWithFormat:@"原本的 %ld，留著不動", (long)ones];
            break;
        }
        default: self.narration.text = @"準備好了，就開始練習。"; break;
    }
}

/// This method describes a snapshot only. Step -1 is the empty before-state of
/// the first reveal; no callback, timer, sound or next-step work lives here.
- (void)applyDotStateForStep:(NSInteger)step {
    CGFloat width = self.stage.bounds.size.width;
    NSInteger count = [self isAddition] ? self.a + self.b : self.a;
    CGFloat frameWidth = MIN(280, width - 8);
    CGFloat x = (width - frameWidth) / 2;
    BOOL merged = self.lessonKind == LessonKindAddSimple && step >= 2;
    BOOL singleFrame = merged || self.lessonKind == LessonKindSubSimple;
    BOOL strategy = [self isTenStrategy];
    // Keep orientation and positions in the same, actually laid-out coordinate
    // space. The parent can already have its next width during nested layout.
    BOOL sideBySide = [self usesSideBySideTenFramesAtWidth:width];
    BOOL compactMakeTen = self.lessonKind == LessonKindMakeTen && !sideBySide;
    if (compactMakeTen) {
        // Reserve a left-side transfer lane instead of shrinking the counters.
        // At the 288-point supported width, 208-point frames have 41.6-point
        // cells, leaving each 32-point counter distinct even in a full row.
        frameWidth = MIN(280, width - 48);
        x = 44 + (width - 48 - frameWidth) / 2;
    }
    if (sideBySide) {
        frameWidth = MIN(280, (width - 32) / 2);
        x = (width - frameWidth * 2 - 24) / 2;
    }
    self.firstFrame.capacity = self.lessonKind == LessonKindAddSimple && !merged ? 5 : 10;
    self.secondFrame.capacity = strategy ? 10 : 5;
    self.firstFrame.frame = strategy ? CGRectMake(x, 34, frameWidth, 100)
        : CGRectMake(x, singleFrame ? 82 : 46, frameWidth, self.firstFrame.capacity == 10 ? 84 : 44);
    self.secondFrame.frame = strategy ? CGRectMake(sideBySide ? x + frameWidth + 24 : x,
        sideBySide ? 34 : compactMakeTen ? CLIntroCompactSourceY : 188, frameWidth, 100) : CGRectMake(x, 168, frameWidth, 44);
    self.firstCountLabel.frame = CGRectMake(sideBySide ? x : 0, singleFrame ? 52 : 0,
        sideBySide ? frameWidth : width, 30);
    self.secondCountLabel.frame = CGRectMake(sideBySide ? CGRectGetMinX(self.secondFrame.frame) : 0,
        sideBySide ? 0 : compactMakeTen ? CGRectGetMaxY(self.secondFrame.frame) + CLIntroCompactAnnotationGap : strategy ? 154 : 132,
        sideBySide ? frameWidth : width, CLIntroAnnotationHeight);
    self.firstFrame.alpha = step >= 0 ? 1 : 0;
    self.firstCountLabel.alpha = step >= 0 ? 1 : 0;
    self.secondFrame.alpha = step < 0 || singleFrame || (step == 0 && self.lessonKind != LessonKindBreakTen) ? 0 : 1;
    self.secondCountLabel.alpha = self.secondFrame.alpha;
    for (NSInteger index = 0; index < count; index++) {
        CLIntroDotView *dot = self.dots[index];
        CLIntroFrameView *target = self.firstFrame;
        NSInteger slot = index;
        dot.alpha = step >= 0 ? 1 : 0;
        dot.crossedOut = NO;
        dot.selectedForTen = NO;
        dot.fillColor = index < self.a ? ChildUI.pinkAccent : ChildUI.skyBlue;
        if (self.lessonKind == LessonKindAddSimple && !merged && index >= self.a) {
            target = self.secondFrame; slot = index - self.a; dot.alpha = step >= 1 ? 1 : 0;
        } else if (self.lessonKind == LessonKindSubSimple && index >= self.a - self.b) {
            dot.crossedOut = step >= 1; dot.alpha = step >= 2 || step < 0 ? 0 : 1;
        } else if (self.lessonKind == LessonKindMakeTen && index >= self.a) {
            NSInteger offset = index - self.a;
            BOOL transferred = offset < 10 - self.a;
            dot.selectedForTen = step >= 2 && transferred;
            dot.fillColor = dot.selectedForTen ? ChildUI.eggYolk : ChildUI.skyBlue;
            if (step >= 3 && transferred) { target = self.firstFrame; slot = self.a + offset; }
            else { target = self.secondFrame; slot = offset; } // Untouched units never compact or move.
            dot.alpha = step >= 1 ? 1 : 0;
        } else if (self.lessonKind == LessonKindBreakTen) {
            if (index >= 10) { target = self.secondFrame; slot = index - 10; dot.fillColor = ChildUI.mintGreen; }
            else {
                dot.fillColor = ChildUI.skyBlue;
                if (index >= 10 - self.b) { dot.crossedOut = step >= 1; dot.alpha = step >= 2 || step < 0 ? 0 : 1; }
            }
        }
        CGPoint point = [target centerForIndex:slot];
        dot.center = CGPointMake(target.frame.origin.x + point.x, target.frame.origin.y + point.y);
    }
}

/// Source order vacates a row from left to right. In the wide layout a counter
/// exits through those vacated slots, turns in the gutter, and enters its target
/// row from the empty right end. In the stacked layout it exits left, turns in
/// the clear inter-frame gap, and enters its target column from below. Top-row
/// target slots are filled before their bottom-row slots. No occupied slot lies
/// on either route, including when just one counter moves and eight stay put.
- (NSArray<CLIntroTransferLeg *> *)makeTenTransferLegs {
    NSMutableArray<CLIntroTransferLeg *> *legs = [NSMutableArray array];
    for (NSInteger offset = 0; offset < 10 - self.a; offset++) {
        CGPoint source = [self.secondFrame centerForIndex:offset];
        source.x += self.secondFrame.frame.origin.x; source.y += self.secondFrame.frame.origin.y;
        CGPoint target = [self.firstFrame centerForIndex:self.a + offset];
        target.x += self.firstFrame.frame.origin.x; target.y += self.firstFrame.frame.origin.y;
        NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithObject:[NSValue valueWithCGPoint:source]];
        if ([self usesSideBySideTenFramesAtWidth:self.stage.bounds.size.width]) {
            CGFloat laneX = (CGRectGetMaxX(self.firstFrame.frame) + CGRectGetMinX(self.secondFrame.frame)) / 2;
            [points addObject:[NSValue valueWithCGPoint:CGPointMake(laneX, source.y)]];
            [points addObject:[NSValue valueWithCGPoint:CGPointMake(laneX, target.y)]];
        } else {
            CGFloat laneX = CGRectGetMinX(self.firstFrame.frame) - 24;
            CGFloat laneY = (CGRectGetMaxY(self.firstFrame.frame) + CGRectGetMinY(self.secondFrame.frame)) / 2;
            [points addObject:[NSValue valueWithCGPoint:CGPointMake(laneX, source.y)]];
            [points addObject:[NSValue valueWithCGPoint:CGPointMake(laneX, laneY)]];
            [points addObject:[NSValue valueWithCGPoint:CGPointMake(target.x, laneY)]];
        }
        [points addObject:[NSValue valueWithCGPoint:target]];
        CGFloat length = 0;
        for (NSUInteger index = 1; index < points.count; index++) {
            CGPoint from = points[index - 1].CGPointValue, to = points[index].CGPointValue;
            length += hypot(to.x - from.x, to.y - from.y);
        }
        NSTimeInterval start = CLIntroTransferPauseDuration + offset * (CLIntroTransferMoveDuration + CLIntroTransferPauseDuration);
        for (NSUInteger index = 1; index < points.count; index++) {
            CGPoint from = points[index - 1].CGPointValue, to = points[index].CGPointValue;
            CGFloat distance = hypot(to.x - from.x, to.y - from.y);
            if (distance <= 0) continue;
            CLIntroTransferLeg *leg = [[CLIntroTransferLeg alloc] init];
            leg.dotIndex = self.a + offset;
            leg.fromCenter = from; leg.toCenter = to;
            leg.startTime = start;
            leg.duration = CLIntroTransferMoveDuration * distance / length;
            start += leg.duration;
            [legs addObject:leg];
        }
    }
    return legs;
}

- (NSTimeInterval)makeTenTransferDuration {
    return CLIntroTransferPauseDuration + (10 - self.a) * (CLIntroTransferMoveDuration + CLIntroTransferPauseDuration);
}

- (CGRect)makeTenTransferBounds:(NSArray<CLIntroTransferLeg *> *)legs {
    CGRect bounds = CGRectNull;
    for (CLIntroTransferLeg *leg in legs) {
        CGSize size = self.dots[leg.dotIndex].bounds.size;
        for (NSValue *value in @[[NSValue valueWithCGPoint:leg.fromCenter], [NSValue valueWithCGPoint:leg.toCenter]]) {
            CGPoint center = value.CGPointValue;
            bounds = CGRectUnion(bounds, CGRectMake(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height));
        }
    }
    return bounds;
}

- (void)animateMakeTenTransfer:(NSArray<CLIntroTransferLeg *> *)legs {
    NSTimeInterval duration = [self makeTenTransferDuration];
    __weak typeof(self) weakSelf = self;
    // Linear keyframes never spring past a turn or a destination. The arrival
    // pause makes each unit countable; no completion schedules another step.
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:duration curve:UIViewAnimationCurveLinear animations:^{
        [UIView animateKeyframesWithDuration:duration delay:0 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
            for (CLIntroTransferLeg *leg in legs) {
                [UIView addKeyframeWithRelativeStartTime:leg.startTime / duration relativeDuration:leg.duration / duration animations:^{
                    if (leg == legs.lastObject) [weakSelf applyDotStateForStep:3];
                    else weakSelf.dots[leg.dotIndex].center = leg.toCenter;
                }];
            }
        } completion:nil];
    }];
    [self startStepAnimator:animator];
}

- (void)updateStageAccessibility {
    NSInteger first = 0, second = 0, crossed = 0;
    for (CLIntroDotView *dot in self.dots) {
        if (dot.alpha < 0.5) continue;
        if (CGRectContainsPoint(self.firstFrame.frame, dot.center)) first++;
        if (CGRectContainsPoint(self.secondFrame.frame, dot.center)) second++;
        if (dot.crossedOut) crossed++;
    }
    self.stage.accessibilityLabel = @"一格一個的點點圖";
    // Model centers already contain the endpoint while UIKit is animating.
    // Do not describe those quantities as an observed animation completion.
    NSString *quantityPrefix = self.playbackState == LessonIntroPlaybackStateRunning ? @"這一步完成後：" : @"";
    self.stage.accessibilityValue = [NSString stringWithFormat:@"%@第一框 %ld 個，第二框 %ld 個；劃掉 %ld 個。%@",
        quantityPrefix, (long)first, (long)second, (long)crossed, self.currentNarration];
    NSString *state;
    switch (self.playbackState) {
        case LessonIntroPlaybackStateRunning: state = @"動態播放中"; break;
        case LessonIntroPlaybackStateCompleted: state = @"動態播放完成"; break;
        case LessonIntroPlaybackStateCancelled: state = @"動態已停止，顯示目前這一步"; break;
        case LessonIntroPlaybackStateReducedMotion: state = @"減少動態，直接顯示這一步"; break;
        default: state = @"靜止圖示，尚未播放"; break;
    }
    if (self.playbackStepIndex == self.step) {
        self.progressLabel.accessibilityValue = [NSString stringWithFormat:@"第 %lu 次播放，第 %ld 小步，%@",
            (unsigned long)self.playbackGeneration, (long)self.playbackStepIndex + 1, state];
    } else {
        // Back changes the selected static snapshot without playing it. Keep
        // the last playback's identity but never call the new step completed.
        NSString *pastState = self.playbackState == LessonIntroPlaybackStateCompleted ? @"動態播放完成"
            : self.playbackState == LessonIntroPlaybackStateCancelled ? @"動態已停止" : @"已直接顯示圖示";
        self.progressLabel.accessibilityValue = [NSString stringWithFormat:@"第 %lu 次播放是先前第 %ld 小步（%@）；目前第 %ld 小步是靜止圖示",
            (unsigned long)self.playbackGeneration, (long)self.playbackStepIndex + 1, pastState, (long)self.step + 1];
    }
}

- (void)renderStepAnimated:(BOOL)animated {
    [self renderStepAnimated:animated frameNewStep:NO];
}

/// Bounds come from the real snapshots, not an assumed fixed stage height.
/// Counter-only bounds also include the stationary original ones for context.
- (CGRect)visibleDiagramBoundsWithFrames:(BOOL)frames annotations:(BOOL)annotations {
    CGRect bounds = CGRectNull;
    for (UIView *dot in self.dots) if (dot.alpha > 0.01) bounds = CGRectUnion(bounds, dot.frame);
    if (frames) {
        for (UIView *frame in @[self.firstFrame, self.secondFrame]) {
            if (frame.alpha > 0.01) bounds = CGRectUnion(bounds, frame.frame);
        }
    }
    if (annotations) {
        for (UIView *label in @[self.firstCountLabel, self.secondCountLabel]) {
            if (label.alpha > 0.01) bounds = CGRectUnion(bounds, label.frame);
        }
    }
    return bounds;
}

- (void)frameNewStepScene:(CGRect)scene frames:(CGRect)frames counters:(CGRect)counters {
    // Prefer the complete annotated diagram. If only the actual transformation
    // fits, show every source/destination counter, not just its final location.
    // An even shorter viewport stays scrollable; never shrink or omit counters.
    for (NSValue *candidate in @[[NSValue valueWithCGRect:scene], [NSValue valueWithCGRect:frames],
        [NSValue valueWithCGRect:counters]]) {
        CGRect bounds = candidate.CGRectValue;
        if (CGRectIsNull(bounds) || CGRectIsEmpty(bounds)) continue;
        bounds = CGRectInset(bounds, -4, -4);
        if (bounds.size.width > self.scrollView.bounds.size.width
            || bounds.size.height > self.scrollView.bounds.size.height) continue;
        CGRect target = [self.stage convertRect:bounds toView:self.scrollView];
        [self.scrollView scrollRectToVisible:target animated:NO];
        return;
    }
}

- (void)renderStepAnimated:(BOOL)animated frameNewStep:(BOOL)frameNewStep {
    [self cancelStepAnimation];
    [self updateStepText];
    if (frameNewStep) {
        // Narration can change content height. Complete layout before choosing
        // the viewport and before an animator gets its source/destination.
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [self.scrollView layoutIfNeeded];
    }
    if (animated) {
        self.playbackGeneration++;
        self.playbackStepIndex = self.step;
        // A requested playback that cannot render is cancelled, not idle or
        // completed. Even pre-layout requests have a unique identity.
        self.playbackState = LessonIntroPlaybackStateCancelled;
    }
    if (![self prepareStageDots]) { [self updateStageAccessibility]; return; }
    CGRect scene = CGRectNull, frames = CGRectNull, counters = CGRectNull;
    if (frameNewStep) {
        [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step]; }];
        scene = [self visibleDiagramBoundsWithFrames:YES annotations:YES];
        frames = [self visibleDiagramBoundsWithFrames:YES annotations:NO];
        counters = [self visibleDiagramBoundsWithFrames:NO annotations:NO];
    }
    if (animated) {
        // Replay always rebuilds the selected step's own before-state. Starting
        // from an already settled model frame would otherwise produce no motion.
        [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step - 1]; }];
    }
    NSArray<CLIntroTransferLeg *> *transferLegs = self.lessonKind == LessonKindMakeTen && self.step == 3
        ? [self makeTenTransferLegs] : nil;
    if (frameNewStep) {
        // Include the entire routed path, not only its source and destination.
        CGRect path = transferLegs ? [self makeTenTransferBounds:transferLegs] : CGRectNull;
        scene = CGRectUnion(scene, path); frames = CGRectUnion(frames, path); counters = CGRectUnion(counters, path);
        [self frameNewStepScene:CGRectUnion(scene, [self visibleDiagramBoundsWithFrames:YES annotations:YES])
            frames:CGRectUnion(frames, [self visibleDiagramBoundsWithFrames:YES annotations:NO])
            counters:CGRectUnion(counters, [self visibleDiagramBoundsWithFrames:NO annotations:NO])];
    }
    if (animated) {
        self.playbackState = [self prefersReducedMotion] ? LessonIntroPlaybackStateReducedMotion
            : [self isEffectivelyVisible] ? LessonIntroPlaybackStateRunning : LessonIntroPlaybackStateCancelled;
    }
    if (animated && self.playbackState == LessonIntroPlaybackStateRunning) {
        if (transferLegs.count) [self animateMakeTenTransfer:transferLegs];
        else {
            __weak typeof(self) weakSelf = self;
            NSInteger selectedStep = self.step;
            UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.85 dampingRatio:0.9 animations:^{
                [weakSelf applyDotStateForStep:selectedStep];
            }];
            [self startStepAnimator:animator];
        }
    } else {
        [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step]; }];
    }
    [self updateStageAccessibility];
}

- (BOOL)prepareStageDots {
    if (self.stage.bounds.size.width <= 0 || self.lessonKind == LessonKindMultiplication) return NO;
    NSInteger count = [self isAddition] ? self.a + self.b : self.a;
    while (self.dots.count < count) {
        CLIntroDotView *dot = [[CLIntroDotView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
        dot.accessibilityIdentifier = [NSString stringWithFormat:@"lessonIntro.dot.%lu", (unsigned long)self.dots.count];
        [self.stage addSubview:dot];
        [self.dots addObject:dot];
    }
    return YES;
}

@end
