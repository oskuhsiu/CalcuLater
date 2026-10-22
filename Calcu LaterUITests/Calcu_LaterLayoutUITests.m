#import <XCTest/XCTest.h>
#import <math.h>

/// Runs on the compact phone, tablet and real system Dynamic Type scenarios.
/// Screenshots and AX trees are evidence for visual review, not substitutes for it.
@interface Calcu_LaterLayoutUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation Calcu_LaterLayoutUITests
- (void)setUp {
    self.continueAfterFailure = NO;
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    self.app = [[XCUIApplication alloc] init];
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)", @"-AppleLocale", @"zh_TW", @"-soundEffectsEnabled", @"NO", @"-CalcuLaterVerticalPlaybackDiagnostics"];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
}
- (void)tearDown {
    if (self.testRun.failureCount > 0) {
        XCTAttachment *screen = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
        screen.name = [@"layout-failure-" stringByAppendingString:self.name];
        screen.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:screen];
        XCTAttachment *tree = [XCTAttachment attachmentWithString:self.app.debugDescription];
        tree.name = @"layout-failure-hierarchy";
        tree.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:tree];
        XCUIElement *verticalContent = self.app.scrollViews[@"teaching.content"];
        if (verticalContent.exists) {
            XCTAttachment *observations = [XCTAttachment attachmentWithString:[verticalContent.value description] ?: @"<missing controller observations>"];
            observations.name = @"layout-failure-vertical-controller-observations";
            observations.lifetime = XCTAttachmentLifetimeKeepAlways;
            [self addAttachment:observations];
        }
    }
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    [self.app terminate];
}
- (XCUIElement *)element:(NSString *)identifier {
    return [self.app descendantsMatchingType:XCUIElementTypeAny][identifier];
}
- (void)capture:(NSString *)name {
    XCTAssertEqual(self.app.state, XCUIApplicationStateRunningForeground);
    XCTAttachment *image = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    image.name = name;
    image.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:image];
    XCTAttachment *hierarchy = [XCTAttachment attachmentWithString:self.app.debugDescription];
    hierarchy.name = [name stringByAppendingString:@"-hierarchy"];
    hierarchy.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:hierarchy];
}
- (void)reveal:(XCUIElement *)element in:(XCUIElement *)container down:(BOOL)down {
    for (NSUInteger attempt = 0; attempt < 10 && !element.hittable; attempt++) {
        XCTAssertTrue(container.exists);
        CGRect containerFrame = container.frame;
        CGRect viewport = CGRectIntersection(containerFrame, self.app.windows.firstMatch.frame);
        XCTAssertFalse(CGRectIsNull(viewport));
        XCTAssertTrue(isfinite(viewport.origin.x) && isfinite(viewport.origin.y)
            && isfinite(viewport.size.width) && isfinite(viewport.size.height));
        XCTAssertGreaterThan(viewport.size.width, 44.0);
        XCTAssertGreaterThan(viewport.size.height, 44.0);
        CGFloat distance = (down ? -1 : 1) * viewport.size.height * 0.3;
        CGFloat travelFraction = 0.3;
        XCUIElement *scrollTarget = element;
        CGRect target = CGRectNull;
        if (element.exists) {
            if (container.elementType == XCUIElementTypeTable && element.elementType != XCUIElementTypeCell
                && element.identifier.length > 0) {
                // Offscreen table accessories can expose stale child frames.
                // Their containing row has the table's current layout position.
                XCUIElement *row = [container.cells containingType:XCUIElementTypeAny identifier:element.identifier].firstMatch;
                if (row.exists) scrollTarget = row;
            }
            target = scrollTarget.frame;
            BOOL hasGeometry = isfinite(target.origin.x) && isfinite(target.origin.y)
                && isfinite(target.size.width) && isfinite(target.size.height)
                && target.size.width > 0 && target.size.height > 0;
            if (hasGeometry) {
                // Recompute direction after EVERY drag. The requested direction
                // is only a hint for a virtualized element without geometry.
                // A broad swipe can pass a row; its new frame must bring us back.
                distance = CGRectGetMidY(target) - CGRectGetMidY(viewport);
                if (fabs(distance) < 1) distance = down ? -24 : 24;
                // AX5 Settings rows can be several screens away. Ten 30% drags
                // exhausted their travel budget before the first switch arrived.
                // Use a half-viewport drag only for a real table row still more
                // than one small drag outside the viewport. Keep the compact
                // overshoot correction unchanged once the row approaches it.
                BOOL farTableRow = container.elementType == XCUIElementTypeTable
                    && scrollTarget.elementType == XCUIElementTypeCell
                    && (CGRectGetMinY(target) > CGRectGetMaxY(viewport) + viewport.size.height * 0.3
                        || CGRectGetMaxY(target) < CGRectGetMinY(viewport) - viewport.size.height * 0.3);
                if (farTableRow) travelFraction = 0.5;
            }
        }
        CGFloat travel = MIN(MAX(fabs(distance), 24), viewport.size.height * travelFraction);
        CGFloat startY = CGRectGetMinY(viewport) + viewport.size.height * (distance > 0 ? 0.65 : 0.35);
        CGFloat endY = startY + (distance > 0 ? -travel : travel);
        XCUICoordinate *origin = [container coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
        CGFloat x = CGRectGetMidX(viewport) - CGRectGetMinX(containerFrame);
        XCUICoordinate *start = [origin coordinateWithOffset:CGVectorMake(x, startY - CGRectGetMinY(containerFrame))];
        XCUICoordinate *end = [origin coordinateWithOffset:CGVectorMake(x, endY - CGRectGetMinY(containerFrame))];
        [start pressForDuration:0.05 thenDragToCoordinate:end];
        if (container.elementType == XCUIElementTypeTable) {
            CGRect after = scrollTarget.exists ? scrollTarget.frame : CGRectNull;
            XCTAttachment *trace = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
                @"attempt=%lu identifier=%@ viewport=%@ targetBefore=%@ targetAfter=%@ requested=%g travel=%g fraction=%g startY=%g endY=%g hittable=%d",
                (unsigned long)attempt + 1, element.identifier, NSStringFromCGRect(viewport),
                NSStringFromCGRect(target), NSStringFromCGRect(after), (double)distance,
                (double)travel, (double)travelFraction, (double)startY, (double)endY, element.hittable]];
            trace.name = @"settings-reveal-scroll";
            trace.lifetime = XCTAttachmentLifetimeKeepAlways;
            [self addAttachment:trace];
        }
    }
    XCTAssertTrue(element.hittable, @"A child must be able to reach %@ by scrolling.", element.identifier);
}
- (void)tapHomeCard:(NSString *)identifier {
    XCUIElement *card = self.app.buttons[identifier];
    [self reveal:card in:self.app.scrollViews.firstMatch down:NO];
    [card tap];
}
- (void)launchScenario:(NSString *)scenario {
    [self.app terminate];
    self.app.launchArguments = [self.app.launchArguments arrayByAddingObjectsFromArray:@[@"-CalcuLaterScenario", scenario, @"-answerMode", @"0"]];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
}
- (void)assertVisibleControl:(XCUIElement *)control {
    XCTAssertTrue(control.exists);
    XCTAssertTrue(control.hittable, @"%@ must remain reachable without scrolling.", control.identifier);
    CGRect frame = control.frame;
    CGRect window = self.app.windows.firstMatch.frame;
    XCTAssertGreaterThanOrEqual(frame.size.width, 44.0);
    XCTAssertGreaterThanOrEqual(frame.size.height, 44.0);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(frame), CGRectGetMinX(window) - 1);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(frame), CGRectGetMaxX(window) + 1);
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(frame), CGRectGetMinY(window) - 1);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(frame), CGRectGetMaxY(window) + 1);
}
- (void)assertHorizontalBounds:(XCUIElement *)element in:(XCUIElement *)container {
    XCTAssertTrue(element.exists);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(element.frame), CGRectGetMinX(container.frame) - 1);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(element.frame), CGRectGetMaxX(container.frame) + 1);
}
- (void)assertTeachingControls {
    for (NSString *identifier in @[@"teaching.previous", @"teaching.replay", @"teaching.next", @"explanation.close"]) {
        [self assertVisibleControl:self.app.buttons[identifier]];
    }
}

