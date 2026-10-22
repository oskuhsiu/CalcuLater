#import "LessonIntroView.h"
#import "Lesson.h"
#import "ArithmeticProblem.h"
#import "SpeechManager.h"
#import "ChildUIKit.h"
#import "SoundManager.h"
#import <math.h>
#import <QuartzCore/QuartzCore.h>

/// Auto Layout reaches this nested scroll/stack child after the intro's own
/// layout callback. Only the stage knows when its actual bounds have changed.
@interface CLIntroStageView : UIView
@property (nonatomic, copy) void (^sizeDidLayout)(void);
@property (nonatomic) CGSize lastLaidOutSize;
@property (nonatomic) CGRect requiredActionBounds;
@end

@implementation CLIntroStageView
- (CGRect)accessibilityFrame {
    // VoiceOver focuses the real causal scene, including its source, target,
    // stationary context and route, rather than unused stage whitespace. This
    // conversion is live, so scrolling never leaves a stale accessibility box.
    if (!CGRectIsEmpty(self.requiredActionBounds) && !CGRectIsNull(self.requiredActionBounds)) {
        return UIAccessibilityConvertFrameToScreenCoordinates(self.requiredActionBounds, self);
    }
    return [super accessibilityFrame];
}
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

/// Footer text uses the child's full preferred size. If that complete title
/// cannot fit, show its familiar symbol instead of truncating or shrinking it.
/// VoiceOver and the system large-content viewer retain the complete action.
@interface CLIntroActionButton : ChildButton
@property (nonatomic) BOOL requiresCompactSymbol;
- (UIFont *)preferredActionTitleFont;
- (BOOL)showsSymbolAtWidth:(CGFloat)width;
@end
@implementation CLIntroActionButton
+ (instancetype)buttonWithTitle:(NSString *)title backgroundColor:(UIColor *)color {
    CLIntroActionButton *button = [self buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    for (NSNumber *state in @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled)]) {
        [button setTitleColor:ChildUI.brownText forState:state.unsignedIntegerValue];
    }
    button.backgroundColor = color;
    button.tintColor = ChildUI.brownText;
    button.layer.cornerRadius = 20;
    [ChildUI applySoftShadowOnLayer:button.layer];
    button.titleLabel.font = [button preferredActionTitleFont];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    button.showsLargeContentViewer = YES;
    button.largeContentTitle = title;
    [button addInteraction:[[UILargeContentViewerInteraction alloc] init]];
    return button;
}
- (void)setRequiresCompactSymbol:(BOOL)requiresCompactSymbol {
    if (_requiresCompactSymbol == requiresCompactSymbol) return;
    _requiresCompactSymbol = requiresCompactSymbol;
    [self setNeedsLayout];
}
- (BOOL)showsSymbolAtWidth:(CGFloat)width {
    // Both geometry hooks run during UIKit's lazy title/image-view creation.
    // Never read either view from here. Resolve the same uncapped font used by
    // the label from current traits, rather than retaining a stale measurement.
    CGFloat titleWidth = [self.currentTitle sizeWithAttributes:@{NSFontAttributeName:[self preferredActionTitleFont]}].width;
    return self.requiresCompactSymbol || self.currentTitle.length == 0 || ceil(titleWidth) + 16 > width;
}
- (UIFont *)preferredActionTitleFont {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightBold]
        compatibleWithTraitCollection:self.traitCollection];
}
- (CGRect)titleRectForContentRect:(CGRect)contentRect {
    if ([self showsSymbolAtWidth:contentRect.size.width]) return CGRectZero;
    return CGRectInset(contentRect, 8, 8);
}
- (CGRect)imageRectForContentRect:(CGRect)contentRect {
    if (![self showsSymbolAtWidth:contentRect.size.width]) return CGRectZero;
    return CGRectMake(CGRectGetMidX(contentRect) - 12, CGRectGetMidY(contentRect) - 12, 24, 24);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL symbol = [self showsSymbolAtWidth:self.bounds.size.width];
    self.titleLabel.hidden = symbol;
    self.imageView.hidden = !symbol;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory
            isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        self.titleLabel.font = [self preferredActionTitleFont];
        [self invalidateIntrinsicContentSize];
        [self setNeedsLayout];
    }
}
@end

