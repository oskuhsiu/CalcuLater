#import "LessonViewController.h"
#import "Lesson.h"
#import "ArithmeticProblem.h"
#import "MultipleChoiceAnswerView.h"
#import "ChildUIKit.h"
#import "MakeBreakTenHintView.h"
#import "AdditionHintView.h"
#import "SubtractionHintView.h"
#import "LessonProgressStore.h"
#import "SoundManager.h"
#import "LessonIntroView.h"
#import "DecorativeBackgroundView.h"

@interface LessonViewController () <MultipleChoiceAnswerViewDelegate, LessonIntroViewDelegate>
@property (nonatomic, strong) Lesson *lesson;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UILabel *problemLabel;
@property (nonatomic, strong) MultipleChoiceAnswerView *mcq;
@property (nonatomic, strong) UIView *hintContainer;
@property (nonatomic, strong) UIView *currentHintView;
@property (nonatomic, strong) UIView *resultOverlay;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) ChildButton *tutorialButton;
@property (nonatomic, strong) LessonIntroView *introView;
@property (nonatomic, strong) ArithmeticProblem *currentProblem;
@property (nonatomic, assign) NSInteger questionIndex;
@property (nonatomic, assign) NSInteger correctCount;
@property (nonatomic, assign) NSInteger wrongStreak;  // 本題答錯次數
@end

@implementation LessonViewController

- (instancetype)initWithLesson:(Lesson *)lesson {
    self = [super init];
    if (self) {
        _lesson = lesson;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeLessons];

    [self setupUI];
    if ([self shouldShowIntro]) {
        [self showIntro];
    } else {
        [self loadNextQuestion];
    }
}

- (BOOL)shouldShowIntro {
    switch (self.lesson.kind) {
        case LessonKindAddSimple:
        case LessonKindSubSimple:
        case LessonKindMakeTen:
        case LessonKindBreakTen:
            return YES;
        case LessonKindMultiplication:
            return NO;
    }
    return NO;
}

- (void)showIntro {
    self.introView = [[LessonIntroView alloc] initWithLesson:self.lesson];
    self.introView.delegate = self;
    self.introView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.introView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.introView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [self.introView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.introView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.introView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-20],
    ]];

    // 隱藏底下題目 UI
    self.problemLabel.hidden = YES;
    self.progressLabel.hidden = YES;
    self.mcq.hidden = YES;
    self.tutorialButton.hidden = YES;

    [self.view layoutIfNeeded];
    [self.introView play];
}

- (void)lessonIntroDidFinish:(LessonIntroView *)introView {
    [UIView animateWithDuration:0.3 animations:^{
        introView.alpha = 0;
    } completion:^(BOOL finished) {
        [introView removeFromSuperview];
        self.introView = nil;
        self.problemLabel.hidden = NO;
        self.progressLabel.hidden = NO;
        self.mcq.hidden = NO;
        self.tutorialButton.hidden = NO;
        [self loadNextQuestion];
    }];
}

