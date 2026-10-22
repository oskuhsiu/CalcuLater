#import "VerticalTeachingViewController.h"
#import "ArithmeticTeachingSequence.h"
#import "VerticalArithmeticBoardView.h"
#import "WordProblem.h"
#import "ChildUIKit.h"
#import "SoundManager.h"
#import "SpeechManager.h"
#import <math.h>

typedef NS_ENUM(NSInteger, VTInspectionAnchor) {
    VTInspectionAnchorHeading, VTInspectionAnchorAction, VTInspectionAnchorWritten,
    VTInspectionAnchorFeedback, VTInspectionAnchorChoices, VTInspectionAnchorNotice
};

/// VoiceOver scrolling is deliberate inspection too, but need not begin a pan.
@interface VTInspectionScrollView : UIScrollView
@property (nonatomic, copy) void (^inspectionBegan)(void);
@end
@implementation VTInspectionScrollView
- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction {
    if (self.inspectionBegan) self.inspectionBegan();
    return [super accessibilityScroll:direction];
}
@end

@interface VerticalTeachingViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) ArithmeticTeachingSequence *sequence;
@property (nonatomic, strong) WordProblem *wordProblem;
@property (nonatomic) NSUInteger stepIndex;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *content;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UILabel *narration;
@property (nonatomic, strong) VerticalArithmeticBoardView *board;
@property (nonatomic, strong) NSLayoutConstraint *boardHeight;
@property (nonatomic, strong) UIStackView *predictionStack;
@property (nonatomic, strong) UILabel *prompt;
@property (nonatomic, strong) UIStackView *choices;
@property (nonatomic, strong) UILabel *choiceFeedback;
@property (nonatomic, strong) ChildButton *previousButton;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) ChildButton *replayButton;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableSet<NSNumber *> *> *attemptedValues;
@property (nonatomic, strong) NSMutableIndexSet *answeredSteps;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *lastAttemptedValues;
@property (nonatomic, strong) ChildButton *focusButton;
@property (nonatomic, strong) UILabel *playbackNotice;
@property (nonatomic) VTInspectionAnchor inspectionAnchor;
@property (nonatomic) BOOL hasManualInspection;
@property (nonatomic) BOOL framingContent;
@property (nonatomic) BOOL needsSemanticReframe;
@property (nonatomic) CGSize lastViewportSize;
@property (nonatomic) BOOL hasMeasuredContentGeometry;
@property (nonatomic) CGRect lastBoardFrameInScroll;
@property (nonatomic) CGSize lastContentSize;
@property (nonatomic) NSUInteger semanticReframeGeneration;
#if DEBUG
@property (nonatomic, strong) NSMutableArray<NSString *> *playbackLayoutObservations;
#endif
- (BOOL)frameCurrentTransformation;
- (void)beginManualInspection;
- (void)recordPlaybackLayoutEvent:(NSString *)event;
@end

