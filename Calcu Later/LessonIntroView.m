#import "LessonIntroView.h"
#import "Lesson.h"
#import "ChildUIKit.h"
#import "SoundManager.h"

@interface LessonIntroView ()
@property (nonatomic, strong) Lesson *lesson;

@property (nonatomic, strong) UILabel *headerLabel;     // 「先看示範～」
@property (nonatomic, strong) UILabel *problemLabel;    // 大字題目
@property (nonatomic, strong) UIView *stage;            // 視覺區
@property (nonatomic, strong) UILabel *narration;       // 旁白
@property (nonatomic, strong) ChildButton *replayButton;
@property (nonatomic, strong) ChildButton *startButton;

@property (nonatomic, assign) NSInteger demoSerial;     // 每次 play 加 1，用來作廢上一次的 timer callback
@property (nonatomic, assign) NSInteger layoutRetryCount; // 當 stage.bounds 為 0 時的重試次數上限
@end

static const NSInteger kIntroLayoutMaxRetries = 10;  // 0.05s * 10 = 0.5s，逾期就放棄示範動畫

@implementation LessonIntroView

#pragma mark - Init

- (instancetype)initWithLesson:(Lesson *)lesson {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _lesson = lesson;
        self.backgroundColor = ChildUI.creamBackground;
        self.layer.cornerRadius = 28.0;
        [ChildUI applySoftShadowOnLayer:self.layer];
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = @"先看老師示範一次～";
    self.headerLabel.font = [ChildUI roundedFontOfSize:20.0 weight:UIFontWeightSemibold];
    self.headerLabel.textColor = [ChildUI.brownText colorWithAlphaComponent:0.7];
    self.headerLabel.textAlignment = NSTextAlignmentCenter;
    self.headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.headerLabel];

    self.problemLabel = [[UILabel alloc] init];
    self.problemLabel.font = [ChildUI roundedMonoFontOfSize:56.0 weight:UIFontWeightBold];
    self.problemLabel.textColor = ChildUI.brownText;
    self.problemLabel.textAlignment = NSTextAlignmentCenter;
    self.problemLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.problemLabel];

    self.stage = [[UIView alloc] init];
    self.stage.translatesAutoresizingMaskIntoConstraints = NO;
    self.stage.clipsToBounds = NO;
    [self addSubview:self.stage];

    self.narration = [[UILabel alloc] init];
    self.narration.font = [ChildUI roundedFontOfSize:20.0 weight:UIFontWeightMedium];
    self.narration.textColor = ChildUI.brownText;
    self.narration.textAlignment = NSTextAlignmentCenter;
    self.narration.numberOfLines = 2;
    self.narration.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.narration];

    self.replayButton = [ChildButton buttonWithTitle:@"再看一次" backgroundColor:ChildUI.lavender];
    self.replayButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.replayButton addTarget:self action:@selector(replayTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.replayButton];

    self.startButton = [ChildButton buttonWithTitle:@"開始練習" backgroundColor:ChildUI.mintGreen];
    self.startButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.startButton addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.startButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:20],
        [self.headerLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],

        [self.problemLabel.topAnchor constraintEqualToAnchor:self.headerLabel.bottomAnchor constant:8],
        [self.problemLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
        [self.problemLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [self.problemLabel.heightAnchor constraintEqualToConstant:68],

        [self.stage.topAnchor constraintEqualToAnchor:self.problemLabel.bottomAnchor constant:12],
        [self.stage.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
        [self.stage.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [self.stage.bottomAnchor constraintEqualToAnchor:self.narration.topAnchor constant:-12],

        [self.narration.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
        [self.narration.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [self.narration.bottomAnchor constraintEqualToAnchor:self.replayButton.topAnchor constant:-16],
        [self.narration.heightAnchor constraintEqualToConstant:56],

        [self.replayButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
        [self.replayButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20],
        [self.replayButton.heightAnchor constraintEqualToConstant:56],
        [self.replayButton.widthAnchor constraintEqualToConstant:130],

        [self.startButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [self.startButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20],
        [self.startButton.heightAnchor constraintEqualToConstant:56],
        [self.startButton.widthAnchor constraintEqualToConstant:160],
    ]];
}

#pragma mark - Buttons

- (void)startTapped {
    // 鎖死兩個按鈕：introView 淡出有 0.3s，這段期間不能再點到 startTapped / replayTapped，
    // 否則 delegate 會被呼叫兩次（→ loadNextQuestion 跑兩次、problemLabel 入場動畫疊兩條、
    // mcq 重 configure → 選項順序亂跳）。
    self.startButton.enabled = NO;
    self.replayButton.enabled = NO;
    self.demoSerial++;  // 作廢 pending callbacks
    [self.delegate lessonIntroDidFinish:self];
}

- (void)replayTapped {
    [self play];
}

#pragma mark - Play

- (void)play {
    self.demoSerial++;
    self.layoutRetryCount = 0;
    NSInteger serial = self.demoSerial;

    // 清空 stage 與旁白
    for (UIView *v in [self.stage.subviews copy]) [v removeFromSuperview];
    self.narration.text = @"";
    self.narration.alpha = 0;

    switch (self.lesson.kind) {
        case LessonKindAddSimple: {
            BOOL isL1 = [self.lesson.lessonID isEqualToString:@"L1"];
            [self playAddSimpleWithSerial:serial a:isL1 ? 2 : 4 b:isL1 ? 3 : 5];
            break;
        }
        case LessonKindSubSimple:
            [self playSubSimpleWithSerial:serial a:7 b:3];
            break;
        case LessonKindMakeTen:
            [self playMakeTenWithSerial:serial a:8 b:5];
            break;
        case LessonKindBreakTen:
            [self playBreakTenWithSerial:serial a:12 b:5];
            break;
        case LessonKindMultiplication:
            // 九九乘法目前不做示範動畫（直接進答題）
            [self.delegate lessonIntroDidFinish:self];
            break;
    }
}

#pragma mark - Step helpers

- (void)afterDelay:(NSTimeInterval)delay serial:(NSInteger)serial do:(void (^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.demoSerial != serial) return;  // 已被取代或關掉
        block();
    });
}

/// 當 stage.bounds 還是 0 時要求重試本次 play；逾期次數上限就跳過示範直接結束。
/// 回傳 YES 代表已排定重試，呼叫端應該 return；NO 代表已放棄。
- (BOOL)retryLayoutIfPossibleSerial:(NSInteger)serial retry:(void (^)(void))retry {
    if (self.layoutRetryCount >= kIntroLayoutMaxRetries) {
        // 已重試 N 次 stage 仍沒尺寸（layout pathological，view 沒進 hierarchy 等）：
        // 直接結束示範，讓 LessonViewController 接手出題；否則 20Hz dispatch_after 不歸零。
        NSLog(@"[LessonIntroView] stage bounds zero after %ld retries; skipping demo", (long)self.layoutRetryCount);
        [self.delegate lessonIntroDidFinish:self];
        return NO;
    }
    self.layoutRetryCount++;
    [self afterDelay:0.05 serial:serial do:retry];
    return YES;
}

- (void)showNarration:(NSString *)text {
    self.narration.alpha = 0;
    self.narration.text = text;
    [UIView animateWithDuration:0.25 animations:^{ self.narration.alpha = 1.0; }];
}

/// 生成一個圓點（直徑 dp、顏色 color），加進 stage 並回傳。位置先放在 (x,y) 中心。
- (UIView *)addDotAtX:(CGFloat)x y:(CGFloat)y diameter:(CGFloat)d color:(UIColor *)c {
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(x - d/2, y - d/2, d, d)];
    dot.backgroundColor = c;
    dot.layer.cornerRadius = d / 2.0;
    [ChildUI applySoftShadowOnLayer:dot.layer];
    dot.alpha = 0;
    dot.transform = CGAffineTransformMakeScale(0.4, 0.4);
    [self.stage addSubview:dot];
    return dot;
}

/// 將 dots 排成一行，置中於 (cx, cy)。
- (void)layoutDots:(NSArray<UIView *> *)dots centerX:(CGFloat)cx centerY:(CGFloat)cy diameter:(CGFloat)d gap:(CGFloat)gap {
    NSInteger n = dots.count;
    CGFloat totalW = n * d + (n - 1) * gap;
    CGFloat startX = cx - totalW / 2.0 + d / 2.0;
    for (NSInteger i = 0; i < n; i++) {
        UIView *dot = dots[i];
        CGPoint center = CGPointMake(startX + i * (d + gap), cy);
        dot.center = center;
    }
}

/// 一批 dots「彈跳出現」。
- (void)bounceInDots:(NSArray<UIView *> *)dots stagger:(NSTimeInterval)stagger {
    NSTimeInterval delay = 0;
    for (UIView *dot in dots) {
        [UIView animateWithDuration:0.35 delay:delay usingSpringWithDamping:0.55 initialSpringVelocity:0.6
                            options:0 animations:^{
            dot.alpha = 1.0;
            dot.transform = CGAffineTransformIdentity;
        } completion:nil];
        delay += stagger;
    }
}

#pragma mark - L1/L2: 簡單加法

- (void)playAddSimpleWithSerial:(NSInteger)serial a:(NSInteger)a b:(NSInteger)b {
    self.problemLabel.text = [NSString stringWithFormat:@"%ld + %ld = ?", (long)a, (long)b];
    [self showNarration:[NSString stringWithFormat:@"看～這邊有 %ld 顆。", (long)a]];

    [self layoutIfNeeded];
    CGFloat W = CGRectGetWidth(self.stage.bounds);
    CGFloat H = CGRectGetHeight(self.stage.bounds);
    if (W <= 0 || H <= 0) {
        [self retryLayoutIfPossibleSerial:serial retry:^{ [self playAddSimpleWithSerial:serial a:a b:b]; }];
        return;
    }
    CGFloat d = 36.0;
    CGFloat gap = 8.0;

    NSMutableArray *left = [NSMutableArray array];
    NSMutableArray *right = [NSMutableArray array];
    for (NSInteger i = 0; i < a; i++) {
        [left addObject:[self addDotAtX:0 y:0 diameter:d color:ChildUI.pinkAccent]];
    }
    for (NSInteger i = 0; i < b; i++) {
        [right addObject:[self addDotAtX:0 y:0 diameter:d color:ChildUI.skyBlue]];
    }
    [self layoutDots:left centerX:W * 0.30 centerY:H * 0.5 diameter:d gap:gap];
    [self layoutDots:right centerX:W * 0.72 centerY:H * 0.5 diameter:d gap:gap];

    // Step 1：a 顆紅慢慢出現
    [self bounceInDots:left stagger:0.25];

    // Step 2：a 出完 → 等一下 → 換 b 旁白 → b 顆藍慢慢出現
    NSTimeInterval t1 = 0.25 * a + 1.2;
    [self afterDelay:t1 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"還有 %ld 顆。", (long)b]];
    }];
    [self afterDelay:t1 + 0.6 serial:serial do:^{
        [self bounceInDots:right stagger:0.25];
    }];

    // Step 3：合起來
    NSTimeInterval t2 = t1 + 0.6 + 0.25 * b + 1.6;
    [self afterDelay:t2 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"把它們合起來……", (long)(a + b)]];
    }];
    [self afterDelay:t2 + 1.0 serial:serial do:^{
        NSMutableArray *all = [NSMutableArray array];
        [all addObjectsFromArray:left];
        [all addObjectsFromArray:right];

        NSInteger n = all.count;
        CGFloat totalW = n * d + (n - 1) * gap;
        CGFloat startX = W / 2.0 - totalW / 2.0 + d / 2.0;
        CGFloat targetY = H * 0.5;

        [UIView animateWithDuration:0.9 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.4
                            options:0 animations:^{
            for (NSInteger i = 0; i < n; i++) {
                UIView *dot = all[i];
                dot.center = CGPointMake(startX + i * (d + gap), targetY);
            }
        } completion:nil];
        [[SoundManager sharedInstance] play:SoundEffectReveal];
    }];

    // Step 4：答案
    [self afterDelay:t2 + 2.4 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"一共是 %ld 顆！", (long)(a + b)]];
        self.problemLabel.text = [NSString stringWithFormat:@"%ld + %ld = %ld", (long)a, (long)b, (long)(a + b)];
        self.problemLabel.transform = CGAffineTransformMakeScale(1.1, 1.1);
        [UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.6
                            options:0 animations:^{
            self.problemLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
        [[SoundManager sharedInstance] play:SoundEffectCheer];
    }];
}

