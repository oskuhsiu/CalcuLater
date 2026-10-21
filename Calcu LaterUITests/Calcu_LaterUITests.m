#import <XCTest/XCTest.h>
#import <math.h>

/// Native tap flows with screenshots and accessibility trees at each checkpoint.
@interface Calcu_LaterUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation Calcu_LaterUITests

- (void)setUp {
    self.continueAfterFailure = NO;
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    self.app = [[XCUIApplication alloc] init];
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)",
                                @"-AppleLocale", @"zh_TW",
                                @"-soundEffectsEnabled", @"NO"];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
}

- (void)tearDown {
    if (self.testRun.failureCount > 0) {
        XCTAttachment *screen = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
        screen.name = [@"native-failure-" stringByAppendingString:self.name];
        screen.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:screen];
        XCTAttachment *tree = [XCTAttachment attachmentWithString:self.app.debugDescription];
        tree.name = @"native-failure-hierarchy";
        tree.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:tree];
    }
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

- (void)tapHomeCard:(NSString *)identifier {
    XCUIElement *card = self.app.buttons[identifier];
    XCTAssertTrue([card waitForExistenceWithTimeout:5]);
    if (!card.hittable) [self.app.scrollViews.firstMatch swipeUp];
    XCTAssertTrue(card.hittable, @"The home card must be reachable by scrolling.");
    [card tap];
}

- (void)testHomeSettingsAndReturn {
    [self capture:@"01-home"];
    [self.app.buttons[@"home.settings"] tap];
    XCTAssertTrue([self.app.navigationBars[@"設定"] waitForExistenceWithTimeout:5]);
    [self capture:@"02-settings"];
    [self.app.buttons[@"完成"] tap];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue(self.app.buttons[@"home.settings"].hittable);
}

