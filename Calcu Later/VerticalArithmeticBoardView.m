#import "VerticalArithmeticBoardView.h"
#import "ChildUIKit.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <stdlib.h>

static const NSTimeInterval VABExchangeDuration = 0.88;
static const CGFloat VABInset = 16.0;
static const CGFloat VABUnitGap = 6.0;
static const CGFloat VABExchangeHandoff = 0.5;
// The 28 pt sign has its own lane, outside both 4 pt outline outsets.
static const CGFloat VABExchangeLane = 40.0;

/// These are the selected working columns, not all operands in the problem.
/// Carry annotations are already included in workingDigits and are never added.
typedef struct {
    BOOL valid;
    NSInteger sourceBefore;
    NSInteger sourceAfter;
    NSInteger destinationBefore;
    NSInteger destinationAfter;
    NSInteger exchangedSource;
    NSInteger exchangedDestination;
} VABExchangeQuantities;

typedef struct {
    CGRect scope;
    CGRect mode;
    CGRect sourceLabel;
    CGRect destinationLabel;
    CGRect sourceUnits;
    CGRect destinationUnits;
    CGRect sign;
    CGRect retainedSourceLabel;
    CGRect retainedDestinationLabel;
    CGRect retainedSourceUnits;
    CGRect retainedDestinationUnits;
    CGRect counts;
    CGFloat height;
} VABExchangeLayout;

static NSInteger VABPlaceValue(NSInteger place) {
    NSInteger value = 1;
    for (NSInteger index = 0; index < place; index++) value *= 10;
    return value;
}

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
@property (nonatomic, strong) NSMutableArray<VABUnitView *> *retainedSourceUnits;
@property (nonatomic, strong) NSMutableArray<VABUnitView *> *retainedDestinationUnits;
@property (nonatomic, strong) UILabel *exchangeModeLabel;
@property (nonatomic, strong) UILabel *exchangeEqualsLabel;
@property (nonatomic, strong) CAShapeLayer *exchangeSourceOutline;
@property (nonatomic, strong) CAShapeLayer *exchangeDestinationOutline;
@property (nonatomic) CFTimeInterval exchangeAnimationStartTime;
@property (nonatomic, strong) NSMutableArray<CALayer *> *animatedLayers;
@property (nonatomic, strong) NSMutableArray<UIView *> *transientViews;
@property (nonatomic, strong, nullable) CADisplayLink *animationDisplayLink;
@property (nonatomic) CFTimeInterval animationEndTime;
@property (nonatomic) CGSize renderedSize;
@property (nonatomic) BOOL needsSnapshotLayout;
@property (nonatomic) BOOL playsWrittenExchange;
@property (nonatomic) BOOL requiresVisiblePlayback;
@property (nonatomic, assign, readwrite) VerticalArithmeticPlaybackState playbackState;
@property (nonatomic, strong) UIAccessibilityElement *summaryElement;
@property (nonatomic, strong) UIAccessibilityElement *concreteElement;
- (void)animationTick:(CADisplayLink *)link;
- (VABExchangeQuantities)exchangeQuantities;
- (VABExchangeLayout)exchangeLayoutForWidth:(CGFloat)width;
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
    _retainedSourceUnits = [NSMutableArray array];
    _retainedDestinationUnits = [NSMutableArray array];
    _animatedLayers = [NSMutableArray array];
    _transientViews = [NSMutableArray array];
    self.backgroundColor = ChildUI.creamBackground;
    self.layer.cornerRadius = 24;
    self.clipsToBounds = YES;
    self.accessibilityIdentifier = @"verticalTeachingBoardContainer";
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
    // Replay of the same immutable snapshot must not replace unchanged objects.
    // A real width/trait change still requests a new measured layout.
    BOOL sameSnapshot = self.sequence == sequence && self.currentStep == sequence.steps[stepIndex] && self.contentView;
    self.playbackState = VerticalArithmeticPlaybackStateStill;
    self.playsWrittenExchange = YES;
    self.requiresVisiblePlayback = NO;
    self.sequence = sequence;
    self.currentStepIndex = stepIndex;
    self.currentStep = sequence.steps[stepIndex];
    self.isAccessibilityElement = NO;
    [self updateSpokenSummary];
    self.needsSnapshotLayout = self.needsSnapshotLayout || !sameSnapshot;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    // The convenience path must obey the same full-material admission as the
    // controller-owned playback path, including newly added retained rows.
    if (animated) [self playCurrentActionInVisibleRect:self.bounds];
    return YES;
}

- (BOOL)showStepAtIndex:(NSInteger)stepIndex animated:(BOOL)animated {
    return [self configureWithSequence:self.sequence stepIndex:stepIndex animated:animated];
}