#pragma mark - L3: 簡單減法

- (void)playSubSimpleWithSerial:(NSInteger)serial a:(NSInteger)a b:(NSInteger)b {
    self.problemLabel.text = [NSString stringWithFormat:@"%ld - %ld = ?", (long)a, (long)b];
    [self showNarration:[NSString stringWithFormat:@"先有 %ld 顆。", (long)a]];

    [self layoutIfNeeded];
    CGFloat W = CGRectGetWidth(self.stage.bounds);
    CGFloat H = CGRectGetHeight(self.stage.bounds);
    if (W <= 0 || H <= 0) {
        [self retryLayoutIfPossibleSerial:serial retry:^{ [self playSubSimpleWithSerial:serial a:a b:b]; }];
        return;
    }
    CGFloat d = 36.0;
    CGFloat gap = 8.0;

    NSMutableArray *dots = [NSMutableArray array];
    for (NSInteger i = 0; i < a; i++) {
        [dots addObject:[self addDotAtX:0 y:0 diameter:d color:ChildUI.pinkAccent]];
    }
    [self layoutDots:dots centerX:W / 2.0 centerY:H * 0.5 diameter:d gap:gap];
    [self bounceInDots:dots stagger:0.22];

    NSTimeInterval t1 = 0.22 * a + 1.8;
    // Step 2：旁白「拿走 b 顆」+ 變色
    [self afterDelay:t1 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"我們要拿走 %ld 顆。", (long)b]];
    }];
    [self afterDelay:t1 + 0.8 serial:serial do:^{
        for (NSInteger i = a - b; i < a; i++) {
            UIView *dot = dots[i];
            [UIView animateWithDuration:0.7 animations:^{
                dot.backgroundColor = [ChildUI.brownText colorWithAlphaComponent:0.2];
                dot.transform = CGAffineTransformMakeScale(0.85, 0.85);
            }];
        }
        [[SoundManager sharedInstance] play:SoundEffectReveal];
    }];

    // Step 3：淡出
    NSTimeInterval t2 = t1 + 2.2;
    [self afterDelay:t2 serial:serial do:^{
        for (NSInteger i = a - b; i < a; i++) {
            UIView *dot = dots[i];
            [UIView animateWithDuration:0.8 animations:^{
                dot.alpha = 0;
                dot.transform = CGAffineTransformMakeScale(0.3, 0.3);
                dot.center = CGPointMake(dot.center.x, dot.center.y + 50);
            }];
        }
    }];

    // Step 4：剩下 N 顆
    NSTimeInterval t3 = t2 + 1.6;
    [self afterDelay:t3 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"剩下 %ld 顆！", (long)(a - b)]];
        NSMutableArray *remaining = [NSMutableArray array];
        for (NSInteger i = 0; i < a - b; i++) [remaining addObject:dots[i]];
        NSInteger n = remaining.count;
        CGFloat totalW = n * d + (n - 1) * gap;
        CGFloat startX = W / 2.0 - totalW / 2.0 + d / 2.0;
        [UIView animateWithDuration:0.8 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.4
                            options:0 animations:^{
            for (NSInteger i = 0; i < n; i++) {
                UIView *dot = remaining[i];
                dot.center = CGPointMake(startX + i * (d + gap), H * 0.5);
            }
        } completion:nil];

        self.problemLabel.text = [NSString stringWithFormat:@"%ld - %ld = %ld", (long)a, (long)b, (long)(a - b)];
        self.problemLabel.transform = CGAffineTransformMakeScale(1.1, 1.1);
        [UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.6
                            options:0 animations:^{
            self.problemLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
        [[SoundManager sharedInstance] play:SoundEffectCheer];
    }];
}

