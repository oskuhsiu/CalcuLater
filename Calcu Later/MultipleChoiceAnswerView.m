#import "MultipleChoiceAnswerView.h"
#import "DistractorGenerator.h"
#import "ArithmeticProblem.h"
#import "ChildUIKit.h"
#import "SoundManager.h"

static const NSTimeInterval MCQWrongFeedbackDuration = 0.35;

@interface MultipleChoiceAnswerView ()
@property (nonatomic, copy) NSArray<UIButton *> *choiceButtons;
@property (nonatomic, copy) NSArray<UILabel *> *feedbackLabels;
@property (nonatomic, copy) NSArray<NSString *> *choiceTitles;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *currentChoices;
@property (nonatomic, strong) NSMutableIndexSet *attemptedWrongIndexes;
@property (nonatomic, assign) NSInteger correctChoiceIndex;
@property (nonatomic, assign) BOOL configured;
@property (nonatomic, assign) BOOL choicesLocked;
@property (nonatomic, assign) BOOL feedbackInProgress;
@property (nonatomic, assign) BOOL correctAnswerChosen;
@property (nonatomic, assign) BOOL answerRevealed;
@property (nonatomic, assign) NSUInteger feedbackGeneration;
@property (nonatomic, copy, nullable) dispatch_block_t feedbackRelease;
@end

@implementation MultipleChoiceAnswerView

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
    self.isAccessibilityElement = NO;
    self.shouldGroupAccessibilityChildren = YES;
    self.correctChoiceIndex = NSNotFound;
    self.choiceTitles = @[];
    self.attemptedWrongIndexes = [NSMutableIndexSet indexSet];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.layer.cornerRadius = 24.0;
        button.layer.borderColor = ChildUI.brownText.CGColor;
        [button setTitleColor:ChildUI.brownText forState:UIControlStateNormal];
        [button setTitleColor:ChildUI.brownText forState:UIControlStateHighlighted];
        [button setTitleColor:ChildUI.brownText forState:UIControlStateDisabled];
        button.titleLabel.font = [ChildUI scaledRoundedMonoFontOfSize:42.0 weight:UIFontWeightBold
                                                         textStyle:UIFontTextStyleLargeTitle maximumPointSize:52.0];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.55;
        button.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 26, 12);
        button.tag = i;
        button.accessibilityIdentifier = [NSString stringWithFormat:@"answer.%ld", (long)i];
        button.accessibilityLanguage = @"zh-TW";
        [ChildUI applySoftShadowOnLayer:button.layer];
        [button addTarget:self action:@selector(choiceTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(touchDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(touchCancelled:)
          forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];

        UILabel *feedback = [[UILabel alloc] init];
        feedback.font = [ChildUI scaledRoundedFontOfSize:14.0 weight:UIFontWeightSemibold
                                              textStyle:UIFontTextStyleCaption1 maximumPointSize:18.0];
        feedback.adjustsFontForContentSizeCategory = YES;
        feedback.adjustsFontSizeToFitWidth = YES;
        feedback.minimumScaleFactor = 0.8;
        feedback.textColor = ChildUI.brownText;
        feedback.textAlignment = NSTextAlignmentCenter;
        feedback.isAccessibilityElement = NO;
        feedback.userInteractionEnabled = NO;
        [button addSubview:feedback];
        [self addSubview:button];
        [buttons addObject:button];
        [labels addObject:feedback];
    }
    self.choiceButtons = buttons;
    self.feedbackLabels = labels;
    [self updateChoiceAppearance];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(motionPreferenceChanged:)
                                                 name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
}

- (void)dealloc {
    if (_feedbackRelease) dispatch_block_cancel(_feedbackRelease);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isAcceptingAnswers {
    return self.configured && !self.choicesLocked && !self.feedbackInProgress;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat gap = MIN(16.0, MAX(0.0, CGRectGetWidth(self.bounds) * 0.04));
    CGFloat width = MAX(0.0, (CGRectGetWidth(self.bounds) - gap) * 0.5);
    CGFloat height = MAX(0.0, (CGRectGetHeight(self.bounds) - gap) * 0.5);
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = self.choiceButtons[i];
        // Bounds/center remain well-defined if the press animation is in flight.
        button.bounds = CGRectMake(0, 0, width, height);
        button.center = CGPointMake((i % 2) * (width + gap) + width * 0.5,
                                    (i / 2) * (height + gap) + height * 0.5);
        self.feedbackLabels[i].frame = CGRectMake(8, MAX(0.0, height - 27), MAX(0.0, width - 16), 22);
        button.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:button.bounds cornerRadius:24.0].CGPath;
    }
}

