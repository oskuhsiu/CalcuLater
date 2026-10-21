#import "VerticalArithmeticBoardView.h"
#import "ChildUIKit.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const NSTimeInterval VABExchangeDuration = 0.88;
static const CGFloat VABInset = 16.0;

@interface VABWeakDisplayLinkTarget : NSObject
@property (nonatomic, weak) id target;
- (void)tick:(CADisplayLink *)link;
@end

/// One concrete unit, not one accessibility element per dot. A ten is a segmented
/// rod, a hundred a labelled block. Higher places retain an explicit unit label.
@interface VABUnitView : UIView
@property (nonatomic) NSInteger place;
@property (nonatomic) BOOL crossedOut;
@property (nonatomic, strong) UIColor *unitColor;
@end

@implementation VABUnitView
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    CGRect body = CGRectInset(self.bounds, 2, 2);
    [self.unitColor setFill];
    [ChildUI.brownText setStroke];
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:self.place == 0 ? body.size.width / 2 : 3];
    shape.lineWidth = 1;
    [shape fill];
    [shape stroke];
    if (self.place == 1) {
        CGContextSetStrokeColorWithColor(context, [ChildUI.brownText colorWithAlphaComponent:0.45].CGColor);
        CGContextSetLineWidth(context, 0.7);
        for (NSInteger i = 1; i < 10; i++) {
            CGFloat y = CGRectGetMinY(body) + body.size.height * i / 10;
            CGContextMoveToPoint(context, CGRectGetMinX(body), y);
            CGContextAddLineToPoint(context, CGRectGetMaxX(body), y);
        }
        CGContextStrokePath(context);
    } else if (self.place >= 2) {
        NSDictionary *attributes = @{NSFontAttributeName:[ChildUI roundedFontOfSize:MIN(13, body.size.width * 0.7) weight:UIFontWeightBold], NSForegroundColorAttributeName:ChildUI.brownText};
        NSString *unit = @[@"一", @"十", @"百", @"千", @"萬"][MIN(4, self.place)];
        CGSize textSize = [unit sizeWithAttributes:attributes];
        [unit drawAtPoint:CGPointMake(CGRectGetMidX(body) - textSize.width / 2, CGRectGetMidY(body) - textSize.height / 2) withAttributes:attributes];
    }
    if (self.crossedOut) {
        CGContextSetStrokeColorWithColor(context, ChildUI.brownText.CGColor);
        CGContextSetLineWidth(context, 2);
        CGContextMoveToPoint(context, CGRectGetMinX(body), CGRectGetMaxY(body));
        CGContextAddLineToPoint(context, CGRectGetMaxX(body), CGRectGetMinY(body));
        CGContextStrokePath(context);
    }
}
@end

typedef struct {
    CGFloat width;
    CGFloat headingHeight;
    CGFloat annotationHeight;
    CGFloat operandHeight;
    CGFloat answerHeight;
    CGFloat gridHeight;
    CGFloat illustrationHeight;
    CGFloat height;
} VABMetrics;

@interface VerticalArithmeticBoardView ()
@property (nonatomic, strong, readwrite, nullable) ArithmeticTeachingSequence *sequence;
@property (nonatomic, assign, readwrite) NSInteger currentStepIndex;
@property (nonatomic, strong, readwrite, nullable) ArithmeticTeachingStep *currentStep;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *gridView;
@property (nonatomic, strong) UIView *illustrationView;
@property (nonatomic, strong) NSMutableArray<UILabel *> *annotationLabels;
@property (nonatomic, strong) NSMutableArray<UILabel *> *answerLabels;
@property (nonatomic, strong) NSMutableArray<NSValue *> *columnFrames;
@property (nonatomic, strong) NSMutableArray<VABUnitView *> *exchangeSourceUnits;
@property (nonatomic, strong) NSMutableArray<VABUnitView *> *exchangeDestinationUnits;
@property (nonatomic, strong) NSMutableArray<CALayer *> *animatedLayers;
@property (nonatomic, strong) NSMutableArray<UIView *> *transientViews;
@property (nonatomic, strong, nullable) CADisplayLink *animationDisplayLink;
@property (nonatomic) CFTimeInterval animationEndTime;
@property (nonatomic) CGSize renderedSize;
@property (nonatomic) BOOL needsSnapshotLayout;
- (void)animationTick:(CADisplayLink *)link;
@end

@implementation VABWeakDisplayLinkTarget
- (void)tick:(CADisplayLink *)link {
    VerticalArithmeticBoardView *board = self.target;
    if (!board) { [link invalidate]; return; }
    [board animationTick:link];
}
@end