- (void)testLessonIntroAndPractice {
    [self tapHomeCard:@"home.lessons"];
    XCTAssertTrue([self.app.collectionViews.firstMatch waitForExistenceWithTimeout:5]);
    [self capture:@"03-lessons"];
    [self.app.collectionViews.cells.firstMatch tap];
    XCTAssertTrue([self.app.buttons[@"開始練習"] waitForExistenceWithTimeout:5]);
    [self capture:@"04-lesson-intro"];
    [self.app.buttons[@"開始練習"] tap];
    XCTAssertTrue([self.app.staticTexts[@"lesson.problem"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue(self.app.buttons[@"answer.0"].hittable);
    [self capture:@"05-lesson-question"];
    [self.app.buttons[@"看怎麼算"] tap];
    [self capture:@"06-lesson-hint"];
    XCUIElement *vertical = self.app.buttons[@"explanation.vertical"];
    XCTAssertTrue(vertical.hittable);
    [vertical tap];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    XCUIElement *teaching = [self.app descendantsMatchingType:XCUIElementTypeAny][@"teaching.screen"];
    XCTAssertTrue(teaching.exists);
    [teaching.buttons[@"explanation.close"] tap];
    XCTAssertTrue(self.app.buttons[@"answer.0"].hittable, @"Return from nested teaching goes back to the question.");
    [self leavePractice:@"lesson.close"];
    XCTAssertTrue([self.app.collectionViews.firstMatch waitForExistenceWithTimeout:5]);
    [self.app.buttons[@"navigation.home"] tap];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:5]);
}

- (void)leavePractice:(NSString *)identifier {
    [self.app.buttons[identifier] tap];
    XCUIElement *pause = self.app.alerts.buttons[@"先休息"];
    if ([pause waitForExistenceWithTimeout:2]) [pause tap];
}

- (void)relaunchScenario:(NSString *)scenario {
    [self.app terminate];
    self.app.launchArguments = [self.app.launchArguments arrayByAddingObjectsFromArray:@[@"-CalcuLaterScenario", scenario,
        @"-drillTier", [scenario isEqualToString:@"borrow"] ? @"3" : @"2"]];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
}

- (void)testRemainderExplanationAndChildPacedCompletion {
    [self relaunchScenario:@"remainder"];
    [self tapHomeCard:@"home.stories"];
    [self.app.buttons[@"stories.grade.3"] tap];
    XCTAssertTrue([self.app.staticTexts[@"story.text"] waitForExistenceWithTimeout:5]);
    NSString *story = self.app.staticTexts[@"story.text"].label;
    CGRect storyFrame = self.app.staticTexts[@"story.text"].frame;
    CGRect contentFrame = self.app.scrollViews[@"practice.content"].frame;
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(storyFrame), CGRectGetMinX(contentFrame));
    XCTAssertLessThanOrEqual(CGRectGetMaxX(storyFrame), CGRectGetMaxX(contentFrame));
    XCTAssertGreaterThan(storyFrame.size.height, 40.0, @"The full fixture story must wrap, not truncate to one line.");
    [self.app.buttons[@"看怎麼算"] tap];
    XCUIElement *steps = self.app.staticTexts[@"explanation.steps"];
    XCTAssertTrue([steps waitForExistenceWithTimeout:5]);
    XCTAssertTrue([steps.label containsString:@"5 × 4 + 3 = 23"]);
    XCTAssertFalse([steps.label containsString:@"5 × 4 = 23"]);
    [self capture:@"13-remainder-teaching"];
    [self.app.buttons[@"explanation.close"] tap];
    XCUIElement *answer = [self.app.buttons matchingPredicate:[NSPredicate predicateWithFormat:
        @"identifier BEGINSWITH %@ AND label ENDSWITH %@", @"answer.", @"，5"]].firstMatch;
    XCTAssertTrue(answer.hittable);
    [answer tap];
    XCTAssertTrue([self.app.buttons[@"session.next"] waitForExistenceWithTimeout:5]);
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertEqualObjects(self.app.staticTexts[@"story.text"].label, story);
    XCTAssertTrue(self.app.buttons[@"session.next"].hittable);
    [self capture:@"14-remainder-persistent-answer"];
    [self.app.buttons[@"session.next"] tap];
    XCTAssertTrue([self.app.scrollViews[@"session.summary"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue([self.app.staticTexts[@"session.results"].label containsString:@"一起學會  1 題"]);
    XCTAssertTrue(self.app.buttons[@"session.review"].exists);
    [self capture:@"15-session-summary"];
    [self.app.buttons[@"session.review"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"story.text"].label, story);
    XCTAssertTrue([self.app.staticTexts[@"session.progress"].label containsString:@"再練一次"]);
}

- (void)testFractionDiagramAndLandscapeBorrowing {
    [self relaunchScenario:@"fraction"];
    [self tapHomeCard:@"home.stories"];
    [self.app.buttons[@"stories.grade.3"] tap];
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.staticTexts[@"explanation.steps"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue([self.app.staticTexts[@"explanation.steps"].label containsString:@"4 等份"]);
    [self capture:@"16-equal-parts-fraction"];
    [self.app.buttons[@"explanation.close"] tap];
    [self leavePractice:@"story.close"];
    [self.app.buttons[@"navigation.home"] tap];
    [self.app terminate];
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)", @"-AppleLocale", @"zh_TW",
        @"-soundEffectsEnabled", @"NO", @"-drillTier", @"3", @"-CalcuLaterScenario", @"borrow"];
    [self.app launch];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationLandscapeLeft;
    [self tapHomeCard:@"home.practice"];
    XCTAssertTrue([self.app.staticTexts[@"practice.problem"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue(self.app.buttons[@"answer.0"].hittable);
    [self capture:@"17-landscape-practice"];
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"explanation.close"] waitForExistenceWithTimeout:5]);
    [self capture:@"18-borrow-across-zero"];
    [self.app.buttons[@"explanation.close"] tap];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
}

- (NSInteger)answerForEquation:(NSString *)text {
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:
        @"^([0-9]+)\\s*([+−×÷-])\\s*([0-9]+)" options:0 error:nil];
    NSTextCheckingResult *match = [pattern firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    XCTAssertNotNil(match, @"Expected a visible arithmetic question, got %@", text);
    NSInteger a = [[text substringWithRange:[match rangeAtIndex:1]] integerValue];
    NSString *op = [text substringWithRange:[match rangeAtIndex:2]];
    NSInteger b = [[text substringWithRange:[match rangeAtIndex:3]] integerValue];
    if ([op isEqualToString:@"+"]) return a + b;
    if ([op isEqualToString:@"×"]) return a * b;
    if ([op isEqualToString:@"÷"]) return a / b;
    return a - b;
}

- (void)testDrillWrongHintCorrectAndExit {
    [self tapHomeCard:@"home.practice"];
    XCUIElement *question = self.app.staticTexts[@"practice.problem"];
    XCTAssertTrue([question waitForExistenceWithTimeout:5]);
    NSInteger answer = [self answerForEquation:question.label];
    [self capture:@"07-practice-question"];
    NSInteger wrongCount = 0;
    XCUIElement *correct = nil;
    for (NSInteger index = 0; index < 4; index++) {
        XCUIElement *choice = self.app.buttons[[NSString stringWithFormat:@"answer.%ld", (long)index]];
        XCTAssertTrue(choice.hittable);
        NSPredicate *enabled = [NSPredicate predicateWithFormat:@"enabled == YES"];
        XCTestExpectation *ready = [self expectationForPredicate:enabled evaluatedWithObject:choice handler:nil];
        [self waitForExpectations:@[ready] timeout:5];
        NSString *visibleAnswer = [choice.label componentsSeparatedByString:@"，"].lastObject;
        if (visibleAnswer.integerValue == answer) {
            correct = choice;
        } else if (wrongCount < 2) {
            [choice tap];
            XCTAssertFalse(choice.enabled);
            wrongCount++;
            if (wrongCount == 2) {
                XCTAssertTrue([self.app.buttons[@"explanation.close"] waitForExistenceWithTimeout:5]);
                [self capture:@"08-practice-help-sheet"];
                [self.app.buttons[@"explanation.close"] tap];
            }
        }
    }
    XCTAssertEqual(wrongCount, 2);
    XCTAssertNotNil(correct);
    [self capture:@"08-practice-after-two-misses"];
    NSPredicate *enabled = [NSPredicate predicateWithFormat:@"enabled == YES"];
    XCTestExpectation *ready = [self expectationForPredicate:enabled evaluatedWithObject:correct handler:nil];
    [self waitForExpectations:@[ready] timeout:5];
    [correct tap];
    NSPredicate *streak = [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"連對 ×1"];
    XCTestExpectation *updated = [self expectationForPredicate:streak
        evaluatedWithObject:self.app.staticTexts[@"practice.streak"] handler:nil];
    [self waitForExpectations:@[updated] timeout:5];
    [self capture:@"09-practice-correct"];
    [self leavePractice:@"practice.close"];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:5]);
}

