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
    [self.app.buttons[@"lesson.close"] tap];
    XCTAssertTrue([self.app.collectionViews.firstMatch waitForExistenceWithTimeout:5]);
    [self.app.buttons[@"navigation.home"] tap];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:5]);
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
        if (choice.label.integerValue == answer) {
            correct = choice;
        } else if (wrongCount < 2) {
            [choice tap];
            XCTAssertFalse(choice.enabled);
            wrongCount++;
        }
    }
    XCTAssertEqual(wrongCount, 2);
    XCTAssertNotNil(correct);
    [self capture:@"08-practice-after-two-misses"];
    [correct tap];
    NSPredicate *streak = [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"連對 ×1"];
    XCTestExpectation *updated = [self expectationForPredicate:streak
        evaluatedWithObject:self.app.staticTexts[@"practice.streak"] handler:nil];
    [self waitForExpectations:@[updated] timeout:5];
    [self capture:@"09-practice-correct"];
    [self.app.buttons[@"practice.close"] tap];
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
    [self.app.buttons[@"story.close"] tap];
    XCTAssertTrue([self.app.buttons[@"stories.grade.1"] waitForExistenceWithTimeout:5]);
    [self.app.buttons[@"navigation.home"] tap];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:5]);
}

@end
