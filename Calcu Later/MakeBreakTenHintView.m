#import "MakeBreakTenHintView.h"
#import "ArithmeticProblem.h"
#import "ChildUIKit.h"

@interface MakeBreakTenHintView ()
@property (nonatomic, assign) MakeBreakTenMode mode;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) NSMutableArray<UILabel *> *stepLabels;
@end

@implementation MakeBreakTenHintView

- (instancetype)initWithFrame:(CGRect)frame mode:(MakeBreakTenMode)mode {
    self = [super initWithFrame:frame];
    if (self) {
        _mode = mode;
        self.backgroundColor = ChildUI.creamBackground;
        self.layer.cornerRadius = 24.0;
        self.layer.masksToBounds = YES;
        _stack = [[UIStackView alloc] init];
        _stack.axis = UILayoutConstraintAxisVertical;
        _stack.alignment = UIStackViewAlignmentCenter;
        _stack.distribution = UIStackViewDistributionEqualSpacing;
        _stack.spacing = 18.0;
        _stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_stack];
        [NSLayoutConstraint activateConstraints:@[
            [_stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:16],
            [_stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],
        ]];
        _stepLabels = [NSMutableArray array];
    }
    return self;
}

- (BOOL)configureWithProblem:(ArithmeticProblem *)problem {
    NSArray<NSString *> *steps = nil;
    if (self.mode == MakeBreakTenModeMakeTen) {
        steps = [self makeTenStepsFor:problem];
    } else {
        steps = [self breakTenStepsFor:problem];
    }
    if (!steps) return NO;

    for (UILabel *l in self.stepLabels) [l removeFromSuperview];
    [self.stepLabels removeAllObjects];

    UIFont *font = [ChildUI roundedMonoFontOfSize:32.0 weight:UIFontWeightSemibold];
    NSInteger i = 0;
    for (NSString *s in steps) {
        UILabel *l = [[UILabel alloc] init];
        l.text = s;
        l.font = font;
        l.textColor = ChildUI.brownText;
        l.alpha = 0;
        l.transform = CGAffineTransformMakeScale(0.8, 0.8);
        [self.stack addArrangedSubview:l];
        [self.stepLabels addObject:l];

        [UIView animateWithDuration:0.45 delay:0.18 * (double)i
              usingSpringWithDamping:0.55 initialSpringVelocity:0.3 options:0 animations:^{
            l.alpha = 1.0;
            l.transform = CGAffineTransformIdentity;
        } completion:nil];
        i++;
    }
    return YES;
}

#pragma mark - Step text

- (nullable NSArray<NSString *> *)makeTenStepsFor:(ArithmeticProblem *)p {
    if (![p.operatorSymbol isEqualToString:@"+"]) return nil;
    NSInteger a = p.number1, b = p.number2;
    if (a + b <= 10 || a < 1 || a > 9 || b < 1 || b > 9) return nil;
    NSInteger need = 10 - a;
    NSInteger rest = b - need;
    return @[
        [NSString stringWithFormat:@"%ld + %ld", (long)a, (long)b],
        [NSString stringWithFormat:@"%ld + (%ld + %ld)", (long)a, (long)need, (long)rest],
        [NSString stringWithFormat:@"(%ld + %ld) + %ld", (long)a, (long)need, (long)rest],
        [NSString stringWithFormat:@"10 + %ld = %ld", (long)rest, (long)(a + b)],
    ];
}

- (nullable NSArray<NSString *> *)breakTenStepsFor:(ArithmeticProblem *)p {
    if (![p.operatorSymbol isEqualToString:@"-"]) return nil;
    NSInteger a = p.number1, b = p.number2;
    if (a < 10 || a > 19 || (a % 10) >= b) return nil;
    NSInteger ones = a % 10;
    return @[
        [NSString stringWithFormat:@"%ld − %ld", (long)a, (long)b],
        [NSString stringWithFormat:@"(10 + %ld) − %ld", (long)ones, (long)b],
        [NSString stringWithFormat:@"(10 − %ld) + %ld", (long)b, (long)ones],
        [NSString stringWithFormat:@"%ld + %ld = %ld", (long)(10 - b), (long)ones, (long)(a - b)],
    ];
}

@end
