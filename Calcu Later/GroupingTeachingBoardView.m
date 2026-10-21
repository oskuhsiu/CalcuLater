#import "GroupingTeachingBoardView.h"
#import "ChildUIKit.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const NSTimeInterval GBTMotionDuration = 1.0;
static const CGFloat GBTInset = 12;
static const CGFloat GBTGap = 12;

typedef NS_ENUM(NSInteger, GBTDisplayPhase) {
    GBTDisplayPhaseSettled,
    GBTDisplayPhaseBefore,
    GBTDisplayPhaseMoving
};

@interface GBTCounterView : UIView
@property (nonatomic, strong) UIColor *counterColor;
@end
@implementation GBTCounterView
- (void)setCounterColor:(UIColor *)counterColor { if ([_counterColor isEqual:counterColor]) return; _counterColor = counterColor; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGRect circle = CGRectInset(self.bounds, 1, 1);
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:circle];
    [self.counterColor setFill];
    [ChildUI.brownText setStroke];
    path.lineWidth = 1.4;
    [path fill];
    [path stroke];
}
@end

@interface GBTLayout : NSObject
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGRect legendFrame;
@property (nonatomic) CGRect stateFrame;
@property (nonatomic) CGRect actionFrame;
@property (nonatomic) CGRect sourceFrame;
@property (nonatomic) CGFloat sourceTitleHeight;
@property (nonatomic) CGFloat sourceCounterY;
@property (nonatomic) CGFloat sourceUnitSize;
@property (nonatomic) NSInteger sourceColumns;
@property (nonatomic) CGRect emptyFrame;
@property (nonatomic, copy) NSArray<NSValue *> *groupFrames;
@property (nonatomic) CGFloat groupTitleHeight;
@property (nonatomic) CGFloat groupCounterY;
@property (nonatomic) CGFloat groupUnitSize;
@property (nonatomic) CGFloat groupCountY;
@property (nonatomic) CGFloat groupCountHeight;
@property (nonatomic) CGRect answerFrame;
@property (nonatomic) CGRect remainderFrame;
@end
@implementation GBTLayout @end

@interface GBTTransfer : NSObject
@property (nonatomic, strong) GBTCounterView *counter;
@property (nonatomic, weak) UIView *destinationView;
@property (nonatomic) CGRect destinationFrame;
@property (nonatomic) CGPoint start;
@property (nonatomic) CGPoint end;
@property (nonatomic) CGFloat sourceUnitSize;
@property (nonatomic, strong) UIColor *settledColor;
@end
@implementation GBTTransfer @end

@interface GBTWeakDisplayLinkTarget : NSObject
@property (nonatomic, weak) id target;
- (void)tick:(CADisplayLink *)link;
@end

@interface GroupingTeachingBoardView ()
@property (nonatomic, strong, readwrite, nullable) GroupingTeachingSequence *sequence;
@property (nonatomic, assign, readwrite) NSInteger currentStepIndex;
@property (nonatomic, strong, readwrite, nullable) GroupingTeachingStep *currentStep;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *actionLabel;
@property (nonatomic, strong) UIView *sourceView;
@property (nonatomic, strong) UILabel *sourceLabel;
@property (nonatomic, strong) UILabel *sourceEmptyLabel;
@property (nonatomic, strong) NSMutableArray<GBTCounterView *> *poolCounters;
@property (nonatomic, strong) NSMutableArray<UIView *> *groupViews;
@property (nonatomic, strong) NSMutableArray<UILabel *> *groupTitleLabels;
@property (nonatomic, strong) NSMutableArray<UILabel *> *groupCountLabels;
@property (nonatomic, strong) NSMutableArray<NSArray<GBTCounterView *> *> *groupCounters;
@property (nonatomic, strong) NSMutableArray<GBTTransfer *> *transfers;
@property (nonatomic, strong) GBTLayout *renderedLayout;
@property (nonatomic) CGSize renderedSize;
@property (nonatomic) BOOL needsSnapshotLayout;
@property (nonatomic) GBTDisplayPhase displayPhase;
@property (nonatomic, strong, nullable) CADisplayLink *animationDisplayLink;
@property (nonatomic) CFTimeInterval animationStartTime;
- (void)animationTick:(CADisplayLink *)link;
@end

@implementation GBTWeakDisplayLinkTarget
- (void)tick:(CADisplayLink *)link {
    GroupingTeachingBoardView *board = self.target;
    if (board) [board animationTick:link];
    else [link invalidate];
}
@end

@implementation GroupingTeachingBoardView

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
    _poolCounters = [NSMutableArray array];
    _groupViews = [NSMutableArray array];
    _groupTitleLabels = [NSMutableArray array];
    _groupCountLabels = [NSMutableArray array];
    _groupCounters = [NSMutableArray array];
    _transfers = [NSMutableArray array];
    self.backgroundColor = ChildUI.creamBackground;
    self.layer.cornerRadius = 22;
    self.clipsToBounds = YES;
    self.accessibilityIdentifier = @"groupingTeachingBoard";
    self.accessibilityLabel = @"一步一步看分組";
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

