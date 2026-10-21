#import "PracticeViewController.h"
#import "ArithmeticProblem.h"
#import "WordProblem.h"
#import "WordProblemGenerator.h"
#import "ProblemGenerator.h"
#import "Lesson.h"
#import "LessonIntroView.h"
#import "LessonProgressStore.h"
#import "PracticeSession.h"
#import "PracticeProgressStore.h"
#import "MultipleChoiceAnswerView.h"
#import "DistractorGenerator.h"
#import "DrawingCanvasView.h"
#import "ExplanationViewController.h"
#import "VerticalTeachingViewController.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"
#import "MascotView.h"
#import "SettingsManager.h"
#import "SoundManager.h"
#import "SpeechManager.h"

/// One finger draws. The explicit two-finger scroll gesture remains available
/// even when the scratchpad fills the viewport.
@interface PracticeScrollView : UIScrollView
@property (nonatomic, weak) DrawingCanvasView *drawingCanvas;
@end
@implementation PracticeScrollView
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGestureRecognizer && self.drawingCanvas && !self.drawingCanvas.hidden) {
        CGPoint point = [gestureRecognizer locationInView:self.drawingCanvas];
        if (CGRectContainsPoint(self.drawingCanvas.bounds, point) && gestureRecognizer.numberOfTouches < 2) return NO;
    }
    BOOL accepted = [super gestureRecognizerShouldBegin:gestureRecognizer];
    if (accepted && gestureRecognizer == self.panGestureRecognizer && gestureRecognizer.numberOfTouches >= 2) {
        [self.drawingCanvas cancelActiveStroke];
    }
    return accepted;
}
@end

@interface PracticeViewController () <MultipleChoiceAnswerViewDelegate, LessonIntroViewDelegate>
@property (nonatomic) PracticeKind kind;
@property (nonatomic, strong) Lesson *lesson;
@property (nonatomic) NSInteger grade;
@property (nonatomic, copy) NSString *prefix;
@property (nonatomic, strong) PracticeSession *session;
@property (nonatomic) BOOL reviewRun;
@property (nonatomic) BOOL writingMode;
@property (nonatomic) BOOL equationRevealed;
@property (nonatomic) BOOL showingSummary;
@property (nonatomic) NSInteger correctStreak;
@property (nonatomic, strong) UIView *toolbar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) ChildButton *helpButton;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *questionStack;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *problemLabel;
@property (nonatomic, strong) UILabel *storyLabel;
@property (nonatomic, strong) UILabel *equationLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *progress;
@property (nonatomic, strong) UIStackView *storyActions;
@property (nonatomic, strong) ChildButton *equationButton;
@property (nonatomic, strong) UIView *mascotHost;
@property (nonatomic, strong) MascotView *mascot;
@property (nonatomic, strong) DrawingCanvasView *canvas;
@property (nonatomic, strong) UIStackView *writingTools;
@property (nonatomic, strong) UILabel *scratchpadNote;
@property (nonatomic, strong) UIView *tray;
@property (nonatomic, strong) MultipleChoiceAnswerView *mcq;
@property (nonatomic, strong) UIStackView *feedback;
@property (nonatomic, strong) UIScrollView *feedbackScroll;
@property (nonatomic, strong) UILabel *feedbackTitle;
@property (nonatomic, strong) UILabel *feedbackDetail;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) ChildButton *reviewButton;
@property (nonatomic, strong) ChildButton *checkWritingButton;
@property (nonatomic, strong) LessonIntroView *intro;
@property (nonatomic, strong) UIScrollView *summaryScroll;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *verticalConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *wideConstraints;
@property (nonatomic, strong) NSLayoutConstraint *trayHeight;
@property (nonatomic) BOOL wideLayout;
@end

@implementation PracticeViewController
- (instancetype)init { return [self initWithKind:PracticeKindDrill lesson:nil grade:1]; }
- (instancetype)initWithKind:(PracticeKind)kind lesson:(Lesson *)lesson grade:(NSInteger)grade {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _kind = kind;
        _lesson = lesson;
        _grade = MAX(1, MIN(3, grade));
        _prefix = kind == PracticeKindLesson ? @"lesson" : kind == PracticeKindStory ? @"story" : @"practice";
    }
    return self;
}

