#import "ExplanationViewController.h"
#import "ArithmeticProblem.h"
#import "WordProblem.h"
#import "Lesson.h"
#import "ChildUIKit.h"
#import "AnimatedHintView.h"
#import "MakeBreakTenHintView.h"
#import "MathConceptView.h"
#import "SpeechManager.h"
#import "VerticalTeachingViewController.h"

@interface ExplanationViewController ()
@property (nonatomic, strong) ArithmeticProblem *problem;
@property (nonatomic, strong) WordProblem *wordProblem;
@property (nonatomic, strong) Lesson *lesson;
@property (nonatomic, strong) UILabel *heading;
@property (nonatomic, strong) UILabel *explanation;
@property (nonatomic, strong) UIView *visual;
@property (nonatomic, strong) NSLayoutConstraint *visualHeight;
@property (nonatomic, strong) ChildButton *replayButton;
@end

@implementation ExplanationViewController
- (instancetype)initWithArithmeticProblem:(ArithmeticProblem *)problem
                              wordProblem:(WordProblem *)wordProblem lesson:(Lesson *)lesson {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _problem = problem;
        _wordProblem = wordProblem;
        _lesson = lesson;
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[ChildWrappingLabel alloc] init];
    label.text = text;
    label.textColor = ChildUI.brownText;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:size weight:weight] maximumPointSize:size * 1.6];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ChildUI.creamBackground;
    self.view.accessibilityIdentifier = @"explanation.screen";
    self.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.largeDetent];
    self.sheetPresentationController.prefersGrabberVisible = YES;
    self.sheetPresentationController.preferredCornerRadius = 28;

    ChildButton *back = [ChildButton buttonWithTitle:@"回到題目" backgroundColor:ChildUI.mintGreen];
    back.accessibilityIdentifier = @"explanation.close";
    back.translatesAutoresizingMaskIntoConstraints = NO;
    [back addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:back];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    NSLayoutConstraint *preferredWidth = [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32];
    preferredWidth.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [back.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [back.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [back.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [back.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:back.topAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.centerXAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerXAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:680],
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],
        preferredWidth,
        [scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];

    self.heading = [self label:@"一起想一想" size:30 weight:UIFontWeightBold];
    self.heading.accessibilityTraits |= UIAccessibilityTraitHeader;
    [stack addArrangedSubview:self.heading];
    [stack addArrangedSubview:[self label:@"慢慢看，準備好了再回到題目。" size:18 weight:UIFontWeightMedium]];
    if (self.wordProblem) {
        [stack addArrangedSubview:[self label:self.wordProblem.storyText size:21 weight:UIFontWeightMedium]];
    }

    if ([VerticalTeachingViewController supportsProblem:self.problem wordProblem:self.wordProblem]) {
        ChildButton *vertical = [ChildButton buttonWithTitle:@"一步一步看直式" backgroundColor:ChildUI.skyBlue];
        vertical.accessibilityIdentifier = @"explanation.vertical";
        [vertical.heightAnchor constraintGreaterThanOrEqualToConstant:60].active = YES;
        [vertical addTarget:self action:@selector(showVerticalTeaching) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:vertical];
    }
    self.visual = [self makeVisual];
    if (self.visual) {
        [stack addArrangedSubview:self.visual];
        self.visualHeight = [self.visual.heightAnchor constraintEqualToConstant:360];
        self.visualHeight.active = YES;
    }
    NSString *text = self.wordProblem ? self.wordProblem.workedExplanationText : [self arithmeticExplanation];
    self.explanation = [self label:text size:23 weight:UIFontWeightSemibold];
    self.explanation.accessibilityIdentifier = @"explanation.steps";
    [stack addArrangedSubview:self.explanation];

    self.replayButton = [ChildButton buttonWithTitle:@"再看一次" backgroundColor:ChildUI.lavender];
    self.replayButton.accessibilityIdentifier = @"explanation.replay";
    self.replayButton.hidden = !self.visual;
    NSLayoutConstraint *replayHeight = [self.replayButton.heightAnchor constraintGreaterThanOrEqualToConstant:60];
    replayHeight.priority = 999;
    replayHeight.active = YES;
    [self.replayButton addTarget:self action:@selector(replay) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:self.replayButton];
    ChildButton *speak = [ChildButton buttonWithTitle:@"朗讀做法" backgroundColor:ChildUI.skyBlue];
    [speak.heightAnchor constraintGreaterThanOrEqualToConstant:60].active = YES;
    [speak addTarget:self action:@selector(speak) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:speak];
}

- (UIView *)makeVisual {
    WordProblem *word = self.wordProblem;
    if (word && (word.operator2 || word.missingAddend || word.missingSubtrahend || word.missingMinuend)) return nil;
    // A numerical bridge does not preserve the story's grouping meaning.
    // Sharing among four children is NOT the same picture as four per bag.
    // Keep the exact worked text until templates explicitly supply that meaning.
    if (word && ([word.operatorSymbol isEqualToString:@"×"] || [word.operatorSymbol isEqualToString:@"÷"])) return nil;
    if (self.lesson && (self.lesson.kind == LessonKindMakeTen || self.lesson.kind == LessonKindBreakTen)) {
        return [[MakeBreakTenHintView alloc] initWithFrame:CGRectZero
            mode:self.lesson.kind == LessonKindMakeTen ? MakeBreakTenModeMakeTen : MakeBreakTenModeBreakTen];
    }
    MathConceptView *concept = [[MathConceptView alloc] initWithFrame:CGRectZero];
    BOOL configured = word.isFractionAnswer
        ? [concept configureWithNumerator:word.answerNumerator denominator:word.answerDenominator]
        : [concept configureWithNumber1:self.problem.number1 number2:self.problem.number2
                              operator:self.problem.operatorSymbol answer:self.problem.answer remainder:word.remainder];
    if (configured) return concept;
    if ([self.problem.operatorSymbol isEqualToString:@"+"] || [self.problem.operatorSymbol isEqualToString:@"-"]) {
        return [[AnimatedHintView alloc] initWithFrame:CGRectZero];
    }
    return nil;
}

- (NSString *)arithmeticExplanation {
    ArithmeticProblem *p = self.problem;
    NSString *op = [p.operatorSymbol isEqualToString:@"-"] ? @"−" : p.operatorSymbol;
    if ([op isEqualToString:@"÷"] && p.number2 > 0) {
        NSInteger remainder = p.number1 % p.number2;
        if (remainder) return [NSString stringWithFormat:@"%ld ÷ %ld = %ld 餘 %ld\n檢查看看：%ld × %ld + %ld = %ld",
            (long)p.number1, (long)p.number2, (long)p.answer, (long)remainder,
            (long)p.answer, (long)p.number2, (long)remainder, (long)p.number1];
        return [NSString stringWithFormat:@"%ld ÷ %ld = %ld\n檢查看看：%ld × %ld = %ld",
            (long)p.number1, (long)p.number2, (long)p.answer, (long)p.answer, (long)p.number2, (long)p.number1];
    }
    if ([op isEqualToString:@"×"]) return [NSString stringWithFormat:@"每組 %ld 個，有 %ld 組。\n%ld × %ld = %ld",
        (long)p.number1, (long)p.number2, (long)p.number1, (long)p.number2, (long)p.answer];
    return [NSString stringWithFormat:@"%ld %@ %ld = %ld\n%@", (long)p.number1, op, (long)p.number2, (long)p.answer,
        [op isEqualToString:@"+"] ? @"把兩邊合起來，看看一共有多少。" : @"從原來的數量拿走一些，看看還剩多少。"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self replay];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.heading);
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if ([self.visual isKindOfClass:MathConceptView.class] && self.visual.bounds.size.width > 0) {
        CGFloat height = MAX(340, [self.visual sizeThatFits:CGSizeMake(self.visual.bounds.size.width, CGFLOAT_MAX)].height);
        if (fabs(self.visualHeight.constant - height) > 0.5) self.visualHeight.constant = height;
    }
}
- (void)replay {
    [self.view layoutIfNeeded];
    if ([self.visual isKindOfClass:AnimatedHintView.class]) {
        [(AnimatedHintView *)self.visual configureWithProblem:self.problem];
    } else if ([self.visual isKindOfClass:MakeBreakTenHintView.class]) {
        void (^configure)(void) = ^{ [(MakeBreakTenHintView *)self.visual configureWithProblem:self.problem]; };
        if (UIAccessibilityIsReduceMotionEnabled()) [UIView performWithoutAnimation:configure];
        else configure();
    } else {
        [self.visual setNeedsDisplay];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.visual.accessibilityLabel);
    }
}
- (void)showVerticalTeaching {
    if (self.presentedViewController) return;
    [SpeechManager.sharedInstance stop];
    VerticalTeachingViewController *teaching = [[VerticalTeachingViewController alloc]
        initWithProblem:self.problem wordProblem:self.wordProblem];
    __weak typeof(self) weakSelf = self;
    teaching.returnToQuestion = ^{
        // The button promises the question, not another layer of help.
        [weakSelf.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    };
    [self presentViewController:teaching animated:YES completion:nil];
}
- (void)speak { [SpeechManager.sharedInstance speak:self.explanation.text]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [SpeechManager.sharedInstance stop];
    if ([self.visual isKindOfClass:AnimatedHintView.class]) [(AnimatedHintView *)self.visual cancelAnimations];
}
@end
