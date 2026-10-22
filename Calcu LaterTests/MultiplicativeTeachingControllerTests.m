#import <XCTest/XCTest.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "MultiplicativeTeachingViewController.h"
#import "MultiplicativeTeachingPresentation.h"
#import "MultiplicativePlaceValueBoardView.h"
#import "MultiplicativeWrittenWorkView.h"
#import "ChildUIKit.h"
#import "WordProblem.h"

// Fixture isolation only: never hide foreign windows or infer order from key status.
// Include a hidden model if its native presentation or animation may still paint.
static BOOL MTPFixtureWindowMayPaint(UIWindow *window) {
    CALayer *layer = window.layer, *paint = layer.presentationLayer;
    return layer.animationKeys.count || !((layer.hidden || layer.opacity <= 0)
        && (!paint || paint.hidden || paint.opacity <= 0));
}
static CGFloat MTPFixtureLevelAboveScene(UIWindowScene *scene, UIWindow *fixture) {
    CGFloat highest = UIWindowLevelNormal;
    for (UIWindow *window in scene.windows) if (window != fixture && MTPFixtureWindowMayPaint(window)) {
        if (!isfinite(window.windowLevel)) return NAN;
        highest = MAX(highest, window.windowLevel);
    }
    CGFloat level = highest + 1;
    return isfinite(level) && level > highest ? level : NAN;
}
static BOOL MTPFixtureHasStrictWindowOrder(UIWindow *fixture, UIWindowScene *scene) {
    if (!fixture || !scene || fixture.windowScene != scene || ![scene.windows containsObject:fixture]
        || !isfinite(fixture.windowLevel)) return NO;
    for (UIWindow *window in scene.windows) if (window != fixture && MTPFixtureWindowMayPaint(window)
        && (!isfinite(window.windowLevel) || !(fixture.windowLevel > window.windowLevel))) return NO;
    return YES;
}
// Only public, read-only metadata. Never load a root view or inspect UI text.
// Bound both the tree depth and the total visited nodes, including paint-only nodes.
static void MTPAppendWindowLayerDiagnostic(NSMutableArray<NSString *> *lines, CALayer *layer,
                                            NSUInteger depth, NSUInteger *remaining, BOOL presented) {
    if (!layer || !*remaining) return;
    --*remaining;
    CALayer *paint = presented ? layer : layer.presentationLayer;
    [lines addObject:[NSString stringWithFormat:@"windowLayer depth=%lu presented=%d class=%@ delegateClass=%@ model=%p frame=%@ bounds=%@ position=%@ hidden=%d opacity=%g z=%g clips=%d mask=%d contents=%d backgroundAlpha=%g shadow=%g animated=%d transformIdentity=%d sublayerTransformIdentity=%d; paint=%p modelLink=%d frame=%@ bounds=%@ position=%@ hidden=%d opacity=%g z=%g clips=%d mask=%d contents=%d backgroundAlpha=%g shadow=%g transformIdentity=%d sublayerTransformIdentity=%d children=%lu/%lu",
        (unsigned long)depth, presented, NSStringFromClass(layer.class), NSStringFromClass([(id)layer.delegate class]), layer.modelLayer,
        NSStringFromCGRect(layer.frame), NSStringFromCGRect(layer.bounds), NSStringFromCGPoint(layer.position), layer.hidden, (double)layer.opacity, (double)layer.zPosition,
        layer.masksToBounds, layer.mask != nil, layer.contents != nil, (double)(layer.backgroundColor ? CGColorGetAlpha(layer.backgroundColor) : 0), (double)layer.shadowOpacity, layer.animationKeys.count != 0,
        CATransform3DIsIdentity(layer.transform), CATransform3DIsIdentity(layer.sublayerTransform), paint, paint.modelLayer == (presented ? layer.modelLayer : layer),
        NSStringFromCGRect(paint.frame), NSStringFromCGRect(paint.bounds), NSStringFromCGPoint(paint.position), paint.hidden, (double)paint.opacity, (double)paint.zPosition,
        paint.masksToBounds, paint.mask != nil, paint.contents != nil, (double)(paint.backgroundColor ? CGColorGetAlpha(paint.backgroundColor) : 0), (double)paint.shadowOpacity,
        CATransform3DIsIdentity(paint.transform), CATransform3DIsIdentity(paint.sublayerTransform), (unsigned long)layer.sublayers.count, (unsigned long)paint.sublayers.count]];
    if (depth >= 3) return;
    for (CALayer *child in layer.sublayers) {
        if (!*remaining) break;
        MTPAppendWindowLayerDiagnostic(lines, child, depth + 1, remaining, presented);
    }
    if (!presented) for (CALayer *child in paint.sublayers) {
        if (!*remaining) break;
        if (!child.modelLayer || ![layer.sublayers containsObject:child.modelLayer])
            MTPAppendWindowLayerDiagnostic(lines, child, depth + 1, remaining, YES);
    }
}
static NSString *MTPFixtureWindowSnapshot(UIWindowScene *scene, UIWindow *fixture) {
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:
        @"sceneWindowSnapshot sceneState=%ld totalWindows=%lu windowLimit=16 layerNodesPerWindow=16 depthLimit=3",
        (long)scene.activationState, (unsigned long)scene.windows.count]];
    NSUInteger windows = 0;
    for (UIWindow *window in scene.windows) {
        if (windows++ == 16) { [lines addObject:@"additional windows omitted"]; break; }
        UIViewController *root = window.rootViewController; UIView *loadedRoot = root.viewIfLoaded;
        [lines addObject:[NSString stringWithFormat:@"sceneWindow=%p class=%@ current=%d key=%d level=%g hidden=%d alpha=%g frame=%@ potentiallyVisible=%d rootClass=%@ loadedRootClass=%@",
            window, NSStringFromClass(window.class), window == fixture, window.isKeyWindow, (double)window.windowLevel, window.hidden, (double)window.alpha,
            NSStringFromCGRect(window.frame), MTPFixtureWindowMayPaint(window), NSStringFromClass(root.class), NSStringFromClass(loadedRoot.class)]];
        NSUInteger remaining = 16;
        MTPAppendWindowLayerDiagnostic(lines, window.layer, 0, &remaining, NO);
        if (!remaining) [lines addObject:@"window layer node limit reached"];
    }
    return [lines componentsJoinedByString:@"\n"];
}