- (void)setupUI {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    self.closeButton.tintColor = ChildUI.brownText;
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];

    // 「看怎麼算」按鈕：主動觸發 hint，孩子答錯前就能參考教學
    self.tutorialButton = [ChildButton buttonWithTitle:@"看怎麼算" backgroundColor:ChildUI.lavender];
    self.tutorialButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.tutorialButton.titleLabel.font = [ChildUI roundedFontOfSize:18.0 weight:UIFontWeightSemibold];
    [self.tutorialButton addTarget:self action:@selector(tutorialTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.tutorialButton];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = self.lesson.title;
    self.titleLabel.font = [ChildUI roundedFontOfSize:24.0 weight:UIFontWeightBold];
    self.titleLabel.textColor = ChildUI.brownText;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.7;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.titleLabel];

    self.progressLabel = [[UILabel alloc] init];
    self.progressLabel.font = [ChildUI roundedFontOfSize:18.0 weight:UIFontWeightMedium];
    self.progressLabel.textColor = [ChildUI.brownText colorWithAlphaComponent:0.7];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.progressLabel];

    self.problemLabel = [[UILabel alloc] init];
    self.problemLabel.font = [ChildUI roundedMonoFontOfSize:64.0 weight:UIFontWeightBold];
    self.problemLabel.textColor = ChildUI.brownText;
    self.problemLabel.textAlignment = NSTextAlignmentCenter;
    self.problemLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.problemLabel];

    self.hintContainer = [[UIView alloc] init];
    self.hintContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.hintContainer.hidden = YES;
    [self.view addSubview:self.hintContainer];

    self.mcq = [[MultipleChoiceAnswerView alloc] initWithFrame:CGRectZero];
    self.mcq.delegate = self;
    self.mcq.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mcq];

    [NSLayoutConstraint activateConstraints:@[
        [self.closeButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.closeButton.widthAnchor constraintEqualToConstant:36],
        [self.closeButton.heightAnchor constraintEqualToConstant:36],

        [self.tutorialButton.centerYAnchor constraintEqualToAnchor:self.closeButton.centerYAnchor],
        [self.tutorialButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.tutorialButton.heightAnchor constraintEqualToConstant:40],
        [self.tutorialButton.widthAnchor constraintEqualToConstant:120],

        [self.titleLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14],
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        // 防止課程標題撞上「看怎麼算」按鈕 / 關閉按鈕，遇到長標題會 adjustsFontSizeToFitWidth。
        [self.titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.closeButton.trailingAnchor constant:8],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.tutorialButton.leadingAnchor constant:-8],

        [self.progressLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:6],
        [self.progressLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

        [self.problemLabel.topAnchor constraintEqualToAnchor:self.progressLabel.bottomAnchor constant:24],
        [self.problemLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.problemLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.problemLabel.heightAnchor constraintEqualToConstant:80],

        [self.hintContainer.topAnchor constraintEqualToAnchor:self.problemLabel.bottomAnchor constant:12],
        [self.hintContainer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.hintContainer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.hintContainer.bottomAnchor constraintEqualToAnchor:self.mcq.topAnchor constant:-16],

        [self.mcq.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [self.mcq.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [self.mcq.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-24],
        [self.mcq.heightAnchor constraintEqualToConstant:280],
    ]];
}

#pragma mark - Flow

- (void)loadNextQuestion {
    [self clearHint];
    self.wrongStreak = 0;
    if (self.questionIndex >= self.lesson.questionCount) {
        [self showCompletion];
        return;
    }
    self.currentProblem = [self.lesson generateProblem];
    self.problemLabel.text = [NSString stringWithFormat:@"%ld %@ %ld = ?",
                              (long)self.currentProblem.number1,
                              self.currentProblem.operatorSymbol,
                              (long)self.currentProblem.number2];
    self.progressLabel.text = [NSString stringWithFormat:@"第 %ld / %ld 題",
                               (long)(self.questionIndex + 1), (long)self.lesson.questionCount];
    [self.mcq configureWithProblem:self.currentProblem];

    // 答題前的入場彈跳
    self.problemLabel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5
                        options:0 animations:^{
        self.problemLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)mcqView:(MultipleChoiceAnswerView *)view didChoose:(NSInteger)choiceValue result:(MCQResult)result {
    if (result == MCQResultCorrect) {
        self.correctCount++;
        self.questionIndex++;
        [[SoundManager sharedInstance] play:SoundEffectCorrect];
        // 鎖住按鈕直到下一題載入，否則 0.85s 內被連點會讓 questionIndex 多加、跳題。
        [self.mcq disableAllChoices];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.view.window == nil) return;
            [strongSelf loadNextQuestion];
        });
        return;
    }

    self.wrongStreak++;
    [self shakeProblemLabel];
    [[SoundManager sharedInstance] play:SoundEffectWrong];
    if (self.wrongStreak == 1) {
        // 鼓勵，不顯示 hint
        return;
    }
    if (self.wrongStreak == 2) {
        [self showHintForCurrentProblem];
        return;
    }
    // 三次錯：揭示答案 + 跳下一題
    self.problemLabel.text = [NSString stringWithFormat:@"%ld %@ %ld = %ld",
                              (long)self.currentProblem.number1,
                              self.currentProblem.operatorSymbol,
                              (long)self.currentProblem.number2,
                              (long)self.currentProblem.answer];
    [self showHintForCurrentProblem];
    self.questionIndex++;
    [self.mcq disableAllChoices];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.view.window == nil) return;
        [strongSelf loadNextQuestion];
    });
}

