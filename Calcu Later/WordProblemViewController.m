#import "WordProblemViewController.h"
#import "WordProblem.h"
#import "WordProblemGenerator.h"
#import "ArithmeticProblem.h"
#import "MultipleChoiceAnswerView.h"
#import "DistractorGenerator.h"
#import "AdditionHintView.h"
#import "SubtractionHintView.h"
#import "AnimatedHintView.h"
#import "DrawingCanvasView.h"
#import "ChildUIKit.h"
#import "SoundManager.h"
#import "SpeechManager.h"
#import "SettingsManager.h"
#import "DecorativeBackgroundView.h"
#import "MascotView.h"

@interface WordProblemViewController () <MultipleChoiceAnswerViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, assign) NSInteger grade;
@property (nonatomic, strong) WordProblem *currentProblem;
@property (nonatomic, copy, nullable) NSString *lastTemplateID;
@property (nonatomic, assign) NSInteger wrongStreakThisProblem;
@property (nonatomic, assign) NSInteger correctStreak;
@property (nonatomic, assign) CFAbsoluteTime lastWrongTapAt;  // 反垃圾連點
/// MCQ 已配置的 WordProblem（idempotency token）。避免 loadNextProblem 與
/// applyAnswerModeUI 兩個入口同題重複 configure；同時偵測「mode 切到 MCQ 但 MCQ 還停在前一題」。
@property (nonatomic, weak) WordProblem *mcqConfiguredProblem;

// Header
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *gradeBadge;
@property (nonatomic, strong) UILabel *streakLabel;
@property (nonatomic, strong) ChildButton *tutorialButton;

// Story + equation
@property (nonatomic, strong) UIView *storyCard;
@property (nonatomic, strong) UILabel *storyLabel;
@property (nonatomic, strong) UIButton *speakButton;       // 重讀題目
@property (nonatomic, strong) UILabel *equationLabel;
@property (nonatomic, strong) ChildButton *revealEquationButton;  // 「看算式」揭示鈕
/// 橫式算式是否已揭示（點過「看算式」或被強制揭示答案）。一開始隱藏。
@property (nonatomic, assign) BOOL equationRevealed;
/// 算式是否要連答案一起顯示（答錯 3 次 / 寫作模式「看答案」時為 YES）。
@property (nonatomic, assign) BOOL answerRevealed;

// Answer
@property (nonatomic, strong) MultipleChoiceAnswerView *mcq;
@property (nonatomic, strong) DrawingCanvasView *canvasView;
@property (nonatomic, strong) ChildButton *undoButton;
@property (nonatomic, strong) ChildButton *clearButton;
@property (nonatomic, strong) ChildButton *nextButton;
@property (nonatomic, strong) ChildButton *revealButton;

// Hint
@property (nonatomic, strong) UIView *hintHost;
@property (nonatomic, strong) AdditionHintView *additionHintView;
@property (nonatomic, strong) SubtractionHintView *subtractionHintView;
@property (nonatomic, strong) AnimatedHintView *animatedHintView;
@property (nonatomic, strong) UIView *textHintView;
@property (nonatomic, strong) UILabel *textHintLabel;

// Mascot
@property (nonatomic, strong) MascotView *mascot;
@end

@implementation WordProblemViewController

- (instancetype)initWithGrade:(NSInteger)grade {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _grade = MAX(1, MIN(3, grade));
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeLessons];
    [self setupUI];
    [self applyAnswerModeUI];
    [self loadNextProblem];
}

#pragma mark - UI