- (void)configureWithProblem:(ArithmeticProblem *)problem {
    NSArray<NSNumber *> *choices = problem ? [DistractorGenerator choicesForProblem:problem] : @[];
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSInteger correctIndex = NSNotFound;
    for (NSUInteger i = 0; i < MIN(choices.count, 4); i++) {
        [titles addObject:choices[i].stringValue];
        if (choices[i].integerValue == problem.answer) correctIndex = (NSInteger)i;
    }
    [self configureWithChoiceTitles:titles correctIndex:correctIndex];
    self.currentChoices = [choices subarrayWithRange:NSMakeRange(0, MIN(choices.count, 4))];
}

- (void)configureWithChoiceTitles:(NSArray<NSString *> *)titles correctIndex:(NSInteger)correctIndex {
    self.currentChoices = nil; // String-mode delegates receive the selected index, as before.
    self.choiceTitles = [titles subarrayWithRange:NSMakeRange(0, MIN(titles.count, 4))];
    BOOL validIndex = correctIndex >= 0 && correctIndex < (NSInteger)self.choiceTitles.count;
    self.configured = validIndex && self.choiceTitles[correctIndex].length > 0;
    self.correctChoiceIndex = self.configured ? correctIndex : NSNotFound;
    [self reset];
}

- (void)reset {
    [self invalidateFeedbackRelease];
    self.choicesLocked = NO;
    self.correctAnswerChosen = NO;
    self.answerRevealed = NO;
    [self.attemptedWrongIndexes removeAllIndexes];
    [self restoreButtonTransforms];
    [self updateChoiceAppearance];
}

- (void)disableAllChoices {
    [self invalidateFeedbackRelease];
    self.choicesLocked = YES;
    if (!self.correctAnswerChosen) [self restoreButtonTransforms];
    [self updateChoiceAppearance];
}

- (void)revealCorrectChoice {
    if (!self.configured) return;
    [self disableAllChoices];
    self.answerRevealed = !self.correctAnswerChosen;
    [self updateChoiceAppearance];
}

- (void)updateChoiceAppearance {
    NSArray<UIColor *> *colors = @[ChildUI.pinkAccent, ChildUI.skyBlue, ChildUI.mintGreen, ChildUI.eggYolk];
    for (NSUInteger i = 0; i < self.choiceButtons.count; i++) {
        UIButton *button = self.choiceButtons[i];
        NSString *title = i < self.choiceTitles.count ? self.choiceTitles[i] : @"";
        BOOL populated = title.length > 0;
        BOOL wrong = [self.attemptedWrongIndexes containsIndex:i];
        BOOL correct = (NSInteger)i == self.correctChoiceIndex && (self.correctAnswerChosen || self.answerRevealed);
        button.hidden = !populated;
        button.alpha = 1.0; // Disabled does not mean unreadable.
        button.enabled = populated && self.isAcceptingAnswers && !wrong;
        button.selected = correct;
        [button setTitle:title forState:UIControlStateNormal];
        button.backgroundColor = correct ? ChildUI.correctGreen : (wrong ? ChildUI.wrongPink : colors[i]);
        button.layer.borderWidth = (correct || wrong) ? 2.5 : 0.0;
        NSString *feedback = @"";
        NSString *value = self.choicesLocked ? @"未選擇" : @"尚未作答";
        if (wrong) {
            feedback = @"↻ 再想一想";
            value = @"已試過，還不是答案";
        } else if (correct) {
            feedback = self.answerRevealed ? @"✓ 正確答案" : @"✓ 答對了！";
            value = self.answerRevealed ? @"正確答案" : @"答對了";
        }
        self.feedbackLabels[i].text = feedback;
        button.isAccessibilityElement = populated;
        button.accessibilityLabel = [NSString stringWithFormat:@"選項 %lu，%@", (unsigned long)i + 1,
                                     [self spokenChoiceTitle:title]];
        button.accessibilityValue = value;
        button.accessibilityHint = button.enabled ? @"點兩下選擇這個答案" : nil;
        button.accessibilityTraits = UIAccessibilityTraitButton
                                   | (button.enabled ? 0 : UIAccessibilityTraitNotEnabled)
                                   | (correct ? UIAccessibilityTraitSelected : 0);
    }
}