- (void)clearSnapshot {
    self.summaryElement = nil;
    self.concreteElement = nil;
    [self.contentView removeFromSuperview];
    self.contentView = nil;
    self.gridView = nil;
    self.illustrationView = nil;
    [self.annotationLabels removeAllObjects];
    [self.answerLabels removeAllObjects];
    [self.columnFrames removeAllObjects];
    [self.exchangeSourceUnits removeAllObjects];
    [self.exchangeDestinationUnits removeAllObjects];
    [self.retainedSourceUnits removeAllObjects];
    [self.retainedDestinationUnits removeAllObjects];
    self.exchangeModeLabel = nil;
    self.exchangeEqualsLabel = nil;
    self.exchangeSourceOutline = nil;
    self.exchangeDestinationOutline = nil;
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
    if (step.kind == ArithmeticTeachingStepKindRegroup) {
        [parts addObject:[self exchangeScopeText]];
        [parts addObject:[self exchangeCountsText]];
        [parts addObject:[self retainedSourceText]];
        [parts addObject:[self retainedDestinationText]];
    }
    NSMutableArray<NSString *> *written = [NSMutableArray array];
    for (NSInteger column = 0; column < self.sequence.columnCount; column++) {
        id digit = step.visibleAnswerDigits[column];
        if ([digit isKindOfClass:NSNumber.class]) [written addObject:[NSString stringWithFormat:@"%@寫 %@", [self placeNameForColumn:column], digit]];
    }
    [parts addObject:written.count ? [written componentsJoinedByString:@"，"] : @"答案還沒寫，先看這一步。"];
    self.accessibilityValue = [parts componentsJoinedByString:@" "];
}

- (BOOL)isPlaying { return self.playbackState == VerticalArithmeticPlaybackStatePlaying; }

- (NSString *)playbackDescription {
    switch (self.playbackState) {
        case VerticalArithmeticPlaybackStatePlaying: return @"正在交換";
        case VerticalArithmeticPlaybackStateCompleted: return @"動態已播放完成";
        case VerticalArithmeticPlaybackStateInterrupted: return @"動態已暫停，停在這一步";
        case VerticalArithmeticPlaybackStateReducedMotion: return @"減少動態，直接看這一步";
        case VerticalArithmeticPlaybackStateStill: return @"停在這一步";
    }
}

- (void)setPlaybackState:(VerticalArithmeticPlaybackState)playbackState {
    _playbackState = playbackState;
    self.concreteElement.accessibilityValue = [NSString stringWithFormat:@"%@。%@。%@。%@。%@", [self exchangeScopeText], [self exchangeCountsText], [self retainedSourceText], [self retainedDestinationText], [self playbackDescription]];
}

- (NSArray *)accessibilityElements {
    if (!self.currentStep) return @[];
    if (!self.summaryElement) self.summaryElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
    self.summaryElement.accessibilityIdentifier = @"verticalTeachingBoard";
    self.summaryElement.accessibilityLabel = self.accessibilityLabel;
    self.summaryElement.accessibilityValue = self.accessibilityValue;
    self.summaryElement.accessibilityLanguage = @"zh-TW";
    self.summaryElement.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.summaryElement.accessibilityFrameInContainerSpace = self.bounds;
    CGRect concrete = self.currentConcreteTransformationRect;
    if (CGRectIsNull(concrete) || CGRectIsEmpty(concrete)) return @[self.summaryElement];
    if (!self.concreteElement) self.concreteElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
    self.concreteElement.accessibilityIdentifier = @"verticalTeachingExchange";
    self.concreteElement.accessibilityLabel = @"這一步兩欄的交換與不動的數量";
    self.concreteElement.accessibilityValue = [NSString stringWithFormat:@"%@。%@。%@。%@。%@", [self exchangeScopeText], [self exchangeCountsText], [self retainedSourceText], [self retainedDestinationText], [self playbackDescription]];
    self.concreteElement.accessibilityLanguage = @"zh-TW";
    self.concreteElement.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.concreteElement.accessibilityFrameInContainerSpace = concrete;
    return @[self.summaryElement, self.concreteElement];
}

#pragma mark - Width-aware layout

- (UIFont *)bodyFont {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightMedium]
        maximumPointSize:30 compatibleWithTraitCollection:self.traitCollection];
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
        m.illustrationHeight = [self exchangeLayoutForWidth:textWidth].height;
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

- (CGRect)currentWrittenRect {
    return self.gridView ? [self.gridView convertRect:self.gridView.bounds toView:self] : CGRectNull;
}

- (CGRect)currentActionRect {
    if (self.currentStep.kind == ArithmeticTeachingStepKindRegroup) return self.currentConcreteTransformationRect;
    if (self.currentStep.kind == ArithmeticTeachingStepKindWriteAnswer && [self validColumn:self.currentStep.activeColumn]
        && self.currentStep.activeColumn < (NSInteger)self.answerLabels.count) {
        UILabel *answer = self.answerLabels[self.currentStep.activeColumn];
        // A deliberately omitted leading zero is explained, not written.
        if (!answer.text.length) return CGRectNull;
        return [answer convertRect:CGRectInset(answer.bounds, -5, -5) toView:self];
    }
    return CGRectNull;
}

