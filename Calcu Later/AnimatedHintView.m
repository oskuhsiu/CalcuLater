#import "AnimatedHintView.h"
#import "ArithmeticProblem.h"
#import "AdditionHintView.h"
#import "SubtractionHintView.h"
#import "ChildUIKit.h"
#import "SoundManager.h"

/// 改造後的 AnimatedHintView：包裝 AdditionHintView 或 SubtractionHintView，
/// 用 mask 區域逐位（從右到左）spring 揭露答案 row 與進位/借位 row。
/// 切換或重設時 cancel 進行中的動畫，避免殘留。
@interface AnimatedHintView ()
@property (nonatomic, strong) UIView *innerHintView;
@property (nonatomic, strong) NSHashTable<UIView *> *animatedSubviews;
@end

@implementation AnimatedHintView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _animatedSubviews = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.innerHintView.frame = self.bounds;
}

- (void)configureWithProblem:(ArithmeticProblem *)problem {
    // cancel 既有動畫
    [self cancelAnimations];
    if (self.innerHintView) [self.innerHintView removeFromSuperview];
    self.innerHintView = nil;

    UIView *child = nil;
    if ([problem.operatorSymbol isEqualToString:@"+"]) {
        AdditionHintView *v = [[AdditionHintView alloc] initWithFrame:self.bounds];
        if ([v configureWithProblem:problem]) child = v;
    } else if ([problem.operatorSymbol isEqualToString:@"-"]) {
        SubtractionHintView *v = [[SubtractionHintView alloc] initWithFrame:self.bounds];
        if ([v configureWithProblem:problem]) child = v;
    }
    if (!child) return;

    self.innerHintView = child;
    [self addSubview:child];
    [self setNeedsLayout];
    [self layoutIfNeeded];

    [self animateRevealUnder:child];
}

#pragma mark - Animation

- (void)cancelAnimations {
    for (UIView *v in [self.animatedSubviews allObjects]) {
        [v.layer removeAllAnimations];
        v.transform = CGAffineTransformIdentity;
        v.alpha = 1.0;
    }
    [self.animatedSubviews removeAllObjects];
}

/// 逐位 spring 揭露：把 inner view 的子 view（含 carry 帽 / digit / arrow）由右到左、分批彈出。
- (void)animateRevealUnder:(UIView *)hint {
    // 取 AdditionHintView / SubtractionHintView 公開的 gridContainer property，避免
    // 依賴 hint.subviews.firstObject 這個隱性結構；若兩者在外面包了任何 sibling
    // （例如底色卡片）這條動畫就會抓錯 view。
    UIView *grid = nil;
    if ([hint isKindOfClass:[AdditionHintView class]]) {
        grid = ((AdditionHintView *)hint).gridContainer;
    } else if ([hint isKindOfClass:[SubtractionHintView class]]) {
        grid = ((SubtractionHintView *)hint).gridContainer;
    }
    if (!grid) return;
    NSArray<UIView *> *cells = grid.subviews;

    // 依 x 座標分組（從右到左揭露：x 大的先）
    NSArray<UIView *> *sorted = [cells sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        if (a.center.x == b.center.x) return NSOrderedSame;
        return a.center.x > b.center.x ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSInteger i = 0;
    NSInteger lastSoundBatch = -1;
    const NSTimeInterval batchGap = 0.55;   // 每位之間延遲
    const NSTimeInterval revealDuration = 1.0;
    NSSet *operatorChars = [NSSet setWithArray:@[@"+", @"-", @"−", @"×", @"÷", @"="]];
    for (UIView *v in sorted) {
        // 運算符 cell 屬於題目結構，直接顯示不做 reveal
        if ([v isKindOfClass:[UILabel class]]) {
            NSString *t = [((UILabel *)v).text stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceCharacterSet]];
            if (t.length > 0 && [operatorChars containsObject:t]) {
                v.alpha = 1.0;
                v.transform = CGAffineTransformIdentity;
                continue;
            }
        }
        [self.animatedSubviews addObject:v];
        v.alpha = 0;
        v.transform = CGAffineTransformMakeScale(0.4, 0.4);
        NSInteger batch = i / 2;
        NSTimeInterval delay = batchGap * (double)batch;
        [UIView animateWithDuration:revealDuration delay:delay
              usingSpringWithDamping:0.55 initialSpringVelocity:0.6
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            v.alpha = 1.0;
            v.transform = CGAffineTransformIdentity;
        } completion:nil];
        if (batch != lastSoundBatch) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [[SoundManager sharedInstance] play:SoundEffectReveal];
            });
            lastSoundBatch = batch;
        }
        i++;
    }

    // grid 內的 CAShapeLayer（arrow / strike）做不到 UIView 動畫，用 opacity 漸入。
    NSInteger li = 0;
    for (CALayer *layer in [grid.layer.sublayers copy]) {
        if (![layer isKindOfClass:[CAShapeLayer class]]) continue;
        CAShapeLayer *sl = (CAShapeLayer *)layer;
        CGFloat finalOpacity = sl.opacity > 0 ? sl.opacity : 1.0;
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
        anim.fromValue = @0.0;
        anim.toValue = @(finalOpacity);
        anim.duration = revealDuration;
        anim.beginTime = CACurrentMediaTime() + batchGap * (double)(li / 2);
        anim.fillMode = kCAFillModeBoth;
        [sl addAnimation:anim forKey:@"reveal"];
        li++;
    }
}

@end