- (void)setupUI {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    self.closeButton.tintColor = ChildUI.brownText;
    self.closeButton.accessibilityLabel = @"離開練習";
    self.closeButton.accessibilityIdentifier = @"story.close";
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];

    self.gradeBadge = [[UILabel alloc] init];
    self.gradeBadge.text = [NSString stringWithFormat:@"%ld 年級", (long)self.grade];
    self.gradeBadge.font = [ChildUI roundedFontOfSize:18.0 weight:UIFontWeightSemibold];
    self.gradeBadge.textColor = ChildUI.brownText;
    self.gradeBadge.textAlignment = NSTextAlignmentCenter;
    self.gradeBadge.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.gradeBadge];

    self.streakLabel = [[UILabel alloc] init];
    self.streakLabel.font = [ChildUI roundedFontOfSize:16.0 weight:UIFontWeightSemibold];
    self.streakLabel.textColor = ChildUI.eggYolk;
    self.streakLabel.textAlignment = NSTextAlignmentCenter;
    self.streakLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.streakLabel];

    self.tutorialButton = [ChildButton buttonWithTitle:@"看怎麼算" backgroundColor:ChildUI.lavender];
    self.tutorialButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.tutorialButton.titleLabel.font = [ChildUI roundedFontOfSize:16.0 weight:UIFontWeightSemibold];
    [self.tutorialButton addTarget:self action:@selector(tutorialTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.tutorialButton];

    // 故事卡片
    self.storyCard = [[UIView alloc] init];
    self.storyCard.backgroundColor = ChildUI.creamBackground;
    self.storyCard.layer.cornerRadius = 24.0;
    [ChildUI applySoftShadowOnLayer:self.storyCard.layer];
    self.storyCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.storyCard];

    self.storyLabel = [[UILabel alloc] init];
    self.storyLabel.accessibilityIdentifier = @"story.text";
    self.storyLabel.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightMedium];
    self.storyLabel.textColor = ChildUI.brownText;
    self.storyLabel.numberOfLines = 0;
    // numberOfLines=0 與 adjustsFontSizeToFitWidth 行為矛盾，UIKit 對多行 + autoshrink
    // 行為不一致；維持多行換行即可，太長就讓 storyCard 撐高。
    self.storyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.storyCard addSubview:self.storyLabel];

    // 重讀題目（朗讀）：故事卡右上角喇叭鈕。新題會自動朗讀一次，此鈕用來重聽。
    self.speakButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.speakButton setImage:[UIImage systemImageNamed:@"speaker.wave.2.fill"] forState:UIControlStateNormal];
    self.speakButton.tintColor = ChildUI.pinkAccent;
    self.speakButton.accessibilityLabel = @"再讀一次題目";
    self.speakButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.speakButton addTarget:self action:@selector(speakStory) forControlEvents:UIControlEventTouchUpInside];
    [self.storyCard addSubview:self.speakButton];

    // 整張故事卡也可點來重讀（給孩子更大的點擊目標）。
    // delegate 讓點在卡內按鈕（喇叭鈕 / 看算式鈕）上的觸控交給按鈕本身，不觸發整卡重讀。
    UITapGestureRecognizer *cardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(speakStory)];
    cardTap.delegate = self;
    [self.storyCard addGestureRecognizer:cardTap];

    self.equationLabel = [[UILabel alloc] init];
    self.equationLabel.accessibilityIdentifier = @"story.equation";
    self.equationLabel.font = [ChildUI roundedMonoFontOfSize:30.0 weight:UIFontWeightBold];
    self.equationLabel.textColor = [ChildUI.brownText colorWithAlphaComponent:0.85];
    self.equationLabel.textAlignment = NSTextAlignmentCenter;
    self.equationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.equationLabel.hidden = YES;  // 一開始隱藏；保留版面高度，由「看算式」鈕揭示
    [self.storyCard addSubview:self.equationLabel];

    // 「看算式」揭示鈕：疊在 equationLabel 位置上，讓孩子明顯知道算式藏在哪。
    self.revealEquationButton = [ChildButton buttonWithTitle:@"🧮 看算式" backgroundColor:ChildUI.lavender];
    self.revealEquationButton.titleLabel.font = [ChildUI roundedFontOfSize:18.0 weight:UIFontWeightSemibold];
    self.revealEquationButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.revealEquationButton addTarget:self action:@selector(revealEquationTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.storyCard addSubview:self.revealEquationButton];

    // Hint host（疊在 mcq / 故事卡之上的中段區）
    self.hintHost = [[UIView alloc] init];
    self.hintHost.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hintHost];

    self.additionHintView = [[AdditionHintView alloc] initWithFrame:CGRectZero];
    self.additionHintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.additionHintView.hidden = YES;
    [self.hintHost addSubview:self.additionHintView];

    self.subtractionHintView = [[SubtractionHintView alloc] initWithFrame:CGRectZero];
    self.subtractionHintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtractionHintView.hidden = YES;
    [self.hintHost addSubview:self.subtractionHintView];

    self.animatedHintView = [[AnimatedHintView alloc] initWithFrame:CGRectZero];
    self.animatedHintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.animatedHintView.hidden = YES;
    [self.hintHost addSubview:self.animatedHintView];

    self.textHintView = [[UIView alloc] init];
    self.textHintView.backgroundColor = [UIColor colorWithRed:1.00 green:0.98 blue:0.94 alpha:1.0];
    self.textHintView.layer.cornerRadius = 24.0;
    self.textHintView.layer.masksToBounds = YES;
    self.textHintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textHintView.hidden = YES;
    [self.hintHost addSubview:self.textHintView];

    self.textHintLabel = [[UILabel alloc] init];
    self.textHintLabel.font = [ChildUI roundedMonoFontOfSize:26.0 weight:UIFontWeightSemibold];
    self.textHintLabel.textColor = ChildUI.brownText;
    self.textHintLabel.textAlignment = NSTextAlignmentCenter;
    self.textHintLabel.numberOfLines = 0;
    self.textHintLabel.adjustsFontSizeToFitWidth = YES;
    self.textHintLabel.minimumScaleFactor = 0.5;
    self.textHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.textHintView addSubview:self.textHintLabel];

    // MCQ
    self.mcq = [[MultipleChoiceAnswerView alloc] initWithFrame:CGRectZero];
    self.mcq.delegate = self;
    self.mcq.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mcq];

    // 手寫
    self.canvasView = [[DrawingCanvasView alloc] initWithFrame:CGRectZero];
    self.canvasView.layer.borderColor = [ChildUI.brownText colorWithAlphaComponent:0.15].CGColor;
    self.canvasView.layer.borderWidth = 2.0;
    self.canvasView.layer.cornerRadius = 24.0;
    self.canvasView.layer.masksToBounds = YES;
    self.canvasView.backgroundColor = [UIColor whiteColor];
    self.canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.canvasView];

    self.undoButton = [ChildButton buttonWithTitle:@"復原" backgroundColor:ChildUI.lavender];
    self.undoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.undoButton addTarget:self action:@selector(undoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.undoButton];

    self.clearButton = [ChildButton buttonWithTitle:@"清除" backgroundColor:ChildUI.pinkAccent];
    self.clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearButton addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearButton];

    self.nextButton = [ChildButton buttonWithTitle:@"下一題" backgroundColor:ChildUI.skyBlue];
    self.nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nextButton];

    self.revealButton = [ChildButton buttonWithTitle:@"看答案" backgroundColor:ChildUI.pumpkinOrange];
    self.revealButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.revealButton addTarget:self action:@selector(revealTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.revealButton];

    self.mascot = [[MascotView alloc] initWithVariant:MascotVariantPortrait];
    self.mascot.translatesAutoresizingMaskIntoConstraints = NO;
    self.mascot.hidden = !SettingsManager.sharedInstance.mascotEnabled;
    [self.view addSubview:self.mascot];

    [NSLayoutConstraint activateConstraints:@[
        [self.closeButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.closeButton.widthAnchor constraintEqualToConstant:36],
        [self.closeButton.heightAnchor constraintEqualToConstant:36],

        [self.gradeBadge.centerYAnchor constraintEqualToAnchor:self.closeButton.centerYAnchor],
        [self.gradeBadge.leadingAnchor constraintEqualToAnchor:self.closeButton.trailingAnchor constant:12],
        [self.gradeBadge.trailingAnchor constraintLessThanOrEqualToAnchor:self.streakLabel.leadingAnchor constant:-8],

        [self.streakLabel.centerYAnchor constraintEqualToAnchor:self.closeButton.centerYAnchor],
        [self.streakLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.streakLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.tutorialButton.leadingAnchor constant:-8],

        [self.tutorialButton.centerYAnchor constraintEqualToAnchor:self.closeButton.centerYAnchor],
        [self.tutorialButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.tutorialButton.heightAnchor constraintEqualToConstant:40],
        [self.tutorialButton.widthAnchor constraintEqualToConstant:110],

        [self.storyCard.topAnchor constraintEqualToAnchor:self.closeButton.bottomAnchor constant:14],
        [self.storyCard.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.storyCard.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],

        [self.speakButton.topAnchor constraintEqualToAnchor:self.storyCard.topAnchor constant:12],
        [self.speakButton.trailingAnchor constraintEqualToAnchor:self.storyCard.trailingAnchor constant:-14],
        [self.speakButton.widthAnchor constraintEqualToConstant:44],
        [self.speakButton.heightAnchor constraintEqualToConstant:44],

        [self.storyLabel.topAnchor constraintEqualToAnchor:self.storyCard.topAnchor constant:18],
        [self.storyLabel.leadingAnchor constraintEqualToAnchor:self.storyCard.leadingAnchor constant:18],
        // trailing 讓開右上角喇叭鈕，避免題目文字壓到鈕
        [self.storyLabel.trailingAnchor constraintEqualToAnchor:self.speakButton.leadingAnchor constant:-6],

        [self.equationLabel.topAnchor constraintEqualToAnchor:self.storyLabel.bottomAnchor constant:10],
        [self.equationLabel.leadingAnchor constraintEqualToAnchor:self.storyCard.leadingAnchor constant:18],
        [self.equationLabel.trailingAnchor constraintEqualToAnchor:self.storyCard.trailingAnchor constant:-18],
        [self.equationLabel.bottomAnchor constraintEqualToAnchor:self.storyCard.bottomAnchor constant:-16],

        // 「看算式」鈕疊在 equationLabel 中央（equationLabel 隱藏時仍保留高度撐住卡片）
        [self.revealEquationButton.centerXAnchor constraintEqualToAnchor:self.equationLabel.centerXAnchor],
        [self.revealEquationButton.centerYAnchor constraintEqualToAnchor:self.equationLabel.centerYAnchor],
        [self.revealEquationButton.heightAnchor constraintEqualToConstant:44],
        [self.revealEquationButton.widthAnchor constraintGreaterThanOrEqualToConstant:160],

        // Hint host 介於故事卡與 MCQ 之間
        [self.hintHost.topAnchor constraintEqualToAnchor:self.storyCard.bottomAnchor constant:12],
        [self.hintHost.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.hintHost.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.hintHost.bottomAnchor constraintEqualToAnchor:self.mcq.topAnchor constant:-12],

        [self.additionHintView.topAnchor constraintEqualToAnchor:self.hintHost.topAnchor],
        [self.additionHintView.leadingAnchor constraintEqualToAnchor:self.hintHost.leadingAnchor],
        [self.additionHintView.trailingAnchor constraintEqualToAnchor:self.hintHost.trailingAnchor],
        [self.additionHintView.bottomAnchor constraintEqualToAnchor:self.hintHost.bottomAnchor],
        [self.subtractionHintView.topAnchor constraintEqualToAnchor:self.hintHost.topAnchor],
        [self.subtractionHintView.leadingAnchor constraintEqualToAnchor:self.hintHost.leadingAnchor],
        [self.subtractionHintView.trailingAnchor constraintEqualToAnchor:self.hintHost.trailingAnchor],
        [self.subtractionHintView.bottomAnchor constraintEqualToAnchor:self.hintHost.bottomAnchor],
        [self.animatedHintView.topAnchor constraintEqualToAnchor:self.hintHost.topAnchor],
        [self.animatedHintView.leadingAnchor constraintEqualToAnchor:self.hintHost.leadingAnchor],
        [self.animatedHintView.trailingAnchor constraintEqualToAnchor:self.hintHost.trailingAnchor],
        [self.animatedHintView.bottomAnchor constraintEqualToAnchor:self.hintHost.bottomAnchor],
        [self.textHintView.topAnchor constraintEqualToAnchor:self.hintHost.topAnchor],
        [self.textHintView.leadingAnchor constraintEqualToAnchor:self.hintHost.leadingAnchor],
        [self.textHintView.trailingAnchor constraintEqualToAnchor:self.hintHost.trailingAnchor],
        [self.textHintView.bottomAnchor constraintEqualToAnchor:self.hintHost.bottomAnchor],
        [self.textHintLabel.centerXAnchor constraintEqualToAnchor:self.textHintView.centerXAnchor],
        [self.textHintLabel.centerYAnchor constraintEqualToAnchor:self.textHintView.centerYAnchor],
        [self.textHintLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.textHintView.leadingAnchor constant:20],
        [self.textHintLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.textHintView.trailingAnchor constant:-20],

        // MCQ 區
        [self.mcq.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.mcq.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.mcq.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
        [self.mcq.heightAnchor constraintEqualToConstant:240],

        // 手寫畫板（重用 mcq 區域，加上按鈕列）
        [self.canvasView.topAnchor constraintEqualToAnchor:self.hintHost.topAnchor],
        [self.canvasView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.canvasView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.canvasView.bottomAnchor constraintEqualToAnchor:self.nextButton.topAnchor constant:-12],

        [self.undoButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.undoButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
        [self.undoButton.heightAnchor constraintEqualToConstant:52],
        [self.undoButton.widthAnchor constraintEqualToConstant:100],

        [self.clearButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.clearButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
        [self.clearButton.heightAnchor constraintEqualToConstant:52],
        [self.clearButton.widthAnchor constraintEqualToConstant:100],

        [self.nextButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.nextButton.bottomAnchor constraintEqualToAnchor:self.undoButton.topAnchor constant:-10],
        [self.nextButton.heightAnchor constraintEqualToConstant:48],
        [self.nextButton.widthAnchor constraintEqualToConstant:100],

        [self.revealButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.revealButton.bottomAnchor constraintEqualToAnchor:self.clearButton.topAnchor constant:-10],
        [self.revealButton.heightAnchor constraintEqualToConstant:48],
        [self.revealButton.widthAnchor constraintEqualToConstant:100],

        [self.mascot.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.mascot.bottomAnchor constraintEqualToAnchor:self.mcq.topAnchor constant:-4],
        [self.mascot.widthAnchor constraintEqualToConstant:64],
        [self.mascot.heightAnchor constraintEqualToConstant:64],
    ]];
}

- (void)applyAnswerModeUI {
    BOOL mcqMode = SettingsManager.sharedInstance.answerMode == AnswerModeMultipleChoice;
    self.mcq.hidden = !mcqMode;
    self.canvasView.hidden = mcqMode;
    self.undoButton.hidden = mcqMode;
    self.clearButton.hidden = mcqMode;
    self.nextButton.hidden = mcqMode;
    self.revealButton.hidden = mcqMode;
    // 「看怎麼算」按鈕是 MCQ 模式專屬：寫作模式有自己的「看答案」按鈕做答案揭示，
    // 而且 tutorial 觸發的 hint view 會被 canvas 蓋住（hintHost 在 canvas 之下），
    // 所以在寫作模式直接隱藏避免按了沒反應的死動作。
    self.tutorialButton.hidden = !mcqMode;
    [self updateMascotVisibility];
    // 切到 MCQ 且當前題目存在時，必須重新配置選項：
    // 否則「MCQ → 切去寫字 → 寫字模式按下一題 → 切回 MCQ」的路徑下
    // mcq 按鈕仍停留在前一題的 titles，與 storyLabel / equationLabel 不一致。
    // 用「已配置過的 WordProblem 物件指標」當作 idempotency token，避免：
    //   (a) 同題重複 configure 在 reveal 鎖按鈕期把 disabled 還原成 enabled
    //   (b) 切換答題模式時 MCQ 卡在上一題
    if (mcqMode && self.currentProblem
        && self.mcqConfiguredProblem != self.currentProblem) {
        [self configureMCQForCurrentProblem];
    }
}

/// 把當前題目套用到 MCQ（依分數題 / 標準題分支）。把已配置的 WordProblem 物件存起來
/// 作為 idempotency token，避免重複配置（loadNextProblem 與 applyAnswerModeUI 兩個入口）。
- (void)configureMCQForCurrentProblem {
    if (!self.currentProblem) return;
    if (self.currentProblem.isFractionAnswer) {
        NSInteger correctIdx = 0;
        NSArray<NSString *> *titles = [DistractorGenerator
            fractionChoicesForNumerator:self.currentProblem.answerNumerator
                            denominator:self.currentProblem.answerDenominator
                        outCorrectIndex:&correctIdx];
        [self.mcq configureWithChoiceTitles:titles correctIndex:correctIdx];
    } else {
        [self.mcq configureWithProblem:[self.currentProblem toArithmeticProblem]];
    }
    self.mcqConfiguredProblem = self.currentProblem;
}

#pragma mark - Flow

- (void)loadNextProblem {
    [[SpeechManager sharedInstance] stop];  // 停掉前一題未讀完的朗讀
    [self hideAllHintViews];
    [self.canvasView clearCanvas];
    self.wrongStreakThisProblem = 0;
    self.lastWrongTapAt = 0;

    self.currentProblem = [WordProblemGenerator generateForGrade:self.grade
                                              excludingTemplate:self.lastTemplateID];
    self.lastTemplateID = self.currentProblem.templateID;

    self.storyLabel.text = self.currentProblem.storyText;

    // 橫式算式回到「隱藏」狀態，由「看算式」鈕揭示。
    self.equationRevealed = NO;
    self.answerRevealed = NO;
    [self refreshEquationViews];

    if (SettingsManager.sharedInstance.answerMode == AnswerModeMultipleChoice) {
        [self configureMCQForCurrentProblem];
    }
    [self updateMascotVisibility];

    // 入場彈跳
    self.storyCard.transform = CGAffineTransformMakeScale(0.94, 0.94);
    self.storyCard.alpha = 0.7;
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0.5
                        options:0 animations:^{
        self.storyCard.transform = CGAffineTransformIdentity;
        self.storyCard.alpha = 1.0;
    } completion:nil];

    // 自動朗讀新題目；尊重「音效開關」（重讀鈕則為使用者明確操作，不受此限）。
    if (SettingsManager.sharedInstance.soundEffectsEnabled) {
        [self speakStory];
    }
}

- (NSString *)displayOperator:(NSString *)op {
    // 內部存 "-"，顯示用 "−"（U+2212，較粗）
    return [op isEqualToString:@"-"] ? @"−" : op;
}

- (void)updateStreakLabel {
    self.streakLabel.text = self.correctStreak > 0
        ? [NSString stringWithFormat:@"連對 ×%ld 🔥", (long)self.correctStreak]
        : @"";
}

#pragma mark - Story speech (朗讀)

/// 朗讀目前題目。重讀鈕與整張卡片點擊都走這裡。
///
/// 註：曾做過「逐字高亮」（willSpeakRangeOfSpeechString:），但在 app 偏好的
/// Enhanced/Premium 中文嗓音下，邊界回呼時機無法緊貼實際播放位置（語音分段預合成 +
/// 緩衝播放），高亮會明顯落後朗讀，故移除。只保留單純朗讀。
- (void)speakStory {
    NSString *story = self.currentProblem.storyText;
    if (story.length == 0) return;
    [[SpeechManager sharedInstance] speak:story];
}

/// 點在卡內的按鈕（UIControl）上時，不要觸發整卡重讀，讓按鈕自己處理。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    return ![touch.view isKindOfClass:[UIControl class]];
}