- (void)showHintForCurrentProblem {
    [self clearHint];
    UIView *hv = [self buildHintViewForProblem:self.currentProblem];
    if (!hv) return;
    hv.translatesAutoresizingMaskIntoConstraints = NO;
    hv.alpha = 0;
    [self.hintContainer addSubview:hv];
    [NSLayoutConstraint activateConstraints:@[
        [hv.topAnchor constraintEqualToAnchor:self.hintContainer.topAnchor],
        [hv.leadingAnchor constraintEqualToAnchor:self.hintContainer.leadingAnchor],
        [hv.trailingAnchor constraintEqualToAnchor:self.hintContainer.trailingAnchor],
        [hv.bottomAnchor constraintEqualToAnchor:self.hintContainer.bottomAnchor],
    ]];
    self.hintContainer.hidden = NO;
    self.currentHintView = hv;
    [UIView animateWithDuration:0.35 animations:^{ hv.alpha = 1.0; }];
}

- (UIView *)buildHintViewForProblem:(ArithmeticProblem *)p {
    switch (self.lesson.kind) {
        case LessonKindMakeTen: {
            MakeBreakTenHintView *v = [[MakeBreakTenHintView alloc] initWithFrame:CGRectZero
                                                                              mode:MakeBreakTenModeMakeTen];
            if ([v configureWithProblem:p]) return v;
            return nil;
        }
        case LessonKindBreakTen: {
            MakeBreakTenHintView *v = [[MakeBreakTenHintView alloc] initWithFrame:CGRectZero
                                                                              mode:MakeBreakTenModeBreakTen];
            if ([v configureWithProblem:p]) return v;
            return nil;
        }
        case LessonKindMultiplication: {
            // 對乘法用文字 hint：「N 個 M 相加」
            UILabel *l = [[UILabel alloc] init];
            l.font = [ChildUI roundedFontOfSize:26.0 weight:UIFontWeightMedium];
            l.textColor = ChildUI.brownText;
            l.textAlignment = NSTextAlignmentCenter;
            l.numberOfLines = 0;
            l.text = [NSString stringWithFormat:@"%ld 個 %ld 加起來：\n%@",
                      (long)p.number2, (long)p.number1,
                      [self repeatedAddText:p.number1 times:p.number2 result:p.answer]];
            UIView *bg = [[UIView alloc] init];
            bg.backgroundColor = ChildUI.creamBackground;
            bg.layer.cornerRadius = 24.0;
            bg.layer.masksToBounds = YES;
            l.translatesAutoresizingMaskIntoConstraints = NO;
            [bg addSubview:l];
            [NSLayoutConstraint activateConstraints:@[
                [l.centerXAnchor constraintEqualToAnchor:bg.centerXAnchor],
                [l.centerYAnchor constraintEqualToAnchor:bg.centerYAnchor],
                [l.leadingAnchor constraintGreaterThanOrEqualToAnchor:bg.leadingAnchor constant:16],
                [l.trailingAnchor constraintLessThanOrEqualToAnchor:bg.trailingAnchor constant:-16],
            ]];
            return bg;
        }
        case LessonKindAddSimple:
        case LessonKindSubSimple: {
            // 用圓點具象呈現
            return [self buildDotsHintForProblem:p];
        }
    }
    return nil;
}

- (NSString *)repeatedAddText:(NSInteger)n times:(NSInteger)t result:(NSInteger)r {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSInteger i = 0; i < t; i++) [parts addObject:[NSString stringWithFormat:@"%ld", (long)n]];
    return [NSString stringWithFormat:@"%@ = %ld", [parts componentsJoinedByString:@" + "], (long)r];
}

