#include <math.h>
#import "AnimatedHintView.h"
#import "ArithmeticProblem.h"
#import "ArithmeticSolution.h"
#import "AdditionHintView.h"
#import "SubtractionHintView.h"
#import "ChildUIKit.h"
#import "SoundManager.h"

@interface AnimatedHintView ()
@property (nonatomic, strong, nullable) UIView *innerHintView;
@property (nonatomic, strong) NSHashTable<CALayer *> *animatedLayers;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *pendingSoundBlocks;
@property (nonatomic, assign) NSUInteger revealGeneration;
@property (nonatomic, assign) CGSize renderedSize;
@end

@implementation AnimatedHintView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self commonInit];
    return self;
}

- (void)commonInit {
    self.backgroundColor = UIColor.clearColor;
    self.animatedLayers = [NSHashTable weakObjectsHashTable];
    self.pendingSoundBlocks = [NSMutableArray array];
    self.accessibilityLabel = @"直式解題提示";
    self.accessibilityLanguage = @"zh-TW";
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(motionPreferenceChanged:)
                   name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(applicationWillResignActive:)
                   name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)dealloc {
    for (dispatch_block_t block in _pendingSoundBlocks) dispatch_block_cancel(block);
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!CGSizeEqualToSize(self.renderedSize, self.bounds.size)) {
        // Static hint views rebuild their grids on resize. Do not keep sounds for old cells.
        [self cancelAnimations];
        self.renderedSize = self.bounds.size;
    }
    self.innerHintView.frame = self.bounds;
}

- (void)configureWithProblem:(ArithmeticProblem *)problem {
    [self cancelAnimations];
    [self.innerHintView removeFromSuperview];
    self.innerHintView = nil;
    self.accessibilityValue = nil;
    self.isAccessibilityElement = NO;

    UIView *child = nil;
    if ([problem.operatorSymbol isEqualToString:@"+"]) {
        AdditionHintView *view = [[AdditionHintView alloc] initWithFrame:self.bounds];
        if ([view configureWithProblem:problem]) child = view;
    } else if ([problem.operatorSymbol isEqualToString:@"-"]) {
        SubtractionHintView *view = [[SubtractionHintView alloc] initWithFrame:self.bounds];
        if ([view configureWithProblem:problem]) child = view;
    }
    if (!child) return;

    self.innerHintView = child;
    child.accessibilityElementsHidden = YES; // Digits in separate rows are not a spoken explanation.
    child.isAccessibilityElement = NO;
    self.isAccessibilityElement = YES;
    self.accessibilityValue = [self spokenSummaryForProblem:problem];
    [self addSubview:child];
    self.renderedSize = self.bounds.size;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [child layoutIfNeeded];
    if ([self isVisibleForReveal] && ChildUI.motionEnabled) [self animateRevealUnder:child];
}

#pragma mark - One coherent spoken explanation

- (NSString *)placeNameAtOffset:(NSInteger)offset {
    NSArray<NSString *> *names = @[@"個位", @"十位", @"百位", @"千位", @"萬位", @"十萬位", @"百萬位", @"千萬位", @"億位"];
    return offset >= 0 && offset < (NSInteger)names.count ? names[offset]
        : [NSString stringWithFormat:@"從右邊數第 %ld 位", (long)offset + 1];
}

- (NSString *)spokenSummaryForProblem:(ArithmeticProblem *)problem {
    ArithmeticSolution *solution = [ArithmeticSolution solutionForProblem:problem];
    BOOL addition = [problem.operatorSymbol isEqualToString:@"+"];
    NSMutableArray<NSString *> *sentences = [NSMutableArray arrayWithObjects:
        [NSString stringWithFormat:@"%ld %@ %ld 等於 %ld。", (long)problem.number1,
         addition ? @"加" : @"減", (long)problem.number2, (long)problem.answer],
        @"先把相同的位數對齊，從個位往左算。", nil];
    NSInteger carry = 0;
    for (NSInteger i = solution.maxLength - 1; i >= 0; i--) {
        NSInteger offset = solution.maxLength - 1 - i;
        NSString *place = [self placeNameAtOffset:offset];
        NSInteger first = solution.digits1[i].integerValue;
        NSInteger second = solution.digits2[i].integerValue;
        if (addition) {
            NSInteger total = first + second + carry;
            NSString *incoming = carry ? @"，再加進位的 1" : @"";
            NSString *outgoing = total >= 10
                ? [NSString stringWithFormat:@"，向%@進 1", [self placeNameAtOffset:offset + 1]] : @"";
            [sentences addObject:[NSString stringWithFormat:@"%@：%ld 加 %ld%@，是 %ld，寫 %ld%@。",
                                  place, (long)first, (long)second, incoming, (long)total, (long)(total % 10), outgoing]];
            carry = total / 10;
        } else {
            BorrowInfo *borrow = solution.borrows[i];
            NSInteger effective = borrow.afterBorrowing ? borrow.afterBorrowing.integerValue
                : (borrow.afterLending ? borrow.afterLending.integerValue : first);
            // Leading zero columns are not printed in the answer either.
            if (i == 0 && offset > 0 && effective == 0 && second == 0) continue;
            NSString *borrowing = borrow.afterBorrowing ? @"不夠減，先向左邊借位。" : @"";
            [sentences addObject:[NSString stringWithFormat:@"%@：%@%ld 減 %ld 是 %ld。", place,
                                  borrowing, (long)effective, (long)second, (long)(effective - second)]];
        }
    }
    return [sentences componentsJoinedByString:@" "];
}

