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
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)", @"-AppleLocale", @"zh_TW", @"-soundEffectsEnabled", @"NO"];
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
        if (element.exists) {
            XCUIElement *scrollTarget = element;
            if (container.elementType == XCUIElementTypeTable && element.elementType != XCUIElementTypeCell
                && element.identifier.length > 0) {
                // Offscreen table accessories can expose stale child frames.
                // Their containing row has the table's current layout position.
                XCUIElement *row = [container.cells containingType:XCUIElementTypeAny identifier:element.identifier].firstMatch;
                if (row.exists) scrollTarget = row;
            }
            CGRect target = scrollTarget.frame;
            BOOL hasGeometry = isfinite(target.origin.x) && isfinite(target.origin.y)
                && isfinite(target.size.width) && isfinite(target.size.height)
                && target.size.width > 0 && target.size.height > 0;
            if (hasGeometry) {
                // Recompute direction after EVERY drag. The requested direction
                // is only a hint for a virtualized element without geometry.
                // A broad swipe can pass a row; its new frame must bring us back.
                distance = CGRectGetMidY(target) - CGRectGetMidY(viewport);
                if (fabs(distance) < 1) distance = down ? -24 : 24;
            }
        }
        CGFloat travel = MIN(MAX(fabs(distance), 24), viewport.size.height * 0.3);
        CGFloat startY = CGRectGetMinY(viewport) + viewport.size.height * (distance > 0 ? 0.65 : 0.35);
        CGFloat endY = startY + (distance > 0 ? -travel : travel);
        XCUICoordinate *origin = [container coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
        CGFloat x = CGRectGetMidX(viewport) - CGRectGetMinX(containerFrame);
        XCUICoordinate *start = [origin coordinateWithOffset:CGVectorMake(x, startY - CGRectGetMinY(containerFrame))];
        XCUICoordinate *end = [origin coordinateWithOffset:CGVectorMake(x, endY - CGRectGetMinY(containerFrame))];
        [start pressForDuration:0.05 thenDragToCoordinate:end];
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
        [conditions addObject:[NSPredicate predicateWithFormat:@"value CONTAINS %@", fragment]];
    }
    [conditions addObject:[NSPredicate predicateWithFormat:@"NOT (value CONTAINS %@)", @"正在移動"]];
    NSPredicate *settled = [NSCompoundPredicate andPredicateWithSubpredicates:conditions];
    XCTestExpectation *ready = [self expectationForPredicate:settled
        evaluatedWithObject:[self element:@"groupingTeachingBoard"] handler:nil];
    [self waitForExpectations:@[ready] timeout:3];
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
- (void)captureGroupingBoardSlices:(NSString *)name {
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
    XCTAssertEqualWithAccuracy(board.frame.origin.y, inspectedFrame.origin.y, 1.0,
        @"Replay must keep the selected lower portion in view.");
    // Replay resets to before/moving counts for the real one-second animation.
    // A tap returning is not evidence that those quantities have settled.
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

- (void)testTeachingPredictionReplayAndLandscapeBounds {
    [self launchScenario:@"carry"];
    [self tapHomeCard:@"home.practice"];
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    [self assertTeachingControls];
    [self capture:@"layout-04-place-value-alignment"];
    [self.app.buttons[@"teaching.next"] tap];
    XCUIElement *content = self.app.scrollViews[@"teaching.content"];
    XCUIElement *choice = self.app.buttons[@"teaching.choice.12"];
    [self reveal:choice in:content down:NO];
    [self assertHorizontalBounds:choice in:content];
    NSString *predictionProgress = self.app.staticTexts[@"teaching.progress"].label;
    [choice tap];
    XCTAssertFalse(choice.enabled);
    XCTAssertEqualObjects([choice.value description], @"對，想通這一步了");
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, predictionProgress);
    [self capture:@"layout-05-child-prediction"];
    [self.app.buttons[@"teaching.next"] tap];
    [self.app.buttons[@"teaching.next"] tap];
    XCUIElement *board = [self element:@"verticalTeachingBoard"];
    XCTAssertTrue([[board.value description] containsString:@"個位 12 → 2"]);
    [self assertHorizontalBounds:board in:content];
    [self assertTeachingControls];
    [self capture:@"layout-06-carry-exchange"];
    CGRect beforeInspection = board.frame;
    BOOL needsScrolling = CGRectGetMaxY(self.app.buttons[@"teaching.restart"].frame) > CGRectGetMaxY(content.frame) + 1;
    [content swipeUp];
    CGRect inspectedFrame = board.frame;
    if (needsScrolling) XCTAssertLessThan(inspectedFrame.origin.y, beforeInspection.origin.y - 1);
    [self.app.buttons[@"teaching.replay"] tap];
    XCTAssertEqualWithAccuracy(board.frame.origin.y, inspectedFrame.origin.y, 1.0,
        @"Replay must preserve the part of the board the child scrolled to inspect.");
    [self capture:@"layout-07-replay-preserves-inspection"];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationLandscapeLeft;
    NSPredicate *landscape = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        CGSize size = self.app.windows.firstMatch.frame.size;
        return size.width > size.height;
    }];
    XCTestExpectation *rotated = [self expectationForPredicate:landscape evaluatedWithObject:self.app handler:nil];
    [self waitForExpectations:@[rotated] timeout:5];
    [self assertTeachingControls];
    [self assertHorizontalBounds:board in:content];
    [self capture:@"layout-08-landscape-teaching"];
    [self reveal:board in:content down:NO];
    CGRect visibleBoard = CGRectIntersection(board.frame, content.frame);
    XCTAssertGreaterThan(visibleBoard.size.height, 40.0);
    CGFloat landscapeBoardY = board.frame.origin.y;
    [self.app.buttons[@"teaching.replay"] tap];
    XCTAssertEqualWithAccuracy(board.frame.origin.y, landscapeBoardY, 1.0);
    [self capture:@"layout-09-landscape-inspect-and-replay"];
    [self.app.buttons[@"explanation.close"] tap];
    XCTAssertTrue(self.app.buttons[@"answer.0"].hittable);
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
    XCTAssertTrue(self.app.buttons[@"home.settings"].hittable);
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

    [self.app.buttons[@"grouping.previous"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, predictionProgress);
    XCTAssertFalse(self.app.buttons[@"grouping.choice.1"].enabled);
    XCTAssertEqualObjects([self.app.buttons[@"grouping.choice.1"].value description], @"對，想通這一步了");
    [self.app.buttons[@"grouping.next"] tap]; // Back to index 2; other predictions may be skipped.
    for (NSUInteger step = 2; step < 11; step++) [self.app.buttons[@"grouping.next"] tap];
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