@interface MultiplicativeTeachingViewController (ComponentTesting)
- (void)selectActionIndex:(NSInteger)index play:(BOOL)play;
- (void)submitProposalText:(NSString *)text key:(MTPPreparationKey *)key;
- (void)observeFirstAction;
- (void)inspectSourceResult;
- (void)showBefore;
- (void)showAfter;
- (void)next;
- (void)previous;
- (void)replay;
- (void)restart;
- (void)close;
- (void)reopenQuestion;
- (void)returnToSavedSelection;
- (void)toggleWritten;
- (void)toggleOverview;
- (void)cancelPlayback:(MTPPlaceValueInterruptionReason)reason;
- (void)applicationInterrupted:(NSNotification *)notification;
- (void)keyboardChanged:(NSNotification *)notification;
- (void)keyboardDidHide:(NSNotification *)notification;
- (void)admitPreparedPlayback:(CADisplayLink *)link;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scroll;
@end

/// Observes the actual static configure boundary; it never changes admission,
/// visibility, animation state, motion preferences or renderer return values.
@interface MTPBoundaryObservingBoard : MultiplicativePlaceValueBoardView
@property (nonatomic, copy) void (^willConfigureAction)(void);
@end
@implementation MTPBoundaryObservingBoard
- (void)configureWithAction:(MultiplicativeTeachingAction *)action sessionID:(NSString *)sessionID
               selectionID:(NSString *)selectionID endpoint:(MTPPlaceValueEndpoint)endpoint {
    if (self.willConfigureAction) self.willConfigureAction();
    [super configureWithAction:action sessionID:sessionID selectionID:selectionID endpoint:endpoint];
}
@end