- (UILabel *)labelWithSize:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[ChildWrappingLabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:size weight:weight] maximumPointSize:size * 1.5];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = ChildUI.brownText;
    label.numberOfLines = 0;
    return label;
}
- (ChildButton *)button:(NSString *)title color:(UIColor *)color action:(SEL)action {
    ChildButton *button = [ChildButton buttonWithTitle:title backgroundColor:color];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    NSLayoutConstraint *height = [button.heightAnchor constraintGreaterThanOrEqualToConstant:60];
    height.priority = 999; // A hidden arranged subview must be allowed to collapse.
    height.active = YES;
    return button;
}
- (UIStackView *)verticalStack {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    return stack;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.writingMode = self.kind != PracticeKindLesson && SettingsManager.sharedInstance.answerMode == AnswerModeWriting;
    [DecorativeBackgroundView installInViewController:self
        theme:self.kind == PracticeKindDrill ? BackgroundThemeDrill : BackgroundThemeLessons];
    [self setupInterface];
    [self beginNewRun];
    if (self.lesson && self.lesson.kind != LessonKindMultiplication) [self showIntro];
}

- (void)setupInterface {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.toolbar = [[UIView alloc] init];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.toolbar];
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"chevron.backward"] forState:UIControlStateNormal];
    [close setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:23 weight:UIImageSymbolWeightBold] forImageInState:UIControlStateNormal];
    close.tintColor = ChildUI.brownText;
    close.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.8];
    close.layer.cornerRadius = 20;
    close.accessibilityLabel = @"先休息，離開練習";
    close.accessibilityIdentifier = [self.prefix stringByAppendingString:@".close"];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.toolbar addSubview:close];
    self.titleLabel = [self labelWithSize:23 weight:UIFontWeightBold];
    self.titleLabel.text = self.kind == PracticeKindLesson ? @"學一學" : self.kind == PracticeKindStory ? @"想一想" : @"練一練";
    self.titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.titleLabel];
    self.helpButton = [self button:@"看怎麼算" color:ChildUI.lavender action:@selector(helpTapped)];
    self.helpButton.titleLabel.font = [ChildUI roundedFontOfSize:18 weight:UIFontWeightSemibold];
    self.helpButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar addSubview:self.helpButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.toolbar.topAnchor constraintEqualToAnchor:safe.topAnchor constant:6],
        [self.toolbar.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.toolbar.heightAnchor constraintEqualToConstant:60],
        [close.leadingAnchor constraintEqualToAnchor:self.toolbar.leadingAnchor],
        [close.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:56], [close.heightAnchor constraintEqualToConstant:60],
        [self.helpButton.trailingAnchor constraintEqualToAnchor:self.toolbar.trailingAnchor],
        [self.helpButton.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
        [self.helpButton.widthAnchor constraintEqualToConstant:116],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:close.trailingAnchor constant:12],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.helpButton.leadingAnchor constant:-8],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.toolbar.centerYAnchor],
    ]];

    self.scroll = [[PracticeScrollView alloc] init];
    self.scroll.delaysContentTouches = NO;
    if (self.writingMode) self.scroll.panGestureRecognizer.minimumNumberOfTouches = 2;
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    self.scroll.accessibilityIdentifier = @"practice.content";
    [self.view addSubview:self.scroll];
    self.questionStack = [self verticalStack];
    self.questionStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.questionStack];
    NSLayoutConstraint *columnWidth = [self.questionStack.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-8];
    columnWidth.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor],
        [self.questionStack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:8],
        [self.questionStack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [self.questionStack.centerXAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.centerXAnchor],
        [self.questionStack.widthAnchor constraintLessThanOrEqualToConstant:680], columnWidth,
        [self.questionStack.widthAnchor constraintLessThanOrEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-8],
    ]];
    self.progressLabel = [self labelWithSize:17 weight:UIFontWeightSemibold];
    self.progressLabel.accessibilityIdentifier = @"session.progress";
    [self.questionStack addArrangedSubview:self.progressLabel];
    self.progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progress.progressTintColor = ChildUI.calmGreen;
    self.progress.trackTintColor = [ChildUI.mintGreen colorWithAlphaComponent:0.3];
    self.progress.accessibilityElementsHidden = YES;
    [self.progress.heightAnchor constraintEqualToConstant:8].active = YES;
    [self.questionStack addArrangedSubview:self.progress];
    self.detailLabel = [self labelWithSize:19 weight:UIFontWeightSemibold];
    [self.questionStack addArrangedSubview:self.detailLabel];

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.whiteColor;
    card.layer.cornerRadius = 28;
    [ChildUI applySoftShadowOnLayer:card.layer];
    UIStackView *questionContent = [self verticalStack];
    questionContent.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:questionContent];
    [NSLayoutConstraint activateConstraints:@[
        [questionContent.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [questionContent.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20],
        [questionContent.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [questionContent.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
    ]];
    self.problemLabel = [self labelWithSize:48 weight:UIFontWeightBold];
    self.problemLabel.font = [ChildUI roundedMonoFontOfSize:48 weight:UIFontWeightBold];
    self.problemLabel.textAlignment = NSTextAlignmentCenter;
    self.problemLabel.adjustsFontSizeToFitWidth = YES;
    self.problemLabel.minimumScaleFactor = 0.7;
    self.problemLabel.accessibilityIdentifier = [self.prefix stringByAppendingString:@".problem"];
    [questionContent addArrangedSubview:self.problemLabel];
    self.storyLabel = [self labelWithSize:23 weight:UIFontWeightMedium];
    self.storyLabel.accessibilityIdentifier = @"story.text";
    self.storyLabel.hidden = self.kind != PracticeKindStory;
    self.problemLabel.hidden = self.kind == PracticeKindStory;
    [questionContent addArrangedSubview:self.storyLabel];
    self.equationLabel = [self labelWithSize:27 weight:UIFontWeightSemibold];
    self.equationLabel.accessibilityIdentifier = @"story.equation";
    self.equationLabel.hidden = YES;
    [questionContent addArrangedSubview:self.equationLabel];
    [self.questionStack addArrangedSubview:card];

    self.storyActions = [[UIStackView alloc] init];
    self.storyActions.axis = UILayoutConstraintAxisHorizontal;
    self.storyActions.distribution = UIStackViewDistributionFillEqually;
    self.storyActions.spacing = 12;
    ChildButton *speak = [self button:@"讀題目" color:ChildUI.skyBlue action:@selector(speakQuestion)];
    speak.accessibilityLabel = @"再讀一次題目";
    self.equationButton = [self button:@"🧮 看算式" color:ChildUI.lavender action:@selector(revealEquation)];
    self.equationButton.titleLabel.font = [ChildUI roundedFontOfSize:19 weight:UIFontWeightSemibold];
    [self.storyActions addArrangedSubview:speak];
    [self.storyActions addArrangedSubview:self.equationButton];
    self.storyActions.hidden = self.kind != PracticeKindStory;
    [self.questionStack addArrangedSubview:self.storyActions];
    self.statusLabel = [self labelWithSize:20 weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.accessibilityIdentifier = self.kind == PracticeKindDrill ? @"practice.streak" : @"session.feedback";
    [self.questionStack addArrangedSubview:self.statusLabel];

    self.mascotHost = [[UIView alloc] init];
    NSLayoutConstraint *mascotHeight = [self.mascotHost.heightAnchor constraintEqualToConstant:132];
    mascotHeight.priority = 999;
    mascotHeight.active = YES;
    self.mascot = [[MascotView alloc] initWithVariant:MascotVariantPortrait];
    self.mascot.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mascotHost addSubview:self.mascot];
    [NSLayoutConstraint activateConstraints:@[
        [self.mascot.centerXAnchor constraintEqualToAnchor:self.mascotHost.centerXAnchor],
        [self.mascot.centerYAnchor constraintEqualToAnchor:self.mascotHost.centerYAnchor],
        [self.mascot.widthAnchor constraintEqualToConstant:124],
        [self.mascot.heightAnchor constraintEqualToConstant:124],
    ]];
    self.mascotHost.hidden = self.writingMode || !SettingsManager.sharedInstance.mascotEnabled;
    [self.questionStack addArrangedSubview:self.mascotHost];

    self.scratchpadNote = [self labelWithSize:17 weight:UIFontWeightMedium];
    self.scratchpadNote.text = @"一根手指寫畫，兩根手指滑動頁面。\n這是草稿紙，不會自動判讀答案；寫好後，一起對照做法。";
    self.scratchpadNote.hidden = !self.writingMode;
    [self.questionStack addArrangedSubview:self.scratchpadNote];
    self.canvas = [[DrawingCanvasView alloc] initWithFrame:CGRectZero];
    ((PracticeScrollView *)self.scroll).drawingCanvas = self.canvas;
    self.canvas.backgroundColor = UIColor.whiteColor;
    self.canvas.layer.cornerRadius = 24;
    self.canvas.layer.borderWidth = 2;
    self.canvas.layer.borderColor = [ChildUI.brownText colorWithAlphaComponent:0.15].CGColor;
    self.canvas.clipsToBounds = YES;
    self.canvas.hidden = !self.writingMode;
    NSLayoutConstraint *canvasHeight = [self.canvas.heightAnchor constraintEqualToConstant:300];
    canvasHeight.priority = 999;
    canvasHeight.active = YES;
    [self.questionStack addArrangedSubview:self.canvas];
    self.writingTools = [[UIStackView alloc] init];
    self.writingTools.axis = UILayoutConstraintAxisHorizontal;
    self.writingTools.distribution = UIStackViewDistributionFillEqually;
    self.writingTools.spacing = 12;
    [self.writingTools addArrangedSubview:[self button:@"復原" color:ChildUI.lavender action:@selector(undo)]];
    [self.writingTools addArrangedSubview:[self button:@"清除" color:ChildUI.pinkAccent action:@selector(clear)]];
    self.writingTools.hidden = !self.writingMode;
    [self.questionStack addArrangedSubview:self.writingTools];

    self.tray = [[UIView alloc] init];
    self.tray.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tray];
    self.mcq = [[MultipleChoiceAnswerView alloc] initWithFrame:CGRectZero];
    self.mcq.delegate = self;
    self.mcq.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tray addSubview:self.mcq];
    NSLayoutConstraint *choiceHeight = [self.mcq.heightAnchor constraintEqualToAnchor:self.tray.heightAnchor];
    choiceHeight.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.mcq.leadingAnchor constraintEqualToAnchor:self.tray.leadingAnchor],
        [self.mcq.trailingAnchor constraintEqualToAnchor:self.tray.trailingAnchor],
        [self.mcq.centerYAnchor constraintEqualToAnchor:self.tray.centerYAnchor],
        [self.mcq.heightAnchor constraintLessThanOrEqualToConstant:320], choiceHeight,
    ]];
    self.feedback = [self verticalStack];
    self.feedback.spacing = 10;
    self.feedback.translatesAutoresizingMaskIntoConstraints = NO;
    self.feedbackTitle = [self labelWithSize:27 weight:UIFontWeightBold];
    self.feedbackTitle.textAlignment = NSTextAlignmentCenter;
    self.feedbackDetail = [self labelWithSize:18 weight:UIFontWeightMedium];
    self.feedbackDetail.textAlignment = NSTextAlignmentCenter;
    self.nextButton = [self button:@"下一題" color:ChildUI.mintGreen action:@selector(nextTapped)];
    self.nextButton.accessibilityIdentifier = @"session.next";
    self.reviewButton = [self button:@"再看做法" color:ChildUI.lavender action:@selector(helpTapped)];
    [self.feedback addArrangedSubview:self.feedbackTitle];
    [self.feedback addArrangedSubview:self.feedbackDetail];
    [self.feedback addArrangedSubview:self.nextButton];
    [self.feedback addArrangedSubview:self.reviewButton];
    self.feedbackScroll = [[UIScrollView alloc] init];
    self.feedbackScroll.accessibilityIdentifier = @"practice.feedback";
    self.feedbackScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.feedbackScroll.alwaysBounceVertical = YES;
    [self.tray addSubview:self.feedbackScroll];
    [self.feedbackScroll addSubview:self.feedback];
    [NSLayoutConstraint activateConstraints:@[
        [self.feedbackScroll.leadingAnchor constraintEqualToAnchor:self.tray.leadingAnchor],
        [self.feedbackScroll.trailingAnchor constraintEqualToAnchor:self.tray.trailingAnchor],
        [self.feedbackScroll.topAnchor constraintEqualToAnchor:self.tray.topAnchor],
        [self.feedbackScroll.bottomAnchor constraintEqualToAnchor:self.tray.bottomAnchor],
        [self.feedbackScroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:self.feedbackScroll.frameLayoutGuide.widthAnchor],
        [self.feedback.leadingAnchor constraintEqualToAnchor:self.feedbackScroll.contentLayoutGuide.leadingAnchor],
        [self.feedback.trailingAnchor constraintEqualToAnchor:self.feedbackScroll.contentLayoutGuide.trailingAnchor],
        [self.feedback.topAnchor constraintEqualToAnchor:self.feedbackScroll.contentLayoutGuide.topAnchor constant:4],
        [self.feedback.bottomAnchor constraintEqualToAnchor:self.feedbackScroll.contentLayoutGuide.bottomAnchor constant:-12],
    ]];
    self.checkWritingButton = [self button:@"寫好了，對照答案" color:ChildUI.mintGreen action:@selector(checkWriting)];
    self.checkWritingButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tray addSubview:self.checkWritingButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.checkWritingButton.centerYAnchor constraintEqualToAnchor:self.tray.centerYAnchor],
        [self.checkWritingButton.leadingAnchor constraintEqualToAnchor:self.tray.leadingAnchor],
        [self.checkWritingButton.trailingAnchor constraintEqualToAnchor:self.tray.trailingAnchor],
    ]];
    self.trayHeight = [self.tray.heightAnchor constraintEqualToConstant:264];
    NSLayoutConstraint *trayWidth = [self.tray.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-32];
    trayWidth.priority = UILayoutPriorityDefaultHigh;
    self.verticalConstraints = @[
        [self.scroll.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor constant:8],
        [self.scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.tray.topAnchor constant:-12],
        [self.tray.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.tray.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [self.tray.widthAnchor constraintLessThanOrEqualToConstant:640], trayWidth, self.trayHeight,
    ];
    self.wideConstraints = @[
        [self.scroll.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor constant:12],
        [self.scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.tray.leadingAnchor constant:-24],
        [self.scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [self.tray.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor constant:12],
        [self.tray.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.tray.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [self.tray.widthAnchor constraintEqualToAnchor:safe.widthAnchor multiplier:0.44 constant:-24],
    ];
    [NSLayoutConstraint activateConstraints:self.verticalConstraints];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    BOOL wide = self.view.bounds.size.width > self.view.bounds.size.height;
    if (wide != self.wideLayout) {
        [NSLayoutConstraint deactivateConstraints:self.wideLayout ? self.wideConstraints : self.verticalConstraints];
        self.wideLayout = wide;
        [NSLayoutConstraint activateConstraints:wide ? self.wideConstraints : self.verticalConstraints];
    }
    BOOL largeText = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    CGFloat height = self.writingMode && !self.session.awaitingNext ? 80 : (largeText ? 328 : 264);
    if (self.trayHeight.constant != height) self.trayHeight.constant = height;
}

#if DEBUG
// Explicit launch-only fixtures exercise the same native rendering and answer
// paths as generated content, without hoping a random draw reaches a defect.
- (NSArray *)debugFixtureQuestions {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [arguments indexOfObject:@"-CalcuLaterScenario"];
    if (index == NSNotFound || index + 1 >= arguments.count) return nil;
    NSString *scenario = arguments[index + 1];
    if (self.kind == PracticeKindStory && [scenario isEqualToString:@"remainder"]) {
        return @[[[WordProblem alloc] initWithStory:@"有 23 顆糖果，每 4 顆裝成一包，可以裝滿幾包？"
            templateID:@"quality.remainder" grade:3 number1:23 number2:4 operator:@"÷" answer:5 unit:@"包"
            missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:3
            number3:0 operator2:nil intermediate:0 isFractionAnswer:NO answerNumerator:0 answerDenominator:0]];
    }
    if (self.kind == PracticeKindStory && [scenario isEqualToString:@"fraction"]) {
        return @[[[WordProblem alloc] initWithStory:@"一張色紙平均分成 4 等份，塗上其中 1 份。塗色的部分是整張色紙的幾分之幾？"
            templateID:@"quality.fraction" grade:3 number1:1 number2:4 operator:@"/" answer:1 unit:@""
            missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:0
            number3:0 operator2:nil intermediate:0 isFractionAnswer:YES answerNumerator:1 answerDenominator:4]];
    }
    if (self.kind == PracticeKindDrill && [scenario isEqualToString:@"carry"]) {
        return @[[[ArithmeticProblem alloc] initWithNumber1:27 number2:15 operator:@"+" answer:42]];
    }
    if (self.kind == PracticeKindDrill && [scenario isEqualToString:@"borrow"]) {
        return @[[[ArithmeticProblem alloc] initWithNumber1:500 number2:128 operator:@"-" answer:372]];
    }
    return nil;
}
#endif

- (NSArray *)newQuestions {
#if DEBUG
    NSArray *fixture = [self debugFixtureQuestions];
    if (fixture) return fixture;
#endif
    if (self.lesson) return [self.lesson generateSessionProblems];
    NSUInteger count = self.kind == PracticeKindStory || self.writingMode ? 5 : 10;
    NSMutableArray *questions = [NSMutableArray arrayWithCapacity:count];
    SettingsManager *settings = SettingsManager.sharedInstance;
    NSString *lastTemplate = nil;
    NSString *lastArithmetic = nil;
    for (NSUInteger i = 0; i < count; i++) {
        if (self.kind == PracticeKindStory) {
            WordProblem *problem = [WordProblemGenerator generateForGrade:self.grade excludingTemplate:lastTemplate];
            lastTemplate = problem.templateID;
            [questions addObject:problem];
        } else {
            ArithmeticProblem *problem;
            NSString *key;
            for (NSUInteger attempt = 0; attempt < 12; attempt++) {
                problem = [ProblemGenerator generateForTier:(DrillTier)settings.drillTier
                    allowAddition:settings.operationAddition allowSubtraction:settings.operationSubtraction
                    allowMultiplication:settings.operationMultiplication allowDivision:settings.operationDivision];
                key = [NSString stringWithFormat:@"%ld%@%ld", (long)problem.number1, problem.operatorSymbol, (long)problem.number2];
                if (![key isEqualToString:lastArithmetic]) break;
            }
            lastArithmetic = key;
            [questions addObject:problem];
        }
    }
    return questions;
}
- (void)beginNewRun {
    self.reviewRun = NO;
    [self beginQuestions:[self newQuestions]];
}
- (void)beginQuestions:(NSArray *)questions {
    self.session = [[PracticeSession alloc] initWithQuestions:questions];
    self.correctStreak = 0;
    self.showingSummary = NO;
    [self.summaryScroll removeFromSuperview]; self.summaryScroll = nil;
    self.scroll.hidden = NO;
    self.tray.hidden = NO;
    self.helpButton.hidden = NO;
    [self loadCurrentQuestion];
}
- (WordProblem *)wordProblem {
    id question = self.session.currentQuestion;
    return [question isKindOfClass:WordProblem.class] ? question : nil;
}
- (ArithmeticProblem *)arithmeticProblem {
    return self.wordProblem ? self.wordProblem.toArithmeticProblem : self.session.currentQuestion;
}
- (NSString *)equationRevealing:(BOOL)reveal {
    if (self.wordProblem) return [self.wordProblem equationTextRevealingAnswer:reveal];
    ArithmeticProblem *p = self.arithmeticProblem;
    NSString *op = [p.operatorSymbol isEqualToString:@"-"] ? @"−" : p.operatorSymbol;
    return [NSString stringWithFormat:@"%ld %@ %ld = %@", (long)p.number1, op, (long)p.number2,
        reveal ? [@(p.answer) stringValue] : @"?"];
}
- (void)loadCurrentQuestion {
    if (self.session.finished) { [self showSummary]; return; }
    [SpeechManager.sharedInstance stop];
    [self.canvas resetCanvas];
    self.equationRevealed = NO;
    self.progressLabel.text = [NSString stringWithFormat:@"%@第 %lu 題 · 共 %lu 題",
        self.reviewRun ? @"再練一次 · " : @"", (unsigned long)self.session.currentIndex + 1,
        (unsigned long)self.session.questions.count];
    self.progress.progress = (float)self.session.currentIndex / MAX(1, self.session.questions.count);
    self.detailLabel.text = self.lesson ? self.lesson.title : self.kind == PracticeKindStory
        ? [NSString stringWithFormat:@"%ld 年級 · 把數學用在生活裡", (long)self.grade]
        : [ProblemGenerator titleForTier:(DrillTier)SettingsManager.sharedInstance.drillTier];
    self.problemLabel.text = [self equationRevealing:NO];
    self.storyLabel.text = self.wordProblem.storyText;
    self.equationLabel.text = @"";
    self.equationLabel.hidden = YES;
    self.equationButton.hidden = NO;
    self.statusLabel.text = self.writingMode ? @"可以畫點點，也可以寫算式。" : @"自己試試，不急著猜。";
    [self.mascot setEmotion:MascotEmotionIdle];
    self.feedbackScroll.hidden = YES;
    self.mcq.hidden = self.writingMode;
    self.checkWritingButton.hidden = !self.writingMode;
    if (!self.writingMode) {
        WordProblem *word = self.wordProblem;
        if (word.isFractionAnswer) {
            NSInteger index = NSNotFound;
            NSArray *choices = [DistractorGenerator fractionChoicesForNumerator:word.answerNumerator
                denominator:word.answerDenominator outCorrectIndex:&index];
            [self.mcq configureWithChoiceTitles:choices correctIndex:index];
        } else {
            [self.mcq configureWithProblem:self.arithmeticProblem];
        }
    }
    [self.scroll setContentOffset:CGPointZero animated:NO];
    [self.view setNeedsLayout];
    if (self.wordProblem && SettingsManager.sharedInstance.soundEffectsEnabled && !UIAccessibilityIsVoiceOverRunning()) {
        [self speakQuestion];
    }
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,
        self.wordProblem ? self.storyLabel : self.problemLabel);
}

- (void)mcqView:(MultipleChoiceAnswerView *)view didChoose:(NSInteger)value result:(MCQResult)result {
    if (![self.session submitCorrect:result == MCQResultCorrect]) return;
    if (result == MCQResultCorrect) {
        self.correctStreak++;
        [SoundManager.sharedInstance play:self.correctStreak % 5 == 0 ? SoundEffectCheer : SoundEffectCorrect];
        [self.mascot setEmotion:MascotEmotionHappy];
        [self showResolvedCorrect:YES];
        return;
    }
    self.correctStreak = 0;
    [SoundManager.sharedInstance play:SoundEffectWrong];
    [self.mascot setEmotion:MascotEmotionThinking];
    self.statusLabel.text = @"沒關係，再想想看。";
    if (self.session.awaitingNext) {
        [self showResolvedCorrect:NO];
    } else if (self.session.attempts == 2) {
        self.statusLabel.text = @"我們一起看看做法，再回來試試。";
        [self helpTapped];
    } else {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.statusLabel.text);
    }
}
- (void)showResolvedCorrect:(BOOL)correct {
    [self.mcq revealCorrectChoice];
    self.mcq.hidden = YES;
    self.checkWritingButton.hidden = YES;
    self.feedbackScroll.hidden = NO;
    [self.feedbackScroll setContentOffset:CGPointZero animated:NO];
    self.feedbackTitle.text = self.writingMode ? @"一起對照看看" : correct ? @"答對了！" : @"這一題，一起學會了";
    self.feedbackDetail.text = self.writingMode ? @"答案不會自動判讀，看看你的做法一不一樣。"
        : self.session.usedHelp ? @"會找方法，也是一種進步。準備好再往下走。"
        : self.session.attempts > 1 ? @"你再試了一次，找到答案了。" : @"把答案看清楚，準備好了再繼續。";
    self.statusLabel.text = correct ? [NSString stringWithFormat:@"答對了！連對 ×%ld", (long)self.correctStreak]
        : @"慢慢來，做法可以再看一次。";
    NSString *next = self.session.currentIndex + 1 == self.session.questions.count ? @"看看這次收穫" : @"我懂了，下一題";
    [self.nextButton setTitle:next forState:UIControlStateNormal];
    self.problemLabel.text = [self equationRevealing:YES];
    if (self.wordProblem) {
        self.equationLabel.text = [self equationRevealing:YES];
        self.equationLabel.hidden = NO;
        self.equationButton.hidden = YES;
    }
    [self.view setNeedsLayout];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.feedbackTitle);
}
- (void)nextTapped {
    if (![self.session advance]) return;
    [self loadCurrentQuestion];
}
- (void)helpTapped {
    if (!self.session.currentQuestion || self.presentedViewController || self.showingSummary) return;
    [self.session markHelpUsed];
    [SpeechManager.sharedInstance stop];
    ArithmeticProblem *problem = self.arithmeticProblem;
    BOOL strategyLesson = self.lesson && (self.lesson.kind == LessonKindMakeTen || self.lesson.kind == LessonKindBreakTen);
    BOOL needsPlaceValue = MAX(problem.number1, MAX(problem.number2, problem.answer)) > 20;
    UIViewController *explanation;
    if (needsPlaceValue && !strategyLesson && [VerticalTeachingViewController supportsProblem:problem wordProblem:self.wordProblem]) {
        explanation = [[VerticalTeachingViewController alloc] initWithProblem:problem wordProblem:self.wordProblem];
    } else {
        // Count small sets and retain the lesson's make-ten/break-ten strategy.
        // A secondary entry lets learners connect those pictures to the columns.
        explanation = [[ExplanationViewController alloc]
            initWithArithmeticProblem:problem wordProblem:self.wordProblem lesson:self.lesson];
    }
    [self presentViewController:explanation animated:YES completion:nil];
}
- (void)revealEquation {
    if (!self.wordProblem || self.equationRevealed) return;
    self.equationRevealed = YES;
    self.equationLabel.text = [self equationRevealing:self.session.awaitingNext];
    self.equationLabel.hidden = NO;
    self.equationButton.hidden = YES;
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.equationLabel);
}
- (void)speakQuestion { [SpeechManager.sharedInstance speak:self.wordProblem.storyText ?: [self equationRevealing:NO]]; }
- (void)undo { [self.canvas undoLastStroke]; }
- (void)clear { [self.canvas clearCanvas]; }
- (void)checkWriting {
    [self.session revealAnswer];
    [self showResolvedCorrect:NO];
}

