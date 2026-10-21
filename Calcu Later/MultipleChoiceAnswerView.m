#import "MultipleChoiceAnswerView.h"
#import "DistractorGenerator.h"
#import "ArithmeticProblem.h"
#import "ChildUIKit.h"
#import "SoundManager.h"

@interface MultipleChoiceAnswerView ()
@property (nonatomic, strong) NSArray<UIButton *> *choiceButtons;
@property (nonatomic, strong) ArithmeticProblem *problem;
@property (nonatomic, strong) NSArray<NSNumber *> *currentChoices;
/// 字串模式：configureWithChoiceTitles: 設定。NSNotFound 表示走 problem.answer 比對的整數模式。
@property (nonatomic, assign) NSInteger explicitCorrectIndex;
@end

@implementation MultipleChoiceAnswerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        // 整數模式的 sentinel。Zero-init (= 0) 會被誤判為「字串模式 correctIndex=0」，
        // 導致 configure 之前任何點擊都把按鈕 0 當正解。
        _explicitCorrectIndex = NSNotFound;
        NSMutableArray *btns = [NSMutableArray array];
        UIColor *cycle[4] = {
            ChildUI.pinkAccent, ChildUI.skyBlue, ChildUI.mintGreen, ChildUI.eggYolk
        };
        for (NSInteger i = 0; i < 4; i++) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.backgroundColor = cycle[i];
            b.layer.cornerRadius = 24.0;
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.titleLabel.font = [ChildUI roundedMonoFontOfSize:42.0 weight:UIFontWeightBold];
            b.tag = i;
            b.accessibilityIdentifier = [NSString stringWithFormat:@"answer.%ld", (long)i];
            [ChildUI applySoftShadowOnLayer:b.layer];
            [b addTarget:self action:@selector(_choiceTapped:) forControlEvents:UIControlEventTouchUpInside];
            [b addTarget:self action:@selector(_touchDown:) forControlEvents:UIControlEventTouchDown];
            // 不在 TouchUpInside 還原 transform：_choiceTapped 會用 _correctFeedback 接手放大彈跳，
            // 否則兩個動畫同時跑 _touchUp 會覆蓋 _correctFeedback，孩子看不到放大效果。
            [b addTarget:self action:@selector(_touchUp:) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
            [self addSubview:b];
            [btns addObject:b];
        }
        self.choiceButtons = [btns copy];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat gap = 16.0;
    CGFloat w = (CGRectGetWidth(self.bounds) - gap) * 0.5;
    CGFloat h = (CGRectGetHeight(self.bounds) - gap) * 0.5;
    for (NSInteger i = 0; i < 4; i++) {
        NSInteger r = i / 2;
        NSInteger c = i % 2;
        UIButton *b = self.choiceButtons[i];
        b.frame = CGRectMake(c * (w + gap), r * (h + gap), w, h);
    }
}

- (void)configureWithProblem:(ArithmeticProblem *)problem {
    self.problem = problem;
    self.explicitCorrectIndex = NSNotFound;  // 整數模式：用 problem.answer 比對
    self.currentChoices = [DistractorGenerator choicesForProblem:problem];
    for (NSInteger i = 0; i < 4; i++) {
        NSString *s = [NSString stringWithFormat:@"%ld", (long)self.currentChoices[i].integerValue];
        [self.choiceButtons[i] setTitle:s forState:UIControlStateNormal];
        self.choiceButtons[i].enabled = YES;
        self.choiceButtons[i].alpha = 1.0;
    }
}