@interface MultiplicativeTeachingControllerTests : XCTestCase {
    NSString *_preElevationWindowDiagnostic;
}
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIWindow *priorKeyWindow;
@property (nonatomic, strong) MultiplicativeTeachingViewController *controller;
@end
@implementation MultiplicativeTeachingControllerTests
- (void)setUp {
    [super setUp];
    UIWindowScene *foreground = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            foreground = (UIWindowScene *)scene;
            for (UIWindow *candidate in foreground.windows) if (candidate.isKeyWindow) self.priorKeyWindow = candidate;
            if (self.priorKeyWindow) break;
        }
    }
    XCTAssertNotNil(foreground, @"Native component acceptance requires a real foreground UIWindowScene.");
    if (foreground) {
        _preElevationWindowDiagnostic = MTPFixtureWindowSnapshot(foreground, nil);
        self.window = [[UIWindow alloc] initWithWindowScene:foreground];
        CGFloat fixtureLevel = MTPFixtureLevelAboveScene(foreground, self.window);
        XCTAssertTrue(isfinite(fixtureLevel), @"No finite strictly higher fixture level: %@", _preElevationWindowDiagnostic);
        if (!isfinite(fixtureLevel)) return;
        // Set only this owned window once; do not compensate for later overlays.
        self.window.windowLevel = fixtureLevel;
        XCTAssertTrue(MTPFixtureHasStrictWindowOrder(self.window, foreground), @"%@", MTPFixtureWindowSnapshot(foreground, self.window));
        self.window.frame = foreground.coordinateSpace.bounds;
        self.window.rootViewController = [[UIViewController alloc] init];
        [self.window makeKeyAndVisible];
        XCTAssertTrue(MTPFixtureHasStrictWindowOrder(self.window, foreground), @"Order changed during makeKeyAndVisible: %@", MTPFixtureWindowSnapshot(foreground, self.window));
        [self.window layoutIfNeeded]; [CATransaction flush];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.025]];
        XCTAssertEqual(foreground.activationState, UISceneActivationStateForegroundActive);
        XCTAssertTrue(MTPFixtureHasStrictWindowOrder(self.window, foreground), @"Order changed after native presentation: %@", MTPFixtureWindowSnapshot(foreground, self.window));
        CALayer *paint = self.window.layer.presentationLayer;
        XCTAssertNotNil(paint); XCTAssertEqual(paint.modelLayer, self.window.layer); XCTAssertFalse(paint.hidden); XCTAssertGreaterThan(paint.opacity, 0);
    }
}
- (void)tearDown {
    if (_preElevationWindowDiagnostic.length && self.testRun.failureCount) {
        XCTAttachment *attachment = [XCTAttachment attachmentWithString:_preElevationWindowDiagnostic];
        attachment.name = @"native-pre-elevation-scene-windows";
        attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:attachment];
    }
    [self.controller cancelPlayback:MTPPlaceValueInterruptionReasonDetached];
    [self.controller.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [self.controller willMoveToParentViewController:nil]; [self.controller.view removeFromSuperview];
    [self.controller removeFromParentViewController]; self.controller = nil;
    self.window.hidden = YES; self.window.rootViewController = nil; self.window = nil;
    [self.priorKeyWindow makeKeyWindow]; self.priorKeyWindow = nil;
    [super tearDown];
}
- (void)open:(NSInteger)a second:(NSInteger)b operation:(NSString *)operation {
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation
        answer:[operation isEqualToString:@"×"] ? a * b : a / b];
    self.controller = [[MultiplicativeTeachingViewController alloc] initWithProblem:problem wordProblem:nil];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge;
    [self.window.rootViewController addChildViewController:self.controller];
    [self.window.rootViewController.view addSubview:self.controller.view];
    [self.controller didMoveToParentViewController:self.window.rootViewController];
    [self resize:self.window.bounds.size];
}
- (void)resize:(CGSize)size {
    self.controller.view.frame = (CGRect){CGPointZero, size};
    for (NSUInteger pass = 0; pass < 4; pass++) { [self.controller.view setNeedsLayout]; [self.controller.view layoutIfNeeded]; }
}
- (void)awaitExplicitPaintAdmission {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while ([self.controller valueForKey:@"playbackAdmissionLink"] && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    XCTAssertNil([self.controller valueForKey:@"playbackAdmissionLink"], @"The explicit one-frame request must resolve, not hang or retry.");
}
- (MultiplicativeTeachingPresentation *)presentation { return [self.controller valueForKey:@"presentation"]; }
- (MultiplicativeTeachingActionPlan *)plan { return [self.controller valueForKey:@"plan"]; }
- (MultiplicativePlaceValueBoardView *)board { return [self.controller valueForKey:@"board"]; }
- (MultiplicativeWrittenWorkView *)written { return [self.controller valueForKey:@"written"]; }
- (void)assertNoPrediction {
    XCTAssertNil([self.controller valueForKey:@"activePreparationKey"]);
    XCTAssertNil([self.controller valueForKey:@"preparationCard"]);
    XCTAssertNil([self.controller valueForKey:@"proposalField"]);
    XCTAssertNil([self.controller valueForKey:@"feedbackLabel"]);
}
- (void)assertSnapshot:(MultiplicativeTeachingActionSnapshot *)snapshot {
    XCTAssertEqual(self.presentation.snapshot, snapshot); XCTAssertEqual(self.board.snapshot, snapshot); XCTAssertEqual(self.written.snapshot, snapshot);
}
- (void)testBareNumericRouteRejectsStoriesInvalidAnswersAndUnsupportedInputs {
    ArithmeticProblem *(^problem)(NSInteger, NSInteger, NSString *, NSInteger) = ^ArithmeticProblem *(NSInteger a, NSInteger b, NSString *op, NSInteger answer) {
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:answer];
    };
    XCTAssertTrue([MultiplicativeTeachingViewController supportsProblem:problem(99, 9, @"×", 891) wordProblem:nil]);
    XCTAssertTrue([MultiplicativeTeachingViewController supportsProblem:problem(899, 9, @"÷", 99) wordProblem:nil]);
    XCTAssertFalse([MultiplicativeTeachingViewController supportsProblem:problem(99, 9, @"×", 891) wordProblem:[[WordProblem alloc] init]]);
    for (ArithmeticProblem *invalid in @[problem(4, 0, @"×", 0), problem(1000, 1, @"÷", 1000),
        problem(999, 9, @"×", 8991), problem(8, 2, @"+", 10), problem(9, 3, @"÷", 4)])
        XCTAssertFalse([MultiplicativeTeachingViewController supportsProblem:invalid wordProblem:nil]);
    ArithmeticProblem *multiStep = problem(12, 3, @"÷", 4); multiStep.isMultiStep = YES;
    XCTAssertFalse([MultiplicativeTeachingViewController supportsProblem:multiStep wordProblem:nil]);
}
- (void)testPreparationUsesNeutralCompleteInventoryAndBlankOptionalInput {
    [self open:899 second:9 operation:@"÷"];
    [self.controller selectActionIndex:14 play:NO];
    XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourcePreparation);
    [self assertSnapshot:self.plan.actions[15].before];
    XCTAssertNil(self.board.action); XCTAssertNil(self.board.scene); XCTAssertNil(self.board.selectionID);
    XCTAssertTrue(self.board.displayingFullSnapshot);
    UITextField *field = [self.controller valueForKey:@"proposalField"];
    XCTAssertEqualObjects(field.text, @""); XCTAssertNil([self.controller valueForKey:@"submittedProposal"]);
    XCTAssertEqualObjects(self.presentation.snapshot.pool.counts, (@[@0, @89, @0]));
    NSDictionary<NSNumber *, UIView *> *units = [self.board valueForKey:@"unitViews"];
    XCTAssertEqual(units.count, 98u, @"The complete source contains all 89 pool tens and nine original ones.");
    for (NSUInteger identifier = 9; identifier <= 17; identifier++) {
        UIView *unit = units[@(identifier)];
        XCTAssertNotNil(unit); XCTAssertEqualObjects([unit valueForKey:@"owner"], @"pool");
        XCTAssertFalse([unit.accessibilityLabel containsString:@"正在移動"]);
    }
    NSDictionary *labels = [self.board valueForKey:@"labels"];
    XCTAssertNil(labels[@"context"]); XCTAssertNil(labels[@"instruction"]);
    for (UILabel *cell in self.written.answerCellLabels) XCTAssertEqualObjects(cell.text, @"");
    XCTAssertEqual(self.written.snapshot.visibleDivisionRows.count, 1u); XCTAssertNil(self.written.snapshot.visibleRemainder);
    UIButton *observe = [self.controller valueForKey:@"nextButton"], *result = [self.controller valueForKey:@"resultButton"];
    XCTAssertTrue(observe.enabled); XCTAssertTrue(result.enabled);
    XCTAssertEqualObjects(observe.currentTitle, @"看第一個動作"); XCTAssertEqualObjects(result.currentTitle, @"直接看這一步結果");
}
- (void)testPredictionClosesAtomicallyBeforeAnyFirstActionBindingAndRejectsStaleSubmission {
    [self open:899 second:9 operation:@"÷"]; [self.controller selectActionIndex:14 play:NO];
    MTPPreparationKey *key = self.presentation.preparationKey;
    [self.controller submitProposalText:@"8" key:key];
    UILabel *feedback = [self.controller valueForKey:@"feedbackLabel"];
    XCTAssertTrue([feedback.text containsString:@"72 個十"]); XCTAssertTrue([feedback.text containsString:@"17 個十"]);
    [self assertSnapshot:key.anchor];
    UIButton *oldSubmit = [self.controller valueForKey:@"submitProposalButton"];
    UITextField *oldField = [self.controller valueForKey:@"proposalField"];
    [self.board removeFromSuperview];
    MTPBoundaryObservingBoard *observing = [[MTPBoundaryObservingBoard alloc] initWithFrame:CGRectZero];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"]; [scroll addSubview:observing];
    [self.controller setValue:observing forKey:@"board"];
    __block NSUInteger boundaryCount = 0;
    __weak typeof(self) weakSelf = self;
    observing.willConfigureAction = ^{
        boundaryCount++; [weakSelf assertNoPrediction];
        XCTAssertNil(oldField.superview.superview, @"The old card is detached before selected participants exist.");
        XCTAssertNil(feedback.text.length ? feedback.text : nil);
    };
    [self.controller observeFirstAction]; [self awaitExplicitPaintAdmission];
    XCTAssertEqual(boundaryCount, 1u); XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseActionSelection);
    XCTAssertEqual(self.presentation.actionIndex, 15); [self assertNoPrediction];
    [self.controller cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    [self assertSnapshot:self.plan.actions[15].after];
    XCTAssertEqualObjects(self.board.snapshot.pool.counts, (@[@0, @80, @0]));
    [self.controller submitProposalText:@"10" key:key]; [oldSubmit sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self assertNoPrediction]; [self assertSnapshot:self.plan.actions[15].after];
}
- (void)testBlankInvalidAndBoundaryInputsKeepBothObservationExitsAvailable {
    [self open:899 second:9 operation:@"÷"]; [self.controller selectActionIndex:14 play:NO];
    MTPPreparationKey *key = self.presentation.preparationKey;
    for (NSString *input in @[@"", @"-1", @"1000", @"0", @"999", @"10", @"8"]) {
        [self.controller submitProposalText:input key:key];
        XCTAssertTrue(((UIButton *)[self.controller valueForKey:@"nextButton"]).enabled);
        XCTAssertTrue(((UIButton *)[self.controller valueForKey:@"resultButton"]).enabled);
        [self assertSnapshot:key.anchor];
        XCTAssertNil(self.board.action); XCTAssertNil(self.board.scene);
    }
    [self.controller inspectSourceResult];
    [self assertNoPrediction]; XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourceInspection);
    [self assertSnapshot:self.plan.actions[23].after];
    XCTAssertNil(self.board.action); XCTAssertNil(self.board.scene);
    XCTAssertEqual(self.written.snapshot.visibleDivisionRows.count, 1u);
    for (UILabel *cell in self.written.answerCellLabels) XCTAssertEqualObjects(cell.text, @"");
    XCTAssertNil(self.written.snapshot.visibleRemainder);
}
- (void)testMultiplicationFeedbackDirectResultAndReplayDoNotReopenPrediction {
    [self open:99 second:9 operation:@"×"]; [self.controller selectActionIndex:20 play:NO];
    MTPPreparationKey *key = self.presentation.preparationKey;
    for (NSString *input in @[@"81", @"153", @"89"]) {
        [self.controller submitProposalText:input key:key];
        NSString *feedback = ((UILabel *)[self.controller valueForKey:@"feedbackLabel"]).text;
        if ([input isEqual:@"81"]) XCTAssertTrue([feedback containsString:@"原來已有 8 個十"]);
        if ([input isEqual:@"153"]) XCTAssertTrue([feedback containsString:@"只在累積區一次"]);
        XCTAssertFalse([feedback containsString:@"891"]); [self assertSnapshot:key.anchor];
    }
    [self.controller inspectSourceResult];
    [self assertSnapshot:self.plan.actions[29].after];
    XCTAssertEqualObjects(self.board.snapshot.accumulator.counts, (@[@0, @89, @1]));
    XCTAssertEqualObjects(self.written.answerCellLabels[1].text, @""); XCTAssertEqualObjects(self.written.answerCellLabels[0].text, @"");
    XCTAssertEqualObjects(((UIButton *)[self.controller valueForKey:@"replayButton"]).currentTitle, @"從第一個動作看");
    [self.controller showBefore]; [self assertSnapshot:self.plan.actions[21].before]; [self assertNoPrediction];
    [self.controller showAfter]; [self assertSnapshot:self.plan.actions[29].after];
    [self.controller replay]; [self awaitExplicitPaintAdmission]; [self.controller cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    XCTAssertEqual(self.presentation.actionIndex, 21); [self assertSnapshot:self.plan.actions[21].after];
    XCTAssertEqualObjects(self.board.snapshot.accumulator.counts, (@[@0, @17, @1])); [self assertNoPrediction];
    [self.controller replay]; [self awaitExplicitPaintAdmission]; [self.controller cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    XCTAssertEqual(self.presentation.actionIndex, 21); [self assertSnapshot:self.plan.actions[21].after]; [self assertNoPrediction];
}
- (void)testReopeningAfterAWriteRestoresAllOriginalMetadataAndReturnsStatically {
    [self open:899 second:9 operation:@"÷"]; [self.controller selectActionIndex:24 play:NO];
    MultiplicativeTeachingActionSnapshot *written = self.plan.actions[24].after;
    [self assertSnapshot:written]; XCTAssertEqualObjects(self.written.answerCellLabels[1].text, @"9");
    XCTAssertEqual(written.visibleDivisionRows.count, 2u);
    [self.controller reopenQuestion];
    XCTAssertTrue(self.presentation.review); [self assertSnapshot:self.plan.actions[15].before];
    XCTAssertEqual(self.presentation.snapshot.visibleDivisionRows.count, 1u);
    XCTAssertEqualObjects(self.written.answerCellLabels[1].text, @"");
    XCTAssertEqualObjects(((UITextField *)[self.controller valueForKey:@"proposalField"]).text, @"");
    XCTAssertEqualObjects(self.presentation.snapshot.completedColumns, [NSIndexSet indexSetWithIndex:0]);
    XCTAssertEqual(self.presentation.snapshot.recipients.count, 9u);
    for (MultiplicativeTeachingQuantity *recipient in self.presentation.snapshot.recipients) XCTAssertEqual(recipient.weightedValue, 0);
    [self.controller returnToSavedSelection]; [self assertNoPrediction]; [self assertSnapshot:written];
    XCTAssertEqual(self.presentation.actionIndex, 24); XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateStatic);
    XCTAssertEqualObjects(self.written.answerCellLabels[1].text, @"9"); XCTAssertEqual(self.written.snapshot.visibleDivisionRows.count, 2u);
}
- (void)testBackCrossesBoundedActionsThenOriginalPreparationWithoutReverseMotion {
    [self open:899 second:9 operation:@"÷"]; [self.controller selectActionIndex:16 play:NO];
    [self.controller previous]; XCTAssertEqual(self.presentation.actionIndex, 15); [self assertSnapshot:self.plan.actions[15].after];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateStatic); [self assertNoPrediction];
    [self.controller previous]; XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourcePreparation);
    XCTAssertTrue(self.presentation.review); [self assertSnapshot:self.plan.actions[15].before];
    [self.controller previous]; XCTAssertEqual(self.presentation.actionIndex, 13); [self assertSnapshot:self.plan.actions[13].after];
    [self assertNoPrediction]; XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self.controller next]; XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourcePreparation);
    [self assertSnapshot:self.plan.actions[15].before];
}
- (void)testFreshReplayAndStaleCallbacksKeepWrittenWorkAtTheRealBoardEndpoint {
    [self open:1 second:1 operation:@"×"];
    XCTAssertTrue(ChildUI.motionEnabled, @"The ordinary-motion acceptance fixture must have real system Reduce Motion off.");
    [self.controller selectActionIndex:2 play:NO];
    NSString *oldSelection = self.presentation.selectionID;
    [self.controller replay]; [self awaitExplicitPaintAdmission];
    XCTAssertNotEqualObjects(self.presentation.selectionID, oldSelection);
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning, @"A complete one-unit action must fit the ordinary foreground fixture.");
    [self assertSnapshot:self.plan.actions[2].before]; [self assertNoPrediction];
    void (^oldCallback)(MTPPlaceValuePlaybackState) = self.board.playbackStateDidChange;
    [self.controller cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    [self assertSnapshot:self.plan.actions[2].after]; XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateInterrupted);
    [self.controller selectActionIndex:3 play:NO];
    MultiplicativeTeachingActionSnapshot *later = self.presentation.snapshot;
    if (oldCallback) oldCallback(MTPPlaceValuePlaybackStateCompleted);
    [self assertSnapshot:later]; XCTAssertEqual(self.presentation.actionIndex, 3);
    [self.controller restart];
    if (oldCallback) oldCallback(MTPPlaceValuePlaybackStateCompleted);
    [self assertSnapshot:self.plan.actions[0].after]; XCTAssertEqual(self.presentation.actionIndex, 0);
}
- (void)testLayoutScrollAndBackgroundCancellationNeverResumeOrForceScroll {
    [self open:1 second:1 operation:@"×"]; [self.controller selectActionIndex:2 play:YES]; [self awaitExplicitPaintAdmission];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self resize:CGSizeMake(320, 300)];
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning); [self assertSnapshot:self.plan.actions[2].after];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGPoint offset = scroll.contentOffset;
    [self resize:self.window.bounds.size];
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.x, offset.x, .01);
    // UIKit may clamp an offset after a size change; the controller must not frame the action automatically.
    [self.controller showBefore]; [self assertSnapshot:self.plan.actions[2].before];
    offset = scroll.contentOffset;
    [self.controller.view setNeedsLayout]; [self.controller.view layoutIfNeeded];
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, offset)); [self assertSnapshot:self.plan.actions[2].before];
    [self.controller replay]; [self awaitExplicitPaintAdmission]; XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self.controller scrollViewWillBeginDragging:scroll];
    [self assertSnapshot:self.plan.actions[2].after]; XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self.controller replay]; [self awaitExplicitPaintAdmission]; XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self.controller applicationInterrupted:nil];
    [self assertSnapshot:self.plan.actions[2].after]; XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateInterrupted);
    [self.controller.view setNeedsLayout]; [self.controller.view layoutIfNeeded];
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
}
- (void)testTypedWriteHighlightsAndFramesOnlyTheCurrentlyRevealedRelation {
    [self open:899 second:9 operation:@"÷"]; [self.controller selectActionIndex:24 play:YES];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateStationary);
    [self assertSnapshot:self.plan.actions[24].after];
    XCTAssertEqualObjects(self.written.answerCellLabels[1].text, @"9");
    XCTAssertGreaterThan(self.written.answerCellLabels[1].layer.borderWidth, 0);
    CGRect row = [self.written latestWorkRowRectForColumn:1];
    XCTAssertFalse(CGRectIsNull(row));
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGRect viewport = UIEdgeInsetsInsetRect(scroll.bounds, UIEdgeInsetsMake(8, 0, 8, 0));
    XCTAssertTrue(CGRectContainsRect(viewport, [self.written convertRect:row toView:scroll]),
        @"The newly revealed tens relation must not be left below older written rows.");
    NSString *notice = ((UILabel *)[self.controller valueForKey:@"noticeLabel"]).text;
    XCTAssertTrue([notice containsString:@"靜態"]); XCTAssertTrue([notice containsString:@"沒有播放動畫"]);
    [self.controller showBefore];
    [self assertSnapshot:self.plan.actions[24].before];
    XCTAssertEqualObjects(self.written.answerCellLabels[1].text, @"");
    XCTAssertGreaterThan(self.written.answerCellLabels[1].layer.borderWidth, 0);
    XCTAssertTrue(CGRectIsNull([self.written latestWorkRowRectForColumn:1]),
        @"Before retains the existing H row and must not invent or highlight the future T row.");
    CGRect cell = [self.written convertRect:self.written.answerCellLabels[1].frame toView:scroll];
    XCTAssertTrue(CGRectContainsRect(UIEdgeInsetsInsetRect(scroll.bounds, UIEdgeInsetsMake(8, 0, 8, 0)), cell));
    [self.controller showAfter];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateStatic);
    [self assertSnapshot:self.plan.actions[24].after];
}
- (void)testExplicitObserveWaitsForKeyboardDisappearanceAndAnInterruptedRequestCannotRestart {
    [self open:1 second:1 operation:@"×"]; [self.controller selectActionIndex:1 play:NO];
    CGFloat occupiedTop = self.controller.view.bounds.size.height - 240;
    [self.controller setValue:@(occupiedTop) forKey:@"keyboardTop"];
    [self.controller setValue:@YES forKey:@"keyboardDismissalInProgress"];
    [self.controller observeFirstAction];
    XCTAssertEqual(self.presentation.actionIndex, 2); [self assertNoPrediction];
    [self assertSnapshot:self.plan.actions[2].before];
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    XCTAssertNotNil([self.controller valueForKey:@"pendingKeyboardPlay"]);
    NSNotification *willHide = [NSNotification notificationWithName:UIKeyboardWillHideNotification object:nil
        userInfo:@{UIKeyboardFrameEndUserInfoKey:[NSValue valueWithCGRect:CGRectMake(0, self.controller.view.bounds.size.height, 320, 240)]}];
    [self.controller keyboardChanged:willHide];
    XCTAssertEqualWithAccuracy([[self.controller valueForKey:@"keyboardTop"] doubleValue], occupiedTop, .01);
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self.controller keyboardDidHide:[NSNotification notificationWithName:UIKeyboardDidHideNotification object:nil]];
    XCTAssertNil([self.controller valueForKey:@"pendingKeyboardPlay"]);
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    XCTAssertNotNil([self.controller valueForKey:@"pendingPaintPlay"]);
    [self awaitExplicitPaintAdmission];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self assertSnapshot:self.plan.actions[2].before];
    [self.controller cancelPlayback:MTPPlaceValueInterruptionReasonCancelled];
    [self.controller setValue:@(occupiedTop) forKey:@"keyboardTop"];
    [self.controller setValue:@YES forKey:@"keyboardDismissalInProgress"];
    [self.controller replay]; [self awaitExplicitPaintAdmission];
    XCTAssertNotNil([self.controller valueForKey:@"pendingKeyboardPlay"]);
    [self.controller previous];
    XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourcePreparation);
    [self.controller keyboardDidHide:[NSNotification notificationWithName:UIKeyboardDidHideNotification object:nil]];
    XCTAssertNil([self.controller valueForKey:@"pendingKeyboardPlay"]);
    XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourcePreparation);
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self assertSnapshot:self.plan.actions[2].before];
}
- (void)testSubmittedProposalCannotAdmitDuringHideOrEscapeAChangeDetectedByFinalLayout {
    [self open:1 second:1 operation:@"×"]; [self.controller selectActionIndex:1 play:NO];
    [self.controller setValue:@(self.controller.view.bounds.size.height - 240) forKey:@"keyboardTop"];
    [self.controller submitProposalText:@"0" key:self.presentation.preparationKey];
    XCTAssertFalse(((UITextField *)[self.controller valueForKey:@"proposalField"]).isFirstResponder);
    [self.controller keyboardChanged:[NSNotification notificationWithName:UIKeyboardWillHideNotification object:nil
        userInfo:@{UIKeyboardFrameEndUserInfoKey:[NSValue valueWithCGRect:CGRectMake(0, self.controller.view.bounds.size.height, 320, 240)]}]];
    [self.controller observeFirstAction];
    XCTAssertNotNil([self.controller valueForKey:@"pendingKeyboardPlay"]);
    XCTAssertNil([self.controller valueForKey:@"pendingPaintPlay"]);
    [self assertSnapshot:self.plan.actions[2].before];
    CGRect frame = self.controller.view.frame; frame.size.width -= 1; self.controller.view.frame = frame;
    // The first layout that sees this size change is inside DidHide itself.
    [self.controller keyboardDidHide:[NSNotification notificationWithName:UIKeyboardDidHideNotification object:nil]];
    XCTAssertNil([self.controller valueForKey:@"pendingKeyboardPlay"]);
    XCTAssertNil([self.controller valueForKey:@"pendingPaintPlay"]);
    XCTAssertNil([self.controller valueForKey:@"playbackAdmissionLink"]);
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self assertSnapshot:self.plan.actions[2].before];
}
- (void)testOneFrameAdmissionIsCancelledBeforeItsFirstTickAndNeverReplaysAStaleSelection {
    [self open:1 second:1 operation:@"×"]; [self.controller selectActionIndex:2 play:YES];
    CADisplayLink *oldLink = [self.controller valueForKey:@"playbackAdmissionLink"];
    XCTAssertNotNil(oldLink); [self assertSnapshot:self.plan.actions[2].before];
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self.controller previous];
    XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourcePreparation);
    XCTAssertNil([self.controller valueForKey:@"playbackAdmissionLink"]);
    [self.controller admitPreparedPlayback:oldLink];
    XCTAssertEqual(self.presentation.phase, MTPPresentationPhaseSourcePreparation);
    [self assertSnapshot:self.plan.actions[2].before];
    [self.controller selectActionIndex:2 play:YES];
    oldLink = [self.controller valueForKey:@"playbackAdmissionLink"];
    XCTAssertNotNil(oldLink);
    [self.controller scrollViewWillBeginDragging:[self.controller valueForKey:@"scroll"]];
    [self.controller admitPreparedPlayback:oldLink];
    [self assertSnapshot:self.plan.actions[2].before];
    XCTAssertNil([self.controller valueForKey:@"playbackAdmissionLink"]);
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
}
- (void)testMaximumTextKeepsTypedWriteEmphasisAndFocusesTheCurrentReadableCaption {
    [self open:899 second:9 operation:@"÷"]; [self.controller selectActionIndex:24 play:YES];
    CGFloat normalFont = self.written.answerCellLabels[1].font.pointSize;
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self resize:CGSizeMake(320, 568)];
    XCTAssertGreaterThan(self.written.answerCellLabels[1].layer.borderWidth, 0);
    XCTAssertGreaterThan(self.written.answerCellLabels[1].font.pointSize, normalFont);
    [self.controller replay];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateStationary);
    [self assertSnapshot:self.plan.actions[24].after];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGRect caption = [self.written latestWorkCaptionRectForColumn:1];
    XCTAssertFalse(CGRectIsNull(caption));
    CGRect inScroll = [self.written convertRect:caption toView:scroll];
    XCTAssertTrue(CGRectIntersectsRect(scroll.bounds, inScroll));
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(inScroll), CGRectGetMinY(scroll.bounds));
    XCTAssertFalse(self.written.answerCellLabels[1].adjustsFontSizeToFitWidth);
    XCTAssertGreaterThan(self.written.minimumReadableWidth, scroll.bounds.size.width - 32);
    XCTAssertEqual(self.written.snapshot.visibleDivisionRows.count, 2u);
    XCTAssertNil(self.written.snapshot.visibleRemainder);
}
- (NSDictionary *)progressDefaults {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSDictionary *values = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (NSString *key in values) if ([key hasPrefix:@"practice."] || [key hasPrefix:@"lesson."] || [key hasPrefix:@"concept."])
        result[key] = values[key];
    return result;
}
- (void)testTeachingInspectionAndProposalNeverSubmitPracticeProgress {
    NSDictionary *before = self.progressDefaults;
    [self open:99 second:9 operation:@"×"]; [self.controller selectActionIndex:20 play:NO];
    [self.controller submitProposalText:@"89" key:self.presentation.preparationKey];
    [self.controller inspectSourceResult]; [self.controller showBefore]; [self.controller showAfter];
    [self.controller reopenQuestion]; [self.controller returnToSavedSelection]; [self.controller restart];
    __block NSUInteger returned = 0;
    self.controller.returnToQuestion = ^{ returned++; };
    [self.controller close];
    XCTAssertEqual(returned, 1u); XCTAssertEqualObjects(self.progressDefaults, before);
}
- (void)testAccessibilityTextUsesFullSizeScrollableControlsAndHonestStaticRecovery {
    [self open:899 second:9 operation:@"÷"]; [self.controller selectActionIndex:15 play:NO];
    CGFloat baseFont = ((UIButton *)[self.controller valueForKey:@"nextButton"]).titleLabel.font.pointSize;
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self resize:CGSizeMake(320, 568)];
    NSArray<UIButton *> *buttons = [self.controller valueForKey:@"allControlButtons"];
    UIScrollView *controls = [self.controller valueForKey:@"controlsScroll"];
    for (UIButton *button in buttons) if (!button.hidden) {
        XCTAssertGreaterThanOrEqual(button.bounds.size.height, 44);
        XCTAssertGreaterThanOrEqual(button.bounds.size.width, 44);
        XCTAssertFalse(button.titleLabel.adjustsFontSizeToFitWidth);
        XCTAssertGreaterThan(button.titleLabel.font.pointSize, baseFont);
        XCTAssertLessThanOrEqual(CGRectGetMaxY(button.frame), controls.contentSize.height);
    }
    XCTAssertGreaterThan(controls.contentSize.height, controls.bounds.size.height);
    [self.controller replay]; [self awaitExplicitPaintAdmission];
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateCompleted);
    [self assertSnapshot:self.plan.actions[15].after]; [self assertNoPrediction];
    XCTAssertGreaterThan(((UILabel *)[self.controller valueForKey:@"noticeLabel"]).text.length, 0u);
    [self.controller showBefore]; [self assertSnapshot:self.plan.actions[15].before];
    [self.controller toggleWritten];
    XCTAssertGreaterThan(self.written.minimumReadableWidth, 288);
    XCTAssertFalse(self.written.answerCellLabels.firstObject.adjustsFontSizeToFitWidth);
    XCTAssertNotEqual(self.board.playbackState, MTPPlaceValuePlaybackStateRunning);
    [self assertSnapshot:self.plan.actions[15].before];
}
@end
