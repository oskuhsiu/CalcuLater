//
//  ViewController.m
//  Calcu Later — Drill 區（刷題）
//

#import "ViewController.h"
#import "DrawingCanvasView.h"
#import "AdditionHintView.h"
#import "SubtractionHintView.h"
#import "AnimatedHintView.h"
#import "MultipleChoiceAnswerView.h"
#import "ArithmeticProblem.h"
#import "ProblemGenerator.h"
#import "SettingsManager.h"
#import "ChildUIKit.h"
#import "SettingsViewController.h"
#import "SoundManager.h"
#import "MascotView.h"
#import "DecorativeBackgroundView.h"

@interface ViewController () <MultipleChoiceAnswerViewDelegate>

// Header
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) MascotView *mascot;
@property (nonatomic, strong) UILabel *streakLabel;

// Question
@property (nonatomic, strong) UILabel *problemLabel;
@property (nonatomic, strong) UILabel *answerLabel;

// Buttons
@property (nonatomic, strong) ChildButton *nextProblemButton;
@property (nonatomic, strong) ChildButton *hintButton;

// Answer surfaces
@property (nonatomic, strong) MultipleChoiceAnswerView *mcq;
@property (nonatomic, strong) DrawingCanvasView *canvasView;
@property (nonatomic, strong) ChildButton *undoButton;
@property (nonatomic, strong) ChildButton *clearButton;

// Hints
@property (nonatomic, strong) UIView *hintHost;
@property (nonatomic, strong) AdditionHintView *additionHintView;
@property (nonatomic, strong) SubtractionHintView *subtractionHintView;
@property (nonatomic, strong) AnimatedHintView *animatedHintView;
// 乘 / 除沒有直式 hint view，用一塊文字背景顯示答案與分解（重複加 / 重複減）。
@property (nonatomic, strong) UIView *textHintView;
@property (nonatomic, strong) UILabel *textHintLabel;
@property (nonatomic, assign) NSInteger currentHintType;  // 0=none, 1=static, 2=animated

// State
@property (nonatomic, strong) ArithmeticProblem *currentProblem;
@property (nonatomic, assign) NSInteger correctStreak;
@property (nonatomic, assign) NSInteger wrongStreakThisProblem;

// Mascot 兩組 layout（依答題模式切換）
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *mascotMCQConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *mascotWritingConstraints;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeDrill];
    [self setupUI];
    [self applyAnswerModeUI];
    [self generateNewProblem];
}

#pragma mark - Layout

