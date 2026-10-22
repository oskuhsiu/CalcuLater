#import "GroupingTeachingFocusView.h"
#import "ChildUIKit.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

// Full-size countable objects, never scaled to manufacture a fit.
static const CGFloat GFTUnit = 20;
static const CGFloat GFTInset = 12;
static const NSTimeInterval GFTLead = 0.28;
static const NSTimeInterval GFTLeg = 0.82;
static const NSTimeInterval GFTTail = 0.24;

@interface GFTCounter : UIView
@property (nonatomic, strong) UIColor *color;
@end
@implementation GFTCounter
- (void)setColor:(UIColor *)color { _color = color; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, self.color.CGColor);
    CGContextFillEllipseInRect(context, CGRectInset(self.bounds, 1, 1));
    CGContextSetStrokeColorWithColor(context, [ChildUI.brownText colorWithAlphaComponent:0.65].CGColor);
    CGContextSetLineWidth(context, 1.2);
    CGContextStrokeEllipseInRect(context, CGRectInset(self.bounds, 1, 1));
}
@end
@interface GFTLayout : NSObject
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat actionHeight;
@property (nonatomic) CGRect caption;
@property (nonatomic) CGRect source;
@property (nonatomic) CGRect sourceTitle;
@property (nonatomic) CGFloat sourceCounterY;
@property (nonatomic) NSInteger sourceColumns;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSValue *> *groups;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSValue *> *groupTitles;
@property (nonatomic) CGFloat groupCounterY;
@property (nonatomic) CGRect summary;
@property (nonatomic) CGFloat laneX;
@end
@implementation GFTLayout @end

@interface GroupingTeachingFocusView ()
@property (nonatomic, strong, readwrite, nullable) GroupingTeachingAction *action;
@property (nonatomic, copy, readwrite) NSString *playbackState;
@property (nonatomic, copy, readwrite) NSString *spokenDescription;
@property (nonatomic, assign, readwrite) NSUInteger playbackGeneration;
@property (nonatomic, assign, readwrite) NSInteger displayedPoolCount;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *displayedGroupCounts;
@property (nonatomic, assign, readwrite) NSInteger inFlightCount;
@property (nonatomic, assign, readwrite, getter=isShowingBeforeState) BOOL showingBeforeState;
/// The maps below belong to this exact immutable action, only after construction.
@property (nonatomic, strong, nullable) GroupingTeachingAction *renderedAction;
@property (nonatomic, strong) GFTLayout *sceneLayout;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UILabel *sourceLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UILabel *> *groupLabels;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, GFTCounter *> *counters;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *sourcePoints;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *targetPoints;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *targetGroups;
@property (nonatomic, copy) NSArray<NSNumber *> *movingIDs;
@property (nonatomic, strong, nullable) CADisplayLink *clock;
@property (nonatomic) CFTimeInterval startedAt;
@property (nonatomic) CGSize renderedSize;
@property (nonatomic) BOOL sceneNeedsLayout;
- (void)tick:(CADisplayLink *)link generation:(NSUInteger)generation;
@end
@interface GFTClockTarget : NSObject
@property (nonatomic, weak) GroupingTeachingFocusView *view;
@property (nonatomic) NSUInteger generation;
- (void)tick:(CADisplayLink *)link;
@end
@implementation GFTClockTarget
- (void)tick:(CADisplayLink *)link { if (self.view) [self.view tick:link generation:self.generation]; else [link invalidate]; }
@end