/// Only Previous has an unavailable first-step state. Keep its label/symbol
/// fully readable; a neutral, flat surface distinguishes it from a ready action.
@interface CLIntroPreviousButton : CLIntroActionButton
@end
@implementation CLIntroPreviousButton
- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.adjustsImageWhenDisabled = NO;
    self.backgroundColor = enabled ? ChildUI.lavender : [UIColor colorWithWhite:0.90 alpha:1.0];
    if (enabled) [ChildUI applySoftShadowOnLayer:self.layer];
    else self.layer.shadowOpacity = 0;
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

@interface LessonIntroView () <UIScrollViewDelegate>
@property (nonatomic) LessonKind lessonKind;
@property (nonatomic) NSInteger a;
@property (nonatomic) NSInteger b;
@property (nonatomic) NSInteger answer;
@property (nonatomic) BOOL currentProblem;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSLayoutConstraint *scrollBottomSpacing;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UILabel *problemLabel;
@property (nonatomic, strong) UIView *stage;
@property (nonatomic, strong) NSLayoutConstraint *stageHeight;
@property (nonatomic, strong) UILabel *narration;
@property (nonatomic, strong) UILabel *visibilityInstruction;
@property (nonatomic, strong) UIStackView *buttonStack;
@property (nonatomic, strong) NSLayoutConstraint *buttonStackHeight;
@property (nonatomic, strong) ChildButton *previousButton;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) ChildButton *replayButton;
@property (nonatomic, strong) ChildButton *startButton;
@property (nonatomic, strong) ChildButton *readButton;
@property (nonatomic, strong) NSLayoutConstraint *readButtonHeight;
@property (nonatomic, strong) ChildButton *pinnedReadButton;
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
@property (nonatomic) CGRect requiredActionBounds;
@property (nonatomic, strong, nullable) CADisplayLink *visibilityDisplayLink;
@property (nonatomic) BOOL finished;
@property (nonatomic) BOOL hasPresentedInitialScene;
@property (nonatomic) NSInteger step;
@property (nonatomic) NSInteger renderedSnapshotStep;
@property (nonatomic) CGSize lastBoundsSize;
- (BOOL)prepareStageDots;
- (void)settleStageAfterLayout;
- (void)validatePlaybackVisibility;
- (SpeechManager *)speechManager;
@end

/// CADisplayLink retains its target. The target must not retain this teaching
/// surface, including if a parent removes it before the next display frame.
@interface CLIntroVisibilityTarget : NSObject
@property (nonatomic, weak) LessonIntroView *intro;
@end
@implementation CLIntroVisibilityTarget
- (void)checkVisibility:(CADisplayLink *)link { [self.intro validatePlaybackVisibility]; }
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
    _renderedSnapshotStep = NSIntegerMin;
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
    [_visibilityDisplayLink invalidate];
    if (_stepAnimator.state == UIViewAnimatingStateActive) [_stepAnimator stopAnimation:YES];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)isAddition { return self.lessonKind == LessonKindAddSimple || self.lessonKind == LessonKindMakeTen; }