@implementation VerticalArithmeticBoardView

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
    _currentStepIndex = NSNotFound;
    _annotationLabels = [NSMutableArray array];
    _answerLabels = [NSMutableArray array];
    _columnFrames = [NSMutableArray array];
    _exchangeSourceUnits = [NSMutableArray array];
    _exchangeDestinationUnits = [NSMutableArray array];
    _animatedLayers = [NSMutableArray array];
    _transientViews = [NSMutableArray array];
    self.backgroundColor = ChildUI.creamBackground;
    self.layer.cornerRadius = 24;
    self.clipsToBounds = YES;
    self.accessibilityIdentifier = @"verticalTeachingBoard";
    self.accessibilityLabel = @"一步一步看直式";
    self.accessibilityLanguage = @"zh-TW";
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(stopForNotification:) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(stopForNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(stopForNotification:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(contentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)dealloc {
    [_animationDisplayLink invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Deterministic snapshots

- (BOOL)configureWithSequence:(ArithmeticTeachingSequence *)sequence stepIndex:(NSInteger)stepIndex animated:(BOOL)animated {
    [self cancelAnimations];
    if (!sequence.isValid || sequence.columnCount < 1 || sequence.columnCount > 5 || stepIndex < 0 || stepIndex >= (NSInteger)sequence.steps.count) {
        self.sequence = nil;
        self.currentStep = nil;
        self.currentStepIndex = NSNotFound;
        [self clearSnapshot];
        self.isAccessibilityElement = NO;
        self.accessibilityValue = nil;
        [self invalidateIntrinsicContentSize];
        return NO;
    }
    self.sequence = sequence;
    self.currentStepIndex = stepIndex;
    self.currentStep = sequence.steps[stepIndex];
    self.isAccessibilityElement = YES;
    [self updateSpokenSummary];
    self.needsSnapshotLayout = YES;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    if (animated && [self canAnimate]) [self animateCurrentAction];
    return YES;
}

- (BOOL)showStepAtIndex:(NSInteger)stepIndex animated:(BOOL)animated {
    return [self configureWithSequence:self.sequence stepIndex:stepIndex animated:animated];
}

- (void)clearSnapshot {
    [self.contentView removeFromSuperview];
    self.contentView = nil;
    self.gridView = nil;
    self.illustrationView = nil;
    [self.annotationLabels removeAllObjects];
    [self.answerLabels removeAllObjects];
    [self.columnFrames removeAllObjects];
    [self.exchangeSourceUnits removeAllObjects];
    [self.exchangeDestinationUnits removeAllObjects];
}

- (NSString *)placeNameForColumn:(NSInteger)column {
    NSInteger place = self.sequence.columnCount - 1 - column;
    return place >= 0 && place < 5 ? @[@"個位", @"十位", @"百位", @"千位", @"萬位"][place] : @"";
}

- (NSString *)unitNameForColumn:(NSInteger)column {
    NSInteger place = self.sequence.columnCount - 1 - column;
    return place >= 0 && place < 5 ? @[@"一", @"十", @"百", @"千", @"萬"][place] : @"";
}

- (BOOL)validColumn:(NSInteger)column {
    return column >= 0 && column < self.sequence.columnCount;
}

- (NSString *)exchangeCountsText {
    ArithmeticTeachingStep *step = self.currentStep;
    if (step.kind != ArithmeticTeachingStepKindRegroup || ![self validColumn:step.sourceColumn] || ![self validColumn:step.destinationColumn]) return @"";
    return [NSString stringWithFormat:@"%@ %@ → %@　・　%@ %@ → %@",
            [self placeNameForColumn:step.sourceColumn], step.workingDigitsBefore[step.sourceColumn], step.workingDigits[step.sourceColumn],
            [self placeNameForColumn:step.destinationColumn], step.workingDigitsBefore[step.destinationColumn], step.workingDigits[step.destinationColumn]];
}

- (void)updateSpokenSummary {
    ArithmeticTeachingStep *step = self.currentStep;
    ArithmeticProblem *problem = self.sequence.problem;
    NSString *spokenProblem = [NSString stringWithFormat:@"%ld %@ %ld。", (long)problem.number1,
                               [problem.operatorSymbol isEqualToString:@"+"] ? @"加" : @"減", (long)problem.number2];
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObjects:spokenProblem, step.explanation, nil];
    if (step.kind == ArithmeticTeachingStepKindPrediction && step.prompt.length) [parts addObject:step.prompt];
    if (step.kind == ArithmeticTeachingStepKindRegroup) [parts addObject:[self exchangeCountsText]];
    NSMutableArray<NSString *> *written = [NSMutableArray array];
    for (NSInteger column = 0; column < self.sequence.columnCount; column++) {
        id digit = step.visibleAnswerDigits[column];
        if ([digit isKindOfClass:NSNumber.class]) [written addObject:[NSString stringWithFormat:@"%@寫 %@", [self placeNameForColumn:column], digit]];
    }
    [parts addObject:written.count ? [written componentsJoinedByString:@"，"] : @"答案還沒寫，先看這一步。"];
    self.accessibilityValue = [parts componentsJoinedByString:@" "];
}

#pragma mark - Width-aware layout

- (UIFont *)bodyFont {
    return [ChildUI scaledRoundedFontOfSize:18 weight:UIFontWeightMedium textStyle:UIFontTextStyleBody maximumPointSize:30];
}

- (CGFloat)heightForText:(NSString *)text font:(UIFont *)font width:(CGFloat)width {
    if (!text.length || width <= 0) return 0;
    return ceil([text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                             attributes:@{NSFontAttributeName:font} context:nil].size.height);
}

- (VABMetrics)metricsForWidth:(CGFloat)width {
    VABMetrics m = {0};
    m.width = MAX(1, width);
    if (!self.currentStep) return m;
    CGFloat textWidth = MAX(1, width - 2 * VABInset);
    UIFont *headingFont = [ChildUI scaledRoundedFontOfSize:15 weight:UIFontWeightBold textStyle:UIFontTextStyleCaption1 maximumPointSize:20];
    CGFloat numberScale = MIN(1.45, [UIFontMetrics.defaultMetrics scaledValueForValue:1]);
    m.headingHeight = ceil(headingFont.lineHeight + 8);
    m.annotationHeight = ceil(28 * numberScale) + 18; // Includes a dedicated exchange-arrow lane.
    m.operandHeight = ceil(40 * numberScale);
    m.answerHeight = ceil(44 * numberScale);
    m.gridHeight = m.headingHeight + m.annotationHeight + m.operandHeight * 2 + 10 + m.answerHeight;
    m.illustrationHeight = 0;
    if (self.currentStep.kind == ArithmeticTeachingStepKindRegroup) {
        m.illustrationHeight = 110 + [self heightForText:[self exchangeCountsText] font:self.bodyFont width:textWidth - 20];
    } else if ([self validColumn:self.currentStep.activeColumn] && self.currentStep.kind != ArithmeticTeachingStepKindPrediction) {
        m.illustrationHeight = 100 + [self heightForText:[self illustrationTitle] font:self.bodyFont width:textWidth - 20];
    }
    m.height = VABInset + m.gridHeight + (m.illustrationHeight ? 12 + m.illustrationHeight : 0) + VABInset;
    return m;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat width = isfinite(size.width) && size.width > 0 ? size.width : MAX(1, CGRectGetWidth(self.bounds));
    return CGSizeMake(width, [self metricsForWidth:width].height);
}

- (CGRect)currentConcreteTransformationRect {
    if (!self.currentStep || self.currentStep.kind != ArithmeticTeachingStepKindRegroup || !self.illustrationView) return CGRectNull;
    return [self.illustrationView convertRect:self.illustrationView.bounds toView:self];
}

- (CGRect)currentTransformationRect {
    CGRect concrete = self.currentConcreteTransformationRect;
    if (CGRectIsNull(concrete) || !self.gridView) return CGRectNull;
    CGRect grid = [self.gridView convertRect:self.gridView.bounds toView:self];
    return CGRectUnion(grid, concrete);
}

- (CGSize)intrinsicContentSize {
    CGFloat width = CGRectGetWidth(self.bounds);
    return CGSizeMake(UIViewNoIntrinsicMetric, width > 0 ? [self sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height : UIViewNoIntrinsicMetric);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL widthChanged = self.renderedSize.width != CGRectGetWidth(self.bounds);
    BOOL resized = !CGSizeEqualToSize(self.renderedSize, self.bounds.size);
    if (resized) [self cancelAnimations];
    if (!resized && !self.needsSnapshotLayout) return;
    self.renderedSize = self.bounds.size;
    if (widthChanged) [self invalidateIntrinsicContentSize];
    self.needsSnapshotLayout = NO;
    [self rebuildSnapshot];
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font identifier:(NSString *)identifier {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = ChildUI.brownText;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.85;
    label.isAccessibilityElement = NO;
    label.accessibilityIdentifier = identifier;
    return label;
}

- (void)rebuildSnapshot {
    [self clearSnapshot];
    if (!self.currentStep || CGRectGetWidth(self.bounds) <= 0) return;
    VABMetrics m = [self metricsForWidth:CGRectGetWidth(self.bounds)];
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, m.width, m.height)];
    self.contentView.accessibilityElementsHidden = YES;
    [self addSubview:self.contentView];
    CGFloat availableWidth = MAX(1, m.width - 2 * VABInset);
    CGFloat gridWidth = MIN(availableWidth, self.sequence.columnCount * 78 + 26);
    self.gridView = [[UIView alloc] initWithFrame:CGRectMake((m.width - gridWidth) / 2, VABInset, gridWidth, m.gridHeight)];
    self.gridView.accessibilityIdentifier = @"verticalTeachingGrid";
    [self.contentView addSubview:self.gridView];
    CGFloat operatorWidth = MIN(26, gridWidth * 0.12);
    CGFloat cellWidth = (gridWidth - operatorWidth) / self.sequence.columnCount;
    CGFloat numberSize = MIN(m.operandHeight * 0.72, cellWidth * 0.74);
    UIFont *numberFont = [ChildUI roundedMonoFontOfSize:numberSize weight:UIFontWeightSemibold];
    UIFont *annotationFont = [ChildUI roundedMonoFontOfSize:MIN(28, cellWidth * 0.58) weight:UIFontWeightBold];
    UIFont *headingFont = [ChildUI scaledRoundedFontOfSize:15 weight:UIFontWeightBold textStyle:UIFontTextStyleCaption1 maximumPointSize:20];
    CGFloat annotationY = m.headingHeight + 18;
    CGFloat firstY = m.headingHeight + m.annotationHeight;
    CGFloat secondY = firstY + m.operandHeight;
    CGFloat lineY = secondY + m.operandHeight + 4;
    CGFloat answerY = secondY + m.operandHeight + 10;
    BOOL addition = [self.sequence.problem.operatorSymbol isEqualToString:@"+"];
    ArithmeticTeachingStep *step = self.currentStep;

    for (NSInteger column = 0; column < self.sequence.columnCount; column++) {
        CGFloat x = operatorWidth + column * cellWidth;
        CGRect columnFrame = CGRectMake(x + 2, 0, MAX(1, cellWidth - 4), m.gridHeight);
        [self.columnFrames addObject:[NSValue valueWithCGRect:columnFrame]];
        if (column == step.activeColumn || (step.kind == ArithmeticTeachingStepKindRegroup && (column == step.sourceColumn || column == step.destinationColumn))) {
            UIView *focus = [[UIView alloc] initWithFrame:columnFrame];
            focus.backgroundColor = [(column == step.sourceColumn ? ChildUI.pumpkinOrange : ChildUI.skyBlue) colorWithAlphaComponent:0.20];
            focus.layer.cornerRadius = 14;
            focus.layer.borderColor = [ChildUI.brownText colorWithAlphaComponent:0.28].CGColor;
            focus.layer.borderWidth = 1;
            focus.accessibilityIdentifier = [NSString stringWithFormat:@"verticalFocus%ld", (long)column];
            [self.gridView addSubview:focus];
        }
        UILabel *heading = [self labelWithText:[self placeNameForColumn:column] font:headingFont identifier:[NSString stringWithFormat:@"verticalPlace%ld", (long)column]];
        heading.frame = CGRectMake(x, 0, cellWidth, m.headingHeight);
        [self.gridView addSubview:heading];

        NSString *annotation = @"";
        BOOL rewritten = !addition && ![step.workingDigits[column] isEqual:step.firstDigits[column]];
        if (rewritten) annotation = step.workingDigits[column].stringValue;
        else if (addition && step.carryDigits[column].integerValue > 0) annotation = [NSString stringWithFormat:@"+%@", step.carryDigits[column]];
        else if (addition && column == step.activeColumn &&
                 (step.kind == ArithmeticTeachingStepKindColumnCalculation || step.kind == ArithmeticTeachingStepKindRegroup)) annotation = step.workingDigits[column].stringValue;
        UILabel *rewrite = [self labelWithText:annotation font:annotationFont identifier:[NSString stringWithFormat:@"verticalWorking%ld", (long)column]];
        rewrite.frame = CGRectMake(x + 2, annotationY, MAX(1, cellWidth - 4), m.annotationHeight - 18);
        if (annotation.length) {
            rewrite.backgroundColor = [ChildUI.eggYolk colorWithAlphaComponent:0.40];
            rewrite.layer.cornerRadius = 10;
            rewrite.clipsToBounds = YES;
        }
        [self.annotationLabels addObject:rewrite];
        [self.gridView addSubview:rewrite];

        NSString *firstText = column >= self.sequence.firstOperandStartColumn ? step.firstDigits[column].stringValue : @"";
        UILabel *first = [self labelWithText:firstText font:numberFont identifier:[NSString stringWithFormat:@"verticalFirst%ld", (long)column]];
        first.frame = CGRectMake(x, firstY, cellWidth, m.operandHeight);
        if (rewritten && firstText.length) first.attributedText = [[NSAttributedString alloc] initWithString:firstText attributes:@{NSStrikethroughStyleAttributeName:@(NSUnderlineStyleSingle), NSForegroundColorAttributeName:[ChildUI.brownText colorWithAlphaComponent:0.65]}];
        [self.gridView addSubview:first];
        UILabel *second = [self labelWithText:column >= self.sequence.secondOperandStartColumn ? step.secondDigits[column].stringValue : @"" font:numberFont identifier:[NSString stringWithFormat:@"verticalSecond%ld", (long)column]];
        second.frame = CGRectMake(x, secondY, cellWidth, m.operandHeight);
        [self.gridView addSubview:second];

        id answerDigit = step.visibleAnswerDigits[column];
        // No access to problem.answer or expectedAnswer: only explicitly written cells.
        UILabel *answer = [self labelWithText:[answerDigit isKindOfClass:NSNumber.class] ? [answerDigit stringValue] : @"" font:numberFont identifier:[NSString stringWithFormat:@"verticalAnswer%ld", (long)column]];
        answer.frame = CGRectMake(x, answerY, cellWidth, m.answerHeight);
        [self.answerLabels addObject:answer];
        [self.gridView addSubview:answer];
        if (![answerDigit isKindOfClass:NSNumber.class] && column >= self.sequence.answerStartColumn) {
            UIView *placeholder = [[UIView alloc] initWithFrame:CGRectMake(x + cellWidth * 0.31, answerY + m.answerHeight * 0.76, cellWidth * 0.38, 2)];
            placeholder.backgroundColor = [ChildUI.brownText colorWithAlphaComponent:0.25];
            placeholder.accessibilityIdentifier = [NSString stringWithFormat:@"verticalBlank%ld", (long)column];
            [self.gridView addSubview:placeholder];
        }
    }
    UILabel *operator = [self labelWithText:addition ? @"+" : @"−" font:numberFont identifier:@"verticalOperator"];
    operator.frame = CGRectMake(0, secondY, operatorWidth, m.operandHeight);
    [self.gridView addSubview:operator];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, lineY, gridWidth, 2)];
    line.backgroundColor = ChildUI.brownText;
    [self.gridView addSubview:line];
    if (step.kind == ArithmeticTeachingStepKindRegroup) [self addExchangeArrowAtY:m.headingHeight + 9];

    CGFloat y = CGRectGetMaxY(self.gridView.frame) + 12;
    if (m.illustrationHeight > 0) {
        self.illustrationView = [[UIView alloc] initWithFrame:CGRectMake(VABInset, y, availableWidth, m.illustrationHeight)];
        self.illustrationView.backgroundColor = [ChildUI.mintGreen colorWithAlphaComponent:0.18];
        self.illustrationView.layer.cornerRadius = 16;
        self.illustrationView.accessibilityIdentifier = @"verticalUnitIllustration";
        [self.contentView addSubview:self.illustrationView];
        if (step.kind == ArithmeticTeachingStepKindRegroup) [self buildExchangeIllustration];
        else [self buildColumnIllustration];
    }
}

- (void)addExchangeArrowAtY:(CGFloat)y {
    ArithmeticTeachingStep *step = self.currentStep;
    if (![self validColumn:step.sourceColumn] || ![self validColumn:step.destinationColumn]) return;
    CGFloat start = CGRectGetMidX(self.columnFrames[step.sourceColumn].CGRectValue);
    CGFloat end = CGRectGetMidX(self.columnFrames[step.destinationColumn].CGRectValue);
    CGFloat direction = end > start ? 1 : -1;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(start, y)];
    [path addLineToPoint:CGPointMake(end - 5 * direction, y)];
    [path moveToPoint:CGPointMake(end - 11 * direction, y - 4)];
    [path addLineToPoint:CGPointMake(end - 5 * direction, y)];
    [path addLineToPoint:CGPointMake(end - 11 * direction, y + 4)];
    CAShapeLayer *arrow = [CAShapeLayer layer];
    arrow.path = path.CGPath;
    arrow.strokeColor = ChildUI.brownText.CGColor;
    arrow.fillColor = UIColor.clearColor.CGColor;
    arrow.lineWidth = 2;
    arrow.name = @"verticalExchangeArrow";
    [self.gridView.layer addSublayer:arrow];
}