#pragma mark - Cancellable reveal

- (BOOL)isVisibleForReveal {
    if (!self.window || UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) return NO;
    for (UIView *view = self; view; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) return NO;
    }
    return YES;
}

- (void)cancelAnimations {
    self.revealGeneration++;
    for (dispatch_block_t block in self.pendingSoundBlocks) dispatch_block_cancel(block);
    [self.pendingSoundBlocks removeAllObjects];
    for (CALayer *layer in self.animatedLayers) [layer removeAnimationForKey:@"hintReveal"];
    [self.animatedLayers removeAllObjects];
    // Model layers are always fully visible. Removing presentation animations reveals
    // the complete explanation immediately, without a completion or delayed mutation.
}

- (void)animateRevealUnder:(UIView *)hint {
    UIView *grid = nil;
    if ([hint isKindOfClass:AdditionHintView.class]) grid = ((AdditionHintView *)hint).gridContainer;
    if ([hint isKindOfClass:SubtractionHintView.class]) grid = ((SubtractionHintView *)hint).gridContainer;
    if (!grid) return;

    NSArray<UIView *> *sorted = [grid.subviews sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat difference = a.center.x - b.center.x;
        if (fabs(difference) < 1.0) return NSOrderedSame;
        return difference > 0 ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSSet<NSString *> *operators = [NSSet setWithArray:@[@"+", @"-", @"−", @"×", @"÷", @"="]];
    const NSTimeInterval batchGap = 0.45;
    NSMutableArray<NSNumber *> *columns = [NSMutableArray array];
    for (UIView *cell in sorted) {
        if ([cell isKindOfClass:UILabel.class]) {
            NSString *text = [((UILabel *)cell).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if (text.length > 0 && [operators containsObject:text]) continue;
        }
        // Horizontal separators are the problem's structure, not another digit column.
        if (CGRectGetHeight(cell.bounds) <= 6.0 && CGRectGetWidth(cell.bounds) > 6.0) continue;
        if (columns.count == 0 || fabs(columns.lastObject.doubleValue - cell.center.x) >= 1.0) {
            [columns addObject:@(cell.center.x)];
            [self scheduleRevealSoundAfter:batchGap * (columns.count - 1)];
        }
        [self addRevealToLayer:cell.layer delay:batchGap * (columns.count - 1) scales:YES];
    }
    for (CALayer *layer in [grid.layer.sublayers copy]) {
        if (![layer isKindOfClass:CAShapeLayer.class]) continue;
        // Borrow arrows/strikes join the nearest column instead of an unrelated pair count.
        CAShapeLayer *shape = (CAShapeLayer *)layer;
        CGFloat centerX = shape.path ? CGRectGetMidX(CGPathGetBoundingBox(shape.path)) : layer.position.x;
        NSUInteger nearest = 0;
        CGFloat distance = CGFLOAT_MAX;
        for (NSUInteger i = 0; i < columns.count; i++) {
            CGFloat candidate = fabs(columns[i].doubleValue - centerX);
            if (candidate < distance) { distance = candidate; nearest = i; }
        }
        [self addRevealToLayer:layer delay:batchGap * nearest scales:NO];
    }
}

- (void)addRevealToLayer:(CALayer *)layer delay:(NSTimeInterval)delay scales:(BOOL)scales {
    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @0;
    opacity.toValue = @(layer.opacity);
    opacity.duration = 0.32;
    NSMutableArray<CAAnimation *> *animations = [NSMutableArray arrayWithObject:opacity];
    if (scales) {
        CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        scale.values = @[@0.85, @1.04, @1.0];
        scale.duration = 0.55;
        [animations addObject:scale];
    }
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = animations;
    group.duration = 0.55;
    group.beginTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil] + delay;
    group.fillMode = kCAFillModeBackwards;
    group.removedOnCompletion = YES;
    [layer addAnimation:group forKey:@"hintReveal"];
    [self.animatedLayers addObject:layer];
}

- (void)scheduleRevealSoundAfter:(NSTimeInterval)delay {
    NSUInteger generation = self.revealGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.revealGeneration || ![self isVisibleForReveal] || !ChildUI.motionEnabled) return;
        [self playRevealSound];
    });
    [self.pendingSoundBlocks addObject:block];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)playRevealSound {
    [[SoundManager sharedInstance] play:SoundEffectReveal];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    if (hidden) [self cancelAnimations];
}

- (void)setAlpha:(CGFloat)alpha {
    [super setAlpha:alpha];
    if (alpha <= 0.01) [self cancelAnimations];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self cancelAnimations];
}

- (void)motionPreferenceChanged:(NSNotification *)notification {
    if (!ChildUI.motionEnabled) [self cancelAnimations];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self cancelAnimations];
}

@end
