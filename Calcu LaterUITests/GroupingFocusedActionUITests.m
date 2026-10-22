#import <XCTest/XCTest.h>
#import <math.h>

/// Real app geometry and lifecycle. Run these selectors at normal and maximum
/// system text size. Actual system Reduce Motion has a separate Settings suite.
@interface GroupingFocusedActionUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end
@implementation GroupingFocusedActionUITests
- (void)setUp { [super setUp]; self.continueAfterFailure = NO; XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait; self.app = [[XCUIApplication alloc] init]; }
- (void)tearDown {
    if (self.testRun.failureCount) [self capture:@"focused-action-failure"];
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait; [self.app terminate]; [super tearDown];
}
- (void)capture:(NSString *)name {
    XCTAttachment *screen = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    screen.name = name; screen.lifetime = XCTAttachmentLifetimeKeepAlways; [self addAttachment:screen];
    XCTAttachment *tree = [XCTAttachment attachmentWithString:self.app.debugDescription];
    tree.name = [name stringByAppendingString:@"-hierarchy"]; tree.lifetime = XCTAttachmentLifetimeKeepAlways; [self addAttachment:tree];
}
- (XCUIElement *)board { return [self.app descendantsMatchingType:XCUIElementTypeAny][@"groupingTeachingBoard"]; }
- (XCUIElement *)content { return self.app.scrollViews[@"grouping.content"]; }
- (NSString *)value { return [self.board.value description]; }
- (void)open:(NSString *)scenario {
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)", @"-AppleLocale", @"zh_TW", @"-soundEffectsEnabled", @"NO", @"-CalcuLaterScenario", scenario, @"-drillTier", @"2"];
    [self.app launch]; XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
    XCUIElement *stories = self.app.buttons[@"home.stories"]; if (!stories.hittable) [self.app.scrollViews.firstMatch swipeUp];
    XCTAssertTrue(stories.hittable); [stories tap]; [self.app.buttons[@"stories.grade.3"] tap]; [self.app.buttons[@"看怎麼算"] tap];
    XCTAssertTrue([self.app.buttons[@"grouping.next"] waitForExistenceWithTimeout:5]); XCTAssertFalse(self.app.buttons[@"grouping.changeMeaning"].exists);
}
- (void)next { [self.app.buttons[@"grouping.next"] tap]; }
- (void)waitForNaturalCompletionWithTransfers:(NSUInteger)transfers {
    // Declared lead + visible serial legs + tail, plus1s runner slack. Selected
    // after-state totals cannot satisfy this natural renderer-lifecycle assertion.
    NSTimeInterval duration = 0.28 + 0.82 * transfers + 0.24;
    NSTimeInterval started = NSProcessInfo.processInfo.systemUptime;
    NSMutableArray<NSString *> *samples = [NSMutableArray array];
    NSPredicate *completed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary<NSString *, id> *bindings) {
        NSTimeInterval queryStarted = NSProcessInfo.processInfo.systemUptime - started;
        XCUIElement *board = [self.app descendantsMatchingType:XCUIElementTypeAny][@"groupingTeachingBoard"];
        BOOL exists = board.exists;
        NSString *value = exists ? ([board.value description] ?: @"<nil groupingTeachingBoard.value>") : @"<missing groupingTeachingBoard>";
        // Preserve BOTH original requirements. Selected final counts, a pause,
        // cancellation, or a static endpoint are not natural completion.
        BOOL matches = exists && [value containsString:@"播放狀態：completed"] && [value containsString:@"播放完成"];
        [samples addObject:[NSString stringWithFormat:@"sample=%lu queryStarted=%.6f observed=%.6f exists=%d matches=%d value=%@",
            (unsigned long)samples.count + 1, queryStarted, NSProcessInfo.processInfo.systemUptime - started,
            exists, matches, value]];
        return matches;
    }];
    XCTNSPredicateExpectation *ready = [[XCTNSPredicateExpectation alloc] initWithPredicate:completed object:nil];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ready] timeout:duration + 1.0];
    NSString *trace = [NSString stringWithFormat:@"transfers=%lu timeout=%.3f elapsed=%.6f result=%ld\n%@",
        (unsigned long)transfers, duration + 1.0, NSProcessInfo.processInfo.systemUptime - started, (long)result,
        [samples componentsJoinedByString:@"\n"]];
    XCTAttachment *observations = [XCTAttachment attachmentWithString:trace];
    observations.name = @"focused-grouping-natural-completion-observations";
    observations.lifetime = XCTAttachmentLifetimeKeepAlways;
    // Retain samples before the failure assertion can stop this test.
    [self addAttachment:observations];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"The live action must naturally complete within %.3f seconds.", duration + 1.0);
}
- (void)assertActionFullyVisible {
    XCTAssertEqual([[self.app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"groupingTeachingBoard"].count, 1u);
    CGRect board = self.board.frame, viewport = self.content.frame;
    XCTAssertTrue(self.board.exists && self.content.exists); XCTAssertTrue(isfinite(board.origin.y) && isfinite(board.size.height)); XCTAssertGreaterThan(board.size.height, 100);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -1, -1), board), @"complete causal scene %@ must be inside %@", NSStringFromCGRect(board), NSStringFromCGRect(viewport));
}
- (void)revealControl:(XCUIElement *)element {
    // Inspection only. Never used to rescue a clipped first-play/replay action.
    XCTAssertTrue(element.exists);
    for (NSUInteger attempt = 0; attempt < 10; attempt++) {
        CGRect rect = element.frame, viewport = self.content.frame;
        if (element.hittable && CGRectContainsRect(viewport, rect)) return;
        CGFloat delta = CGRectGetMinY(rect) < CGRectGetMinY(viewport) ? CGRectGetMinY(rect) - CGRectGetMinY(viewport) - 8 : CGRectGetMaxY(rect) - CGRectGetMaxY(viewport) + 8;
        CGFloat distance = MIN(fabs(delta), viewport.size.height * 0.3), startY = delta > 0 ? 0.7 : 0.3;
        XCUICoordinate *start = [self.content coordinateWithNormalizedOffset:CGVectorMake(0.5, startY)];
        XCUICoordinate *end = [self.content coordinateWithNormalizedOffset:CGVectorMake(0.5, startY + (delta > 0 ? -1 : 1) * distance / viewport.size.height)];
        [start pressForDuration:0.05 thenDragToCoordinate:end withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
    }
    XCTAssertTrue(element.hittable);
}
- (void)selectFirstRecipientIfFullRound {
    if ([self.value containsString:@"每位再拿 1 顆"]) {
        [self waitForNaturalCompletionWithTransfers:4]; [self capture:@"focused-full-fitting-sharing-round"];
        XCUIElement *split = self.app.buttons[@"grouping.splitRound"]; XCTAssertTrue(split.exists); [self revealControl:split]; [split tap];
    }
    XCTAssertTrue([self.value containsString:@"第 1 / 4 位"]);
}
- (void)assertMainQuestionUnansweredAfterClose {
    [self.app.buttons[@"explanation.close"] tap]; XCTAssertTrue(self.app.buttons[@"answer.0"].enabled); XCTAssertFalse(self.app.buttons[@"session.next"].exists);
}
- (void)testSharingFirstPlayReplayAndFourthRecipientStayFullyVisible {
    [self open:@"sharing"]; [self next]; [self next]; [self assertActionFullyVisible];
    [self capture:@"focused-sharing-first-play-entry"]; [self selectFirstRecipientIfFullRound];
    for (NSUInteger recipient = 1; recipient <= 4; recipient++) {
        [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:1];
        XCTAssertTrue(([self.value containsString:[NSString stringWithFormat:@"第 %lu / 4 位", (unsigned long)recipient]]));
        XCTAssertTrue(([self.value containsString:[NSString stringWithFormat:@"待分的糖果：%lu 顆", (unsigned long)(23 - recipient)]]));
        XCTAssertTrue([self.value containsString:@"答案還沒寫"]);
        NSString *selected = self.value; [self capture:[NSString stringWithFormat:@"focused-sharing-recipient-%lu-natural-end", (unsigned long)recipient]];
        XCTAssertEqualObjects(self.value, selected, @"Next recipient is a child choice, not automatic playback.");
        if (recipient < 4) [self next];
    }
    for (NSUInteger replay = 0; replay < 2; replay++) {
        [self.app.buttons[@"grouping.replay"] tap]; [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:1];
        XCTAssertTrue([self.value containsString:@"第 4 個小朋友有 1 顆"]); XCTAssertTrue([self.value containsString:@"待分的糖果：19 顆"]);
    }
    [self.app.buttons[@"grouping.previous"] tap]; XCTAssertTrue([self.value containsString:@"第 3 / 4 位"]); XCTAssertTrue([self.value containsString:@"待分的糖果：20 顆"]); XCTAssertFalse([self.value containsString:@"播放完成"]);
    [self next]; [self waitForNaturalCompletionWithTransfers:1]; [self.app.buttons[@"grouping.viewMode"] tap]; XCTAssertTrue([self.value containsString:@"第 4 個小朋友有 1 顆"]);
    [self.app.buttons[@"grouping.replay"] tap]; [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:1];
    [self capture:@"focused-fourth-recipient-replay-from-overview"]; [self assertMainQuestionUnansweredAfterClose];
}
- (void)testPackingFirstAndFifthBagUseOneVisibleSourceToTargetRoute {
    [self open:@"packing"]; [self next]; [self next];
    for (NSUInteger bag = 1; bag <= 5; bag++) {
        [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:4];
        XCTAssertTrue(([self.value containsString:[NSString stringWithFormat:@"第 %lu 包有 4 顆", (unsigned long)bag]]));
        XCTAssertTrue(([self.value containsString:[NSString stringWithFormat:@"待分組的糖果：%lu 顆", (unsigned long)(23 - 4 * bag)]]));
        XCTAssertTrue([self.value containsString:@"答案還沒寫"]);
        if (bag == 1 || bag >= 4) [self capture:[NSString stringWithFormat:@"focused-packing-bag-%lu-natural-end", (unsigned long)bag]];
        if (bag < 5) { [self next]; [self next]; }
    }
    [self.app.buttons[@"grouping.replay"] tap]; [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:4]; XCTAssertTrue([self.value containsString:@"已分成 5 包"]);
    [self.app.buttons[@"grouping.previous"] tap]; [self.app.buttons[@"grouping.previous"] tap];
    XCTAssertTrue([self.value containsString:@"第 4 包有 4 顆"]); XCTAssertFalse([self.value containsString:@"第 5 包有"]);
    [self.app.buttons[@"grouping.replay"] tap]; [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:4];
    [self capture:@"focused-packing-fourth-bag-revisit"]; [self assertMainQuestionUnansweredAfterClose];
}
- (void)assertFeedbackVisibleContaining:(NSArray<NSString *> *)phrases {
    XCUIElement *feedback = self.app.staticTexts[@"grouping.feedback"]; XCTAssertTrue(feedback.hittable);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(self.content.frame, -1, -1), feedback.frame), @"Feedback must be focused without an extra swipe: %@ in %@", NSStringFromCGRect(feedback.frame), NSStringFromCGRect(self.content.frame));
    for (NSString *phrase in phrases) XCTAssertTrue([feedback.label containsString:phrase], @"%@ in %@", phrase, feedback.label);
}
- (void)testWrongCountAndContinuationCoachTheChosenQuantityWithoutAdvancing {
    [self open:@"sharing"]; [self next]; NSString *progress = self.app.staticTexts[@"grouping.progress"].label;
    [self.app.buttons[@"grouping.choice.2"] tap]; [self assertFeedbackVisibleContaining:@[@"你選 2 顆", @"現在有 0 顆", @"只再拿 1 顆", @"共同待分還有 23 顆"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress); XCTAssertFalse(self.app.buttons[@"grouping.choice.2"].enabled);
    [self capture:@"focused-wrong-count-feedback-no-scroll"]; [self.app.buttons[@"grouping.viewMode"] tap];
    XCTAssertTrue([self.value containsString:@"第 4 個小朋友有 0 顆"]); XCTAssertTrue([self.value containsString:@"待分的糖果：23 顆"]);
    [self.app.buttons[@"grouping.viewMode"] tap]; XCTAssertTrue(self.app.buttons[@"grouping.choice.1"].hittable); [self.app.buttons[@"grouping.choice.1"] tap];
    [self assertFeedbackVisibleContaining:@[@"你選 1 顆", @"共同待分還有 23 顆"]]; XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    [self capture:@"focused-correct-count-feedback-no-scroll"]; [self next];
    for (NSUInteger round = 1; round <= 5; round++) {
        if ([self.app.buttons[@"grouping.next"].label isEqualToString:@"下一位"]) {
            XCUIElement *skip = self.app.buttons[@"grouping.skipRound"]; [self revealControl:skip]; [skip tap];
            XCTAssertTrue([self.app.staticTexts[@"grouping.visibilityNotice"].label containsString:@"剛才沒播放的動作不算看過"]); XCTAssertFalse([self.value containsString:@"播放完成"]);
        }
        [self next]; if (round < 5) [self next];
    }
    XCTAssertTrue([self.app.staticTexts[@"grouping.prompt"].label containsString:@"還能讓每個小朋友再拿 1 顆嗎"]);
    progress = self.app.staticTexts[@"grouping.progress"].label; [self.app.buttons[@"grouping.choice.1"] tap];
    [self assertFeedbackVisibleContaining:@[@"你選「還可以」", @"只有 3 顆", @"要 4 顆", @"還差 1 顆", @"沒有讓每位都再拿 1 顆"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    [self capture:@"focused-wrong-continuation-feedback-no-scroll"]; [self assertMainQuestionUnansweredAfterClose];
}
- (void)testLandscapePausePreservesSelectionUntilExplicitReplay {
    [self open:@"sharing"]; [self next]; [self next]; [self selectFirstRecipientIfFullRound]; [self waitForNaturalCompletionWithTransfers:1];
    NSString *progress = self.app.staticTexts[@"grouping.progress"].label;
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft; [self.app.buttons[@"grouping.replay"] tap];
    BOOL cannotFit = self.board.frame.size.height > self.content.frame.size.height - 8;
    if (cannotFit) {
        XCTAssertTrue([self.value containsString:@"播放狀態：paused-visibility"]); XCTAssertFalse([self.value containsString:@"播放完成"]);
        XCUIElement *notice = self.app.staticTexts[@"grouping.visibilityNotice"]; XCTAssertTrue(notice.hittable); XCTAssertTrue([notice.label containsString:@"轉直後按重看"]);
        [self capture:@"focused-landscape-honest-pause"];
    } else { [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:1]; }
    XCTAssertTrue([self.value containsString:@"待分的糖果：22 顆"]); XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, progress);
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;
    if (cannotFit) XCTAssertFalse([self.value containsString:@"播放完成"], @"Rotation alone must not restart playback.");
    XCTAssertTrue([self.value containsString:@"第 1 / 4 位"]);
    [self.app.buttons[@"grouping.replay"] tap]; [self assertActionFullyVisible]; [self waitForNaturalCompletionWithTransfers:1];
    [XCUIDevice.sharedDevice pressButton:XCUIDeviceButtonHome]; [self.app activate];
    XCTAssertTrue([self.value containsString:@"第 1 / 4 位"]); XCTAssertTrue([self.value containsString:@"待分的糖果：22 顆"]);
    [self capture:@"focused-portrait-explicit-replay-after-pause"]; [self assertMainQuestionUnansweredAfterClose];
}
@end