#pragma mark - Bounded, meaningful concrete units

- (NSArray<VABUnitView *> *)addUnits:(NSInteger)count column:(NSInteger)column inRect:(CGRect)rect parent:(UIView *)parent color:(UIColor *)color crossingFrom:(NSInteger)crossingFrom {
    NSMutableArray<VABUnitView *> *units = [NSMutableArray array];
    NSInteger boundedCount = MIN(20, MAX(0, count));
    NSInteger place = self.sequence.columnCount - 1 - column;
    // A compact ten-frame keeps small dots/blocks countable on a 320 pt phone;
    // rods stay in one row so their ten segments remain visible.
    NSInteger maximumColumns = rect.size.width < 180 && place != 1 ? 5 : 10;
    NSInteger columns = MIN(maximumColumns, MAX(1, boundedCount));
    NSInteger rows = MAX(1, (boundedCount + columns - 1) / columns);
    CGFloat slotWidth = rect.size.width / columns;
    CGFloat slotHeight = rect.size.height / rows;
    for (NSInteger i = 0; i < boundedCount; i++) {
        CGFloat width = MAX(1, MIN(place == 1 ? 13 : 22, slotWidth - 3));
        CGFloat height = place == 1 ? MIN(40, slotHeight - 4) : MIN(width, slotHeight - 4);
        VABUnitView *unit = [[VABUnitView alloc] initWithFrame:CGRectMake(rect.origin.x + (i % columns) * slotWidth + (slotWidth - width) / 2, rect.origin.y + (i / columns) * slotHeight + (slotHeight - height) / 2, width, height)];
        unit.backgroundColor = UIColor.clearColor;
        unit.place = place;
        unit.unitColor = color;
        unit.crossedOut = crossingFrom != NSNotFound && i >= crossingFrom;
        unit.isAccessibilityElement = NO;
        [parent addSubview:unit];
        [units addObject:unit];
    }
    return units;
}

