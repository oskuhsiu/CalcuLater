#import "ConceptLearningPathViewController.h"
#import "ConceptLearningPath.h"
#import "ArithmeticProblem.h"
#import "VerticalTeachingViewController.h"
#import "GroupingTeachingViewController.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"
#import "SpeechManager.h"
#import <math.h>

/// Full-size Dynamic Type titles wrap inside the actual button width. Actions
/// grow vertically instead of capping, shrinking, or clipping the chosen text.
@interface ConceptPathActionButton : ChildButton
@end
@implementation ConceptPathActionButton
- (CGSize)intrinsicContentSize {
    // Keep the natural width independent of the previous wrapping width, so
    // the persistent Close action can grow again after a narrow/large-text pass.
    CGSize naturalTitle = [self.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    CGSize size = CGSizeMake(ceil(naturalTitle.width) + self.contentEdgeInsets.left + self.contentEdgeInsets.right, 0);
    CGFloat width = self.bounds.size.width > 0 ? self.bounds.size.width : size.width;
    width = MAX(1, width - self.contentEdgeInsets.left - self.contentEdgeInsets.right);
    CGSize title = [self.titleLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    size.height = MAX(60, ceil(title.height) + self.contentEdgeInsets.top + self.contentEdgeInsets.bottom);
    return size;
}
- (CGRect)titleRectForContentRect:(CGRect)contentRect {
    // UIKit asks for this rectangle while lazily creating titleLabel. Reading
    // that property here re-enters its creation and exhausts the stack. The
    // content rectangle already excludes our padding; UILabel centers its full
    // wrapped text within it, and intrinsicContentSize supplies the needed height.
    return contentRect;
}
- (void)layoutSubviews {
    CGFloat width = MAX(1, self.bounds.size.width - self.contentEdgeInsets.left - self.contentEdgeInsets.right);
    if (fabs(self.titleLabel.preferredMaxLayoutWidth - width) > 0.5) {
        self.titleLabel.preferredMaxLayoutWidth = width;
        [self invalidateIntrinsicContentSize];
    }
    [super layoutSubviews];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self invalidateIntrinsicContentSize];
}
@end

@interface ConceptLearningPathViewController ()
@property (nonatomic, strong) ConceptLearningPath *path;
@property (nonatomic) NSUInteger stageIndex;
@property (nonatomic) NSUInteger explorationIndex;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UILabel *stageLabel;
@property (nonatomic, strong) UILabel *invitationLabel;
@property (nonatomic, strong) UILabel *questionLabel;
@property (nonatomic, strong) UILabel *equationLabel;
@property (nonatomic, strong) UILabel *focusLabel;
@property (nonatomic, strong) UILabel *variationLabel;
@property (nonatomic, strong) ChildButton *readButton;
@property (nonatomic, strong) ChildButton *previousNumbersButton;
@property (nonatomic, strong) ChildButton *changeButton;
@property (nonatomic, strong) ChildButton *previousButton;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) UIStackView *navigation;
@property (nonatomic, strong) UIStackView *numberNavigation;
@property (nonatomic, strong, nullable) SpeechManager *readingSpeechManager;
@property (nonatomic) NSUInteger readingGeneration;
@property (nonatomic) BOOL hasReadCurrentQuestion;
@property (nonatomic) BOOL applicationInactive;
@property (nonatomic) BOOL viewLeaving;
@end
@implementation ConceptLearningPathViewController
- (instancetype)initWithPath:(ConceptLearningPath *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _path = path; self.modalPresentationStyle = UIModalPresentationFullScreen; }
    return self;
}
- (UILabel *)label:(CGFloat)size bold:(BOOL)bold identifier:(NSString *)identifier {
    UILabel *label = [[ChildWrappingLabel alloc] init];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:size weight:bold ? UIFontWeightBold : UIFontWeightRegular]
        compatibleWithTraitCollection:self.traitCollection];
    label.adjustsFontForContentSizeCategory = YES; label.textColor = ChildUI.brownText; label.numberOfLines = 0;
    label.accessibilityIdentifier = identifier;
    return label;
}
- (ChildButton *)button:(NSString *)title color:(UIColor *)color identifier:(NSString *)identifier action:(SEL)action {
    // ChildButton's inherited convenience factory returns ChildButton itself,
    // so allocate this local subclass directly to retain its sizing contract.
    ChildButton *button = [ConceptPathActionButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:ChildUI.brownText forState:UIControlStateNormal];
    [button setTitleColor:ChildUI.brownText forState:UIControlStateHighlighted];
    [button setTitleColor:ChildUI.brownText forState:UIControlStateDisabled];
    button.backgroundColor = color;
    button.layer.cornerRadius = 20;
    [ChildUI applySoftShadowOnLayer:button.layer];
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:20 weight:UIFontWeightBold]
        compatibleWithTraitCollection:self.traitCollection];
    button.titleLabel.adjustsFontForContentSizeCategory = YES; button.titleLabel.adjustsFontSizeToFitWidth = NO;
    button.titleLabel.numberOfLines = 0; button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    [button setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [button setContentCompressionResistancePriority:999 forAxis:UILayoutConstraintAxisVertical];
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 16, 14, 16);
    button.accessibilityIdentifier = identifier;
    NSLayoutConstraint *height = [button.heightAnchor constraintGreaterThanOrEqualToConstant:60];
    height.priority = 999; // Hidden arranged actions must be allowed to collapse.
    height.active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillInterruptReading:)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillInterruptReading:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeLessons];
    self.view.accessibilityIdentifier = @"concept.screen";
    ChildButton *close = [self button:@"回到學一學" color:ChildUI.skyBlue identifier:@"concept.close" action:@selector(close)];
    close.accessibilityHint = @"離開探索，不會改變練習星星。"; close.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:close];
    self.scroll = [[UIScrollView alloc] init]; self.scroll.accessibilityIdentifier = @"concept.content";
    self.scroll.alwaysBounceVertical = YES; self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scroll];
    UIStackView *content = [[UIStackView alloc] init]; content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 18; content.translatesAutoresizingMaskIntoConstraints = NO; [self.scroll addSubview:content];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *scrollWidth = [self.scroll.widthAnchor constraintEqualToAnchor:safe.widthAnchor]; scrollWidth.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [close.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8], [close.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [close.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:16],
        [self.scroll.topAnchor constraintEqualToAnchor:close.bottomAnchor constant:8], [self.scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [self.scroll.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [self.scroll.widthAnchor constraintLessThanOrEqualToConstant:768], scrollWidth,
        [content.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:16],
        [content.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [content.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [content.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];
    UILabel *title = [self label:26 bold:YES identifier:@"concept.title"]; title.text = self.path.title;
    title.accessibilityTraits |= UIAccessibilityTraitHeader; [content addArrangedSubview:title];
    UILabel *unscored = [self label:17 bold:NO identifier:@"concept.unscored"];
    unscored.text = @"慢慢探索，不計分、不限時。"; [content addArrangedSubview:unscored];
    self.stageLabel = [self label:21 bold:YES identifier:@"concept.stage"]; self.stageLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.invitationLabel = [self label:19 bold:NO identifier:@"concept.invitation"];
    self.questionLabel = [self label:22 bold:YES identifier:@"concept.question"];
    self.equationLabel = [self label:30 bold:YES identifier:@"concept.equation"];
    self.equationLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.focusLabel = [self label:19 bold:NO identifier:@"concept.focus"];
    for (UILabel *label in @[self.stageLabel, self.invitationLabel, self.questionLabel, self.equationLabel]) [content addArrangedSubview:label];
    self.readButton = [self button:@"聽題目" color:ChildUI.skyBlue identifier:@"concept.read" action:@selector(readQuestion)];
    [content addArrangedSubview:self.readButton];
    // Number comparison belongs with the current equation, not with stage navigation.
    self.variationLabel = [self label:17 bold:NO identifier:@"concept.variation"]; [content addArrangedSubview:self.variationLabel];
    self.numberNavigation = [[UIStackView alloc] init]; self.numberNavigation.spacing = 12;
    self.numberNavigation.distribution = UIStackViewDistributionFillEqually;
    self.previousNumbersButton = [self button:@"上一組數字" color:ChildUI.eggYolk identifier:@"concept.previousNumbers" action:@selector(previousNumbers)];
    self.changeButton = [self button:@"下一組數字" color:ChildUI.eggYolk identifier:@"concept.change" action:@selector(changeNumbers)];
    [self.numberNavigation addArrangedSubview:self.previousNumbersButton]; [self.numberNavigation addArrangedSubview:self.changeButton];
    [content addArrangedSubview:self.numberNavigation];
    [content addArrangedSubview:self.focusLabel];
    ChildButton *teach = [self button:@"看這題怎麼算" color:ChildUI.mintGreen identifier:@"concept.teach" action:@selector(openTeaching)];
    teach.accessibilityHint = @"打開這一題的動畫。可以自己選擇每一步，也可以試著回答，不計分。"; [content addArrangedSubview:teach];
    self.navigation = [[UIStackView alloc] init]; self.navigation.spacing = 12; self.navigation.distribution = UIStackViewDistributionFillEqually;
    self.previousButton = [self button:@"上一階段" color:ChildUI.lavender identifier:@"concept.previous" action:@selector(previous)];
    self.nextButton = [self button:@"下一階段" color:ChildUI.skyBlue identifier:@"concept.next" action:@selector(next)];
    [self.navigation addArrangedSubview:self.previousButton]; [self.navigation addArrangedSubview:self.nextButton]; [content addArrangedSubview:self.navigation];
    [self updateQuestion];
}
- (ConceptLearningExample *)currentExample {
    if (self.stageIndex == 0) return self.path.firstExample;
    if (self.stageIndex == 1) return self.path.relatedExample;
    return self.path.explorationExamples[self.explorationIndex];
}
- (void)updateQuestion {
    [self stopQuestionReading];
    self.hasReadCurrentQuestion = NO;
    [self updateReadingButton];
    ConceptLearningExample *example = [self currentExample];
    self.stageLabel.text = @[@"1 / 3 · 學習階段：看一個例子", @"2 / 3 · 學習階段：換一題想想", @"3 / 3 · 學習階段：換數字探索"][self.stageIndex];
    self.invitationLabel.text = @[@"動畫可以慢慢看，每次只看一小步。", @"先用手指或心裡想一想：和剛才有什麼一樣？", @"來回換數字，比較方法哪裡一樣、哪裡不同。"][self.stageIndex];
    self.questionLabel.text = example.questionText; self.equationLabel.text = example.equationText; self.focusLabel.text = example.focusText;
    self.previousButton.enabled = self.stageIndex > 0;
    self.previousButton.accessibilityHint = self.stageIndex == 2 ? @"回到換一題想想。再回來時，會保留現在這組數字。" : @"回到看一個例子，不是換上一組探索數字。";
    [self.nextButton setTitle:self.stageIndex == 2 ? @"回到學一學" : @"下一階段" forState:UIControlStateNormal];
    self.nextButton.accessibilityHint = self.stageIndex == 2 ? @"離開探索，不會記錄為學會或增加星星。" : @"換到下一個學習階段。可以不看動畫，也可以再回來。";
    BOOL explore = self.stageIndex == 2;
    self.variationLabel.hidden = !explore; self.numberNavigation.hidden = !explore;
    self.previousNumbersButton.hidden = !explore; self.changeButton.hidden = !explore;
    NSUInteger count = self.path.explorationExamples.count;
    self.variationLabel.text = [NSString stringWithFormat:@"數字組別 %lu / %lu，可以來回比較。", (unsigned long)self.explorationIndex + 1, (unsigned long)count];
    self.previousNumbersButton.accessibilityHint = self.explorationIndex == 0
        ? @"回到最後一組數字，留在換數字探索。不會計分。" : @"看上一組數字，留在換數字探索。不會計分。";
    self.changeButton.accessibilityHint = self.explorationIndex + 1 == count
        ? @"回到第一組數字，留在換數字探索。不會計分。" : @"看下一組數字，留在換數字探索。不會計分。";
    self.view.accessibilityValue = [NSString stringWithFormat:@"%@，%@", self.path.title, self.stageLabel.text];
}
- (void)showChangedQuestion {
    [self updateQuestion];
    [self.view layoutIfNeeded];
    CGRect heading = [self.stageLabel convertRect:self.stageLabel.bounds toView:self.scroll];
    CGFloat maximum = MAX(0, self.scroll.contentSize.height - self.scroll.bounds.size.height);
    [self.scroll setContentOffset:CGPointMake(0, MIN(maximum, MAX(0, heading.origin.y - 12))) animated:NO];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.stageLabel);
}
- (void)previous { if (self.presentedViewController || self.stageIndex == 0) return; self.stageIndex--; [self showChangedQuestion]; }
- (void)next {
    if (self.presentedViewController) return;
    if (self.stageIndex == 2) { [self close]; return; }
    self.stageIndex++; [self showChangedQuestion];
}
- (void)changeNumbers {
    if (self.presentedViewController || self.stageIndex != 2) return;
    self.explorationIndex = (self.explorationIndex + 1) % self.path.explorationExamples.count; [self showChangedQuestion];
}
- (void)previousNumbers {
    if (self.presentedViewController || self.stageIndex != 2) return;
    NSUInteger count = self.path.explorationExamples.count;
    self.explorationIndex = (self.explorationIndex + count - 1) % count; [self showChangedQuestion];
}
- (SpeechManager *)questionSpeechManager { return SpeechManager.sharedInstance; }
- (NSString *)questionReadingText {
    ConceptLearningExample *example = [self currentExample];
    // Speak only the displayed question and focus. Never ask a solution/teaching
    // sequence for narration, and never read problem.answer or a worked result.
    NSString *equation = example.equationText;
    for (NSArray<NSString *> *replacement in @[@[@" + ", @" 加 "], @[@" − ", @" 減 "],
                                                @[@" × ", @" 乘以 "], @[@" ÷ ", @" 除以 "],
                                                @[@" = ?", @" 等於多少？"]]) {
        equation = [equation stringByReplacingOccurrencesOfString:replacement[0] withString:replacement[1]];
    }
    return [NSString stringWithFormat:@"%@\n%@\n%@", example.questionText, equation, example.focusText];
}
- (void)updateReadingButton {
    BOOL reading = self.readingSpeechManager != nil;
    [self.readButton setTitle:reading ? @"停止朗讀" : (self.hasReadCurrentQuestion ? @"再聽一次" : @"聽題目") forState:UIControlStateNormal];
    self.readButton.accessibilityValue = reading ? @"正在朗讀題目" : @"沒有朗讀";
    self.readButton.accessibilityHint = reading ? @"停止朗讀，題目和學習階段都不會改變。" : @"從頭朗讀這題和想一想的提示，不會打開解答。";
}
- (void)readQuestion {
    if (self.presentedViewController || self.isBeingDismissed || self.applicationInactive || self.viewLeaving || !self.view.window) return;
    if (self.readingSpeechManager) { [self stopQuestionReading]; return; }
    self.hasReadCurrentQuestion = YES;
    NSUInteger generation = ++self.readingGeneration;
    self.readingSpeechManager = [self questionSpeechManager];
    [self updateReadingButton];
    __weak typeof(self) weakSelf = self;
    [self.readingSpeechManager speak:[self questionReadingText] willSpeakRange:nil onFinish:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.readingGeneration != generation) return;
        self.readingSpeechManager = nil;
        [self updateReadingButton];
    }];
}
- (void)stopQuestionReading {
    // Clear ownership before stop invokes its completion. Late callbacks cannot
    // relabel a newer question/read, or stop another screen's shared speech.
    ++self.readingGeneration;
    SpeechManager *speech = self.readingSpeechManager;
    self.readingSpeechManager = nil;
    [speech stop];
    [self updateReadingButton];
}
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion {
    // A page sheet need not make its presenter disappear. Stop at presentation,
    // independently of the existing teaching-route choice below.
    [self stopQuestionReading];
    [super presentViewController:controller animated:animated completion:completion];
}
- (void)openTeaching {
    if (self.presentedViewController || self.isBeingDismissed) return;
    ConceptLearningExample *example = [self currentExample]; ArithmeticProblem *problem = example.problem; UIViewController *teaching;
    if (example.wordProblem && [GroupingTeachingViewController supportsProblem:problem wordProblem:example.wordProblem]) {
        teaching = [[GroupingTeachingViewController alloc] initWithProblem:problem wordProblem:example.wordProblem];
    } else if (!example.wordProblem && [VerticalTeachingViewController supportsProblem:problem wordProblem:nil]) {
        teaching = [[VerticalTeachingViewController alloc] initWithProblem:problem wordProblem:nil];
    } else { return; } // Fail closed. A story must never silently become arithmetic-only teaching.
    // Default sheet dismissal returns exactly here, without changing this question or scoring.
    [self presentViewController:teaching animated:YES completion:nil];
}
- (void)close { if (self.presentedViewController || self.isBeingDismissed) return; [self stopQuestionReading]; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.viewLeaving = YES;
    [self stopQuestionReading];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.viewLeaving = NO; // Returning enables a new tap; it never resumes speech.
}
- (void)applicationWillInterruptReading:(NSNotification *)notification {
    self.applicationInactive = YES;
    [self stopQuestionReading];
}
- (void)applicationDidBecomeActive:(NSNotification *)notification { self.applicationInactive = NO; }
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_readingSpeechManager stop];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.navigation.axis = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) || self.scroll.bounds.size.width < 400 ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.numberNavigation.axis = self.navigation.axis;
}
@end