- (void)assertGroupingControls {
    for (NSString *identifier in @[@"grouping.previous", @"grouping.replay", @"grouping.next", @"explanation.close"]) {
        [self assertVisibleControl:self.app.buttons[identifier]];
    }
}
- (NSString *)openGroupingStory:(NSString *)scenario {
    [self launchScenario:scenario];
    [self tapHomeCard:@"home.stories"];
    XCTAssertTrue([self.app.buttons[@"stories.grade.3"] waitForExistenceWithTimeout:5]);
    [self.app.buttons[@"stories.grade.3"] tap];
    XCUIElement *story = self.app.staticTexts[@"story.text"];
    XCTAssertTrue([story waitForExistenceWithTimeout:5]);
    NSString *originalStory = story.label;
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"grouping.next"] waitForExistenceWithTimeout:5]);
    XCTAssertFalse(self.app.buttons[@"grouping.changeMeaning"].exists);
    [self assertGroupingControls];
    return originalStory;
}
- (NSString *)groupingBoardValue {
    return [[self element:@"groupingTeachingBoard"].value description];
}
- (void)waitForGroupingValues:(NSArray<NSString *> *)fragments {
    NSMutableArray<NSPredicate *> *conditions = [NSMutableArray array];
    for (NSString *fragment in fragments) {
        [conditions addObject:[NSPredicate predicateWithFormat:@"SELF CONTAINS %@", fragment]];
    }
    [conditions addObject:[NSPredicate predicateWithFormat:@"NOT (SELF CONTAINS %@)", @"正在移動"]];
    NSPredicate *settled = [NSCompoundPredicate andPredicateWithSubpredicates:conditions];
    [self waitForFreshGroupingValueMatching:settled timeout:3 name:@"layout-grouping-quantity-observations"];
}
- (void)waitForFreshGroupingValueMatching:(NSPredicate *)condition timeout:(NSTimeInterval)timeout name:(NSString *)name {
    NSTimeInterval started = NSProcessInfo.processInfo.systemUptime;
    NSMutableArray<NSString *> *samples = [NSMutableArray array];
    NSPredicate *freshValue = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary<NSString *, id> *bindings) {
        NSTimeInterval queryStarted = NSProcessInfo.processInfo.systemUptime - started;
        // Re-query each time, rather than evaluating against the expectation's
        // earlier XCUIElement snapshot. Keep the entire observed lifecycle value.
        XCUIElement *board = [self element:@"groupingTeachingBoard"];
        BOOL exists = board.exists;
        NSString *value = exists ? ([board.value description] ?: @"<nil groupingTeachingBoard.value>") : @"<missing groupingTeachingBoard>";
        BOOL matches = exists && [condition evaluateWithObject:value];
        [samples addObject:[NSString stringWithFormat:@"sample=%lu queryStarted=%.6f observed=%.6f exists=%d matches=%d value=%@",
            (unsigned long)samples.count + 1, queryStarted, NSProcessInfo.processInfo.systemUptime - started,
            exists, matches, value]];
        return matches;
    }];
    XCTNSPredicateExpectation *ready = [[XCTNSPredicateExpectation alloc] initWithPredicate:freshValue object:nil];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ready] timeout:timeout];
    NSString *trace = [NSString stringWithFormat:@"condition=%@ timeout=%.3f elapsed=%.6f result=%ld\n%@",
        condition, timeout, NSProcessInfo.processInfo.systemUptime - started, (long)result,
        [samples componentsJoinedByString:@"\n"]];
    XCTAttachment *observations = [XCTAttachment attachmentWithString:trace];
    observations.name = name;
    observations.lifetime = XCTAttachmentLifetimeKeepAlways;
    // Retain all samples before continueAfterFailure=NO can stop the case.
    [self addAttachment:observations];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"The live grouping value must satisfy %@ within %.3f seconds.", condition, timeout);
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
- (void)assertGroupingBoardVisible {
    XCUIElement *board = [self element:@"groupingTeachingBoard"];
    XCUIElement *content = self.app.scrollViews[@"grouping.content"];
    CGRect boardFrame = [self checkedFrame:board];
    CGRect viewport = [self checkedFrame:content];
    CGRect visible = CGRectIntersection(boardFrame, viewport);
    XCTAssertFalse(CGRectIsNull(visible));
    XCTAssertFalse(CGRectIsEmpty(visible));
    XCTAssertGreaterThan(visible.size.width, 44.0);
    XCTAssertGreaterThan(visible.size.height, 44.0);
    [self assertHorizontalBounds:board in:content];
    // One AX element describes the whole board. Neither its hittability nor
    // this intersection proves that counters are visible; review native video.
}
- (void)dragGroupingContentBy:(CGFloat)distance {
    XCUIElement *board = [self element:@"groupingTeachingBoard"];
    XCUIElement *content = self.app.scrollViews[@"grouping.content"];
    CGRect before = [self checkedFrame:board];
    CGRect viewport = [self checkedFrame:content];
    CGFloat height = viewport.size.height;
    XCTAssertTrue(isfinite(distance));
    CGFloat travel = MIN(fabs(distance), height * 0.55);
    CGFloat startY = distance > 0 ? 0.8 : 0.2;
    CGFloat endY = startY + (distance > 0 ? -1 : 1) * travel / height;
    XCUICoordinate *start = [content coordinateWithNormalizedOffset:CGVectorMake(0.5, startY)];
    XCUICoordinate *end = [content coordinateWithNormalizedOffset:CGVectorMake(0.5, endY)];
    CGPoint startPoint = start.screenPoint, endPoint = end.screenPoint;
    // A bounded finger path alone is not a bounded scroll: the old zero-hold
    // gesture kept moving after release. Hold at the endpoint before lifting.
    [start pressForDuration:0.05 thenDragToCoordinate:end
        withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
    CGRect after = [self checkedFrame:board];
    NSString *measurement = [NSString stringWithFormat:
        @"requestedScroll=%.2f; boundedScroll=%.2f; measuredScroll=%.2f; "
         "before=%@; after=%@; viewportBefore=%@; viewportAfter=%@; touchStart=%@; touchEnd=%@",
        distance, copysign(travel, distance), CGRectGetMinY(before) - CGRectGetMinY(after),
        NSStringFromCGRect(before), NSStringFromCGRect(after), NSStringFromCGRect(viewport),
        NSStringFromCGRect(content.frame), NSStringFromCGPoint(startPoint), NSStringFromCGPoint(endPoint)];
    XCTAttachment *trace = [XCTAttachment attachmentWithString:measurement];
    trace.name = @"grouping-board-inspection-scroll";
    trace.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:trace];
}
- (void)assertCompleteGroupingActionVisible {
    XCTAssertEqual([[self.app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"groupingTeachingBoard"].count, 1u);
    CGRect action = [self checkedFrame:[self element:@"groupingTeachingBoard"]];
    CGRect viewport = [self checkedFrame:self.app.scrollViews[@"grouping.content"]];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -1, -1), action),
        @"The complete source, active target, labels and route must fit before inspection: %@ in %@", NSStringFromCGRect(action), NSStringFromCGRect(viewport));
}
- (void)waitForGroupingActionNaturalEnd {
    NSString *value = self.groupingBoardValue;
    XCTAssertTrue([value containsString:@"播放狀態："],
        @"A division action must expose its renderer lifecycle; a static overview is not motion evidence.");
    NSUInteger transfers = [value containsString:@" / "] ? 1 : 4; // These story fixtures are 23 ÷ 4.
    NSTimeInterval duration = 0.28 + 0.82 * transfers + 0.24;
    NSPredicate *completed = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", @"。播放完成。播放狀態：completed"];
    [self waitForFreshGroupingValueMatching:completed timeout:duration + 1.0 name:@"layout-grouping-natural-completion-observations"];
}
- (void)finishFocusedSharingRoundWatchingActions:(BOOL)watch {
    for (NSUInteger recipient = 0; recipient < 9; recipient++) {
        if (watch) { [self assertCompleteGroupingActionVisible]; [self waitForGroupingActionNaturalEnd]; }
        if (![self.app.buttons[@"grouping.next"].label isEqualToString:@"下一位"]) return;
        [self.app.buttons[@"grouping.next"] tap];
    }
    XCTFail(@"The bounded sharing round must finish after at most nine explicit recipient choices.");
}
- (void)previousOriginalGroupingStep {
    NSString *original = self.app.staticTexts[@"grouping.progress"].label;
    for (NSUInteger recipient = 0; recipient < 10; recipient++) {
        [self.app.buttons[@"grouping.previous"] tap];
        if (![self.app.staticTexts[@"grouping.progress"].label isEqualToString:original]) return;
    }
    XCTFail(@"Previous must leave the bounded recipient subactions.");
}
- (void)captureGroupingBoardSlices:(NSString *)name {
    if ([self.groupingBoardValue containsString:@"播放狀態："]) {
        [self assertCompleteGroupingActionVisible]; [self waitForGroupingActionNaturalEnd];
        [self.app.buttons[@"grouping.viewMode"] tap]; // Inspect the exact selected partial/full snapshot, not a different round.
    }
    XCUIElement *board = [self element:@"groupingTeachingBoard"];
    XCUIElement *content = self.app.scrollViews[@"grouping.content"];
    // Start at the board's top, not whichever portion makes a tall AX element
    // hittable. Small boards may already fit without needing to align their top.
    for (NSUInteger attempt = 0; attempt < 8; attempt++) {
        CGRect frame = [self checkedFrame:board];
        CGRect viewport = [self checkedFrame:content];
        CGFloat delta = CGRectGetMinY(frame) - CGRectGetMinY(viewport) - 8;
        if (fabs(delta) <= 12 || (CGRectGetMinY(frame) >= CGRectGetMinY(viewport)
            && CGRectGetMaxY(frame) <= CGRectGetMaxY(viewport))) break;
        [self dragGroupingContentBy:delta];
        if (fabs(board.frame.origin.y - frame.origin.y) < 1) break;
    }
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(board.frame), CGRectGetMinY(content.frame) - 12);
    [self assertGroupingBoardVisible];
    [self capture:[name stringByAppendingString:@"-top"]];
    // Retain consecutive portions through the lower groups and answer/remainder.
    // Do not assert that the whole board fits in a compact/large-text viewport.
    for (NSUInteger slice = 1; slice <= 8; slice++) {
        CGFloat remaining = CGRectGetMaxY(board.frame) - CGRectGetMaxY(content.frame);
        if (remaining <= 12) break;
        CGRect before = board.frame;
        [self dragGroupingContentBy:MIN(remaining + 8, content.frame.size.height * 0.5)];
        XCTAssertLessThan(board.frame.origin.y, before.origin.y - 1,
            @"The child must be able to scroll to the lower groups.");
        XCTAssertLessThanOrEqual(before.origin.y - board.frame.origin.y, content.frame.size.height - 24,
            @"Retained slices must overlap; requested drag distance alone is not evidence of coverage.");
        [self assertGroupingBoardVisible];
        NSString *sliceName = [NSString stringWithFormat:@"%@-lower-slice-%lu", name, (unsigned long)slice];
        [self capture:sliceName];
    }
    XCTAssertLessThanOrEqual(CGRectGetMaxY(board.frame), CGRectGetMaxY(content.frame) + 12,
        @"Retained slices must reach the board's lower groups and separate remainder.");
    [self assertGroupingControls];
}
- (void)captureGroupingBoardEnd:(NSString *)name {
    XCUIElement *board = [self element:@"groupingTeachingBoard"];
    XCUIElement *content = self.app.scrollViews[@"grouping.content"];
    for (NSUInteger attempt = 0; attempt < 8; attempt++) {
        CGRect frame = [self checkedFrame:board];
        CGRect viewport = [self checkedFrame:content];
        CGFloat delta = CGRectGetMaxY(frame) - CGRectGetMaxY(viewport) + 8;
        if (fabs(delta) <= 12 || (CGRectGetMinY(frame) >= CGRectGetMinY(viewport)
            && CGRectGetMaxY(frame) <= CGRectGetMaxY(viewport))) break;
        [self dragGroupingContentBy:delta];
        if (fabs(board.frame.origin.y - frame.origin.y) < 1) break;
    }
    XCTAssertLessThanOrEqual(CGRectGetMaxY(board.frame), CGRectGetMaxY(content.frame) + 12);
    [self assertGroupingBoardVisible];
    [self assertGroupingControls];
    [self capture:name];
}
- (void)replayGroupingPreservingInspection:(NSArray<NSString *> *)settledValues capture:(NSString *)name {
    XCUIElement *board = [self element:@"groupingTeachingBoard"];
    CGRect inspectedFrame = [self checkedFrame:board];
    NSString *progress = self.app.staticTexts[@"grouping.progress"].label;
    [self.app.buttons[@"grouping.replay"] tap];
    // Both callers selected a real division action. Replay must return to that
    // complete causal scene; a static overview cannot bypass natural-end proof.
    [self assertCompleteGroupingActionVisible]; [self waitForGroupingActionNaturalEnd];
    [self capture:[name stringByAppendingString:@"-visible-action-natural-end"]];
    // Restore the explicit overview before checking its original inspection anchor.
    [self.app.buttons[@"grouping.viewMode"] tap];
    XCTAssertEqualWithAccuracy(board.frame.origin.y, inspectedFrame.origin.y, 1.0,
        @"Returning to inspection after Replay must keep the selected lower portion in view.");
    // Keep the existing separate quantity wait and its three-second bound.
    // Natural renderer completion is established above, never inferred from totals.
    [self waitForGroupingValues:settledValues];
    XCTAssertEqualWithAccuracy(board.frame.origin.y, inspectedFrame.origin.y, 1.0);
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    [self assertGroupingBoardVisible];
    [self assertGroupingControls];
    [self capture:name];
}
- (void)assertReturnedToUnansweredStory:(NSString *)story {
    XCUIElement *answer = self.app.buttons[@"answer.0"];
    XCTAssertTrue([answer waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(self.app.staticTexts[@"story.text"].label, story);
    for (NSUInteger index = 0; index < 4; index++) {
        NSString *identifier = [NSString stringWithFormat:@"answer.%lu", (unsigned long)index];
        XCUIElement *option = self.app.buttons[identifier];
        [self assertVisibleControl:option];
        XCTAssertTrue(option.enabled);
        XCTAssertFalse(option.selected);
        XCTAssertEqualObjects([option.value description], @"尚未作答");
    }
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
    XCTAssertFalse(self.app.buttons[@"grouping.next"].exists);
}

- (void)testStoryBoundsAndRemainderExplanation {
    [self launchScenario:@"remainder"];
    [self tapHomeCard:@"home.stories"];
    XCUIElement *grade = self.app.buttons[@"stories.grade.3"];
    XCTAssertTrue([grade waitForExistenceWithTimeout:5]);
    [self assertVisibleControl:grade];
    [grade tap];
    XCUIElement *story = self.app.staticTexts[@"story.text"];
    XCTAssertTrue([story waitForExistenceWithTimeout:5]);
    XCUIElement *content = self.app.scrollViews[@"practice.content"];
    [self assertHorizontalBounds:story in:content];
    if (content.frame.size.width < 500) XCTAssertGreaterThan(story.frame.size.height, 40.0);
    for (NSUInteger i = 0; i < 4; i++) {
        NSString *identifier = [NSString stringWithFormat:@"answer.%lu", (unsigned long)i];
        [self assertVisibleControl:self.app.buttons[identifier]];
    }
    [self capture:@"layout-01-story-and-answer-bounds"];
    [self.app.buttons[@"看怎麼算"] tap];
    XCUIElement *steps = self.app.staticTexts[@"explanation.steps"];
    XCTAssertTrue([steps waitForExistenceWithTimeout:5]);
    XCTAssertTrue([steps.label containsString:@"5 × 4 + 3 = 23"]);
    [self assertVisibleControl:self.app.buttons[@"explanation.close"]];
    [self reveal:steps in:self.app.scrollViews[@"explanation.content"] down:NO];
    [self capture:@"layout-02-remainder-text"];
    [self.app.buttons[@"explanation.close"] tap];
    XCUIElement *correct = [self.app.buttons matchingPredicate:[NSPredicate predicateWithFormat:
        @"identifier BEGINSWITH %@ AND label ENDSWITH %@", @"answer.", @"，5"]].firstMatch;
    [correct tap];
    [self reveal:self.app.buttons[@"session.next"] in:self.app.scrollViews[@"practice.feedback"] down:NO];
    [self.app.buttons[@"session.next"] tap];
    XCUIElement *summary = self.app.scrollViews[@"session.summary"];
    XCTAssertTrue([summary waitForExistenceWithTimeout:5]);
    [self assertHorizontalBounds:self.app.staticTexts[@"session.results"] in:summary];
    [self reveal:self.app.buttons[@"session.review"] in:summary down:NO];
    [self capture:@"layout-03-guided-summary"];
}

- (void)assertVerticalExchangeVisible {
    XCUIElement *exchange = [self element:@"verticalTeachingExchange"];
    XCUIElement *content = self.app.scrollViews[@"teaching.content"];
    CGRect action = [self checkedFrame:exchange];
    CGRect viewport = CGRectIntersection(content.frame, self.app.windows.firstMatch.frame);
    // Save actual geometry before an assertion can terminate the case. A fit
    // failure must be distinguished from a feasible action framed incorrectly.
    XCTAttachment *geometry = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
        @"uptime=%.6f action=%@ viewport=%@ usableViewport=%@ board=%@ heading=%@ narration=%@ progress=%@ actionValue=%@\ncontrollerObservations=%@",
        NSProcessInfo.processInfo.systemUptime, NSStringFromCGRect(action), NSStringFromCGRect(viewport),
        NSStringFromCGRect(CGRectInset(viewport, 0, 8)), NSStringFromCGRect([self element:@"verticalTeachingBoard"].frame),
        NSStringFromCGRect(self.app.staticTexts[@"teaching.heading"].frame), NSStringFromCGRect(self.app.staticTexts[@"explanation.steps"].frame),
        self.app.staticTexts[@"teaching.progress"].label, [exchange.value description], [content.value description]]];
    geometry.name = @"vertical-exchange-framing-observations";
    geometry.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:geometry];
    XCTAssertGreaterThan(action.size.height, 100.0);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(action), CGRectGetMinX(viewport) - 1);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(action), CGRectGetMaxX(viewport) + 1);
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(action), CGRectGetMinY(viewport) + 7);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(action), CGRectGetMaxY(viewport) - 7,
        @"The complete source, destination, movement region and written-column caption must fit, not merely 40 points of the board.");
}
- (void)assertVerticalFeedbackVisible {
    XCUIElement *feedback = self.app.staticTexts[@"teaching.feedback"];
    CGRect viewport = self.app.scrollViews[@"teaching.content"].frame;
    XCTAssertTrue(feedback.exists);
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(feedback.frame), CGRectGetMinY(viewport) + 7);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(feedback.frame), CGRectGetMaxY(viewport) - 7);
    [self assertHorizontalBounds:feedback in:self.app.scrollViews[@"teaching.content"]];
}
- (void)waitForVerticalNaturalCompletion {
    // No scroll, Back, resize, background or cancellation before this check.
    // The dedicated Settings suite owns static Reduce Motion acceptance. Normal
    // layout evidence must prove natural completion, never a static endpoint.
    NSPredicate *settled = [NSPredicate predicateWithFormat:@"value ENDSWITH %@", @"。動態已播放完成"];
    XCTestExpectation *completed = [self expectationForPredicate:settled
        evaluatedWithObject:[self element:@"verticalTeachingExchange"] handler:nil];
    [self waitForExpectations:@[completed] timeout:3];
}
- (void)rotateVerticalLandscape {
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationLandscapeLeft;
    NSPredicate *landscape = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        CGSize size = self.app.windows.firstMatch.frame.size;
        return size.width > size.height;
    }];
    XCTestExpectation *rotated = [self expectationForPredicate:landscape evaluatedWithObject:self.app handler:nil];
    [self waitForExpectations:@[rotated] timeout:5];
}
- (void)assertOriginalPracticeQuestionUnanswered:(NSString *)question {
    XCTAssertEqualObjects(self.app.staticTexts[@"practice.problem"].label, question);
    for (NSInteger index = 0; index < 4; index++) {
        NSString *identifier = [NSString stringWithFormat:@"answer.%ld", (long)index];
        XCUIElement *choice = self.app.buttons[identifier];
        XCTAssertTrue(choice.exists);
        XCTAssertTrue(choice.enabled);
        XCTAssertFalse(choice.selected);
        XCTAssertEqualObjects([choice.value description], @"尚未作答");
    }
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
}
- (void)testTeachingPredictionReplayAndLandscapeBounds {
    [self launchScenario:@"carry"];
    [self tapHomeCard:@"home.practice"];
    NSString *question = self.app.staticTexts[@"practice.problem"].label;
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    [self assertTeachingControls];
    [self capture:@"layout-04-place-value-alignment"];
    [self.app.buttons[@"teaching.next"] tap];
    XCUIElement *content = self.app.scrollViews[@"teaching.content"];
    XCUIElement *wrong = self.app.buttons[@"teaching.choice.11"];
    [self reveal:wrong in:content down:NO];
    NSString *predictionProgress = self.app.staticTexts[@"teaching.progress"].label;
    [wrong tap];
    [self capture:@"layout-05-wrong-prediction-before-helper"];
    [self assertVerticalFeedbackVisible];
    XCTAssertTrue([self.app.staticTexts[@"teaching.feedback"].label containsString:@"你選 11 個一"]);
    XCTAssertTrue([self.app.staticTexts[@"teaching.feedback"].label containsString:@"7 + 5"]);
    XCTAssertFalse(wrong.enabled);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, predictionProgress);
    [self.app.buttons[@"teaching.focus"] tap];
    XCTAssertEqualObjects(self.app.buttons[@"teaching.focus"].label, @"回到選項");
    [self.app.buttons[@"teaching.focus"] tap];
    XCUIElement *choice = self.app.buttons[@"teaching.choice.12"];
    [self reveal:choice in:content down:NO];
    [self assertHorizontalBounds:choice in:content];
    [choice tap];
    [self capture:@"layout-05-correct-prediction-before-helper"];
    [self assertVerticalFeedbackVisible];
    XCTAssertFalse(choice.enabled);
    XCTAssertEqualObjects([choice.value description], @"和這一步的數量相同");
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, predictionProgress);
    [self.app.buttons[@"teaching.next"] tap];
    [self.app.buttons[@"teaching.next"] tap];
    [self capture:@"layout-06-carry-first-play-before-helper"];
    XCUIElement *board = [self element:@"verticalTeachingBoard"];
    NSString *snapshot = [board.value description];
    NSString *progress = self.app.staticTexts[@"teaching.progress"].label;
    XCTAssertTrue([snapshot containsString:@"個位 12 → 2"]);
    XCTAssertTrue([snapshot containsString:@"答案還沒寫"]);
    [self assertHorizontalBounds:board in:content];
    [self assertTeachingControls];
    [self assertVerticalExchangeVisible];
    [self waitForVerticalNaturalCompletion];
    [self capture:@"layout-06-carry-naturally-completed"];
    [self.app.buttons[@"teaching.focus"] tap];
    [self capture:@"layout-07-written-work-inspection"];
    [self.app.buttons[@"teaching.replay"] tap];
    [self capture:@"layout-07-replay-recovers-entire-exchange-before-helper"];
    [self assertVerticalExchangeVisible];
    [self waitForVerticalNaturalCompletion];
    XCTAssertEqualObjects([board.value description], snapshot);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, progress);
    [self rotateVerticalLandscape];
    [self capture:@"layout-08-landscape-before-helper"];
    // Verify rotation itself recovered semantic focus before inspection or Replay
    // has any chance to repair a hidden exchange.
    [self assertVerticalExchangeVisible];
    XCTAssertFalse([[[self element:@"verticalTeachingExchange"].value description] containsString:@"正在交換"],
        @"Rotation may reframe the selected action but cannot silently replay it.");
    XCTAssertEqualObjects([board.value description], snapshot);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, progress);
    [self assertTeachingControls];
    [self assertHorizontalBounds:board in:content];
    [self.app.buttons[@"teaching.focus"] tap];
    [self capture:@"layout-08-landscape-written-inspection"];
    [self.app.buttons[@"teaching.replay"] tap];
    [self capture:@"layout-09-landscape-replay-before-helper"];
    [self assertVerticalExchangeVisible];
    [self waitForVerticalNaturalCompletion];
    [self capture:@"layout-09-landscape-naturally-completed"];
    XCTAssertEqualObjects([board.value description], snapshot);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, progress);
    [self.app.buttons[@"explanation.close"] tap];
    [self assertOriginalPracticeQuestionUnanswered:question];
    XCTAssertTrue(self.app.buttons[@"answer.0"].hittable);
}
- (void)testTwoZeroBorrowExchangesRemainVisibleAfterRotateAndReplay {
    [self launchScenario:@"borrow"];
    [self tapHomeCard:@"home.practice"];
    NSString *question = self.app.staticTexts[@"practice.problem"].label;
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    XCUIElement *content = self.app.scrollViews[@"teaching.content"];
    [self.app.buttons[@"teaching.next"] tap];
    XCUIElement *wrong = self.app.buttons[@"teaching.choice.1"];
    [self reveal:wrong in:content down:NO];
    [wrong tap];
    [self capture:@"borrow-01-first-wrong-prediction-before-helper"];
    [self assertVerticalFeedbackVisible];
    XCTAssertTrue([self.app.staticTexts[@"teaching.feedback"].label containsString:@"1 個百 = 10 個十"]);
    [self.app.buttons[@"teaching.next"] tap];
    [self capture:@"borrow-02-first-exchange-first-play-before-helper"];
    XCUIElement *board = [self element:@"verticalTeachingBoard"];
    NSString *firstSnapshot = [board.value description];
    NSString *firstProgress = self.app.staticTexts[@"teaching.progress"].label;
    XCTAssertTrue([firstSnapshot containsString:@"百位 5 → 4"]);
    XCTAssertTrue([firstSnapshot containsString:@"十位 0 → 10"]);
    XCTAssertFalse([firstSnapshot containsString:@"個位 0 → 10"]);
    XCTAssertTrue([firstSnapshot containsString:@"答案還沒寫"]);
    [self assertVerticalExchangeVisible];
    [self waitForVerticalNaturalCompletion];
    [self capture:@"borrow-03-first-exchange-naturally-completed"];
    [self.app.buttons[@"teaching.next"] tap];
    wrong = self.app.buttons[@"teaching.choice.1"];
    [self reveal:wrong in:content down:NO];
    [wrong tap];
    [self capture:@"borrow-04-second-wrong-prediction-before-helper"];
    [self assertVerticalFeedbackVisible];
    XCTAssertTrue([self.app.staticTexts[@"teaching.feedback"].label containsString:@"1 個十 = 10 個一"]);
    [self.app.buttons[@"teaching.next"] tap];
    [self capture:@"borrow-05-second-exchange-first-play-before-helper"];
    NSString *secondSnapshot = [board.value description];
    NSString *secondProgress = self.app.staticTexts[@"teaching.progress"].label;
    XCTAssertTrue([secondSnapshot containsString:@"十位 10 → 9"]);
    XCTAssertTrue([secondSnapshot containsString:@"個位 0 → 10"]);
    XCTAssertTrue([secondSnapshot containsString:@"答案還沒寫"]);
    [self assertVerticalExchangeVisible];
    [self waitForVerticalNaturalCompletion];
    [self capture:@"borrow-06-second-exchange-naturally-completed"];
    [self rotateVerticalLandscape];
    [self capture:@"borrow-07-landscape-before-helper"];
    [self.app.buttons[@"teaching.focus"] tap];
    [self.app.buttons[@"teaching.replay"] tap];
    [self capture:@"borrow-08-landscape-replay-before-helper"];
    [self assertVerticalExchangeVisible];
    [self waitForVerticalNaturalCompletion];
    XCTAssertEqualObjects([board.value description], secondSnapshot);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, secondProgress);
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertEqualObjects([board.value description], secondSnapshot);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, secondProgress);
    [self.app.buttons[@"teaching.previous"] tap];
    [self.app.buttons[@"teaching.previous"] tap];
    XCTAssertEqualObjects([board.value description], firstSnapshot);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, firstProgress);
    [self.app.buttons[@"teaching.replay"] tap];
    [self capture:@"borrow-09-first-exchange-back-and-replay-before-helper"];
    [self assertVerticalExchangeVisible];
    [self waitForVerticalNaturalCompletion];
    [self assertTeachingControls];
    [self.app.buttons[@"explanation.close"] tap];
    [self assertOriginalPracticeQuestionUnanswered:question];
}