- (void)buildExchangeIllustration {
    ArithmeticTeachingStep *step = self.currentStep;
    if (![self validColumn:step.sourceColumn] || ![self validColumn:step.destinationColumn]) return;
    CGFloat width = CGRectGetWidth(self.illustrationView.bounds);
    CGFloat half = (width - 48) / 2;
    BOOL carriesLeft = step.destinationColumn < step.sourceColumn;
    NSInteger sourceCount = carriesLeft ? 10 : 1;
    NSInteger destinationCount = carriesLeft ? 1 : 10;
    NSString *sourceText = [NSString stringWithFormat:@"%ld 個%@", (long)sourceCount, [self unitNameForColumn:step.sourceColumn]];
    NSString *destinationText = [NSString stringWithFormat:@"%ld 個%@", (long)destinationCount, [self unitNameForColumn:step.destinationColumn]];
    UIFont *font = [ChildUI scaledRoundedFontOfSize:17 weight:UIFontWeightBold textStyle:UIFontTextStyleCallout maximumPointSize:24];
    UILabel *source = [self labelWithText:sourceText font:font identifier:@"verticalExchangeSource"];
    source.frame = CGRectMake(10, 10, half, 30);
    [self.illustrationView addSubview:source];
    UILabel *destination = [self labelWithText:destinationText font:font identifier:@"verticalExchangeDestination"];
    destination.frame = CGRectMake(width - half - 10, 10, half, 30);
    [self.illustrationView addSubview:destination];
    UILabel *equals = [self labelWithText:@"=" font:[ChildUI roundedFontOfSize:25 weight:UIFontWeightBold] identifier:@"verticalExchangeEquals"];
    equals.frame = CGRectMake(width / 2 - 16, 40, 32, 40);
    [self.illustrationView addSubview:equals];
    [self.exchangeSourceUnits addObjectsFromArray:[self addUnits:sourceCount column:step.sourceColumn inRect:CGRectMake(10, 40, half, 44) parent:self.illustrationView color:ChildUI.pumpkinOrange crossingFrom:NSNotFound]];
    [self.exchangeDestinationUnits addObjectsFromArray:[self addUnits:destinationCount column:step.destinationColumn inRect:CGRectMake(width - half - 10, 40, half, 44) parent:self.illustrationView color:ChildUI.skyBlue crossingFrom:NSNotFound]];
    UILabel *counts = [self labelWithText:[self exchangeCountsText] font:self.bodyFont identifier:@"verticalExchangeCounts"];
    counts.numberOfLines = 0;
    counts.adjustsFontSizeToFitWidth = NO;
    counts.frame = CGRectMake(10, 92, width - 20, CGRectGetHeight(self.illustrationView.bounds) - 102);
    [self.illustrationView addSubview:counts];
}