#pragma mark - Equation reveal (橫式算式揭示)

/// 依 equationRevealed / answerRevealed 狀態同步「算式文字」與「看算式鈕」的顯隱。
- (void)refreshEquationViews {
    self.equationLabel.text = [self equationTextRevealingAnswer:self.answerRevealed];
    self.equationLabel.hidden = !self.equationRevealed;
    self.revealEquationButton.hidden = self.equationRevealed;
}

/// 點「看算式」：揭示橫式算式（仍以 "?" 隱藏答案），帶一個彈跳回饋。
- (void)revealEquationTapped {
    if (!self.currentProblem || self.equationRevealed) return;
    self.equationRevealed = YES;
    [self refreshEquationViews];

    self.equationLabel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    self.equationLabel.alpha = 0.0;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0.5
                        options:0 animations:^{
        self.equationLabel.transform = CGAffineTransformIdentity;
        self.equationLabel.alpha = 1.0;
    } completion:nil];
}

/// 強制揭示答案（答錯 3 次 / 寫作模式「看答案」）：連同算式一起顯示，並關閉揭示鈕。
- (void)revealAnswerInEquation {
    self.answerRevealed = YES;
    self.equationRevealed = YES;
    [self refreshEquationViews];
}

#pragma mark - MCQ delegate