- (CGRect)currentPlaybackRect {
    if (self.currentStep.kind == ArithmeticTeachingStepKindRegroup && self.playsWrittenExchange) return self.currentTransformationRect;
    return self.currentActionRect;
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

- (VABExchangeQuantities)exchangeQuantities {
    VABExchangeQuantities q = {0};
    ArithmeticTeachingStep *step = self.currentStep;
    if (step.kind != ArithmeticTeachingStepKindRegroup || ![self validColumn:step.sourceColumn]
        || ![self validColumn:step.destinationColumn] || labs(step.sourceColumn - step.destinationColumn) != 1
        || step.workingDigitsBefore.count != self.sequence.columnCount
        || step.workingDigits.count != self.sequence.columnCount) return q;
    q.sourceBefore = step.workingDigitsBefore[step.sourceColumn].integerValue;
    q.sourceAfter = step.workingDigits[step.sourceColumn].integerValue;
    q.destinationBefore = step.workingDigitsBefore[step.destinationColumn].integerValue;
    q.destinationAfter = step.workingDigits[step.destinationColumn].integerValue;
    // Valid canonical steps are bounded. Reject an inconsistent projection rather
    // than silently truncate it, invent material, or add a carry a second time.
    for (NSNumber *count in @[@(q.sourceBefore), @(q.sourceAfter), @(q.destinationBefore), @(q.destinationAfter)]) {
        if (count.integerValue < 0 || count.integerValue > 20) return q;
    }
    q.exchangedSource = q.sourceBefore - q.sourceAfter;
    q.exchangedDestination = q.destinationAfter - q.destinationBefore;
    NSInteger sourceValue = VABPlaceValue(self.sequence.columnCount - 1 - step.sourceColumn);
    NSInteger destinationValue = VABPlaceValue(self.sequence.columnCount - 1 - step.destinationColumn);
    q.valid = q.exchangedSource > 0 && q.exchangedDestination > 0
        && q.exchangedSource * sourceValue == q.exchangedDestination * destinationValue;
    return q;
}

- (UIFont *)exchangeFont {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
        scaledFontForFont:[ChildUI roundedFontOfSize:17 weight:UIFontWeightBold]
        maximumPointSize:24 compatibleWithTraitCollection:self.traitCollection];
}

- (UIFont *)exchangeScopeFont {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
        scaledFontForFont:[ChildUI roundedFontOfSize:15 weight:UIFontWeightMedium]
        maximumPointSize:22 compatibleWithTraitCollection:self.traitCollection];
}

- (NSString *)exchangeScopeText { return @"這一步兩欄，不是整題全部"; }
- (NSString *)exchangeComparisonText { return @"換前、換後比一比"; }
- (NSString *)exchangePlayingText { return @"圈起這一組，再換一換"; }

- (NSString *)exchangedSourceText {
    return [NSString stringWithFormat:@"%ld 個%@", (long)[self exchangeQuantities].exchangedSource,
        [self unitNameForColumn:self.currentStep.sourceColumn]];
}

- (NSString *)exchangedDestinationText {
    return [NSString stringWithFormat:@"%ld 個%@", (long)[self exchangeQuantities].exchangedDestination,
        [self unitNameForColumn:self.currentStep.destinationColumn]];
}

- (NSString *)retainedSourceText {
    return [NSString stringWithFormat:@"%@留下 %ld 個%@，不換", [self placeNameForColumn:self.currentStep.sourceColumn],
        (long)[self exchangeQuantities].sourceAfter, [self unitNameForColumn:self.currentStep.sourceColumn]];
}

- (NSString *)retainedDestinationText {
    return [NSString stringWithFormat:@"%@原有 %ld 個%@，不換", [self placeNameForColumn:self.currentStep.destinationColumn],
        (long)[self exchangeQuantities].destinationBefore, [self unitNameForColumn:self.currentStep.destinationColumn]];
}

- (CGSize)exchangeUnitSizeForColumn:(NSInteger)column {
    return self.sequence.columnCount - 1 - column == 1 ? CGSizeMake(13, 40) : CGSizeMake(22, 22);
}

- (NSInteger)exchangeUnitColumnsForCount:(NSInteger)count column:(NSInteger)column width:(CGFloat)width {
    CGSize unit = [self exchangeUnitSizeForColumn:column];
    return MIN(MAX(1, count), MAX(1, (NSInteger)floor((width + VABUnitGap) / (unit.width + VABUnitGap))));
}

- (CGFloat)exchangeUnitHeightForCount:(NSInteger)count column:(NSInteger)column width:(CGFloat)width {
    if (count == 0) return 0;
    NSInteger columns = [self exchangeUnitColumnsForCount:count column:column width:width];
    NSInteger rows = (count + columns - 1) / columns;
    return rows * [self exchangeUnitSizeForColumn:column].height + (rows - 1) * VABUnitGap;
}

- (CGFloat)unwrappedWidthForText:(NSString *)text font:(UIFont *)font {
    return ceil([text sizeWithAttributes:@{NSFontAttributeName:font}].width) + 1;
}

- (CGFloat)twoLineWidthForText:(NSString *)text font:(UIFont *)font {
    CGFloat upper = [self unwrappedWidthForText:text font:font];
    CGFloat lower = 1;
    CGFloat twoLines = 2 * [self heightForText:text font:font width:upper];
    // Find the actual wrapping boundary, rather than estimating CJK glyph widths.
    while (upper - lower > 1) {
        CGFloat width = floor((lower + upper) / 2);
        if ([self heightForText:text font:font width:width] <= twoLines) upper = width;
        else lower = width;
    }
    return ceil(upper);
}