- (void)testSettingsSelectionPersistsAndLastOperationStaysAvailable {
    [self.app.buttons[@"home.settings"] tap];
    XCUIElement *table = self.app.tables[@"settings.list"];
    XCTAssertTrue([table waitForExistenceWithTimeout:5]);
    // Establish a persisted opposite state so a broken save cannot pass because
    // Writing happened to be stored by an earlier test or interrupted run.
    XCUIElement *baseline = [self element:@"settings.answerMode.0"];
    [self reveal:baseline in:table down:YES];
    [baseline tap];
    [self.app.buttons[@"settings.done"] tap];
    [self.app terminate];
    [self.app launch];
    [self.app.buttons[@"home.settings"] tap];
    baseline = [self element:@"settings.answerMode.0"];
    XCTAssertEqualObjects([baseline.value description], @"目前使用");
    XCUIElement *writing = [self element:@"settings.answerMode.1"];
    [self reveal:writing in:table down:NO];
    XCTAssertTrue([writing.label containsString:@"不會辨識手寫"]);
    [writing tap];
    XCTAssertEqualObjects([writing.value description], @"目前使用");
    [self capture:@"layout-10-settings-writing-selection"];
    [self.app.buttons[@"settings.done"] tap];
    [self.app terminate];
    [self.app launch];
    [self.app.buttons[@"home.settings"] tap];
    writing = [self element:@"settings.answerMode.1"];
    [self reveal:writing in:table down:NO];
    XCTAssertEqualObjects([writing.value description], @"目前使用", @"Selection survives a real app relaunch.");
    XCUIElement *multipleChoice = [self element:@"settings.answerMode.0"];
    [self reveal:multipleChoice in:table down:YES];
    [multipleChoice tap];
    XCUIElement *tier = [self element:@"settings.tier.3"];
    [self reveal:tier in:table down:NO];
    [tier tap];
    XCTAssertEqualObjects([tier.value description], @"目前使用");
    [self capture:@"layout-11-settings-tier-selection"];
    for (NSUInteger operation = 0; operation < 4; operation++) {
        NSString *identifier = [NSString stringWithFormat:@"settings.operation.%lu", (unsigned long)operation];
        XCUIElement *toggle = self.app.switches[identifier];
        [self reveal:toggle in:table down:NO];
        BOOL enabled = [[toggle.value description] isEqualToString:@"1"];
        if (operation == 0 && !enabled) [toggle tap];
        if (operation > 0 && enabled) [toggle tap];
        XCTAssertEqualObjects([toggle.value description], operation == 0 ? @"1" : @"0");
    }
    XCUIElement *addition = self.app.switches[@"settings.operation.0"];
    [self reveal:addition in:table down:YES];
    XCTAssertEqualObjects([addition.value description], @"1");
    [addition tap];
    XCTAssertEqualObjects([addition.value description], @"1", @"A family cannot accidentally disable every operation.");
    [self capture:@"layout-12-settings-last-operation-guard"];
    [self.app.buttons[@"settings.done"] tap];
    // Wait for the real Home endpoint after the animated Settings dismissal.
    NSPredicate *homeReachable = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        XCUIElement *homeSettings = self.app.buttons[@"home.settings"];
        return homeSettings.exists && homeSettings.hittable;
    }];
    XCTestExpectation *returnedHome = [self expectationForPredicate:homeReachable
        evaluatedWithObject:self.app handler:nil];
    [self waitForExpectations:@[returnedHome] timeout:5];
    XCTAssertTrue(self.app.buttons[@"home.settings"].hittable);
    [self assertVisibleControl:self.app.buttons[@"home.settings"]];
}