- (void)mcqView:(MultipleChoiceAnswerView *)view didChoose:(NSInteger)choiceValue result:(MCQResult)result {
    if (result == MCQResultCorrect) {
        self.correctStreak++;
        [self updateStreakLabel];
        // 5 連對播 Cheer 音效時 mascot 也要做 Cheering 動作，避免聲音/動畫不一致。
        MascotEmotion e = (self.correctStreak > 0 && self.correctStreak % 5 == 0)
            ? MascotEmotionCheering : MascotEmotionHappy;
        [self.mascot setEmotion:e];
        SoundEffect fx = (self.correctStreak > 0 && self.correctStreak % 5 == 0) ? SoundEffectCheer : SoundEffectCorrect;
        [[SoundManager sharedInstance] play:fx];
        [self.mcq disableAllChoices];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.view.window == nil) return;  // VC 已 dismiss 就不做事
            [strongSelf loadNextProblem];
        });
        return;
    }
    // 反垃圾連點：兩次錯答之間至少 0.5s，避免小孩亂連點直接跳過
    // 「第 1 次只搖頭」的溫和階段。判斷時間差，不動 mcq 自身視覺狀態。
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (self.lastWrongTapAt > 0 && (now - self.lastWrongTapAt) < 0.5) {
        return;
    }
    self.lastWrongTapAt = now;

    self.correctStreak = 0;
    [self updateStreakLabel];
    [self.mascot setEmotion:MascotEmotionShake];
    [[SoundManager sharedInstance] play:SoundEffectWrong];

    self.wrongStreakThisProblem++;
    if (self.wrongStreakThisProblem == 1) return;
    if (self.wrongStreakThisProblem == 2) {
        [self showHintAnimated:YES];
        return;
    }
    // 第 3 次以上：揭示答案 + 下一題（包含單位）
    // == 3 才觸發 reveal-and-advance；後續 wrong tap 直接忽略，避免重複 schedule
    // dispatch_after 造成多個 loadNextProblem 競態（會「跳過題目」）。
    if (self.wrongStreakThisProblem > 3) return;
    [self showHintAnimated:YES];
    [self revealAnswerInEquation];
    [self.mcq disableAllChoices];  // 與 ViewController / LessonViewController 對齊：
                                   // reveal 期間鎖按鈕，避免使用者再點到剩下的選項時，
                                   // MCQResultCorrect 路徑又 schedule 一個 0.85s loadNextProblem
                                   // 與這裡的 2.6s 同時 fire，產生「兩個下一題」race。
    __weak typeof(self) weakSelf2 = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf2) strongSelf2 = weakSelf2;
        if (!strongSelf2 || strongSelf2.view.window == nil) return;
        [strongSelf2 loadNextProblem];
    });
}

