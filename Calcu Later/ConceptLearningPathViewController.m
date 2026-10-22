#import "ConceptLearningPathViewController.h"
#import "ConceptLearningPath.h"
#import "ArithmeticProblem.h"
#import "VerticalTeachingViewController.h"
#import "GroupingTeachingViewController.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"
#import <math.h>

/// Single-line, capped actions still grow vertically when text size changes.
@interface ConceptPathActionButton : ChildButton
@end
@implementation ConceptPathActionButton
- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    size.height = MAX(60, ceil(self.titleLabel.font.lineHeight) + self.contentEdgeInsets.top + self.contentEdgeInsets.bottom);
    return size;
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
@property (nonatomic, strong) ChildButton *changeButton;
@property (nonatomic, strong) ChildButton *previousButton;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) UIStackView *navigation;
@end
@implementation ConceptLearningPathViewController
- (instancetype)initWithPath:(ConceptLearningPath *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _path = path; self.modalPresentationStyle = UIModalPresentationFullScreen; }
    return self;
}
- (UILabel *)label:(CGFloat)size bold:(BOOL)bold identifier:(NSString *)identifier {
    UILabel *label = [[ChildWrappingLabel alloc] init];
    label.font = [ChildUI scaledRoundedFontOfSize:size weight:bold ? UIFontWeightBold : UIFontWeightRegular textStyle:UIFontTextStyleBody maximumPointSize:size * 1.6];
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
    button.titleLabel.font = [ChildUI scaledRoundedFontOfSize:20 weight:UIFontWeightBold textStyle:UIFontTextStyleBody maximumPointSize:28];
    button.titleLabel.adjustsFontForContentSizeCategory = YES; button.titleLabel.adjustsFontSizeToFitWidth = NO;
    button.titleLabel.numberOfLines = 1; button.titleLabel.textAlignment = NSTextAlignmentCenter;
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
    unscored.text = @"慢慢探索，不計分、不限時。可以先想、看動畫，或直接換一題。"; [content addArrangedSubview:unscored];
    self.stageLabel = [self label:21 bold:YES identifier:@"concept.stage"]; self.stageLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.invitationLabel = [self label:19 bold:NO identifier:@"concept.invitation"];
    self.questionLabel = [self label:22 bold:YES identifier:@"concept.question"];
    self.equationLabel = [self label:30 bold:YES identifier:@"concept.equation"];
    self.focusLabel = [self label:19 bold:NO identifier:@"concept.focus"];
    for (UILabel *label in @[self.stageLabel, self.invitationLabel, self.questionLabel, self.equationLabel, self.focusLabel]) [content addArrangedSubview:label];
    ChildButton *teach = [self button:@"看這題怎麼算" color:ChildUI.mintGreen identifier:@"concept.teach" action:@selector(openTeaching)];
    teach.accessibilityHint = @"打開這一題的動畫。可以自己選擇每一步，也可以試著回答，不計分。"; [content addArrangedSubview:teach];
    self.variationLabel = [self label:17 bold:NO identifier:@"concept.variation"]; [content addArrangedSubview:self.variationLabel];
    self.changeButton = [self button:@"換一組數字" color:ChildUI.eggYolk identifier:@"concept.change" action:@selector(changeNumbers)];
    self.changeButton.accessibilityHint = @"輪流探索三組準備好的數字。不會計分。"; [content addArrangedSubview:self.changeButton];
    self.navigation = [[UIStackView alloc] init]; self.navigation.spacing = 12; self.navigation.distribution = UIStackViewDistributionFillEqually;
    self.previousButton = [self button:@"上一題" color:ChildUI.lavender identifier:@"concept.previous" action:@selector(previous)];
    self.nextButton = [self button:@"下一題" color:ChildUI.skyBlue identifier:@"concept.next" action:@selector(next)];
    [self.navigation addArrangedSubview:self.previousButton]; [self.navigation addArrangedSubview:self.nextButton]; [content addArrangedSubview:self.navigation];
    [self updateQuestion];
}
- (ConceptLearningExample *)currentExample {
    if (self.stageIndex == 0) return self.path.firstExample;
    if (self.stageIndex == 1) return self.path.relatedExample;
    return self.path.explorationExamples[self.explorationIndex];
}
- (void)updateQuestion {
    ConceptLearningExample *example = [self currentExample];
    self.stageLabel.text = @[@"1 / 3 · 看一個例子", @"2 / 3 · 換一題想想", @"3 / 3 · 換數字探索"][self.stageIndex];
    self.invitationLabel.text = @[@"先讀題目，再打開動畫，一次看一小步。", @"這題跟剛才有什麼一樣？先用手指或心裡想一想。想看提示時，再打開動畫。", @"數字變了，方法還一樣嗎？可以先想，再看；也可以換另一組數字。"][self.stageIndex];
    self.questionLabel.text = example.questionText; self.equationLabel.text = example.equationText; self.focusLabel.text = example.focusText;
    self.previousButton.enabled = self.stageIndex > 0;
    [self.nextButton setTitle:self.stageIndex == 2 ? @"回到學一學" : @"下一題" forState:UIControlStateNormal];
    self.nextButton.accessibilityHint = self.stageIndex == 2 ? @"離開探索，不會記錄為學會或增加星星。" : @"換到下一個探索問題。可以不看動畫，也可以再回來。";
    BOOL explore = self.stageIndex == 2; self.variationLabel.hidden = !explore; self.changeButton.hidden = !explore;
    self.variationLabel.text = [NSString stringWithFormat:@"探索數字 %lu / %lu，可以重複看。", (unsigned long)self.explorationIndex + 1, (unsigned long)self.path.explorationExamples.count];
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
- (void)close { if (self.presentedViewController || self.isBeingDismissed) return; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.navigation.axis = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) || self.scroll.bounds.size.width < 400 ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
}
@end