#pragma mark - L4: 合十法 (e.g. 8 + 5)

- (void)playMakeTenWithSerial:(NSInteger)serial a:(NSInteger)a b:(NSInteger)b {
    NSInteger toTen = 10 - a;
    NSInteger remainder = b - toTen;
    self.problemLabel.text = [NSString stringWithFormat:@"%ld + %ld = ?", (long)a, (long)b];
    [self showNarration:@"我們想辦法先湊滿 10 再算～"];

    [self layoutIfNeeded];
    CGFloat W = CGRectGetWidth(self.stage.bounds);
    CGFloat H = CGRectGetHeight(self.stage.bounds);
    if (W <= 0 || H <= 0) {
        [self retryLayoutIfPossibleSerial:serial retry:^{ [self playMakeTenWithSerial:serial a:a b:b]; }];
        return;
    }
    CGFloat d = 24.0;
    CGFloat gap = 4.0;

    NSMutableArray *left = [NSMutableArray array];
    NSMutableArray *right = [NSMutableArray array];
    for (NSInteger i = 0; i < a; i++) [left addObject:[self addDotAtX:0 y:0 diameter:d color:ChildUI.pinkAccent]];
    for (NSInteger i = 0; i < b; i++) [right addObject:[self addDotAtX:0 y:0 diameter:d color:ChildUI.skyBlue]];

    CGFloat topY = H * 0.30;
    [self layoutDots:left centerX:W * 0.28 centerY:topY diameter:d gap:gap];
    [self layoutDots:right centerX:W * 0.75 centerY:topY diameter:d gap:gap];

    // Step 1：a 顆紅一個一個出現
    [self bounceInDots:left stagger:0.18];
    NSTimeInterval t1 = 0.18 * a + 1.0;
    [self afterDelay:t1 serial:serial do:^{
        [self bounceInDots:right stagger:0.18];
    }];

    // Step 2：拆 b → toTen + remainder
    NSTimeInterval t2 = t1 + 0.18 * b + 1.5;
    [self afterDelay:t2 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"先把 %ld 拆成 %ld 和 %ld。",
                             (long)b, (long)toTen, (long)remainder]];
    }];
    [self afterDelay:t2 + 1.0 serial:serial do:^{
        NSArray *split1 = [right subarrayWithRange:NSMakeRange(0, toTen)];
        NSArray *split2 = [right subarrayWithRange:NSMakeRange(toTen, remainder)];
        CGFloat midX = W * 0.55;
        [UIView animateWithDuration:1.0 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:0.5
                            options:0 animations:^{
            [self layoutDots:split1 centerX:midX - 18 centerY:topY diameter:d gap:gap];
            [self layoutDots:split2 centerX:W * 0.82 centerY:topY diameter:d gap:gap];
            for (UIView *dot in split1) dot.backgroundColor = ChildUI.eggYolk;
        } completion:nil];
        [[SoundManager sharedInstance] play:SoundEffectReveal];
    }];

    // Step 3：toTen 補到 left → 變 10
    NSTimeInterval t3 = t2 + 3.0;
    [self afterDelay:t3 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"%ld 加 %ld 剛好等於 10。",
                             (long)a, (long)toTen]];
    }];
    [self afterDelay:t3 + 1.0 serial:serial do:^{
        NSMutableArray *combined = [NSMutableArray array];
        [combined addObjectsFromArray:left];
        for (NSInteger i = 0; i < toTen; i++) [combined addObject:right[i]];
        [UIView animateWithDuration:1.1 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5
                            options:0 animations:^{
            [self layoutDots:combined centerX:W * 0.32 centerY:topY diameter:d gap:gap];
            for (UIView *dot in combined) dot.backgroundColor = ChildUI.mintGreen;
        } completion:nil];
        [[SoundManager sharedInstance] play:SoundEffectReveal];
    }];

    // Step 4：10 + remainder = answer
    NSTimeInterval t4 = t3 + 3.2;
    [self afterDelay:t4 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"10 加剩下的 %ld，等於 %ld！",
                             (long)remainder, (long)(a + b)]];

        UILabel *eq = [[UILabel alloc] init];
        eq.text = [NSString stringWithFormat:@"10 + %ld = %ld", (long)remainder, (long)(a + b)];
        eq.font = [ChildUI roundedMonoFontOfSize:34.0 weight:UIFontWeightBold];
        eq.textColor = ChildUI.calmGreen;
        eq.textAlignment = NSTextAlignmentCenter;
        eq.alpha = 0;
        eq.transform = CGAffineTransformMakeScale(0.7, 0.7);
        eq.frame = CGRectMake(0, H * 0.65, W, 44);
        [self.stage addSubview:eq];
        [UIView animateWithDuration:0.7 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.6
                            options:0 animations:^{
            eq.alpha = 1.0;
            eq.transform = CGAffineTransformIdentity;
        } completion:nil];

        self.problemLabel.text = [NSString stringWithFormat:@"%ld + %ld = %ld",
                                  (long)a, (long)b, (long)(a + b)];
        [[SoundManager sharedInstance] play:SoundEffectCheer];
    }];
}