- (void)setupUI {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    // 關閉
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    self.closeButton.tintColor = ChildUI.brownText;
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];

    // 設定
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.settingsButton setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
    self.settingsButton.tintColor = ChildUI.brownText;
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.settingsButton];

    self.mascot = [[MascotView alloc] initWithVariant:MascotVariantPortrait];
    self.mascot.translatesAutoresizingMaskIntoConstraints = NO;
    self.mascot.hidden = !SettingsManager.sharedInstance.mascotEnabled;
    [self.view addSubview:self.mascot];

    // streak
    self.streakLabel = [[UILabel alloc] init];
    self.streakLabel.font = [ChildUI roundedFontOfSize:18.0 weight:UIFontWeightSemibold];
    self.streakLabel.textColor = ChildUI.eggYolk;
    self.streakLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.streakLabel];

    // 題目
    self.problemLabel = [[UILabel alloc] init];
    self.problemLabel.font = [ChildUI roundedMonoFontOfSize:60.0 weight:UIFontWeightBold];
    self.problemLabel.textColor = ChildUI.brownText;
    self.problemLabel.textAlignment = NSTextAlignmentCenter;
    self.problemLabel.adjustsFontSizeToFitWidth = YES;
    self.problemLabel.minimumScaleFactor = 0.5;
    self.problemLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.problemLabel];

    self.answerLabel = [[UILabel alloc] init];
    self.answerLabel.font = [ChildUI roundedMonoFontOfSize:24.0 weight:UIFontWeightRegular];
    self.answerLabel.textColor = [ChildUI.brownText colorWithAlphaComponent:0.4];
    self.answerLabel.textAlignment = NSTextAlignmentCenter;
    self.answerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.answerLabel];

    // Hint host
    self.hintHost = [[UIView alloc] init];
    self.hintHost.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hintHost];

    self.canvasView = [[DrawingCanvasView alloc] initWithFrame:CGRectZero];
    self.canvasView.layer.borderColor = [ChildUI.brownText colorWithAlphaComponent:0.15].CGColor;
    self.canvasView.layer.borderWidth = 2.0;
    self.canvasView.layer.cornerRadius = 24.0;
    self.canvasView.layer.masksToBounds = YES;
    self.canvasView.backgroundColor = [UIColor whiteColor];
    self.canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.hintHost addSubview:self.canvasView];

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

    // 乘 / 除的文字 hint：奶油底卡片 + 大字結果 + 分解算式。
    self.textHintView = [[UIView alloc] init];
    self.textHintView.backgroundColor = [UIColor colorWithRed:1.00 green:0.98 blue:0.94 alpha:1.0];
    self.textHintView.layer.cornerRadius = 24.0;
    self.textHintView.layer.masksToBounds = YES;
    self.textHintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textHintView.hidden = YES;
    [self.hintHost addSubview:self.textHintView];

    self.textHintLabel = [[UILabel alloc] init];
    self.textHintLabel.font = [ChildUI roundedMonoFontOfSize:28.0 weight:UIFontWeightSemibold];
    self.textHintLabel.textColor = ChildUI.brownText;
    self.textHintLabel.textAlignment = NSTextAlignmentCenter;
    self.textHintLabel.numberOfLines = 0;
    self.textHintLabel.adjustsFontSizeToFitWidth = YES;
    self.textHintLabel.minimumScaleFactor = 0.5;
    self.textHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.textHintView addSubview:self.textHintLabel];

    self.mcq = [[MultipleChoiceAnswerView alloc] initWithFrame:CGRectZero];
    self.mcq.delegate = self;
    self.mcq.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mcq];

    // 動作按鈕（手寫模式可見）
    self.nextProblemButton = [ChildButton buttonWithTitle:@"新題" backgroundColor:ChildUI.skyBlue];
    self.nextProblemButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.nextProblemButton addTarget:self action:@selector(newProblemTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nextProblemButton];

    self.hintButton = [ChildButton buttonWithTitle:@"提示" backgroundColor:ChildUI.pumpkinOrange];
    self.hintButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.hintButton addTarget:self action:@selector(hintTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.hintButton];

    self.undoButton = [ChildButton buttonWithTitle:@"復原" backgroundColor:ChildUI.lavender];
    self.undoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.undoButton addTarget:self action:@selector(undoTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.undoButton];

    self.clearButton = [ChildButton buttonWithTitle:@"清除" backgroundColor:ChildUI.pinkAccent];
    self.clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearButton addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.clearButton];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.closeButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.closeButton.widthAnchor constraintEqualToConstant:36],
        [self.closeButton.heightAnchor constraintEqualToConstant:36],

        [self.settingsButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.settingsButton.widthAnchor constraintEqualToConstant:36],
        [self.settingsButton.heightAnchor constraintEqualToConstant:36],

        [self.streakLabel.centerYAnchor constraintEqualToAnchor:self.closeButton.centerYAnchor],
        [self.streakLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

        [self.problemLabel.topAnchor constraintEqualToAnchor:self.closeButton.bottomAnchor constant:16],
        [self.problemLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.problemLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.problemLabel.heightAnchor constraintEqualToConstant:74],

        // answerLabel 已永遠隱藏（applyAnswerModeUI），高度收成 0、不撐出空白；
        // hintHost 直接 anchor 到 problemLabel.bottom，避免 36pt 縫吃掉小螢幕 hint 區。
        [self.answerLabel.topAnchor constraintEqualToAnchor:self.problemLabel.bottomAnchor constant:0],
        [self.answerLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.answerLabel.heightAnchor constraintEqualToConstant:0],

        [self.hintHost.topAnchor constraintEqualToAnchor:self.problemLabel.bottomAnchor constant:12],
        [self.hintHost.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.hintHost.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.hintHost.bottomAnchor constraintEqualToAnchor:self.mcq.topAnchor constant:-16],

        [self.canvasView.topAnchor constraintEqualToAnchor:self.hintHost.topAnchor],
        [self.canvasView.leadingAnchor constraintEqualToAnchor:self.hintHost.leadingAnchor],
        [self.canvasView.trailingAnchor constraintEqualToAnchor:self.hintHost.trailingAnchor],
        [self.canvasView.bottomAnchor constraintEqualToAnchor:self.hintHost.bottomAnchor],

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

        // MCQ 區（選擇題模式時顯示在底部）
        [self.mcq.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.mcq.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.mcq.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
        [self.mcq.heightAnchor constraintEqualToConstant:260],

        // 手寫模式的下方按鈕（重用 mcq 的位置）
        [self.undoButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.undoButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
        [self.undoButton.heightAnchor constraintEqualToConstant:56],
        [self.undoButton.widthAnchor constraintEqualToConstant:120],

        [self.clearButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.clearButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
        [self.clearButton.heightAnchor constraintEqualToConstant:56],
        [self.clearButton.widthAnchor constraintEqualToConstant:120],

        [self.nextProblemButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.nextProblemButton.bottomAnchor constraintEqualToAnchor:self.undoButton.topAnchor constant:-12],
        [self.nextProblemButton.heightAnchor constraintEqualToConstant:48],
        [self.nextProblemButton.widthAnchor constraintEqualToConstant:120],

        [self.hintButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.hintButton.bottomAnchor constraintEqualToAnchor:self.clearButton.topAnchor constant:-12],
        [self.hintButton.heightAnchor constraintEqualToConstant:48],
        [self.hintButton.widthAnchor constraintEqualToConstant:120],
    ]];

    // Mascot 兩組 layout：MCQ 模式 → 居中於 hintHost；手寫模式 → 塞在按鈕中間欄
    NSLayoutConstraint *mcqW = [self.mascot.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.30];
    mcqW.priority = UILayoutPriorityDefaultHigh;
    self.mascotMCQConstraints = @[
        [self.mascot.centerXAnchor constraintEqualToAnchor:self.hintHost.centerXAnchor],
        [self.mascot.centerYAnchor constraintEqualToAnchor:self.hintHost.centerYAnchor],
        mcqW,
        [self.mascot.widthAnchor constraintLessThanOrEqualToConstant:180],
        [self.mascot.widthAnchor constraintGreaterThanOrEqualToConstant:110],
        [self.mascot.heightAnchor constraintEqualToAnchor:self.mascot.widthAnchor],
    ];
    self.mascotWritingConstraints = @[
        [self.mascot.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.mascot.topAnchor constraintEqualToAnchor:self.nextProblemButton.topAnchor],
        [self.mascot.bottomAnchor constraintEqualToAnchor:self.clearButton.bottomAnchor],
        [self.mascot.widthAnchor constraintEqualToAnchor:self.mascot.heightAnchor],
    ];
    // idle 浮動由 MascotView 自帶
}

- (void)applyAnswerModeUI {
    BOOL mcqMode = SettingsManager.sharedInstance.answerMode == AnswerModeMultipleChoice;
    self.mcq.hidden = !mcqMode;
    self.canvasView.hidden = mcqMode;
    self.undoButton.hidden = mcqMode;
    self.clearButton.hidden = mcqMode;
    self.nextProblemButton.hidden = mcqMode;
    self.hintButton.hidden = mcqMode;
    // 答案 label 永遠隱藏，避免手寫模式洩漏答案；要看答案請按提示。
    self.answerLabel.hidden = YES;

    // 從手寫切回 MCQ 時，mcq 在當前題目下從未被 configure（generateNewProblem 跳過了），
    // 需要在此補配置；不然 4 個選項按鈕會沒有文字或停留在舊題。
    if (mcqMode && self.currentProblem) {
        [self.mcq configureWithProblem:self.currentProblem];
    }

    // Mascot 位置依模式切換
    [NSLayoutConstraint deactivateConstraints:self.mascotMCQConstraints];
    [NSLayoutConstraint deactivateConstraints:self.mascotWritingConstraints];
    [NSLayoutConstraint activateConstraints:mcqMode ? self.mascotMCQConstraints : self.mascotWritingConstraints];
    [self updateMascotVisibility];
}

- (void)updateMascotVisibility {
    BOOL mcqMode = SettingsManager.sharedInstance.answerMode == AnswerModeMultipleChoice;
    BOOL hintShowing = !self.additionHintView.hidden
                    || !self.subtractionHintView.hidden
                    || !self.animatedHintView.hidden
                    || !self.textHintView.hidden;
    BOOL mascotEnabled = SettingsManager.sharedInstance.mascotEnabled;
    // MCQ 模式 mascot 與 hint 共用中央空間 → hint 顯示時讓出位置
    self.mascot.hidden = !mascotEnabled || (mcqMode && hintShowing);
}

#pragma mark - Game flow

- (void)generateNewProblem {
    SettingsManager *s = SettingsManager.sharedInstance;
    DrillTier tier = (DrillTier)MAX(1, MIN(4, (int)s.drillTier));
    self.currentProblem = [ProblemGenerator generateForTier:tier
                                              allowAddition:s.operationAddition
                                           allowSubtraction:s.operationSubtraction
                                        allowMultiplication:s.operationMultiplication
                                              allowDivision:s.operationDivision];

    self.problemLabel.text = [NSString stringWithFormat:@"%ld %@ %ld = ?",
                              (long)self.currentProblem.number1,
                              self.currentProblem.operatorSymbol,
                              (long)self.currentProblem.number2];
    self.answerLabel.text = [NSString stringWithFormat:@"= %ld", (long)self.currentProblem.answer];

    self.wrongStreakThisProblem = 0;
    [self hideAllHintViews];
    self.currentHintType = 0;
    [self.canvasView clearCanvas];

    if (!self.mcq.hidden) {
        [self.mcq configureWithProblem:self.currentProblem];
    }

    self.problemLabel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [UIView animateWithDuration:0.32 delay:0
          usingSpringWithDamping:0.5 initialSpringVelocity:0.5 options:0 animations:^{
        self.problemLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - MCQ delegate

- (void)mcqView:(MultipleChoiceAnswerView *)view didChoose:(NSInteger)choiceValue result:(MCQResult)result {
    if (result == MCQResultCorrect) {
        self.correctStreak++;
        [self updateStreakLabel];
        [self bounceMascot];
        SoundEffect fx = (self.correctStreak > 0 && self.correctStreak % 5 == 0) ? SoundEffectCheer : SoundEffectCorrect;
        [[SoundManager sharedInstance] play:fx];
        // 鎖住按鈕直到下一題出現，避免 0.85s 內連點重複觸發 delegate。
        [self.mcq disableAllChoices];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self generateNewProblem];
        });
        return;
    }
    self.correctStreak = 0;
    [self updateStreakLabel];
    [self shakeMascot];
    [[SoundManager sharedInstance] play:SoundEffectWrong];

    self.wrongStreakThisProblem++;
    if (self.wrongStreakThisProblem == 1) {
        return;
    }
    if (self.wrongStreakThisProblem == 2) {
        [self showStaticHint];
        return;
    }
    // 第 3 次：揭示
    self.problemLabel.text = [NSString stringWithFormat:@"%ld %@ %ld = %ld",
                              (long)self.currentProblem.number1,
                              self.currentProblem.operatorSymbol,
                              (long)self.currentProblem.number2,
                              (long)self.currentProblem.answer];
    [self showStaticHint];
    // 揭示答案後鎖按鈕，避免 2.4s 內連點再次進 delegate 把已揭示的題目跳掉。
    [self.mcq disableAllChoices];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self generateNewProblem];
    });
}