- (NSString *)spokenChoiceTitle:(NSString *)title {
    NSArray<NSString *> *parts = [title componentsSeparatedByString:@"/"];
    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    if (parts.count == 2 && parts[0].length > 0 && parts[1].length > 0
        && [parts[0] rangeOfCharacterFromSet:nonDigits].location == NSNotFound
        && [parts[1] rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
        return [NSString stringWithFormat:@"%@ 分之 %@", parts[1], parts[0]];
    }
    return title;
}

#pragma mark - Accepted input and feedback

- (void)choiceTapped:(UIButton *)button {
    NSInteger index = button.tag;
    // Gate BEFORE mutating cards or invoking the delegate. sendActionsForControlEvents:
    // can bypass UIKit hit testing, so enabled alone is not a sufficient guard.
    if (!self.isAcceptingAnswers || !button.enabled || self.hidden || !self.userInteractionEnabled
        || index < 0 || index >= (NSInteger)self.choiceButtons.count || self.choiceButtons[index] != button) return;

    [self restoreButtonTransforms];
    BOOL correct = index == self.correctChoiceIndex;
    NSInteger value = self.currentChoices ? self.currentChoices[index].integerValue : index;
    if (correct) {
        self.correctAnswerChosen = YES;
        self.choicesLocked = YES; // A reentrant/double tap cannot award a second answer.
    } else {
        [self.attemptedWrongIndexes addIndex:(NSUInteger)index];
        self.feedbackInProgress = YES;
        [self scheduleFeedbackRelease];
    }
    [self updateChoiceAppearance];
    [self animateFeedbackForButton:button correct:correct];
    [self.delegate mcqView:self didChoose:value result:correct ? MCQResultCorrect : MCQResultWrong];
    // No work after the delegate: it is allowed to configure a new question synchronously.
}

- (void)scheduleFeedbackRelease {
    NSUInteger generation = self.feedbackGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t release = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.feedbackGeneration != generation || self.choicesLocked) return;
        self.feedbackRelease = nil;
        self.feedbackInProgress = NO;
        [self updateChoiceAppearance];
    });
    self.feedbackRelease = release;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MCQWrongFeedbackDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), release);
}

- (void)invalidateFeedbackRelease {
    self.feedbackGeneration++;
    if (self.feedbackRelease) dispatch_block_cancel(self.feedbackRelease);
    self.feedbackRelease = nil;
    self.feedbackInProgress = NO;
}

- (void)animateFeedbackForButton:(UIButton *)button correct:(BOOL)correct {
    if (!ChildUI.motionEnabled || !self.window) return;
    // Core Animation affects presentation only: no stale completion can resize a reused card.
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:correct ? @"transform.scale" : @"transform.translation.x"];
    animation.values = correct ? @[@1.0, @1.08, @0.99, @1.0] : @[@0, @-7, @7, @-4, @4, @0];
    animation.duration = correct ? 0.42 : MCQWrongFeedbackDuration;
    [button.layer addAnimation:animation forKey:@"answerFeedback"];
}

- (void)touchDown:(UIButton *)button {
    if (!self.isAcceptingAnswers || !button.enabled) return;
    [[SoundManager sharedInstance] play:SoundEffectTap];
    if (!ChildUI.motionEnabled) return;
    [UIView animateWithDuration:0.10 delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.96, 0.96);
    } completion:nil];
}

- (void)touchCancelled:(UIButton *)button {
    [button.layer removeAllAnimations];
    button.transform = CGAffineTransformIdentity;
}

- (void)restoreButtonTransforms {
    for (UIButton *button in self.choiceButtons) {
        [button.layer removeAllAnimations];
        button.transform = CGAffineTransformIdentity;
    }
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    if (hidden) [self stopTransientFeedback];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self stopTransientFeedback];
}

- (void)stopTransientFeedback {
    [self invalidateFeedbackRelease];
    [self restoreButtonTransforms];
    [self updateChoiceAppearance];
}

- (void)motionPreferenceChanged:(NSNotification *)notification {
    if (!ChildUI.motionEnabled) [self restoreButtonTransforms];
}

@end
