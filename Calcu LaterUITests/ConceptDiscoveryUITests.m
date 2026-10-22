#import <XCTest/XCTest.h>
#import <math.h>

/// Separate acceptance flows. Not included in an existing CI selection by this change.
@interface ConceptDiscoveryUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end
@implementation ConceptDiscoveryUITests
- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    self.app = [[XCUIApplication alloc] init];
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)", @"-AppleLocale", @"zh_TW", @"-soundEffectsEnabled", @"NO"];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.lessons"] waitForExistenceWithTimeout:10]);
}
- (void)tearDown {
    if (self.testRun.failureCount) [self capture:@"concept-discovery-failure"];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    [super tearDown];
}
- (void)capture:(NSString *)name {
    XCTAssertEqual(self.app.state, XCUIApplicationStateRunningForeground);
    XCTAttachment *image = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    image.name = name;
    image.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:image];
    XCTAttachment *tree = [XCTAttachment attachmentWithString:self.app.debugDescription];
    tree.name = [name stringByAppendingString:@"-hierarchy"];
    tree.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:tree];
}
- (void)reveal:(XCUIElement *)element inScroll:(XCUIElement *)scroll {
    // Offscreen collection cells may not exist until they have been scrolled into view.
    for (NSUInteger attempt = 0; attempt < 10 && !(element.exists && element.hittable); attempt++) {
        CGRect viewport = scroll.frame;
        XCTAssertTrue(isfinite(viewport.origin.y) && isfinite(viewport.size.height) && viewport.size.height > 44);
        CGRect target = element.exists ? element.frame : CGRectNull;
        BOOL above = !CGRectIsNull(target) && isfinite(target.origin.y) && target.size.height > 0
            && CGRectGetMinY(target) < CGRectGetMinY(viewport);
        // Small controlled drags can reverse after overshoot, unlike repeated flings.
        XCUICoordinate *start = [scroll coordinateWithNormalizedOffset:CGVectorMake(0.5, above ? 0.35 : 0.75)];
        XCUICoordinate *end = [scroll coordinateWithNormalizedOffset:CGVectorMake(0.5, above ? 0.75 : 0.35)];
        [start pressForDuration:0.05 thenDragToCoordinate:end
            withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
    }
    XCTAssertTrue(element.exists);
    XCTAssertTrue(element.hittable, @"Expected control must be reachable with bounded scrolling: %@", element.identifier);
}
- (void)openPath:(NSString *)pathID {
    XCUIElement *home = self.app.buttons[@"home.lessons"];
    [self reveal:home inScroll:self.app.scrollViews.firstMatch];
    [home tap];
    XCUIElement *collection = self.app.collectionViews[@"lessons.catalog"];
    XCTAssertTrue([collection waitForExistenceWithTimeout:5]);
    XCUIElement *shortcut = self.app.buttons[@"lessons.explore"];
    [self reveal:shortcut inScroll:collection];
    [shortcut tap];
    NSString *identifier = [@"lessons.concept." stringByAppendingString:pathID];
    XCUIElement *path = collection.cells[identifier];
    [self reveal:path inScroll:collection];
    [path tap];
    XCTAssertTrue([self.app.staticTexts[@"concept.equation"] waitForExistenceWithTimeout:5]);
    XCTAssertFalse(self.app.buttons[@"answer.0"].exists, @"Discovery does not enter random scored practice.");
}
- (void)tapConcept:(NSString *)identifier {
    XCUIElement *button = self.app.buttons[identifier];
    [self revealConceptButton:button];
    [button tap];
}
- (void)revealConceptButton:(XCUIElement *)button {
    XCUIElement *scroll = self.app.scrollViews[@"concept.content"];
    // A six-point sliver can be "hittable" while XCTest chooses a point at the
    // scroll's clipping edge. Expose the actual complete button before tapping;
    // navigation must not masquerade as a failed changed-question contract.
    CGRect viewport = CGRectZero;
    CGRect target = CGRectZero;
    for (NSUInteger attempt = 0; attempt <= 10; attempt++) {
        CGRect scrollFrame = [self checkedFrame:scroll];
        viewport = CGRectIntersection(scrollFrame, self.app.windows.firstMatch.frame);
        XCTAssertFalse(CGRectIsNull(viewport));
        XCTAssertGreaterThan(viewport.size.width, 44);
        XCTAssertGreaterThan(viewport.size.height, 44);
        CGRect visibleBounds = CGRectInset(viewport, 8, 8);
        BOOL hasTarget = button.exists;
        target = hasTarget ? [self checkedFrame:button] : CGRectZero;
        if (hasTarget) {
            XCTAssertLessThanOrEqual(target.size.width, visibleBounds.size.width);
            XCTAssertLessThanOrEqual(target.size.height, visibleBounds.size.height);
            if (CGRectContainsRect(visibleBounds, target)) {
                XCTAssertTrue(button.hittable, @"The fully visible concept button must be tappable.");
                return;
            }
        }
        if (attempt == 10) break;
        CGFloat distance = hasTarget ? CGRectGetMidY(target) - CGRectGetMidY(viewport)
                                     : viewport.size.height * 0.4;
        CGFloat travel = MIN(MAX(fabs(distance), 24), viewport.size.height * 0.4);
        CGFloat startY = CGRectGetMinY(viewport) + viewport.size.height * (distance > 0 ? 0.75 : 0.35);
        CGFloat endY = startY + (distance > 0 ? -travel : travel);
        XCUICoordinate *origin = [scroll coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
        XCUICoordinate *start = [origin coordinateWithOffset:CGVectorMake(CGRectGetMidX(viewport) - CGRectGetMinX(scrollFrame),
                                                                       startY - CGRectGetMinY(scrollFrame))];
        XCUICoordinate *end = [origin coordinateWithOffset:CGVectorMake(CGRectGetMidX(viewport) - CGRectGetMinX(scrollFrame),
                                                                     endY - CGRectGetMinY(scrollFrame))];
        [start pressForDuration:0.05 thenDragToCoordinate:end
            withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
        NSString *observation = [NSString stringWithFormat:@"attempt=%lu identifier=%@ viewport=%@ targetBefore=%@ targetAfter=%@ requested=%.3f travel=%.3f startY=%.3f endY=%.3f hittable=%d",
            (unsigned long)attempt + 1, button.identifier, NSStringFromCGRect(viewport), NSStringFromCGRect(target),
            NSStringFromCGRect(button.exists ? button.frame : CGRectZero), distance, travel, startY, endY, button.hittable];
        XCTAttachment *trace = [XCTAttachment attachmentWithString:observation];
        trace.name = @"concept-button-reveal-scroll";
        trace.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:trace];
    }
    XCTAssertTrue(button.exists, @"Missing concept button: %@", button.identifier);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, 8, 8), target),
                  @"The complete concept button must be reachable within ten drags: %@ in %@", NSStringFromCGRect(target), NSStringFromCGRect(viewport));
    XCTAssertTrue(button.hittable, @"The fully visible concept button must be tappable.");
}
- (XCUIElement *)element:(NSString *)identifier {
    return [self.app descendantsMatchingType:XCUIElementTypeAny][identifier];
}
- (NSString *)boardValue:(NSString *)identifier {
    XCUIElement *board = [self element:identifier];
    XCTAssertTrue([board waitForExistenceWithTimeout:5]);
    XCTAssertEqual([[self.app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:identifier].count, 1u,
        @"The inactive overview must not compete with the actual visible teaching element.");
    return [board.value description];
}
- (void)waitForBoard:(NSString *)identifier fragments:(NSArray<NSString *> *)fragments {
    NSMutableArray<NSPredicate *> *conditions = [NSMutableArray array];
    for (NSString *fragment in fragments) {
        [conditions addObject:[NSPredicate predicateWithFormat:@"value CONTAINS %@", fragment]];
    }
    // Quantity evidence only. It cannot establish completed playback: an
    // interrupted renderer can also settle on these same numeric counts.
    [conditions addObject:[NSPredicate predicateWithFormat:@"NOT (value CONTAINS %@)", @"正在移動"]];
    NSPredicate *settled = [NSCompoundPredicate andPredicateWithSubpredicates:conditions];
    XCTNSPredicateExpectation *ready = [[XCTNSPredicateExpectation alloc] initWithPredicate:settled object:[self element:identifier]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[ready] timeout:3], XCTWaiterResultCompleted);
}
- (CGRect)checkedFrame:(XCUIElement *)element {
    XCTAssertTrue(element.exists);
    CGRect frame = element.frame;
    XCTAssertTrue(isfinite(frame.origin.x) && isfinite(frame.origin.y)
        && isfinite(frame.size.width) && isfinite(frame.size.height));
    XCTAssertGreaterThan(frame.size.width, 44.0);
    XCTAssertGreaterThan(frame.size.height, 44.0);
    return frame;
}
- (void)dragScroll:(XCUIElement *)scroll by:(CGFloat)distance {
    CGFloat height = [self checkedFrame:scroll].size.height;
    CGFloat travel = MIN(fabs(distance), height * 0.45);
    CGFloat startY = distance > 0 ? 0.75 : 0.25;
    CGFloat endY = startY + (distance > 0 ? -1 : 1) * travel / height;
    XCUICoordinate *start = [scroll coordinateWithNormalizedOffset:CGVectorMake(0.5, startY)];
    XCUICoordinate *end = [scroll coordinateWithNormalizedOffset:CGVectorMake(0.5, endY)];
    [start pressForDuration:0.05 thenDragToCoordinate:end
        withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
}
- (void)assertOverviewSlice:(XCUIElement *)board visibleIn:(XCUIElement *)scroll {
    CGRect frame = [self checkedFrame:board], viewport = [self checkedFrame:scroll];
    CGRect visible = CGRectIntersection(frame, viewport);
    XCTAssertFalse(CGRectIsNull(visible));
    XCTAssertGreaterThan(visible.size.height, 44.0);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(frame), CGRectGetMinX(viewport) - 1);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(frame), CGRectGetMaxX(viewport) + 1);
}
- (void)captureOverview:(NSString *)identifier inScroll:(NSString *)scrollID name:(NSString *)name {
    XCUIElement *board = [self element:identifier], *scroll = self.app.scrollViews[scrollID];
    XCTAssertFalse([[self boardValue:identifier] containsString:@"播放狀態："],
        @"Never use an inspection scroll to rescue a clipped first-play action.");
    // Static overview inspection only, after any tested action has completed.
    // Overlapping captures retain all groups and the common pool. They are not
    // evidence of visible motion, which has a separate full-region/lifecycle gate.
    for (NSUInteger attempt = 0; attempt < 8; attempt++) {
        CGRect frame = [self checkedFrame:board], viewport = [self checkedFrame:scroll];
        CGFloat delta = CGRectGetMinY(frame) - CGRectGetMinY(viewport) - 8;
        if (fabs(delta) <= 12 || CGRectContainsRect(viewport, frame)) break;
        [self dragScroll:scroll by:delta];
        if (fabs(board.frame.origin.y - frame.origin.y) < 1) break;
    }
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(board.frame), CGRectGetMinY(scroll.frame) - 12);
    [self assertOverviewSlice:board visibleIn:scroll];
    [self capture:[name stringByAppendingString:@"-top"]];
    for (NSUInteger slice = 1; slice <= 8; slice++) {
        CGFloat remaining = CGRectGetMaxY(board.frame) - CGRectGetMaxY(scroll.frame);
        if (remaining <= 12) break;
        CGRect before = board.frame;
        [self dragScroll:scroll by:MIN(remaining + 8, scroll.frame.size.height * 0.4)];
        XCTAssertLessThan(board.frame.origin.y, before.origin.y - 1);
        XCTAssertLessThanOrEqual(before.origin.y - board.frame.origin.y, scroll.frame.size.height - 24,
            @"Successive captured regions must overlap, not skip a transformation or group.");
        [self assertOverviewSlice:board visibleIn:scroll];
        [self capture:[NSString stringWithFormat:@"%@-slice-%lu", name, (unsigned long)slice]];
    }
    XCTAssertLessThanOrEqual(CGRectGetMaxY(board.frame), CGRectGetMaxY(scroll.frame) + 12,
        @"Static inspection must reach the final groups and common remainder.");
}
- (void)assertAction:(NSString *)identifier fullyVisibleIn:(NSString *)scrollID {
    XCUIElement *action = [self element:identifier];
    XCUIElement *scroll = self.app.scrollViews[scrollID];
    CGRect frame = [self checkedFrame:action];
    CGRect viewport = CGRectIntersection([self checkedFrame:scroll], self.app.windows.firstMatch.frame);
    XCTAssertFalse(CGRectIsNull(viewport));
    XCTAssertGreaterThan(viewport.size.height, 44);
    XCTAssertGreaterThan(frame.size.height, 100);
    XCTAssertEqual([[self.app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:identifier].count, 1u);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -1, -1), frame),
        @"The whole source, target, route and count captions must fit: %@ in %@", NSStringFromCGRect(frame), NSStringFromCGRect(viewport));
    if ([identifier isEqualToString:@"verticalTeachingExchange"]) {
        XCTAssertGreaterThanOrEqual(CGRectGetMinY(frame), CGRectGetMinY(viewport) + 7);
        XCTAssertLessThanOrEqual(CGRectGetMaxY(frame), CGRectGetMaxY(viewport) - 7);
    }
}
- (void)assertVerticalExchangeNaturallyCompletes:(NSString *)name {
    // No scroll, Replay, rotation or cancellation may repair the first-play
    // position before this complete causal-region assertion.
    [self assertAction:@"verticalTeachingExchange" fullyVisibleIn:@"teaching.content"];
    [self capture:[name stringByAppendingString:@"-before-helper"]];
    NSPredicate *completed = [NSPredicate predicateWithFormat:@"value CONTAINS %@", @"動態已播放完成"];
    XCTNSPredicateExpectation *ready = [[XCTNSPredicateExpectation alloc] initWithPredicate:completed object:[self element:@"verticalTeachingExchange"]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[ready] timeout:3], XCTWaiterResultCompleted);
    // Actual system Reduce Motion has a separate scenario. A static/paused
    // snapshot must not satisfy this motion acceptance test.
    [self assertAction:@"verticalTeachingExchange" fullyVisibleIn:@"teaching.content"];
    [self capture:[name stringByAppendingString:@"-natural-end"]];
}
- (void)replayVerticalExchange:(NSArray<NSString *> *)fragments name:(NSString *)name {
    NSString *value = [self boardValue:@"verticalTeachingBoard"];
    NSString *progress = self.app.staticTexts[@"teaching.progress"].label;
    XCUIElement *inspect = self.app.buttons[@"teaching.focus"];
    XCTAssertTrue(inspect.hittable);
    [inspect tap]; // Deliberately inspect written work before Replay recovers the action.
    [self capture:[name stringByAppendingString:@"-written-inspection"]];
    [self.app.buttons[@"teaching.replay"] tap];
    [self assertVerticalExchangeNaturallyCompletes:name];
    [self waitForBoard:@"verticalTeachingBoard" fragments:fragments];
    XCTAssertEqualObjects([self boardValue:@"verticalTeachingBoard"], value);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, progress);
}
- (void)waitForGroupingNaturalCompletionWithTransfers:(NSUInteger)transfers {
    XCTAssertGreaterThan(transfers, 0u);
    // Renderer contract: .28 s lead + .82 s per serial transfer + .24 s tail.
    // The one-second allowance covers scheduling, not a replacement for evidence.
    NSTimeInterval duration = 0.28 + 0.82 * transfers + 0.24;
    NSPredicate *completed = [NSPredicate predicateWithFormat:@"value CONTAINS %@ AND value CONTAINS %@",
        @"播放狀態：completed", @"播放完成"];
    XCTNSPredicateExpectation *ready = [[XCTNSPredicateExpectation alloc] initWithPredicate:completed object:[self element:@"groupingTeachingBoard"]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[ready] timeout:duration + 1.0], XCTWaiterResultCompleted);
}
- (void)assertGroupingActionNaturallyCompletesWithTransfers:(NSUInteger)transfers name:(NSString *)name {
    [self assertAction:@"groupingTeachingBoard" fullyVisibleIn:@"grouping.content"];
    XCTAssertTrue([[self boardValue:@"groupingTeachingBoard"] containsString:@"播放狀態："],
        @"An overview snapshot is not the visible action renderer.");
    if (name) [self capture:[name stringByAppendingString:@"-before-helper"]];
    [self waitForGroupingNaturalCompletionWithTransfers:transfers];
    [self assertAction:@"groupingTeachingBoard" fullyVisibleIn:@"grouping.content"];
    if (name) [self capture:[name stringByAppendingString:@"-natural-end"]];
}
- (NSUInteger)completeSharingRound:(NSUInteger)round total:(NSUInteger)total recipients:(NSUInteger)recipients name:(NSString *)name {
    NSString *progress = self.app.staticTexts[@"grouping.progress"].label;
    NSString *full = [NSString stringWithFormat:@"第 %lu 輪 · 每位再拿 1 顆", (unsigned long)round];
    if ([[self boardValue:@"groupingTeachingBoard"] containsString:full]) {
        [self assertGroupingActionNaturallyCompletesWithTransfers:recipients name:name];
        XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
        XCTAssertEqualObjects(self.app.buttons[@"grouping.next"].label, @"下一小步");
        return recipients;
    }
    for (NSUInteger recipient = 1; recipient <= recipients; recipient++) {
        NSString *selection = [NSString stringWithFormat:@"第 %lu 輪 · 第 %lu / %lu 位", (unsigned long)round, (unsigned long)recipient, (unsigned long)recipients];
        XCTAssertTrue([[self boardValue:@"groupingTeachingBoard"] containsString:selection]);
        NSString *actionName = name ? [NSString stringWithFormat:@"%@-recipient-%lu", name, (unsigned long)recipient] : nil;
        [self assertGroupingActionNaturallyCompletesWithTransfers:1 name:actionName];
        NSMutableArray<NSString *> *counts = [NSMutableArray arrayWithObjects:@"答案還沒寫",
            [NSString stringWithFormat:@"待分的糖果：%lu 顆", (unsigned long)(total - recipients * (round - 1) - recipient)], nil];
        for (NSUInteger group = 1; group <= recipients; group++) {
            [counts addObject:[NSString stringWithFormat:@"第 %lu 個小朋友有 %lu 顆", (unsigned long)group, (unsigned long)(group <= recipient ? round : round - 1)]];
        }
        [self waitForBoard:@"groupingTeachingBoard" fragments:counts];
        XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress,
            @"Recipient choices refine this original round, never advance the original lesson.");
        XCTAssertEqualObjects(self.app.buttons[@"grouping.next"].label, recipient < recipients ? @"下一位" : @"下一小步");
        if (recipient < recipients) [self.app.buttons[@"grouping.next"] tap];
    }
    return 1; // Replay repeats only the deliberately selected final recipient.
}
- (void)replayGroupingActionWithTransfers:(NSUInteger)transfers fragments:(NSArray<NSString *> *)fragments name:(NSString *)name {
    NSString *value = [self boardValue:@"groupingTeachingBoard"];
    XCTAssertTrue([value containsString:@"播放狀態：completed"]);
    NSString *progress = self.app.staticTexts[@"grouping.progress"].label;
    XCUIElement *overview = self.app.buttons[@"grouping.viewMode"];
    XCTAssertTrue(overview.hittable);
    XCTAssertEqualObjects(overview.label, @"看全部");
    [overview tap];
    [self waitForBoard:@"groupingTeachingBoard" fragments:fragments];
    [self captureOverview:@"groupingTeachingBoard" inScroll:@"grouping.content" name:[name stringByAppendingString:@"-all-groups"]];
    [self.app.buttons[@"grouping.replay"] tap];
    [self assertGroupingActionNaturallyCompletesWithTransfers:transfers name:name];
    [self waitForBoard:@"groupingTeachingBoard" fragments:fragments];
    XCTAssertEqualObjects([self boardValue:@"groupingTeachingBoard"], value);
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    [self capture:name];
}
- (void)assertReturnedFromTeaching:(NSString *)nextIdentifier equation:(NSString *)equation {
    NSPredicate *gone = [NSPredicate predicateWithFormat:@"exists == NO"];
    XCTNSPredicateExpectation *closed = [[XCTNSPredicateExpectation alloc] initWithPredicate:gone object:self.app.buttons[nextIdentifier]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[closed] timeout:5], XCTWaiterResultCompleted);
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, equation);
    XCTAssertTrue(self.app.buttons[@"concept.close"].hittable);
    for (NSUInteger index = 0; index < 4; index++) {
        NSString *identifier = [NSString stringWithFormat:@"answer.%lu", (unsigned long)index];
        XCTAssertFalse(self.app.buttons[identifier].exists);
    }
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
}
- (void)returnFromTeaching:(NSString *)nextIdentifier equation:(NSString *)equation {
    [self.app.buttons[@"explanation.close"] tap];
    [self assertReturnedFromTeaching:nextIdentifier equation:equation];
}
- (void)checkChangedVariation:(NSString *)equation prefix:(NSString *)prefix board:(NSString *)boardID fragments:(NSArray<NSString *> *)fragments narration:(NSString *)expectedNarration {
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, equation);
    NSString *question = self.app.staticTexts[@"concept.question"].label;
    NSString *stage = self.app.staticTexts[@"concept.stage"].label;
    NSString *variation = self.app.staticTexts[@"concept.variation"].label;
    XCTAssertTrue([stage hasPrefix:@"3 / 3"]);
    XCTAssertTrue([variation containsString:@"2 / 3"]);
    [self tapConcept:@"concept.teach"];
    NSString *next = [prefix stringByAppendingString:@".next"];
    XCTAssertTrue([self.app.buttons[next] waitForExistenceWithTimeout:5]);
    [self waitForBoard:boardID fragments:fragments];
    if (expectedNarration) {
        XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:expectedNarration]);
    }
    XCTAssertTrue([[self boardValue:boardID] containsString:@"答案還沒寫"]);
    XCTAssertFalse(self.app.buttons[@"grouping.changeMeaning"].exists);
    [self returnFromTeaching:next equation:equation];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.question"].label, question);
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.stage"].label, stage);
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.variation"].label, variation);
    [self tapConcept:@"concept.previous"];
    [self tapConcept:@"concept.next"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, equation);
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.question"].label, question);
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.stage"].label, stage);
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.variation"].label, variation);
}
- (void)testCarryDiscoveryKeepsQuestionsAcrossTeachingBackAndChangedNumbers {
    [self openPath:@"carry"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"27 + 15 = ?");
    [self tapConcept:@"concept.teach"];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue([[self boardValue:@"verticalTeachingBoard"] containsString:@"答案還沒寫"]);
    [self.app.buttons[@"teaching.next"] tap];
    NSString *selectedStep = self.app.staticTexts[@"teaching.progress"].label;
    [XCUIDevice.sharedDevice pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, selectedStep);
    [self capture:@"concept-carry-optional-teaching"];
    [self.app.buttons[@"teaching.next"] tap];
    [self.app.buttons[@"teaching.next"] tap];
    NSArray *exchange = @[@"個位 12 → 2", @"十位 2 → 3", @"答案還沒寫"];
    [self waitForBoard:@"verticalTeachingBoard" fragments:exchange];
    [self assertVerticalExchangeNaturallyCompletes:@"concept-carry-exchange"];
    [self replayVerticalExchange:exchange name:@"concept-carry-replay-from-written-work"];
    [self returnFromTeaching:@"teaching.next" equation:@"27 + 15 = ?"];
    [self tapConcept:@"concept.next"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"36 + 18 = ?");
    XCTAssertTrue([self.app.staticTexts[@"concept.invitation"].label containsString:@"先用手指或心裡想一想"]);
    [self tapConcept:@"concept.next"]; // Guidance is optional, not a completion gate.
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"43 + 16 = ?");
    [self tapConcept:@"concept.change"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"43 + 17 = ?");
    [self checkChangedVariation:@"43 + 17 = ?" prefix:@"teaching" board:@"verticalTeachingBoard" fragments:@[@"43 加 17。"] narration:nil];
    [self capture:@"concept-carry-retained-exploration"];
    [self tapConcept:@"concept.change"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"43 + 18 = ?");
    [self tapConcept:@"concept.change"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"43 + 16 = ?");
    [self.app.buttons[@"concept.close"] tap];
    XCTAssertTrue([self.app.collectionViews[@"lessons.catalog"] waitForExistenceWithTimeout:5]);
}
- (void)testBorrowingDirectlyExposesZeroRegrouping {
    [self openPath:@"borrow"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"42 − 16 = ?");
    [self tapConcept:@"concept.next"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"102 − 38 = ?");
    XCTAssertTrue([self.app.staticTexts[@"concept.focus"].label containsString:@"十位是零"]);
    [self tapConcept:@"concept.teach"];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    [self waitForBoard:@"verticalTeachingBoard" fragments:@[@"102 減 38。", @"答案還沒寫"]];
    [self capture:@"concept-borrow-through-zero"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"1 個百可以換成幾個十"]);
    [self.app.buttons[@"teaching.next"] tap]; // Prediction is optional; this cannot reveal the answer.
    NSArray *hundreds = @[@"百位 1 → 0", @"十位 0 → 10", @"答案還沒寫"];
    [self waitForBoard:@"verticalTeachingBoard" fragments:hundreds];
    NSString *firstExchange = [self boardValue:@"verticalTeachingBoard"];
    NSString *firstProgress = self.app.staticTexts[@"teaching.progress"].label;
    [self assertVerticalExchangeNaturallyCompletes:@"concept-borrow-hundred-to-ten-tens"];
    [self replayVerticalExchange:hundreds name:@"concept-borrow-first-exchange-replay"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"1 個十可以換成幾個一"]);
    NSString *secondPrediction = [self boardValue:@"verticalTeachingBoard"];
    NSString *predictionProgress = self.app.staticTexts[@"teaching.progress"].label;
    XCTAssertTrue([secondPrediction containsString:@"答案還沒寫"]);
    [self.app.buttons[@"teaching.next"] tap];
    NSArray *tens = @[@"十位 10 → 9", @"個位 2 → 12", @"答案還沒寫"];
    [self waitForBoard:@"verticalTeachingBoard" fragments:tens];
    NSString *secondExchange = [self boardValue:@"verticalTeachingBoard"];
    NSString *secondProgress = self.app.staticTexts[@"teaching.progress"].label;
    XCTAssertFalse([secondExchange containsString:@"個位寫"]);
    XCTAssertFalse([secondExchange containsString:@"十位寫"]);
    XCTAssertFalse([self.app.staticTexts[@"explanation.steps"].label containsString:@"= 64"]);
    [self assertVerticalExchangeNaturallyCompletes:@"concept-borrow-ten-to-twelve-ones"];
    [self replayVerticalExchange:tens name:@"concept-borrow-second-exchange-replay"];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationLandscapeLeft;
    NSPredicate *landscape = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        CGSize size = self.app.windows.firstMatch.frame.size;
        return size.width > size.height;
    }];
    XCTNSPredicateExpectation *rotated = [[XCTNSPredicateExpectation alloc] initWithPredicate:landscape object:self.app];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[rotated] timeout:5], XCTWaiterResultCompleted);
    // Rotation itself must preserve semantic focus before Replay can repair it.
    [self assertAction:@"verticalTeachingExchange" fullyVisibleIn:@"teaching.content"];
    XCTAssertEqualObjects([self boardValue:@"verticalTeachingBoard"], secondExchange);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, secondProgress);
    [self replayVerticalExchange:tens name:@"concept-borrow-landscape-replay"];
    [XCUIDevice.sharedDevice pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertEqualObjects([self boardValue:@"verticalTeachingBoard"], secondExchange);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, secondProgress);
    [self.app.buttons[@"teaching.previous"] tap];
    XCTAssertEqualObjects([self boardValue:@"verticalTeachingBoard"], secondPrediction);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, predictionProgress);
    [self.app.buttons[@"teaching.previous"] tap];
    XCTAssertEqualObjects([self boardValue:@"verticalTeachingBoard"], firstExchange);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, firstProgress);
    [self.app.buttons[@"teaching.next"] tap];
    [self.app.buttons[@"teaching.next"] tap];
    [self waitForBoard:@"verticalTeachingBoard" fragments:tens];
    [self assertVerticalExchangeNaturallyCompletes:@"concept-borrow-second-exchange-after-back"];
    XCTAssertEqualObjects([self boardValue:@"verticalTeachingBoard"], secondExchange);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, secondProgress);
    [self returnFromTeaching:@"teaching.next" equation:@"102 − 38 = ?"];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    [self tapConcept:@"concept.next"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"112 − 38 = ?");
    [self tapConcept:@"concept.change"];
    [self checkChangedVariation:@"102 − 38 = ?" prefix:@"teaching" board:@"verticalTeachingBoard" fragments:@[@"102 減 38。"] narration:nil];
    [self tapConcept:@"concept.change"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"203 − 57 = ?");
    [self tapConcept:@"concept.change"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"112 − 38 = ?");
}
- (void)testEqualGroupsDiscoveryDoesNotRequireOpeningTheMultiplicationTable {
    [self openPath:@"equal-groups"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"3 × 2 = ?");
    XCTAssertTrue([self.app.staticTexts[@"concept.question"].label containsString:@"每包有 3 顆糖果，有 2 包"]);
    [self tapConcept:@"concept.teach"];
    XCTAssertTrue([self.app.buttons[@"grouping.next"] waitForExistenceWithTimeout:5]);
    [self waitForBoard:@"groupingTeachingBoard" fragments:@[@"已建立 0 包", @"還有 2 包尚未建立", @"答案還沒寫"]];
    [self capture:@"concept-equal-groups-direct-route"];
    for (NSUInteger bag = 1; bag <= 2; bag++) {
        [self.app.buttons[@"grouping.next"] tap];
        [self.app.buttons[@"grouping.next"] tap];
        [self waitForBoard:@"groupingTeachingBoard" fragments:@[
            [NSString stringWithFormat:@"已建立 %lu 包", (unsigned long)bag],
            [NSString stringWithFormat:@"第 %lu 包有 3 顆", (unsigned long)bag], @"答案還沒寫"]];
    }
    [self waitForBoard:@"groupingTeachingBoard" fragments:@[@"第 1 包有 3 顆", @"第 2 包有 3 顆", @"還有 0 包尚未建立"]];
    [self captureOverview:@"groupingTeachingBoard" inScroll:@"grouping.content" name:@"concept-equal-groups-two-bags"];
    [self.app.buttons[@"grouping.next"] tap];
    [self waitForBoard:@"groupingTeachingBoard" fragments:@[@"第 1 包有 3 顆", @"第 2 包有 3 顆", @"寫下：6 顆"]];
    XCTAssertFalse([[self boardValue:@"groupingTeachingBoard"] containsString:@"答案還沒寫"]);
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"2 包合起來有 6 顆"]);
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.heading"].label, @"回頭想一想");
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.explanation"].label, @"可以回到題目，想想每一步為什麼這樣做；也可以重看剛才的步驟。");
    [self returnFromTeaching:@"grouping.next" equation:@"3 × 2 = ?"];
    [self tapConcept:@"concept.next"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"3 × 3 = ?");
    [self tapConcept:@"concept.next"];
    XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"4 × 3 = ?");
    [self tapConcept:@"concept.change"];
    [self checkChangedVariation:@"3 × 4 = ?" prefix:@"grouping" board:@"groupingTeachingBoard"
        fragments:@[@"每個圓點代表 1 顆糖果", @"已建立 0 包", @"還有 4 包尚未建立"]
        narration:@"每包的糖果有 3 顆，要建立 4 包"];
}
- (void)testSharingAndPackingKeepDifferentQuestionsForTheSameNumbers {
    for (NSString *pathID in @[@"sharing", @"packing"]) {
        if ([pathID isEqualToString:@"packing"]) {
            [self.app terminate];
            [self.app launch];
        }
        [self openPath:pathID];
        [self tapConcept:@"concept.next"];
        XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"13 ÷ 3 = ?");
        NSString *question = self.app.staticTexts[@"concept.question"].label;
        BOOL sharing = [pathID isEqualToString:@"sharing"];
        XCTAssertTrue([question containsString:sharing ? @"平均分給 3 個小朋友" : @"每 3 顆裝成一包"]);
        [self tapConcept:@"concept.teach"];
        XCTAssertTrue([self.app.buttons[@"grouping.next"] waitForExistenceWithTimeout:5]);
        XCTAssertFalse(self.app.buttons[@"grouping.changeMeaning"].exists, @"A story keeps its producer-supplied meaning.");
        [self waitForBoard:@"groupingTeachingBoard" fragments:@[sharing ? @"平均分給 3 個小朋友" : @"已分成 0 包",
            sharing ? @"待分的糖果：13 顆" : @"待分組的糖果：13 顆", @"答案還沒寫"]];
        if (sharing) {
            [self waitForBoard:@"groupingTeachingBoard" fragments:@[@"第 1 個小朋友有 0 顆", @"第 2 個小朋友有 0 顆", @"第 3 個小朋友有 0 顆"]];
        } else {
            XCTAssertFalse([[self boardValue:@"groupingTeachingBoard"] containsString:@"第 1 包有"]);
        }
        [self capture:[@"concept-division-" stringByAppendingString:pathID]];
        NSArray<NSString *> *finalCounts = @[];
        for (NSUInteger action = 1; action <= 4; action++) {
            [self.app.buttons[@"grouping.next"] tap]; // Optional prediction, never an answer gate.
            [self.app.buttons[@"grouping.next"] tap];
            NSString *actionName = (action == 1 || action == 4)
                ? [NSString stringWithFormat:@"concept-division-%@-transfer-%lu", pathID, (unsigned long)action] : nil;
            NSUInteger replayTransfers = 3;
            if (sharing) {
                replayTransfers = [self completeSharingRound:action total:13 recipients:3 name:actionName];
            } else {
                [self assertGroupingActionNaturallyCompletesWithTransfers:3 name:actionName];
            }
            NSMutableArray<NSString *> *state = [NSMutableArray arrayWithObjects:@"答案還沒寫",
                [NSString stringWithFormat:sharing ? @"待分的糖果：%lu 顆" : @"待分組的糖果：%lu 顆", (unsigned long)(13 - 3 * action)], nil];
            NSUInteger count = sharing ? 3 : action;
            [state addObject:[NSString stringWithFormat:sharing ? @"平均分給 %lu 個小朋友" : @"已分成 %lu 包", (unsigned long)count]];
            for (NSUInteger group = 1; group <= count; group++) {
                [state addObject:[NSString stringWithFormat:sharing ? @"第 %lu 個小朋友有 %lu 顆" : @"第 %lu 包有 %lu 顆",
                    (unsigned long)group, (unsigned long)(sharing ? action : 3)]];
            }
            [self waitForBoard:@"groupingTeachingBoard" fragments:state];
            if (action == 4) finalCounts = [state subarrayWithRange:NSMakeRange(1, state.count - 1)];
            NSString *unexpectedGroup = sharing ? @"第 4 個小朋友有"
                : [NSString stringWithFormat:@"第 %lu 包有", (unsigned long)action + 1];
            XCTAssertFalse([[self boardValue:@"groupingTeachingBoard"] containsString:unexpectedGroup]);
            if (action == 1 || action == 4) {
                [self replayGroupingActionWithTransfers:replayTransfers fragments:state name:[actionName stringByAppendingString:@"-replay"]];
            }
        }
        [self.app.buttons[@"grouping.next"] tap];
        XCTAssertTrue([self.app.staticTexts[@"grouping.prompt"].label containsString:sharing ? @"還能讓每個小朋友再拿 1 顆嗎" : @"還夠再分成完整的一包嗎"]);
        [self.app.buttons[@"grouping.next"] tap];
        XCTAssertEqualObjects(self.app.staticTexts[@"grouping.heading"].label, @"看看為什麼停下來");
        XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:sharing ? @"不是每個小朋友各剩一份" : @"不是完整的包"]);
        [self waitForBoard:@"groupingTeachingBoard" fragments:@[@"共同剩下：1 顆糖果", @"這些還在待分區，不在任何一組裡", @"答案還沒寫"]];
        [self waitForBoard:@"groupingTeachingBoard" fragments:finalCounts];
        NSString *remainder = [self boardValue:@"groupingTeachingBoard"];
        XCTAssertEqual([remainder componentsSeparatedByString:@"共同剩下："].count, (NSUInteger)2,
            @"There is exactly one common leftover summary, not a remainder per recipient.");
        XCTAssertFalse([remainder containsString:@"寫下：4"]);
        [self captureOverview:@"groupingTeachingBoard" inScroll:@"grouping.content" name:[@"concept-division-common-remainder-" stringByAppendingString:pathID]];
        [self.app.buttons[@"grouping.next"] tap];
        NSString *answer = sharing ? @"寫下：4 顆" : @"寫下：4 包";
        [self waitForBoard:@"groupingTeachingBoard" fragments:@[answer, @"共同剩下：1 顆糖果"]];
        [self waitForBoard:@"groupingTeachingBoard" fragments:finalCounts];
        XCTAssertFalse([[self boardValue:@"groupingTeachingBoard"] containsString:sharing ? @"寫下：4 包" : @"寫下：4 顆"]);
        XCTAssertFalse([[self boardValue:@"groupingTeachingBoard"] containsString:@"答案還沒寫"]);
        [self captureOverview:@"groupingTeachingBoard" inScroll:@"grouping.content" name:[@"concept-division-answer-unit-" stringByAppendingString:pathID]];
        [self.app.buttons[@"grouping.next"] tap];
        XCTAssertEqualObjects(self.app.staticTexts[@"grouping.heading"].label, @"放回原來的題目檢查");
        XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"正好是原來的糖果 13 顆"]);
        [self.app.buttons[@"grouping.next"] tap];
        XCTAssertEqualObjects(self.app.staticTexts[@"grouping.heading"].label, @"回頭想一想");
        XCTAssertEqualObjects(self.app.staticTexts[@"grouping.explanation"].label, @"可以回到題目，想想每一步為什麼這樣做；也可以重看剛才的步驟。");
        XCTAssertEqualObjects(self.app.buttons[@"grouping.next"].label, @"回到題目");
        [self.app.buttons[@"grouping.next"] tap]; // Exercise the terminal route, not the toolbar close.
        [self assertReturnedFromTeaching:@"grouping.next" equation:@"13 ÷ 3 = ?"];
        XCTAssertEqualObjects(self.app.staticTexts[@"concept.question"].label, question);
        [self tapConcept:@"concept.next"];
        XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"17 ÷ 4 = ?");
        [self tapConcept:@"concept.change"];
        [self checkChangedVariation:@"18 ÷ 4 = ?" prefix:@"grouping" board:@"groupingTeachingBoard"
            fragments:@[sharing ? @"平均分給 4 個小朋友" : @"已分成 0 包",
                sharing ? @"待分的糖果：18 顆" : @"待分組的糖果：18 顆"]
            narration:sharing ? @"把糖果 18 顆平均分給 4 個小朋友" : @"糖果共有 18 顆，每包要有 4 顆"];
        [self tapConcept:@"concept.change"];
        XCTAssertEqualObjects(self.app.staticTexts[@"concept.equation"].label, @"19 ÷ 4 = ?");
    }
}
@end
