#import <XCTest/XCTest.h>

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
        if (down) [container swipeDown];
        else [container swipeUp];
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
@end