- (NSString *)illustrationTitle {
    ArithmeticTeachingStep *step = self.currentStep;
    if (![self validColumn:step.activeColumn]) return @"";
    NSString *unit = [self unitNameForColumn:step.activeColumn];
    if ([self.sequence.problem.operatorSymbol isEqualToString:@"+"]) {
        return [NSString stringWithFormat:@"%@：現在有 %@ 個%@", [self placeNameForColumn:step.activeColumn], step.workingDigits[step.activeColumn], unit];
    }
    return [NSString stringWithFormat:@"%@：%@ 個%@，拿走 %@ 個", [self placeNameForColumn:step.activeColumn], step.workingDigits[step.activeColumn], unit, step.secondDigits[step.activeColumn]];
}

- (void)buildColumnIllustration {
    ArithmeticTeachingStep *step = self.currentStep;
    NSInteger column = step.activeColumn;
    if (![self validColumn:column]) return;
    CGFloat width = CGRectGetWidth(self.illustrationView.bounds);
    NSString *title = [self illustrationTitle];
    CGFloat titleHeight = [self heightForText:title font:self.bodyFont width:width - 20];
    UILabel *label = [self labelWithText:title font:self.bodyFont identifier:@"verticalUnitCount"];
    label.numberOfLines = 0;
    label.adjustsFontSizeToFitWidth = NO;
    label.frame = CGRectMake(10, 10, width - 20, titleHeight);
    [self.illustrationView addSubview:label];
    BOOL addition = [self.sequence.problem.operatorSymbol isEqualToString:@"+"];
    NSInteger count = step.workingDigits[column].integerValue;
    NSInteger crossingFrom = !addition && step.columnValue ? step.columnValue.integerValue : NSNotFound;
    [self addUnits:count column:column inRect:CGRectMake(12, 18 + titleHeight, width - 24, 68) parent:self.illustrationView color:ChildUI.mintGreen crossingFrom:crossingFrom];
}