- (void)updateStreakLabel {
    if (self.correctStreak <= 0) {
        self.streakLabel.text = @"";
    } else {
        self.streakLabel.text = [NSString stringWithFormat:@"連對 ×%ld 🔥", (long)self.correctStreak];
    }
}

- (void)bounceMascot {
    MascotEmotion e = (self.correctStreak > 0 && self.correctStreak % 5 == 0)
        ? MascotEmotionCheering : MascotEmotionHappy;
    [self.mascot setEmotion:e];
}

- (void)shakeMascot {
    [self.mascot setEmotion:MascotEmotionShake];
}

#pragma mark - Hints

- (void)newProblemTapped { [self generateNewProblem]; }
- (void)hintTapped { [self cycleHint]; }

- (void)showStaticHint {
    // 選擇題模式錯 2 次時自動呼叫
    [self hideAllHintViews];
    [self showHintForProblem:self.currentProblem useAnimated:NO];
}

- (void)cycleHint {
    if (!self.currentProblem) return;
    [self hideAllHintViews];
    self.currentHintType = (self.currentHintType + 1) % 3;
    switch (self.currentHintType) {
        case 1:
            [self showHintForProblem:self.currentProblem useAnimated:NO];
            break;
        case 2:
            [self showHintForProblem:self.currentProblem useAnimated:YES];
            break;
        default:
            break;
    }
}

