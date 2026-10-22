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
    NSPredicate *settled = [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", expected];
    [self waitForFreshGroupingValueMatching:settled timeout:3 name:@"grouping-quantity-observations"];
}
- (void)waitForFreshGroupingValueMatching:(NSPredicate *)condition timeout:(NSTimeInterval)timeout name:(NSString *)name {
    NSTimeInterval started = NSProcessInfo.processInfo.systemUptime;
    NSMutableArray<NSString *> *samples = [NSMutableArray array];
    NSPredicate *freshValue = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary<NSString *, id> *bindings) {
        NSTimeInterval queryStarted = NSProcessInfo.processInfo.systemUptime - started;
        // Query the element on EVERY evaluation. Apply the condition to its
        // full string, not to an element supplied to the predicate expectation.
        XCUIElement *board = [self.app descendantsMatchingType:XCUIElementTypeAny][@"groupingTeachingBoard"];
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
    // A non-asserting waiter lets us retain every full-value sample BEFORE a
    // failed assertion stops this test (continueAfterFailure is NO).
    NSString *trace = [NSString stringWithFormat:@"condition=%@ timeout=%.3f elapsed=%.6f result=%ld\n%@",
        condition, timeout, NSProcessInfo.processInfo.systemUptime - started, (long)result,
        [samples componentsJoinedByString:@"\n"]];
    XCTAttachment *observations = [XCTAttachment attachmentWithString:trace];
    observations.name = name;
    observations.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:observations];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"The live grouping value must satisfy %@ within %.3f seconds.", condition, timeout);
}
- (void)finishFocusedSharingRound {
    // Recipient subactions are explicit child choices, not a completed round.
    for (NSUInteger recipient = 0; recipient < 9 && [self.app.buttons[@"grouping.next"].label isEqualToString:@"下一位"]; recipient++) [self.app.buttons[@"grouping.next"] tap];
    XCTAssertNotEqualObjects(self.app.buttons[@"grouping.next"].label, @"下一位");
}
- (void)previousOriginalGroupingStep {
    NSString *original = self.app.staticTexts[@"grouping.progress"].label;
    for (NSUInteger recipient = 0; recipient < 10; recipient++) {
        [self.app.buttons[@"grouping.previous"] tap];
        if (![self.app.staticTexts[@"grouping.progress"].label isEqualToString:original]) return;
    }
    XCTFail(@"Previous must leave the bounded recipient subactions without changing the original lesson.");
}
- (void)waitForVisibleGroupingActionNaturalEnd {
    NSString *value = self.groupingBoardValue;
    XCTAssertTrue([value containsString:@"播放狀態："],
        @"A division action must expose its renderer lifecycle before completion can be accepted.");
    NSUInteger transfers = [value containsString:@" / "] ? 1 : 4; // These story fixtures are23÷4.
    NSTimeInterval declaredActionDuration = 0.28 + 0.82 * transfers + 0.24;
    NSPredicate *completed = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", @"。播放完成。播放狀態：completed"];
    [self waitForFreshGroupingValueMatching:completed timeout:declaredActionDuration + 1.0 name:@"grouping-natural-completion-observations"];
    // The existing separate quantity/model wait remains at3seconds, unchanged.
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
- (void)inspectGroupingBoardExpectingFocusedAction:(BOOL)expectsFocusedAction {
    XCUIElement *board = [self.app descendantsMatchingType:XCUIElementTypeAny][@"groupingTeachingBoard"];
    XCUIElement *content = self.app.scrollViews[@"grouping.content"];
    XCTAssertTrue(board.exists);
    XCTAssertTrue(content.exists);
    if (expectsFocusedAction) XCTAssertTrue([self.groupingBoardValue containsString:@"播放狀態："],
        @"This selected division transfer must use the visible action renderer, not a static overview.");
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
    // Remainder and multiplication snapshots legitimately use the overview.
    // The explicit division-action requirement survives Replay, so a lost mode
    // marker cannot silently take that separate static route.
    if (expectsFocusedAction || [self.groupingBoardValue containsString:@"播放狀態："])
        [self waitForVisibleGroupingActionNaturalEnd];
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
    [self finishFocusedSharingRound];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"這一輪共分出 4 顆"]);
    [self inspectGroupingBoardExpectingFocusedAction:YES];
    [self waitForGroupingValue:@"第 4 個小朋友有 1 顆"];
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 4 個小朋友有 1 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分的糖果：19 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"31-sharing-one-each"];
    [self previousOriginalGroupingStep];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    XCTAssertFalse(self.app.buttons[@"grouping.choice.1"].enabled);
    [self.app.buttons[@"grouping.next"] tap];
    for (NSUInteger step = 2; step < 11; step++) {
        [self finishFocusedSharingRound]; [self.app.buttons[@"grouping.next"] tap];
    }
    XCTAssertTrue([self.app.staticTexts[@"grouping.prompt"].label containsString:@"還能讓每個小朋友再拿 1 顆嗎"]);
    [self.app.buttons[@"grouping.choice.0"] tap];
    XCTAssertEqualObjects([self.app.buttons[@"grouping.choice.0"].value description], @"對，想通這一步了");
    [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"不是每個小朋友各剩一份"]);
    [self inspectGroupingBoardExpectingFocusedAction:NO];
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
    [self inspectGroupingBoardExpectingFocusedAction:YES];
    [self waitForGroupingValue:@"第 1 包有 4 顆"];
    XCTAssertTrue([self.groupingBoardValue containsString:@"已分成 1 包"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"第 1 包有 4 顆"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"待分組的糖果：19 顆"]);
    XCTAssertFalse([self.groupingBoardValue containsString:@"第 2 包有"]);
    [self capture:@"35-packing-first-complete-bag"];
    for (NSUInteger step = 2; step < 12; step++) [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"不是完整的包"]);
    [self inspectGroupingBoardExpectingFocusedAction:NO];
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
    [self inspectGroupingBoardExpectingFocusedAction:NO];
    [self waitForGroupingValue:@"第 1 包有 3 顆"];
    XCTAssertTrue([self.groupingBoardValue containsString:@"已建立 1 包"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"還有 3 包尚未建立"]);
    XCTAssertTrue([self.groupingBoardValue containsString:@"答案還沒寫"]);
    [self capture:@"38-multiplication-one-group"];
    for (NSUInteger step = 2; step < 9; step++) [self.app.buttons[@"grouping.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:@"一共有 12 顆"]);
    [self inspectGroupingBoardExpectingFocusedAction:NO];
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
- (XCUIElement *)revealTenFrameLesson:(NSString *)lessonID title:(NSString *)title in:(XCUIElement *)collection {
    NSString *identifier = [@"lessons.lesson." stringByAppendingString:lessonID];
    NSString *titleIdentifier = [identifier stringByAppendingString:@".title"];
    NSArray<NSString *> *lessonOrder = @[@"L1", @"L2", @"L3", @"L4", @"L5"];
    NSUInteger targetIndex = [lessonOrder indexOfObject:lessonID];
    XCTAssertNotEqual(targetIndex, NSNotFound);
    // Keep the original five-gesture budget. A full swipe can carry L4 from
    // below the compact viewport to above it before the next observation.
    for (NSUInteger attempt = 0; attempt < 5; attempt++) {
        XCUIElement *cell = collection.cells[identifier];
        XCUIElement *label = cell.staticTexts[titleIdentifier];
        BOOL exists = cell.exists;
        if (exists && label.exists && cell.hittable && label.hittable) break;
        CGRect containerFrame = collection.frame;
        CGRect viewport = CGRectIntersection(containerFrame, self.app.windows.firstMatch.frame);
        XCTAssertFalse(CGRectIsNull(viewport));
        XCTAssertTrue(isfinite(viewport.origin.x) && isfinite(viewport.origin.y)
            && isfinite(viewport.size.width) && isfinite(viewport.size.height));
        XCTAssertGreaterThan(viewport.size.width, 44);
        XCTAssertGreaterThan(viewport.size.height, 44);
        CGRect before = exists ? cell.frame : CGRectNull;
        BOOL hasGeometry = !CGRectIsNull(before) && !CGRectIsEmpty(before)
            && isfinite(before.origin.x) && isfinite(before.origin.y)
            && isfinite(before.size.width) && isfinite(before.size.height);
        CGFloat requested = viewport.size.height * 0.3;
        NSString *basis = @"search toward later lessons";
        if (hasGeometry) {
            requested = CGRectGetMidY(before) - CGRectGetMidY(viewport);
            basis = @"fresh target cell frame";
        } else {
            // Virtualized cells may have no frame. Visible later lessons or
            // later sections prove that we must go BACK, not swipe farther down.
            for (XCUIElement *anchor in collection.cells.allElementsBoundByIndex) {
                if (!CGRectIntersectsRect(anchor.frame, viewport)) continue;
                NSString *anchorID = anchor.identifier;
                NSString *prefix = @"lessons.lesson.";
                NSUInteger anchorIndex = [anchorID hasPrefix:prefix]
                    ? [lessonOrder indexOfObject:[anchorID substringFromIndex:prefix.length]] : NSNotFound;
                if ((anchorIndex != NSNotFound && anchorIndex > targetIndex)
                    || [anchorID hasPrefix:@"lessons.concept."] || [anchorID hasPrefix:@"lessons.table."]) {
                    requested = -requested;
                    basis = [@"visible later catalog row: " stringByAppendingString:anchorID];
                    break;
                }
            }
        }
        // A centered but unhittable cell is not evidence for either direction.
        CGFloat travel = fabs(requested) < 1 ? 0 : MIN(MAX(fabs(requested), 24), viewport.size.height * 0.3);
        CGFloat startY = CGRectGetMinY(viewport) + viewport.size.height * (requested > 0 ? 0.65 : 0.35);
        CGFloat endY = startY + (requested > 0 ? -travel : travel);
        XCUICoordinate *origin = [collection coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
        CGFloat x = CGRectGetMidX(viewport) - CGRectGetMinX(containerFrame);
        XCUICoordinate *start = [origin coordinateWithOffset:CGVectorMake(x, startY - CGRectGetMinY(containerFrame))];
        XCUICoordinate *end = [origin coordinateWithOffset:CGVectorMake(x, endY - CGRectGetMinY(containerFrame))];
        CGPoint touchStart = start.screenPoint, touchEnd = end.screenPoint;
        XCTAssertTrue(CGRectContainsPoint(viewport, touchStart) && CGRectContainsPoint(viewport, touchEnd));
        // Slow, held-end dragging limits inertial overshoot; it adds no sleep.
        if (travel > 0) [start pressForDuration:0.05 thenDragToCoordinate:end
            withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
        XCUIElement *afterCell = collection.cells[identifier];
        BOOL existsAfter = afterCell.exists;
        CGRect after = existsAfter ? afterCell.frame : CGRectNull;
        XCUIElement *afterLabel = afterCell.staticTexts[titleIdentifier];
        BOOL titleHittableAfter = existsAfter && afterLabel.exists && afterLabel.hittable;
        CGRect viewportAfter = CGRectIntersection(collection.frame, self.app.windows.firstMatch.frame);
        XCTAttachment *trace = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
            @"attempt=%lu identifier=%@ direction=%@ basis=%@ requested=%.2f travel=%.2f "
             "targetBefore=%@ targetAfter=%@ viewportBefore=%@ viewportAfter=%@ touchStart=%@ touchEnd=%@ titleHittableAfter=%d",
            (unsigned long)attempt + 1, identifier, travel == 0 ? @"none" : (requested > 0 ? @"later/up-drag" : @"earlier/down-drag"),
            basis, requested, travel, NSStringFromCGRect(before), NSStringFromCGRect(after),
            NSStringFromCGRect(viewport), NSStringFromCGRect(viewportAfter), NSStringFromCGPoint(touchStart),
            NSStringFromCGPoint(touchEnd), titleHittableAfter]];
        trace.name = @"ten-frame-catalog-reveal";
        trace.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:trace];
        if (travel == 0) break;
    }
    XCUIElement *lesson = collection.cells[identifier];
    XCUIElement *label = lesson.staticTexts[titleIdentifier];
    XCTAssertTrue(lesson.exists && label.exists && lesson.hittable && label.hittable,
        @"The named lesson must be visibly reachable within five measured drags: %@", identifier);
    XCTAssertEqualObjects(label.label, title);
    return lesson;
}
- (NSString *)openTenFrameLesson:(NSString *)lessonID title:(NSString *)title scenario:(NSString *)scenario {
    [self relaunchScenario:scenario];
    [self tapHomeCard:@"home.lessons"];
    XCUIElement *collection = self.app.collectionViews[@"lessons.catalog"];
    XCTAssertTrue([collection waitForExistenceWithTimeout:5]);
    XCUIElement *lesson = [self revealTenFrameLesson:lessonID title:title in:collection];
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
- (NSUInteger)tenFramePlaybackGeneration {
    XCUIElement *progress = self.app.staticTexts[@"lessonIntro.progress"];
    XCTAssertTrue(progress.exists);
    NSScanner *scanner = [NSScanner scannerWithString:[progress.value description]];
    unsigned long long generation = 0;
    BOOL parsed = [scanner scanString:@"第" intoString:nil] && [scanner scanUnsignedLongLong:&generation]
        && [scanner scanString:@"次播放" intoString:nil];
    XCTAssertTrue(parsed, @"Expected a real playback generation, got %@", progress.value);
    return (NSUInteger)generation;
}
- (void)waitForTenFrameNaturalCompletionAfterGeneration:(NSUInteger)previous step:(NSInteger)step {
    XCUIElement *progress = self.app.staticTexts[@"lessonIntro.progress"];
    NSString *expected = [NSString stringWithFormat:@"第 %lu 次播放，第 %ld 小步，動態播放完成",
        (unsigned long)previous + 1, (long)step + 1];
    NSString *selected = [NSString stringWithFormat:@"第 %ld 小步", (long)step + 1];
    NSPredicate *naturalEnd = [NSPredicate predicateWithFormat:@"value == %@ AND label BEGINSWITH %@", expected, selected];
    XCTestExpectation *completed = [self expectationForPredicate:naturalEnd evaluatedWithObject:progress handler:nil];
    // The longest real transfer is 6.68 seconds. Synchronous endpoint counts,
    // cancellation, Reduce Motion, and a newer Replay cannot satisfy this gate.
    [self waitForExpectations:@[completed] timeout:8];
    XCTAssertEqualObjects([progress.value description], expected);
    XCTAssertEqual([self tenFramePlaybackGeneration], previous + 1);
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
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
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
}
- (void)assertTenFrameListeningIsReachable {
    XCUIElement *listen = self.app.buttons[@"lessonIntro.readPinned"];
    XCUIElement *scroll = self.app.scrollViews[@"lessonIntro.content"];
    CGRect window = self.app.windows.firstMatch.frame;
    XCTAssertTrue(listen.exists && listen.enabled && listen.hittable);
    XCTAssertEqualObjects(listen.label, @"聽聽這一步");
    XCTAssertGreaterThanOrEqual(listen.frame.size.width, 60);
    XCTAssertGreaterThanOrEqual(listen.frame.size.height, 60);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(window, -0.5, -0.5), listen.frame));
    XCTAssertFalse(CGRectIntersectsRect(listen.frame, scroll.frame));
    for (NSString *identifier in @[@"lessonIntro.previous", @"lessonIntro.next", @"lessonIntro.replay", @"lessonIntro.start"]) {
        XCTAssertFalse(CGRectIntersectsRect(listen.frame, self.app.buttons[identifier].frame));
    }
}
- (void)assertTenFrameExplanationIsVisibleWhenItFits {
    // This observation must precede any inspection scroll. Existence or a
    // sliver of hittable text does not establish a readable causal explanation.
    [self assertTenFrameListeningIsReachable];
    XCUIElement *question = self.app.staticTexts[@"lessonIntro.equation"];
    XCUIElement *stage = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"];
    XCUIElement *narration = self.app.staticTexts[@"lessonIntro.narration"];
    XCUIElement *read = self.app.buttons[@"lessonIntro.read"];
    CGRect window = self.app.windows.firstMatch.frame;
    CGRect viewport = CGRectIntersection(self.app.scrollViews[@"lessonIntro.content"].frame, window);
    XCTAssertTrue(question.exists && stage.exists && narration.exists && read.exists);
    for (NSValue *value in @[[NSValue valueWithCGRect:question.frame], [NSValue valueWithCGRect:stage.frame], [NSValue valueWithCGRect:narration.frame],
        [NSValue valueWithCGRect:read.frame]]) {
        CGRect rect = value.CGRectValue;
        XCTAssertTrue(isfinite(rect.origin.x) && isfinite(rect.origin.y)
            && isfinite(rect.size.width) && isfinite(rect.size.height));
        XCTAssertGreaterThan(rect.size.width, 0);
        XCTAssertGreaterThan(rect.size.height, 0);
    }
    CGRect explanation = CGRectUnion(stage.frame, narration.frame);
    CGRect withRead = CGRectUnion(explanation, read.frame);
    CGRect withQuestion = CGRectUnion(question.frame, explanation);
    CGRect withQuestionAndRead = CGRectUnion(withQuestion, withRead);
    // The complete original problem takes priority over the duplicate Read,
    // not over any part of the causal scene or its full narration.
    for (NSValue *candidate in @[[NSValue valueWithCGRect:withQuestionAndRead], [NSValue valueWithCGRect:withQuestion],
        [NSValue valueWithCGRect:withRead], [NSValue valueWithCGRect:explanation]]) {
        CGRect required = candidate.CGRectValue;
        if (required.size.width > viewport.size.width || required.size.height > viewport.size.height) continue;
        XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -0.5, -0.5), required),
            @"The full explanation %@ fits %@ and must already be framed without test scrolling.",
            NSStringFromCGRect(required), NSStringFromCGRect(viewport));
        XCTAssertTrue(CGRectContainsRect(CGRectInset(window, -0.5, -0.5), required));
        if (withQuestion.size.width <= viewport.size.width && withQuestion.size.height <= viewport.size.height) {
            XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -0.5, -0.5), question.frame),
                @"The original equation must be fully visible before any inspection scroll when its teaching unit fits.");
        }
        break;
    }
}
- (void)assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused {
    [self assertTenFrameListeningIsReachable];
    XCUIElement *stage = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"];
    XCUIElement *scroll = self.app.scrollViews[@"lessonIntro.content"];
    XCTAssertTrue(stage.exists && scroll.exists);
    // The stage's live VoiceOver focus frame is the actual required causal
    // region: before/after counters, both frames, count labels and entire route.
    // It is not a Boolean test hook or the model's completion claim.
    CGRect diagram = stage.frame, viewport = scroll.frame, window = self.app.windows.firstMatch.frame;
    XCTAssertTrue(isfinite(diagram.origin.y) && isfinite(diagram.size.height)
        && isfinite(viewport.origin.y) && isfinite(viewport.size.height));
    XCTAssertGreaterThan(diagram.size.height, 100);
    XCTAssertGreaterThan(viewport.size.height, 44);
    NSString *state = [self.app.staticTexts[@"lessonIntro.progress"].value description];
    if ([state containsString:@"點點圖未完整顯示，先看圖再重播"]) {
        XCUIElement *instruction = self.app.staticTexts[@"lessonIntro.visibilityInstruction"];
        XCTAssertTrue(instruction.exists && instruction.hittable);
        XCTAssertTrue(self.app.buttons[@"lessonIntro.replay"].hittable);
        XCTAssertFalse([state containsString:@"動態播放中"] || [state containsString:@"動態播放完成"]);
        XCTAssertFalse(CGRectIntersectsRect(instruction.frame, viewport));
        XCTAssertTrue(CGRectContainsRect(window, instruction.frame));
    } else {
        // No conditional skip when the stage is taller than the viewport.
        // A playing/completed scene must be completely visible now.
        XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -0.5, -0.5), diagram));
        XCTAssertTrue(CGRectContainsRect(CGRectInset(window, -0.5, -0.5), diagram));
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
- (void)assertTenFrameVisibilityPausedForGeneration:(NSUInteger)generation
    selectedProgress:(NSString *)selectedProgress question:(NSString *)question {
    XCUIElement *progress = self.app.staticTexts[@"lessonIntro.progress"];
    NSString *expected = [NSString stringWithFormat:@"第 %lu 次播放，第 4 小步，點點圖未完整顯示，先看圖再重播",
        (unsigned long)generation];
    NSString *endpoint = [@"第一框 10 個，第二框 1 個；劃掉 0 個。原來的題目是 2 加 9。"
        stringByAppendingString:self.app.staticTexts[@"lessonIntro.narration"].label];
    XCTAssertEqualObjects([progress.value description], expected);
    XCTAssertEqualObjects(progress.label, selectedProgress);
    XCTAssertEqual([self tenFramePlaybackGeneration], generation);
    XCTAssertEqualObjects(self.tenFrameStageValue, endpoint);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    XCUIElement *instruction = self.app.staticTexts[@"lessonIntro.visibilityInstruction"];
    CGRect viewport = self.app.scrollViews[@"lessonIntro.content"].frame;
    CGRect window = self.app.windows.firstMatch.frame;
    XCTAssertTrue(instruction.exists && instruction.hittable);
    XCTAssertTrue(CGRectContainsRect(window, instruction.frame));
    XCTAssertFalse(CGRectIntersectsRect(instruction.frame, viewport));
    NSMutableArray<NSValue *> *controlFrames = [NSMutableArray array];
    for (NSString *identifier in @[@"lessonIntro.previous", @"lessonIntro.next", @"lessonIntro.replay",
        @"lessonIntro.start", @"lessonIntro.readPinned"]) {
        XCUIElement *control = self.app.buttons[identifier];
        XCTAssertTrue(control.exists && control.enabled && control.hittable, @"%@", identifier);
        CGRect frame = control.frame;
        XCTAssertGreaterThan(frame.size.width, 0);
        XCTAssertGreaterThan(frame.size.height, 0);
        XCTAssertTrue(CGRectContainsRect(CGRectInset(window, -0.5, -0.5), frame));
        XCTAssertFalse(CGRectIntersectsRect(frame, viewport));
        XCTAssertFalse(CGRectIntersectsRect(frame, instruction.frame));
        for (NSValue *other in controlFrames) XCTAssertFalse(CGRectIntersectsRect(frame, other.CGRectValue));
        [controlFrames addObject:[NSValue valueWithCGRect:frame]];
    }
    // Geometry and accessibility observations must not resume or replace it.
    XCTAssertEqualObjects([progress.value description], expected);
    XCTAssertFalse([[progress.value description] containsString:@"動態播放中"]);
    XCTAssertFalse([[progress.value description] containsString:@"動態播放完成"]);
    XCTAssertEqualObjects(progress.label, selectedProgress);
    XCTAssertEqual([self tenFramePlaybackGeneration], generation);
    XCTAssertEqualObjects(self.tenFrameStageValue, endpoint);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
}
- (void)testMakeTenCurrentNineDotsReplayBackRotateAndFinish {
    NSString *question = [self openTenFrameLesson:@"L4" title:@"合十法（進位加）" scenario:@"make-ten-nine"];
    XCTAssertEqualObjects(question, @"2 + 9 = ?");
    XCTAssertFalse(self.app.buttons[@"lessonIntro.previous"].enabled);
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 2 個，第二框 9 個"]);
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"41a-make-ten-incoming-first-play-before-inspection"];
    [self inspectTenFrameStage];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"41-make-ten-all-nine-incoming-dots"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"9 拆成 8 和 1"]);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"42-make-ten-select-eight-leave-one"];
    NSUInteger beforeFirstTransfer = [self tenFramePlaybackGeneration];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 1 個"]);
    NSString *progress = self.app.staticTexts[@"lessonIntro.progress"].label;
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"43a-make-ten-transfer-first-play-before-inspection"];
    [self waitForTenFrameNaturalCompletionAfterGeneration:beforeFirstTransfer step:3];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"43b-make-ten-first-play-naturally-completed"];
    CGRect diagramBeforeListening = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"].frame;
    NSUInteger generationBeforeListening = [self tenFramePlaybackGeneration];
    [self.app.buttons[@"lessonIntro.readPinned"] tap];
    XCTAssertEqual([self tenFramePlaybackGeneration], generationBeforeListening);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    XCTAssertTrue(CGRectEqualToRect([self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"].frame,
        diagramBeforeListening));
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    NSUInteger beforeReplay = [self tenFramePlaybackGeneration];
    [self inspectTenFrameStage];
    [self waitForTenFrameNaturalCompletionAfterGeneration:beforeReplay step:3];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"43-make-ten-transfer-eight-existing-dots"];
    [self.app.buttons[@"lessonIntro.previous"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 2 個，第二框 9 個"]);
    // Inspect the previous step's real text with bounded ordinary scrolling.
    // This is static comparison, not a Replay that is already safely framed.
    NSUInteger beforeTextInspection = [self tenFramePlaybackGeneration];
    NSString *staticComparison = [self.app.staticTexts[@"lessonIntro.progress"].value description];
    XCUIElement *comparisonNarration = self.app.staticTexts[@"lessonIntro.narration"];
    XCUIElement *comparisonRead = self.app.buttons[@"lessonIntro.read"];
    XCUIElement *comparisonContent = self.app.scrollViews[@"lessonIntro.content"];
    XCTAssertTrue(comparisonNarration.exists && comparisonRead.exists && comparisonContent.exists);
    [self frameBoardForInspection:comparisonNarration in:comparisonContent];
    CGRect visibleNarration = CGRectIntersection(comparisonNarration.frame,
        CGRectIntersection(comparisonContent.frame, self.app.windows.firstMatch.frame));
    XCTAssertFalse(CGRectIsNull(visibleNarration) || CGRectIsEmpty(visibleNarration));
    XCTAssertTrue([comparisonNarration.label containsString:@"9 拆成 8 和 1"]);
    [self frameBoardForInspection:comparisonRead in:comparisonContent];
    XCTAssertTrue(comparisonRead.enabled && comparisonRead.hittable);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(comparisonContent.frame, -0.5, -0.5), comparisonRead.frame));
    XCTAssertTrue(CGRectContainsRect(CGRectInset(self.app.windows.firstMatch.frame, -0.5, -0.5), comparisonRead.frame));
    XCTAssertEqual([self tenFramePlaybackGeneration], beforeTextInspection);
    XCTAssertEqualObjects([self.app.staticTexts[@"lessonIntro.progress"].value description], staticComparison);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self capture:@"43c-make-ten-narration-inspection-before-fresh-next"];
    NSUInteger beforeBackNext = [self tenFramePlaybackGeneration];
    [self.app.buttons[@"lessonIntro.next"] tap];
    [self waitForTenFrameNaturalCompletionAfterGeneration:beforeBackNext step:3];
    // Fresh selection owes the original equation plus the FULL causal action
    // when their actual union fits. Observe before any corrective test scroll;
    // full narration may remain below it, without being shrunk or capped.
    CGRect selectedQuestion = self.app.staticTexts[@"lessonIntro.equation"].frame;
    CGRect selectedScene = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"].frame;
    CGRect selectedWindow = self.app.windows.firstMatch.frame;
    CGRect selectedViewport = CGRectIntersection(comparisonContent.frame, selectedWindow);
    CGRect questionAndScene = CGRectUnion(selectedQuestion, selectedScene);
    for (NSValue *value in @[[NSValue valueWithCGRect:selectedQuestion], [NSValue valueWithCGRect:selectedScene],
        [NSValue valueWithCGRect:selectedViewport]]) {
        CGRect rect = value.CGRectValue;
        XCTAssertTrue(isfinite(rect.origin.x) && isfinite(rect.origin.y)
            && isfinite(rect.size.width) && isfinite(rect.size.height));
        XCTAssertGreaterThan(rect.size.width, 0);
        XCTAssertGreaterThan(rect.size.height, 0);
    }
    if (questionAndScene.size.width <= selectedViewport.size.width
        && questionAndScene.size.height <= selectedViewport.size.height) {
        XCTAssertTrue(CGRectContainsRect(CGRectInset(selectedViewport, -0.5, -0.5), questionAndScene),
            @"Fresh Next must frame the original question and complete fitting scene before test scrolling.");
        XCTAssertTrue(CGRectContainsRect(CGRectInset(selectedWindow, -0.5, -0.5), questionAndScene));
    }
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    for (NSString *identifier in @[@"lessonIntro.previous", @"lessonIntro.next", @"lessonIntro.replay",
        @"lessonIntro.start", @"lessonIntro.readPinned"]) {
        XCUIElement *control = self.app.buttons[identifier];
        XCTAssertTrue(control.exists && control.enabled && control.hittable);
        XCTAssertTrue(CGRectContainsRect(CGRectInset(selectedWindow, -0.5, -0.5), control.frame));
        XCTAssertFalse(CGRectIntersectsRect(control.frame, selectedViewport));
    }
    [self capture:@"43c-make-ten-fresh-next-question-scene-before-inspection"];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 1 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"43c-make-ten-back-next-naturally-completed"];
    // A separate fourth playback attempts an interruption. It must not stand
    // in for any complete transfer above. XCUITest may idle until it finishes
    // before issuing the rotation; record that honestly as continuity only.
    NSUInteger beforeInterruption = [self tenFramePlaybackGeneration];
    NSString *beforeRotationPlayback = [self.app.staticTexts[@"lessonIntro.progress"].value description];
    [self.app.buttons[@"lessonIntro.replay"] tap];
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationLandscapeLeft;
    NSPredicate *landscape = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        XCUIElement *window = object;
        return CGRectGetWidth(window.frame) > CGRectGetHeight(window.frame)
            && self.app.buttons[@"lessonIntro.next"].hittable;
    }];
    XCTestExpectation *rotated = [self expectationForPredicate:landscape
        evaluatedWithObject:self.app.windows.firstMatch handler:nil];
    [self waitForExpectations:@[rotated] timeout:5];
    NSString *afterRotationPlayback = [self.app.staticTexts[@"lessonIntro.progress"].value description];
    NSString *cancelled = [NSString stringWithFormat:@"第 %lu 次播放，第 4 小步，動態已停止，顯示目前這一步",
        (unsigned long)beforeInterruption + 1];
    NSString *completed = [NSString stringWithFormat:@"第 %lu 次播放，第 4 小步，動態播放完成",
        (unsigned long)beforeInterruption + 1];
    BOOL observedCancellation = [afterRotationPlayback isEqualToString:cancelled];
    XCTAssertTrue(observedCancellation || [afterRotationPlayback isEqualToString:completed],
        @"The exact fourth generation must be settled after rotation, not replaced or still running.");
    NSString *interpretation = observedCancellation
        ? @"Cancellation observed for the fourth playback; inspect video to locate the interruption."
        : @"Natural completion observed; rotation continuity only, not UI interruption proof.";
    XCTAttachment *lifecycle = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
        @"Before fourth Replay: %@\nRequested generation: %lu\nAfter rotation: %@\n%@",
        beforeRotationPlayback, (unsigned long)beforeInterruption + 1, afterRotationPlayback, interpretation]];
    lifecycle.name = @"44-make-ten-fourth-playback-rotation-lifecycle";
    lifecycle.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:lifecycle];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 1 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self capture:@"44-make-ten-rotation-preserves-selected-step"];
    // Measure capacity BEFORE Replay can reserve space for pause guidance.
    // A misplaced but fitting action still owes a real natural completion.
    NSUInteger beforeLandscapeReplay = [self tenFramePlaybackGeneration];
    XCTAssertEqual(beforeLandscapeReplay, beforeInterruption + 1);
    XCTAssertEqualObjects([self.app.staticTexts[@"lessonIntro.progress"].value description], afterRotationPlayback);
    XCTAssertFalse(self.app.staticTexts[@"lessonIntro.visibilityInstruction"].exists);
    CGRect requiredAction = [self.app descendantsMatchingType:XCUIElementTypeAny][@"lessonIntro.stage"].frame;
    CGRect unobstructedScroll = self.app.scrollViews[@"lessonIntro.content"].frame;
    CGRect landscapeWindow = self.app.windows.firstMatch.frame;
    for (NSValue *value in @[[NSValue valueWithCGRect:requiredAction],
        [NSValue valueWithCGRect:unobstructedScroll], [NSValue valueWithCGRect:landscapeWindow]]) {
        CGRect frame = value.CGRectValue;
        XCTAssertTrue(isfinite(frame.origin.x) && isfinite(frame.origin.y)
            && isfinite(frame.size.width) && isfinite(frame.size.height));
        XCTAssertGreaterThan(frame.size.width, 0);
        XCTAssertGreaterThan(frame.size.height, 0);
    }
    CGFloat footerTop = CGFLOAT_MAX;
    for (NSString *identifier in @[@"lessonIntro.previous", @"lessonIntro.next", @"lessonIntro.replay",
        @"lessonIntro.start", @"lessonIntro.readPinned"]) {
        XCUIElement *control = self.app.buttons[identifier];
        XCTAssertTrue(control.exists && control.enabled && control.hittable);
        CGRect frame = control.frame;
        XCTAssertTrue(isfinite(frame.origin.x) && isfinite(frame.origin.y)
            && isfinite(frame.size.width) && isfinite(frame.size.height));
        XCTAssertGreaterThan(frame.size.width, 0);
        XCTAssertGreaterThan(frame.size.height, 0);
        XCTAssertTrue(CGRectContainsRect(CGRectInset(landscapeWindow, -0.5, -0.5), frame));
        footerTop = MIN(footerTop, CGRectGetMinY(frame));
    }
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(unobstructedScroll), footerTop - 12, 0.5);
    CGRect available = CGRectIntersection(unobstructedScroll, landscapeWindow);
    XCTAssertFalse(CGRectIsNull(available) || CGRectIsEmpty(available));
    BOOL insufficientLandscapeCapacity = MAX(requiredAction.size.width - available.size.width,
        requiredAction.size.height - available.size.height) > 0.5;
    XCTAttachment *capacity = [XCTAttachment attachmentWithString:[NSString stringWithFormat:
        @"Settled playback before Replay: %@\nRequired action: %@\nUnobstructed scroll: %@\n"
         "Physical window: %@\nMinimum top of all five footer controls: %.3f\nAvailable: %@\nInsufficient dimensions: %d",
        afterRotationPlayback, NSStringFromCGRect(requiredAction), NSStringFromCGRect(unobstructedScroll),
        NSStringFromCGRect(landscapeWindow), (double)footerTop, NSStringFromCGRect(available), insufficientLandscapeCapacity]];
    capacity.name = @"44a-make-ten-landscape-pre-replay-capacity";
    capacity.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:capacity];
    XCTAssertEqualObjects([self.app.staticTexts[@"lessonIntro.progress"].value description], afterRotationPlayback);
    XCTAssertFalse(self.app.staticTexts[@"lessonIntro.visibilityInstruction"].exists);
    [self.app.buttons[@"lessonIntro.replay"] tap];
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    if (insufficientLandscapeCapacity) {
        [self assertTenFrameVisibilityPausedForGeneration:beforeLandscapeReplay + 1 selectedProgress:progress question:question];
        [self capture:@"44a-make-ten-landscape-insufficient-capacity-paused"];
        [self assertTenFrameVisibilityPausedForGeneration:beforeLandscapeReplay + 1 selectedProgress:progress question:question];
    } else {
        [self waitForTenFrameNaturalCompletionAfterGeneration:beforeLandscapeReplay step:3];
        [self capture:@"44a-make-ten-landscape-replay-naturally-completed"];
    }
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 1 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    NSPredicate *portrait = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        XCUIElement *window = object;
        return CGRectGetHeight(window.frame) > CGRectGetWidth(window.frame)
            && self.app.buttons[@"lessonIntro.next"].hittable;
    }];
    XCTestExpectation *upright = [self expectationForPredicate:portrait
        evaluatedWithObject:self.app.windows.firstMatch handler:nil];
    [self waitForExpectations:@[upright] timeout:5];
    if (insufficientLandscapeCapacity) {
        [self assertTenFrameVisibilityPausedForGeneration:beforeLandscapeReplay + 1 selectedProgress:progress question:question];
        [self capture:@"44b-make-ten-portrait-still-paused-before-explicit-replay"];
        [self assertTenFrameVisibilityPausedForGeneration:beforeLandscapeReplay + 1 selectedProgress:progress question:question];
        [self.app.buttons[@"lessonIntro.replay"] tap];
        [self waitForTenFrameNaturalCompletionAfterGeneration:beforeLandscapeReplay + 1 step:3];
        XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
        XCTAssertEqualObjects(self.tenFrameStageValue, ([@"第一框 10 個，第二框 1 個；劃掉 0 個。原來的題目是 2 加 9。"
            stringByAppendingString:self.app.staticTexts[@"lessonIntro.narration"].label]));
        XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
        [self capture:@"44c-make-ten-portrait-explicit-replay-naturally-completed"];
    }
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, @"2 + 9 = 11");
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"10 + 1 = 11"]);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    // Only after all first-play observations: the duplicate inline Read must
    // remain reachable by ordinary scrolling, not disappear behind the footer.
    XCUIElement *inlineRead = self.app.buttons[@"lessonIntro.read"];
    XCUIElement *content = self.app.scrollViews[@"lessonIntro.content"];
    [self frameBoardForInspection:inlineRead in:content];
    XCTAssertTrue(inlineRead.exists && inlineRead.enabled && inlineRead.hittable);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(content.frame, -0.5, -0.5), inlineRead.frame));
    XCTAssertTrue(CGRectContainsRect(CGRectInset(self.app.windows.firstMatch.frame, -0.5, -0.5), inlineRead.frame));
    [self assertTenFrameListeningIsReachable];
    CGRect beforeInlineRead = self.app.staticTexts[@"lessonIntro.narration"].frame;
    NSUInteger generationBeforeInlineRead = [self tenFramePlaybackGeneration];
    [inlineRead tap];
    XCTAssertEqual([self tenFramePlaybackGeneration], generationBeforeInlineRead);
    XCTAssertTrue(CGRectEqualToRect(self.app.staticTexts[@"lessonIntro.narration"].frame, beforeInlineRead));
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, @"2 + 9 = 11");
    [self.app.buttons[@"lessonIntro.next"] tap];
    [self assertTenFrameReturnedToUnansweredQuestion:question];
}
- (void)testBreakTenCurrentEightOnesSurviveReplayBackgroundAndReturn {
    NSString *question = [self openTenFrameLesson:@"L5" title:@"破十法（退位減）" scenario:@"break-ten-nine"];
    XCTAssertEqualObjects(question, @"18 − 9 = ?");
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 8 個"]);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"45a-break-ten-initial-before-inspection"];
    // Initial presentation, not only Next, must show both original quantities
    // when the complete stage fits. Inspect/Replay may not repair this assertion.
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    [self inspectTenFrameStage];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"45-break-ten-ten-and-eight-original-ones"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"劃掉 9 個"]);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"46-break-ten-cross-nine-only-from-ten"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 1 個，第二框 8 個"]);
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"47a-break-ten-removal-first-play-before-inspection"];
    [self.app.buttons[@"lessonIntro.previous"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 8 個；劃掉 9 個"]);
    [self.app.buttons[@"lessonIntro.next"] tap];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self inspectTenFrameStage];
    NSString *progress = self.app.staticTexts[@"lessonIntro.progress"].label;
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [self.app activate];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, progress);
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 1 個，第二框 8 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    XCTAssertTrue(self.app.buttons[@"lessonIntro.start"].hittable);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"47-break-ten-original-eight-survive-background"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, @"18 − 9 = 9");
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"1 + 8 = 9"]);
    [self.app.buttons[@"lessonIntro.start"] tap];
    [self assertTenFrameReturnedToUnansweredQuestion:question];
}
- (void)testTenFrameVerticalComparisonAndSwipeReturnToTheOriginalQuestion {
    NSString *question = [self openTenFrameLesson:@"L4" title:@"合十法（進位加）" scenario:@"make-ten-eighteen"];
    XCTAssertEqualObjects(question, @"9 + 9 = ?");
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 9 個，第二框 9 個"]);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self inspectTenFrameStage];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"48-make-ten-eighteen-countable-dots"];
    [self.app.buttons[@"lessonIntro.next"] tap];
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"9 拆成 1 和 8"]);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"48a-make-ten-select-one-leave-eight-in-original-slots"];
    NSUInteger beforeTransfer = [self tenFramePlaybackGeneration];
    [self.app.buttons[@"lessonIntro.next"] tap];
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"48b-make-ten-one-transfer-first-play-before-inspection"];
    [self waitForTenFrameNaturalCompletionAfterGeneration:beforeTransfer step:3];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 8 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"48c-make-ten-one-arrived-eight-remainders-still-in-original-slots"];
    NSUInteger beforeReplay = [self tenFramePlaybackGeneration];
    [self inspectTenFrameStage];
    [self waitForTenFrameNaturalCompletionAfterGeneration:beforeReplay step:3];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 8 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"48d-make-ten-one-transfer-replay-naturally-completed"];
    [self.app.buttons[@"lessonIntro.previous"] tap];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 9 個，第二框 9 個"]);
    NSUInteger beforeBackNext = [self tenFramePlaybackGeneration];
    [self.app.buttons[@"lessonIntro.next"] tap];
    [self assertTenFrameRequiredSceneIsVisibleOrExplicitlyPaused];
    [self waitForTenFrameNaturalCompletionAfterGeneration:beforeBackNext step:3];
    XCTAssertTrue([self.tenFrameStageValue containsString:@"第一框 10 個，第二框 8 個"]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self assertTenFrameExplanationIsVisibleWhenItFits];
    [self capture:@"48e-make-ten-one-transfer-back-next-eight-original-remainders"];
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