#pragma mark - One finite action, no automatic advancement

- (BOOL)canAnimate {
    if (!ChildUI.motionEnabled || !self.window || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    for (UIView *view = self; view; view = view.superview) if (view.hidden || view.alpha <= 0.01) return NO;
    return YES;
}

- (void)addAnimation:(CAAnimation *)animation toLayer:(CALayer *)layer key:(NSString *)key {
    animation.removedOnCompletion = YES;
    [layer addAnimation:animation forKey:key];
    [self.animatedLayers addObject:layer];
}

- (void)animateCurrentAction {
    if (CGRectGetWidth(self.bounds) <= 0 || CGRectGetHeight(self.bounds) <= 0) return;
    ArithmeticTeachingStep *step = self.currentStep;
    if (step.kind == ArithmeticTeachingStepKindRegroup) [self animateExchange];
    else if (step.kind == ArithmeticTeachingStepKindWriteAnswer && [self validColumn:step.activeColumn] &&
             step.activeColumn < (NSInteger)self.answerLabels.count) {
        UILabel *answer = self.answerLabels[step.activeColumn];
        if (!answer.text.length) return;
        CAKeyframeAnimation *press = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        press.values = @[@0.88, @1.08, @1];
        press.duration = 0.38;
        [self addAnimation:press toLayer:answer.layer key:@"verticalAnswerWrite"];
    }
    if (!self.animatedLayers.count) return;
    self.animationEndTime = CACurrentMediaTime() + VABExchangeDuration;
    VABWeakDisplayLinkTarget *proxy = [VABWeakDisplayLinkTarget new];
    proxy.target = self;
    self.animationDisplayLink = [CADisplayLink displayLinkWithTarget:proxy selector:@selector(tick:)];
    [self.animationDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)animateExchange {
    ArithmeticTeachingStep *step = self.currentStep;
    if (![self validColumn:step.sourceColumn] || ![self validColumn:step.destinationColumn] || self.annotationLabels.count != self.sequence.columnCount) return;
    UILabel *source = self.annotationLabels[step.sourceColumn];
    UILabel *destination = self.annotationLabels[step.destinationColumn];
    CGPoint from = [self.gridView convertPoint:source.center toView:self.contentView];
    CGPoint to = [self.gridView convertPoint:destination.center toView:self.contentView];
    BOOL carriesLeft = step.destinationColumn < step.sourceColumn;
    NSString *packetText = [NSString stringWithFormat:@"%@%@", carriesLeft ? @"10" : @"1", [self unitNameForColumn:step.sourceColumn]];
    UILabel *packet = [self labelWithText:packetText font:[ChildUI roundedMonoFontOfSize:16 weight:UIFontWeightBold] identifier:@"verticalMovingExchange"];
    packet.frame = CGRectMake(0, 0, 44, 30);
    packet.center = to;
    packet.backgroundColor = ChildUI.eggYolk;
    packet.layer.cornerRadius = 10;
    packet.clipsToBounds = YES;
    packet.alpha = 0; // Model state has no transient packet; cancellation is always safe.
    [self.contentView addSubview:packet];
    [self.transientViews addObject:packet];
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:from];
    [path addQuadCurveToPoint:to controlPoint:CGPointMake((from.x + to.x) / 2, MIN(from.y, to.y) - 32)];
    CAKeyframeAnimation *travel = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    travel.path = path.CGPath;
    travel.duration = 0.62;
    travel.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    CAKeyframeAnimation *visibility = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    visibility.values = @[@1, @1, @0];
    visibility.keyTimes = @[@0, @0.72, @1];
    visibility.duration = VABExchangeDuration;
    CAAnimationGroup *packetGroup = [CAAnimationGroup animation];
    packetGroup.animations = @[travel, visibility];
    packetGroup.duration = VABExchangeDuration;
    [self addAnimation:packetGroup toLayer:packet.layer key:@"verticalUnitTransfer"];

    // The concrete equality remains visible at rest. During exchange the ten
    // small pieces visibly collect into one larger unit, or one splits into ten.
    CGPoint sourceCenter = CGPointMake(0, 0);
    for (VABUnitView *unit in self.exchangeSourceUnits) { sourceCenter.x += unit.center.x; sourceCenter.y += unit.center.y; }
    if (self.exchangeSourceUnits.count) { sourceCenter.x /= self.exchangeSourceUnits.count; sourceCenter.y /= self.exchangeSourceUnits.count; }
    for (VABUnitView *unit in self.exchangeDestinationUnits) {
        if (carriesLeft) break;
        CABasicAnimation *move = [CABasicAnimation animationWithKeyPath:@"position"];
        move.fromValue = [NSValue valueWithCGPoint:sourceCenter];
        move.toValue = [NSValue valueWithCGPoint:unit.center];
        move.duration = 0.76;
        move.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self addAnimation:move toLayer:unit.layer key:@"verticalConcreteExchange"];
    }
    if (carriesLeft && self.exchangeDestinationUnits.count) {
        CGPoint destinationCenter = self.exchangeDestinationUnits.firstObject.center;
        for (VABUnitView *unit in self.exchangeSourceUnits) {
            CABasicAnimation *gather = [CABasicAnimation animationWithKeyPath:@"position"];
            gather.fromValue = [NSValue valueWithCGPoint:unit.center];
            gather.toValue = [NSValue valueWithCGPoint:destinationCenter];
            gather.duration = 0.68;
            gather.fillMode = kCAFillModeForwards;
            gather.removedOnCompletion = NO;
            CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
            fade.values = @[@1, @1, @0];
            fade.keyTimes = @[@0, @0.68, @1];
            fade.duration = VABExchangeDuration;
            CAAnimationGroup *group = [CAAnimationGroup animation];
            group.animations = @[gather, fade];
            group.duration = VABExchangeDuration;
            [self addAnimation:group toLayer:unit.layer key:@"verticalConcreteGather"];
        }
        CAKeyframeAnimation *bundle = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        bundle.values = @[@0.7, @0.7, @1.12, @1];
        bundle.keyTimes = @[@0, @0.55, @0.78, @1];
        bundle.duration = VABExchangeDuration;
        [self addAnimation:bundle toLayer:self.exchangeDestinationUnits.firstObject.layer key:@"verticalCountChange"];
    }
    for (NSNumber *columnNumber in @[@(step.sourceColumn), @(step.destinationColumn)]) {
        NSInteger column = columnNumber.integerValue;
        UILabel *label = self.annotationLabels[column];
        // The model layer is already the correct after-state. A disposable before
        // label stays until the unit arrives; cancelling simply removes this veil.
        NSString *beforeText = carriesLeft && column == step.destinationColumn ? @"" : step.workingDigitsBefore[column].stringValue;
        UILabel *before = [self labelWithText:beforeText font:label.font identifier:@"verticalBeforeExchange"];
        before.frame = label.frame;
        before.backgroundColor = self.backgroundColor;
        before.layer.cornerRadius = 10;
        before.clipsToBounds = YES;
        before.alpha = 0;
        [self.gridView addSubview:before];
        [self.transientViews addObject:before];
        CAKeyframeAnimation *oldCount = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        oldCount.values = @[@1, @1, @0];
        oldCount.keyTimes = @[@0, @0.60, @1];
        oldCount.duration = VABExchangeDuration;
        [self addAnimation:oldCount toLayer:before.layer key:@"verticalBeforeCount"];
        CAKeyframeAnimation *newCount = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        newCount.values = @[@0, @0, @1];
        newCount.keyTimes = @[@0, @0.60, @1];
        newCount.duration = VABExchangeDuration;
        [self addAnimation:newCount toLayer:label.layer key:@"verticalAfterCount"];
        CAKeyframeAnimation *emphasis = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        emphasis.values = @[@1, @1, @1.12, @1];
        emphasis.keyTimes = @[@0, @0.55, @0.76, @1];
        emphasis.duration = VABExchangeDuration;
        [self addAnimation:emphasis toLayer:label.layer key:@"verticalCountChange"];
    }
}