- (void)showIntro {
    self.intro = [[LessonIntroView alloc] initWithLesson:self.lesson];
    self.intro.delegate = self;
    self.intro.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.intro];
    [NSLayoutConstraint activateConstraints:@[
        [self.intro.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor constant:12],
        [self.intro.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.intro.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.intro.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
    ]];
    self.scroll.hidden = YES; self.tray.hidden = YES; self.helpButton.hidden = YES;
    [self.view layoutIfNeeded];
    [self.intro play];
}
- (void)lessonIntroDidFinish:(LessonIntroView *)introView {
    [introView stopPlayback];
    [introView removeFromSuperview];
    self.intro = nil;
    self.scroll.hidden = NO; self.tray.hidden = NO; self.helpButton.hidden = NO;
    [self loadCurrentQuestion];
}

- (void)showSummary {
    if (self.showingSummary) return;
    self.showingSummary = YES;
    [SpeechManager.sharedInstance stop];
    [PracticeProgressStore.sharedInstance recordFinishedSession:self.session];
    if (self.lesson && !self.reviewRun) {
        [LessonProgressStore.sharedInstance recordLessonID:self.lesson.lessonID
            correct:self.session.independentCount outOf:self.session.questions.count];
    }
    self.scroll.hidden = YES; self.tray.hidden = YES; self.helpButton.hidden = YES;
    self.summaryScroll = [[UIScrollView alloc] init];
    self.summaryScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.summaryScroll.accessibilityIdentifier = @"session.summary";
    [self.view addSubview:self.summaryScroll];
    UIStackView *stack = [self verticalStack];
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.summaryScroll addSubview:stack];
    NSLayoutConstraint *width = [stack.widthAnchor constraintEqualToAnchor:self.summaryScroll.frameLayoutGuide.widthAnchor constant:-40];
    width.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [self.summaryScroll.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor constant:16],
        [self.summaryScroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.summaryScroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.summaryScroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.summaryScroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:self.summaryScroll.frameLayoutGuide.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.summaryScroll.contentLayoutGuide.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:self.summaryScroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.centerXAnchor constraintEqualToAnchor:self.summaryScroll.frameLayoutGuide.centerXAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:600], width,
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:self.summaryScroll.frameLayoutGuide.widthAnchor constant:-40],
    ]];
    UILabel *heading = [self labelWithSize:32 weight:UIFontWeightBold];
    heading.text = self.reviewRun ? @"再練一次，又進步了！" : @"今天又多會了一點！";
    heading.textAlignment = NSTextAlignmentCenter;
    heading.accessibilityTraits |= UIAccessibilityTraitHeader;
    [stack addArrangedSubview:heading];
    UILabel *complete = [self labelWithSize:23 weight:UIFontWeightSemibold];
    complete.text = [NSString stringWithFormat:@"完成 %lu 題，給自己拍拍手。", (unsigned long)self.session.questions.count];
    complete.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:complete];
    UILabel *results = [self labelWithSize:22 weight:UIFontWeightMedium];
    results.text = self.writingMode ? [NSString stringWithFormat:@"對照做法 %lu 題\n手寫答案由你自己確認。", (unsigned long)self.session.questions.count]
        : [NSString stringWithFormat:@"自己解開  %lu 題\n再試成功  %lu 題\n一起學會  %lu 題",
            (unsigned long)self.session.independentCount, (unsigned long)self.session.retriedCount,
            (unsigned long)self.session.guidedCount];
    results.textAlignment = NSTextAlignmentCenter;
    results.accessibilityIdentifier = @"session.results";
    [stack addArrangedSubview:results];
    if (self.lesson) {
        NSInteger best = [LessonProgressStore.sharedInstance starsForLessonID:self.lesson.lessonID];
        UILabel *bestLabel = [self labelWithSize:18 weight:UIFontWeightMedium];
        bestLabel.text = [NSString stringWithFormat:@"最佳紀錄：%ld 顆星\n這次自己解開 %lu / %lu 題", (long)best,
            (unsigned long)self.session.independentCount, (unsigned long)self.session.questions.count];
        bestLabel.textAlignment = NSTextAlignmentCenter;
        [stack addArrangedSubview:bestLabel];
    }
    if (self.session.reviewQuestions.count && !self.writingMode) {
        NSString *title = [NSString stringWithFormat:@"再練這 %lu 題", (unsigned long)self.session.reviewQuestions.count];
        ChildButton *review = [self button:title color:ChildUI.lavender action:@selector(retryQuestions)];
        review.accessibilityIdentifier = @"session.review";
        [stack addArrangedSubview:review];
    }
    ChildButton *again = [self button:@"再來一小輪" color:ChildUI.mintGreen action:@selector(beginNewRun)];
    again.accessibilityIdentifier = @"session.again";
    [stack addArrangedSubview:again];
    [stack addArrangedSubview:[self button:@"先休息，回去看看" color:ChildUI.skyBlue action:@selector(dismissPractice)]];
    [SoundManager.sharedInstance play:SoundEffectCheer];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, heading);
}
- (void)retryQuestions {
    NSArray *questions = self.session.reviewQuestions;
    if (questions.count == 0) return;
    self.reviewRun = YES;
    [self beginQuestions:questions];
}
- (void)closeTapped {
    if (self.presentedViewController) return;
    if (!self.showingSummary && (self.session.currentIndex > 0 || self.session.attempts > 0 || self.session.usedHelp)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"先休息一下嗎？"
            message:@"這一輪還沒完成。離開後，下次會開始新的一輪。"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"繼續練習" style:UIAlertActionStyleCancel handler:nil]];
        __weak typeof(self) weakSelf = self;
        [alert addAction:[UIAlertAction actionWithTitle:@"先休息" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) { [weakSelf dismissPractice]; }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else [self dismissPractice];
}
- (void)dismissPractice {
    [SpeechManager.sharedInstance stop];
    [self.intro stopPlayback];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [SpeechManager.sharedInstance stop];
    [self.intro stopPlayback];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [SoundManager.sharedInstance prepare];
}
@end