- (void)testStoryReadEquationHintAndReturn {
    [self tapHomeCard:@"home.stories"];
    XCTAssertTrue([self.app.buttons[@"stories.grade.1"] waitForExistenceWithTimeout:5]);
    [self capture:@"10-story-grades"];
    [self.app.buttons[@"stories.grade.1"] tap];
    XCTAssertTrue([self.app.staticTexts[@"story.text"] waitForExistenceWithTimeout:5]);
    XCTAssertGreaterThan(self.app.staticTexts[@"story.text"].label.length, 10);
    [self capture:@"11-story-question"];
    [self.app.buttons[@"🧮 看算式"] tap];
    XCTAssertTrue([self.app.staticTexts[@"story.equation"] waitForExistenceWithTimeout:5]);
    [self.app.buttons[@"看怎麼算"] tap];
    [self capture:@"12-story-hint"];
    [self.app.buttons[@"explanation.close"] tap];
    [self leavePractice:@"story.close"];
    XCTAssertTrue([self.app.buttons[@"stories.grade.1"] waitForExistenceWithTimeout:5]);
    [self.app.buttons[@"navigation.home"] tap];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:5]);
}

- (void)openTeachingScenario:(NSString *)scenario {
    [self relaunchScenario:scenario];
    [self tapHomeCard:@"home.practice"];
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue(self.app.buttons[@"teaching.previous"].hittable);
    XCTAssertTrue(self.app.buttons[@"teaching.replay"].hittable);
}

- (NSString *)teachingBoardValue {
    XCUIElement *board = [self.app descendantsMatchingType:XCUIElementTypeAny][@"verticalTeachingBoard"];
    XCTAssertTrue([board waitForExistenceWithTimeout:5]);
    return [board.value description];
}

- (void)testCarryTeachingPredictionReplayAndReturn {
    [self openTeachingScenario:@"carry"];
    XCTAssertFalse(self.app.buttons[@"teaching.previous"].enabled);
    XCTAssertTrue([[self teachingBoardValue] containsString:@"答案還沒寫"]);
    [self capture:@"20-carry-aligned-place-values"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"7 + 5"]);
    NSString *predictionProgress = self.app.staticTexts[@"teaching.progress"].label;
    XCUIElement *wrong = self.app.buttons[@"teaching.choice.11"];
    XCUIElement *correct = self.app.buttons[@"teaching.choice.12"];
    XCTAssertTrue(wrong.hittable);
    XCTAssertTrue(correct.hittable);
    [wrong tap];
    XCTAssertFalse(wrong.enabled);
    XCTAssertTrue([self.app.staticTexts[@"teaching.feedback"].label containsString:@"不計分"]);
    [correct tap];
    XCTAssertFalse(correct.enabled);
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, predictionProgress,
        @"Prediction never advances the teaching step without the learner.");
    XCTAssertTrue([[self teachingBoardValue] containsString:@"答案還沒寫"]);
    [self capture:@"21-carry-child-prediction"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"explanation.steps"].label containsString:@"7 + 5 = 12"]);
    [self capture:@"22-carry-twelve-ones-before-exchange"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([[self teachingBoardValue] containsString:@"個位 12 → 2"]);
    XCTAssertTrue([[self teachingBoardValue] containsString:@"十位 2 → 3"]);
    XCTAssertTrue([[self teachingBoardValue] containsString:@"答案還沒寫"]);
    [self capture:@"23-carry-ten-ones-become-one-ten"];
    NSString *regroupProgress = self.app.staticTexts[@"teaching.progress"].label;
    NSString *regroupValue = [self teachingBoardValue];
    [self.app.buttons[@"teaching.replay"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, regroupProgress);
    XCTAssertEqualObjects([self teachingBoardValue], regroupValue);
    [self.app.buttons[@"teaching.previous"] tap];
    XCTAssertTrue([self.app.staticTexts[@"explanation.steps"].label containsString:@"7 + 5 = 12"]);
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertEqualObjects([self teachingBoardValue], regroupValue);
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([[self teachingBoardValue] containsString:@"個位寫 2"]);
    XCTAssertFalse([[self teachingBoardValue] containsString:@"十位寫 4"]);
    [self capture:@"24-carry-only-ones-written"];
    for (NSUInteger i = 0; i < 4; i++) [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"explanation.steps"].label containsString:@"27 + 15 = 42"]);
    [self capture:@"25-carry-complete"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"practice.problem"].label, @"27 + 15 = ?");
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
    XCTAssertTrue(self.app.buttons[@"answer.0"].hittable);
}