- (void)animationTick:(CADisplayLink *)link {
    if (CACurrentMediaTime() >= self.animationEndTime || ![self canAnimate]) [self cancelAnimations];
}

- (void)cancelAnimations {
    [self.animationDisplayLink invalidate];
    self.animationDisplayLink = nil;
    for (CALayer *layer in self.animatedLayers) {
        [layer removeAnimationForKey:@"verticalAnswerWrite"];
        [layer removeAnimationForKey:@"verticalUnitTransfer"];
        [layer removeAnimationForKey:@"verticalConcreteExchange"];
        [layer removeAnimationForKey:@"verticalConcreteGather"];
        [layer removeAnimationForKey:@"verticalCountChange"];
        [layer removeAnimationForKey:@"verticalBeforeCount"];
        [layer removeAnimationForKey:@"verticalAfterCount"];
    }
    [self.animatedLayers removeAllObjects];
    for (UIView *view in self.transientViews) [view removeFromSuperview];
    [self.transientViews removeAllObjects];
    self.animationEndTime = 0;
}

- (void)stopForNotification:(NSNotification *)notification { [self cancelAnimations]; }
- (void)contentSizeChanged:(NSNotification *)notification {
    [self cancelAnimations];
    self.needsSnapshotLayout = YES;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}
- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) [self cancelAnimations]; }
- (void)didMoveToSuperview { [super didMoveToSuperview]; if (!self.superview) [self cancelAnimations]; }
- (void)setHidden:(BOOL)hidden { [super setHidden:hidden]; if (hidden) [self cancelAnimations]; }
- (void)setAlpha:(CGFloat)alpha { [super setAlpha:alpha]; if (alpha <= 0.01) [self cancelAnimations]; }
@end