- (CGFloat)shortRowWidthForCount:(NSInteger)count column:(NSInteger)column {
    if (count == 0) return 0;
    CGSize unit = [self exchangeUnitSizeForColumn:column];
    // Two rows of dots/blocks or one row of rods. Never compress a material unit.
    NSInteger rows = unit.height == 40 ? 1 : 2;
    NSInteger columns = (count + rows - 1) / rows;
    return columns * unit.width + (columns - 1) * VABUnitGap;
}

- (VABExchangeLayout)wideExchangeLayoutForWidth:(CGFloat)width {
    VABExchangeLayout layout = {0};
    VABExchangeQuantities q = [self exchangeQuantities];
    if (!q.valid) return layout;
    ArithmeticTeachingStep *step = self.currentStep;
    CGFloat inset = 6, groupGap = 12, labelGap = 4;
    CGFloat innerWidth = width - 2 * inset;
    CGFloat sourceWidth = MAX([self unwrappedWidthForText:[self exchangedSourceText] font:self.exchangeFont],
        [self shortRowWidthForCount:q.exchangedSource column:step.sourceColumn]);
    CGFloat destinationWidth = MAX([self unwrappedWidthForText:[self exchangedDestinationText] font:self.exchangeFont],
        [self shortRowWidthForCount:q.exchangedDestination column:step.destinationColumn]);
    CGFloat retainedSourceWidth = MAX([self twoLineWidthForText:[self retainedSourceText] font:self.exchangeFont],
        [self shortRowWidthForCount:q.sourceAfter column:step.sourceColumn]);
    CGFloat retainedDestinationWidth = MAX([self twoLineWidthForText:[self retainedDestinationText] font:self.exchangeFont],
        [self shortRowWidthForCount:q.destinationBefore column:step.destinationColumn]);
    CGFloat modeWidth = MAX([self unwrappedWidthForText:[self exchangeComparisonText] font:self.exchangeFont],
        [self unwrappedWidthForText:[self exchangePlayingText] font:self.exchangeFont]);
    CGFloat extra = MAX(0, modeWidth - sourceWidth - VABExchangeLane - destinationWidth);
    sourceWidth += extra / 2;
    destinationWidth += extra / 2;
    CGFloat scopeWidth = [self unwrappedWidthForText:[self exchangeScopeText] font:self.exchangeScopeFont];
    extra = MAX(0, scopeWidth - retainedSourceWidth - groupGap - retainedDestinationWidth);
    retainedSourceWidth += extra / 2;
    retainedDestinationWidth += extra / 2;
    CGFloat exchangeWidth = sourceWidth + VABExchangeLane + destinationWidth;
    CGFloat requiredWidth = exchangeWidth + 2 * groupGap + retainedSourceWidth + retainedDestinationWidth;
    if (requiredWidth > innerWidth) return layout;
    // Spend spare width on the unchanged captions, not on smaller type or units.
    retainedSourceWidth += (innerWidth - requiredWidth) / 2;
    retainedDestinationWidth += (innerWidth - requiredWidth) / 2;
    CGFloat destinationX = inset + sourceWidth + VABExchangeLane;
    CGFloat retainedSourceX = inset + exchangeWidth + groupGap;
    CGFloat retainedDestinationX = retainedSourceX + retainedSourceWidth + groupGap;
    CGFloat scopeAvailable = retainedSourceWidth + groupGap + retainedDestinationWidth;
    CGFloat headerHeight = MAX([self heightForText:[self exchangeScopeText] font:self.exchangeScopeFont width:scopeAvailable],
        MAX([self heightForText:[self exchangeComparisonText] font:self.exchangeFont width:exchangeWidth],
            [self heightForText:[self exchangePlayingText] font:self.exchangeFont width:exchangeWidth]));
    layout.mode = CGRectMake(inset, inset, exchangeWidth, headerHeight);
    layout.scope = CGRectMake(retainedSourceX, inset, scopeAvailable, headerHeight);
    CGFloat y = inset + headerHeight + labelGap;
    CGFloat labelHeight = MAX([self heightForText:[self exchangedSourceText] font:self.exchangeFont width:sourceWidth],
        [self heightForText:[self exchangedDestinationText] font:self.exchangeFont width:destinationWidth]);
    layout.sourceLabel = CGRectMake(inset, y, sourceWidth, labelHeight);
    layout.destinationLabel = CGRectMake(destinationX, y, destinationWidth, labelHeight);
    CGFloat unitsHeight = MAX([self exchangeUnitHeightForCount:q.exchangedSource column:step.sourceColumn width:sourceWidth],
        [self exchangeUnitHeightForCount:q.exchangedDestination column:step.destinationColumn width:destinationWidth]);
    layout.sourceUnits = CGRectMake(inset, y + labelHeight + labelGap, sourceWidth, unitsHeight);
    layout.destinationUnits = CGRectMake(destinationX, y + labelHeight + labelGap, destinationWidth, unitsHeight);
    layout.sign = CGRectMake(inset + sourceWidth + (VABExchangeLane - 28) / 2, CGRectGetMidY(layout.sourceUnits) - 20, 28, 40);
    labelHeight = [self heightForText:[self retainedSourceText] font:self.exchangeFont width:retainedSourceWidth];
    layout.retainedSourceLabel = CGRectMake(retainedSourceX, y, retainedSourceWidth, labelHeight);
    unitsHeight = [self exchangeUnitHeightForCount:q.sourceAfter column:step.sourceColumn width:retainedSourceWidth];
    layout.retainedSourceUnits = CGRectMake(retainedSourceX, y + labelHeight + labelGap, retainedSourceWidth, unitsHeight);
    labelHeight = [self heightForText:[self retainedDestinationText] font:self.exchangeFont width:retainedDestinationWidth];
    layout.retainedDestinationLabel = CGRectMake(retainedDestinationX, y, retainedDestinationWidth, labelHeight);
    unitsHeight = [self exchangeUnitHeightForCount:q.destinationBefore column:step.destinationColumn width:retainedDestinationWidth];
    layout.retainedDestinationUnits = CGRectMake(retainedDestinationX, y + labelHeight + labelGap, retainedDestinationWidth, unitsHeight);
    y = MAX(MAX(CGRectGetMaxY(layout.sourceUnits), CGRectGetMaxY(layout.sign)),
        MAX(CGRectGetMaxY(layout.retainedSourceUnits), CGRectGetMaxY(layout.retainedDestinationUnits))) + 6;
    layout.counts = CGRectMake(inset, y, innerWidth, [self heightForText:[self exchangeCountsText] font:self.bodyFont width:innerWidth]);
    layout.height = CGRectGetMaxY(layout.counts) + inset;
    return layout;
}