#pragma mark - Hints

- (void)tutorialTapped {
    if (!self.currentProblem) return;
    BOOL showing = !self.additionHintView.hidden
                || !self.subtractionHintView.hidden
                || !self.animatedHintView.hidden
                || !self.textHintView.hidden;
    if (showing) {
        [self hideAllHintViews];
        return;
    }
    [self showHintAnimated:YES];
}

- (void)showHintAnimated:(BOOL)animated {
    if (!self.currentProblem) return;
    [self hideAllHintViews];

    // 二步驟題不能套單步驟的視覺化 hint（會只顯示第一步算法、誤導），
    // 統一改走 textHint 並把兩步驟拆給孩子看。
    if (self.currentProblem.operator2) {
        [self showTextHintForTwoStep:self.currentProblem];
        return;
    }

    // 分數題：沒有算式可以動畫化；用 textHint 解釋「平分 b 份取 a 份」的概念。
    if (self.currentProblem.isFractionAnswer) {
        WordProblem *p = self.currentProblem;
        self.textHintLabel.text = [NSString stringWithFormat:
                                   @"把整個東西平分成 %ld 份\n其中 %ld 份就是 %ld/%ld",
                                   (long)p.answerDenominator,
                                   (long)p.answerNumerator,
                                   (long)p.answerNumerator,
                                   (long)p.answerDenominator];
        self.textHintView.hidden = NO;
        [self updateMascotVisibility];
        return;
    }

    // 未知數三變體：AnimatedHintView 會動畫出「內部算式」(例如 missingAddend 的 a−b)
    // 並把答案顯示出來——對 tutorial 主動點擊而言等於直接揭示答案。
    // 改走 textHint 給「策略提示」而不是直接算出答案。
    if (self.currentProblem.missingAddend
        || self.currentProblem.missingSubtrahend
        || self.currentProblem.missingMinuend) {
        [self showTextHintForMissing:self.currentProblem];
        return;
    }

    ArithmeticProblem *p = [self.currentProblem toArithmeticProblem];
    NSString *op = p.operatorSymbol;
    BOOL isAdd = [op isEqualToString:@"+"];
    BOOL isSub = [op isEqualToString:@"-"];

    if (animated && (isAdd || isSub)) {
        self.animatedHintView.hidden = NO;
        [self.animatedHintView configureWithProblem:p];
    } else if (isAdd) {
        BOOL ok = [self.additionHintView configureWithProblem:p];
        self.additionHintView.hidden = !ok;
        if (!ok) [self showTextHintForProblem:p];
    } else if (isSub) {
        BOOL ok = [self.subtractionHintView configureWithProblem:p];
        self.subtractionHintView.hidden = !ok;
        if (!ok) [self showTextHintForProblem:p];
    } else {
        [self showTextHintForProblem:p];
    }
    [self updateMascotVisibility];
}