- (void)showHintForProblem:(ArithmeticProblem *)problem useAnimated:(BOOL)animated {
    BOOL isAdd = [problem.operatorSymbol isEqualToString:@"+"];
    BOOL isSub = [problem.operatorSymbol isEqualToString:@"-"];
    if (animated && (isAdd || isSub)) {
        self.animatedHintView.hidden = NO;
        [self.animatedHintView configureWithProblem:problem];
    } else if (isAdd) {
        BOOL ok = [self.additionHintView configureWithProblem:problem];
        self.additionHintView.hidden = !ok;
        if (!ok) [self showTextHintForProblem:problem];
    } else if (isSub) {
        BOOL ok = [self.subtractionHintView configureWithProblem:problem];
        self.subtractionHintView.hidden = !ok;
        if (!ok) [self showTextHintForProblem:problem];
    } else {
        // 乘 / 除（或其他未覆蓋的運算符）：用文字 hint 顯示分解算式與答案，
        // 避免 writing 模式整個 session 看不到任何提示。
        [self showTextHintForProblem:problem];
    }
    [self updateMascotVisibility];
}

- (void)showTextHintForProblem:(ArithmeticProblem *)problem {
    NSString *op = problem.operatorSymbol;
    NSString *body;
    if ([op isEqualToString:@"×"]) {
        // N 個 M 相加（小數字才展開，否則只給算式 + 答案，避免太長）。
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
                (long)problem.number1, op, (long)problem.number2, (long)problem.answer];
    }
    self.textHintLabel.text = body;
    self.textHintView.hidden = NO;
}

- (void)hideAllHintViews {
    self.additionHintView.hidden = YES;
    self.subtractionHintView.hidden = YES;
    self.animatedHintView.hidden = YES;
    self.textHintView.hidden = YES;
    [self updateMascotVisibility];
}

- (void)undoTapped { [self.canvasView undoLastStroke]; }
- (void)clearTapped { [self.canvasView clearCanvas]; }

#pragma mark - Nav

- (void)closeTapped {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)settingsTapped {
    SettingsViewController *vc = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyAnswerModeUI];
    [[SoundManager sharedInstance] prepare];
}

@end