- (VABExchangeLayout)exchangeLayoutForWidth:(CGFloat)width {
    VABExchangeLayout layout = {0};
    VABExchangeQuantities q = [self exchangeQuantities];
    if (!q.valid) return layout;
    VABExchangeLayout wide = [self wideExchangeLayoutForWidth:width];
    if (wide.height > 0) return wide;
    ArithmeticTeachingStep *step = self.currentStep;
    CGFloat innerWidth = MAX(1, width - 20);
    CGFloat half = MAX(1, (innerWidth - VABExchangeLane) / 2);
    CGFloat rightX = width - 10 - half;
    CGFloat y = 10;
    CGFloat height = [self heightForText:[self exchangeScopeText] font:self.exchangeScopeFont width:innerWidth];
    layout.scope = CGRectMake(10, y, innerWidth, height);
    y += height + 6;
    height = MAX([self heightForText:[self exchangeComparisonText] font:self.exchangeFont width:innerWidth],
        [self heightForText:[self exchangePlayingText] font:self.exchangeFont width:innerWidth]);
    layout.mode = CGRectMake(10, y, innerWidth, height);
    y += height + 6;
    height = MAX([self heightForText:[self exchangedSourceText] font:self.exchangeFont width:half],
        [self heightForText:[self exchangedDestinationText] font:self.exchangeFont width:half]);
    layout.sourceLabel = CGRectMake(10, y, half, height);
    layout.destinationLabel = CGRectMake(rightX, y, half, height);
    y += height + 6;
    height = MAX([self exchangeUnitHeightForCount:q.exchangedSource column:step.sourceColumn width:half],
        [self exchangeUnitHeightForCount:q.exchangedDestination column:step.destinationColumn width:half]);
    layout.sourceUnits = CGRectMake(10, y, half, height);
    layout.destinationUnits = CGRectMake(rightX, y, half, height);
    layout.sign = CGRectMake(width / 2 - 14, CGRectGetMidY(layout.sourceUnits) - 20, 28, 40);
    y += height + 12;
    height = MAX([self heightForText:[self retainedSourceText] font:self.exchangeFont width:half],
        [self heightForText:[self retainedDestinationText] font:self.exchangeFont width:half]);
    layout.retainedSourceLabel = CGRectMake(10, y, half, height);
    layout.retainedDestinationLabel = CGRectMake(rightX, y, half, height);
    y += height + 6;
    height = MAX([self exchangeUnitHeightForCount:q.sourceAfter column:step.sourceColumn width:half],
        [self exchangeUnitHeightForCount:q.destinationBefore column:step.destinationColumn width:half]);
    layout.retainedSourceUnits = CGRectMake(10, y, half, height);
    layout.retainedDestinationUnits = CGRectMake(rightX, y, half, height);
    y += height + 10;
    height = [self heightForText:[self exchangeCountsText] font:self.bodyFont width:innerWidth];
    layout.counts = CGRectMake(10, y, innerWidth, height);
    layout.height = y + height + 10;
    return layout;
}

- (UILabel *)addExchangeLabel:(NSString *)text font:(UIFont *)font identifier:(NSString *)identifier frame:(CGRect)frame {
    UILabel *label = [self labelWithText:text font:font identifier:identifier];
    label.numberOfLines = 0;
    label.adjustsFontSizeToFitWidth = NO;
    label.frame = frame;
    [self.illustrationView addSubview:label];
    return label;
}