- (UIView *)buildDotsHintForProblem:(ArithmeticProblem *)p {
    UIView *bg = [[UIView alloc] init];
    bg.backgroundColor = ChildUI.creamBackground;
    bg.layer.cornerRadius = 24.0;
    bg.layer.masksToBounds = YES;

    BOOL isSubtraction = [p.operatorSymbol isEqualToString:@"-"];

    // 圖示池：兒童友善的具象 SF Symbol，左右兩運算元用不同種類 + 配色。
    NSArray<NSString *> *iconPool = @[
        @"apple.logo", @"leaf.fill", @"star.fill", @"heart.fill",
        @"fish.fill", @"bird.fill", @"tortoise.fill", @"ladybug.fill"
    ];
    // 用 problem 內容作種子，讓同一題的圖示穩定不會跳。
    NSUInteger seed = (NSUInteger)(p.number1 * 31 + p.number2 * 7 + (isSubtraction ? 13 : 0));
    NSString *iconA = iconPool[seed % iconPool.count];
    NSString *iconB = iconPool[(seed / iconPool.count + 1) % iconPool.count];
    UIColor *colorA = [ChildUI candyColorAtIndex:(NSInteger)(seed % 6)];
    UIColor *colorB = [ChildUI candyColorAtIndex:(NSInteger)((seed + 2) % 6)];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [bg addSubview:stack];

    if (isSubtraction) {
        // 第一列：N1 個圖示，最後 N2 個畫上斜線 + 半透明，表示「拿走」。
        UIStackView *row1 = [self _iconRowCount:p.number1 iconName:iconA color:colorA
                                  strikeoutLast:p.number2];
        [stack addArrangedSubview:row1];

        UILabel *opLabel = [[UILabel alloc] init];
        opLabel.text = [NSString stringWithFormat:@"拿走 %ld 個", (long)p.number2];
        opLabel.font = [ChildUI roundedFontOfSize:20.0 weight:UIFontWeightMedium];
        opLabel.textColor = [ChildUI.brownText colorWithAlphaComponent:0.7];
        [stack addArrangedSubview:opLabel];
    } else {
        UIStackView *row1 = [self _iconRowCount:p.number1 iconName:iconA color:colorA
                                  strikeoutLast:0];
        [stack addArrangedSubview:row1];

        UIStackView *row2 = [[UIStackView alloc] init];
        row2.axis = UILayoutConstraintAxisHorizontal;
        row2.alignment = UIStackViewAlignmentCenter;
        row2.spacing = 8.0;
        UILabel *plus = [[UILabel alloc] init];
        plus.text = @"+";
        plus.font = [ChildUI roundedFontOfSize:30.0 weight:UIFontWeightBold];
        plus.textColor = ChildUI.brownText;
        [row2 addArrangedSubview:plus];
        UIStackView *icons2 = [self _iconRowCount:p.number2 iconName:iconB color:colorB
                                    strikeoutLast:0];
        [row2 addArrangedSubview:icons2];
        [stack addArrangedSubview:row2];
    }

    UILabel *ans = [[UILabel alloc] init];
    ans.text = [NSString stringWithFormat:@"= %ld", (long)p.answer];
    ans.font = [ChildUI roundedMonoFontOfSize:34.0 weight:UIFontWeightBold];
    ans.textColor = ChildUI.brownText;
    [stack addArrangedSubview:ans];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:bg.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:bg.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:bg.leadingAnchor constant:16],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:bg.trailingAnchor constant:-16],
        [stack.topAnchor constraintGreaterThanOrEqualToAnchor:bg.topAnchor constant:12],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:bg.bottomAnchor constant:-12],
    ]];
    return bg;
}

- (UIStackView *)_iconRowCount:(NSInteger)count iconName:(NSString *)name
                          color:(UIColor *)color strikeoutLast:(NSInteger)strikeCount {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 4.0;

    // 數量多時自動縮小，避免一列塞不下（L1 max 5、L2/L3 max 10）。
    CGFloat iconSize = (count <= 5) ? 32.0 : (count <= 8 ? 26.0 : 22.0);
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:iconSize
                                                                                      weight:UIImageSymbolWeightSemibold];

    for (NSInteger i = 0; i < count; i++) {
        BOOL crossed = (strikeCount > 0) && (i >= count - strikeCount);
        UIImage *img = [UIImage systemImageNamed:name withConfiguration:cfg];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.tintColor = crossed ? [color colorWithAlphaComponent:0.35] : color;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        if (crossed) {
            // 紅色斜線標示「拿走」。
            CAShapeLayer *line = [CAShapeLayer layer];
            line.strokeColor = [UIColor colorWithRed:0.85 green:0.20 blue:0.30 alpha:0.85].CGColor;
            line.lineWidth = 3.0;
            line.lineCap = kCALineCapRound;
            UIBezierPath *path = [UIBezierPath bezierPath];
            CGFloat s = iconSize + 4;
            [path moveToPoint:CGPointMake(2, s - 2)];
            [path addLineToPoint:CGPointMake(s - 2, 2)];
            line.path = path.CGPath;
            iv.layer.masksToBounds = NO;
            [iv.layer addSublayer:line];
            iv.frame = CGRectMake(0, 0, s, s);
        }
        [row addArrangedSubview:iv];
    }
    return row;
}