#pragma mark - L5: 破十法 (e.g. 12 - 5)

- (void)playBreakTenWithSerial:(NSInteger)serial a:(NSInteger)a b:(NSInteger)b {
    NSInteger ones = a % 10;
    NSInteger tenLeft = 10 - b;
    self.problemLabel.text = [NSString stringWithFormat:@"%ld - %ld = ?", (long)a, (long)b];
    [self showNarration:[NSString stringWithFormat:@"先把 %ld 拆成 10 和 %ld。",
                         (long)a, (long)ones]];

    [self layoutIfNeeded];
    CGFloat W = CGRectGetWidth(self.stage.bounds);
    CGFloat H = CGRectGetHeight(self.stage.bounds);
    if (W <= 0 || H <= 0) {
        [self retryLayoutIfPossibleSerial:serial retry:^{ [self playBreakTenWithSerial:serial a:a b:b]; }];
        return;
    }
    CGFloat d = 22.0;
    CGFloat gap = 4.0;

    NSMutableArray *tenGroup = [NSMutableArray array];
    for (NSInteger i = 0; i < 10; i++) {
        [tenGroup addObject:[self addDotAtX:0 y:0 diameter:d color:ChildUI.skyBlue]];
    }
    CGFloat boxCx = W * 0.30;
    CGFloat boxCy = H * 0.35;
    for (NSInteger i = 0; i < 10; i++) {
        NSInteger row = i / 5;
        NSInteger col = i % 5;
        UIView *dot = tenGroup[i];
        dot.center = CGPointMake(boxCx - 2 * (d + gap) + col * (d + gap),
                                 boxCy - 0.5 * (d + gap) + row * (d + gap));
    }
    NSMutableArray *onesGroup = [NSMutableArray array];
    for (NSInteger i = 0; i < ones; i++) {
        [onesGroup addObject:[self addDotAtX:0 y:0 diameter:d color:ChildUI.mintGreen]];
    }
    [self layoutDots:onesGroup centerX:W * 0.75 centerY:boxCy diameter:d gap:gap];

    // Step 1：10 顆藍出現
    [self bounceInDots:tenGroup stagger:0.10];
    NSTimeInterval t1 = 0.10 * 10 + 1.0;
    [self afterDelay:t1 serial:serial do:^{
        [self bounceInDots:onesGroup stagger:0.18];
    }];

    // Step 2：旁白「從 10 裡面拿走 b 顆」+ 變色
    NSTimeInterval t2 = t1 + 0.18 * ones + 1.5;
    [self afterDelay:t2 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"從 10 裡面拿走 %ld 顆。", (long)b]];
    }];
    [self afterDelay:t2 + 0.9 serial:serial do:^{
        for (NSInteger i = 10 - b; i < 10; i++) {
            UIView *dot = tenGroup[i];
            [UIView animateWithDuration:0.7 animations:^{
                dot.backgroundColor = [ChildUI.brownText colorWithAlphaComponent:0.2];
                dot.transform = CGAffineTransformMakeScale(0.85, 0.85);
            }];
        }
        [[SoundManager sharedInstance] play:SoundEffectReveal];
    }];

    // Step 3：淡出 → 旁白「10 拿走 b 還剩 tenLeft」
    NSTimeInterval t3 = t2 + 2.4;
    [self afterDelay:t3 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"10 拿走 %ld 剩 %ld。", (long)b, (long)tenLeft]];
        for (NSInteger i = 10 - b; i < 10; i++) {
            UIView *dot = tenGroup[i];
            [UIView animateWithDuration:0.8 animations:^{
                dot.alpha = 0;
                dot.transform = CGAffineTransformMakeScale(0.3, 0.3);
                dot.center = CGPointMake(dot.center.x, dot.center.y + 40);
            }];
        }
    }];

    // Step 4：剩 tenLeft + ones = answer
    NSTimeInterval t4 = t3 + 2.5;
    [self afterDelay:t4 serial:serial do:^{
        [self showNarration:[NSString stringWithFormat:@"再加上原本的 %ld，等於 %ld！",
                             (long)ones, (long)(a - b)]];

        UILabel *eq = [[UILabel alloc] init];
        eq.text = [NSString stringWithFormat:@"%ld + %ld = %ld",
                   (long)tenLeft, (long)ones, (long)(a - b)];
        eq.font = [ChildUI roundedMonoFontOfSize:34.0 weight:UIFontWeightBold];
        eq.textColor = ChildUI.calmGreen;
        eq.textAlignment = NSTextAlignmentCenter;
        eq.alpha = 0;
        eq.transform = CGAffineTransformMakeScale(0.7, 0.7);
        eq.frame = CGRectMake(0, H * 0.72, W, 44);
        [self.stage addSubview:eq];
        [UIView animateWithDuration:0.7 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.6
                            options:0 animations:^{
            eq.alpha = 1.0;
            eq.transform = CGAffineTransformIdentity;
        } completion:nil];

        self.problemLabel.text = [NSString stringWithFormat:@"%ld - %ld = %ld",
                                  (long)a, (long)b, (long)(a - b)];
        [[SoundManager sharedInstance] play:SoundEffectCheer];
    }];
}

@end