- (NSArray<VABUnitView *> *)addExchangeUnits:(NSInteger)count column:(NSInteger)column rect:(CGRect)rect color:(UIColor *)color identifier:(NSString *)identifier {
    NSMutableArray<VABUnitView *> *units = [NSMutableArray arrayWithCapacity:count];
    CGSize size = [self exchangeUnitSizeForColumn:column];
    NSInteger columns = [self exchangeUnitColumnsForCount:count column:column width:rect.size.width];
    CGFloat height = [self exchangeUnitHeightForCount:count column:column width:rect.size.width];
    for (NSInteger index = 0; index < count; index++) {
        NSInteger row = index / columns;
        NSInteger rowCount = MIN(columns, count - row * columns);
        CGFloat rowWidth = rowCount * size.width + (rowCount - 1) * VABUnitGap;
        CGFloat x = CGRectGetMinX(rect) + (rect.size.width - rowWidth) / 2 + (index % columns) * (size.width + VABUnitGap);
        CGFloat y = CGRectGetMinY(rect) + (rect.size.height - height) / 2 + row * (size.height + VABUnitGap);
        VABUnitView *unit = [[VABUnitView alloc] initWithFrame:CGRectMake(x, y, size.width, size.height)];
        unit.backgroundColor = UIColor.clearColor;
        unit.place = self.sequence.columnCount - 1 - column;
        unit.unitColor = color;
        unit.isAccessibilityElement = NO;
        unit.accessibilityIdentifier = [NSString stringWithFormat:@"%@.%ld", identifier, (long)index];
        [self.illustrationView addSubview:unit];
        [units addObject:unit];
    }
    return units;
}

- (CAShapeLayer *)exchangeOutlineForRect:(CGRect)rect {
    CAShapeLayer *outline = [CAShapeLayer layer];
    outline.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, -3, -3) cornerRadius:6].CGPath;
    outline.strokeColor = ChildUI.brownText.CGColor;
    outline.lineWidth = 2;
    outline.fillColor = UIColor.clearColor.CGColor;
    outline.opacity = 0;
    [self.illustrationView.layer addSublayer:outline];
    return outline;
}