- (BOOL)isTenStrategy { return self.lessonKind == LessonKindMakeTen || self.lessonKind == LessonKindBreakTen; }
- (NSInteger)currentStepIndex { return self.step; }
- (NSInteger)numberOfSteps { return self.lessonKind == LessonKindMakeTen ? 5 : 4; }
- (NSInteger)lastStep { return self.numberOfSteps - 1; }
- (NSString *)currentNarration { return self.narration.text ?: @""; }
- (NSString *)currentSpokenNarration {
    // Keep the original operands available even when a large-text explanation
    // needs scrolling. This spoken-only context never changes measured text or
    // introduces the answer ahead of the existing final-step narration.
    if (![self isTenStrategy]) return self.currentNarration;
    return [NSString stringWithFormat:@"原來的題目是 %ld %@ %ld。%@",
        (long)self.a, [self isAddition] ? @"加" : @"減", (long)self.b, self.currentNarration];
}

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
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightBold]];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    button.accessibilityIdentifier = identifier;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (ChildButton *)footerButton:(NSString *)title color:(UIColor *)color symbol:(NSString *)symbol
    action:(SEL)action identifier:(NSString *)identifier {
    Class buttonClass = action == @selector(goToPreviousStep) ? CLIntroPreviousButton.class : CLIntroActionButton.class;
    CLIntroActionButton *button = [buttonClass buttonWithTitle:title backgroundColor:color];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold]]
        forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.accessibilityIdentifier = identifier;
    button.accessibilityLabel = title;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = NO;
    self.scrollView.delegate = self;
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
    // The complete explanation is scrollable. Never cap or shrink it to make
    // the diagram fit; the fixed speaker shortcut remains available instead.
    self.narration.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:20 weight:UIFontWeightMedium]];
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
    self.readButtonHeight = [self.readButton.heightAnchor constraintEqualToConstant:60];
    self.readButtonHeight.active = YES;

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

    self.previousButton = [self footerButton:@"上一步" color:ChildUI.lavender symbol:@"chevron.left" action:@selector(goToPreviousStep) identifier:@"lessonIntro.previous"];
    self.nextButton = [self footerButton:@"下一步" color:ChildUI.mintGreen symbol:@"chevron.right" action:@selector(goToNextStep) identifier:@"lessonIntro.next"];
    self.replayButton = [self footerButton:@"重看這步" color:ChildUI.lavender symbol:@"arrow.counterclockwise" action:@selector(replayCurrentStep) identifier:@"lessonIntro.replay"];
    self.replayButton.accessibilityLabel = @"重看這一步";
    self.replayButton.largeContentTitle = self.replayButton.accessibilityLabel;
    self.startButton = [self footerButton:self.currentProblem ? @"回到題目" : @"開始練習" color:ChildUI.skyBlue
        symbol:self.currentProblem ? @"arrow.uturn.backward" : @"play.fill" action:@selector(startTapped) identifier:@"lessonIntro.start"];
    // Keep the labeled listening action with the explanation, and offer the
    // same explicit action beside Back/Next while the child inspects the dots.
    // A symbol fits the existing footer height without squeezing the diagram.
    self.pinnedReadButton = [self footerButton:@"" color:ChildUI.skyBlue symbol:@"speaker.wave.2.fill"
        action:@selector(readCurrentStep) identifier:@"lessonIntro.readPinned"];
    self.pinnedReadButton.accessibilityLabel = @"聽聽這一步";
    self.pinnedReadButton.accessibilityHint = @"朗讀這一步，不會換步或移動畫面。";
    self.pinnedReadButton.largeContentTitle = self.pinnedReadButton.accessibilityLabel;
    // Back/listen/Next above Replay/Return reuses the original two-row footer.
    // Wide screens keep one row; every control is at least 60 points tall.
    NSMutableArray<UIStackView *> *pairs = [NSMutableArray array];
    for (NSArray<UIButton *> *buttons in @[@[self.previousButton, self.pinnedReadButton, self.nextButton], @[self.replayButton, self.startButton]]) {
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
    self.scrollBottomSpacing = [self.scrollView.bottomAnchor constraintEqualToAnchor:self.buttonStack.topAnchor constant:-12];
    [NSLayoutConstraint activateConstraints:@[
        [self.buttonStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.buttonStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [self.buttonStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16],
        self.buttonStackHeight,
        [self.scrollView.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        self.scrollBottomSpacing,
        [content.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:4],
        [content.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-12],
        [content.centerXAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.centerXAnchor],
        [content.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32],
        [self.scrollView.contentLayoutGuide.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
    ]];
    // Keep the recovery instruction visible beside the fixed action controls.
    // Its full intrinsic height is reserved outside the scroll viewport. It
    // never covers counters/captions or resizes the action buttons. Only a new
    // explicit playback hides it before checking the larger usable viewport.
    self.visibilityInstruction = [self labelWithSize:18 weight:UIFontWeightSemibold];
    self.visibilityInstruction.text = @"滑動看圖，前後步比一比。";
    self.visibilityInstruction.accessibilityIdentifier = @"lessonIntro.visibilityInstruction";
    self.visibilityInstruction.backgroundColor = ChildUI.creamBackground;
    self.visibilityInstruction.layer.cornerRadius = 12;
    self.visibilityInstruction.hidden = YES;
    self.visibilityInstruction.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.visibilityInstruction];
    [NSLayoutConstraint activateConstraints:@[
        [self.visibilityInstruction.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16],
        [self.visibilityInstruction.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16],
        [self.visibilityInstruction.bottomAnchor constraintEqualToAnchor:self.buttonStack.topAnchor constant:-8],
    ]];
    [self updateStepText];
}

#pragma mark - Layout and lifecycle

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    // Re-evaluate footer row heights and symbol choices after a live size change.
    [self setNeedsLayout];
}

- (BOOL)usesSideBySideTenFramesAtWidth:(CGFloat)width {
    // Two full frames need 240 points each, a 24-point gutter and outer room.
    // Keep the 32-point counters and readable annotation lanes at every width.
    return [self isTenStrategy] && width >= 512;
}

- (void)layoutVisibilityInstruction {
    NSString *text = @"滑動看圖，前後步比一比。";
    CGFloat width = MAX(1, self.bounds.size.width - 32);
    CGFloat fullHeight = ceil([text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
        attributes:@{NSFontAttributeName:self.visibilityInstruction.font} context:nil].size.height) + 8;
    // On a very short large-text surface the full recovery sentence itself can
    // consume the remaining viewport. Keep a complete short instruction there;
    // its spoken label still explains listening and static before/after review.
    CGFloat available = self.bounds.size.height - self.buttonStackHeight.constant - 44;
    if (fullHeight > MAX(0, available - 32)) text = @"滑動看圖";
    if (![self.visibilityInstruction.text isEqualToString:text]) self.visibilityInstruction.text = text;
    self.visibilityInstruction.accessibilityLabel = @"滑動看圖，按喇叭聽這一步，用前後步比一比。";
    CGFloat height = self.visibilityInstruction.hidden ? 0 : ceil([self.visibilityInstruction
        sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height) + 8;
    self.scrollBottomSpacing.constant = -12 - height;
}
- (void)layoutSubviews {
    CGFloat titleWidth = 0;
    for (UIButton *button in @[self.previousButton, self.nextButton, self.replayButton, self.startButton]) {
        titleWidth = MAX(titleWidth, [button.currentTitle sizeWithAttributes:@{NSFontAttributeName:button.titleLabel.font}].width);
    }
    CGFloat footerWidth = MAX(1, self.bounds.size.width - 32);
    BOOL stackVertically = footerWidth < 4 * MAX(112, titleWidth + 24) + 36;
    CGFloat groupWidth = stackVertically ? footerWidth : (footerWidth - 12) / 2;
    CGFloat buttonHeight = 60;
    for (CLIntroActionButton *button in @[self.previousButton, self.nextButton, self.replayButton, self.startButton]) {
        button.requiresCompactSymbol = NO;
        BOOL firstRow = button == self.previousButton || button == self.nextButton;
        CGFloat width = firstRow ? (groupWidth - 24) / 3 : (groupWidth - 12) / 2;
        if (![button showsSymbolAtWidth:width]) buttonHeight = MAX(buttonHeight, ceil(button.titleLabel.font.lineHeight) + 24);
    }
    CGFloat footerHeight = stackVertically ? buttonHeight * 2 + 12 : buttonHeight;
    if (footerHeight > self.bounds.size.height - 44 - 80) {
        // Keep usable inspection space rather than compressing a preferred font
        // or letting large labels push the entire diagram out of the viewport.
        for (CLIntroActionButton *button in @[self.previousButton, self.nextButton, self.replayButton, self.startButton]) {
            button.requiresCompactSymbol = YES;
        }
        footerHeight = stackVertically ? 132 : 60;
    }
    self.buttonStack.axis = stackVertically ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.buttonStackHeight.constant = footerHeight;
    [self layoutVisibilityInstruction];
    CGFloat readWidth = MAX(1, self.bounds.size.width - 32 - 24);
    CGSize readText = [self.readButton.currentTitle boundingRectWithSize:CGSizeMake(readWidth, CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
        attributes:@{NSFontAttributeName:self.readButton.titleLabel.font} context:nil].size;
    self.readButtonHeight.constant = MAX(60, ceil(readText.height) + 24);
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
    } else {
        [self validatePlaybackVisibility];
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
    for (UIView *view = self.stage ?: self; view; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) return NO;
    }
    return YES;
}
/// Actual clipping is independent of nominal stage/scroll sizes. Convert every
/// clip into the same stage coordinate space, including the real window.
- (CGRect)visibleStageRect {
    if (![self isEffectivelyVisible]) return CGRectNull;
    CGRect visible = [self.stage convertRect:self.window.bounds fromView:self.window];
    for (UIView *view = self.stage; view; view = view.superview) {
        if (view.clipsToBounds) {
            visible = CGRectIntersection(visible, [self.stage convertRect:view.bounds fromView:view]);
        }
    }
    return visible;
}
- (BOOL)stageRectIsFullyVisible:(CGRect)rect {
    if (![self isEffectivelyVisible] || CGRectIsNull(rect) || CGRectIsEmpty(rect)) return NO;
    // Test the required scene in each clip's own coordinates. Converting a
    // rotated clip into stage space gives an enclosing box, not the actual
    // visible polygon, and must never admit its invisible corners.
    CGRect inWindow = [self.stage convertRect:rect toView:self.window];
    if (!CGRectContainsRect(CGRectInset(self.window.bounds, -0.5, -0.5), inWindow)) return NO;
    for (UIView *view = self.stage; view; view = view.superview) {
        if (view.clipsToBounds && !CGRectContainsRect(CGRectInset(view.bounds, -0.5, -0.5),
            [self.stage convertRect:rect toView:view])) return NO;
    }
    return YES;
}
- (BOOL)isRequiredActionVisible { return [self stageRectIsFullyVisible:self.requiredActionBounds]; }
- (void)setRequiredActionBounds:(CGRect)bounds {
    _requiredActionBounds = bounds;
    ((CLIntroStageView *)self.stage).requiredActionBounds = bounds;
}
- (void)validatePlaybackVisibility {
    if (self.playbackState != LessonIntroPlaybackStateRunning || ![self isTenStrategy]
        || [self isRequiredActionVisible]) return;
    // Invalidate first. Neither a queued natural-end callback nor restored
    // visibility may revive this generation. Never chase a child's scrolling.
    [self cancelStepAnimation];
    [[self speechManager] stop];
    self.playbackState = [self isEffectivelyVisible] ? LessonIntroPlaybackStateVisibilityPaused
        : LessonIntroPlaybackStateCancelled;
    [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step]; }];
    [self updateStageAccessibility];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { [self validatePlaybackVisibility]; }
- (void)cancelStepAnimation {
    // Invalidate before stopping: even an already-queued callback from an old
    // animator must not certify this or a later selected step as completed.
    self.activeAnimationGeneration = 0;
    [self.visibilityDisplayLink invalidate];
    self.visibilityDisplayLink = nil;
    if (self.playbackState == LessonIntroPlaybackStateRunning) self.playbackState = LessonIntroPlaybackStateCancelled;
    UIViewPropertyAnimator *animator = self.stepAnimator;
    self.stepAnimator = nil;
    if (animator.state == UIViewAnimatingStateActive) [animator stopAnimation:YES];
    [self.stage.layer removeAllAnimations];
    for (UIView *view in self.stage.subviews) [view.layer removeAllAnimations];
}
- (void)stopPlayback {
    [self cancelStepAnimation];
    [[self speechManager] stop];
    [self renderStepAnimated:NO];
}
- (void)settleStageAfterLayout {
    [self cancelStepAnimation];
    [[self speechManager] stop];
    if (![self prepareStageDots]) return;
    // The child owns only its manual diagram layout. Do not reassign sibling
    // labels/buttons here: that can invalidate the surrounding stack mid-pass.
    [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step]; }];
    self.requiredActionBounds = [self visibleDiagramBoundsWithFrames:YES annotations:YES];
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
    // A natural timeline end is not completion if the actual scene is clipped.
    [self validatePlaybackVisibility];
    if (self.playbackState != LessonIntroPlaybackStateRunning) return;
    self.activeAnimationGeneration = 0;
    [self.visibilityDisplayLink invalidate];
    self.visibilityDisplayLink = nil;
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
    if ([self isTenStrategy]) {
        CLIntroVisibilityTarget *target = [[CLIntroVisibilityTarget alloc] init];
        target.intro = self;
        self.visibilityDisplayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(checkVisibility:)];
        [self.visibilityDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    [animator startAnimation];
}