- (void)testBorrowAcrossZeroUsesTwoInspectableExchanges {
    [self openTeachingScenario:@"borrow"];
    [self capture:@"26-borrow-five-hundreds-before-exchange"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"1 個百"]);
    [self.app.buttons[@"teaching.choice.10"] tap];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([[self teachingBoardValue] containsString:@"百位 5 → 4"]);
    XCTAssertTrue([[self teachingBoardValue] containsString:@"十位 0 → 10"]);
    XCTAssertTrue([[self teachingBoardValue] containsString:@"答案還沒寫"]);
    [self capture:@"27-borrow-one-hundred-becomes-ten-tens"];
    [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"1 個十"]);
    [self.app.buttons[@"teaching.next"] tap]; // Optional participation: choosing demonstration is valid.
    XCTAssertTrue([[self teachingBoardValue] containsString:@"十位 10 → 9"]);
    XCTAssertTrue([[self teachingBoardValue] containsString:@"個位 0 → 10"]);
    [self capture:@"28-borrow-one-ten-becomes-ten-ones"];
    NSString *value = [self teachingBoardValue];
    [self.app.buttons[@"teaching.replay"] tap];
    XCTAssertEqualObjects([self teachingBoardValue], value);
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertEqualObjects([self teachingBoardValue], value);
    XCTAssertTrue(self.app.buttons[@"teaching.next"].hittable);
    [self.app.buttons[@"teaching.previous"] tap];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"1 個十"]);
    [self.app.buttons[@"teaching.next"] tap];
    for (NSUInteger i = 0; i < 10; i++) [self.app.buttons[@"teaching.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"explanation.steps"].label containsString:@"500 − 128 = 372"]);
    [self capture:@"29-borrow-complete-with-conserved-place-value"];
    [self.app.buttons[@"explanation.close"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"practice.problem"].label, @"500 − 128 = ?");
    XCTAssertTrue(self.app.buttons[@"answer.0"].hittable);
}

// These use explicit producer metadata, unlike the legacy remainder fixture above.
// The same equation must teach two different questions, not two copies of one picture.
- (void)openGroupingStory:(NSString *)scenario {
    [self relaunchScenario:scenario];
    [self tapHomeCard:@"home.stories"];
    [self.app.buttons[@"stories.grade.3"] tap];
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"grouping.next"] waitForExistenceWithTimeout:5]);
    XCTAssertFalse(self.app.buttons[@"grouping.changeMeaning"].exists,
        @"A story's meaning is fixed by what it asks, not a learner switch.");
}
- (NSString *)groupingBoardValue {
    XCUIElement *board = [self.app descendantsMatchingType:XCUIElementTypeAny][@"groupingTeachingBoard"];
    return [board.value description];
}
- (void)waitForGroupingValue:(NSString *)expected {
    XCUIElement *board = [self.app descendantsMatchingType:XCUIElementTypeAny][@"groupingTeachingBoard"];
    NSPredicate *settled = [NSPredicate predicateWithFormat:@"value CONTAINS %@", expected];
    XCTestExpectation *ready = [self expectationForPredicate:settled evaluatedWithObject:board handler:nil];
    [self waitForExpectations:@[ready] timeout:3];
}
- (void)frameBoardForInspection:(XCUIElement *)board in:(XCUIElement *)content {
    for (NSUInteger attempt = 0; attempt < 8; attempt++) {
        CGRect before = board.frame, viewport = content.frame;
        XCTAssertTrue(isfinite(before.origin.y) && isfinite(before.size.height)
            && isfinite(viewport.origin.y) && isfinite(viewport.size.height));
        XCTAssertGreaterThan(viewport.size.height, 44);
        // Do not disturb a complete first-play diagram just to align its top.
        if (CGRectContainsRect(viewport, before)) break;
        CGFloat delta;
        if (before.size.height <= viewport.size.height) {
            // Correct only the clipped edge of a board that can fit in full.
            delta = CGRectGetMinY(before) < CGRectGetMinY(viewport)
                ? CGRectGetMinY(before) - CGRectGetMinY(viewport)
                : MAX(0, CGRectGetMaxY(before) - CGRectGetMaxY(viewport));
            if (fabs(delta) < 1) break;
        } else {
            // Tall boards need their top framed, not merely a hittable legend.
            delta = CGRectGetMinY(before) - CGRectGetMinY(viewport) - 8;
            if (fabs(delta) < 12) break;
        }
        CGFloat distance = MIN(fabs(delta), viewport.size.height * 0.35);
        CGFloat startY = delta > 0 ? 0.7 : 0.3;
        CGFloat endY = startY + (delta > 0 ? -1 : 1) * distance / viewport.size.height;
        XCUICoordinate *start = [content coordinateWithNormalizedOffset:CGVectorMake(0.5, startY)];
        XCUICoordinate *end = [content coordinateWithNormalizedOffset:CGVectorMake(0.5, endY)];
        CGPoint startPoint = start.screenPoint, endPoint = end.screenPoint;
        // The old default-velocity, zero-hold drag overshot and oscillated.
        // This hold is part of the touch gesture, not a post-action sleep.
        [start pressForDuration:0.05 thenDragToCoordinate:end
            withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
        CGRect after = board.frame;
        CGFloat measured = CGRectGetMinY(before) - CGRectGetMinY(after);
        NSString *measurement = [NSString stringWithFormat:
            @"attempt=%lu; requestedScroll=%.2f; boundedScroll=%.2f; measuredScroll=%.2f; "
             "before=%@; after=%@; viewportBefore=%@; viewportAfter=%@; touchStart=%@; touchEnd=%@",
            (unsigned long)(attempt + 1), delta, copysign(distance, delta), measured,
            NSStringFromCGRect(before), NSStringFromCGRect(after), NSStringFromCGRect(viewport),
            NSStringFromCGRect(content.frame), NSStringFromCGPoint(startPoint), NSStringFromCGPoint(endPoint)];
        XCTAttachment *trace = [XCTAttachment attachmentWithString:measurement];
        trace.name = [board.identifier stringByAppendingString:@"-inspection-scroll"];
        trace.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:trace];
    }
}
- (void)inspectGroupingBoard {
    XCUIElement *board = [self.app descendantsMatchingType:XCUIElementTypeAny][@"groupingTeachingBoard"];
    XCUIElement *content = self.app.scrollViews[@"grouping.content"];
    XCTAssertTrue(board.exists);
    XCTAssertTrue(content.exists);
    CGRect viewport = content.frame;
    CGRect boardFrame = board.frame;
    XCTAssertTrue(isfinite(viewport.origin.x) && isfinite(viewport.origin.y)
        && isfinite(viewport.size.width) && isfinite(viewport.size.height));
    XCTAssertTrue(isfinite(boardFrame.origin.x) && isfinite(boardFrame.origin.y)
        && isfinite(boardFrame.size.width) && isfinite(boardFrame.size.height));
    XCTAssertGreaterThan(viewport.size.width, 44);
    XCTAssertGreaterThan(viewport.size.height, 44);
    XCTAssertGreaterThan(boardFrame.size.width, 44);
    XCTAssertGreaterThan(boardFrame.size.height, 44);
    [self frameBoardForInspection:board in:content];
    XCTAssertTrue(board.hittable);
    CGRect visible = CGRectIntersection(board.frame, content.frame);
    XCTAssertFalse(CGRectIsNull(visible));
    XCTAssertGreaterThan(visible.size.width, 0);
    XCTAssertGreaterThan(visible.size.height, 0);
    XCTAssertGreaterThanOrEqual(visible.size.height, MIN(board.frame.size.height, content.frame.size.height) - 24);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(board.frame), CGRectGetMaxX(content.frame) + 1);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(board.frame), CGRectGetMinX(content.frame) - 1);
    [self.app.buttons[@"grouping.replay"] tap];
}
- (void)testSharedRemainderLeavesOneCommonPool {
    [self openGroupingStory:@"sharing"];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"平均分給 4 個小朋友"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 4 個小朋友有 0 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分的糖果：23 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"30-sharing-known-recipients"];
    [self.app.buttons[@"grouping.next"] tap];
    XCUIElement *choice = self.app.buttons[@"grouping.choice.1"];
    XCTAssertTrue(choice.hittable);
    NSString *progress = self.app.staticTexts[@"grouping.progress"].label;
    [choice tap];
    XCTAssertFalse(choice.enabled);
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"這一輪共分出 4 顆"]);
    [self inspectGroupingBoard];
    [self waitForGroupingValue:@"第 4 個小朋友有 1 顆"];
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 4 個小朋友有 1 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分的糖果：19 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"31-sharing-one-each"];
    [self.app.buttons[@"grouping.previous"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    XCTAssertFalse(self.app.buttons[@"grouping.choice.1"].enabled);
    [self.app.buttons[@"grouping.next"] tap];
    for (NSUInteger step = 2; step < 11; step++) [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.prompt"].label containsString:@"還能讓每個小朋友再拿 1 顆嗎"]);
    [self.app.buttons[@"grouping.choice.0"] tap];
    XCTAssertEqualObjects([self.app.buttons[@"grouping.choice.0"].value description], @"對，想通這一步了");
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"不是每個小朋友各剩一份"]);
    [self inspectGroupingBoard];
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 4 個小朋友有 5 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分的糖果：3 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"32-sharing-common-three-leftover"];
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"最多有 5 顆"]);
    [self capture:@"33-sharing-answer-unit"];
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertTrue(self.app.buttons[@"grouping.next"].hittable);
    [self.app.buttons[@"explanation.close"] tap];
    XCTAssertTrue(self.app.buttons[@"answer.0"].enabled);
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
}
- (void)testPackingCreatesGroupsInsteadOfPrefillingTheQuotient {
    [self openGroupingStory:@"packing"];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"每包要有 4 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"已分成 0 包"]);
    XCTAssertFalse([self.groupingBoardValue containsString:@"第 1 包有"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"34-packing-starts-with-pool"];
    [self.app.buttons[@"grouping.next"] tap];
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"拿出糖果 4 顆"]);
    [self inspectGroupingBoard];
    [self waitForGroupingValue:@"第 1 包有 4 顆"];
    XCTAssertTrue([self.groupingBoardValue containsString:@"已分成 1 包"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 1 包有 4 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分組的糖果：19 顆"]);
    XCTAssertFalse([self.groupingBoardValue containsString:@"第 2 包有"]);
    [self capture:@"35-packing-first-complete-bag"];
    for (NSUInteger step = 2; step < 12; step++) [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"不是完整的包"]);
    [self inspectGroupingBoard];
    XCTAssertTrue([self.groupingBoardValue containsString:@"已分成 5 包"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 5 包有 4 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分組的糖果：3 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"36-packing-five-bags-three-items"];
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"可以分成 5 包"]);
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"正好是原來的糖果 23 顆"]);
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertEqualObjects(self.app.buttons[@"grouping.next"].label, @"回到題目");
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue(self.app.buttons[@"answer.0"].enabled);
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
}
- (void)testMultiplicationBuildsOneKnownGroupAtATime {
    [self openGroupingStory:@"groups"];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"每包的糖果有 3 顆"]);
    [self capture:@"37-multiplication-known-groups"];
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue(self.app.buttons[@"grouping.choice.3"].hittable);
    [self.app.buttons[@"grouping.choice.3"] tap];
    [self.app.buttons[@"grouping.next"] tap];
    [self inspectGroupingBoard];
    [self waitForGroupingValue:@"第 1 包有 3 顆"];
    XCTAssertTrue([self.groupingBoardValue containsString:@"已建立 1 包"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"還有 3 包尚未建立"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"38-multiplication-one-group"];
    for (NSUInteger step = 2; step < 9; step++) [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"一共有 12 顆"]);
    [self inspectGroupingBoard];
    [self capture:@"39-multiplication-total-written"];
    [self.app.buttons[@"explanation.close"] tap];
    XCTAssertTrue(self.app.buttons[@"answer.0"].enabled);
}
- (void)testBareDivisionCanCompareTwoExplicitMeanings {
    [self relaunchScenario:@"division-meanings"];
    [self tapHomeCard:@"home.practice"];
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"grouping.next"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"平均分給 3 組"]);
    XCUIElement *change = self.app.buttons[@"grouping.changeMeaning"];
    XCUIElement *scroll = self.app.scrollViews[@"grouping.content"];
    for (NSUInteger attempt = 0; attempt < 8 && !change.hittable; attempt++) [scroll swipeUp];
    XCTAssertTrue(change.hittable);
    [change tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"每組要有 3 個"]);
    XCTAssertTrue([self.app.staticTexts[@"grouping.progress"].label containsString:@"第 1 小步"]);
    [self capture:@"40-same-division-different-question"];
    [self.app.buttons[@"explanation.close"] tap];
    XCTAssertTrue(self.app.buttons[@"answer.0"].enabled);
}