- (void)buildExchangeIllustration {
    VABExchangeQuantities q = [self exchangeQuantities];
    if (!q.valid) return;
    ArithmeticTeachingStep *step = self.currentStep;
    CGFloat width = CGRectGetWidth(self.illustrationView.bounds);
    VABExchangeLayout layout = [self exchangeLayoutForWidth:width];
    [self addExchangeLabel:[self exchangeScopeText] font:self.exchangeScopeFont identifier:@"verticalExchangeScope" frame:layout.scope];
    self.exchangeModeLabel = [self addExchangeLabel:[self exchangeComparisonText] font:self.exchangeFont identifier:@"verticalExchangeMode" frame:layout.mode];
    [self addExchangeLabel:[self exchangedSourceText] font:self.exchangeFont identifier:@"verticalExchangeSource" frame:layout.sourceLabel];
    [self addExchangeLabel:[self exchangedDestinationText] font:self.exchangeFont identifier:@"verticalExchangeDestination" frame:layout.destinationLabel];
    self.exchangeEqualsLabel = [self addExchangeLabel:@"=" font:[ChildUI roundedFontOfSize:25 weight:UIFontWeightBold] identifier:@"verticalExchangeEquals"
        frame:layout.sign];
    [self.exchangeSourceUnits addObjectsFromArray:[self addExchangeUnits:q.exchangedSource column:step.sourceColumn rect:layout.sourceUnits color:ChildUI.pumpkinOrange identifier:@"verticalExchangedSourceUnit"]];
    [self.exchangeDestinationUnits addObjectsFromArray:[self addExchangeUnits:q.exchangedDestination column:step.destinationColumn rect:layout.destinationUnits color:ChildUI.skyBlue identifier:@"verticalExchangedDestinationUnit"]];
    [self addExchangeLabel:[self retainedSourceText] font:self.exchangeFont identifier:@"verticalRetainedSource" frame:layout.retainedSourceLabel];
    [self addExchangeLabel:[self retainedDestinationText] font:self.exchangeFont identifier:@"verticalRetainedDestination" frame:layout.retainedDestinationLabel];
    // These same objects never join an animation or a transient collection.
    [self.retainedSourceUnits addObjectsFromArray:[self addExchangeUnits:q.sourceAfter column:step.sourceColumn rect:layout.retainedSourceUnits color:ChildUI.mintGreen identifier:@"verticalRetainedSourceUnit"]];
    [self.retainedDestinationUnits addObjectsFromArray:[self addExchangeUnits:q.destinationBefore column:step.destinationColumn rect:layout.retainedDestinationUnits color:ChildUI.mintGreen identifier:@"verticalRetainedDestinationUnit"]];
    [self addExchangeLabel:[self exchangeCountsText] font:self.bodyFont identifier:@"verticalExchangeCounts" frame:layout.counts];
    self.exchangeSourceOutline = [self exchangeOutlineForRect:layout.sourceUnits];
    self.exchangeDestinationOutline = [self exchangeOutlineForRect:layout.destinationUnits];
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

- (BOOL)playCurrentActionInVisibleRect:(CGRect)visibleRect {
    [self cancelAnimations];
    CGRect required = self.currentActionRect;
    if (CGRectIsNull(required) || CGRectIsEmpty(required) || CGRectIsNull(visibleRect)
        || CGRectIsEmpty(visibleRect) || !CGRectContainsRect(visibleRect, required)) return NO;
    CGRect writtenAndConcrete = self.currentTransformationRect;
    self.playsWrittenExchange = CGRectContainsRect(visibleRect, writtenAndConcrete)
        && [self playbackRectFitsClippingAncestors:writtenAndConcrete];
    self.requiresVisiblePlayback = YES;
    if (![self playbackFitsClippingAncestors]) return NO;
    if ([self canAnimate]) [self animateCurrentAction];
    else if (!ChildUI.motionEnabled) self.playbackState = VerticalArithmeticPlaybackStateReducedMotion;
    return YES;
}

- (BOOL)playbackFitsClippingAncestors {
    return [self playbackRectFitsClippingAncestors:self.currentPlaybackRect];
}

- (BOOL)playbackRectFitsClippingAncestors:(CGRect)action {
    if (CGRectIsNull(action) || CGRectIsEmpty(action)) return NO;
    for (UIView *view = self; view; view = view.superview) {
        if ((view.clipsToBounds || view == self.window)
            && !CGRectContainsRect(view.bounds, [self convertRect:action toView:view])) return NO;
    }
    return YES;
}

- (BOOL)canAnimate {
    if (self.requiresVisiblePlayback && ![self playbackFitsClippingAncestors]) return NO;
    if (!ChildUI.motionEnabled || !self.window || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    for (UIView *view = self; view; view = view.superview) if (view.hidden || view.alpha <= 0.01) return NO;
    return YES;
}

- (void)addAnimation:(CAAnimation *)animation toLayer:(CALayer *)layer key:(NSString *)key {
    if (self.exchangeAnimationStartTime > 0) animation.beginTime = [layer convertTime:self.exchangeAnimationStartTime fromLayer:nil];
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
    self.playbackState = VerticalArithmeticPlaybackStatePlaying;
    self.animationEndTime = (self.exchangeAnimationStartTime > 0 ? self.exchangeAnimationStartTime : CACurrentMediaTime()) + VABExchangeDuration;
    VABWeakDisplayLinkTarget *proxy = [VABWeakDisplayLinkTarget new];
    proxy.target = self;
    self.animationDisplayLink = [CADisplayLink displayLinkWithTarget:proxy selector:@selector(tick:)];
    [self.animationDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (CAKeyframeAnimation *)concreteOwnershipAnimationForSource:(BOOL)source {
    CAKeyframeAnimation *ownership = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    ownership.values = source ? @[@1, @0, @0] : @[@0, @1, @1];
    ownership.keyTimes = @[@0, @(VABExchangeHandoff), @1];
    ownership.calculationMode = kCAAnimationDiscrete;
    ownership.duration = VABExchangeDuration;
    ownership.fillMode = kCAFillModeForwards;
    // Keep the live endpoint until the display link restores the explicitly
    // labelled comparison; otherwise a removed source animation could flash back.
    ownership.removedOnCompletion = NO;
    return ownership;
}

- (void)animateExchange {
    ArithmeticTeachingStep *step = self.currentStep;
    if (![self validColumn:step.sourceColumn] || ![self validColumn:step.destinationColumn] || self.annotationLabels.count != self.sequence.columnCount) return;
    VABExchangeQuantities quantities = [self exchangeQuantities];
    if (!quantities.valid || self.exchangeSourceUnits.count != quantities.exchangedSource
        || self.exchangeDestinationUnits.count != quantities.exchangedDestination) return;
    BOOL carriesLeft = step.destinationColumn < step.sourceColumn;
    self.exchangeAnimationStartTime = CACurrentMediaTime();
    self.exchangeModeLabel.text = [self exchangePlayingText];
    self.exchangeEqualsLabel.text = @"→";
    if (self.playsWrittenExchange) {
        UILabel *source = self.annotationLabels[step.sourceColumn];
        UILabel *destination = self.annotationLabels[step.destinationColumn];
        CGPoint from = [self.gridView convertPoint:source.center toView:self.contentView];
        CGPoint to = [self.gridView convertPoint:destination.center toView:self.contentView];
        NSString *packetText = [NSString stringWithFormat:@"%ld%@", (long)quantities.exchangedSource, [self unitNameForColumn:step.sourceColumn]];
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
        travel.duration = VABExchangeDuration * VABExchangeHandoff;
        travel.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        CAKeyframeAnimation *visibility = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        visibility.values = @[@1, @0, @0];
        visibility.keyTimes = @[@0, @(VABExchangeHandoff), @1];
        visibility.calculationMode = kCAAnimationDiscrete;
        visibility.duration = VABExchangeDuration;
        CAAnimationGroup *packetGroup = [CAAnimationGroup animation];
        packetGroup.animations = @[travel, visibility];
        packetGroup.duration = VABExchangeDuration;
        [self addAnimation:packetGroup toLayer:packet.layer key:@"verticalUnitTransfer"];

    }

    // Running is one live representation, not a cross-fade between inventories.
    // Every piece stays in its own countable slot. A grouping outline closes
    // around the source set, then ownership changes at one shared media time.
    // No parent gathers into another parent, shrinks, or fades before that handoff.
    for (VABUnitView *unit in self.exchangeSourceUnits) {
        [self addAnimation:[self concreteOwnershipAnimationForSource:YES] toLayer:unit.layer key:@"verticalConcreteGather"];
    }
    for (VABUnitView *unit in self.exchangeDestinationUnits) {
        [self addAnimation:[self concreteOwnershipAnimationForSource:NO] toLayer:unit.layer key:@"verticalConcreteExchange"];
    }
    for (NSNumber *sourceNumber in @[@YES, @NO]) {
        BOOL source = sourceNumber.boolValue;
        CAShapeLayer *outline = source ? self.exchangeSourceOutline : self.exchangeDestinationOutline;
        CAKeyframeAnimation *closure = [CAKeyframeAnimation animationWithKeyPath:@"strokeEnd"];
        closure.values = source ? @[@0, @1, @1] : @[@0, @0, @1];
        closure.keyTimes = @[@0, @(VABExchangeHandoff), @1];
        closure.duration = VABExchangeDuration;
        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[closure, [self concreteOwnershipAnimationForSource:source]];
        group.duration = VABExchangeDuration;
        group.fillMode = kCAFillModeForwards;
        group.removedOnCompletion = NO;
        [self addAnimation:group toLayer:outline key:@"verticalConcreteClosure"];
    }
    if (self.playsWrittenExchange) {
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
            oldCount.values = @[@1, @0, @0];
            oldCount.keyTimes = @[@0, @(VABExchangeHandoff), @1];
            oldCount.calculationMode = kCAAnimationDiscrete;
            oldCount.duration = VABExchangeDuration;
            [self addAnimation:oldCount toLayer:before.layer key:@"verticalBeforeCount"];
            CAKeyframeAnimation *newCount = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
            newCount.values = @[@0, @1, @1];
            newCount.keyTimes = @[@0, @(VABExchangeHandoff), @1];
            newCount.calculationMode = kCAAnimationDiscrete;
            newCount.duration = VABExchangeDuration;
            [self addAnimation:newCount toLayer:label.layer key:@"verticalAfterCount"];
            CAKeyframeAnimation *emphasis = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            emphasis.values = @[@1, @1, @1.12, @1];
            emphasis.keyTimes = @[@0, @0.55, @0.76, @1];
            emphasis.duration = VABExchangeDuration;
            [self addAnimation:emphasis toLayer:label.layer key:@"verticalCountChange"];
        }
    }
}

- (void)animationTick:(CADisplayLink *)link {
    if (![self canAnimate]) { [self cancelAnimations]; return; }
    if (self.isPlaying && CACurrentMediaTime() >= self.animationEndTime) {
        [self cancelAnimations];
        self.playbackState = VerticalArithmeticPlaybackStateCompleted;
    }
}

- (void)cancelAnimations {
    if (self.isPlaying) self.playbackState = VerticalArithmeticPlaybackStateInterrupted;
    [self.animationDisplayLink invalidate];
    self.animationDisplayLink = nil;
    for (CALayer *layer in self.animatedLayers) {
        [layer removeAnimationForKey:@"verticalAnswerWrite"];
        [layer removeAnimationForKey:@"verticalUnitTransfer"];
        [layer removeAnimationForKey:@"verticalConcreteExchange"];
        [layer removeAnimationForKey:@"verticalConcreteGather"];
        [layer removeAnimationForKey:@"verticalConcreteClosure"];
        [layer removeAnimationForKey:@"verticalCountChange"];
        [layer removeAnimationForKey:@"verticalBeforeCount"];
        [layer removeAnimationForKey:@"verticalAfterCount"];
    }
    [self.animatedLayers removeAllObjects];
    for (UIView *view in self.transientViews) [view removeFromSuperview];
    [self.transientViews removeAllObjects];
    self.animationEndTime = 0;
    self.exchangeAnimationStartTime = 0;
    self.exchangeModeLabel.text = [self exchangeComparisonText];
    self.exchangeEqualsLabel.text = @"=";
}

- (void)stopForNotification:(NSNotification *)notification {
    [self cancelAnimations];
    if ([notification.name isEqualToString:UIAccessibilityReduceMotionStatusDidChangeNotification] && !ChildUI.motionEnabled)
        self.playbackState = VerticalArithmeticPlaybackStateReducedMotion;
}
- (void)contentSizeChanged:(NSNotification *)notification {
    [self cancelAnimations];
    self.needsSnapshotLayout = YES;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self cancelAnimations];
        self.needsSnapshotLayout = YES;
        [self invalidateIntrinsicContentSize];
        [self setNeedsLayout];
    }
}
- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) [self cancelAnimations]; }
- (void)didMoveToSuperview { [super didMoveToSuperview]; if (!self.superview) [self cancelAnimations]; }
- (void)setHidden:(BOOL)hidden { [super setHidden:hidden]; if (hidden) [self cancelAnimations]; }
- (void)setAlpha:(CGFloat)alpha { [super setAlpha:alpha]; if (alpha <= 0.01) [self cancelAnimations]; }
@end