/// 未知數三變體 textHint：給策略提示，不直接算出答案（避免主動點 tutorial 等於揭示答案）。
- (void)showTextHintForMissing:(WordProblem *)wp {
    NSString *body;
    if (wp.missingAddend) {
        // ? + n2 = n1：策略是「從總和拿走已知加數」
        body = [NSString stringWithFormat:
                @"想一想：要把幾加上 %ld 才會變成 %ld？\n（試試 %ld − %ld 是多少）",
                (long)wp.number2, (long)wp.number1,
                (long)wp.number1, (long)wp.number2];
    } else if (wp.missingSubtrahend) {
        // n1 − ? = n2：策略是「從總量拿走剩下，就是被拿走的部分」
        body = [NSString stringWithFormat:
                @"想一想：從 %ld 拿走幾個會剩 %ld？\n（試試 %ld − %ld 是多少）",
                (long)wp.number1, (long)wp.number2,
                (long)wp.number1, (long)wp.number2];
    } else {
        // missingMinuend: ? − n1 = n2：策略是「把剩下的和拿走的加回去」
        body = [NSString stringWithFormat:
                @"想一想：拿掉 %ld 後剩 %ld，原本要有幾個？\n（試試 %ld + %ld 是多少）",
                (long)wp.number1, (long)wp.number2,
                (long)wp.number1, (long)wp.number2];
    }
    self.textHintLabel.text = body;
    self.textHintView.hidden = NO;
    [self updateMascotVisibility];
}

