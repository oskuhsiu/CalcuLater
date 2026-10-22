#import "MultiplicativePlaceValueBoardView.h"
#import "MultiplicativePlaceValueScene.h"
#import "ChildUIKit.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

/// The outer body is exactly 16x16, 16x160, or 160x160. All ink is inset;
/// internal seams remain at the 16-point cell boundaries, even while docking.
@interface MTPMaterialView : UIView
@property (nonatomic, strong) MultiplicativeTeachingUnit *unit;
@property (nonatomic, copy) NSString *owner;
@property (nonatomic) BOOL carryAnnotation;
@end
@implementation MTPMaterialView
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *fill = self.unit.column == 0 ? ChildUI.skyBlue : (self.unit.column == 1 ? ChildUI.eggYolk : ChildUI.mintGreen);
    CGContextSetFillColorWithColor(context, fill.CGColor); CGContextFillRect(context, self.bounds);
    // Two touching half-point outer edges become one full-point internal seam.
    // Docked small units and their replacement therefore have matching seam ink.
    CGContextSetStrokeColorWithColor(context, ChildUI.brownText.CGColor); CGContextSetLineWidth(context, .5);
    CGContextStrokeRect(context, CGRectInset(self.bounds, .25, .25));
    CGContextSetLineWidth(context, 1);
    for (CGFloat x = 16; x < self.bounds.size.width; x += 16) { CGContextMoveToPoint(context, x, .5); CGContextAddLineToPoint(context, x, self.bounds.size.height - .5); }
    for (CGFloat y = 16; y < self.bounds.size.height; y += 16) { CGContextMoveToPoint(context, .5, y); CGContextAddLineToPoint(context, self.bounds.size.width - .5, y); }
    CGContextStrokePath(context);
    if (self.carryAnnotation) {
        // Annotation inside the existing unit, not a second owned object.
        CGContextSetStrokeColorWithColor(context, ChildUI.brownText.CGColor); CGContextSetLineWidth(context, 2);
        CGContextMoveToPoint(context, 3, 7); CGContextAddLineToPoint(context, 3, 3); CGContextAddLineToPoint(context, 7, 3); CGContextStrokePath(context);
    }
}
@end
@interface MTPOverviewLayout : NSObject
@property (nonatomic) CGSize size;
@property (nonatomic, copy) NSArray<MTPPlaceValueUnitPlacement *> *placements;
@property (nonatomic, copy) NSDictionary<NSString *, NSValue *> *labelFrames;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *labelTexts;
@end
@implementation MTPOverviewLayout @end

/// Immutable identity fence for one clock. The scene itself owns all origins.
@interface MTPPlaybackTransaction : NSObject
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *selectionID;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) NSUInteger revision;
@property (nonatomic, strong) MultiplicativeTeachingAction *action;
@property (nonatomic, strong) MultiplicativePlaceValueScene *scene;
@property (nonatomic, strong) MultiplicativeTeachingActionSnapshot *before;
@property (nonatomic, strong) MultiplicativeTeachingActionSnapshot *after;
@property (nonatomic, copy) NSArray<UIScrollView *> *scrollViews;
@property (nonatomic, copy) NSArray<NSValue *> *scrollOffsets;
@end
@implementation MTPPlaybackTransaction @end
@interface MultiplicativePlaceValueBoardView ()
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingAction *action;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingActionSnapshot *snapshot;
@property (nonatomic, strong, readwrite, nullable) MultiplicativePlaceValueScene *scene;
@property (nonatomic, copy, readwrite) NSString *sessionID;
@property (nonatomic, copy, readwrite, nullable) NSString *selectionID;
@property (nonatomic, assign, readwrite) MTPPlaceValueEndpoint endpoint;
@property (nonatomic, assign, readwrite) MTPPlaceValuePlaybackState playbackState;
@property (nonatomic, assign, readwrite) MTPPlaceValueInterruptionReason interruptionReason;
@property (nonatomic, assign, readwrite) NSUInteger playbackGeneration;
@property (nonatomic, assign, readwrite) NSUInteger layoutRevision;
@property (nonatomic, assign, readwrite) BOOL displayingFullSnapshot;
@property (nonatomic, copy, readwrite) NSString *statusExplanation;
@property (nonatomic, copy, readwrite) NSString *spokenDescription;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, MTPMaterialView *> *unitViews;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UILabel *> *labels;
@property (nonatomic, strong, nullable) UIView *cradle;
@property (nonatomic, strong, nullable) MTPPlaceValueProjection *projection;
@property (nonatomic, copy) NSSet<CALayer *> *retiredOwnedRootLayers;
@property (nonatomic, strong, nullable) MTPOverviewLayout *overviewLayout;
@property (nonatomic, strong, nullable) MTPPlaybackTransaction *transaction;
@property (nonatomic, strong, nullable) CADisplayLink *clock;
@property (nonatomic) CFTimeInterval startTimestamp;
@property (nonatomic) CFTimeInterval lastTimestamp;
@property (nonatomic) CGRect requestedVisibleRect;
@property (nonatomic) CGSize renderedSize;
@property (nonatomic) BOOL updatingBindings;
@property (nonatomic) BOOL needsSceneLayout;
- (void)tick:(CADisplayLink *)link transaction:(MTPPlaybackTransaction *)transaction;
- (void)advanceClockAtTimestamp:(CFTimeInterval)timestamp transaction:(MTPPlaybackTransaction *)transaction clock:(CADisplayLink *)link;
@end
@interface MTPClockTarget : NSObject
@property (nonatomic, weak) MultiplicativePlaceValueBoardView *board;
@property (nonatomic, strong) MTPPlaybackTransaction *transaction;
- (void)tick:(CADisplayLink *)link;
@end
@implementation MTPClockTarget
- (void)tick:(CADisplayLink *)link { if (self.board) [self.board tick:link transaction:self.transaction]; else [link invalidate]; }
@end