- (void)testSharingPredictionTransferReplayAndCommonRemainder {
    NSString *story = [self openGroupingStory:@"sharing"];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"平均分給 4 個小朋友"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 4 個小朋友有 0 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分的糖果：23 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"layout-13-sharing-known-recipients"];
    [self.app.buttons[@"grouping.next"] tap]; // Index 1: optional prediction.
    XCUIElement *content = self.app.scrollViews[@"grouping.content"];
    XCUIElement *choice = self.app.buttons[@"grouping.choice.1"];
    [self reveal:choice in:content down:NO];
    [self assertHorizontalBounds:choice in:content];
    NSString *predictionProgress = self.app.staticTexts[@"grouping.progress"].label;
    [choice tap];
    XCTAssertFalse(choice.enabled);
    XCTAssertEqualObjects([choice.value description], @"對，想通這一步了");
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, predictionProgress);
    [self assertGroupingControls];
    [self capture:@"layout-14-sharing-child-prediction"];

    [self.app.buttons[@"grouping.next"] tap]; // Index 2: first real transfer.
    [self assertCompleteGroupingActionVisible];
    [self capture:@"layout-15-sharing-first-recipient-entry"];
    [self finishFocusedSharingRoundWatchingActions:YES];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"這一輪共分出 4 顆"]);
    // Do not scroll before recording the controller's first-play framing.
    // The existing native recording preserves before/mid/after, unmodified.
    [self assertGroupingBoardVisible];
    NSArray<NSString *> *firstRound = @[@"第 1 個小朋友有 1 顆", @"第 2 個小朋友有 1 顆",
        @"第 3 個小朋友有 1 顆", @"第 4 個小朋友有 1 顆", @"待分的糖果：19 顆", @"答案還沒寫"];
    [self waitForGroupingValues:firstRound];
    [self capture:@"layout-15-sharing-first-play-viewport"];
    [self captureGroupingBoardSlices:@"layout-16-sharing-first-round"];
    [self replayGroupingPreservingInspection:firstRound capture:@"layout-17-sharing-lower-replay-settled"];

    [self previousOriginalGroupingStep];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, predictionProgress);
    XCTAssertFalse(self.app.buttons[@"grouping.choice.1"].enabled);
    XCTAssertEqualObjects([self.app.buttons[@"grouping.choice.1"].value description], @"對，想通這一步了");
    [self.app.buttons[@"grouping.next"] tap]; // Back to index 2; other predictions may be skipped.
    for (NSUInteger step = 2; step < 11; step++) {
        [self finishFocusedSharingRoundWatchingActions:NO]; [self.app.buttons[@"grouping.next"] tap];
    }
    XCTAssertTrue([self.app.staticTexts[@"grouping.prompt"].label containsString:@"還能讓每個小朋友再拿 1 顆嗎"]);
    XCUIElement *notEnough = self.app.buttons[@"grouping.choice.0"];
    [self reveal:notEnough in:content down:NO];
    [self assertHorizontalBounds:notEnough in:content];
    [notEnough tap];
    XCTAssertEqualObjects([notEnough.value description], @"對，想通這一步了");
    [self.app.buttons[@"grouping.next"] tap]; // Index 12: one common remainder, not one per child.
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"不是每個小朋友各剩一份"]);
    [self waitForGroupingValues:@[@"第 1 個小朋友有 5 顆", @"第 2 個小朋友有 5 顆",
        @"第 3 個小朋友有 5 顆", @"第 4 個小朋友有 5 顆", @"待分的糖果：3 顆",
        @"共同剩下：3 顆糖果", @"這些還在待分區，不在任何一組裡", @"答案還沒寫"]];
    [self captureGroupingBoardSlices:@"layout-18-sharing-common-three-leftover"];
    [self.app.buttons[@"grouping.next"] tap]; // Index 13: answer uses the item unit.
    [self waitForGroupingValues:@[@"寫下：5 顆", @"共同剩下：3 顆糖果"]];
    XCTAssertFalse([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self captureGroupingBoardEnd:@"layout-19-sharing-answer-and-remainder-units"];
    [self.app.buttons[@"explanation.close"] tap];
    [self assertReturnedToUnansweredStory:story];
    [self capture:@"layout-20-sharing-returned-unanswered"];
}