- (void)configureWithChoiceTitles:(NSArray<NSString *> *)titles correctIndex:(NSInteger)correctIndex {
    self.problem = nil;
    self.currentChoices = nil;
    // 防呆：correctIndex 必須落在 [0, titles.count) 內。
    // - NSNotFound 會讓 _choiceTapped 走進整數模式分支，因 currentChoices/problem 已被 nil 掉，
    //   nil-messaging 讓 result=(0==0)=Correct，每一格都被當成正解 → 答題失效。
    // - 超出範圍 (e.g. == titles.count) 會讓 idx 永不等於 correctIndex → 每一格都判錯。
    // 兩種情境都讓 MCQ 不可用；clamp 到 0 + assert 留下訊號（debug build 噴錯，release 還能玩）。
    if (correctIndex == (NSInteger)NSNotFound
        || correctIndex < 0
        || correctIndex >= (NSInteger)titles.count) {
        NSAssert(NO, @"MCQ configureWithChoiceTitles: invalid correctIndex %ld for %lu titles",
                 (long)correctIndex, (unsigned long)titles.count);
        correctIndex = 0;
    }
    self.explicitCorrectIndex = correctIndex;
    NSInteger n = MIN((NSInteger)titles.count, 4);
    for (NSInteger i = 0; i < 4; i++) {
        NSString *s = (i < n) ? titles[i] : @"";
        [self.choiceButtons[i] setTitle:s forState:UIControlStateNormal];
        // titles 少於 4 的剩餘按鈕直接 disable，避免空白按鈕被點到（一定判錯，孩子困惑）。
        BOOL hasTitle = (i < n) && (s.length > 0);
        self.choiceButtons[i].enabled = hasTitle;
        self.choiceButtons[i].alpha = hasTitle ? 1.0 : 0.0;
    }
}

- (void)reset {
    for (UIButton *b in self.choiceButtons) {
        b.enabled = YES;
        b.alpha = 1.0;
        b.transform = CGAffineTransformIdentity;
    }
}

- (void)disableAllChoices {
    for (UIButton *b in self.choiceButtons) {
        b.enabled = NO;
    }
}

#pragma mark - Tap

- (void)_choiceTapped:(UIButton *)btn {
    NSInteger idx = btn.tag;
    MCQResult result;
    NSInteger value;
    if (self.explicitCorrectIndex != NSNotFound) {
        // 字串模式（分數等）：用 index 比對。value 對 delegate 無意義，傳 idx 占位。
        result = (idx == self.explicitCorrectIndex) ? MCQResultCorrect : MCQResultWrong;
        value = idx;
    } else {
        value = self.currentChoices[idx].integerValue;
        result = (value == self.problem.answer) ? MCQResultCorrect : MCQResultWrong;
    }

    if (result == MCQResultCorrect) {
        [self _correctFeedback:btn];
    } else {
        [self _wrongFeedback:btn];
    }

    [self.delegate mcqView:self didChoose:value result:result];
}

- (void)_correctFeedback:(UIButton *)btn {
    // 先取消任何 in-flight 動畫（例如 _touchDown 的 0.92 縮小），確保彈跳從 1.0 起跳。
    [btn.layer removeAllAnimations];
    btn.transform = CGAffineTransformIdentity;
    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.45 initialSpringVelocity:0.8
                        options:UIViewAnimationOptionAllowUserInteraction animations:^{
        btn.transform = CGAffineTransformMakeScale(1.18, 1.18);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 animations:^{
            btn.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)_wrongFeedback:(UIButton *)btn {
    btn.enabled = NO;
    [UIView animateWithDuration:0.50 animations:^{
        btn.alpha = 0.4;
    }];
    // 柔和搖頭
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    shake.values = @[ @(btn.center.x), @(btn.center.x - 8), @(btn.center.x + 8),
                      @(btn.center.x - 5), @(btn.center.x + 5), @(btn.center.x) ];
    shake.keyTimes = @[ @0, @0.2, @0.4, @0.6, @0.8, @1.0 ];
    shake.duration = 0.45;
    [btn.layer addAnimation:shake forKey:@"shake"];
}

- (void)_touchDown:(UIButton *)b {
    [[SoundManager sharedInstance] play:SoundEffectTap];
    [UIView animateWithDuration:0.10 animations:^{
        b.transform = CGAffineTransformMakeScale(0.92, 0.92);
    }];
}

- (void)_touchUp:(UIButton *)b {
    [UIView animateWithDuration:0.20 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5
                        options:0 animations:^{
        b.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