@implementation MultiplicativePlaceValueBoardView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _sessionID = @""; _statusExplanation = @""; _spokenDescription = @""; _playbackState = MTPPlaceValuePlaybackStateEmpty;
        _unitViews = [NSMutableDictionary dictionary]; _labels = [NSMutableDictionary dictionary];
        self.clipsToBounds = YES; self.backgroundColor = ChildUI.creamBackground;
        self.accessibilityIdentifier = @"multiplicative.place.board"; self.accessibilityLabel = @"位值積木"; self.isAccessibilityElement = NO;
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(backgrounded:) name:UIApplicationWillResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(motionChanged:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(textChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [_clock invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (UIFont *)materialFont {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightSemibold] compatibleWithTraitCollection:self.traitCollection];
}
- (BOOL)motionAllowed { return ChildUI.motionEnabled; }
- (BOOL)applicationActive { return UIApplication.sharedApplication.applicationState == UIApplicationStateActive; }
- (void)invalidateClock {
    self.playbackGeneration++; [self.clock invalidate]; self.clock = nil; self.transaction = nil; self.startTimestamp = 0; self.lastTimestamp = 0;
}
- (NSSet<CALayer *> *)ownedRootLayers {
    NSMutableSet *layers = [NSMutableSet set];
    for (UIView *view in self.unitViews.allValues) [layers addObject:view.layer];
    for (UIView *view in self.labels.allValues) [layers addObject:view.layer];
    if (self.cradle) [layers addObject:self.cradle.layer];
    return layers.copy;
}
- (void)clearPaint {
    // Only these exact retired roots may still appear in CA's old presentation
    // during synchronous preparation. They are never exempt on a running tick.
    NSSet *owned = [self ownedRootLayers]; NSMutableSet *retired = [NSMutableSet set];
    for (CALayer *paint in self.layer.presentationLayer.sublayers) {
        CALayer *model = paint.modelLayer;
        if (model && ([owned containsObject:model] || [self.retiredOwnedRootLayers containsObject:model])) [retired addObject:model];
    }
    [retired unionSet:owned]; self.retiredOwnedRootLayers = retired.copy;
    // Retire ownership before UIKit trait/layout callbacks from view removal.
    NSDictionary *units = self.unitViews; NSDictionary *labels = self.labels; UIView *cradle = self.cradle;
    self.unitViews = [NSMutableDictionary dictionary]; self.labels = [NSMutableDictionary dictionary]; self.cradle = nil; self.projection = nil; self.overviewLayout = nil;
    for (UIView *view in units.allValues) [view removeFromSuperview];
    for (UIView *view in labels.allValues) [view removeFromSuperview]; [cradle removeFromSuperview];
}
- (void)beginSelectionReplacement {
    self.updatingBindings = YES; [self invalidateClock];
    self.scene = nil; self.action = nil; self.snapshot = nil; self.selectionID = nil;
    self.spokenDescription = @""; self.accessibilityValue = nil;
    [self clearPaint]; self.layoutRevision++;
}
- (void)notifyState { if (self.playbackStateDidChange) self.playbackStateDidChange(self.playbackState); }
- (void)installCanonicalSpeech {
    NSString *current = self.action ? (self.endpoint == MTPPlaceValueEndpointBefore ? self.action.spokenBefore : self.action.spokenAfter) : self.snapshot.spokenDescription;
    current = current ?: @"";
    self.spokenDescription = self.statusExplanation.length ? [NSString stringWithFormat:@"%@ %@", self.statusExplanation, current] : current;
    self.accessibilityValue = self.spokenDescription;
}
- (void)configureWithAction:(MultiplicativeTeachingAction *)action sessionID:(NSString *)sessionID selectionID:(NSString *)selectionID endpoint:(MTPPlaceValueEndpoint)endpoint {
    [self beginSelectionReplacement]; self.sessionID = sessionID; self.selectionID = selectionID; self.action = action; self.endpoint = endpoint;
    self.snapshot = endpoint == MTPPlaceValueEndpointBefore ? action.before : action.after;
    self.playbackState = MTPPlaceValuePlaybackStateStatic; self.interruptionReason = MTPPlaceValueInterruptionReasonNone; self.statusExplanation = @"";
    self.displayingFullSnapshot = action.inputUnits.count == 0 && action.outputUnits.count == 0;
    [self installCanonicalSpeech]; self.needsSceneLayout = YES; self.updatingBindings = NO; [self rebuildIfNeeded]; [self notifyState];
}
- (void)configureWithSnapshot:(MultiplicativeTeachingActionSnapshot *)snapshot sessionID:(NSString *)sessionID {
    [self beginSelectionReplacement]; self.sessionID = sessionID; self.snapshot = snapshot; self.endpoint = MTPPlaceValueEndpointBefore;
    self.displayingFullSnapshot = YES; self.playbackState = MTPPlaceValuePlaybackStateStatic; self.interruptionReason = MTPPlaceValueInterruptionReasonNone; self.statusExplanation = @"";
    [self installCanonicalSpeech]; self.needsSceneLayout = YES; self.updatingBindings = NO; [self rebuildIfNeeded]; [self notifyState];
}
- (NSString *)statusForState:(MTPPlaceValuePlaybackState)state {
    switch (state) {
        case MTPPlaceValuePlaybackStateCompleted: return @"這個動作播放完了；可以慢慢比較動作前／後。";
        case MTPPlaceValuePlaybackStateStationary: return @"這一步沒有積木移動，可以慢慢比較動作前／後。";
        case MTPPlaceValuePlaybackStateReducedMotion: return @"已開啟減少動態效果，這次不播放。可以比較動作前／後，也可以看全部。";
        case MTPPlaceValuePlaybackStateInsufficientSpace: return @"現在無法完整看清這個動作，這次先不播放。可以切換動作前／後，也可以看全部；調整畫面後，按重看才會再試一次。";
        case MTPPlaceValuePlaybackStateInterrupted: return @"動作已中止，現在靜止顯示選定的狀態，不代表已看完。可以比較前／後；按重看才會重新播放。";
        case MTPPlaceValuePlaybackStateInvalidScene: return @"這次先不播放，改看完整的積木。可以比較動作前／後。";
        default: return @"";
    }
}
- (MTPOverviewLayout *)overviewForWidth:(CGFloat)width {
    CGFloat actualWidth = MAX(184, width), available = actualWidth - 24, y = 12;
    NSMutableDictionary *frames = [NSMutableDictionary dictionary], *texts = [NSMutableDictionary dictionary]; NSMutableArray *placements = [NSMutableArray array];
    void (^label)(NSString *, NSString *) = ^(NSString *key, NSString *text) { texts[key] = text; };
    NSString *heading = self.action ? [NSString stringWithFormat:@"%@ · %@", self.action.title, self.endpoint == MTPPlaceValueEndpointBefore ? @"動作前" : @"動作後"] : @"目前全部積木";
    label(@"heading", heading);
    if (self.statusExplanation.length) label(@"status", self.statusExplanation);
    if (self.action) label(@"instruction", self.endpoint == MTPPlaceValueEndpointBefore ? self.action.instruction : self.action.resultExplanation);
    for (NSString *key in @[@"heading", @"status", @"instruction"]) if (texts[key]) {
        CGFloat h = MTPPlaceValueTextHeight(texts[key], self.materialFont, available); frames[key] = [NSValue valueWithCGRect:CGRectMake(12, y, available, h)]; y += h + 12;
    }
    NSDictionary *owners = MTPPlaceValueOwners(self.snapshot); NSMutableSet *carry = [NSMutableSet set];
    for (NSArray *column in self.snapshot.carryUnits) for (MultiplicativeTeachingUnit *unit in column) [carry addObject:@(unit.identifier)];
    for (NSString *owner in MTPPlaceValueOwnerOrder(self.snapshot)) {
        NSArray<MultiplicativeTeachingUnit *> *units = owners[owner]; NSInteger counts[3] = {0,0,0}; for (MultiplicativeTeachingUnit *unit in units) counts[unit.column]++;
        NSString *key = [@"owner." stringByAppendingString:owner]; NSString *text = [NSString stringWithFormat:@"%@：%ld 個百、%ld 個十、%ld 個一", MTPPlaceValueOwnerName(owner, self.snapshot), (long)counts[0], (long)counts[1], (long)counts[2]];
        if (units.count == 0) text = [text stringByAppendingString:@"。目前沒有積木。"];
        CGFloat h = MTPPlaceValueTextHeight(text, self.materialFont, available); texts[key] = text; frames[key] = [NSValue valueWithCGRect:CGRectMake(12, y, available, h)]; y += h + 12;
        for (NSInteger column = 0; column < 3; column++) {
            NSMutableArray<MultiplicativeTeachingUnit *> *columnUnits = [NSMutableArray array]; NSUInteger carryCount = 0;
            for (MultiplicativeTeachingUnit *unit in units) if (unit.column == column) { [columnUnits addObject:unit]; if ([carry containsObject:@(unit.identifier)]) carryCount++; }
            if (!columnUnits.count) continue;
            key = [NSString stringWithFormat:@"place.%@.%ld", owner, (long)column];
            text = [NSString stringWithFormat:@"%@：%lu 個%@%@", MTPPlaceValuePlaceName(column), (unsigned long)columnUnits.count, MTPPlaceValuePlaceName(column), carryCount ? [NSString stringWithFormat:@"，其中 %lu 個是先前換來的，已包含在內", (unsigned long)carryCount] : @""];
            h = MTPPlaceValueTextHeight(text, self.materialFont, available); texts[key] = text; frames[key] = [NSValue valueWithCGRect:CGRectMake(12, y, available, h)]; y += h + 12;
            CGSize body = MTPPlaceValueBodySize(column); NSUInteger columns = MAX(1, (NSUInteger)floor((available + 10) / (body.width + 10)));
            for (NSUInteger i = 0; i < columnUnits.count; i++) {
                MultiplicativeTeachingUnit *unit = columnUnits[i]; CGRect frame = CGRectMake(12 + (i % columns) * (body.width + 10), y + (i / columns) * (body.height + 10), body.width, body.height);
                [placements addObject:[[MTPPlaceValueUnitPlacement alloc] initWithUnit:unit owner:owner frame:frame inTransit:NO carryAnnotation:[carry containsObject:@(unit.identifier)]]];
            }
            NSUInteger rows = (columnUnits.count + columns - 1) / columns; y += rows * body.height + (rows - 1) * 10 + 18;
        }
        y += 12;
    }
    if (self.snapshot.visibleRemainder) {
        NSString *text = [NSString stringWithFormat:@"共同的餘數是 %@，不是每份各有一份餘數。", self.snapshot.visibleRemainder];
        texts[@"remainder"] = text; CGFloat h = MTPPlaceValueTextHeight(text, self.materialFont, available); frames[@"remainder"] = [NSValue valueWithCGRect:CGRectMake(12, y, available, h)]; y += h + 12;
    }
    MTPOverviewLayout *layout = [[MTPOverviewLayout alloc] init]; layout.size = CGSizeMake(actualWidth, ceil(y + 12)); layout.placements = placements; layout.labelFrames = frames; layout.labelTexts = texts; return layout;
}
- (UILabel *)makeLabel:(NSString *)identifier frame:(CGRect)frame text:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:frame]; label.font = self.materialFont; label.textColor = ChildUI.brownText; label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping; label.adjustsFontSizeToFitWidth = NO; label.text = text;
    label.accessibilityIdentifier = [@"multiplicative.place." stringByAppendingString:identifier]; label.accessibilityLanguage = @"zh-TW";
    [self addSubview:label]; self.labels[identifier] = label; return label;
}
- (void)applyPlacements:(NSArray<MTPPlaceValueUnitPlacement *> *)placements labelTexts:(NSDictionary<NSString *, NSString *> *)texts {
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    @try {
        NSMutableSet *live = [NSMutableSet set]; for (MTPPlaceValueUnitPlacement *placement in placements) [live addObject:@(placement.unit.identifier)];
        // Retire first, then add; both are committed in the SAME CA transaction.
        for (NSNumber *identifier in self.unitViews.allKeys.copy) if (![live containsObject:identifier]) { MTPMaterialView *view = self.unitViews[identifier]; [self.unitViews removeObjectForKey:identifier]; [view removeFromSuperview]; }
        for (MTPPlaceValueUnitPlacement *placement in placements) {
            NSNumber *identifier = @(placement.unit.identifier); MTPMaterialView *view = self.unitViews[identifier];
            if (!view) { view = [[MTPMaterialView alloc] initWithFrame:placement.frame]; view.backgroundColor = UIColor.clearColor; view.opaque = NO; view.isAccessibilityElement = YES; view.accessibilityTraits = UIAccessibilityTraitStaticText; [self addSubview:view]; self.unitViews[identifier] = view; }
            view.unit = placement.unit; view.owner = placement.owner; view.carryAnnotation = placement.carryAnnotation; view.frame = placement.frame;
            view.accessibilityIdentifier = [NSString stringWithFormat:@"multiplicative.unit.%@.%lu", self.sessionID, (unsigned long)placement.unit.identifier];
            view.accessibilityLabel = [NSString stringWithFormat:@"%@的 1 個%@%@%@", MTPPlaceValueOwnerName(placement.owner, self.snapshot), MTPPlaceValuePlaceName(placement.unit.column), placement.carryAnnotation ? @"，先前換來的，已包含在這一區" : @"", placement.inTransit ? @"，正在移動，抵達前仍屬於這一區" : @""];
            view.accessibilityLanguage = @"zh-TW"; [view setNeedsDisplay];
        }
        for (NSString *key in texts) self.labels[key].text = texts[key];
    } @finally { [CATransaction commit]; }
}
- (void)installScenePaint {
    [self clearPaint];
    if (!CGRectIsNull(self.scene.cradleRect)) {
        self.cradle = [[UIView alloc] initWithFrame:self.scene.cradleRect]; self.cradle.backgroundColor = UIColor.clearColor;
        self.cradle.layer.borderWidth = 1; self.cradle.layer.borderColor = [ChildUI.brownText colorWithAlphaComponent:.5].CGColor;
        self.cradle.isAccessibilityElement = NO; self.cradle.accessibilityIdentifier = @"multiplicative.place.exchange.cradle"; [self addSubview:self.cradle];
    }
    MTPPlaceValueProjection *projection = [self.scene projectionAfter:self.endpoint == MTPPlaceValueEndpointAfter];
    for (NSString *key in self.scene.labelFrames) [self makeLabel:key frame:self.scene.labelFrames[key].CGRectValue text:projection.labelTexts[key]];
    [self applyProjection:projection];
}
- (void)applyProjection:(MTPPlaceValueProjection *)projection {
    self.projection = projection; self.snapshot = projection.canonicalSnapshot;
    [self applyPlacements:projection.placements labelTexts:projection.labelTexts];
    self.spokenDescription = [NSString stringWithFormat:@"%@ %@ %@", projection.labelTexts[@"title"], projection.labelTexts[@"phase"], projection.labelTexts[@"context"]];
    self.accessibilityValue = self.spokenDescription;
}
- (void)installOverviewPaint {
    [self clearPaint]; self.overviewLayout = [self overviewForWidth:self.bounds.size.width];
    for (NSString *key in self.overviewLayout.labelFrames) [self makeLabel:key frame:self.overviewLayout.labelFrames[key].CGRectValue text:self.overviewLayout.labelTexts[key]];
    [self applyPlacements:self.overviewLayout.placements labelTexts:self.overviewLayout.labelTexts];
    [self installCanonicalSpeech];
}
- (void)rebuildIfNeeded {
    if (self.updatingBindings || !self.needsSceneLayout || !self.snapshot || self.bounds.size.width <= 0) return;
    self.updatingBindings = YES; self.needsSceneLayout = NO; self.renderedSize = self.bounds.size;
    if (self.action) self.scene = [MultiplicativePlaceValueScene sceneWithAction:self.action width:self.bounds.size.width font:self.materialFont];
    else self.scene = nil; // Neutral rendering never even prepares an action scene.
    if (self.displayingFullSnapshot || self.scene.stationary) [self installOverviewPaint]; else [self installScenePaint];
    self.updatingBindings = NO; [self invalidateIntrinsicContentSize]; [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews]; if (self.updatingBindings) return;
    if (!CGSizeEqualToSize(self.renderedSize, self.bounds.size)) {
        BOOL running = self.clock != nil; [self invalidateClock]; self.layoutRevision++;
        if (running) { self.endpoint = MTPPlaceValueEndpointAfter; self.snapshot = self.action.after; self.displayingFullSnapshot = YES; self.playbackState = MTPPlaceValuePlaybackStateInterrupted; self.interruptionReason = MTPPlaceValueInterruptionReasonLayoutChanged; self.statusExplanation = [self statusForState:self.playbackState]; }
        if (running) [self installCanonicalSpeech]; self.needsSceneLayout = YES; [self rebuildIfNeeded]; if (running) [self notifyState];
    } else [self rebuildIfNeeded];
}
- (CGSize)requiredActionSizeThatFits:(CGSize)size {
    if (!self.action) return CGSizeZero;
    MultiplicativePlaceValueScene *scene = [MultiplicativePlaceValueScene sceneWithAction:self.action width:MAX(1, size.width) font:self.materialFont];
    return scene.stationary ? [self overviewForWidth:size.width].size : scene.requiredRect.size;
}
- (CGSize)sizeThatFits:(CGSize)size {
    if (!self.snapshot) return CGSizeMake(size.width, 0);
    if (self.displayingFullSnapshot || !self.action || (!self.action.inputUnits.count && !self.action.outputUnits.count)) return [self overviewForWidth:size.width].size;
    return [self requiredActionSizeThatFits:size];
}
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, [self sizeThatFits:self.bounds.size].height); }
- (CGRect)requiredActionRect { return self.scene && !self.scene.stationary ? self.scene.requiredRect : CGRectNull; }
// Agreement tolerance is 0.0001 point for UIKit center/bounds decomposition
// and CA float presentation storage. Clip containment is never expanded.
- (BOOL)point:(CGPoint)a agreesWith:(CGPoint)b {
    return isfinite(a.x) && isfinite(a.y) && isfinite(b.x) && isfinite(b.y) && fabs(a.x - b.x) <= .0001 && fabs(a.y - b.y) <= .0001;
}
- (BOOL)rect:(CGRect)a agreesWith:(CGRect)b {
    return [self point:a.origin agreesWith:b.origin] && [self point:CGPointMake(a.size.width, a.size.height) agreesWith:CGPointMake(b.size.width, b.size.height)];
}
- (BOOL)layerIsStable:(CALayer *)layer requirePresentation:(BOOL)requirePresentation {
    if ([layer isKindOfClass:CATransformLayer.class] || layer.animationKeys.count || !CATransform3DIsIdentity(layer.transform) || !CATransform3DIsIdentity(layer.sublayerTransform) || layer.mask) return NO;
    CALayer *presented = layer.presentationLayer;
    if (!presented) return !requirePresentation;
    return !presented.animationKeys.count && !presented.mask && CATransform3DIsIdentity(presented.transform) && CATransform3DIsIdentity(presented.sublayerTransform)
        && [self rect:presented.bounds agreesWith:layer.bounds] && [self point:presented.position agreesWith:layer.position]
        && [self point:presented.anchorPoint agreesWith:layer.anchorPoint] && fabs(presented.anchorPointZ - layer.anchorPointZ) <= .0001
        && fabs(presented.zPosition - layer.zPosition) <= .0001 && fabs(presented.opacity - layer.opacity) <= .0001
        && presented.hidden == layer.hidden && presented.masksToBounds == layer.masksToBounds && fabs(presented.cornerRadius - layer.cornerRadius) <= .0001;
}
- (BOOL)paintTreeIsStable:(CALayer *)layer requirePresentation:(BOOL)requirePresentation {
    CALayer *presented = layer.presentationLayer;
    if (!layer.animationKeys.count && (layer.hidden || layer.opacity <= 0) && (!presented || presented.hidden || presented.opacity <= 0)) return YES;
    if (![self layerIsStable:layer requirePresentation:requirePresentation]) return NO;
    for (CALayer *child in layer.sublayers) if (![self paintTreeIsStable:child requirePresentation:requirePresentation]) return NO;
    for (CALayer *paint in presented.sublayers) {
        CALayer *model = paint.modelLayer;
        if ((!model || ![layer.sublayers containsObject:model]) && !paint.hidden && paint.opacity > 0) return NO;
    }
    return YES;
}
- (BOOL)isIdentityPresentation:(UIView *)view requirePresentation:(BOOL)requirePresentation {
    return CGAffineTransformIsIdentity(view.transform) && !view.layer.hidden && view.layer.opacity >= 1 && [self layerIsStable:view.layer requirePresentation:requirePresentation];
}
- (BOOL)layerIsSettledInvisible:(CALayer *)layer {
    CALayer *presented = layer.presentationLayer;
    return !layer.animationKeys.count && (layer.hidden || layer.opacity <= 0) && (!presented || presented.hidden || presented.opacity <= 0);
}
- (BOOL)layerMayCoverAction:(CALayer *)layer inCoordinateView:(UIView *)coordinateView {
    if ([self layerIsSettledInvisible:layer]) return NO;
    // No model-only certificate for an unknown cover, including a standalone
    // layer with no UIView. Its descendants may paint outside its own bounds.
    if (![self paintTreeIsStable:layer requirePresentation:YES] || layer.shadowOpacity > 0 || layer.presentationLayer.shadowOpacity > 0) return YES;
    CGRect rect = [coordinateView.layer convertRect:layer.bounds fromLayer:layer];
    if (CGRectIntersectsRect([self convertRect:rect fromView:coordinateView], self.requiredActionRect)) return YES;
    if (!layer.masksToBounds) for (CALayer *child in layer.sublayers) if ([self layerMayCoverAction:child inCoordinateView:coordinateView]) return YES;
    return NO;
}
- (BOOL)occluderMayCoverAction:(UIView *)view {
    return [self layerMayCoverAction:view.layer inCoordinateView:view];
}
- (NSUInteger)presentationIndexOfLayer:(CALayer *)layer inParent:(CALayer *)parent {
    NSArray<CALayer *> *children = parent.presentationLayer.sublayers;
    for (NSUInteger i = 0; i < children.count; i++) if (children[i].modelLayer == layer) return i;
    return NSNotFound;
}
- (BOOL)layer:(CALayer *)cover couldPaintAbove:(CALayer *)target inParent:(CALayer *)parent {
    if ([self layerIsSettledInvisible:cover]) return NO;
    if (![self layerIsStable:cover requirePresentation:YES]) return YES;
    NSArray *children = parent.sublayers;
    NSUInteger coverIndex = [children indexOfObjectIdenticalTo:cover], targetIndex = [children indexOfObjectIdenticalTo:target];
    if (coverIndex == NSNotFound || targetIndex == NSNotFound || !isfinite(cover.zPosition) || !isfinite(target.zPosition)) return YES;
    if (cover.zPosition > target.zPosition || (cover.zPosition == target.zPosition && coverIndex > targetIndex)) return YES;
    CALayer *coverPaint = cover.presentationLayer, *targetPaint = target.presentationLayer;
    // Fresh owned roots can be absent only in preparation, never on a tick.
    if (!targetPaint && !self.clock && parent == self.layer && [[self ownedRootLayers] containsObject:target]) return NO;
    NSUInteger coverPaintIndex = [self presentationIndexOfLayer:cover inParent:parent], targetPaintIndex = [self presentationIndexOfLayer:target inParent:parent];
    if (!coverPaint || !targetPaint || coverPaintIndex == NSNotFound || targetPaintIndex == NSNotFound) return YES;
    return coverPaint.zPosition > targetPaint.zPosition || (coverPaint.zPosition == targetPaint.zPosition && coverPaintIndex > targetPaintIndex);
}
- (BOOL)layerChildrenAreUnobscured:(CALayer *)parent targets:(NSSet<CALayer *> *)targets {
    for (CALayer *cover in parent.sublayers) {
        if ([targets containsObject:cover]) continue;
        for (CALayer *target in targets) if ([self layer:cover couldPaintAbove:target inParent:parent]
            && [self layerMayCoverAction:cover inCoordinateView:self.window]) return NO;
    }
    // A removed/reordered model layer can still be painting in an uncommitted
    // transaction. Do not silently discard that presentation-only sibling.
    for (CALayer *paint in parent.presentationLayer.sublayers) {
        CALayer *model = paint.modelLayer;
        if (model && [parent.sublayers containsObject:model]) continue;
        if (model && !self.clock && parent == self.layer && [self.retiredOwnedRootLayers containsObject:model]) continue;
        // Judge this actual paint, not a different lookup through its detached
        // model: hiding/removing the model need not erase the old painted child.
        if (!paint.hidden && paint.opacity > 0) return NO;
    }
    return YES;
}
- (BOOL)ownedSurfaceHasNoAdditionalPaint:(CALayer *)layer {
    // The renderer creates no child paint for a material or text surface. A
    // stable opaque child is still an occluder, not evidence of legible cells.
    for (CALayer *child in layer.sublayers) if (![self layerIsSettledInvisible:child]) return NO;
    for (CALayer *paint in layer.presentationLayer.sublayers) if (!paint.hidden && paint.opacity > 0) return NO;
    return YES;
}
- (BOOL)cradleHasOnlyKnownGuidePaint {
    // This exact renderer-owned guide has a clear fill, one inset border and no
    // image/descendants. Its overlap with exchanging material is intentional.
    CALayer *layer = self.cradle.layer, *presented = layer.presentationLayer;
    CGColorRef border = [ChildUI.brownText colorWithAlphaComponent:.5].CGColor;
    for (CALayer *paint in presented ? @[layer, presented] : @[layer]) {
        if (paint.contents || paint.sublayers.count || (paint.backgroundColor && CGColorGetAlpha(paint.backgroundColor) > 0)
            || paint.borderWidth != 1 || !paint.borderColor || !CGColorEqualToColor(paint.borderColor, border)) return NO;
    }
    return YES;
}
- (BOOL)installedPaintIsLawful {
    if (!self.projection || self.unitViews.count != self.projection.placements.count || self.labels.count != self.scene.labelFrames.count) return NO;
    // Fresh owned paint may not have a presentation copy during synchronous
    // preparation. Once a clock exists, missing actual paint refuses advancement.
    BOOL requirePresentation = self.clock != nil;
    if (CGRectIsNull(self.scene.cradleRect)) { if (self.cradle) return NO; }
    else {
        if (!self.cradle || self.cradle.superview != self || self.cradle.layer.superlayer != self.layer || self.cradle.hidden || self.cradle.alpha < 1 || ![self isIdentityPresentation:self.cradle requirePresentation:requirePresentation]
            || ![self paintTreeIsStable:self.cradle.layer requirePresentation:requirePresentation] || self.cradle.layer.shadowOpacity > 0
            || ![self rect:self.cradle.frame agreesWith:self.scene.cradleRect] || ![self cradleHasOnlyKnownGuidePaint]) return NO;
        CALayer *presented = self.cradle.layer.presentationLayer;
        if (!CGRectContainsRect(self.requiredActionRect, presented ? presented.frame : self.cradle.frame)) return NO;
    }
    NSMutableArray<NSValue *> *paint = [NSMutableArray array];
    for (MTPPlaceValueUnitPlacement *placement in self.projection.placements) {
        MTPMaterialView *view = self.unitViews[@(placement.unit.identifier)];
        if (!view || view.superview != self || view.layer.superlayer != self.layer || view.unit != placement.unit || ![view.owner isEqualToString:placement.owner] || view.carryAnnotation != placement.carryAnnotation || view.hidden || view.alpha < 1
            || ![self isIdentityPresentation:view requirePresentation:requirePresentation] || ![self paintTreeIsStable:view.layer requirePresentation:requirePresentation] || ![self rect:view.frame agreesWith:placement.frame] || ![self ownedSurfaceHasNoAdditionalPaint:view.layer]
            || !CGSizeEqualToSize(view.bounds.size, MTPPlaceValueBodySize(placement.unit.column)) || view.layer.shadowOpacity > 0) return NO;
        CALayer *presented = view.layer.presentationLayer;
        CGRect painted = presented ? presented.frame : view.frame;
        if (!CGRectContainsRect(self.requiredActionRect, painted)) return NO;
        [paint addObject:[NSValue valueWithCGRect:painted]];
    }
    for (NSString *key in self.scene.labelFrames) {
        UILabel *label = self.labels[key];
        if (!label || label.superview != self || label.layer.superlayer != self.layer || label.hidden || label.alpha < 1 || ![self isIdentityPresentation:label requirePresentation:requirePresentation] || ![self paintTreeIsStable:label.layer requirePresentation:requirePresentation] || label.layer.shadowOpacity > 0 || label.shadowColor
            || ![self rect:label.frame agreesWith:self.scene.labelFrames[key].CGRectValue] || ![self ownedSurfaceHasNoAdditionalPaint:label.layer]
            || ![label.text isEqualToString:self.projection.labelTexts[key]] || label.adjustsFontSizeToFitWidth
            || fabs(label.font.pointSize - self.scene.font.pointSize) > .001
            || MTPPlaceValueTextHeight(label.text, label.font, label.bounds.size.width) > label.bounds.size.height + .001) return NO;
        CALayer *presented = label.layer.presentationLayer; CGRect paintedLabel = presented ? presented.frame : label.frame;
        if (!CGRectContainsRect(self.requiredActionRect, paintedLabel) || (self.cradle && CGRectIntersectsRect(paintedLabel, self.cradle.frame))) return NO;
        for (NSValue *unit in paint) if (CGRectIntersectsRect(unit.CGRectValue, paintedLabel)) return NO;
    }
    for (NSUInteger a = 0; a < paint.count; a++) for (NSUInteger b = a + 1; b < paint.count; b++) {
        CGRect overlap = CGRectIntersection(paint[a].CGRectValue, paint[b].CGRectValue);
        if (!CGRectIsNull(overlap) && overlap.size.width > .001 && overlap.size.height > .001) return NO;
    }
    return [self layerChildrenAreUnobscured:self.layer targets:[self ownedRootLayers]];
}
- (BOOL)actualVisibilityContainsRequiredRect {
    if (!isfinite(self.requestedVisibleRect.origin.x) || !isfinite(self.requestedVisibleRect.origin.y) || !isfinite(self.requestedVisibleRect.size.width) || !isfinite(self.requestedVisibleRect.size.height)) return NO;
    if (!self.window || !self.window.windowScene || ![self applicationActive] || self.window.windowScene.activationState != UISceneActivationStateForegroundActive
        || CGRectIsNull(self.requiredActionRect) || self.scene.width != self.bounds.size.width || !self.scene.geometryValid || ![self installedPaintIsLawful] || self.window.hidden || self.window.alpha <= .01) return NO;
    // View-based coordinates certify only the matching backing-layer chain.
    // Refuse raw ancestor interposition rather than assuming its clip/coordinates
    // match the UIView hierarchy. Never force a CA commit to obtain actual paint.
    BOOL reachedWindow = NO; NSMutableArray<CALayer *> *chain = [NSMutableArray array];
    for (UIView *view = self; view; view = view.superview) {
        CALayer *layer = view.layer, *paint = layer.presentationLayer;
        if (![self layerIsStable:layer requirePresentation:YES] || layer.hidden || !(layer.opacity >= 1)
            || !paint || paint.hidden || !(paint.opacity >= 1)) return NO;
        [chain addObject:layer];
        if (view == self.window) { reachedWindow = YES; break; }
        if (!view.superview || layer.superlayer != view.superview.layer || paint.superlayer.modelLayer != view.superview.layer) return NO;
    }
    if (!reachedWindow) return NO;
    for (CALayer *layer in chain) if (layer != self.window.layer
        && ![self layerChildrenAreUnobscured:layer.superlayer targets:[NSSet setWithObject:layer]]) return NO;
    // UIWindowScene.windows documents association, not same-level z ordering.
    // Only a strictly lower window level proves that another window is behind us.
    for (UIWindow *window in self.window.windowScene.windows) if (window != self.window && window.windowLevel >= self.window.windowLevel
        && [self occluderMayCoverAction:window]) return NO;
    CGRect visible = CGRectIntersection(self.bounds, self.requestedVisibleRect);
    visible = CGRectIntersection(visible, [self convertRect:self.window.bounds fromView:self.window]);
    visible = CGRectIntersection(visible, [self convertRect:self.window.safeAreaLayoutGuide.layoutFrame fromView:self.window]);
    for (CALayer *layer in chain) if (layer.masksToBounds) {
        CGRect clip = layer.cornerRadius > 0 ? CGRectInset(layer.bounds,layer.cornerRadius,layer.cornerRadius) : layer.bounds;
        visible = CGRectIntersection(visible,[self.layer convertRect:clip fromLayer:layer]);
    }
    for (UIView *view = self; view; view = view.superview) {
        if (view.hidden || view.alpha < 1 || ![self isIdentityPresentation:view requirePresentation:YES]) return NO;
        if (view.clipsToBounds || [view isKindOfClass:UIScrollView.class]) {
            CGRect clip = view.bounds;
            // Rounded clips are not rectangular; certify their inscribed rectangle.
            if (view.layer.cornerRadius > 0) clip = CGRectInset(clip, view.layer.cornerRadius, view.layer.cornerRadius);
            visible = CGRectIntersection(visible, [self convertRect:clip fromView:view]);
        }
        if ([view isKindOfClass:UIScrollView.class]) { UIScrollView *scroll = (UIScrollView *)view; if (scroll.dragging || scroll.tracking || scroll.decelerating) return NO; }
    }
    if (!CGRectContainsRect(visible, self.requiredActionRect)) return NO;
    // A presented controller in this window is a known occluder, even when its
    // containment hierarchy is not a sibling of this board's scroll viewport.
    UIViewController *root = self.window.rootViewController;
    for (UIViewController *presented = root.presentedViewController; presented; presented = presented.presentedViewController) {
        if (presented.isViewLoaded && presented.view.window == self.window && ![self isDescendantOfView:presented.view]
            && [self occluderMayCoverAction:presented.view]) return NO;
    }
    for (NSUInteger i = 0; i < self.transaction.scrollViews.count; i++) if (!CGPointEqualToPoint(self.transaction.scrollViews[i].contentOffset, self.transaction.scrollOffsets[i].CGPointValue)) return NO;
    return YES;
}
- (BOOL)transactionIsCurrent:(MTPPlaybackTransaction *)transaction clock:(CADisplayLink *)clock {
    return transaction && transaction == self.transaction && clock == self.clock && transaction.action == self.action && transaction.scene == self.scene
        && transaction.before == self.action.before && transaction.after == self.action.after && transaction.generation == self.playbackGeneration
        && transaction.revision == self.layoutRevision && [transaction.sessionID isEqualToString:self.sessionID] && [transaction.selectionID isEqualToString:self.selectionID];
}
- (void)settleRecovery:(MTPPlaceValuePlaybackState)state reason:(MTPPlaceValueInterruptionReason)reason explanation:(NSString *)explanation {
    [self invalidateClock]; self.endpoint = MTPPlaceValueEndpointAfter; self.snapshot = self.action.after; self.playbackState = state; self.interruptionReason = reason;
    self.statusExplanation = explanation; self.displayingFullSnapshot = YES; [self installCanonicalSpeech]; self.needsSceneLayout = YES; [self rebuildIfNeeded]; [self notifyState];
}
- (void)settleRecovery:(MTPPlaceValuePlaybackState)state reason:(MTPPlaceValueInterruptionReason)reason {
    [self settleRecovery:state reason:reason explanation:[self statusForState:state]];
}
- (MTPPlaceValuePlaybackState)playInVisibleRect:(CGRect)visibleRect {
    if (!self.action || self.updatingBindings) return self.playbackState;
    [self invalidateClock]; self.updatingBindings = YES;
    self.endpoint = MTPPlaceValueEndpointBefore; self.snapshot = self.action.before; self.displayingFullSnapshot = NO; self.interruptionReason = MTPPlaceValueInterruptionReasonNone;
    self.statusExplanation = @""; self.layoutRevision++; NSUInteger preparedRevision = self.layoutRevision; CGSize preparedSize = self.bounds.size;
    self.needsSceneLayout = NO; self.scene = [MultiplicativePlaceValueScene sceneWithAction:self.action width:preparedSize.width font:self.materialFont];
    self.renderedSize = preparedSize; self.requestedVisibleRect = visibleRect;
    [self installScenePaint]; self.updatingBindings = NO;
    if (self.layoutRevision != preparedRevision || !CGSizeEqualToSize(preparedSize, self.bounds.size)) {
        [self settleRecovery:MTPPlaceValuePlaybackStateInterrupted reason:MTPPlaceValueInterruptionReasonLayoutChanged]; return self.playbackState;
    }
    if (self.scene.stationary) { [self settleRecovery:MTPPlaceValuePlaybackStateStationary reason:MTPPlaceValueInterruptionReasonNone]; return self.playbackState; }
    if (![self motionAllowed]) { [self settleRecovery:MTPPlaceValuePlaybackStateReducedMotion reason:MTPPlaceValueInterruptionReasonMotionChanged]; return self.playbackState; }
    if (!self.scene.geometryValid) { [self settleRecovery:MTPPlaceValuePlaybackStateInvalidScene reason:MTPPlaceValueInterruptionReasonNone]; return self.playbackState; }
    if (!self.window || !self.window.windowScene) { [self settleRecovery:MTPPlaceValuePlaybackStateInterrupted reason:MTPPlaceValueInterruptionReasonDetached]; return self.playbackState; }
    if (![self applicationActive] || self.window.windowScene.activationState != UISceneActivationStateForegroundActive) { [self settleRecovery:MTPPlaceValuePlaybackStateInterrupted reason:MTPPlaceValueInterruptionReasonBackground]; return self.playbackState; }
    if (self.hidden || self.alpha < 1) { [self settleRecovery:MTPPlaceValuePlaybackStateInterrupted reason:MTPPlaceValueInterruptionReasonVisibility]; return self.playbackState; }
    if (![self actualVisibilityContainsRequiredRect]) { [self settleRecovery:MTPPlaceValuePlaybackStateInsufficientSpace reason:MTPPlaceValueInterruptionReasonVisibility]; return self.playbackState; }
    MTPPlaybackTransaction *transaction = [[MTPPlaybackTransaction alloc] init]; transaction.sessionID = self.sessionID; transaction.selectionID = self.selectionID;
    transaction.generation = self.playbackGeneration; transaction.revision = self.layoutRevision; transaction.action = self.action; transaction.scene = self.scene; transaction.before = self.action.before; transaction.after = self.action.after;
    NSMutableArray *scrolls = [NSMutableArray array], *offsets = [NSMutableArray array];
    for (UIView *view = self.superview; view; view = view.superview) if ([view isKindOfClass:UIScrollView.class]) { [scrolls addObject:view]; [offsets addObject:[NSValue valueWithCGPoint:((UIScrollView *)view).contentOffset]]; }
    transaction.scrollViews = scrolls; transaction.scrollOffsets = offsets; self.transaction = transaction;
    MTPClockTarget *target = [[MTPClockTarget alloc] init]; target.board = self; target.transaction = transaction;
    self.clock = [CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)]; self.playbackState = MTPPlaceValuePlaybackStateRunning;
    // The first tick sets the origin after the exact before frame has been placed.
    // No settle-after helper or prior view positions participate in this start.
    [self.clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes]; [self notifyState]; return self.playbackState;
}
- (void)tick:(CADisplayLink *)link transaction:(MTPPlaybackTransaction *)transaction {
    [self advanceClockAtTimestamp:link.timestamp transaction:transaction clock:link];
}
- (void)advanceClockAtTimestamp:(CFTimeInterval)timestamp transaction:(MTPPlaybackTransaction *)transaction clock:(CADisplayLink *)link {
    if (![self transactionIsCurrent:transaction clock:link]) return;
    if (![self motionAllowed]) { [self settleRecovery:MTPPlaceValuePlaybackStateReducedMotion reason:MTPPlaceValueInterruptionReasonMotionChanged]; return; }
    if (![self actualVisibilityContainsRequiredRect]) { [self cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonVisibility]; return; }
    // Never silently catch up across unobserved births, a docking hold, or a
    // recipient's settled dwell. Half the shortest dwell (0.25s) is the maximum
    // admitted gap. A foreground hitch is interrupted, not natural completion.
    BOOL invalidTime = !isfinite(timestamp) || timestamp <= 0 || (self.lastTimestamp > 0 && timestamp < self.lastTimestamp);
    BOOL missedFrames = self.lastTimestamp > 0 && timestamp - self.lastTimestamp > .125;
    if (invalidTime || missedFrames) {
        NSString *explanation = invalidTime ? @"這次無法確認播放進度，先停止，不代表已看完。現在可看靜止的積木，比較前／後；按重看才會再試一次。"
            : @"剛才播放停頓，沒有完整看見這段變化。現在先看靜止的積木，可以比較前／後；按重看才會再試一次。";
        [self settleRecovery:MTPPlaceValuePlaybackStateInterrupted reason:MTPPlaceValueInterruptionReasonVisibility explanation:explanation]; return;
    }
    if (timestamp == self.lastTimestamp) return;
    if (self.startTimestamp == 0) self.startTimestamp = timestamp;
    self.lastTimestamp = timestamp;
    [self renderElapsed:MAX(0, timestamp - self.startTimestamp) transaction:transaction clock:link];
}
- (void)renderElapsed:(NSTimeInterval)elapsed transaction:(MTPPlaybackTransaction *)transaction clock:(CADisplayLink *)clock {
    if (![self transactionIsCurrent:transaction clock:clock]) return;
    MTPPlaceValueProjection *projection = [transaction.scene projectionAtElapsed:elapsed]; [self applyProjection:projection];
    if (projection.complete) {
        [self invalidateClock]; self.endpoint = MTPPlaceValueEndpointAfter; self.snapshot = transaction.after;
        self.playbackState = MTPPlaceValuePlaybackStateCompleted; self.interruptionReason = MTPPlaceValueInterruptionReasonNone; self.statusExplanation = [self statusForState:self.playbackState];
        self.spokenDescription = [NSString stringWithFormat:@"%@ %@", self.statusExplanation, self.action.spokenAfter]; self.accessibilityValue = self.spokenDescription; [self notifyState];
    }
}
- (void)showEndpoint:(MTPPlaceValueEndpoint)endpoint {
    if (!self.action) return;
    [self invalidateClock]; self.endpoint = endpoint; self.snapshot = endpoint == MTPPlaceValueEndpointBefore ? self.action.before : self.action.after;
    if (self.playbackState == MTPPlaceValuePlaybackStateRunning || self.playbackState == MTPPlaceValuePlaybackStateCompleted) { self.playbackState = MTPPlaceValuePlaybackStateStatic; self.statusExplanation = @""; }
    [self installCanonicalSpeech]; self.needsSceneLayout = YES; [self rebuildIfNeeded]; [self notifyState];
}
- (void)showBeforeState { [self showEndpoint:MTPPlaceValueEndpointBefore]; }
- (void)showAfterState { [self showEndpoint:MTPPlaceValueEndpointAfter]; }
- (void)cancelPlaybackWithReason:(MTPPlaceValueInterruptionReason)reason {
    if (self.updatingBindings) return;
    BOOL running = self.clock != nil; [self invalidateClock];
    if (running) { self.endpoint = MTPPlaceValueEndpointAfter; self.snapshot = self.action.after; self.displayingFullSnapshot = YES; }
    if (!self.action) return;
    self.interruptionReason = reason; self.playbackState = MTPPlaceValuePlaybackStateInterrupted; self.statusExplanation = [self statusForState:self.playbackState];
    [self installCanonicalSpeech]; self.needsSceneLayout = YES; [self rebuildIfNeeded]; [self notifyState];
}
- (void)recheckVisibility { if (self.clock && ![self actualVisibilityContainsRequiredRect]) [self cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonVisibility]; }
- (void)backgrounded:(NSNotification *)notification { if (self.clock) [self cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonBackground]; }
- (void)motionChanged:(NSNotification *)notification {
    if (self.clock) { [self settleRecovery:![self motionAllowed] ? MTPPlaceValuePlaybackStateReducedMotion : MTPPlaceValuePlaybackStateInterrupted reason:MTPPlaceValueInterruptionReasonMotionChanged]; }
    // Passive recovery never creates a clock, changes selection or resumes motion.
}
- (void)textChanged:(NSNotification *)notification {
    if (self.updatingBindings) { self.needsSceneLayout = YES; self.layoutRevision++; return; }
    if (self.clock) [self cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonLayoutChanged];
    self.layoutRevision++; self.needsSceneLayout = YES; [self rebuildIfNeeded];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection && ![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) [self textChanged:nil];
}
- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (self.window && self.window != newWindow && self.clock) [self cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonDetached]; [super willMoveToWindow:newWindow];
}
- (void)setHidden:(BOOL)hidden { if (hidden && self.clock) [self cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonVisibility]; [super setHidden:hidden]; }
- (void)setAlpha:(CGFloat)alpha { if (alpha <= .01 && self.clock) [self cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonVisibility]; [super setAlpha:alpha]; }
@end