@implementation GroupingTeachingFocusView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _playbackState = @"settled"; _spokenDescription = @""; _displayedGroupCounts = @[];
        self.backgroundColor = ChildUI.creamBackground; self.clipsToBounds = YES;
        self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitStaticText;
        self.accessibilityIdentifier = @"groupingTeachingBoard";
        self.accessibilityLabel = @"看清楚這一次怎麼分"; self.accessibilityLanguage = @"zh-TW";
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(interrupted:) name:UIApplicationWillResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(interrupted:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(textSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [_clock invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)configureWithAction:(GroupingTeachingAction *)action {
    // UIKit can deliver a pending trait change inside layoutIfNeeded, before
    // layoutSubviews. Retire the old action's entire scene BEFORE publishing
    // the new action, so its cancellation never uses the old bag/recipient IDs.
    [self invalidateClock]; [self clearScene]; self.action = action;
    self.playbackState = action && ![self motionAllowed] ? @"reduced-motion" : @"settled"; self.showingBeforeState = NO;
    self.sceneNeedsLayout = YES;
    [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; [self layoutIfNeeded];
}
- (BOOL)isShare { return self.action.sequence.context.meaning == GroupingStoryMeaningShareEqually; }
- (UIFont *)font {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightSemibold]
        maximumPointSize:28 compatibleWithTraitCollection:self.traitCollection];
}
- (CGFloat)textHeight:(NSString *)text width:(CGFloat)width {
    CGRect bounds = [text boundingRectWithSize:CGSizeMake(MAX(1, width), CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:self.font} context:nil];
    return ceil(MAX(self.font.lineHeight, bounds.size.height)) + 2;
}
- (NSArray<NSNumber *> *)activeGroups { return self.action.snapshot.activeGroupIndices; }
- (NSString *)captionForStatus:(NSString *)status {
    if (self.isShare && !self.action.isFullAction) return [NSString stringWithFormat:@"%@\n這輪每位只再拿 1 %@\n%@", self.action.progressText, self.action.sequence.context.itemUnit, status];
    return [NSString stringWithFormat:@"%@\n%@", self.action.progressText ?: @"", status];
}
- (NSString *)sourceTitle:(NSInteger)count { return [NSString stringWithFormat:@"共同待分：%ld %@", (long)count, self.action.sequence.context.itemUnit]; }
- (NSString *)groupTitle:(NSInteger)group count:(NSInteger)count {
    return [NSString stringWithFormat:@"第 %ld %@：%ld %@", (long)group + 1, self.action.sequence.context.groupName, (long)count, self.action.sequence.context.itemUnit];
}
- (NSString *)summaryForCounts:(NSArray<NSNumber *> *)counts {
    NSInteger total = 0, others = 0;
    NSSet *active = [NSSet setWithArray:self.activeGroups];
    for (NSInteger index = 0; index < (NSInteger)counts.count; index++) if (![active containsObject:@(index)]) { total += counts[index].integerValue; others++; }
    GroupingStoryContext *context = self.action.sequence.context;
    NSString *other = others ? [NSString stringWithFormat:@"\n另外 %ld %@共有 %ld %@，可按「看全部」查看。", (long)others, context.groupName, (long)total, context.itemUnit] : @"";
    return [NSString stringWithFormat:@"每個圓點是 1 %@%@\n仍是原來的 %ld %@", context.itemUnit, other, (long)self.action.sequence.problem.number1, context.itemUnit];
}
- (GFTLayout *)layoutForWidth:(CGFloat)width {
    GFTLayout *layout = [[GFTLayout alloc] init];
    if (!self.action) return layout;
    CGFloat available = MAX(1, width - 2 * GFTInset), y = GFTInset;
    NSArray *captions = @[[self captionForStatus:@"動作前 · 先數一數"], [self captionForStatus:[NSString stringWithFormat:@"移動中：1 %@", self.action.sequence.context.itemUnit]],
        [self captionForStatus:@"這一步完成 · 再慢慢看"], [self captionForStatus:@"先停下來 · 可轉直重看"], [self captionForStatus:@"不播放移動 · 可比較前後"],
        [self captionForStatus:@"已停在這一步 · 按重看"], [self captionForStatus:@"先數一數 · 還是同一份"]];
    CGFloat captionHeight = 0;
    for (NSString *caption in captions) captionHeight = MAX(captionHeight, [self textHeight:caption width:available]);
    layout.caption = CGRectMake(GFTInset, y, available, captionHeight); y += captionHeight + 8;
    // The right lane is outside every card/title. A 20 pt mover has 12 pt
    // clearance from the right card edge and stays inside the scene bounds.
    CGFloat cardWidth = MAX(1, width - 52), inner = MAX(1, cardWidth - 2 * GFTInset);
    layout.laneX = width - 18;
    layout.sourceColumns = MAX(1, MIN(10, (NSInteger)floor((inner + 4) / 24)));
    CGFloat sourceTitleHeight = MAX([self textHeight:[self sourceTitle:self.action.snapshot.poolCountBefore.integerValue] width:inner],
        [self textHeight:[self sourceTitle:self.action.snapshot.poolCountAfter.integerValue] width:inner]);
    sourceTitleHeight = MAX(sourceTitleHeight, [self textHeight:[self sourceTitle:self.action.sequence.problem.number1] width:inner]);
    layout.sourceCounterY = GFTInset + sourceTitleHeight + 8;
    // Reserve the original source tray, including its original digit-width title.
    NSInteger rows = (self.action.sequence.problem.number1 + layout.sourceColumns - 1) / layout.sourceColumns;
    CGFloat poolHeight = layout.sourceCounterY + MAX(GFTUnit, rows * 26 - 6) + GFTInset;
    layout.source = CGRectMake(GFTInset, y, cardWidth, poolHeight);
    layout.sourceTitle = CGRectMake(GFTInset * 2, y + GFTInset, inner, sourceTitleHeight);
    y = CGRectGetMaxY(layout.source) + 12;
    NSMutableDictionary *groups = [NSMutableDictionary dictionary], *titles = [NSMutableDictionary dictionary];
    layout.groupCounterY = GFTInset;
    for (NSNumber *group in self.activeGroups) {
        NSInteger index = group.integerValue;
        NSInteger before = index < (NSInteger)self.action.snapshot.groupCountsBefore.count ? self.action.snapshot.groupCountsBefore[index].integerValue : 0;
        NSInteger after = self.action.snapshot.groupCountsAfter[index].integerValue;
        CGFloat titleHeight = MAX([self textHeight:[self groupTitle:index count:before] width:inner], [self textHeight:[self groupTitle:index count:after] width:inner]);
        // Two fixed rows; labels BELOW the tray, never across incoming routes.
        CGFloat titleY = y + GFTInset + 46 + 8;
        groups[group] = [NSValue valueWithCGRect:CGRectMake(GFTInset, y, cardWidth, GFTInset + 46 + 8 + titleHeight + GFTInset)];
        titles[group] = [NSValue valueWithCGRect:CGRectMake(GFTInset * 2, titleY, inner, titleHeight)];
        y = CGRectGetMaxY([groups[group] CGRectValue]) + 12;
    }
    layout.groups = groups; layout.groupTitles = titles; layout.actionHeight = ceil(y);
    CGFloat summaryHeight = MAX([self textHeight:[self summaryForCounts:self.action.snapshot.groupCountsBefore] width:available],
        [self textHeight:[self summaryForCounts:self.action.snapshot.groupCountsAfter] width:available]);
    layout.summary = CGRectMake(GFTInset, y, available, summaryHeight); y += summaryHeight + GFTInset;
    layout.height = ceil(y); return layout;
}
- (CGSize)requiredActionSizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self layoutForWidth:MAX(1, size.width)].actionHeight); }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self layoutForWidth:MAX(1, size.width)].height); }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, [self sizeThatFits:self.bounds.size].height); }
- (CGRect)requiredActionRect { return self.action && self.renderedAction == self.action && self.sceneLayout ? CGRectMake(0, 0, CGRectGetWidth(self.bounds), self.sceneLayout.actionHeight) : CGRectNull; }
- (CGRect)accessibilityFrame {
    CGRect rect = self.requiredActionRect;
    return !CGRectIsNull(rect) ? UIAccessibilityConvertFrameToScreenCoordinates(rect, self) : [super accessibilityFrame];
}
- (UILabel *)label:(CGRect)frame identifier:(NSString *)identifier {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.numberOfLines = 0; label.font = self.font; label.textColor = ChildUI.brownText;
    label.isAccessibilityElement = NO; label.accessibilityIdentifier = identifier;
    [self addSubview:label]; return label;
}
- (void)card:(CGRect)frame color:(UIColor *)color identifier:(NSString *)identifier {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [color colorWithAlphaComponent:0.25]; card.layer.cornerRadius = 16; card.layer.borderWidth = 1.3;
    card.layer.borderColor = [ChildUI.brownText colorWithAlphaComponent:0.5].CGColor;
    card.isAccessibilityElement = NO; card.accessibilityIdentifier = identifier; [self addSubview:card];
}
- (CGPoint)pointForIndex:(NSInteger)index card:(CGRect)card counterY:(CGFloat)y columns:(NSInteger)columns {
    CGFloat trayWidth = columns * 20 + (columns - 1) * 4;
    return CGPointMake(CGRectGetMinX(card) + (CGRectGetWidth(card) - trayWidth) / 2 + 10 + (index % columns) * 24,
        CGRectGetMinY(card) + y + 10 + (index / columns) * 26);
}
- (GFTCounter *)counter:(NSNumber *)identity color:(UIColor *)color point:(CGPoint)point {
    GFTCounter *counter = self.counters[identity];
    if (!counter) {
        counter = [[GFTCounter alloc] initWithFrame:CGRectMake(0, 0, GFTUnit, GFTUnit)];
        counter.backgroundColor = UIColor.clearColor; counter.isAccessibilityElement = NO;
        counter.accessibilityIdentifier = [NSString stringWithFormat:@"grouping.focus.counter.%@", identity];
        self.counters[identity] = counter; [self addSubview:counter];
    }
    counter.color = color; counter.center = point; return counter;
}
- (void)clearScene {
    // Mark the scene unavailable before removing UIKit views, too. Lifecycle
    // callbacks during replacement may invalidate playback, but cannot render.
    self.renderedAction = nil; self.sceneLayout = nil;
    for (UIView *view in self.subviews.copy) [view removeFromSuperview];
    self.counters = [NSMutableDictionary dictionary]; self.sourcePoints = [NSMutableDictionary dictionary];
    self.targetPoints = [NSMutableDictionary dictionary]; self.targetGroups = [NSMutableDictionary dictionary];
    self.groupLabels = [NSMutableDictionary dictionary]; self.movingIDs = @[];
    self.captionLabel = nil; self.sourceLabel = nil; self.summaryLabel = nil;
    self.displayedPoolCount = 0; self.displayedGroupCounts = @[]; self.inFlightCount = 0;
    self.accessibilityValue = nil; self.spokenDescription = @"";
}
- (void)layoutSubviews {
    [super layoutSubviews];
    BOOL resized = !CGSizeEqualToSize(self.renderedSize, self.bounds.size);
    if (!resized && !self.sceneNeedsLayout) return;
    BOOL interrupted = self.clock != nil, inspectingBefore = self.showingBeforeState && !interrupted;
    [self invalidateClock]; self.renderedSize = self.bounds.size; self.sceneNeedsLayout = NO;
    [self clearScene];
    if (!self.action || CGRectGetWidth(self.bounds) <= 0) return;
    self.sceneLayout = [self layoutForWidth:CGRectGetWidth(self.bounds)];
    GFTLayout *layout = self.sceneLayout;
    self.captionLabel = [self label:layout.caption identifier:@"grouping.focus.caption"];
    [self card:layout.source color:ChildUI.skyBlue identifier:@"grouping.focus.pool"];
    self.sourceLabel = [self label:layout.sourceTitle identifier:@"grouping.focus.poolCount"];
    for (NSNumber *group in self.activeGroups) {
        [self card:layout.groups[group].CGRectValue color:[ChildUI candyColorAtIndex:group.integerValue] identifier:[NSString stringWithFormat:@"grouping.focus.group.%@", group]];
        self.groupLabels[group] = [self label:layout.groupTitles[group].CGRectValue identifier:[NSString stringWithFormat:@"grouping.focus.groupCount.%@", group]];
    }
    self.summaryLabel = [self label:layout.summary identifier:@"grouping.focus.summary"];
    for (NSInteger index = 0; index < self.action.snapshot.poolCountBefore.integerValue; index++) {
        CGPoint point = [self pointForIndex:index card:layout.source counterY:layout.sourceCounterY columns:layout.sourceColumns];
        self.sourcePoints[@(index)] = [NSValue valueWithCGPoint:point];
        [self counter:@(index) color:ChildUI.skyBlue point:point];
    }
    NSMutableArray *moving = [NSMutableArray array];
    for (NSNumber *group in self.activeGroups) {
        NSInteger groupIndex = group.integerValue;
        NSArray<NSNumber *> *ids = self.action.groupIdentitiesAfter[groupIndex];
        for (NSInteger index = 0; index < (NSInteger)ids.count; index++) {
            NSNumber *identity = ids[index];
            CGPoint point = [self pointForIndex:index card:layout.groups[group].CGRectValue counterY:layout.groupCounterY columns:5];
            self.targetPoints[identity] = [NSValue valueWithCGPoint:point]; self.targetGroups[identity] = group;
            [self counter:identity color:[ChildUI candyColorAtIndex:groupIndex] point:point];
            if (self.sourcePoints[identity]) [moving addObject:identity];
        }
    }
    // Tail-first source exits and left-to-right target arrivals have empty lanes.
    [moving sortUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) { return [b compare:a]; }];
    self.movingIDs = moving; self.renderedAction = self.action;
    if (interrupted) self.playbackState = @"cancelled";
    [self renderCompletedCount:inspectingBefore ? 0 : moving.count movingProgress:-1 before:inspectingBefore];
}
- (NSString *)statusText {
    if ([self.playbackState isEqualToString:@"paused-visibility"]) return @"先停下來 · 可轉直重看";
    if ([self.playbackState isEqualToString:@"cancelled"]) return @"已停在這一步 · 按重看";
    if (self.showingBeforeState) return @"動作前 · 先數一數";
    if ([self.playbackState isEqualToString:@"running"]) return self.inFlightCount ? [NSString stringWithFormat:@"移動中：1 %@", self.action.sequence.context.itemUnit] : @"先數一數 · 還是同一份";
    if ([self.playbackState isEqualToString:@"reduced-motion"]) return @"不播放移動 · 可比較前後";
    return @"這一步完成 · 再慢慢看";
}
- (void)updateLabels {
    if (!self.action || self.renderedAction != self.action) return;
    self.captionLabel.text = [self captionForStatus:self.statusText]; self.sourceLabel.text = [self sourceTitle:self.displayedPoolCount];
    for (NSNumber *group in self.activeGroups) self.groupLabels[group].text = [self groupTitle:group.integerValue count:self.displayedGroupCounts[group.integerValue].integerValue];
    self.summaryLabel.text = [self summaryForCounts:self.displayedGroupCounts];
    NSMutableArray *spoken = [NSMutableArray arrayWithObjects:self.action.progressText, self.statusText, nil];
    if (self.isShare) [spoken addObject:[NSString stringWithFormat:@"平均分給 %lu %@；這輪每位只再拿 1 %@", (unsigned long)self.displayedGroupCounts.count, self.action.sequence.context.groupName, self.action.sequence.context.itemUnit]];
    else [spoken addObject:[NSString stringWithFormat:@"已分成 %ld %@", (long)(self.action.snapshot.groupCountsBefore.count + (self.displayedPoolCount == self.action.snapshot.poolCountAfter.integerValue && !self.inFlightCount ? 1 : 0)), self.action.sequence.context.groupName]];
    for (NSInteger index = 0; index < (NSInteger)self.displayedGroupCounts.count; index++) [spoken addObject:[NSString stringWithFormat:@"第 %ld %@有 %@ %@", (long)index + 1, self.action.sequence.context.groupName, self.displayedGroupCounts[index], self.action.sequence.context.itemUnit]];
    [spoken addObject:[NSString stringWithFormat:@"%@的%@：%ld %@", self.isShare ? @"待分" : @"待分組", self.action.sequence.context.itemName, (long)self.displayedPoolCount, self.action.sequence.context.itemUnit]];
    if (self.inFlightCount) [spoken addObject:[NSString stringWithFormat:@"另外有 1 %@正在移動", self.action.sequence.context.itemUnit]];
    [spoken addObject:@"答案還沒寫，先把數量看清楚。"];
    self.spokenDescription = [spoken componentsJoinedByString:@"。"];
    if ([self.playbackState isEqualToString:@"completed"]) [spoken addObject:@"播放完成"];
    [spoken addObject:[@"播放狀態：" stringByAppendingString:self.playbackState]];
    self.accessibilityValue = [spoken componentsJoinedByString:@"。"];
}
- (CGPoint)routeFrom:(CGPoint)start to:(CGPoint)end progress:(CGFloat)progress {
    CGFloat lane = self.sceneLayout.laneX;
    CGFloat a = fabs(lane - start.x), b = fabs(end.y - start.y), c = fabs(lane - end.x);
    CGFloat distance = MAX(0, MIN(1, progress)) * (a + b + c);
    if (distance <= a) return CGPointMake(start.x + distance, start.y);
    if (distance <= a + b) return CGPointMake(lane, start.y + (end.y >= start.y ? 1 : -1) * (distance - a));
    return CGPointMake(lane - (distance - a - b), end.y);
}
- (void)renderCompletedCount:(NSInteger)completed movingProgress:(CGFloat)progress before:(BOOL)before {
    self.showingBeforeState = before;
    if (!self.action || self.renderedAction != self.action) return;
    completed = MAX(0, MIN(completed, (NSInteger)self.movingIDs.count));
    NSMutableArray<NSNumber *> *counts = [self.action.snapshot.groupCountsBefore mutableCopy];
    while (counts.count < self.action.snapshot.groupCountsAfter.count) [counts addObject:@0];
    NSSet *completeIDs = [NSSet setWithArray:[self.movingIDs subarrayWithRange:NSMakeRange(0, completed)]];
    NSNumber *movingID = progress >= 0 && completed < (NSInteger)self.movingIDs.count ? self.movingIDs[completed] : nil;
    self.inFlightCount = movingID ? 1 : 0; self.displayedPoolCount = self.action.snapshot.poolCountBefore.integerValue - completed - self.inFlightCount;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    @try {
        for (NSNumber *identity in self.counters) {
            GFTCounter *counter = self.counters[identity];
            BOOL arrived = [completeIDs containsObject:identity], originalTarget = !self.sourcePoints[identity];
            if (arrived || originalTarget) {
                counter.center = self.targetPoints[identity].CGPointValue;
                counter.color = [ChildUI candyColorAtIndex:self.targetGroups[identity].integerValue];
                if (arrived) { NSInteger group = self.targetGroups[identity].integerValue; counts[group] = @(counts[group].integerValue + 1); }
            } else if ([identity isEqual:movingID]) {
                counter.center = [self routeFrom:self.sourcePoints[identity].CGPointValue to:self.targetPoints[identity].CGPointValue progress:progress];
                counter.color = [ChildUI candyColorAtIndex:self.targetGroups[identity].integerValue];
                [self bringSubviewToFront:counter];
            } else { counter.center = self.sourcePoints[identity].CGPointValue; counter.color = ChildUI.skyBlue; }
        }
    } @finally {
        // Do not swallow an invariant failure, but never leave an explicit
        // transaction open to contaminate unrelated views or later callbacks.
        [CATransaction commit];
    }
    self.displayedGroupCounts = counts; [self updateLabels];
}
- (BOOL)motionAllowed { return ChildUI.motionEnabled; }
- (BOOL)applicationActive { return UIApplication.sharedApplication.applicationState == UIApplicationStateActive; }
- (BOOL)actuallyVisible {
    if (!self.window || CGRectIsNull(self.requiredActionRect)) return NO;
    CGRect visible = CGRectIntersection(self.bounds, [self.window convertRect:self.window.bounds toView:self]);
    for (UIView *view = self; view; view = view.superview) {
        if (view.hidden || view.alpha < 0.01) return NO;
        if (view.clipsToBounds) visible = CGRectIntersection(visible, [view convertRect:view.bounds toView:self]);
    }
    return CGRectContainsRect(CGRectInset(visible, -0.5, -0.5), self.requiredActionRect);
}
- (BOOL)playInVisibleRect:(CGRect)visibleRect {
    [self cancelPlayback]; [self layoutIfNeeded];
    if (!self.action || !self.movingIDs.count) return NO;
    if (!CGRectContainsRect(CGRectInset(visibleRect, -0.5, -0.5), self.requiredActionRect) || ![self actuallyVisible]) { [self pauseForVisibility]; return NO; }
    if (![self motionAllowed]) { self.playbackState = @"reduced-motion"; [self renderCompletedCount:self.movingIDs.count movingProgress:-1 before:NO]; return NO; }
    if (![self applicationActive]) { self.playbackState = @"cancelled"; [self renderCompletedCount:self.movingIDs.count movingProgress:-1 before:NO]; return NO; }
    self.playbackState = @"running"; self.startedAt = CACurrentMediaTime();
    [self renderCompletedCount:0 movingProgress:-1 before:YES];
    GFTClockTarget *target = [[GFTClockTarget alloc] init]; target.view = self; target.generation = self.playbackGeneration;
    self.clock = [CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
    [self.clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return YES;
}
- (void)renderElapsed:(NSTimeInterval)elapsed {
    if (![self.playbackState isEqualToString:@"running"]) return;
    NSTimeInterval duration = GFTLead + self.movingIDs.count * GFTLeg + GFTTail;
    if (elapsed >= duration) {
        [self invalidateClock]; self.playbackState = @"completed";
        [self renderCompletedCount:self.movingIDs.count movingProgress:-1 before:NO]; return;
    }
    if (elapsed < GFTLead) { [self renderCompletedCount:0 movingProgress:-1 before:YES]; return; }
    CGFloat actionTime = (elapsed - GFTLead) / GFTLeg;
    NSInteger completed = MIN((NSInteger)floor(actionTime), (NSInteger)self.movingIDs.count);
    CGFloat local = actionTime - completed;
    if (completed == (NSInteger)self.movingIDs.count) [self renderCompletedCount:completed movingProgress:-1 before:NO];
    else if (local >= 0.84) [self renderCompletedCount:completed + 1 movingProgress:-1 before:NO];
    else [self renderCompletedCount:completed movingProgress:local / 0.84 before:NO];
}
- (void)tick:(CADisplayLink *)link generation:(NSUInteger)generation {
    if (link != self.clock || generation != self.playbackGeneration) return;
    if (![self actuallyVisible]) { [self pauseForVisibility]; return; }
    if (![self motionAllowed]) { [self settleForReducedMotion]; return; }
    if (![self applicationActive]) { [self cancelPlayback]; return; }
    [self renderElapsed:CACurrentMediaTime() - self.startedAt];
}
- (void)invalidateClock { [self.clock invalidate]; self.clock = nil; self.playbackGeneration++; self.startedAt = 0; }
- (void)cancelPlayback {
    BOOL running = self.clock != nil;
    [self invalidateClock]; if (running) self.playbackState = @"cancelled";
    BOOL preserveBefore = self.showingBeforeState && !running;
    [self renderCompletedCount:preserveBefore ? 0 : self.movingIDs.count movingProgress:-1 before:preserveBefore];
}
- (void)pauseForVisibility {
    BOOL preserveBefore = self.showingBeforeState && self.clock == nil;
    [self invalidateClock]; self.playbackState = @"paused-visibility";
    [self renderCompletedCount:preserveBefore ? 0 : self.movingIDs.count movingProgress:-1 before:preserveBefore];
}
- (void)showBeforeState { [self invalidateClock]; self.playbackState = [self motionAllowed] ? @"before" : @"reduced-motion"; [self renderCompletedCount:0 movingProgress:-1 before:YES]; }
- (void)showAfterState { [self invalidateClock]; self.playbackState = [self motionAllowed] ? @"settled" : @"reduced-motion"; [self renderCompletedCount:self.movingIDs.count movingProgress:-1 before:NO]; }
- (void)settleForReducedMotion {
    [self cancelPlayback];
    // Containment remains a separate gate. A preference notification cannot
    // turn a paused offscreen scene into a claim of visible playback.
    if (self.action && ![self.playbackState isEqualToString:@"paused-visibility"]) {
        self.playbackState = @"reduced-motion"; [self updateLabels];
    }
}
- (void)interrupted:(NSNotification *)notification {
    if ([notification.name isEqualToString:UIAccessibilityReduceMotionStatusDidChangeNotification] && ![self motionAllowed]) {
        [self settleForReducedMotion]; return;
    }
    [self cancelPlayback];
    if ([notification.name isEqualToString:UIAccessibilityReduceMotionStatusDidChangeNotification] && [self.playbackState isEqualToString:@"reduced-motion"]) {
        self.playbackState = self.showingBeforeState ? @"before" : @"settled"; [self updateLabels];
    }
}
- (void)textSizeChanged:(NSNotification *)notification { [self cancelPlayback]; self.sceneNeedsLayout = YES; [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) [self textSizeChanged:nil];
}
- (void)setHidden:(BOOL)hidden { if (hidden) [self cancelPlayback]; [super setHidden:hidden]; }
- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) [self cancelPlayback]; }
- (void)didMoveToSuperview { [super didMoveToSuperview]; if (!self.superview) [self cancelPlayback]; }
@end