#pragma mark - Selected snapshot only

- (BOOL)countsAreBounded:(NSArray<NSNumber *> *)counts {
    if (counts.count > 9) return NO;
    for (NSNumber *count in counts) if (![count isKindOfClass:NSNumber.class] || count.integerValue < 0 || count.integerValue > 10) return NO;
    return YES;
}
- (BOOL)configureWithSequence:(GroupingTeachingSequence *)sequence stepIndex:(NSInteger)stepIndex animated:(BOOL)animated {
    [self cancelAnimations];
    GroupingTeachingStep *step = sequence.isSupported && stepIndex >= 0 && stepIndex < (NSInteger)sequence.steps.count
        ? sequence.steps[stepIndex] : nil;
    if (!step || !sequence.context || ![self countsAreBounded:step.groupCountsBefore] || ![self countsAreBounded:step.groupCountsAfter]
        || (step.poolCountBefore && (step.poolCountBefore.integerValue < 0 || step.poolCountBefore.integerValue > 90))
        || (step.poolCountAfter && (step.poolCountAfter.integerValue < 0 || step.poolCountAfter.integerValue > 90))) {
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
    self.currentStep = step;
    self.currentStepIndex = stepIndex;
    self.displayPhase = GBTDisplayPhaseSettled;
    self.isAccessibilityElement = YES;
    self.needsSnapshotLayout = YES;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self updateStateLabels];
    if (animated && [self canAnimate]) [self animateCurrentAction];
    return YES;
}
- (BOOL)showStepAtIndex:(NSInteger)stepIndex animated:(BOOL)animated {
    return [self configureWithSequence:self.sequence stepIndex:stepIndex animated:animated];
}
- (void)clearSnapshot {
    [self.contentView removeFromSuperview];
    self.contentView = nil;
    self.stateLabel = nil;
    self.actionLabel = nil;
    self.sourceView = nil;
    self.sourceLabel = nil;
    self.sourceEmptyLabel = nil;
    self.renderedLayout = nil;
    [self.poolCounters removeAllObjects];
    [self.groupViews removeAllObjects];
    [self.groupTitleLabels removeAllObjects];
    [self.groupCountLabels removeAllObjects];
    [self.groupCounters removeAllObjects];
}
- (BOOL)isBuild { return self.sequence.context.meaning == GroupingStoryMeaningBuildEqualGroups; }
- (BOOL)isShare { return self.sequence.context.meaning == GroupingStoryMeaningShareEqually; }
- (BOOL)isTransform {
    GroupingTeachingStepKind kind = self.currentStep.kind;
    return self.currentStep && (kind == GroupingTeachingStepKindBuildGroup || kind == GroupingTeachingStepKindShareRound || kind == GroupingTeachingStepKindPackGroup);
}
- (NSInteger)movedCounterCount {
    NSInteger count = 0;
    for (NSInteger i = 0; i < (NSInteger)self.currentStep.groupCountsAfter.count; i++) {
        NSInteger before = i < (NSInteger)self.currentStep.groupCountsBefore.count ? self.currentStep.groupCountsBefore[i].integerValue : 0;
        count += MAX(0, self.currentStep.groupCountsAfter[i].integerValue - before);
    }
    return count;
}
- (NSString *)legendText {
    GroupingStoryContext *context = self.sequence.context;
    return [NSString stringWithFormat:@"每個圓點代表 1 %@%@", context.itemUnit, context.itemName];
}
- (NSString *)stateTextForPhase:(GBTDisplayPhase)phase {
    GroupingTeachingStep *step = self.currentStep;
    GroupingStoryContext *context = self.sequence.context;
    NSInteger groups = phase == GBTDisplayPhaseSettled ? step.groupCountsAfter.count : step.groupCountsBefore.count;
    if (self.isBuild) {
        NSInteger unopened = step.unopenedGroupCount.integerValue;
        if (phase != GBTDisplayPhaseSettled) unopened += step.groupCountsAfter.count - step.groupCountsBefore.count;
        return [NSString stringWithFormat:@"已建立 %ld %@\n還有 %ld %@尚未建立", (long)groups, context.groupName, (long)unopened, context.groupName];
    }
    if (self.isShare) return [NSString stringWithFormat:@"平均分給 %ld %@", (long)groups, context.groupName];
    return [NSString stringWithFormat:@"已分成 %ld %@", (long)groups, context.groupName];
}
- (NSString *)actionTextForPhase:(GBTDisplayPhase)phase {
    if (!self.isTransform) return @"可以停下來數一數，再看下一步。";
    if (phase == GBTDisplayPhaseBefore) return [@"準備：" stringByAppendingString:self.currentStep.actionTitle];
    if (phase == GBTDisplayPhaseMoving) return [NSString stringWithFormat:@"正在：%@\n移動中：%ld %@", self.currentStep.actionTitle, (long)self.movedCounterCount, self.sequence.context.itemUnit];
    return [@"已完成：" stringByAppendingString:self.currentStep.actionTitle];
}
- (NSString *)sourceTextForPhase:(GBTDisplayPhase)phase {
    if (self.isBuild) {
        if (self.currentStep.kind != GroupingTeachingStepKindBuildGroup) return @"準備區：每次建立一組";
        if (phase == GBTDisplayPhaseSettled) return @"這一組已放好了";
        return [NSString stringWithFormat:@"這次的一組：%ld %@", (long)self.movedCounterCount, self.sequence.context.itemUnit];
    }
    NSNumber *count = phase == GBTDisplayPhaseBefore ? self.currentStep.poolCountBefore : self.currentStep.poolCountAfter;
    return [NSString stringWithFormat:@"%@的%@：%ld %@", self.isShare ? @"待分" : @"待分組", self.sequence.context.itemName,
        (long)count.integerValue, self.sequence.context.itemUnit];
}
- (NSString *)groupTitleAtIndex:(NSInteger)index phase:(GBTDisplayPhase)phase {
    BOOL preparing = phase != GBTDisplayPhaseSettled && index >= (NSInteger)self.currentStep.groupCountsBefore.count;
    return [NSString stringWithFormat:@"%@第 %ld %@", preparing ? @"準備" : @"", (long)index + 1, self.sequence.context.groupName];
}
- (NSString *)answerText {
    if (!self.currentStep.visibleAnswer) return @"答案還沒寫，先把數量看清楚。";
    return [NSString stringWithFormat:@"寫下：%@ %@", self.currentStep.visibleAnswer, self.sequence.context.answerUnit];
}
- (NSString *)remainderText {
    NSNumber *remainder = self.currentStep.visibleRemainder;
    if (!remainder) return @"";
    if (remainder.integerValue == 0) return @"剛好分完，沒有剩下。";
    return [NSString stringWithFormat:@"共同剩下：%@ %@%@\n這些還在待分區，不在任何一組裡。", remainder, self.sequence.context.itemUnit, self.sequence.context.itemName];
}