/// 二步驟 textHint：把兩步驟拆成兩行顯示，幫孩子建立「先算第一步、再算第二步」的拆解習慣。
- (void)showTextHintForTwoStep:(WordProblem *)wp {
    NSString *op1 = [self displayOperator:wp.operatorSymbol];
    NSString *op2 = [self displayOperator:wp.operator2];
    NSString *body = [NSString stringWithFormat:
                      @"第一步：%ld %@ %ld = %ld\n第二步：%ld %@ %ld = %ld",
                      (long)wp.number1, op1, (long)wp.number2, (long)wp.intermediate,
                      (long)wp.intermediate, op2, (long)wp.number3, (long)wp.answer];
    self.textHintLabel.text = body;
    self.textHintView.hidden = NO;
    [self updateMascotVisibility];
}

- (void)showTextHintForProblem:(ArithmeticProblem *)problem {
    NSString *op = problem.operatorSymbol;
    NSString *body;
    if ([op isEqualToString:@"×"]) {
        NSInteger n = problem.number2;
        NSInteger m = problem.number1;
        if (n >= 1 && n <= 6) {
            NSMutableArray *parts = [NSMutableArray array];
            for (NSInteger i = 0; i < n; i++) [parts addObject:[NSString stringWithFormat:@"%ld", (long)m]];
            body = [NSString stringWithFormat:@"%ld × %ld\n= %@\n= %ld",
                    (long)m, (long)n, [parts componentsJoinedByString:@" + "], (long)problem.answer];
        } else {
            body = [NSString stringWithFormat:@"%ld × %ld = %ld",
                    (long)m, (long)n, (long)problem.answer];
        }
    } else if ([op isEqualToString:@"÷"]) {
        body = [NSString stringWithFormat:@"%ld ÷ %ld = %ld\n（%ld × %ld = %ld）",
                (long)problem.number1, (long)problem.number2, (long)problem.answer,
                (long)problem.answer, (long)problem.number2, (long)problem.number1];
    } else {
        body = [NSString stringWithFormat:@"%ld %@ %ld = %ld",
                (long)problem.number1, [self displayOperator:op], (long)problem.number2, (long)problem.answer];
    }
    self.textHintLabel.text = body;
    self.textHintView.hidden = NO;
    [self updateMascotVisibility];
}

- (void)hideAllHintViews {
    self.additionHintView.hidden = YES;
    self.subtractionHintView.hidden = YES;
    self.animatedHintView.hidden = YES;
    self.textHintView.hidden = YES;
    [self updateMascotVisibility];
}

/// MCQ 模式下 hintHost 與 mascot 共用底部空間，hint 顯示時把 mascot 讓開避免
/// 蓋住直式答案 row。寫作模式下 mascot 也讓開避免疊在 canvas 上方。
- (void)updateMascotVisibility {
    BOOL mascotEnabled = SettingsManager.sharedInstance.mascotEnabled;
    BOOL mcqMode = SettingsManager.sharedInstance.answerMode == AnswerModeMultipleChoice;
    BOOL hintShowing = !self.additionHintView.hidden
                    || !self.subtractionHintView.hidden
                    || !self.animatedHintView.hidden
                    || !self.textHintView.hidden;
    // 寫作模式 mascot 會疊在 canvas 上擋小孩寫字 → 寫作模式直接收起。
    self.mascot.hidden = !mascotEnabled || !mcqMode || hintShowing;
}