- (void)clearHint {
    for (UIView *v in [self.hintContainer.subviews copy]) [v removeFromSuperview];
    self.currentHintView = nil;
    self.hintContainer.hidden = YES;
}

- (void)shakeProblemLabel {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    CGFloat x = self.problemLabel.center.x;
    shake.values = @[ @(x), @(x - 10), @(x + 10), @(x - 6), @(x + 6), @(x) ];
    shake.duration = 0.45;
    [self.problemLabel.layer addAnimation:shake forKey:@"shake"];
}

- (void)showCompletion {
    [[LessonProgressStore sharedInstance] recordLessonID:self.lesson.lessonID
                                                  correct:self.correctCount
                                                    outOf:self.lesson.questionCount];
    self.problemLabel.hidden = YES;
    self.mcq.hidden = YES;
    self.hintContainer.hidden = YES;
    self.tutorialButton.hidden = YES;

    self.resultOverlay = [[UIView alloc] init];
    self.resultOverlay.backgroundColor = ChildUI.creamBackground;
    self.resultOverlay.layer.cornerRadius = 32.0;
    [ChildUI applySoftShadowOnLayer:self.resultOverlay.layer];
    self.resultOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.resultOverlay];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"做得好！";
    title.font = [ChildUI roundedFontOfSize:34.0 weight:UIFontWeightBold];
    title.textColor = ChildUI.brownText;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultOverlay addSubview:title];

    NSInteger stars = [[LessonProgressStore sharedInstance] starsForLessonID:self.lesson.lessonID];
    NSMutableString *starStr = [NSMutableString string];
    for (NSInteger i = 0; i < 3; i++) [starStr appendString:i < stars ? @"★" : @"☆"];
    UILabel *starLabel = [[UILabel alloc] init];
    starLabel.text = starStr;
    starLabel.font = [ChildUI roundedFontOfSize:64.0 weight:UIFontWeightBold];
    starLabel.textColor = ChildUI.eggYolk;
    starLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultOverlay addSubview:starLabel];

    UILabel *score = [[UILabel alloc] init];
    score.text = [NSString stringWithFormat:@"答對 %ld / %ld", (long)self.correctCount, (long)self.lesson.questionCount];
    score.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightMedium];
    score.textColor = ChildUI.brownText;
    score.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultOverlay addSubview:score];

    ChildButton *finishBtn = [ChildButton buttonWithTitle:@"回到課程" backgroundColor:ChildUI.skyBlue];
    finishBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [finishBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.resultOverlay addSubview:finishBtn];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.resultOverlay.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [self.resultOverlay.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [self.resultOverlay.widthAnchor constraintEqualToConstant:300],
        [self.resultOverlay.heightAnchor constraintEqualToConstant:340],

        [title.topAnchor constraintEqualToAnchor:self.resultOverlay.topAnchor constant:32],
        [title.centerXAnchor constraintEqualToAnchor:self.resultOverlay.centerXAnchor],

        [starLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:24],
        [starLabel.centerXAnchor constraintEqualToAnchor:self.resultOverlay.centerXAnchor],

        [score.topAnchor constraintEqualToAnchor:starLabel.bottomAnchor constant:20],
        [score.centerXAnchor constraintEqualToAnchor:self.resultOverlay.centerXAnchor],

        [finishBtn.bottomAnchor constraintEqualToAnchor:self.resultOverlay.bottomAnchor constant:-24],
        [finishBtn.centerXAnchor constraintEqualToAnchor:self.resultOverlay.centerXAnchor],
        [finishBtn.widthAnchor constraintEqualToConstant:200],
        [finishBtn.heightAnchor constraintEqualToConstant:56],
    ]];

    self.resultOverlay.alpha = 0;
    self.resultOverlay.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0.5
                        options:0 animations:^{
        self.resultOverlay.alpha = 1.0;
        self.resultOverlay.transform = CGAffineTransformIdentity;
    } completion:nil];
    [[SoundManager sharedInstance] play:SoundEffectCheer];
}

- (void)closeTapped {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

/// 「看怎麼算」：主動觸發目前題目的 hint；再按一次收起。
- (void)tutorialTapped {
    if (!self.currentProblem) return;
    if (!self.hintContainer.hidden) {
        [self clearHint];
        return;
    }
    [self showHintForCurrentProblem];
}

@end
