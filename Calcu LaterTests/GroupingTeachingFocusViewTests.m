#import <XCTest/XCTest.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "GroupingTeachingFocusView.h"
#import "GroupingTeachingBoardView.h"
#import "WordProblem.h"

@interface GroupingTeachingFocusView (Testing)
- (BOOL)motionAllowed;
- (BOOL)applicationActive;
- (BOOL)actuallyVisible;
- (void)renderElapsed:(NSTimeInterval)elapsed;
- (void)tick:(CADisplayLink *)link generation:(NSUInteger)generation;
@end
// Component dependencies, not an app launch preference or a substitute for the
// dedicated native Settings flow that changes the actual system preference.
@interface GFTTestView : GroupingTeachingFocusView
@property (nonatomic) BOOL testMotionAllowed;
@property (nonatomic) BOOL testVisibility;
/// Deliver a lifecycle callback at configure's layout boundary, before UIKit
/// builds the new scene. Real pending-trait propagation has its own test below.
@property (nonatomic, copy) void (^beforeNextLayout)(void);
@end
@implementation GFTTestView
- (BOOL)motionAllowed { return self.testMotionAllowed; }
- (BOOL)actuallyVisible { return self.testVisibility; }
- (BOOL)applicationActive { return YES; }
- (void)layoutIfNeeded {
    void (^callback)(void) = self.beforeNextLayout; self.beforeNextLayout = nil;
    if (callback) callback();
    [super layoutIfNeeded];
}
@end
@interface GroupingTeachingFocusViewTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) GFTTestView *focus;
@end
@implementation GroupingTeachingFocusViewTests
- (void)setUp {
    [super setUp]; self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 700, 1200)];
    self.window.rootViewController = [[UIViewController alloc] init]; self.window.hidden = NO;
    self.focus = [[GFTTestView alloc] initWithFrame:CGRectMake(0, 0, 320, 600)];
    self.focus.testMotionAllowed = YES; self.focus.testVisibility = YES;
    [self.window.rootViewController.view addSubview:self.focus];
}
- (void)tearDown {
    self.focus.beforeNextLayout = nil;
    // Dispose of a failed scene without trying to render it a second time.
    [self.focus configureWithAction:nil]; [self.focus.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [self.focus removeFromSuperview]; self.focus = nil;
    self.window.hidden = YES; self.window.rootViewController = nil; self.window = nil; [super tearDown];
}
- (GroupingTeachingSequence *)sequence:(BOOL)share {
    GroupingStoryContext *context = [[GroupingStoryContext alloc] initWithMeaning:share ? GroupingStoryMeaningShareEqually : GroupingStoryMeaningMakeGroupsOf
        itemName:@"糖果" itemUnit:@"顆" groupName:share ? @"個小朋友" : @"包" answerUnit:share ? @"顆" : @"包"];
    WordProblem *story = [[WordProblem alloc] initWithStory:@"原來的故事" templateID:@"focus-native-components" grade:3 number1:23 number2:4 operator:@"÷" answer:5 unit:context.answerUnit
        missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:3 number3:0 operator2:nil intermediate:0 isFractionAnswer:NO answerNumerator:0 answerDenominator:0 groupingContext:context strategyText:@"照原來的規則。"];
    return [GroupingTeachingSequence sequenceForWordProblem:story];
}
- (GroupingTeachingAction *)actionSharing:(BOOL)share last:(BOOL)last full:(BOOL)full {
    GroupingTeachingSequence *sequence = [self sequence:share]; NSInteger index = 0;
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) if (sequence.steps[i].kind == (share ? GroupingTeachingStepKindShareRound : GroupingTeachingStepKindPackGroup)) { index = i; if (!last) break; }
    if (full) return [GroupingTeachingAction fullActionForSequence:sequence stepIndex:index];
    NSArray *actions = [GroupingTeachingAction focusedActionsForSequence:sequence stepIndex:index]; return last ? actions.lastObject : actions.firstObject;
}
- (void)fitAction:(GroupingTeachingAction *)action width:(CGFloat)width {
    [self.focus configureWithAction:action]; CGSize size = [self.focus sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    self.focus.frame = CGRectMake(0, 0, size.width, size.height); [self.focus setNeedsLayout]; [self.focus layoutIfNeeded];
}
- (void)assertConservation {
    NSInteger total = self.focus.displayedPoolCount + self.focus.inFlightCount;
    for (NSNumber *count in self.focus.displayedGroupCounts) total += count.integerValue;
    XCTAssertEqual(total, 23); XCTAssertGreaterThanOrEqual(self.focus.displayedPoolCount, 0); XCTAssertLessThanOrEqual(self.focus.inFlightCount, 1);
}
- (void)assertAfterSceneBelongsToAction:(GroupingTeachingAction *)action {
    XCTAssertEqual(self.focus.action, action);
    XCTAssertEqual(self.focus.displayedPoolCount, action.snapshot.poolCountAfter.integerValue);
    XCTAssertEqualObjects(self.focus.displayedGroupCounts, action.snapshot.groupCountsAfter);
    XCTAssertEqual(self.focus.inFlightCount, 0); XCTAssertFalse(self.focus.isShowingBeforeState);
    NSDictionary *counters = [self.focus valueForKey:@"counters"];
    NSDictionary *sources = [self.focus valueForKey:@"sourcePoints"];
    NSDictionary *targets = [self.focus valueForKey:@"targetPoints"];
    NSDictionary *owners = [self.focus valueForKey:@"targetGroups"];
    NSMutableSet *expectedIDs = [NSMutableSet set], *sourceIDs = [NSMutableSet set], *movingIDs = [NSMutableSet set];
    NSMutableDictionary *expectedOwners = [NSMutableDictionary dictionary];
    for (NSInteger identity = 0; identity < action.snapshot.poolCountBefore.integerValue; identity++) {
        [sourceIDs addObject:@(identity)]; [expectedIDs addObject:@(identity)];
    }
    for (NSNumber *group in action.snapshot.activeGroupIndices) for (NSNumber *identity in action.groupIdentitiesAfter[group.integerValue]) {
        expectedOwners[identity] = group; [expectedIDs addObject:identity];
        if ([sourceIDs containsObject:identity]) [movingIDs addObject:identity];
    }
    XCTAssertEqualObjects([NSSet setWithArray:counters.allKeys], expectedIDs);
    XCTAssertEqualObjects([NSSet setWithArray:sources.allKeys], sourceIDs);
    XCTAssertEqualObjects([NSSet setWithArray:targets.allKeys], [NSSet setWithArray:expectedOwners.allKeys]);
    XCTAssertEqualObjects(owners, expectedOwners);
    XCTAssertEqualObjects([NSSet setWithArray:[self.focus valueForKey:@"movingIDs"]], movingIDs);
    for (NSNumber *identity in expectedIDs) {
        UIView *counter = counters[identity];
        CGPoint expected = expectedOwners[identity] ? [targets[identity] CGPointValue] : [sources[identity] CGPointValue];
        XCTAssertTrue(CGPointEqualToPoint(counter.center, expected), @"identity %@ retained the wrong position", identity);
    }
    [self assertConservation];
}
- (NSArray<UILabel *> *)labels {
    NSMutableArray *labels = [NSMutableArray array]; for (UIView *view in self.focus.subviews) if ([view isKindOfClass:UILabel.class]) [labels addObject:view]; return labels;
}
- (void)assertTextAndCounterContainment {
    for (UILabel *label in self.labels) {
        CGRect text = [label.text boundingRectWithSize:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:label.font} context:nil];
        XCTAssertLessThanOrEqual(ceil(text.size.height), label.bounds.size.height + 0.5, @"%@", label.text);
        XCTAssertTrue(CGRectContainsRect(self.focus.bounds, label.frame));
    }
    NSDictionary<NSNumber *, UIView *> *counters = [self.focus valueForKey:@"counters"];
    for (UIView *counter in counters.allValues) {
        XCTAssertEqualWithAccuracy(counter.bounds.size.width, 20, 0.01); XCTAssertEqualWithAccuracy(counter.bounds.size.height, 20, 0.01);
        XCTAssertTrue(CGRectContainsRect(self.focus.requiredActionRect, counter.frame));
    }
}
- (NSString *)geometryDescription {
    NSMutableArray *lines = [NSMutableArray arrayWithObjects:
        [NSString stringWithFormat:@"category=%@ bounds=%@ required=%@ measured=%@", self.focus.traitCollection.preferredContentSizeCategory,
            NSStringFromCGRect(self.focus.bounds), NSStringFromCGRect(self.focus.requiredActionRect),
            NSStringFromCGSize([self.focus requiredActionSizeThatFits:CGSizeMake(self.focus.bounds.size.width, CGFLOAT_MAX)])], nil];
    for (UILabel *label in self.labels) {
        CGRect text = [label.text boundingRectWithSize:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX)
            options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:label.font} context:nil];
        [lines addObject:[NSString stringWithFormat:@"%@ font=%@ %.2fpt lineHeight=%.2f frame=%@ textHeight=%.2f text=%@",
            label.accessibilityIdentifier, label.font.fontName, label.font.pointSize, label.font.lineHeight, NSStringFromCGRect(label.frame), text.size.height, label.text]];
    }
    return [lines componentsJoinedByString:@"\n"];
}
- (void)assertCategory:(NSString *)category fontSize:(CGFloat)fontSize maximumActionHeight:(CGFloat)height diagnosticName:(NSString *)name {
    NSString *geometry = [self geometryDescription];
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:geometry];
    attachment.name = name; attachment.lifetime = XCTAttachmentLifetimeKeepAlways; [self addAttachment:attachment];
    XCTAssertEqualObjects(self.focus.traitCollection.preferredContentSizeCategory, category, @"%@", geometry);
    XCTAssertGreaterThan(self.labels.count, 0u);
    for (UILabel *label in self.labels) {
        XCTAssertEqualObjects(label.traitCollection.preferredContentSizeCategory, category, @"%@", geometry);
        XCTAssertEqualWithAccuracy(label.font.pointSize, fontSize, 0.01, @"%@", geometry);
        XCTAssertFalse(label.adjustsFontSizeToFitWidth, @"%@", geometry);
    }
    CGFloat measured = [self.focus requiredActionSizeThatFits:CGSizeMake(self.focus.bounds.size.width, CGFLOAT_MAX)].height;
    XCTAssertEqualWithAccuracy(self.focus.requiredActionRect.size.height, measured, 0.01, @"%@", geometry);
    XCTAssertLessThanOrEqual(self.focus.requiredActionRect.size.height, height, @"%@", geometry);
    [self assertTextAndCounterContainment]; [self assertConservation];
}
- (void)testFixedCounterSizeAndReadableGeometryAtCompactWideAndMaximumText {
    NSArray *actions = @[[self actionSharing:YES last:NO full:NO], [self actionSharing:YES last:YES full:NO], [self actionSharing:NO last:NO full:YES], [self actionSharing:NO last:YES full:YES]];
    for (NSString *category in @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        self.focus.traitOverrides.preferredContentSizeCategory = category;
        for (NSNumber *width in @[@288, @361, @680]) for (GroupingTeachingAction *action in actions) {
            [self fitAction:action width:width.doubleValue]; [self assertTextAndCounterContainment]; [self assertConservation];
            XCTAssertGreaterThan(self.focus.traitCollection.displayScale, 0); XCTAssertEqualObjects(self.focus.traitCollection.preferredContentSizeCategory, category);
            [self.focus showBeforeState]; [self assertTextAndCounterContainment]; [self assertConservation];
        }
    }
}
- (void)testReconfigurationWithPendingTextChangeDoesNotRenderPreviousBagOwners {
    GroupingTeachingAction *lastBag = [self actionSharing:NO last:YES full:YES];
    NSArray *nextActions = @[[self actionSharing:YES last:NO full:NO], [self actionSharing:NO last:NO full:YES]];
    for (GroupingTeachingAction *next in nextActions) for (NSString *category in @[UIContentSizeCategoryAccessibilityExtraExtraExtraLarge, UIContentSizeCategoryLarge]) {
        [self fitAction:lastBag width:361]; [self.focus showBeforeState];
        XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@4, @4, @4, @4, @0]));
        NSUInteger generation = self.focus.playbackGeneration;
        // Do not read traitCollection or force layout between this override and
        // configuration. This is the native re-entrant path in the retained crash.
        self.focus.traitOverrides.preferredContentSizeCategory = category;
        [self.focus configureWithAction:next];
        XCTAssertEqualObjects(self.focus.traitCollection.preferredContentSizeCategory, category);
        XCTAssertGreaterThan(self.focus.playbackGeneration, generation);
        XCTAssertNil([self.focus valueForKey:@"clock"]);
        [self assertAfterSceneBelongsToAction:next];
        [self.focus cancelPlayback]; [self assertAfterSceneBelongsToAction:next];
    }
}
- (void)testLifecycleReentryDuringActionReplacementCannotUsePreviousOwnerMaps {
    GroupingTeachingAction *lastBag = [self actionSharing:NO last:YES full:YES];
    NSArray *nextActions = @[[self actionSharing:NO last:NO full:YES], [self actionSharing:YES last:NO full:NO]];
    for (GroupingTeachingAction *next in nextActions) for (NSString *notification in @[UIApplicationWillResignActiveNotification, UIAccessibilityReduceMotionStatusDidChangeNotification, UIContentSizeCategoryDidChangeNotification]) {
        [self fitAction:lastBag width:361]; XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]);
        [self.focus renderElapsed:0.28 + 0.82 * 2.4]; XCTAssertEqual(self.focus.inFlightCount, 1);
        CADisplayLink *old = [self.focus valueForKey:@"clock"]; NSUInteger generation = self.focus.playbackGeneration;
        __block NSUInteger callbacks = 0;
        BOOL reduceMotion = [notification isEqualToString:UIAccessibilityReduceMotionStatusDidChangeNotification];
        __weak GFTTestView *weakFocus = self.focus;
        self.focus.beforeNextLayout = ^{
            GFTTestView *focus = weakFocus; callbacks++;
            XCTAssertEqual(focus.action, next);
            XCTAssertTrue(CGRectIsNull(focus.requiredActionRect));
            XCTAssertEqual([[focus valueForKey:@"counters"] count], 0u);
            if (reduceMotion) focus.testMotionAllowed = NO;
            [NSNotificationCenter.defaultCenter postNotificationName:notification object:nil];
            [focus tick:old generation:generation];
        };
        [self.focus configureWithAction:next];
        XCTAssertEqual(callbacks, 1u); XCTAssertNil([self.focus valueForKey:@"clock"]);
        XCTAssertGreaterThan(self.focus.playbackGeneration, generation);
        XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]);
        XCTAssertEqualObjects(self.focus.playbackState, reduceMotion ? @"reduced-motion" : @"settled");
        [self assertAfterSceneBelongsToAction:next];
        self.focus.testMotionAllowed = YES;
        if (reduceMotion) [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        XCTAssertEqualObjects(self.focus.playbackState, @"settled"); [self assertAfterSceneBelongsToAction:next];
    }
}
- (void)testRestartFromLastPackingActionKeepsNewPlaybackIndependentOfOldClock {
    [self fitAction:[self actionSharing:NO last:YES full:YES] width:361];
    XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]); [self.focus renderElapsed:0.28 + 0.82 * 2.4];
    CADisplayLink *old = [self.focus valueForKey:@"clock"]; NSUInteger oldGeneration = self.focus.playbackGeneration;
    GroupingTeachingAction *firstBag = [self actionSharing:NO last:NO full:YES];
    [self.focus configureWithAction:firstBag]; [self assertAfterSceneBelongsToAction:firstBag];
    NSDictionary *counters = [[self.focus valueForKey:@"counters"] copy];
    XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]);
    CADisplayLink *current = [self.focus valueForKey:@"clock"]; NSUInteger generation = self.focus.playbackGeneration;
    XCTAssertNotEqual(old, current); XCTAssertGreaterThan(generation, oldGeneration);
    [self.focus tick:old generation:oldGeneration]; [self.focus tick:old generation:generation]; [self.focus tick:current generation:oldGeneration];
    XCTAssertEqual([self.focus valueForKey:@"clock"], current); XCTAssertEqualObjects(self.focus.playbackState, @"running");
    XCTAssertEqual(self.focus.displayedPoolCount, 23); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@0]));
    XCTAssertEqual(self.focus.inFlightCount, 0); XCTAssertTrue(self.focus.isShowingBeforeState);
    [self.focus renderElapsed:20]; XCTAssertEqualObjects(self.focus.playbackState, @"completed"); [self assertAfterSceneBelongsToAction:firstBag];
    [self.focus showBeforeState]; [self.focus showAfterState];
    NSDictionary *now = [self.focus valueForKey:@"counters"];
    for (NSNumber *identity in counters) XCTAssertEqual(counters[identity], now[identity]);
    [self assertAfterSceneBelongsToAction:firstBag];
}
- (void)testNilAndZeroWidthReconfigurationDiscardPreviousSceneUntilLayoutIsReady {
    [self fitAction:[self actionSharing:NO last:YES full:YES] width:361];
    XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]);
    CADisplayLink *old = [self.focus valueForKey:@"clock"]; NSUInteger generation = self.focus.playbackGeneration;
    [self.focus configureWithAction:nil];
    XCTAssertNil(self.focus.action); XCTAssertNil([self.focus valueForKey:@"clock"]); XCTAssertTrue(CGRectIsNull(self.focus.requiredActionRect));
    XCTAssertEqual(self.focus.subviews.count, 0u); XCTAssertEqual([[self.focus valueForKey:@"counters"] count], 0u);
    XCTAssertEqual(self.focus.displayedPoolCount, 0); XCTAssertEqualObjects(self.focus.displayedGroupCounts, @[]);
    XCTAssertEqualObjects(self.focus.spokenDescription, @""); XCTAssertNil(self.focus.accessibilityValue);
    [self.focus tick:old generation:generation];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    GroupingTeachingAction *firstRecipient = [self actionSharing:YES last:NO full:NO];
    self.focus.frame = CGRectZero; [self.focus configureWithAction:firstRecipient]; [self.focus showBeforeState];
    XCTAssertEqual([[self.focus valueForKey:@"targetGroups"] count], 0u); XCTAssertTrue(CGRectIsNull(self.focus.requiredActionRect));
    XCTAssertFalse([self.focus playInVisibleRect:CGRectMake(0, 0, 361, 900)]); XCTAssertNil([self.focus valueForKey:@"clock"]);
    CGSize size = [self.focus sizeThatFits:CGSizeMake(361, CGFLOAT_MAX)];
    self.focus.frame = CGRectMake(0, 0, size.width, size.height); [self.focus setNeedsLayout]; [self.focus layoutIfNeeded];
    XCTAssertTrue(self.focus.isShowingBeforeState); XCTAssertEqual(self.focus.displayedPoolCount, 23);
    XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@0, @0, @0, @0])); [self assertConservation];
    [self.focus showAfterState]; [self assertAfterSceneBelongsToAction:firstRecipient];
}
- (void)testRenderingInvariantFailureStillClosesItsCoreAnimationTransaction {
    GroupingTeachingAction *lastBag = [self actionSharing:NO last:YES full:YES]; [self fitAction:lastBag width:361];
    NSMutableDictionary *owners = [self.focus valueForKey:@"targetGroups"];
    NSNumber *identity = [[self.focus valueForKey:@"movingIDs"] firstObject], *owner = owners[identity];
    // Deliberately violate the renderer invariant, not the immutable math model.
    // The failure must remain visible rather than silently dropping a counter.
    [CATransaction begin]; [CATransaction setDisableActions:NO];
    @try {
        owners[identity] = @(lastBag.snapshot.groupCountsAfter.count);
        XCTAssertThrowsSpecificNamed([self.focus showAfterState], NSException, NSRangeException);
        BOOL leakedTransaction = [CATransaction disableActions];
        // Keep this regression itself isolated even if the finally is removed.
        if (leakedTransaction) [CATransaction commit];
        XCTAssertFalse(leakedTransaction, @"A failed render must not leave its inner transaction on the caller's stack.");
    } @finally {
        owners[identity] = owner; [CATransaction commit];
    }
    [self.focus showAfterState]; [self assertAfterSceneBelongsToAction:lastBag];
}
- (void)testRealActionGeometryFitsCompactAndMaximumTextPortraitButRejectsLandscape {
    self.focus.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge;
    [self fitAction:[self actionSharing:YES last:NO full:NO] width:288];
    [self assertCategory:UIContentSizeCategoryLarge fontSize:18 maximumActionHeight:355 diagnosticName:@"focused-compact-large-geometry"];
    UILabel *caption = [self.focus valueForKey:@"captionLabel"];
    XCTAssertTrue([caption.text containsString:@"這輪每位只再拿 1 顆"]);
    self.focus.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self fitAction:[self actionSharing:YES last:YES full:NO] width:361];
    [self assertCategory:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge fontSize:28 maximumActionHeight:577 diagnosticName:@"focused-portrait-maximum-text-geometry"];
    XCTAssertGreaterThan(self.focus.requiredActionRect.size.height, 208);
    XCTAssertFalse([self.focus playInVisibleRect:CGRectMake(0, 0, 361, 208)]);
    XCTAssertEqualObjects(self.focus.playbackState, @"paused-visibility"); XCTAssertNil([self.focus valueForKey:@"clock"]);
    XCTAssertEqual(self.focus.displayedPoolCount, 3); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@5, @5, @5, @5]));
    XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]);
    self.focus.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge;
    [self fitAction:[self actionSharing:YES last:NO full:NO] width:288];
    [self assertCategory:UIContentSizeCategoryLarge fontSize:18 maximumActionHeight:355 diagnosticName:@"focused-compact-restored-large-geometry"];
}
- (void)testOneExistingObjectMovesAtATimeWithoutCrossingAnyLabelOrStationaryCounter {
    for (GroupingTeachingAction *action in @[[self actionSharing:YES last:NO full:YES], [self actionSharing:NO last:YES full:YES]]) {
        [self fitAction:action width:361]; XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]);
        NSDictionary<NSNumber *, UIView *> *counters = [[self.focus valueForKey:@"counters"] copy]; NSArray<NSNumber *> *moving = [self.focus valueForKey:@"movingIDs"];
        for (NSInteger index = 0; index < (NSInteger)moving.count; index++) for (NSInteger sample = 0; sample <= 80; sample++) {
            CGFloat progress = sample / 80.0; [self.focus renderElapsed:0.28 + 0.82 * (index + progress * 0.839)]; [self assertConservation];
            UIView *mover = counters[moving[index]]; NSDictionary *current = [self.focus valueForKey:@"counters"];
            XCTAssertEqual(mover, current[moving[index]]); XCTAssertTrue(CGRectContainsRect(self.focus.requiredActionRect, mover.frame));
            for (UILabel *label in self.labels) XCTAssertFalse(CGRectIntersectsRect(mover.frame, label.frame), @"%@ crossed %@ at %.3f", moving[index], label.text, progress);
            for (NSNumber *identity in counters) if (![identity isEqual:moving[index]]) XCTAssertFalse(CGRectIntersectsRect(mover.frame, counters[identity].frame), @"%@ crossed %@ at %.3f", moving[index], identity, progress);
        }
        [self.focus renderElapsed:20]; XCTAssertEqualObjects(self.focus.playbackState, @"completed"); [self assertConservation];
        XCTAssertEqualObjects(self.focus.displayedGroupCounts, action.snapshot.groupCountsAfter); XCTAssertEqual(self.focus.displayedPoolCount, action.snapshot.poolCountAfter.integerValue);
    }
}
- (void)testReplayUsesTheSameViewsAndBeforeStateAfterCompletingTheSelectedFourthRecipient {
    NSArray *actions = [GroupingTeachingAction focusedActionsForSequence:[self sequence:YES] stepIndex:2];
    [self fitAction:actions.lastObject width:361]; NSDictionary *counters = [[self.focus valueForKey:@"counters"] copy];
    for (NSUInteger replay = 0; replay < 3; replay++) {
        XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]);
        XCTAssertEqual(self.focus.displayedPoolCount, 20); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@1, @1, @1, @0]));
        [self.focus renderElapsed:20]; XCTAssertEqual(self.focus.displayedPoolCount, 19); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@1, @1, @1, @1]));
        NSDictionary *now = [self.focus valueForKey:@"counters"]; for (NSNumber *identity in counters) XCTAssertEqual(counters[identity], now[identity]);
    }
}
- (void)testBackgroundAndMotionPreferenceCancellationIgnoreOldClockCallbacks {
    [self fitAction:[self actionSharing:NO last:YES full:YES] width:361];
    for (NSString *notification in @[UIApplicationWillResignActiveNotification, UIAccessibilityReduceMotionStatusDidChangeNotification]) {
        XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]); CADisplayLink *old = [self.focus valueForKey:@"clock"]; NSUInteger generation = self.focus.playbackGeneration;
        [NSNotificationCenter.defaultCenter postNotificationName:notification object:nil];
        XCTAssertNil([self.focus valueForKey:@"clock"]); XCTAssertGreaterThan(self.focus.playbackGeneration, generation); XCTAssertEqualObjects(self.focus.playbackState, @"cancelled");
        [self.focus tick:old generation:generation]; [self.focus renderElapsed:20];
        XCTAssertEqualObjects(self.focus.playbackState, @"cancelled"); XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]); [self assertConservation];
    }
}
- (void)testResizeHideAndDetachCancelWithoutSelectingAnotherAction {
    GroupingTeachingAction *action = [self actionSharing:NO last:YES full:YES]; [self fitAction:action width:361];
    XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]); self.focus.frame = CGRectMake(0, 0, 680, 500); [self.focus setNeedsLayout]; [self.focus layoutIfNeeded];
    XCTAssertNil([self.focus valueForKey:@"clock"]); XCTAssertEqual(self.focus.action, action); XCTAssertEqual(self.focus.displayedPoolCount, 3);
    XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]); self.focus.hidden = YES; XCTAssertNil([self.focus valueForKey:@"clock"]);
    self.focus.hidden = NO; XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]); [self.focus removeFromSuperview];
    XCTAssertNil([self.focus valueForKey:@"clock"]); XCTAssertEqual(self.focus.action, action); XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]);
}
- (void)testReducedMotionIsASeparateSettledStateWithManualBeforeAfter {
    [self fitAction:[self actionSharing:NO last:NO full:YES] width:361]; self.focus.testMotionAllowed = NO;
    XCTAssertFalse([self.focus playInVisibleRect:self.focus.bounds]); XCTAssertEqualObjects(self.focus.playbackState, @"reduced-motion");
    XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]); XCTAssertNil([self.focus valueForKey:@"clock"]);
    XCTAssertEqual(self.focus.displayedPoolCount, 19); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@4]));
    [self.focus showBeforeState]; XCTAssertEqual(self.focus.displayedPoolCount, 23); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@0]));
    XCTAssertTrue([self.focus.spokenDescription containsString:@"動作前"]); XCTAssertFalse([self.focus.spokenDescription containsString:@"這輪分完了"]);
    [self.focus showAfterState]; XCTAssertEqual(self.focus.displayedPoolCount, 19); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@4]));
}
- (void)testActualMotionPreferenceDependencyClearsStaleCompletionWithoutAdvancing {
    GroupingTeachingAction *action = [self actionSharing:NO last:NO full:YES];
    [self fitAction:action width:361]; XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]);
    CADisplayLink *old = [self.focus valueForKey:@"clock"]; NSUInteger generation = self.focus.playbackGeneration;
    self.focus.testMotionAllowed = NO;
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    XCTAssertEqualObjects(self.focus.playbackState, @"reduced-motion"); XCTAssertNil([self.focus valueForKey:@"clock"]);
    [self.focus tick:old generation:generation]; [self.focus renderElapsed:20];
    XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]); XCTAssertEqual(self.focus.action, action); [self assertConservation];
    [self.focus showBeforeState]; XCTAssertEqual(self.focus.displayedPoolCount, 23); XCTAssertEqualObjects(self.focus.playbackState, @"reduced-motion");
    self.focus.testMotionAllowed = YES;
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    XCTAssertEqualObjects(self.focus.playbackState, @"before"); XCTAssertTrue(self.focus.isShowingBeforeState); XCTAssertNil([self.focus valueForKey:@"clock"]);
    XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]); [self.focus renderElapsed:20]; XCTAssertEqualObjects(self.focus.playbackState, @"completed");
    self.focus.testMotionAllowed = NO;
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    XCTAssertEqualObjects(self.focus.playbackState, @"reduced-motion"); XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]);
    [self.focus pauseForVisibility];
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    XCTAssertEqualObjects(self.focus.playbackState, @"paused-visibility"); XCTAssertEqual(self.focus.action, action);
}
- (void)testAVisibleRectClaimCannotOverrideActualAncestorClipping {
    [self fitAction:[self actionSharing:YES last:NO full:NO] width:361];
    UIScrollView *clipped = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 361, 180)]; clipped.clipsToBounds = YES;
    [self.window.rootViewController.view addSubview:clipped];
    GroupingTeachingFocusView *realView = [[GroupingTeachingFocusView alloc] initWithFrame:self.focus.frame]; [clipped addSubview:realView];
    [realView configureWithAction:self.focus.action]; [realView setNeedsLayout]; [realView layoutIfNeeded];
    XCTAssertFalse([realView playInVisibleRect:realView.bounds]); XCTAssertEqualObjects(realView.playbackState, @"paused-visibility"); XCTAssertNil([realView valueForKey:@"clock"]);
    [realView cancelPlayback]; [clipped removeFromSuperview];
}
- (void)testExplicitBeforeInspectionSurvivesPassiveResizeTextAndBackground {
    [self fitAction:[self actionSharing:NO last:NO full:YES] width:361]; [self.focus showBeforeState];
    self.focus.frame = CGRectMake(0, 0, 680, 500); [self.focus setNeedsLayout]; [self.focus layoutIfNeeded];
    XCTAssertTrue(self.focus.isShowingBeforeState); XCTAssertEqual(self.focus.displayedPoolCount, 23);
    self.focus.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self.focus setNeedsLayout]; [self.focus layoutIfNeeded]; [self.focus pauseForVisibility];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertTrue(self.focus.isShowingBeforeState); XCTAssertEqual(self.focus.displayedPoolCount, 23); XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@0]));
    XCTAssertNil([self.focus valueForKey:@"clock"]); [self.focus showAfterState]; XCTAssertEqual(self.focus.displayedPoolCount, 19);
}
- (void)testOnlyNaturalClockEndMarksTheSelectedActionCompleted {
    [self fitAction:[self actionSharing:YES last:NO full:NO] width:361]; XCTAssertTrue([self.focus playInVisibleRect:self.focus.bounds]);
    NSPredicate *finished = [NSPredicate predicateWithFormat:@"playbackState == %@", @"completed"];
    XCTestExpectation *completion = [self expectationForPredicate:finished evaluatedWithObject:self.focus handler:nil];
    [self waitForExpectations:@[completion] timeout:2.5];
    XCTAssertNil([self.focus valueForKey:@"clock"]); XCTAssertTrue([self.focus.accessibilityValue containsString:@"播放完成"]); [self assertConservation];
}
- (void)testOverviewUsesExactPartialSnapshotRatherThanCompletedRound {
    GroupingTeachingAction *action = [self actionSharing:YES last:NO full:NO];
    GroupingTeachingBoardView *overview = [[GroupingTeachingBoardView alloc] initWithFrame:CGRectMake(0, 0, 361, 1600)];
    XCTAssertTrue([overview configureWithAction:action]); XCTAssertEqual(overview.currentStep, action.snapshot);
    XCTAssertTrue([overview.accessibilityValue containsString:@"第 1 個小朋友有 1 顆"]); XCTAssertTrue([overview.accessibilityValue containsString:@"第 4 個小朋友有 0 顆"]);
    XCTAssertTrue([overview.accessibilityValue containsString:@"待分的糖果：22 顆"]); XCTAssertTrue([overview.accessibilityValue containsString:@"這輪還沒分完"]);
    XCTAssertNil([overview valueForKey:@"animationDisplayLink"]);
}
- (void)testSourceSurvivorsKeepTheirPositionsAcrossTenToNineDigitWrap {
    NSArray<GroupingTeachingAction *> *actions = [GroupingTeachingAction focusedActionsForSequence:[self sequence:YES] stepIndex:8];
    XCTAssertEqualObjects(actions[1].snapshot.poolCountBefore, @10); XCTAssertEqualObjects(actions[2].snapshot.poolCountBefore, @9);
    self.focus.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    for (NSInteger width = 288; width <= 398; width++) {
        [self fitAction:actions[1] width:width]; NSDictionary *before = [[self.focus valueForKey:@"sourcePoints"] copy];
        [self fitAction:actions[2] width:width]; NSDictionary *after = [self.focus valueForKey:@"sourcePoints"];
        for (NSInteger identity = 0; identity < 8; identity++) XCTAssertTrue(CGPointEqualToPoint([before[@(identity)] CGPointValue], [after[@(identity)] CGPointValue]), @"width %ld identity %ld", (long)width, (long)identity);
    }
}
- (void)testPartialAndFinalRecipientOverviewFramesStayStable {
    NSArray<GroupingTeachingAction *> *actions = [GroupingTeachingAction focusedActionsForSequence:[self sequence:YES] stepIndex:2];
    GroupingTeachingBoardView *overview = [[GroupingTeachingBoardView alloc] initWithFrame:CGRectMake(0, 0, 361, 2000)];
    [self.window.rootViewController.view addSubview:overview]; overview.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    for (NSNumber *width in @[@288, @361, @680]) {
        CGRect first = CGRectNull;
        for (GroupingTeachingAction *action in actions) {
            [overview configureWithAction:action]; CGSize size = [overview sizeThatFits:CGSizeMake(width.doubleValue, CGFLOAT_MAX)]; overview.frame = CGRectMake(0, 0, size.width, size.height); [overview setNeedsLayout]; [overview layoutIfNeeded];
            UIView *group = [[overview valueForKey:@"groupViews"] firstObject];
            if (CGRectIsNull(first)) first = group.frame;
            XCTAssertTrue(CGRectEqualToRect(group.frame, first));
        }
    }
    [overview.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class]; [overview removeFromSuperview];
}
@end