/// 把目前題目轉成「a OP b = ans 單位」字串。
/// revealing=NO 時不顯示答案（用 "?"），revealing=YES 顯示完整答案 + 單位。
///
/// 特殊渲染：
///   - missingAddend：渲染為「? + b = a」（內部 op 是 "-"，但等式呈現為加法）
///   - missingSubtrahend：渲染為「a − ? = b」
///   - 有餘數除法：揭示時渲染為「a ÷ b = q⋯r 單位」
///   - 二步驟：渲染為「a op1 b op2 c = ?」
- (NSString *)equationTextRevealingAnswer:(BOOL)reveal {
    if (!self.currentProblem) return @"";
    WordProblem *p = self.currentProblem;
    NSString *unit = p.unit ?: @"";

    if (p.isFractionAnswer) {
        // 分數識別題沒有運算式；equation 面板就顯示答案。
        if (!reveal) return @"答案：?";
        return [NSString stringWithFormat:@"答案：%ld/%ld",
                (long)p.answerNumerator, (long)p.answerDenominator];
    }

    if (p.operator2) {
        // 二步驟：a op1 b op2 c = ?
        NSString *op1 = [self displayOperator:p.operatorSymbol];
        NSString *op2 = [self displayOperator:p.operator2];
        if (!reveal) {
            return [NSString stringWithFormat:@"%ld %@ %ld %@ %ld = ?",
                    (long)p.number1, op1, (long)p.number2, op2, (long)p.number3];
        }
        return [NSString stringWithFormat:@"%ld %@ %ld %@ %ld = %ld %@",
                (long)p.number1, op1, (long)p.number2, op2, (long)p.number3,
                (long)p.answer, unit];
    }

    if (p.missingAddend) {
        // 等式以加法呈現：「? + number2 = number1」，即使內部 op 為 "-"
        // 顯示 unit 在最後（與標準格式一致），避免「8 顆 + 5 = 13」這種混淆語意。
        if (!reveal) {
            return [NSString stringWithFormat:@"? + %ld = %ld",
                    (long)p.number2, (long)p.number1];
        }
        return [NSString stringWithFormat:@"%ld + %ld = %ld %@",
                (long)p.answer, (long)p.number2, (long)p.number1, unit];
    }

    if (p.missingSubtrahend) {
        // 「number1 − ? = number2」，內部 op 為 "-"，answer = number1 - number2
        NSString *op = [self displayOperator:p.operatorSymbol];
        if (!reveal) {
            return [NSString stringWithFormat:@"%ld %@ ? = %ld",
                    (long)p.number1, op, (long)p.number2];
        }
        return [NSString stringWithFormat:@"%ld %@ %ld = %ld %@",
                (long)p.number1, op, (long)p.answer, (long)p.number2, unit];
    }

    if (p.missingMinuend) {
        // 等式以減法呈現：「? − number1 = number2」，內部 op 為 "+"，answer = number1 + number2
        if (!reveal) {
            return [NSString stringWithFormat:@"? − %ld = %ld",
                    (long)p.number1, (long)p.number2];
        }
        return [NSString stringWithFormat:@"%ld − %ld = %ld %@",
                (long)p.answer, (long)p.number1, (long)p.number2, unit];
    }

    NSString *op = [self displayOperator:p.operatorSymbol];
    if (!reveal) {
        return [NSString stringWithFormat:@"%ld %@ %ld = ?",
                (long)p.number1, op, (long)p.number2];
    }
    if (p.remainder > 0) {
        // 有餘數除法：a ÷ b = q [unit]⋯r
        // unit 屬於商（每隊/每包/每盤），餘數的單位與商不同（剩下的人/糖），
        // 因此把 unit 緊貼在商後面、不要落在 r 旁邊以免語意混淆。
        // 空 unit 時退化成 "a ÷ b = q⋯r"。
        if (unit.length > 0) {
            return [NSString stringWithFormat:@"%ld %@ %ld = %ld %@⋯%ld",
                    (long)p.number1, op, (long)p.number2,
                    (long)p.answer, unit, (long)p.remainder];
        }
        return [NSString stringWithFormat:@"%ld %@ %ld = %ld⋯%ld",
                (long)p.number1, op, (long)p.number2,
                (long)p.answer, (long)p.remainder];
    }
    return [NSString stringWithFormat:@"%ld %@ %ld = %ld %@",
            (long)p.number1, op, (long)p.number2, (long)p.answer, unit];
}

#pragma mark - Writing mode controls

- (void)undoTapped { [self.canvasView undoLastStroke]; }
- (void)clearTapped { [self.canvasView clearCanvas]; }
- (void)nextTapped { [self loadNextProblem]; }
/// 寫作模式「看答案」：只把答案寫到 equationLabel（含單位）。
/// 不觸發 hintHost 內的 hint view，避免被 canvas 蓋住的死動作。
- (void)revealTapped {
    if (!self.currentProblem) return;
    [self revealAnswerInEquation];
}

#pragma mark - Nav

- (void)closeTapped {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyAnswerModeUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[SpeechManager sharedInstance] stop];  // 離開畫面就停止朗讀，避免關掉後還在講話
}

@end