#pragma mark - Child-controlled steps

- (void)startTapped {
    if (self.finished) return;
    self.finished = YES;
    for (UIButton *button in @[self.previousButton, self.nextButton, self.replayButton, self.startButton, self.readButton, self.pinnedReadButton]) button.enabled = NO;
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
    [[self speechManager] stop];
    self.step--;
    [self renderStepAnimated:NO];
    // This is an in-place step change. Moving VoiceOver focus to narration
    // below the diagram could override the child's chosen viewport.
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.currentSpokenNarration);
}
- (void)goToNextStep {
    if (self.finished) return;
    if (self.step == [self lastStep]) { [self startTapped]; return; }
    [self cancelStepAnimation];
    [[self speechManager] stop];
    self.step++;
    [self renderStepAnimated:YES frameNewStep:YES];
    [SoundManager.sharedInstance play:self.step == [self lastStep] ? SoundEffectCheer : SoundEffectReveal];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.currentSpokenNarration);
}
- (void)replayCurrentStep {
    if (self.finished) return;
    [self cancelStepAnimation];
    [[self speechManager] stop];
    [self renderStepAnimated:YES];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.currentSpokenNarration);
}
- (SpeechManager *)speechManager { return SpeechManager.sharedInstance; }
- (void)readCurrentStep {
    if (!self.finished) [[self speechManager] speak:self.currentSpokenNarration];
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
    self.nextButton.accessibilityLabel = self.nextButton.currentTitle;
    self.nextButton.largeContentTitle = self.nextButton.currentTitle;
    [self.nextButton setImage:[UIImage systemImageNamed:self.step == [self lastStep] ? @"checkmark" : @"chevron.right"
        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold]]
        forState:UIControlStateNormal];
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
                [NSString stringWithFormat:@"先把 %ld 拆成 10 和 %ld。原本的 %ld 個不夠拿走 %ld 個，可以先留著，從 10 裡拿走 %ld 個。", (long)a, (long)ones, (long)ones, (long)b, (long)b],
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
    self.renderedSnapshotStep = step;
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
    BOOL paused = self.playbackState == LessonIntroPlaybackStateVisibilityPaused && self.playbackStepIndex == self.step;
    self.visibilityInstruction.hidden = !paused;
    [self layoutVisibilityInstruction];
    [self setNeedsLayout];
    self.replayButton.accessibilityHint = paused
        ? @"可滑動看圖，或用上一步和下一步比較。完整點點圖能顯示時，再按重看這一步。"
        : @"重看目前這一步，不會跳到下一步。";
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
        quantityPrefix, (long)first, (long)second, (long)crossed, self.currentSpokenNarration];
    NSString *state;
    switch (self.playbackState) {
        case LessonIntroPlaybackStateRunning: state = @"動態播放中"; break;
        case LessonIntroPlaybackStateCompleted: state = @"動態播放完成"; break;
        case LessonIntroPlaybackStateCancelled: state = @"動態已停止，顯示目前這一步"; break;
        case LessonIntroPlaybackStateReducedMotion: state = @"減少動態，直接顯示這一步"; break;
        case LessonIntroPlaybackStateVisibilityPaused: state = @"點點圖未完整顯示，先看圖再重播"; break;
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

/// Pedagogical framing is not motion admission. Long narration must never
/// make an otherwise fully visible causal action fail its independent gate.
/// All bounds are actual laid-out rectangles in the stage's coordinate space;
/// equation/narration/listen are siblings, not additions to requiredActionBounds.
- (CGRect)explanationFramingBoundsForScene:(CGRect)scene {
    if (![self isTenStrategy] || CGRectIsNull(scene) || CGRectIsEmpty(scene)) return CGRectNull;
    CGRect viewport = [self visibleStageRect];
    if (CGRectIsNull(viewport) || CGRectIsEmpty(viewport)) return CGRectNull;
    CGRect explanation = CGRectUnion(scene, [self.narration convertRect:self.narration.bounds toView:self.stage]);
    CGRect withRead = CGRectUnion(explanation, [self.readButton convertRect:self.readButton.bounds toView:self.stage]);
    CGRect withQuestion = CGRectUnion(explanation, [self.problemLabel convertRect:self.problemLabel.bounds toView:self.stage]);
    CGRect withQuestionAndRead = CGRectUnion(withQuestion, withRead);
    // The original problem is more useful than a duplicate listening action.
    // Prefer its exact union with the complete causal scene and narration only
    // when all of it fits. Otherwise retain the honest existing fallback; the
    // inline Read still scrolls normally and its pinned twin is always present.
    for (NSValue *candidate in @[[NSValue valueWithCGRect:withQuestionAndRead], [NSValue valueWithCGRect:withQuestion],
        [NSValue valueWithCGRect:withRead], [NSValue valueWithCGRect:explanation]]) {
        CGRect bounds = candidate.CGRectValue;
        if (bounds.size.width <= viewport.size.width && bounds.size.height <= viewport.size.height) return bounds;
    }
    // If full narration cannot fit, keep the original question with the whole
    // causal scene when their exact union fits the real clipped viewport.
    CGRect questionAndScene = CGRectUnion(scene,
        [self.problemLabel convertRect:self.problemLabel.bounds toView:self.stage]);
    if (questionAndScene.size.width <= viewport.size.width
        && questionAndScene.size.height <= viewport.size.height) return questionAndScene;
    return CGRectNull; // The fixed speaker still reads the full current text.
}

- (void)frameNewStepScene:(CGRect)scene frames:(CGRect)frames counters:(CGRect)counters {
    // New steps prefer the complete explanation even when the diagram alone
    // already fits. Replay reaches this method only if its action was clipped,
    // preserving every already-safe inspection offset exactly. Initial static
    // presentation retains its smaller fallbacks; motion never drops context.
    CGRect explanation = [self explanationFramingBoundsForScene:scene];
    CGRect preferred = CGRectIsNull(explanation) ? scene : explanation;
    if ([self stageRectIsFullyVisible:preferred]) return;
    CGRect actualViewport = [self visibleStageRect];
    if (CGRectIsNull(actualViewport) || CGRectIsEmpty(actualViewport)) return;
    for (NSValue *candidate in @[[NSValue valueWithCGRect:explanation], [NSValue valueWithCGRect:scene],
        [NSValue valueWithCGRect:frames], [NSValue valueWithCGRect:counters]]) {
        CGRect bounds = candidate.CGRectValue;
        if (CGRectIsNull(bounds) || CGRectIsEmpty(bounds)) continue;
        if (bounds.size.width > actualViewport.size.width || bounds.size.height > actualViewport.size.height) continue;
        CGRect padded = CGRectInset(bounds, -4, -4);
        if (padded.size.width <= actualViewport.size.width && padded.size.height <= actualViewport.size.height) bounds = padded;
        CGRect target = [self.stage convertRect:bounds toView:self.scrollView];
        CGRect viewport = [self.stage convertRect:actualViewport toView:self.scrollView];
        CGFloat dx = CGRectGetMinX(target) < CGRectGetMinX(viewport) ? CGRectGetMinX(target) - CGRectGetMinX(viewport)
            : MAX(0, CGRectGetMaxX(target) - CGRectGetMaxX(viewport));
        CGFloat dy = CGRectGetMinY(target) < CGRectGetMinY(viewport) ? CGRectGetMinY(target) - CGRectGetMinY(viewport)
            : MAX(0, CGRectGetMaxY(target) - CGRectGetMaxY(viewport));
        UIEdgeInsets insets = self.scrollView.adjustedContentInset;
        CGPoint offset = self.scrollView.contentOffset;
        offset.x = MAX(-insets.left, MIN(offset.x + dx,
            MAX(-insets.left, self.scrollView.contentSize.width - self.scrollView.bounds.size.width + insets.right)));
        offset.y = MAX(-insets.top, MIN(offset.y + dy,
            MAX(-insets.top, self.scrollView.contentSize.height - self.scrollView.bounds.size.height + insets.bottom)));
        [self.scrollView setContentOffset:offset animated:NO];
        return; // The admission gate independently verifies real containment.
    }
}

- (void)renderStepAnimated:(BOOL)animated frameNewStep:(BOOL)frameNewStep {
    [self cancelStepAnimation];
    [self updateStepText];
    if (animated) {
        self.visibilityInstruction.hidden = YES;
        // Replay also needs final layout before computing its own complete
        // before/after scene. Layout itself has no framing permission.
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [self.scrollView layoutIfNeeded];
        self.playbackGeneration++;
        self.playbackStepIndex = self.step;
        self.playbackState = LessonIntroPlaybackStateCancelled;
    }
    if (![self prepareStageDots]) { [self updateStageAccessibility]; return; }
    // Replay already owns this selected endpoint (also while UIKit presents a
    // moving counter). Read that actual snapshot instead of applying an extra
    // target before its source. A new step/layout builds its own endpoint once.
    if (!animated || frameNewStep || self.renderedSnapshotStep != self.step) {
        [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step]; }];
    }
    CGRect required = [self visibleDiagramBoundsWithFrames:YES annotations:YES];
    CGRect frames = [self visibleDiagramBoundsWithFrames:YES annotations:NO];
    CGRect counters = [self visibleDiagramBoundsWithFrames:NO annotations:NO];
    if (animated) {
        // Reconstruct the selected step's own source. Sampling the two real
        // snapshots never changes the original source→target Replay sequence.
        [UIView performWithoutAnimation:^{ [self applyDotStateForStep:self.step - 1]; }];
        required = CGRectUnion(required, [self visibleDiagramBoundsWithFrames:YES annotations:YES]);
        frames = CGRectUnion(frames, [self visibleDiagramBoundsWithFrames:YES annotations:NO]);
        counters = CGRectUnion(counters, [self visibleDiagramBoundsWithFrames:NO annotations:NO]);
    }
    NSArray<CLIntroTransferLeg *> *transferLegs = self.lessonKind == LessonKindMakeTen && self.step == 3
        ? [self makeTenTransferLegs] : nil;
    if (animated && transferLegs.count) required = CGRectUnion(required, [self makeTenTransferBounds:transferLegs]);
    self.requiredActionBounds = required;
    if (animated && (frameNewStep || ([self isTenStrategy] && ![self isRequiredActionVisible]))) {
        // Only explicit selection may frame the teaching unit. A fully visible
        // causal Replay retains its exact offset, including deliberate text
        // inspection; the fixed speaker never requires a corrective scroll.
        [self frameNewStepScene:required frames:[self isTenStrategy] ? required : frames
            counters:[self isTenStrategy] ? required : counters];
    }
    if (animated) {
        self.playbackState = [self prefersReducedMotion] ? LessonIntroPlaybackStateReducedMotion
            : ![self isEffectivelyVisible] ? LessonIntroPlaybackStateCancelled
            : [self isTenStrategy] && ![self isRequiredActionVisible] ? LessonIntroPlaybackStateVisibilityPaused
            : LessonIntroPlaybackStateRunning;
    }
    if (animated && self.playbackState == LessonIntroPlaybackStateRunning && [self isTenStrategy]) {
        // Replay may begin with a committed destination presentation. Merely
        // assigning the model source in this same transaction leaves delayed
        // keyframes inheriting that old presentation while they wait. Commit
        // the complete source now, before UIKit captures any new keyframe.
        // This introduces no timer, pre-roll delay or forced animation finish.
        [CATransaction flush];
        [self validatePlaybackVisibility];
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
    } else if (animated) {
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