#pragma mark - Readable width-bounded layout

- (UIFont *)font:(CGFloat)size maximum:(CGFloat)maximum weight:(UIFontWeight)weight {
    UIFont *base = [ChildUI roundedFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:base maximumPointSize:maximum compatibleWithTraitCollection:self.traitCollection];
}
- (CGFloat)heightForText:(NSString *)text font:(UIFont *)font width:(CGFloat)width {
    if (!text.length) return 0;
    CGRect rect = [text boundingRectWithSize:CGSizeMake(MAX(1, width), CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
        attributes:@{NSFontAttributeName:font} context:nil];
    return ceil(MAX(font.lineHeight, rect.size.height)) + 2;
}
- (CGFloat)maximumHeightForTexts:(NSArray<NSString *> *)texts font:(UIFont *)font width:(CGFloat)width {
    CGFloat height = 0;
    for (NSString *text in texts) height = MAX(height, [self heightForText:text font:font width:width]);
    return height;
}
- (CGFloat)unitSizeForWidth:(CGFloat)width columns:(NSInteger)columns {
    return MAX(2, MIN(20, (width - 4 * (columns - 1) - (columns == 10 ? 8 : 0)) / columns));
}
- (CGFloat)counterHeightForCount:(NSInteger)count columns:(NSInteger)columns unitSize:(CGFloat)unitSize {
    NSInteger rows = (count + columns - 1) / columns;
    return rows ? rows * (unitSize + 6) - 6 : 0;
}
- (GBTLayout *)layoutForWidth:(CGFloat)width {
    GBTLayout *layout = [[GBTLayout alloc] init];
    layout.width = MAX(1, width);
    if (!self.currentStep) { layout.height = 0; layout.groupFrames = @[]; return layout; }
    CGFloat innerWidth = MAX(1, width - 2 * GBTInset), y = GBTInset;
    UIFont *body = [self font:18 maximum:28 weight:UIFontWeightMedium];
    UIFont *caption = [self font:18 maximum:28 weight:UIFontWeightSemibold];
    UIFont *countFont = [self font:22 maximum:32 weight:UIFontWeightBold];
    GroupingStoryContext *context = self.sequence.context;
    NSString *boundedState = self.isBuild
        ? [NSString stringWithFormat:@"已建立 9 %@\n還有 9 %@尚未建立", context.groupName, context.groupName]
        : (self.isShare ? [NSString stringWithFormat:@"平均分給 9 %@", context.groupName]
                       : [NSString stringWithFormat:@"已分成 9 %@", context.groupName]);
    NSString *boundedAction = self.isBuild ? [@"建立一" stringByAppendingString:context.groupName]
        : (self.isShare ? [NSString stringWithFormat:@"每%@再分 1 %@", context.groupName, context.itemUnit]
                       : [@"分出一" stringByAppendingString:context.groupName]);
    NSString *boundedMovingText = [NSString stringWithFormat:@"正在：%@\n移動中：10 %@", boundedAction, context.itemUnit];
    CGFloat h = [self heightForText:self.legendText font:body width:innerWidth];
    layout.legendFrame = CGRectMake(GBTInset, y, innerWidth, h); y += h + 8;
    h = [self maximumHeightForTexts:@[boundedState, [self stateTextForPhase:GBTDisplayPhaseBefore], [self stateTextForPhase:GBTDisplayPhaseSettled]] font:caption width:innerWidth];
    layout.stateFrame = CGRectMake(GBTInset, y, innerWidth, h); y += h + 8;
    h = [self maximumHeightForTexts:@[boundedMovingText, [@"已完成：" stringByAppendingString:boundedAction], @"可以停下來數一數，再看下一步。", [self actionTextForPhase:GBTDisplayPhaseBefore], [self actionTextForPhase:GBTDisplayPhaseMoving], [self actionTextForPhase:GBTDisplayPhaseSettled]] font:body width:innerWidth];
    layout.actionFrame = CGRectMake(GBTInset, y, innerWidth, h); y += h + GBTGap;

    BOOL sourceVisible = self.currentStep.poolCountAfter != nil || self.isBuild;
    if (sourceVisible) {
        CGFloat sourceInner = MAX(1, innerWidth - 2 * GBTInset);
        NSString *boundedSource = self.isBuild ? [NSString stringWithFormat:@"這次的一組：10 %@", context.itemUnit]
            : [NSString stringWithFormat:@"%@的%@：90 %@", self.isShare ? @"待分" : @"待分組", context.itemName, context.itemUnit];
        NSMutableArray<NSString *> *sourceTitles = [NSMutableArray arrayWithObjects:boundedSource,
            [self sourceTextForPhase:GBTDisplayPhaseBefore], [self sourceTextForPhase:GBTDisplayPhaseSettled], nil];
        if (self.isBuild) [sourceTitles addObject:@"準備區：每次建立一組"];
        layout.sourceTitleHeight = [self maximumHeightForTexts:sourceTitles font:caption width:sourceInner];
        layout.sourceColumns = self.isBuild ? 5 : (sourceInner >= 204 ? 10 : 5);
        layout.sourceUnitSize = [self unitSizeForWidth:sourceInner columns:layout.sourceColumns];
        // Reserve the same tray geometry as objects leave it. This is the known
        // conserved total of THIS snapshot, not an answer or future pool state.
        NSInteger maxCount = self.isBuild ? 10 : self.currentStep.poolCountAfter.integerValue;
        if (!self.isBuild) for (NSNumber *count in self.currentStep.groupCountsAfter) maxCount += count.integerValue;
        layout.sourceCounterY = GBTInset + layout.sourceTitleHeight + 10;
        CGFloat counterHeight = [self counterHeightForCount:maxCount columns:layout.sourceColumns unitSize:layout.sourceUnitSize];
        CGFloat emptyHeight = [self heightForText:self.isBuild ? @"準備區現在是空的。" : @"沒有待分的物件" font:body width:sourceInner];
        CGFloat sourceHeight = layout.sourceCounterY + MAX(counterHeight, emptyHeight) + GBTInset;
        layout.sourceFrame = CGRectMake(GBTInset, y, innerWidth, sourceHeight); y += sourceHeight + GBTGap;
    }

    NSInteger groupCount = self.currentStep.groupCountsAfter.count;
    NSMutableArray<NSValue *> *frames = [NSMutableArray arrayWithCapacity:groupCount];
    if (groupCount > 0) {
        NSInteger columns = innerWidth >= 570 ? 3 : (innerWidth >= 232 && !(caption.pointSize > 24 && innerWidth < 420) ? 2 : 1);
        CGFloat cardWidth = (innerWidth - GBTGap * (columns - 1)) / columns;
        CGFloat cardInner = MAX(1, cardWidth - 2 * GBTInset);
        // A newly prepared group must not resize or move earlier groups. Fixed
        // width-based slots reserve no empty cards, only stable positions.
        NSString *longestTitle = [NSString stringWithFormat:@"準備第 9 %@", self.sequence.context.groupName];
        layout.groupTitleHeight = [self heightForText:longestTitle font:caption width:cardInner];
        for (NSInteger i = 0; i < groupCount; i++) {
            // A C macro does not treat Objective-C brackets as parentheses.
            // Keep the two-title literal outside MAX so its comma is not an argument.
            NSArray<NSString *> *titles = @[[self groupTitleAtIndex:i phase:GBTDisplayPhaseBefore],
                                            [self groupTitleAtIndex:i phase:GBTDisplayPhaseSettled]];
            CGFloat titleHeight = [self maximumHeightForTexts:titles font:caption width:cardInner];
            layout.groupTitleHeight = MAX(layout.groupTitleHeight, titleHeight);
        }
        layout.groupUnitSize = [self unitSizeForWidth:cardInner columns:5];
        layout.groupCounterY = GBTInset + layout.groupTitleHeight + 10;
        layout.groupCountY = layout.groupCounterY + [self counterHeightForCount:10 columns:5 unitSize:layout.groupUnitSize] + 10;
        NSString *maximumCount = [NSString stringWithFormat:@"10 %@", self.sequence.context.itemUnit];
        layout.groupCountHeight = [self heightForText:maximumCount font:countFont width:cardInner];
        CGFloat cardHeight = layout.groupCountY + layout.groupCountHeight + GBTInset;
        for (NSInteger i = 0; i < groupCount; i++) {
            CGRect frame = CGRectMake(GBTInset + (i % columns) * (cardWidth + GBTGap), y + (i / columns) * (cardHeight + GBTGap), cardWidth, cardHeight);
            [frames addObject:[NSValue valueWithCGRect:frame]];
        }
        NSInteger rows = (groupCount + columns - 1) / columns;
        y += rows * (cardHeight + GBTGap);
    } else {
        NSString *empty = self.isBuild ? @"還沒有建立任何一組。" : @"還沒有分出完整的一組。";
        h = [self heightForText:empty font:body width:innerWidth];
        layout.emptyFrame = CGRectMake(GBTInset, y, innerWidth, h); y += h + GBTGap;
    }
    layout.groupFrames = frames;
    UIFont *answerFont = [self font:21 maximum:32 weight:UIFontWeightBold];
    h = [self heightForText:self.answerText font:answerFont width:innerWidth];
    layout.answerFrame = CGRectMake(GBTInset, y, innerWidth, h); y += h + GBTInset;
    if (self.remainderText.length) {
        h = [self heightForText:self.remainderText font:body width:innerWidth];
        layout.remainderFrame = CGRectMake(GBTInset, y, innerWidth, h); y += h + GBTInset;
    }
    layout.height = ceil(y);
    return layout;
}
- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat width = isfinite(size.width) && size.width > 0 ? size.width : (CGRectGetWidth(self.bounds) > 0 ? CGRectGetWidth(self.bounds) : 320);
    return CGSizeMake(width, [self layoutForWidth:width].height);
}
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, [self sizeThatFits:self.bounds.size].height); }
- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL resized = !CGSizeEqualToSize(self.bounds.size, self.renderedSize);
    if (!self.currentStep || CGRectGetWidth(self.bounds) <= 0 || (!resized && !self.needsSnapshotLayout)) return;
    [self cancelAnimations];
    self.renderedSize = self.bounds.size;
    self.needsSnapshotLayout = NO;
    [self renderSnapshot];
}
- (UILabel *)label:(NSString *)text font:(UIFont *)font frame:(CGRect)frame identifier:(NSString *)identifier inView:(UIView *)parent {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.font = font;
    label.textColor = ChildUI.brownText;
    label.text = text;
    label.isAccessibilityElement = NO;
    label.accessibilityIdentifier = identifier;
    [parent addSubview:label];
    return label;
}
- (UIView *)cardWithFrame:(CGRect)frame color:(UIColor *)color {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [color colorWithAlphaComponent:0.25];
    card.layer.borderColor = [ChildUI.brownText colorWithAlphaComponent:0.5].CGColor;
    card.layer.borderWidth = 1.3;
    card.layer.cornerRadius = 16;
    [self.contentView addSubview:card];
    return card;
}
- (CGPoint)counterCenter:(NSInteger)index inWidth:(CGFloat)width y:(CGFloat)y unitSize:(CGFloat)unitSize columns:(NSInteger)columns {
    CGFloat fullWidth = columns * unitSize + (columns - 1) * 4 + (columns == 10 ? 8 : 0);
    NSInteger column = index % columns;
    return CGPointMake((width - fullWidth) / 2 + unitSize / 2 + column * (unitSize + 4) + (columns == 10 && column >= 5 ? 8 : 0),
        y + unitSize / 2 + (index / columns) * (unitSize + 6));
}
- (GBTCounterView *)counterAtIndex:(NSInteger)index width:(CGFloat)width y:(CGFloat)y unitSize:(CGFloat)unitSize columns:(NSInteger)columns color:(UIColor *)color inView:(UIView *)parent {
    GBTCounterView *counter = [[GBTCounterView alloc] initWithFrame:CGRectMake(0, 0, unitSize, unitSize)];
    counter.backgroundColor = UIColor.clearColor;
    counter.counterColor = color;
    counter.center = [self counterCenter:index inWidth:width y:y unitSize:unitSize columns:columns];
    counter.isAccessibilityElement = NO;
    [parent addSubview:counter];
    return counter;
}
- (void)renderSnapshot {
    [self clearSnapshot];
    GBTLayout *layout = [self layoutForWidth:CGRectGetWidth(self.bounds)];
    self.renderedLayout = layout;
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, layout.width, layout.height)];
    self.contentView.accessibilityElementsHidden = YES;
    [self addSubview:self.contentView];
    UIFont *body = [self font:18 maximum:28 weight:UIFontWeightMedium];
    UIFont *caption = [self font:18 maximum:28 weight:UIFontWeightSemibold];
    UIFont *countFont = [self font:22 maximum:32 weight:UIFontWeightBold];
    [self label:self.legendText font:body frame:layout.legendFrame identifier:@"groupingLegend" inView:self.contentView];
    self.stateLabel = [self label:@"" font:caption frame:layout.stateFrame identifier:@"groupingState" inView:self.contentView];
    self.actionLabel = [self label:@"" font:body frame:layout.actionFrame identifier:@"groupingAction" inView:self.contentView];
    if (!CGRectIsEmpty(layout.sourceFrame)) {
        self.sourceView = [self cardWithFrame:layout.sourceFrame color:ChildUI.skyBlue];
        self.sourceView.accessibilityIdentifier = self.isBuild ? @"groupingStagingArea" : @"groupingPool";
        CGFloat width = CGRectGetWidth(self.sourceView.bounds);
        self.sourceLabel = [self label:@"" font:caption frame:CGRectMake(GBTInset, GBTInset, width - 2 * GBTInset, layout.sourceTitleHeight)
            identifier:@"groupingPoolCount" inView:self.sourceView];
        if (!self.isBuild) {
            for (NSInteger i = 0; i < self.currentStep.poolCountAfter.integerValue; i++) {
                [self.poolCounters addObject:[self counterAtIndex:i width:width y:layout.sourceCounterY unitSize:layout.sourceUnitSize columns:layout.sourceColumns color:ChildUI.skyBlue inView:self.sourceView]];
            }
        }
        self.sourceEmptyLabel = [self label:self.isBuild ? @"準備區現在是空的。" : @"沒有待分的物件" font:body
            frame:CGRectMake(GBTInset, layout.sourceCounterY, width - 2 * GBTInset, CGRectGetHeight(self.sourceView.bounds) - layout.sourceCounterY - GBTInset)
            identifier:@"groupingEmptyPool" inView:self.sourceView];
    }
    for (NSInteger i = 0; i < (NSInteger)layout.groupFrames.count; i++) {
        UIView *card = [self cardWithFrame:layout.groupFrames[i].CGRectValue color:[ChildUI candyColorAtIndex:i]];
        card.accessibilityIdentifier = [NSString stringWithFormat:@"groupingGroup%ld", (long)i];
        [self.groupViews addObject:card];
        CGFloat width = CGRectGetWidth(card.bounds);
        NSString *titleID = [NSString stringWithFormat:@"groupingGroupTitle%ld", (long)i];
        [self.groupTitleLabels addObject:[self label:@"" font:caption frame:CGRectMake(GBTInset, GBTInset, width - 2 * GBTInset, layout.groupTitleHeight) identifier:titleID inView:card]];
        NSMutableArray<GBTCounterView *> *counters = [NSMutableArray array];
        for (NSInteger j = 0; j < self.currentStep.groupCountsAfter[i].integerValue; j++) {
            [counters addObject:[self counterAtIndex:j width:width y:layout.groupCounterY unitSize:layout.groupUnitSize columns:5 color:[ChildUI candyColorAtIndex:i] inView:card]];
        }
        [self.groupCounters addObject:counters];
        NSString *countID = [NSString stringWithFormat:@"groupingGroupCount%ld", (long)i];
        [self.groupCountLabels addObject:[self label:@"" font:countFont frame:CGRectMake(GBTInset, layout.groupCountY, width - 2 * GBTInset, layout.groupCountHeight) identifier:countID inView:card]];
    }
    if (!CGRectIsEmpty(layout.emptyFrame)) [self label:self.isBuild ? @"還沒有建立任何一組。" : @"還沒有分出完整的一組。" font:body frame:layout.emptyFrame identifier:@"groupingEmptyGroups" inView:self.contentView];
    [self label:self.answerText font:[self font:21 maximum:32 weight:UIFontWeightBold] frame:layout.answerFrame identifier:@"groupingAnswer" inView:self.contentView];
    if (!CGRectIsEmpty(layout.remainderFrame)) [self label:self.remainderText font:body frame:layout.remainderFrame identifier:@"groupingRemainder" inView:self.contentView];
    [self updateStateLabels];
}

