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
    [self.app.buttons[@"explanation.close"] tap];
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
    self.app.launchArguments = [self.app.launchArguments arrayByAddingObjectsFromArray:@[@"-CalcuLaterScenario", scenario]];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
}

- (void)testRemainderExplanationAndChildPacedCompletion {
    [self relaunchScenario:@"remainder"];
    [self tapHomeCard:@"home.stories"];
    [self.app.buttons[@"stories.grade.3"] tap];
    XCTAssertTrue([self.app.staticTexts[@"story.text"] waitForExistenceWithTimeout:5]);
    NSString *story = self.app.staticTexts[@"story.text"].label;
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
        @"-soundEffectsEnabled", @"NO", @"-CalcuLaterScenario", @"borrow"];
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

@end