- (void)testPackingSkippedPredictionTransferReplayAndAnswerUnits {
    NSString *story = [self openGroupingStory:@"packing"];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"每包要有 4 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"已分成 0 包"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分組的糖果：23 顆"]);
    XCTAssertFalse([self.groupingBoardValue containsString:@"第 1 包有"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"layout-21-packing-no-prefilled-bags"];
    [self.app.buttons[@"grouping.next"] tap]; // Index 1: deliberately leave the prediction unanswered.
    XCUIElement *choice = self.app.buttons[@"grouping.choice.1"];
    [self reveal:choice in:self.app.scrollViews[@"grouping.content"] down:NO];
    XCTAssertTrue(choice.enabled);
    XCTAssertEqualObjects([choice.value description], @"還沒選擇");
    XCTAssertEqualObjects(self.app.buttons[@"grouping.next"].label, @"先看示範");
    NSString *predictionProgress = self.app.staticTexts[@"grouping.progress"].label;
    [self capture:@"layout-22-packing-optional-prediction"];
    [self.app.buttons[@"grouping.next"] tap]; // Index 2: skipping still performs the actual transfer.
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"拿出糖果 4 顆"]);
    [self assertGroupingBoardVisible];
    NSArray<NSString *> *firstBag = @[@"已分成 1 包", @"第 1 包有 4 顆", @"待分組的糖果：19 顆", @"答案還沒寫"];
    [self assertCompleteGroupingActionVisible]; [self waitForGroupingActionNaturalEnd];
    [self waitForGroupingValues:firstBag];
    XCTAssertFalse([self.groupingBoardValue containsString:@"第 2 包有"]);
    [self capture:@"layout-23-packing-first-play-viewport"];
    [self captureGroupingBoardSlices:@"layout-24-packing-first-bag"];
    [self replayGroupingPreservingInspection:firstBag capture:@"layout-25-packing-lower-replay-settled"];
    XCTAssertFalse([self.groupingBoardValue containsString:@"第 2 包有"]);

    [self.app.buttons[@"grouping.previous"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, predictionProgress);
    XCTAssertTrue(self.app.buttons[@"grouping.choice.1"].enabled);
    XCTAssertEqualObjects([self.app.buttons[@"grouping.choice.1"].value description], @"還沒選擇");
    [self.app.buttons[@"grouping.next"] tap];
    for (NSUInteger step = 2; step < 12; step++) [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"不是完整的包"]);
    [self waitForGroupingValues:@[@"已分成 5 包", @"第 1 包有 4 顆", @"第 2 包有 4 顆",
        @"第 3 包有 4 顆", @"第 4 包有 4 顆", @"第 5 包有 4 顆", @"待分組的糖果：3 顆",
        @"共同剩下：3 顆糖果", @"答案還沒寫"]];
    XCTAssertFalse([self.groupingBoardValue containsString:@"第 6 包有"]);
    [self captureGroupingBoardSlices:@"layout-26-packing-five-bags-common-leftover"];
    [self.app.buttons[@"grouping.next"] tap]; // Index 13: bags are the answer, sweets are the remainder.
    [self waitForGroupingValues:@[@"寫下：5 包", @"共同剩下：3 顆糖果"]];
    XCTAssertFalse([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self captureGroupingBoardEnd:@"layout-27-packing-different-answer-and-remainder-units"];
    [self.app.buttons[@"grouping.next"] tap]; // Index 14: reconstruction.
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"正好是原來的糖果 23 顆"]);
    [self.app.buttons[@"grouping.next"] tap]; // Index 15: completion does not submit a practice answer.
    XCTAssertEqualObjects(self.app.buttons[@"grouping.next"].label, @"回到題目");
    [self assertGroupingControls];
    [self.app.buttons[@"grouping.next"] tap];
    [self assertReturnedToUnansweredStory:story];
    [self capture:@"layout-28-packing-completed-but-unanswered"];
}
@end