// Actual-question ten-frame acceptance flows. Fixtures are launch-only and
// restricted to the matching lesson kind in PracticeViewController.
- (NSString *)openTenFrameLesson:(NSString *)title scenario:(NSString *)scenario {
    [self relaunchScenario:scenario];
    [self tapHomeCard:@"home.lessons"];
    XCUIElement *collection = self.app.collectionViews.firstMatch;
    XCTAssertTrue([collection waitForExistenceWithTimeout:5]);
    XCUIElement *lesson = self.app.staticTexts[title];
    for (NSUInteger attempt = 0; attempt < 5 && !lesson.hittable; attempt++) [collection swipeUp];
    XCTAssertTrue(lesson.hittable);
    [lesson tap];
    XCTAssertTrue([self.app.buttons[@"lessonIntro.start"] waitForExistenceWithTimeout:5]);
    [self.app.buttons[@"lessonIntro.start"] tap];
    XCUIElement *question = self.app.staticTexts[@"lesson.problem"];
    XCTAssertTrue([question waitForExistenceWithTimeout:5]);
    NSString *equation = question.label;
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"lessonIntro.next"] waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, equation);
    XCTAssertFalse(self.app.staticTexts[@"explanation.steps"].exists, @"No full-answer text may accompany the strategy.");
    XCTAssertFalse(self.app.buttons[@"explanation.replay"].exists, @"Replay belongs to the current step, not a second footer.");
    return equation;
}
- (NSString *)tenFrameStageValue {
    XCUIElement *stage = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"];
    XCTAssertTrue([stage waitForExistenceWithTimeout:5]);
    return [stage.value description];
}
- (void)inspectTenFrameStage {
    XCUIElement *stage = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"];
    XCUIElement *scroll = self.app.scrollViews[@"lessonIntro.content"];
    XCTAssertTrue(stage.exists);
    XCTAssertTrue(scroll.exists);
    CGRect viewport = scroll.frame, board = stage.frame;
    XCTAssertTrue(isfinite(viewport.origin.y) && isfinite(viewport.size.height)
        && isfinite(board.origin.y) && isfinite(board.size.height));
    XCTAssertGreaterThan(viewport.size.height, 44);
    // Both the stacked and side-by-side layouts retain two full ten-frame rows.
    XCTAssertGreaterThan(board.size.height, 100);
    XCTAssertGreaterThan(board.size.width, 160);
    [self frameBoardForInspection:stage in:scroll];
    CGRect visible = CGRectIntersection(stage.frame, scroll.frame);
    XCTAssertFalse(CGRectIsNull(visible));
    XCTAssertGreaterThan(visible.size.height, 0);
    XCTAssertGreaterThanOrEqual(visible.size.height, MIN(stage.frame.size.height, scroll.frame.size.height) - 24);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(stage.frame), CGRectGetMinX(scroll.frame));
    XCTAssertLessThanOrEqual(CGRectGetMaxX(stage.frame), CGRectGetMaxX(scroll.frame));
    // Reconstruct the move only after the diagram is framed in retained video.
    [self.app.buttons[@"lessonIntro.replay"] tap];
}
- (void)assertTenFrameFirstPlayFramingWhenWholeStageFits {
    XCUIElement *stage = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"];
    XCUIElement *scroll = self.app.scrollViews[@"lessonIntro.content"];
    XCTAssertTrue(stage.exists && scroll.exists);
    CGRect diagram = stage.frame, viewport = scroll.frame;
    XCTAssertTrue(isfinite(diagram.origin.y) && isfinite(diagram.size.height)
        && isfinite(viewport.origin.y) && isfinite(viewport.size.height));
    XCTAssertGreaterThan(diagram.size.height, 100);
    XCTAssertGreaterThan(viewport.size.height, 44);
    // Check the untouched new-step position, before any reveal gesture or Replay.
    // Shorter viewports still need separate native inspection of both endpoints.
    if (diagram.size.height + 8 <= viewport.size.height) {
        XCTAssertGreaterThanOrEqual(CGRectGetMinY(diagram), CGRectGetMinY(viewport) - 4);
        XCTAssertLessThanOrEqual(CGRectGetMaxY(diagram), CGRectGetMaxY(viewport) + 4);
    }
}
- (void)assertTenFrameReturnedToUnansweredQuestion:(NSString *)question {
    XCUIElement *label = self.app.staticTexts[@"lesson.problem"];
    XCTAssertTrue([label waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(label.label, question);
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
    for (NSUInteger index = 0; index < 4; index++) {
        XCUIElement *answer = self.app.buttons[[NSString stringWithFormat:@"answer.%lu", (unsigned long)index]];
        XCTAssertTrue(answer.enabled);
        XCTAssertTrue(answer.hittable);
    }
}
- (void)testMakeTenCurrentNineDotsReplayBackRotateAndFinish {
    NSString *question = [self openTenFrameLesson:@"合十法（進位加）" scenario:@"make-ten-nine"];
    XCTAssertEqualObjects(question, @"2 + 9 = ?");
    XCTAssertFalse(self.app.buttons[@"lessonIntro.previous"].enabled);
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 2 個，第二框 9 個"]);
    [self assertTenFrameFirstPlayFramingWhenWholeStageFits];
    [self capture:@"41a-make-ten-incoming-first-play-before-inspection"];
    [self inspectTenFrameStage];
    [self capture:@"41-make-ten-all-nine-incoming-dots"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"9 拆成 8 和 1"]);
    [self capture:@"42-make-ten-select-eight-leave-one"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 1 個"]);
    NSString *progress = self.app.staticTexts[@"lessonIntro.progress"].label;
    [self assertTenFrameFirstPlayFramingWhenWholeStageFits];
    [self capture:@"43a-make-ten-transfer-first-play-before-inspection"];
    [self inspectTenFrameStage];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
    [self capture:@"43-make-ten-transfer-eight-existing-dots"];
    [self.app.buttons[@"lessonIntro.previous"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 2 個，第二框 9 個"]);
    [self.app.buttons[@"lessonIntro.next"] tap];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationLandscapeLeft;
    NSPredicate *landscape = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        XCUIElement *window = object;
        return CGRectGetWidth(window.frame) > CGRectGetHeight(window.frame)
            && self.app.buttons[@"lessonIntro.next"].hittable;
    }];
    XCTestExpectation *rotated = [self expectationForPredicate:landscape
        evaluatedWithObject:self.app.windows.firstMatch handler:nil];
    [self waitForExpectations:@[rotated] timeout:5];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 1 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self capture:@"44-make-ten-rotation-preserves-selected-step"];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    NSPredicate *portrait = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        XCUIElement *window = object;
        return CGRectGetHeight(window.frame) > CGRectGetWidth(window.frame)
            && self.app.buttons[@"lessonIntro.next"].hittable;
    }];
    XCTestExpectation *upright = [self expectationForPredicate:portrait
        evaluatedWithObject:self.app.windows.firstMatch handler:nil];
    [self waitForExpectations:@[upright] timeout:5];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, @"2 + 9 = 11");
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"10 + 1 = 11"]);
    [self.app.buttons[@"lessonIntro.next"] tap];
    [self assertTenFrameReturnedToUnansweredQuestion:question];
}
- (void)testBreakTenCurrentEightOnesSurviveReplayBackgroundAndReturn {
    NSString *question = [self openTenFrameLesson:@"破十法（退位減）" scenario:@"break-ten-nine"];
    XCTAssertEqualObjects(question, @"18 − 9 = ?");
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 8 個"]);
    [self capture:@"45a-break-ten-initial-before-inspection"];
    // Initial presentation, not only Next, must show both original quantities
    // when the complete stage fits. Inspect/Replay may not repair this assertion.
    [self assertTenFrameFirstPlayFramingWhenWholeStageFits];
    [self inspectTenFrameStage];
    [self capture:@"45-break-ten-ten-and-eight-original-ones"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"劃掉 9 個"]);
    [self capture:@"46-break-ten-cross-nine-only-from-ten"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 1 個，第二框 8 個"]);
    [self assertTenFrameFirstPlayFramingWhenWholeStageFits];
    [self capture:@"47a-break-ten-removal-first-play-before-inspection"];
    [self.app.buttons[@"lessonIntro.previous"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 8 個；劃掉 9 個"]);
    [self.app.buttons[@"lessonIntro.next"] tap];
    [self inspectTenFrameStage];
    NSString *progress = self.app.staticTexts[@"lessonIntro.progress"].label;
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 1 個，第二框 8 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    XCTAssertTrue(self.app.buttons[@"lessonIntro.start"].hittable);
    [self capture:@"47-break-ten-original-eight-survive-background"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, @"18 − 9 = 9");
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"1 + 8 = 9"]);
    [self.app.buttons[@"lessonIntro.start"] tap];
    [self assertTenFrameReturnedToUnansweredQuestion:question];
}
- (void)testTenFrameVerticalComparisonAndSwipeReturnToTheOriginalQuestion {
    NSString *question = [self openTenFrameLesson:@"合十法（進位加）" scenario:@"make-ten-eighteen"];
    XCTAssertEqualObjects(question, @"9 + 9 = ?");
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 9 個，第二框 9 個"]);
    [self inspectTenFrameStage];
    [self capture:@"48-make-ten-eighteen-countable-dots"];
    [self.app.buttons[@"explanation.vertical"] tap];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    XCUIElement *vertical = [self.app descendantsMatchingType:XCUIElementTypeAny][@"teaching.screen"];
    [vertical.buttons[@"explanation.close"] tap];
    [self assertTenFrameReturnedToUnansweredQuestion:question];
    [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"lessonIntro.next"] waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    XCUIElement *sheet = [self.app descendantsMatchingType:XCUIElementTypeAny][@"explanation.screen"];
    XCUICoordinate *grabber = [sheet coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.01)];
    XCUICoordinate *down = [sheet coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.85)];
    [grabber pressForDuration:0.05 thenDragToCoordinate:down];
    NSPredicate *dismissed = [NSPredicate predicateWithFormat:@"hittable == YES"];
    XCTestExpectation *returned = [self expectationForPredicate:dismissed
        evaluatedWithObject:self.app.buttons[@"answer.0"] handler:nil];
    [self waitForExpectations:@[returned] timeout:5];
    [self assertTenFrameReturnedToUnansweredQuestion:question];
}

@end
