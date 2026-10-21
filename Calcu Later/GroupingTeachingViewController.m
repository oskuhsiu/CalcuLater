#import "GroupingTeachingViewController.h"
#import "GroupingTeachingSequence.h"
#import "GroupingTeachingBoardView.h"
#import "WordProblem.h"
#import "ChildUIKit.h"
#import "SoundManager.h"
#import "SpeechManager.h"
#import <math.h>

@interface GroupingTeachingViewController ()
@property (nonatomic, strong) GroupingTeachingSequence *sequence;
@property (nonatomic, strong) GroupingTeachingSequence *alternativeSequence;
@property (nonatomic, strong) ChildButton *meaningButton;
@property (nonatomic, strong) WordProblem *wordProblem;
@property (nonatomic) NSUInteger stepIndex;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *content;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UILabel *narration;
@property (nonatomic, strong) GroupingTeachingBoardView *board;
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
- (BOOL)frameCurrentTransformation;
@end

@implementation GroupingTeachingViewController
// Stories enter through their full immutable model. Never fall back to an
// arithmetic-only interpretation when producer-supplied roles are missing.
+ (GroupingTeachingSequence *)sequenceForProblem:(ArithmeticProblem *)problem wordProblem:(WordProblem *)wordProblem {
    if (wordProblem) return [GroupingTeachingSequence sequenceForWordProblem:wordProblem];
    BOOL multiplication = [problem.operatorSymbol isEqualToString:@"×"] || [problem.operatorSymbol isEqualToString:@"*"];
    GroupingTeachingSequence *sequence = [GroupingTeachingSequence sequenceForArithmeticProblem:problem
        meaning:multiplication ? GroupingStoryMeaningBuildEqualGroups : GroupingStoryMeaningShareEqually];
    if (!multiplication && !sequence.isSupported) {
        sequence = [GroupingTeachingSequence sequenceForArithmeticProblem:problem meaning:GroupingStoryMeaningMakeGroupsOf];
    }
    return sequence;
}
+ (BOOL)supportsProblem:(ArithmeticProblem *)problem wordProblem:(WordProblem *)wordProblem {
    return [self sequenceForProblem:problem wordProblem:wordProblem].isSupported;
}
- (instancetype)initWithProblem:(ArithmeticProblem *)problem wordProblem:(WordProblem *)wordProblem {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sequence = [GroupingTeachingViewController sequenceForProblem:problem wordProblem:wordProblem];
        _wordProblem = _sequence.wordProblem;
        _attemptedValues = [NSMutableDictionary dictionary];
        _answeredSteps = [NSMutableIndexSet indexSet];
        if (!wordProblem && _sequence.isSupported && ![problem.operatorSymbol isEqualToString:@"×"]
            && ![problem.operatorSymbol isEqualToString:@"*"]) {
            GroupingStoryMeaning other = _sequence.context.meaning == GroupingStoryMeaningShareEqually
                ? GroupingStoryMeaningMakeGroupsOf : GroupingStoryMeaningShareEqually;
            GroupingTeachingSequence *alternative = [GroupingTeachingSequence sequenceForArithmeticProblem:problem meaning:other];
            if (alternative.isSupported) _alternativeSequence = alternative;
        }
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
    self.view.accessibilityIdentifier = @"grouping.screen";
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
    UILabel *title = [self labelWithSize:22 weight:UIFontWeightBold];
    title.text = @"一起分一分";
    title.font = [ChildUI scaledRoundedFontOfSize:22 weight:UIFontWeightBold textStyle:UIFontTextStyleHeadline maximumPointSize:26];
    title.numberOfLines = 1;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [toolbar addSubview:title];

    UIStackView *navigation = [[UIStackView alloc] init];
    navigation.axis = UILayoutConstraintAxisHorizontal;
    navigation.distribution = UIStackViewDistributionFillEqually;
    navigation.spacing = 12;
    navigation.translatesAutoresizingMaskIntoConstraints = NO;
    self.previousButton = [self button:@"上一步" color:ChildUI.lavender action:@selector(previous)];
    self.previousButton.accessibilityIdentifier = @"grouping.previous";
    self.nextButton = [self button:@"下一小步" color:ChildUI.mintGreen action:@selector(next)];
    self.nextButton.accessibilityIdentifier = @"grouping.next";
    [navigation addArrangedSubview:self.previousButton];
    self.replayButton = [self button:@"重看" color:ChildUI.skyBlue action:@selector(replay)];
    self.replayButton.accessibilityIdentifier = @"grouping.replay";
    self.replayButton.accessibilityLabel = @"重看這一步";
    [navigation addArrangedSubview:self.replayButton];
    [navigation addArrangedSubview:self.nextButton];
    [self.view addSubview:navigation];

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    self.scroll.accessibilityIdentifier = @"grouping.content";
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
        [title.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:close.leadingAnchor constant:-12],
        [title.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
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
    self.progressLabel.accessibilityIdentifier = @"grouping.progress";
    [content addArrangedSubview:self.progressLabel];
    self.heading = [self labelWithSize:27 weight:UIFontWeightBold];
    self.heading.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.heading.accessibilityIdentifier = @"grouping.heading";
    [content addArrangedSubview:self.heading];
    self.narration = [self labelWithSize:21 weight:UIFontWeightMedium];
    self.narration.accessibilityIdentifier = @"grouping.explanation";
    [content addArrangedSubview:self.narration];
    self.board = [[GroupingTeachingBoardView alloc] initWithFrame:CGRectZero];
    self.boardHeight = [self.board.heightAnchor constraintEqualToConstant:370];
    self.boardHeight.active = YES;

    self.predictionStack = [self stack];
    self.prompt = [self labelWithSize:22 weight:UIFontWeightSemibold];
    self.prompt.accessibilityIdentifier = @"grouping.prompt";
    [self.predictionStack addArrangedSubview:self.prompt];
    self.choices = [[UIStackView alloc] init];
    self.choices.axis = UILayoutConstraintAxisHorizontal;
    self.choices.spacing = 12;
    self.choices.distribution = UIStackViewDistributionFillEqually;
    [self.predictionStack addArrangedSubview:self.choices];
    self.choiceFeedback = [self labelWithSize:18 weight:UIFontWeightMedium];
    self.choiceFeedback.accessibilityIdentifier = @"grouping.feedback";
    [self.predictionStack addArrangedSubview:self.choiceFeedback];
    [content addArrangedSubview:self.predictionStack];

    [content addArrangedSubview:self.board];
    ChildButton *read = [self button:@"聽聽這一步" color:ChildUI.skyBlue action:@selector(readStep)];
    read.accessibilityIdentifier = @"grouping.read";
    [content addArrangedSubview:read];
    ChildButton *restart = [self button:@"從頭再看" color:ChildUI.eggYolk action:@selector(restart)];
    restart.accessibilityIdentifier = @"grouping.restart";
    [content addArrangedSubview:restart];
    if (self.alternativeSequence) {
        self.meaningButton = [self button:@"用另一種分法看" color:ChildUI.lavender action:@selector(changeMeaning)];
        self.meaningButton.accessibilityIdentifier = @"grouping.changeMeaning";
        [content addArrangedSubview:self.meaningButton];
    }
    if (self.wordProblem) {
        UILabel *story = [self labelWithSize:18 weight:UIFontWeightMedium];
        story.text = [@"回頭看看題目：\n" stringByAppendingString:self.wordProblem.storyText];
        [content addArrangedSubview:story];
    }
    [self showCurrentStepAnimated:NO];
}

- (GroupingTeachingStep *)currentStep {
    return self.sequence.isSupported && self.stepIndex < self.sequence.steps.count ? self.sequence.steps[self.stepIndex] : nil;
}
- (void)showCurrentStepAnimated:(BOOL)animated {
    [SpeechManager.sharedInstance stop];
    GroupingTeachingStep *step = self.currentStep;
    if (!step) {
        self.heading.text = @"先回到題目看看";
        self.narration.text = @"這一題先用故事裡的關係一起想，不把不同的問題畫成一樣的圖。";
        [self.predictionStack removeFromSuperview];
        self.previousButton.enabled = NO;
        [self.nextButton setTitle:@"回到題目" forState:UIControlStateNormal];
        return;
    }
    self.progressLabel.text = [NSString stringWithFormat:@"第 %lu 小步 · 共 %lu 步 · 不用急",
        (unsigned long)self.stepIndex + 1, (unsigned long)self.sequence.steps.count];
    self.heading.text = step.title;
    if (self.meaningButton) {
        NSInteger divisor = self.sequence.problem.number2;
        NSString *otherMeaning = self.alternativeSequence.context.meaning == GroupingStoryMeaningShareEqually
            ? [NSString stringWithFormat:@"換成平均分給 %ld 組", (long)divisor]
            : [NSString stringWithFormat:@"換成每組放 %ld 個", (long)divisor];
        [self.meaningButton setTitle:otherMeaning forState:UIControlStateNormal];
    }
    self.narration.text = step.explanation;
    [self.board configureWithSequence:self.sequence stepIndex:self.stepIndex animated:NO];
    self.previousButton.enabled = self.stepIndex > 0;
    BOOL prediction = step.kind == GroupingTeachingStepKindPredict;
    // Detach the nested stack rather than imposing a required zero height over
    // its required internal spacers, especially when choices stack vertically.
    if (prediction && !self.predictionStack.superview) {
        [self.content insertArrangedSubview:self.predictionStack
            atIndex:[self.content.arrangedSubviews indexOfObject:self.board]];
    } else if (!prediction) {
        [self.predictionStack removeFromSuperview];
    }
    self.replayButton.enabled = step.kind != GroupingTeachingStepKindObserve;
    [self.nextButton setTitle:step.kind == GroupingTeachingStepKindCompletion ? @"回到題目"
        : prediction && ![self.answeredSteps containsIndex:self.stepIndex] ? @"先看示範" : @"下一小步"
        forState:UIControlStateNormal];
    if (prediction) [self configurePrediction];
    [self.scroll setContentOffset:CGPointZero animated:NO];
    // Fit the selected snapshot before animation. A later size change rightly
    // cancels board motion, so animation must start only after final layout.
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self updateBoardHeight];
    [self.view layoutIfNeeded];
    BOOL framedTransformation = NO;
    if (animated) {
        framedTransformation = [self frameCurrentTransformation];
        [self.board showStepAtIndex:self.stepIndex animated:YES];
    }
    // Do not move VoiceOver back to an offscreen heading after deliberately
    // framing a transfer. The board describes only this selected snapshot.
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification,
        framedTransformation ? self.board : self.heading);
}
- (BOOL)frameCurrentTransformation {
    CGRect focus = self.board.currentTransformationRect;
    if (CGRectIsNull(focus) || CGRectIsEmpty(focus)) return NO;
    CGRect inContent = [self.board convertRect:focus toView:self.scroll];
    CGFloat viewportHeight = self.scroll.bounds.size.height;
    if (viewportHeight <= 0) return NO;
    CGFloat proposed = CGRectGetMinY(inContent) - MAX(8, (viewportHeight - inContent.size.height) / 2);
    CGFloat maximum = MAX(0, self.scroll.contentSize.height - viewportHeight);
    // First playback prioritizes the actual quantity transfer. Replay intentionally
    // does not call this: the learner can inspect any part without being moved.
    [self.scroll setContentOffset:CGPointMake(0, MIN(maximum, MAX(0, proposed))) animated:NO];
    return YES;
}
- (NSArray<NSNumber *> *)choiceValuesForStep:(GroupingTeachingStep *)step {
    if (step.predictionKind == GroupingTeachingPredictionKindCanContinue) return @[@YES, @NO];
    NSInteger answer = step.expectedAnswer.integerValue;
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithObject:@(answer)];
    for (NSNumber *candidate in @[@(MAX(0, answer - 1)), @(answer + 1), @(answer + 2)]) {
        if (![values containsObject:candidate]) [values addObject:candidate];
        if (values.count == 3) break;
    }
    [values exchangeObjectAtIndex:0 withObjectAtIndex:self.stepIndex % values.count];
    return values;
}
- (NSString *)choiceTitle:(NSInteger)value {
    return self.currentStep.predictionKind == GroupingTeachingPredictionKindCanContinue
        ? (value ? @"還可以" : @"不夠了") : [NSString stringWithFormat:@"%ld", (long)value];
}
- (void)configurePrediction {
    GroupingTeachingStep *step = self.currentStep;
    self.prompt.text = step.prompt;
    for (UIView *view in self.choices.arrangedSubviews.copy) [view removeFromSuperview];
    for (NSNumber *value in [self choiceValuesForStep:step]) {
        ChildButton *button = [self button:[self choiceTitle:value.integerValue] color:ChildUI.eggYolk action:@selector(choosePrediction:)];
        button.tag = value.integerValue;
        button.accessibilityIdentifier = [NSString stringWithFormat:@"grouping.choice.%@", value];
        button.accessibilityLabel = [NSString stringWithFormat:@"我想是 %@", [self choiceTitle:value.integerValue]];
        [self.choices addArrangedSubview:button];
    }
    [self updatePredictionFeedback];
}
- (void)updatePredictionFeedback {
    GroupingTeachingStep *step = self.currentStep;
    BOOL answered = [self.answeredSteps containsIndex:self.stepIndex];
    NSSet<NSNumber *> *attempts = self.attemptedValues[@(self.stepIndex)];
    for (ChildButton *button in self.choices.arrangedSubviews) {
        BOOL correctChosen = answered && button.tag == step.expectedAnswer.integerValue;
        BOOL tried = [attempts containsObject:@(button.tag)];
        button.enabled = !answered && !tried;
        button.layer.borderWidth = correctChosen || tried ? 2 : 0;
        button.layer.borderColor = ChildUI.brownText.CGColor;
        button.backgroundColor = correctChosen ? ChildUI.mintGreen : tried ? ChildUI.wrongPink : ChildUI.eggYolk;
        button.accessibilityValue = correctChosen ? @"對，想通這一步了" : tried ? @"再想一想" : @"還沒選擇";
        [button setTitle:[NSString stringWithFormat:@"%@%@", correctChosen ? @"✓ " : tried ? @"↻ " : @"", [self choiceTitle:button.tag]]
            forState:UIControlStateNormal];
    }
    self.choiceFeedback.text = answered ? @"對！準備好了，就看看下一小步。"
        : attempts.count ? @"再數數看圖裡的數量，也可以先看示範。這裡不計分。" : @"可以先想想，也可以直接看示範。";
}
- (void)choosePrediction:(UIButton *)button {
    GroupingTeachingStep *step = self.currentStep;
    if (step.kind != GroupingTeachingStepKindPredict || !button.enabled
        || ![self.choices.arrangedSubviews containsObject:button] || [self.answeredSteps containsIndex:self.stepIndex]) return;
    NSNumber *key = @(self.stepIndex);
    NSMutableSet<NSNumber *> *attempts = self.attemptedValues[key];
    if (!attempts) self.attemptedValues[key] = attempts = [NSMutableSet set];
    [attempts addObject:@(button.tag)];
    if (button.tag == step.expectedAnswer.integerValue) {
        [self.answeredSteps addIndex:self.stepIndex];
        [SoundManager.sharedInstance play:SoundEffectCorrect];
        [self.nextButton setTitle:@"下一小步" forState:UIControlStateNormal];
    }
    [self updatePredictionFeedback];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.choiceFeedback.text);
}
- (void)next {
    if (!self.sequence.isSupported || self.stepIndex + 1 >= self.sequence.steps.count) { [self close]; return; }
    self.stepIndex++;
    [self showCurrentStepAnimated:YES];
}
- (void)previous {
    if (self.stepIndex == 0) return;
    self.stepIndex--;
    [self showCurrentStepAnimated:NO];
}
- (void)replay {
    [SpeechManager.sharedInstance stop];
    // Keep the part the child chose to inspect in view. Jumping to the heading
    // here hides the exchange on compact-height and large-text screens.
    [self.board showStepAtIndex:self.stepIndex animated:YES];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.board);
}
- (void)restart {
    [self.answeredSteps removeAllIndexes];
    [self.attemptedValues removeAllObjects];
    self.stepIndex = 0;
    [self showCurrentStepAnimated:NO];
}
- (void)readStep {
    GroupingTeachingStep *step = self.currentStep;
    if (step) [SpeechManager.sharedInstance speak:step.spokenExplanation];
}
- (void)changeMeaning {
    if (!self.alternativeSequence) return;
    [self pausePlayback];
    GroupingTeachingSequence *previous = self.sequence;
    self.sequence = self.alternativeSequence;
    self.alternativeSequence = previous;
    [self restart];
}
- (void)close {
    [self pausePlayback];
    if (self.returnToQuestion) self.returnToQuestion();
    else [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)pausePlayback {
    [self.board cancelAnimations];
    [SpeechManager.sharedInstance stop];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateBoardHeight];
    BOOL largeText = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    self.choices.axis = largeText ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
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
