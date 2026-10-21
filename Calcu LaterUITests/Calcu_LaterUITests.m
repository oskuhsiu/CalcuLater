#import <XCTest/XCTest.h>

/// Native tap flows with screenshots and accessibility trees at each checkpoint.
@interface Calcu_LaterUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation Calcu_LaterUITests

- (void)setUp {
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)",
                                @"-AppleLocale", @"zh_TW",
                                @"-soundEffectsEnabled", @"NO"];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
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

@end