#pragma mark - Coherent before / moving / settled states

- (void)updateStateLabels {
    if (!self.currentStep) return;
    self.stateLabel.text = [self stateTextForPhase:self.displayPhase];
    self.actionLabel.text = [self actionTextForPhase:self.displayPhase];
    self.sourceLabel.text = [self sourceTextForPhase:self.displayPhase];
    BOOL settled = self.displayPhase == GBTDisplayPhaseSettled;
    NSArray<NSNumber *> *counts = settled ? self.currentStep.groupCountsAfter : self.currentStep.groupCountsBefore;
    for (NSInteger i = 0; i < (NSInteger)self.groupViews.count; i++) {
        self.groupTitleLabels[i].text = [self groupTitleAtIndex:i phase:self.displayPhase];
        NSInteger count = i < (NSInteger)counts.count ? counts[i].integerValue : 0;
        self.groupCountLabels[i].text = [NSString stringWithFormat:@"%ld %@", (long)count, self.sequence.context.itemUnit];
        // A prepared group has an explicit caption and stronger outline, not
        // faded text that would make the current zero/count harder to read.
        self.groupViews[i].alpha = 1;
        self.groupViews[i].layer.borderWidth = !settled && i >= (NSInteger)self.currentStep.groupCountsBefore.count ? 2 : 1.3;
    }
    NSInteger poolCount = self.displayPhase == GBTDisplayPhaseBefore ? self.currentStep.poolCountBefore.integerValue : self.currentStep.poolCountAfter.integerValue;
    self.sourceEmptyLabel.hidden = self.isBuild ? !settled : (poolCount != 0 || self.displayPhase == GBTDisplayPhaseMoving);
    NSMutableArray<NSString *> *spoken = [NSMutableArray arrayWithObjects:self.legendText, [self stateTextForPhase:self.displayPhase], nil];
    for (NSInteger i = 0; i < (NSInteger)counts.count; i++) {
        [spoken addObject:[NSString stringWithFormat:@"第 %ld %@有 %@ %@", (long)i + 1, self.sequence.context.groupName, counts[i], self.sequence.context.itemUnit]];
    }
    if (self.currentStep.poolCountAfter || (self.isBuild && self.isTransform && self.displayPhase == GBTDisplayPhaseBefore)) [spoken addObject:[self sourceTextForPhase:self.displayPhase]];
    if (self.displayPhase == GBTDisplayPhaseMoving) [spoken addObject:[NSString stringWithFormat:@"另外有 %ld %@正在移動", (long)self.movedCounterCount, self.sequence.context.itemUnit]];
    [spoken addObject:self.answerText];
    if (self.remainderText.length) [spoken addObject:self.remainderText];
    self.accessibilityValue = [spoken componentsJoinedByString:@"。"];
}
- (CGRect)currentTransformationRect {
    if (!self.isTransform || !self.renderedLayout || !self.sourceView) return CGRectNull;
    GBTLayout *layout = self.renderedLayout;
    CGRect region = CGRectNull;
    NSInteger movedIndex = 0;
    for (NSInteger group = 0; group < (NSInteger)self.currentStep.groupCountsAfter.count; group++) {
        NSInteger before = group < (NSInteger)self.currentStep.groupCountsBefore.count ? self.currentStep.groupCountsBefore[group].integerValue : 0;
        CGRect card = layout.groupFrames[group].CGRectValue;
        for (NSInteger item = before; item < self.currentStep.groupCountsAfter[group].integerValue; item++) {
            NSInteger sourceIndex = self.isBuild ? movedIndex : self.currentStep.poolCountAfter.integerValue + movedIndex;
            CGPoint start = [self counterCenter:sourceIndex inWidth:CGRectGetWidth(layout.sourceFrame) y:layout.sourceCounterY unitSize:layout.sourceUnitSize columns:layout.sourceColumns];
            start.x += CGRectGetMinX(layout.sourceFrame); start.y += CGRectGetMinY(layout.sourceFrame);
            CGPoint end = [self counterCenter:item inWidth:CGRectGetWidth(card) y:layout.groupCounterY unitSize:layout.groupUnitSize columns:5];
            end.x += CGRectGetMinX(card); end.y += CGRectGetMinY(card);
            CGRect source = CGRectMake(start.x - layout.sourceUnitSize / 2, start.y - layout.sourceUnitSize / 2, layout.sourceUnitSize, layout.sourceUnitSize);
            CGRect destination = CGRectMake(end.x - layout.groupUnitSize / 2, end.y - layout.groupUnitSize / 2, layout.groupUnitSize, layout.groupUnitSize);
            region = CGRectUnion(region, CGRectUnion(source, destination));
            movedIndex++;
        }
    }
    return region;
}
- (BOOL)canAnimate {
    if (!self.currentStep || !self.window || !ChildUI.motionEnabled || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return NO;
    for (UIView *view = self; view; view = view.superview) if (view.hidden || view.alpha <= 0.01) return NO;
    return CGRectGetWidth(self.bounds) > 0 && CGRectGetHeight(self.bounds) > 0;
}
- (void)animateCurrentAction {
    if (!self.isTransform || !self.contentView || !self.sourceView) return;
    GBTLayout *layout = self.renderedLayout;
    NSInteger movedIndex = 0;
    for (NSInteger group = 0; group < (NSInteger)self.currentStep.groupCountsAfter.count; group++) {
        NSInteger before = group < (NSInteger)self.currentStep.groupCountsBefore.count ? self.currentStep.groupCountsBefore[group].integerValue : 0;
        for (NSInteger item = before; item < self.currentStep.groupCountsAfter[group].integerValue; item++) {
            GBTCounterView *counter = self.groupCounters[group][item];
            GBTTransfer *transfer = [[GBTTransfer alloc] init];
            transfer.counter = counter;
            transfer.destinationView = counter.superview;
            transfer.destinationFrame = counter.frame;
            transfer.settledColor = counter.counterColor;
            transfer.end = [counter.superview convertPoint:counter.center toView:self.contentView];
            NSInteger sourceIndex = self.isBuild ? movedIndex : self.currentStep.poolCountAfter.integerValue + movedIndex;
            CGPoint source = [self counterCenter:sourceIndex inWidth:CGRectGetWidth(self.sourceView.bounds) y:layout.sourceCounterY unitSize:layout.sourceUnitSize columns:layout.sourceColumns];
            transfer.start = [self.sourceView convertPoint:source toView:self.contentView];
            transfer.sourceUnitSize = layout.sourceUnitSize;
            [counter removeFromSuperview];
            [self.contentView addSubview:counter];
            counter.bounds = CGRectMake(0, 0, transfer.sourceUnitSize, transfer.sourceUnitSize);
            counter.center = transfer.start;
            counter.counterColor = self.isBuild ? transfer.settledColor : ChildUI.skyBlue;
            [self.transfers addObject:transfer];
            movedIndex++;
        }
    }
    NSMutableArray<NSValue *> *sourcePoints = [NSMutableArray arrayWithCapacity:self.transfers.count];
    for (GBTTransfer *transfer in self.transfers) [sourcePoints addObject:[NSValue valueWithCGPoint:transfer.start]];
    NSComparator pointOrder = ^NSComparisonResult(NSValue *left, NSValue *right) {
        CGPoint a = left.CGPointValue, b = right.CGPointValue;
        if (fabs(a.x - b.x) > 0.1) return a.x < b.x ? NSOrderedAscending : NSOrderedDescending;
        if (fabs(a.y - b.y) > 0.1) return a.y < b.y ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    };
    [sourcePoints sortUsingComparator:pointOrder];
    NSArray<GBTTransfer *> *orderedTargets = [self.transfers sortedArrayUsingComparator:^NSComparisonResult(GBTTransfer *a, GBTTransfer *b) {
        return pointOrder([NSValue valueWithCGPoint:a.end], [NSValue valueWithCGPoint:b.end]);
    }];
    for (NSUInteger i = 0; i < orderedTargets.count; i++) {
        orderedTargets[i].start = sourcePoints[i].CGPointValue;
        orderedTargets[i].counter.center = orderedTargets[i].start;
    }
    self.displayPhase = GBTDisplayPhaseBefore;
    [self updateStateLabels];
    self.animationStartTime = CACurrentMediaTime();
    GBTWeakDisplayLinkTarget *target = [[GBTWeakDisplayLinkTarget alloc] init];
    target.target = self;
    self.animationDisplayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
    [self.animationDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)renderAnimationAtProgress:(CGFloat)progress {
    if (!self.animationDisplayLink) return;
    if (progress >= 1) { [self cancelAnimations]; return; }
    CGFloat travel = MIN(1, MAX(0, (progress - 0.16) / 0.66));
    // A finite pause before and after makes both quantities inspectable. While
    // moving, source and destination captions exclude the separately counted movers.
    GBTDisplayPhase phase = progress < 0.16 ? GBTDisplayPhaseBefore : (progress < 0.82 ? GBTDisplayPhaseMoving : GBTDisplayPhaseSettled);
    if (phase != self.displayPhase) { self.displayPhase = phase; [self updateStateLabels]; }
    CGFloat t = travel * travel * (3 - 2 * travel);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (GBTTransfer *transfer in self.transfers) {
        CGFloat arc = sin(M_PI * t) * 20;
        CGFloat unitSize = transfer.sourceUnitSize + (CGRectGetWidth(transfer.destinationFrame) - transfer.sourceUnitSize) * t;
        transfer.counter.bounds = CGRectMake(0, 0, unitSize, unitSize);
        transfer.counter.center = CGPointMake(transfer.start.x + (transfer.end.x - transfer.start.x) * t,
            transfer.start.y + (transfer.end.y - transfer.start.y) * t - arc);
        transfer.counter.counterColor = travel >= 1 ? transfer.settledColor : (self.isBuild ? transfer.settledColor : ChildUI.skyBlue);
    }
    [CATransaction commit];
}
- (void)animationTick:(CADisplayLink *)link {
    if (![self canAnimate]) { [self cancelAnimations]; return; }
    [self renderAnimationAtProgress:(CACurrentMediaTime() - self.animationStartTime) / GBTMotionDuration];
}
- (void)cancelAnimations {
    [self.animationDisplayLink invalidate];
    self.animationDisplayLink = nil;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (GBTTransfer *transfer in self.transfers) {
        [transfer.counter removeFromSuperview];
        [transfer.destinationView addSubview:transfer.counter];
        transfer.counter.frame = transfer.destinationFrame;
        transfer.counter.counterColor = transfer.settledColor;
    }
    [CATransaction commit];
    [self.transfers removeAllObjects];
    self.animationStartTime = 0;
    self.displayPhase = GBTDisplayPhaseSettled;
    [self updateStateLabels];
}
- (void)stopForNotification:(NSNotification *)notification { [self cancelAnimations]; }
- (void)contentSizeChanged:(NSNotification *)notification {
    [self cancelAnimations];
    self.needsSnapshotLayout = YES;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) [self contentSizeChanged:nil];
}
- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) [self cancelAnimations]; }
- (void)didMoveToSuperview { [super didMoveToSuperview]; if (!self.superview) [self cancelAnimations]; }
- (void)setHidden:(BOOL)hidden { [super setHidden:hidden]; if (hidden) [self cancelAnimations]; }
- (void)setAlpha:(CGFloat)alpha { [super setAlpha:alpha]; if (alpha <= 0.01) [self cancelAnimations]; }
@end