@implementation VerticalTeachingViewController
+ (BOOL)supportsProblem:(ArithmeticProblem *)problem wordProblem:(WordProblem *)wordProblem {
    // A missing-part or two-step story must keep its own reasoning, not a
    // numerically similar but semantically different vertical calculation.
    if (wordProblem && (wordProblem.isFractionAnswer || wordProblem.operator2
        || wordProblem.missingAddend || wordProblem.missingSubtrahend || wordProblem.missingMinuend)) return NO;
    return [ArithmeticTeachingSequence sequenceForProblem:problem].isValid;
}
- (instancetype)initWithProblem:(ArithmeticProblem *)problem wordProblem:(WordProblem *)wordProblem {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sequence = [ArithmeticTeachingSequence sequenceForProblem:problem];
        _wordProblem = wordProblem;
        _attemptedValues = [NSMutableDictionary dictionary];
        _answeredSteps = [NSMutableIndexSet indexSet];
        _lastAttemptedValues = [NSMutableDictionary dictionary];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pausePlayback)
            name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (UILabel *)labelWithSize:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[ChildWrappingLabel alloc] init];
    label.font = [ChildUI scaledRoundedFontOfSize:size weight:weight textStyle:UIFontTextStyleBody maximumPointSize:size * 1.65];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = ChildUI.brownText;
    label.numberOfLines = 0;
    return label;
}
- (ChildButton *)button:(NSString *)title color:(UIColor *)color action:(SEL)action {
    ChildButton *button = [ChildButton buttonWithTitle:title backgroundColor:color];
    button.titleLabel.font = [ChildUI scaledRoundedFontOfSize:20 weight:UIFontWeightBold textStyle:UIFontTextStyleBody maximumPointSize:27];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    NSLayoutConstraint *height = [button.heightAnchor constraintGreaterThanOrEqualToConstant:60];
    height.priority = 999;
    height.active = YES;
    return button;
}
- (UIStackView *)stack {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    return stack;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ChildUI.creamBackground;
    self.view.accessibilityIdentifier = @"teaching.screen";
    self.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.largeDetent];
    self.sheetPresentationController.prefersGrabberVisible = YES;
    self.sheetPresentationController.preferredCornerRadius = 28;

    UIView *toolbar = [[UIView alloc] init];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:toolbar];
    ChildButton *close = [self button:@"回到題目" color:ChildUI.skyBlue action:@selector(close)];
    close.accessibilityIdentifier = @"explanation.close";
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [toolbar addSubview:close];
    self.focusButton = [self button:@"看直式" color:ChildUI.eggYolk action:@selector(focusCurrentContent)];
    self.focusButton.accessibilityIdentifier = @"teaching.focus";
    self.focusButton.translatesAutoresizingMaskIntoConstraints = NO;
    [toolbar addSubview:self.focusButton];

    UIStackView *navigation = [[UIStackView alloc] init];
    navigation.axis = UILayoutConstraintAxisHorizontal;
    navigation.distribution = UIStackViewDistributionFillEqually;
    navigation.spacing = 12;
    navigation.translatesAutoresizingMaskIntoConstraints = NO;
    self.previousButton = [self button:@"上一步" color:ChildUI.lavender action:@selector(previous)];
    self.previousButton.accessibilityIdentifier = @"teaching.previous";
    self.nextButton = [self button:@"下一小步" color:ChildUI.mintGreen action:@selector(next)];
    self.nextButton.accessibilityIdentifier = @"teaching.next";
    [navigation addArrangedSubview:self.previousButton];
    self.replayButton = [self button:@"重看" color:ChildUI.skyBlue action:@selector(replay)];
    self.replayButton.accessibilityIdentifier = @"teaching.replay";
    self.replayButton.accessibilityLabel = @"重看這一步";
    [navigation addArrangedSubview:self.replayButton];
    [navigation addArrangedSubview:self.nextButton];
    [self.view addSubview:navigation];

    VTInspectionScrollView *scroll = [[VTInspectionScrollView alloc] init];
    __weak typeof(self) weakSelf = self;
    scroll.inspectionBegan = ^{ [weakSelf beginManualInspection]; };
    self.scroll = scroll;
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.scroll.delegate = self;
    self.scroll.accessibilityIdentifier = @"teaching.content";
    [self.view addSubview:self.scroll];
    UIStackView *content = [self stack];
    self.content = content;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:content];
    NSLayoutConstraint *width = [content.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-32];
    width.priority = 999;
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [toolbar.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [toolbar.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [toolbar.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [toolbar.heightAnchor constraintEqualToConstant:60],
        [close.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor],
        [close.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:120],
        [self.focusButton.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor],
        [self.focusButton.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-12],
        [self.focusButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [navigation.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [navigation.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [navigation.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [self.scroll.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor constant:8],
        [self.scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:navigation.topAnchor constant:-12],
        [self.scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor],
        [content.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:12],
        [content.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [content.centerXAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.centerXAnchor],
        [content.widthAnchor constraintLessThanOrEqualToConstant:680], width,
        [content.widthAnchor constraintLessThanOrEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-32],
    ]];

    self.progressLabel = [self labelWithSize:17 weight:UIFontWeightSemibold];
    self.progressLabel.accessibilityIdentifier = @"teaching.progress";
    [content addArrangedSubview:self.progressLabel];
    self.heading = [self labelWithSize:27 weight:UIFontWeightBold];
    self.heading.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.heading.accessibilityIdentifier = @"teaching.heading";
    [content addArrangedSubview:self.heading];
    self.narration = [self labelWithSize:21 weight:UIFontWeightMedium];
    self.narration.accessibilityIdentifier = @"explanation.steps";
    [content addArrangedSubview:self.narration];
    self.board = [[VerticalArithmeticBoardView alloc] initWithFrame:CGRectZero];
    self.boardHeight = [self.board.heightAnchor constraintEqualToConstant:370];
    self.boardHeight.active = YES;

    self.predictionStack = [self stack];
    self.prompt = [self labelWithSize:22 weight:UIFontWeightSemibold];
    self.prompt.accessibilityIdentifier = @"teaching.prompt";
    [self.predictionStack addArrangedSubview:self.prompt];
    self.choices = [[UIStackView alloc] init];
    self.choices.axis = UILayoutConstraintAxisHorizontal;
    self.choices.spacing = 12;
    self.choices.distribution = UIStackViewDistributionFillEqually;
    [self.predictionStack addArrangedSubview:self.choices];
    self.choiceFeedback = [self labelWithSize:18 weight:UIFontWeightMedium];
    self.choiceFeedback.accessibilityIdentifier = @"teaching.feedback";
    [self.predictionStack addArrangedSubview:self.choiceFeedback];
    [content addArrangedSubview:self.predictionStack];

    self.playbackNotice = [self labelWithSize:18 weight:UIFontWeightSemibold];
    self.playbackNotice.accessibilityIdentifier = @"teaching.playbackNotice";
    [content addArrangedSubview:self.board];
    ChildButton *read = [self button:@"聽聽這一步" color:ChildUI.skyBlue action:@selector(readStep)];
    read.accessibilityIdentifier = @"teaching.read";
    [content addArrangedSubview:read];
    ChildButton *restart = [self button:@"從頭再看" color:ChildUI.eggYolk action:@selector(restart)];
    restart.accessibilityIdentifier = @"teaching.restart";
    [content addArrangedSubview:restart];
    if (self.wordProblem) {
        UILabel *story = [self labelWithSize:18 weight:UIFontWeightMedium];
        story.text = [@"回頭看看題目：\n" stringByAppendingString:self.wordProblem.storyText];
        [content addArrangedSubview:story];
    }
    [self showCurrentStepAnimated:NO];
}

- (ArithmeticTeachingStep *)currentStep {
    return self.sequence.isValid && self.stepIndex < self.sequence.steps.count ? self.sequence.steps[self.stepIndex] : nil;
}
- (void)showCurrentStepAnimated:(BOOL)animated {
    self.semanticReframeGeneration++;
    [[self speechManager] stop];
    [self.playbackNotice removeFromSuperview];
    self.inspectionAnchor = VTInspectionAnchorHeading;
    self.hasManualInspection = NO;
    ArithmeticTeachingStep *step = self.currentStep;
    if (!step) {
        self.heading.text = @"先回到題目看看";
        self.narration.text = @"這一題沒有合適的直式步驟，先用題目的做法一起想。";
        [self.predictionStack removeFromSuperview];
        self.previousButton.enabled = NO;
        [self.nextButton setTitle:@"回到題目" forState:UIControlStateNormal];
        return;
    }
    self.progressLabel.text = [NSString stringWithFormat:@"第 %lu 小步 · 共 %lu 步 · 不用急",
        (unsigned long)self.stepIndex + 1, (unsigned long)self.sequence.steps.count];
    self.heading.text = step.title;
    self.narration.text = step.explanation;
    [self.board configureWithSequence:self.sequence stepIndex:self.stepIndex animated:NO];
    self.previousButton.enabled = self.stepIndex > 0;
    BOOL prediction = step.kind == ArithmeticTeachingStepKindPrediction;
    // Detach the nested stack rather than imposing a required zero height over
    // its required internal spacers, especially when choices stack vertically.
    if (prediction && !self.predictionStack.superview) {
        [self.content insertArrangedSubview:self.predictionStack
            atIndex:[self.content.arrangedSubviews indexOfObject:self.board]];
    } else if (!prediction) {
        [self.predictionStack removeFromSuperview];
    }
    self.replayButton.enabled = step.kind != ArithmeticTeachingStepKindAlignment;
    [self.nextButton setTitle:step.kind == ArithmeticTeachingStepKindCompletion ? @"回到題目"
        : prediction && ![self.answeredSteps containsIndex:self.stepIndex] ? @"先看示範" : @"下一小步"
        forState:UIControlStateNormal];
    if (prediction) [self configurePrediction];
    [self updateFocusButton];
    self.framingContent = YES;
    [self.scroll setContentOffset:CGPointZero animated:NO];
    self.framingContent = NO;
    // Set this snapshot's measured height BEFORE asking the stack to lay out.
    // A genuine later resize must still interrupt motion, not silently replay it.
    [self updateBoardHeight];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self updateBoardHeight];
    [self.view layoutIfNeeded];
    BOOL framedTransformation = NO;
    if (animated) framedTransformation = [self playCurrentAction];
    id focus = self.playbackNotice.superview ? self.playbackNotice
        : framedTransformation ? self.board.accessibilityElements.lastObject : self.heading;
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, focus);
}
- (CGRect)unobscuredViewport {
    return UIEdgeInsetsInsetRect(self.scroll.bounds, UIEdgeInsetsMake(8, 0, 8, 0));
}
- (BOOL)viewportContainsBoardRect:(CGRect)rect {
    return !CGRectIsNull(rect) && !CGRectIsEmpty(rect)
        && CGRectContainsRect(self.unobscuredViewport, [self.board convertRect:rect toView:self.scroll]);
}
- (BOOL)frameRect:(CGRect)rect inView:(UIView *)view {
    if (!view || CGRectIsNull(rect) || CGRectIsEmpty(rect) || self.scroll.bounds.size.height <= 16) return NO;
    CGRect target = [view convertRect:rect toView:self.scroll];
    CGRect viewport = self.unobscuredViewport;
    if (CGRectContainsRect(viewport, target)) return NO;
    CGFloat proposed = CGRectGetMinY(target) - MAX(8, (self.scroll.bounds.size.height - target.size.height) / 2);
    CGFloat maximum = MAX(0, self.scroll.contentSize.height - self.scroll.bounds.size.height);
    self.framingContent = YES;
    [self.scroll setContentOffset:CGPointMake(0, MIN(maximum, MAX(0, proposed))) animated:NO];
    self.framingContent = NO;
    return YES;
}
- (BOOL)frameCurrentTransformation {
    CGRect focus = self.board.currentTransformationRect;
    if (CGRectIsNull(focus) || CGRectIsEmpty(focus)) return NO;
    // Reframe semantically after inspection/rotation; playback is checked only
    // AFTER scrolling, against the complete action and real clipping ancestors.
    if (focus.size.height > self.unobscuredViewport.size.height || focus.size.width > self.unobscuredViewport.size.width)
        focus = self.board.currentConcreteTransformationRect;
    return [self frameRect:focus inView:self.board];
}
- (void)updateFocusButton {
    BOOL prediction = self.currentStep.kind == ArithmeticTeachingStepKindPrediction;
    BOOL exchange = self.currentStep.kind == ArithmeticTeachingStepKindRegroup;
    NSString *title = prediction ? (self.inspectionAnchor == VTInspectionAnchorWritten ? @"回到選項" : @"看數量")
        : exchange && self.inspectionAnchor != VTInspectionAnchorAction ? @"看交換" : @"看直式";
    [self.focusButton setTitle:title forState:UIControlStateNormal];
    self.focusButton.accessibilityHint = prediction ? @"只換看的位置，不換步驟，也不計分"
        : @"只換看的位置；要播放這一步，請按重看";
}
- (void)focusCurrentContent {
    [self pausePlayback];
    self.hasManualInspection = NO;
    if (self.currentStep.kind == ArithmeticTeachingStepKindPrediction && self.inspectionAnchor == VTInspectionAnchorWritten) {
        self.inspectionAnchor = VTInspectionAnchorChoices;
        [self framePredictionChoices];
    } else if (self.currentStep.kind == ArithmeticTeachingStepKindRegroup && self.inspectionAnchor != VTInspectionAnchorAction) {
        self.inspectionAnchor = VTInspectionAnchorAction;
        [self frameRect:self.board.currentConcreteTransformationRect inView:self.board];
    } else {
        self.inspectionAnchor = VTInspectionAnchorWritten;
        [self frameRect:self.board.currentWrittenRect inView:self.board];
    }
    [self updateFocusButton];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification,
        self.inspectionAnchor == VTInspectionAnchorChoices ? self.prompt
            : self.inspectionAnchor == VTInspectionAnchorAction ? self.board.accessibilityElements.lastObject
            : self.board.accessibilityElements.firstObject);
}
- (BOOL)playCurrentAction {
    CGRect action = self.board.currentActionRect;
    if (CGRectIsNull(action) || CGRectIsEmpty(action)) {
        if (self.currentStep.kind == ArithmeticTeachingStepKindWriteAnswer) {
            // Leading zeroes deliberately stay blank. Keep the explanation in
            // view, including when Replay follows inspection of the written work.
            self.hasManualInspection = NO;
            self.inspectionAnchor = VTInspectionAnchorHeading;
            CGRect narration = [self.narration convertRect:self.narration.bounds toView:self.content];
            CGRect explanation = CGRectUnion(narration, [self.heading convertRect:self.heading.bounds toView:self.content]);
            if (explanation.size.height > self.unobscuredViewport.size.height) explanation = narration;
            [self frameRect:explanation inView:self.content];
            [self updateFocusButton];
        }
        return NO;
    }
    self.hasManualInspection = NO;
    self.inspectionAnchor = VTInspectionAnchorAction;
    if (self.currentStep.kind == ArithmeticTeachingStepKindRegroup) [self frameCurrentTransformation];
    else [self frameRect:action inView:self.board];
    CGRect visible = [self.scroll convertRect:self.unobscuredViewport toView:self.board];
    [self recordPlaybackLayoutEvent:@"admission-before"];
    if ([self.board playCurrentActionInVisibleRect:visible]) {
        [self recordPlaybackLayoutEvent:@"admission-accepted"];
        [self updateFocusButton];
        return YES;
    }
    [self recordPlaybackLayoutEvent:@"admission-refused"];
    // Never start a partially visible action. Everything remains inspectable.
    self.playbackNotice.text = @"畫面放不下完整動作，先停在這一步。\n直拿手機後按「重看」，或用上方按鈕慢慢看。";
    if (!self.playbackNotice.superview) [self.content insertArrangedSubview:self.playbackNotice
        atIndex:[self.content.arrangedSubviews indexOfObject:self.board]];
    self.inspectionAnchor = VTInspectionAnchorNotice;
    [self.view layoutIfNeeded];
    [self frameRect:self.playbackNotice.bounds inView:self.playbackNotice];
    [self updateFocusButton];
    return NO;
}
- (void)framePredictionChoices {
    CGRect choices = [self.choices convertRect:self.choices.bounds toView:self.content];
    CGRect prompt = [self.prompt convertRect:self.prompt.bounds toView:self.content];
    CGRect combined = CGRectUnion(choices, prompt);
    [self frameRect:combined.size.height <= self.unobscuredViewport.size.height ? combined : choices inView:self.content];
}
- (void)framePredictionFeedback {
    CGRect feedback = [self.choiceFeedback convertRect:self.choiceFeedback.bounds toView:self.content];
    CGRect choices = [self.choices convertRect:self.choices.bounds toView:self.content];
    CGRect combined = CGRectUnion(choices, feedback);
    [self frameRect:combined.size.height <= self.unobscuredViewport.size.height ? combined : feedback inView:self.content];
}
- (NSString *)unitForColumn:(NSInteger)column {
    NSInteger place = self.sequence.columnCount - 1 - column;
    return place >= 0 && place < 5 ? @[@"一", @"十", @"百", @"千", @"萬"][place] : @"";
}
- (NSString *)placeForColumn:(NSInteger)column {
    NSInteger place = self.sequence.columnCount - 1 - column;
    return place >= 0 && place < 5 ? @[@"個位", @"十位", @"百位", @"千位", @"萬位"][place] : @"";
}
- (NSString *)feedbackForSelection:(NSNumber *)selection answered:(BOOL)answered {
    if (!selection) return @"可以先想想，也可以直接看示範。";
    ArithmeticTeachingStep *step = self.currentStep;
    NSInteger column = step.activeColumn;
    NSString *unit = [self unitForColumn:column];
    NSString *detail;
    ArithmeticTeachingStep *next = self.stepIndex + 1 < self.sequence.steps.count ? self.sequence.steps[self.stepIndex + 1] : nil;
    if (next.kind == ArithmeticTeachingStepKindRegroup && next) {
        NSString *sourceUnit = [self unitForColumn:next.sourceColumn];
        NSString *comparison = answered ? @"" : [NSString stringWithFormat:@"，比 1 個%@%@", sourceUnit,
            selection.integerValue < step.expectedAnswer.integerValue ? @"少" : @"多"];
        detail = [NSString stringWithFormat:@"你選 %@ 個%@%@。1 個%@ = 10 個%@，數量不變。", selection, unit, comparison, sourceUnit, unit];
    } else if ([self.sequence.problem.operatorSymbol isEqualToString:@"+"]) {
        NSInteger first = step.firstDigits[column].integerValue;
        NSInteger second = step.secondDigits[column].integerValue;
        NSInteger carry = step.carryDigits[column].integerValue;
        NSString *expression = carry > 0 ? [NSString stringWithFormat:@"%ld + %ld + %ld", (long)first, (long)second, (long)carry]
            : [NSString stringWithFormat:@"%ld + %ld", (long)first, (long)second];
        detail = answered ? [NSString stringWithFormat:@"%@ = %@ 個%@。", expression, selection, unit]
            : [NSString stringWithFormat:@"你選 %@ 個%@。再看%@的 %@ 個%@，把這些數量合起來。", selection, unit, [self placeForColumn:column], expression, unit];
    } else {
        NSInteger first = step.workingDigits[column].integerValue;
        NSInteger second = step.secondDigits[column].integerValue;
        detail = answered ? [NSString stringWithFormat:@"%ld − %ld = %@ 個%@。", (long)first, (long)second, selection, unit]
            : [NSString stringWithFormat:@"你選 %@ 個%@。%@有 %ld 個%@，拿走 %ld 個%@，再數剩下的。", selection, unit, [self placeForColumn:column], (long)first, unit, (long)second, unit];
    }
    return [detail stringByAppendingString:answered ? @"準備好再看下一步。" : @"可按「看數量」再想想，不計分。"];
}
- (NSArray<NSNumber *> *)choiceValuesForStep:(ArithmeticTeachingStep *)step {
    NSInteger answer = step.expectedAnswer.integerValue;
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithObject:@(answer)];
    BOOL exchangeNext = self.stepIndex + 1 < self.sequence.steps.count
        && self.sequence.steps[self.stepIndex + 1].kind == ArithmeticTeachingStepKindRegroup;
    NSArray<NSNumber *> *candidates = exchangeNext ? @[@1, @10, @100, @0]
        : @[@(MAX(0, answer - 1)), @(answer + 1), @(answer + 2)];
    for (NSNumber *candidate in candidates) {
        if (![values containsObject:candidate]) [values addObject:candidate];
        if (values.count == 3) break;
    }
    // Stable across Replay and Back, without always putting the answer first.
    NSUInteger destination = self.stepIndex % values.count;
    [values exchangeObjectAtIndex:0 withObjectAtIndex:destination];
    return values;
}
- (void)configurePrediction {
    ArithmeticTeachingStep *step = self.currentStep;
    self.prompt.text = step.prompt;
    for (UIView *view in self.choices.arrangedSubviews.copy) [view removeFromSuperview];
    for (NSNumber *value in [self choiceValuesForStep:step]) {
        ChildButton *button = [self button:value.stringValue color:ChildUI.eggYolk action:@selector(choosePrediction:)];
        button.tag = value.integerValue;
        button.accessibilityIdentifier = [NSString stringWithFormat:@"teaching.choice.%@", value];
        button.accessibilityLabel = [NSString stringWithFormat:@"我想是 %@", value];
        [self.choices addArrangedSubview:button];
    }
    [self updatePredictionFeedback];
}
- (void)updatePredictionFeedback {
    ArithmeticTeachingStep *step = self.currentStep;
    BOOL answered = [self.answeredSteps containsIndex:self.stepIndex];
    NSSet<NSNumber *> *attempts = self.attemptedValues[@(self.stepIndex)];
    for (ChildButton *button in self.choices.arrangedSubviews) {
        BOOL correctChosen = answered && button.tag == step.expectedAnswer.integerValue;
        BOOL tried = [attempts containsObject:@(button.tag)];
        button.enabled = !answered && !tried;
        button.layer.borderWidth = correctChosen || tried ? 2 : 0;
        button.layer.borderColor = ChildUI.brownText.CGColor;
        button.backgroundColor = correctChosen ? ChildUI.mintGreen : tried ? ChildUI.wrongPink : ChildUI.eggYolk;
        button.accessibilityValue = correctChosen ? @"和這一步的數量相同" : tried ? @"再想一想" : @"還沒選擇";
        [button setTitle:[NSString stringWithFormat:@"%@%ld", correctChosen ? @"✓ " : tried ? @"↻ " : @"", (long)button.tag]
            forState:UIControlStateNormal];
    }
    self.choiceFeedback.text = [self feedbackForSelection:self.lastAttemptedValues[@(self.stepIndex)] answered:answered];
}
- (void)choosePrediction:(UIButton *)button {
    ArithmeticTeachingStep *step = self.currentStep;
    if (step.kind != ArithmeticTeachingStepKindPrediction || !button.enabled
        || ![self.choices.arrangedSubviews containsObject:button] || [self.answeredSteps containsIndex:self.stepIndex]) return;
    self.semanticReframeGeneration++;
    NSNumber *key = @(self.stepIndex);
    NSMutableSet<NSNumber *> *attempts = self.attemptedValues[key];
    if (!attempts) self.attemptedValues[key] = attempts = [NSMutableSet set];
    [attempts addObject:@(button.tag)];
    self.lastAttemptedValues[key] = @(button.tag);
    if (button.tag == step.expectedAnswer.integerValue) {
        [self.answeredSteps addIndex:self.stepIndex];
        [SoundManager.sharedInstance play:SoundEffectCorrect];
        [self.nextButton setTitle:@"下一小步" forState:UIControlStateNormal];
    }
    [self updatePredictionFeedback];
    self.inspectionAnchor = VTInspectionAnchorFeedback;
    self.hasManualInspection = NO;
    [self updateFocusButton];
    [self.view layoutIfNeeded];
    [self framePredictionFeedback];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.choiceFeedback);
}
- (void)next {
    if (!self.sequence.isValid || self.stepIndex + 1 >= self.sequence.steps.count) { [self close]; return; }
    self.stepIndex++;
    [self showCurrentStepAnimated:YES];
}
- (void)previous {
    if (self.stepIndex == 0) return;
    self.stepIndex--;
    [self showCurrentStepAnimated:NO];
}
- (void)replay {
    self.semanticReframeGeneration++;
    [[self speechManager] stop];
    // Replay recovers semantic focus, not an obsolete numerical offset.
    [self.playbackNotice removeFromSuperview];
    [self.board showStepAtIndex:self.stepIndex animated:NO];
    [self updateBoardHeight];
    [self.view layoutIfNeeded];
    [self updateBoardHeight];
    [self.view layoutIfNeeded];
    BOOL focused = [self playCurrentAction];
    if (!focused && self.currentStep.kind == ArithmeticTeachingStepKindPrediction) {
        self.inspectionAnchor = VTInspectionAnchorChoices;
        [self framePredictionChoices];
        [self updateFocusButton];
    }
    id focus = self.playbackNotice.superview ? self.playbackNotice
        : self.currentStep.kind == ArithmeticTeachingStepKindRegroup ? self.board.accessibilityElements.lastObject
        : self.currentStep.kind == ArithmeticTeachingStepKindPrediction ? self.prompt
        : !focused && self.currentStep.kind == ArithmeticTeachingStepKindWriteAnswer ? self.heading
        : self.board.accessibilityElements.firstObject;
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, focus);
}
- (void)restart {
    [self.answeredSteps removeAllIndexes];
    [self.attemptedValues removeAllObjects];
    [self.lastAttemptedValues removeAllObjects];
    self.stepIndex = 0;
    [self showCurrentStepAnimated:NO];
}
- (SpeechManager *)speechManager { return SpeechManager.sharedInstance; }
- (void)readStep {
    ArithmeticTeachingStep *step = self.currentStep;
    NSString *speech = step.kind == ArithmeticTeachingStepKindPrediction
        ? [NSString stringWithFormat:@"%@。%@。%@", step.title, step.explanation, step.prompt]
        : [NSString stringWithFormat:@"%@。%@", step.title, step.explanation];
    if (step.kind == ArithmeticTeachingStepKindPrediction && self.lastAttemptedValues[@(self.stepIndex)]) {
        // Read only this prediction's visible coaching, on explicit request.
        speech = [NSString stringWithFormat:@"%@ %@", speech, self.choiceFeedback.text];
    }
    [[self speechManager] speak:speech];
}
- (void)close {
    [self pausePlayback];
    if (self.returnToQuestion) self.returnToQuestion();
    else [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)pausePlayback {
    self.semanticReframeGeneration++;
    [self recordPlaybackLayoutEvent:@"pause-request"];
    [self.board cancelAnimations];
    [[self speechManager] stop];
}
- (void)reframeCurrentInspection {
    if (self.hasManualInspection) return;
    if (self.inspectionAnchor == VTInspectionAnchorAction) {
        if (self.currentStep.kind == ArithmeticTeachingStepKindRegroup) [self frameCurrentTransformation];
        else [self frameRect:self.board.currentActionRect inView:self.board];
    } else if (self.inspectionAnchor == VTInspectionAnchorFeedback) [self framePredictionFeedback];
    else if (self.inspectionAnchor == VTInspectionAnchorChoices) [self framePredictionChoices];
    else if (self.inspectionAnchor == VTInspectionAnchorWritten) [self frameRect:self.board.currentWrittenRect inView:self.board];
    else if (self.inspectionAnchor == VTInspectionAnchorNotice) [self frameRect:self.playbackNotice.bounds inView:self.playbackNotice];
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self pausePlayback];
    NSUInteger generation = self.semanticReframeGeneration;
    __weak typeof(self) weakSelf = self;
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.semanticReframeGeneration || self.hasManualInspection || !self.view.window) return;
        // UIKit can finish changing contentOffset after the first size/layout
        // callback, without changing either content-space geometry signature.
        // Own exactly this transition's completion, never every later scroll.
        [self.view layoutIfNeeded];
        [self.scroll layoutIfNeeded];
        [self reframeCurrentInspection];
        [self recordPlaybackLayoutEvent:@"transition-completed-reframe"];
    }];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.board.isPlaying || self.board.playbackState == VerticalArithmeticPlaybackStateInterrupted)
        [self recordPlaybackLayoutEvent:@"layout-observed"];
    [self updateBoardHeight];
    BOOL largeText = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    self.choices.axis = largeText ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    if (!CGSizeEqualToSize(self.lastViewportSize, self.scroll.bounds.size)) {
        [self recordPlaybackLayoutEvent:@"viewport-size-changed"];
        self.lastViewportSize = self.scroll.bounds.size;
        self.needsSemanticReframe = YES;
        [self.board cancelAnimations];
    }
    // A fitted board height is not a settled stack: the labels above it can
    // invalidate their wrapped heights on the NEXT layout pass. Observe the
    // board's content-space position too, not just the viewport dimensions.
    // Scrolling does not change these coordinates, so a safe inspection offset
    // is retained and a learner's manual inspection never gets pulled back.
    if (!self.framingContent && fabs(self.board.bounds.size.height - self.boardHeight.constant) < 0.5) {
        [self.board layoutIfNeeded];
        CGRect boardFrame = [self.board convertRect:self.board.bounds toView:self.scroll];
        BOOL boardChanged = self.hasMeasuredContentGeometry
            && !CGRectEqualToRect(self.lastBoardFrameInScroll, boardFrame);
        BOOL contentChanged = !self.hasMeasuredContentGeometry || boardChanged
            || !CGSizeEqualToSize(self.lastContentSize, self.scroll.contentSize);
        if (contentChanged) [self recordPlaybackLayoutEvent:boardChanged ? @"board-geometry-changed" : @"content-size-settled"];
        self.hasMeasuredContentGeometry = YES;
        self.lastBoardFrameInScroll = boardFrame;
        self.lastContentSize = self.scroll.contentSize;
        if (contentChanged) {
            self.needsSemanticReframe = YES;
            // A footer's wrapped height or delayed contentSize update cannot
            // invalidate a stationary, fully visible action. Real board motion
            // still cancels, including upstream rewrapping at unchanged size.
            if (boardChanged) [self.board cancelAnimations];
        }
        if (self.needsSemanticReframe) {
            self.needsSemanticReframe = NO;
            // A content-size correction may also clamp the offset. Do not hide
            // an already-clipped playback by reframing it before checking.
            if (self.board.isPlaying && ![self viewportContainsBoardRect:self.board.currentPlaybackRect]) {
                [self recordPlaybackLayoutEvent:@"reframe-playback-outside-viewport"];
                [self.board cancelAnimations];
            }
            [self reframeCurrentInspection];
        }
    }
    // Wrapping can displace an action without changing the viewport size.
    if (self.board.isPlaying && ![self viewportContainsBoardRect:self.board.currentPlaybackRect]) {
        [self recordPlaybackLayoutEvent:@"layout-playback-outside-viewport"];
        [self.board cancelAnimations];
    }
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self beginManualInspection];
}
- (void)beginManualInspection {
    self.hasManualInspection = YES;
    [self pausePlayback];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.board.isPlaying && ![self viewportContainsBoardRect:self.board.currentPlaybackRect]) {
        [self recordPlaybackLayoutEvent:@"scroll-playback-outside-viewport"];
        [self.board cancelAnimations];
    }
}
- (void)recordPlaybackLayoutEvent:(NSString *)event {
#if DEBUG
    if (![NSProcessInfo.processInfo.arguments containsObject:@"-CalcuLaterVerticalPlaybackDiagnostics"]) return;
    if (!self.playbackLayoutObservations) self.playbackLayoutObservations = [NSMutableArray array];
    [self.playbackLayoutObservations addObject:[NSString stringWithFormat:
        @"uptime=%.6f event=%@ step=%lu state=%ld viewport=%@ board=%@ priorBoard=%@ fittedHeight=%.3f contentSize=%@ priorContentSize=%@ offset=%@ action=%@ manual=%d generation=%lu",
        NSProcessInfo.processInfo.systemUptime, event, (unsigned long)self.stepIndex, (long)self.board.playbackState,
        NSStringFromCGRect(self.unobscuredViewport), NSStringFromCGRect([self.board convertRect:self.board.bounds toView:self.scroll]),
        NSStringFromCGRect(self.lastBoardFrameInScroll), self.boardHeight.constant,
        NSStringFromCGSize(self.scroll.contentSize),
        NSStringFromCGSize(self.lastContentSize), NSStringFromCGPoint(self.scroll.contentOffset),
        NSStringFromCGRect(self.board.currentPlaybackRect), self.hasManualInspection, (unsigned long)self.semanticReframeGeneration]];
    if (self.playbackLayoutObservations.count > 32) [self.playbackLayoutObservations removeObjectAtIndex:0];
    // Opt-in test observations belong to the scroll container, never to the
    // exchange's spoken quantity/lifecycle value or its exact completion suffix.
    self.scroll.accessibilityValue = [self.playbackLayoutObservations componentsJoinedByString:@"\n"];
#endif
}
- (void)updateBoardHeight {
    CGFloat width = self.board.bounds.size.width;
    if (width > 0) {
        CGFloat height = MAX(240, [self.board sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
        if (fabs(self.boardHeight.constant - height) > 0.5) self.boardHeight.constant = height;
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self pausePlayback];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.heading);
}
@end
