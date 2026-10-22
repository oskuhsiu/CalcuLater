#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <TargetConditionals.h>
#import <math.h>

/// Only the dedicated, disposable CI-owned iOS 18.5 Simulator may run this test.
/// Settings is the source of truth. Arithmetic launch fixtures do not simulate
/// accessibility, and an endpoint/Completed/Cancelled value is not motion proof.
@interface ReducedMotionTeachingUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@property (nonatomic, strong) XCUIApplication *settings;
@property (nonatomic, copy) NSString *originalReduceMotionValue;
@property (nonatomic, assign) BOOL ownedSimulatorVerified;
@property (nonatomic, assign) BOOL systemReduceMotionVerified;
@end

static BOOL RMUsableFrame(CGRect rect) {
    return !CGRectIsNull(rect) && !CGRectIsInfinite(rect)
        && isfinite(rect.origin.x) && isfinite(rect.origin.y)
        && isfinite(rect.size.width) && isfinite(rect.size.height)
        && rect.size.width > 0 && rect.size.height > 0;
}

@implementation ReducedMotionTeachingUITests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
    self.settings = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.Preferences"];
}

- (void)attachText:(NSString *)text name:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:text];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)capture:(NSString *)name application:(XCUIApplication *)application {
    XCTAttachment *image = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    image.name = name;
    image.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:image];
    XCUIApplicationState state = application.state;
    NSString *hierarchy = state == XCUIApplicationStateNotRunning
        ? @"Application is not running; no accessibility hierarchy is available."
        : application.debugDescription;
    [self attachText:[NSString stringWithFormat:@"applicationState=%lu\n%@",
        (unsigned long)state, hierarchy]
        name:[name stringByAppendingString:@"-hierarchy"]];
}

- (BOOL)fail:(NSString *)reason application:(XCUIApplication *)application {
    [self capture:@"rm-native-failure" application:application];
    XCTFail(@"%@", reason);
    return NO;
}

- (BOOL)confirmOwnedSimulator {
    NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
    NSString *name = environment[@"SIMULATOR_DEVICE_NAME"] ?: @"";
    NSString *udid = environment[@"SIMULATOR_UDID"] ?: @"";
    NSString *version = UIDevice.currentDevice.systemVersion;
    [self attachText:[NSString stringWithFormat:@"simulatorBuild=%d\nname=%@\nudid=%@\niOS=%@",
        TARGET_OS_SIMULATOR, name, udid, version] name:@"rm-owned-simulator-precondition"];
    NSPredicate *ownedName = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",
        @"CalcuLater-quality-[0-9]+-[0-9]+-reducedMotion"];
    BOOL verified = TARGET_OS_SIMULATOR && [ownedName evaluateWithObject:name]
        && [[NSUUID alloc] initWithUUIDString:udid] != nil && [version isEqualToString:@"18.5"];
    if (!verified) {
        // This is a failure, not a skip. Do not even launch Settings on an
        // ordinary developer Simulator or a physical/user-owned device.
        XCTFail(@"Requires the job-owned reducedMotion iOS 18.5 Simulator; no system setting was changed.");
        return NO;
    }
    self.ownedSimulatorVerified = YES;
    [XCUIDevice sharedDevice].orientation = UIDeviceOrientationPortrait;
    return YES;
}

- (XCUIElement *)element:(NSString *)identifier {
    return [self.app descendantsMatchingType:XCUIElementTypeAny][identifier];
}

- (XCUIElement *)settingsElementOfType:(XCUIElementType)type labels:(NSArray<NSString *> *)labels {
    return [[self.settings descendantsMatchingType:type]
        matchingPredicate:[NSPredicate predicateWithFormat:@"label IN %@ OR identifier IN %@", labels, labels]].firstMatch;
}

- (BOOL)waitForValue:(NSString *)value element:(XCUIElement *)element
        application:(XCUIApplication *)application name:(NSString *)name {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"exists == YES AND value == %@", value];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:element];
    if ([XCTWaiter waitForExpectations:@[expectation] timeout:3] != XCTWaiterResultCompleted) {
        return [self fail:[NSString stringWithFormat:@"%@ expected exact value %@; observed %@", name, value, element.value]
            application:application];
    }
    return YES;
}

/// Bounded navigation only. This helper never frames an action after its first
/// play to make a failed visibility assertion pass. Every drag uses live frames.
- (BOOL)reveal:(XCUIElement *)element in:(XCUIElement *)container
        application:(XCUIApplication *)application name:(NSString *)name {
    NSMutableArray<NSString *> *measurements = [NSMutableArray array];
    for (NSUInteger attempt = 0; attempt <= 8; attempt++) {
        if (element.exists && element.hittable) {
            if (measurements.count) [self attachText:[measurements componentsJoinedByString:@"\n"] name:name];
            return YES;
        }
        if (attempt == 8 || !container.exists) break;
        CGRect frame = container.frame;
        CGRect viewport = CGRectIntersection(frame, application.windows.firstMatch.frame);
        if (!RMUsableFrame(frame) || !RMUsableFrame(viewport) || viewport.size.height < 80 || viewport.size.width < 80) break;
        CGRect target = element.exists ? element.frame : CGRectNull;
        CGFloat delta = RMUsableFrame(target) ? CGRectGetMidY(target) - CGRectGetMidY(viewport) : viewport.size.height * 0.32;
        if (fabs(delta) < 2) break; // Occluded center: another swipe is not a fix.
        CGFloat distance = MIN(MAX(fabs(delta), 24), viewport.size.height * 0.32);
        CGFloat startY = CGRectGetMinY(viewport) + viewport.size.height * (delta > 0 ? 0.70 : 0.30);
        CGFloat endY = startY + (delta > 0 ? -distance : distance);
        XCUICoordinate *origin = [container coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
        CGFloat x = CGRectGetMidX(viewport) - CGRectGetMinX(frame);
        XCUICoordinate *start = [origin coordinateWithOffset:CGVectorMake(x, startY - CGRectGetMinY(frame))];
        XCUICoordinate *end = [origin coordinateWithOffset:CGVectorMake(x, endY - CGRectGetMinY(frame))];
        [start pressForDuration:0.05 thenDragToCoordinate:end withVelocity:XCUIGestureVelocitySlow thenHoldForDuration:0.2];
        CGRect after = element.exists ? element.frame : CGRectNull;
        [measurements addObject:[NSString stringWithFormat:
            @"drag=%lu requested=%.2f bounded=%.2f targetBefore=%@ targetAfter=%@ viewport=%@ touchStart=%@ touchEnd=%@",
            (unsigned long)attempt + 1, delta, copysign(distance, delta), NSStringFromCGRect(target),
            NSStringFromCGRect(after), NSStringFromCGRect(viewport), NSStringFromCGPoint(start.screenPoint), NSStringFromCGPoint(end.screenPoint)]];
    }
    [self attachText:[measurements componentsJoinedByString:@"\n"] name:name];
    return [self fail:[NSString stringWithFormat:@"%@ was not reachable within eight geometry-bounded drags.", name] application:application];
}

- (XCUIElement *)settingsScrollContainer {
    for (XCUIElement *container in @[self.settings.tables.firstMatch, self.settings.collectionViews.firstMatch,
                                    self.settings.scrollViews.firstMatch]) {
        if (container.exists && RMUsableFrame(container.frame)) return container;
    }
    return self.settings.tables.firstMatch; // The caller records a real failure.
}

- (BOOL)openSettingsRow:(NSArray<NSString *> *)labels title:(NSArray<NSString *> *)title name:(NSString *)name {
    XCUIElement *row = [self settingsElementOfType:XCUIElementTypeStaticText labels:labels];
    if (![self reveal:row in:[self settingsScrollContainer] application:self.settings name:name]) return NO;
    [row tap];
    XCUIElement *bar = [self settingsElementOfType:XCUIElementTypeNavigationBar labels:title];
    if (![bar waitForExistenceWithTimeout:5]) return [self fail:[name stringByAppendingString:@" did not open its expected Settings page."] application:self.settings];
    return YES;
}

/// Accept only the known root, Accessibility, or Motion pages. A missing route,
/// unexpected alert or localization is retained as a native failure, not bypassed.
- (XCUIElement *)resolveSystemReduceMotionSwitch {
    if (self.settings.state != XCUIApplicationStateRunningForeground) {
        [self fail:@"Settings must be the foreground application for the real system-switch readback." application:self.settings];
        return nil;
    }
    XCUIElement *motion = [self settingsElementOfType:XCUIElementTypeNavigationBar labels:@[@"Motion", @"動態效果"]];
    if (!motion.exists) {
        XCUIElement *accessibility = [self settingsElementOfType:XCUIElementTypeNavigationBar labels:@[@"Accessibility", @"輔助使用"]];
        if (!accessibility.exists) {
            XCUIElement *root = [self settingsElementOfType:XCUIElementTypeNavigationBar labels:@[@"Settings", @"設定"]];
            if (![root waitForExistenceWithTimeout:5]) {
                [self fail:@"Settings did not expose a known navigation root; no deep-link or blind Back retry is permitted." application:self.settings];
                return nil;
            }
            if (![self openSettingsRow:@[@"Accessibility", @"輔助使用"] title:@[@"Accessibility", @"輔助使用"] name:@"rm-settings-accessibility-navigation"]) return nil;
        }
        if (![self openSettingsRow:@[@"Motion", @"動態效果"] title:@[@"Motion", @"動態效果"] name:@"rm-settings-motion-navigation"]) return nil;
    }
    XCUIElement *toggle = [self settingsElementOfType:XCUIElementTypeSwitch labels:@[@"Reduce Motion", @"減少動態效果"]];
    if (![toggle waitForExistenceWithTimeout:5]
        || ![self reveal:toggle in:[self settingsScrollContainer] application:self.settings name:@"rm-settings-reduce-motion-switch"]) {
        [self fail:@"The real Settings Reduce Motion switch is unavailable." application:self.settings];
        return nil;
    }
    return toggle;
}

- (BOOL)enableRealSystemReduceMotion {
    XCTAssertTrue(self.ownedSimulatorVerified);
    // Language selection is for Settings navigation only, never an accessibility
    // preference. The actual Reduce Motion change is a single native UI tap.
    self.settings.launchArguments = @[@"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US"];
    [self.settings launch];
    XCUIElement *toggle = [self resolveSystemReduceMotionSwitch];
    if (!toggle) return NO;
    NSString *before = [toggle.value description];
    [self capture:@"rm-settings-01-original-switch" application:self.settings];
    if (![@[@"0", @"1"] containsObject:before]) return [self fail:@"Reduce Motion switch did not expose an unambiguous 0/1 value; nothing was toggled." application:self.settings];
    // Record BEFORE touching the switch so tearDown can recover even if the
    // post-tap assertion fails. Never retry a toggle with an uncertain outcome.
    self.originalReduceMotionValue = before;
    if ([before isEqualToString:@"0"]) [toggle tap];
    if (![self waitForValue:@"1" element:toggle application:self.settings name:@"System Reduce Motion ON readback"]) return NO;
    [self capture:@"rm-settings-02-enabled-readback" application:self.settings];
    [self attachText:[NSString stringWithFormat:@"bundle=com.apple.Preferences\nroute=Settings > Accessibility > Motion > Reduce Motion\noriginal=%@\nobserved=%@\nenableTapCount=%d",
        before, toggle.value, [before isEqualToString:@"0"] ? 1 : 0] name:@"rm-settings-verified-transition"];
    self.systemReduceMotionVerified = YES;
    return YES;
}

- (void)tearDown {
    // Cleanup is bounded and does not hide the original failure. Continue here
    // only so a failed readback cannot prevent evidence and app termination.
    self.continueAfterFailure = YES;
    if (self.testRun.failureCount > 0 && self.ownedSimulatorVerified) {
        XCUIApplication *foreground = self.settings.state == XCUIApplicationStateRunningForeground ? self.settings : self.app;
        [self capture:@"rm-failure-before-cleanup" application:foreground];
    }
    if (self.ownedSimulatorVerified && self.originalReduceMotionValue) {
        [self.settings activate];
        XCUIElement *toggle = [self resolveSystemReduceMotionSwitch];
        if (toggle) {
            NSString *current = [toggle.value description];
            [self capture:@"rm-settings-03-before-restore" application:self.settings];
            if ([@[@"0", @"1"] containsObject:current]) {
                if (![current isEqualToString:self.originalReduceMotionValue]) [toggle tap];
                [self waitForValue:self.originalReduceMotionValue element:toggle application:self.settings name:@"Restore original system Reduce Motion"];
                [self capture:@"rm-settings-04-restored-readback" application:self.settings];
                [self attachText:[NSString stringWithFormat:@"original=%@\nbeforeCleanup=%@\nobservedAfterCleanup=%@",
                    self.originalReduceMotionValue, current, toggle.value] name:@"rm-settings-cleanup-readback"];
            } else {
                [self fail:@"Cleanup found an ambiguous switch value; no blind toggle was attempted. Dispose of only this job-owned Simulator." application:self.settings];
            }
        }
    }
    if (self.ownedSimulatorVerified) {
        if (self.app.state != XCUIApplicationStateNotRunning) [self.app terminate];
        if (self.settings.state != XCUIApplicationStateNotRunning) [self.settings terminate];
    }
    [super tearDown];
}

- (void)tap:(NSString *)identifier {
    XCUIElement *button = self.app.buttons[identifier];
    XCTAssertTrue([button waitForExistenceWithTimeout:5]);
    XCTAssertTrue(button.hittable && button.enabled, @"%@ must be available to the child.", identifier);
    [button tap];
}

- (void)launchScenario:(NSString *)scenario {
    XCTAssertTrue(self.systemReduceMotionVerified);
    if (self.app.state != XCUIApplicationStateNotRunning) [self.app terminate];
    // Replace, never append fixtures across launches. No motion override exists.
    self.app.launchArguments = @[@"-AppleLanguages", @"(zh-Hant)", @"-AppleLocale", @"zh_TW",
        @"-soundEffectsEnabled", @"NO", @"-answerMode", @"0", @"-CalcuLaterScenario", scenario,
        @"-drillTier", [scenario isEqualToString:@"borrow"] ? @"3" : @"2"];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"home.settings"] waitForExistenceWithTimeout:10]);
}

- (void)tapHome:(NSString *)identifier {
    XCUIElement *card = self.app.buttons[identifier];
    XCTAssertTrue([card waitForExistenceWithTimeout:5]);
    [self reveal:card in:self.app.scrollViews.firstMatch application:self.app name:identifier];
    [self tap:identifier];
}

- (void)assertFullyVisible:(XCUIElement *)element inScroll:(NSString *)identifier {
    XCTAssertEqual(self.app.state, XCUIApplicationStateRunningForeground);
    XCUIElement *scroll = self.app.scrollViews[identifier];
    XCTAssertTrue(element.exists && scroll.exists);
    CGRect frame = element.frame, viewport = CGRectIntersection(scroll.frame, self.app.windows.firstMatch.frame);
    XCTAssertTrue(RMUsableFrame(frame) && RMUsableFrame(viewport));
    XCTAssertGreaterThan(frame.size.width, 44);
    XCTAssertGreaterThan(frame.size.height, 44);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -1, -1), frame),
        @"Complete causal scene must already be visible, without test repair. scene=%@ viewport=%@", NSStringFromCGRect(frame), NSStringFromCGRect(viewport));
}

- (void)assertUnanswered:(NSString *)question identifier:(NSString *)identifier progress:(NSString *)progress {
    XCUIElement *label = self.app.staticTexts[identifier];
    XCTAssertTrue([label waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(label.label, question);
    XCTAssertEqualObjects(self.app.staticTexts[@"session.progress"].label, progress);
    XCTAssertFalse(self.app.buttons[@"session.next"].exists);
    for (NSUInteger index = 0; index < 4; index++) {
        XCUIElement *answer = self.app.buttons[[NSString stringWithFormat:@"answer.%lu", (unsigned long)index]];
        XCTAssertTrue(answer.exists && answer.enabled && answer.hittable);
    }
}

#pragma mark - Actual-question ten frames

- (NSString *)openTenFrame:(NSString *)scenario title:(NSString *)title question:(NSString *)question {
    [self launchScenario:scenario];
    [self tapHome:@"home.lessons"];
    XCUIElement *collection = self.app.collectionViews.firstMatch;
    XCTAssertTrue([collection waitForExistenceWithTimeout:5]);
    XCUIElement *lesson = self.app.staticTexts[title];
    [self reveal:lesson in:collection application:self.app name:[scenario stringByAppendingString:@"-lesson-navigation"]];
    [lesson tap];
    [self tap:@"lessonIntro.start"];
    XCTAssertTrue([self.app.staticTexts[@"lesson.problem"] waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lesson.problem"].label, question);
    NSString *progress = self.app.staticTexts[@"session.progress"].label;
    [self capture:[@"rm-" stringByAppendingFormat:@"%@-question-before", scenario] application:self.app];
    [self tap:@"看怎麼算"];
    XCTAssertTrue([self.app.buttons[@"lessonIntro.next"] waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    XCTAssertFalse(self.app.staticTexts[@"explanation.steps"].exists);
    return progress;
}

- (NSUInteger)tenFrameGeneration {
    NSString *value = [self.app.staticTexts[@"lessonIntro.progress"].value description];
    NSScanner *scanner = [NSScanner scannerWithString:value];
    unsigned long long generation = 0;
    BOOL valid = [scanner scanString:@"第" intoString:nil] && [scanner scanUnsignedLongLong:&generation]
        && [scanner scanString:@"次播放" intoString:nil];
    XCTAssertTrue(valid && generation > 0, @"Expected actual requested playback generation, got %@", value);
    return (NSUInteger)generation;
}

- (void)assertTenFrameStep:(NSUInteger)step generation:(NSUInteger)generation
        first:(NSInteger)first second:(NSInteger)second crossed:(NSInteger)crossed {
    XCUIElement *progress = self.app.staticTexts[@"lessonIntro.progress"];
    NSString *expected = [NSString stringWithFormat:@"第 %lu 次播放，第 %lu 小步，減少動態，直接顯示這一步",
        (unsigned long)generation, (unsigned long)step];
    [self waitForValue:expected element:progress application:self.app name:@"Ten-frame runtime Reduce Motion"];
    NSString *selectedStep = [NSString stringWithFormat:@"第 %lu 小步", (unsigned long)step];
    XCTAssertTrue([progress.label hasPrefix:selectedStep]);
    XCTAssertFalse([[progress.value description] containsString:@"動態播放完成"]);
    XCTAssertFalse([[progress.value description] containsString:@"動態播放中"]);
    XCUIElement *stage = [self element:@"lessonIntro.stage"];
    NSString *counts = [NSString stringWithFormat:@"第一框 %ld 個，第二框 %ld 個；劃掉 %ld 個", (long)first, (long)second, (long)crossed];
    XCTAssertTrue([[stage.value description] hasPrefix:counts]);
    [self assertFullyVisible:stage inScroll:@"lessonIntro.content"];
}

- (void)replayTenFrameAtStep:(NSUInteger)step first:(NSInteger)first second:(NSInteger)second crossed:(NSInteger)crossed name:(NSString *)name {
    NSUInteger generation = [self tenFrameGeneration];
    NSString *selected = self.app.staticTexts[@"lessonIntro.progress"].label;
    NSString *endpoint = [[self element:@"lessonIntro.stage"].value description];
    CGRect before = [self element:@"lessonIntro.stage"].frame;
    [self tap:@"lessonIntro.replay"];
    [self assertTenFrameStep:step generation:generation + 1 first:first second:second crossed:crossed];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.progress"].label, selected);
    XCTAssertEqualObjects([[self element:@"lessonIntro.stage"].value description], endpoint);
    CGRect after = [self element:@"lessonIntro.stage"].frame;
    XCTAssertEqualWithAccuracy(before.origin.y, after.origin.y, 1);
    XCTAssertEqualWithAccuracy(before.size.height, after.size.height, 1);
    [self capture:name application:self.app];
}

- (void)verifyMakeTen {
    NSString *question = @"2 + 9 = ?";
    NSString *questionProgress = [self openTenFrame:@"make-ten-nine" title:@"合十法（進位加）" question:question];
    NSUInteger generation = [self tenFrameGeneration];
    [self assertTenFrameStep:1 generation:generation first:2 second:0 crossed:0];
    [self capture:@"rm-make-ten-01-original-two" application:self.app];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:2 generation:++generation first:2 second:9 crossed:0];
    [self capture:@"rm-make-ten-02-all-nine-incoming" application:self.app];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:3 generation:++generation first:2 second:9 crossed:0];
    XCTAssertTrue([self.app.staticTexts[@"lessonIntro.narration"].label containsString:@"9 拆成 8 和 1"]);
    [self capture:@"rm-make-ten-03-before-transfer-eight-and-one" application:self.app];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:4 generation:++generation first:10 second:1 crossed:0];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self capture:@"rm-make-ten-04-static-conserved-eleven" application:self.app];
    [self replayTenFrameAtStep:4 first:10 second:1 crossed:0 name:@"rm-make-ten-05-replay-same-step"];
    [self tap:@"lessonIntro.previous"];
    XCTAssertTrue([[[self element:@"lessonIntro.stage"] value] hasPrefix:@"第一框 2 個，第二框 9 個"]);
    [self capture:@"rm-make-ten-06-back-before-state" application:self.app];
    generation = [self tenFrameGeneration];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:4 generation:++generation first:10 second:1 crossed:0];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:5 generation:++generation first:10 second:1 crossed:0];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, @"2 + 9 = 11");
    [self capture:@"rm-make-ten-07-teaching-answer-only" application:self.app];
    [self tap:@"lessonIntro.start"];
    [self assertUnanswered:question identifier:@"lesson.problem" progress:questionProgress];
    [self capture:@"rm-make-ten-08-original-question-still-blank" application:self.app];
}

- (void)verifyBreakTen {
    NSString *question = @"18 − 9 = ?";
    NSString *questionProgress = [self openTenFrame:@"break-ten-nine" title:@"破十法（退位減）" question:question];
    NSUInteger generation = [self tenFrameGeneration];
    [self assertTenFrameStep:1 generation:generation first:10 second:8 crossed:0];
    [self capture:@"rm-break-ten-01-original-ten-and-eight" application:self.app];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:2 generation:++generation first:10 second:8 crossed:9];
    [self capture:@"rm-break-ten-02-before-removal-nine-crossed" application:self.app];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:3 generation:++generation first:1 second:8 crossed:0];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, question);
    [self capture:@"rm-break-ten-03-static-original-eight-preserved" application:self.app];
    [self replayTenFrameAtStep:3 first:1 second:8 crossed:0 name:@"rm-break-ten-04-replay-same-step"];
    [self tap:@"lessonIntro.previous"];
    XCTAssertTrue([[[self element:@"lessonIntro.stage"] value] hasPrefix:@"第一框 10 個，第二框 8 個；劃掉 9 個"]);
    [self capture:@"rm-break-ten-05-back-before-removal" application:self.app];
    generation = [self tenFrameGeneration];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:3 generation:++generation first:1 second:8 crossed:0];
    [self tap:@"lessonIntro.next"];
    [self assertTenFrameStep:4 generation:++generation first:1 second:8 crossed:0];
    XCTAssertEqualObjects(self.app.staticTexts[@"lessonIntro.equation"].label, @"18 − 9 = 9");
    [self capture:@"rm-break-ten-06-teaching-answer-only" application:self.app];
    [self tap:@"lessonIntro.start"];
    [self assertUnanswered:question identifier:@"lesson.problem" progress:questionProgress];
    [self capture:@"rm-break-ten-07-original-question-still-blank" application:self.app];
}

#pragma mark - Visible vertical exchanges

- (NSString *)openVertical:(NSString *)scenario question:(NSString *)question {
    [self launchScenario:scenario];
    [self tapHome:@"home.practice"];
    XCTAssertTrue([self.app.staticTexts[@"practice.problem"] waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(self.app.staticTexts[@"practice.problem"].label, question);
    NSString *progress = self.app.staticTexts[@"session.progress"].label;
    [self capture:[@"rm-" stringByAppendingFormat:@"%@-question-before", scenario] application:self.app];
    [self tap:@"看怎麼算"];
    XCTAssertTrue([self.app.buttons[@"teaching.next"] waitForExistenceWithTimeout:5]);
    return progress;
}

- (void)assertVerticalExchange:(NSString *)counts name:(NSString *)name {
    XCUIElement *exchange = [self element:@"verticalTeachingExchange"];
    NSString *expected = [counts stringByAppendingString:@"。減少動態，直接看這一步"];
    [self waitForValue:expected element:exchange application:self.app name:@"Vertical runtime Reduce Motion"];
    XCTAssertFalse([[exchange.value description] containsString:@"動態已播放完成"]);
    XCTAssertFalse([[exchange.value description] containsString:@"正在交換"]);
    XCTAssertFalse([[exchange.value description] containsString:@"動態已暫停"]);
    XCTAssertTrue([[[self element:@"verticalTeachingBoard"] value] containsString:@"答案還沒寫"]);
    [self capture:name application:self.app];
    [self assertFullyVisible:exchange inScroll:@"teaching.content"];
    NSString *step = self.app.staticTexts[@"teaching.progress"].label;
    NSString *summary = [[self element:@"verticalTeachingBoard"].value description];
    CGRect before = exchange.frame;
    [self tap:@"teaching.replay"];
    [self waitForValue:expected element:exchange application:self.app name:@"Vertical Replay remains reduced motion"];
    XCTAssertEqualObjects(self.app.staticTexts[@"teaching.progress"].label, step);
    XCTAssertEqualObjects([[self element:@"verticalTeachingBoard"].value description], summary);
    [self assertFullyVisible:exchange inScroll:@"teaching.content"];
    XCTAssertEqualWithAccuracy(exchange.frame.origin.y, before.origin.y, 1);
    [self capture:[name stringByAppendingString:@"-replay-same-step"] application:self.app];
}

- (void)verifyVerticalExchanges {
    NSString *progress = [self openVertical:@"carry" question:@"27 + 15 = ?"];
    [self tap:@"teaching.next"]; // Prediction is optional and unscored.
    [self tap:@"teaching.next"];
    XCTAssertTrue([self.app.staticTexts[@"explanation.steps"].label containsString:@"7 + 5 = 12"]);
    XCTAssertTrue([[[self element:@"verticalTeachingBoard"] value] containsString:@"答案還沒寫"]);
    [self capture:@"rm-carry-01-twelve-ones-before-exchange" application:self.app];
    [self tap:@"teaching.next"];
    [self assertVerticalExchange:@"個位 12 → 2　・　十位 2 → 3" name:@"rm-carry-02-ten-ones-become-one-ten"];
    [self tap:@"explanation.close"];
    [self assertUnanswered:@"27 + 15 = ?" identifier:@"practice.problem" progress:progress];
    [self capture:@"rm-carry-03-original-question-still-blank" application:self.app];

    progress = [self openVertical:@"borrow" question:@"500 − 128 = ?"];
    [self tap:@"teaching.next"];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"1 個百"]);
    [self capture:@"rm-borrow-01-before-hundred-exchange" application:self.app];
    [self tap:@"teaching.next"];
    [self assertVerticalExchange:@"百位 5 → 4　・　十位 0 → 10" name:@"rm-borrow-02-one-hundred-ten-tens"];
    [self tap:@"teaching.next"];
    XCTAssertTrue([self.app.staticTexts[@"teaching.prompt"].label containsString:@"1 個十"]);
    [self capture:@"rm-borrow-03-before-ten-exchange" application:self.app];
    [self tap:@"teaching.next"];
    [self assertVerticalExchange:@"十位 10 → 9　・　個位 0 → 10" name:@"rm-borrow-04-one-ten-ten-ones"];
    [self tap:@"explanation.close"];
    [self assertUnanswered:@"500 − 128 = ?" identifier:@"practice.problem" progress:progress];
    [self capture:@"rm-borrow-05-original-question-still-blank" application:self.app];
}

#pragma mark - Sharing and packing retain different meanings

- (void)assertGroupingCounts:(NSArray<NSNumber *> *)counts pool:(NSInteger)pool sharing:(BOOL)sharing {
    XCUIElementQuery *boards = [[self.app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"groupingTeachingBoard"];
    XCTAssertEqual(boards.count, 1U, @"Only the visible focus or overview may expose the board identifier, never both.");
    NSString *value = [[self element:@"groupingTeachingBoard"].value description];
    NSString *groupName = sharing ? @"個小朋友" : @"包";
    NSRegularExpression *groups = [NSRegularExpression regularExpressionWithPattern:@"第 ([0-9]+) (個小朋友|包)有 ([0-9]+) 顆" options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [groups matchesInString:value options:0 range:NSMakeRange(0, value.length)];
    XCTAssertEqual(matches.count, counts.count, @"No duplicated or missing recipients/bags: %@", value);
    NSInteger total = pool;
    for (NSUInteger index = 0; index < counts.count; index++) {
        NSString *expected = [NSString stringWithFormat:@"第 %lu %@有 %@ 顆", (unsigned long)index + 1, groupName, counts[index]];
        XCTAssertTrue([value containsString:expected], @"%@", value);
        total += counts[index].integerValue;
    }
    NSString *poolPrefix = sharing ? @"待分的糖果：" : @"待分組的糖果：";
    XCTAssertEqual([value componentsSeparatedByString:poolPrefix].count, 2U, @"Exactly one common pool, not a pool per group.");
    NSString *expectedPool = [poolPrefix stringByAppendingFormat:@"%ld 顆", (long)pool];
    XCTAssertTrue([value containsString:expectedPool]);
    XCTAssertEqual(total, 23, @"All original objects remain in the groups or the one source pool.");
    XCTAssertTrue([value containsString:@"答案還沒寫"]);
    XCTAssertFalse([value containsString:@"正在移動"]);
    XCTAssertFalse([value containsString:@"移動中："]);
}

- (void)assertGroupingReducedAction:(NSString *)action counts:(NSArray<NSNumber *> *)counts
        pool:(NSInteger)pool sharing:(BOOL)sharing name:(NSString *)name {
    XCUIElement *board = [self element:@"groupingTeachingBoard"];
    NSString *value = [board.value description];
    XCTAssertTrue([value hasPrefix:[action stringByAppendingString:@"。"]], @"%@", value);
    XCTAssertTrue([value hasSuffix:@"播放狀態：reduced-motion"], @"Require runtime reduced-motion, not any static endpoint: %@", value);
    for (NSString *forbidden in @[@"播放完成", @"播放狀態：running", @"播放狀態：cancelled", @"播放狀態：paused-visibility"]) {
        XCTAssertFalse([value containsString:forbidden]);
    }
    [self assertGroupingCounts:counts pool:pool sharing:sharing];
    [self capture:name application:self.app];
    [self assertFullyVisible:board inScroll:@"grouping.content"];
}

- (void)compareAndReplayFirstGroupingAction:(NSString *)action after:(NSArray<NSNumber *> *)after
        pool:(NSInteger)pool sharing:(BOOL)sharing name:(NSString *)name {
    NSString *selected = self.app.staticTexts[@"grouping.progress"].label;
    NSString *endpoint = [[self element:@"groupingTeachingBoard"].value description];
    XCUIElement *compare = self.app.buttons[@"grouping.compare"];
    [self reveal:compare in:self.app.scrollViews[@"grouping.content"] application:self.app name:[name stringByAppendingString:@"-compare-navigation"]];
    [self tap:@"grouping.compare"];
    NSString *before = [[self element:@"groupingTeachingBoard"].value description];
    XCTAssertTrue([before hasPrefix:[action stringByAppendingString:@"。"]]);
    XCTAssertTrue([before containsString:@"動作前 · 先數一數"]);
    XCTAssertTrue([before hasSuffix:@"播放狀態：reduced-motion"]);
    XCTAssertEqualObjects(self.app.buttons[@"grouping.compare"].label, @"看動作後");
    for (NSString *forbidden in @[@"播放完成", @"播放狀態：running", @"播放狀態：cancelled", @"播放狀態：paused-visibility"]) {
        XCTAssertFalse([before containsString:forbidden]);
    }
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, selected);
    [self assertGroupingCounts:sharing ? @[@0, @0, @0, @0] : @[@0] pool:23 sharing:sharing];
    [self assertFullyVisible:[self element:@"groupingTeachingBoard"] inScroll:@"grouping.content"];
    [self capture:[name stringByAppendingString:@"-explicit-before-state"] application:self.app];
    // Before is a separate displayed endpoint while the actual motion mode stays
    // reduced-motion. This comparison never substitutes for static AFTER proof.
    [self tap:@"grouping.replay"];
    [self assertGroupingReducedAction:action counts:after pool:pool sharing:sharing name:[name stringByAppendingString:@"-replay-static-after"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"grouping.progress"].label, selected);
    XCTAssertEqualObjects([[self element:@"groupingTeachingBoard"].value description], endpoint);
}

- (void)verifyGrouping:(BOOL)sharing {
    NSString *scenario = sharing ? @"sharing" : @"packing";
    [self launchScenario:scenario];
    [self tapHome:@"home.stories"];
    [self tap:@"stories.grade.3"];
    XCUIElement *story = self.app.staticTexts[@"story.text"];
    XCTAssertTrue([story waitForExistenceWithTimeout:5]);
    NSString *question = story.label;
    NSString *progress = self.app.staticTexts[@"session.progress"].label;
    XCTAssertTrue([question containsString:sharing ? @"平均分給 4 個小朋友" : @"每 4 顆裝成一包"]);
    [self capture:[@"rm-" stringByAppendingFormat:@"%@-00-question-before", scenario] application:self.app];
    [self tap:@"看怎麼算"];
    XCTAssertTrue([self.app.buttons[@"grouping.next"] waitForExistenceWithTimeout:5]);
    XCTAssertFalse(self.app.buttons[@"grouping.changeMeaning"].exists);
    [self assertGroupingCounts:sharing ? @[@0, @0, @0, @0] : @[] pool:23 sharing:sharing];
    [self capture:[@"rm-" stringByAppendingFormat:@"%@-01-original-common-pool", scenario] application:self.app];

    // Exactly five rounds/bags. A sharing scene can legitimately choose a full
    // round only if its *entire* real causal frame fits; otherwise every one of
    // the four recipients is inspected. No skip-round or blind next-until loop.
    for (NSInteger round = 1; round <= 5; round++) {
        [self tap:@"grouping.next"]; // Prediction.
        XCTAssertTrue(self.app.staticTexts[@"grouping.prompt"].exists);
        [self tap:@"grouping.next"]; // First action of this round/bag.
        NSString *value = [[self element:@"groupingTeachingBoard"].value description];
        NSString *fullAction = [NSString stringWithFormat:@"第 %ld 輪 · 每位再拿 1 顆", (long)round];
        NSString *firstRecipient = [NSString stringWithFormat:@"第 %ld 輪 · 第 1 / 4 位", (long)round];
        BOOL split = sharing && [value hasPrefix:[firstRecipient stringByAppendingString:@"。"]];
        if (sharing) XCTAssertTrue(split || [value hasPrefix:[fullAction stringByAppendingString:@"。"]], @"Unknown sharing action: %@", value);
        NSInteger actionCount = split ? 4 : 1;
        for (NSInteger actionIndex = 0; actionIndex < actionCount; actionIndex++) {
            if (actionIndex > 0) [self tap:@"grouping.next"];
            NSMutableArray<NSNumber *> *counts = [NSMutableArray array];
            if (sharing) {
                for (NSInteger recipient = 0; recipient < 4; recipient++) [counts addObject:@(round - (split && recipient > actionIndex ? 1 : 0))];
            } else {
                for (NSInteger bag = 0; bag < round; bag++) [counts addObject:@4];
            }
            NSInteger pool = 23 - (sharing && split ? (round - 1) * 4 + actionIndex + 1 : round * 4);
            NSString *action = sharing ? (split ? [NSString stringWithFormat:@"第 %ld 輪 · 第 %ld / 4 位", (long)round, (long)actionIndex + 1] : fullAction)
                : [NSString stringWithFormat:@"第 %ld 包 · 每包 4 顆", (long)round];
            NSString *name = [NSString stringWithFormat:@"rm-%@-round-%ld-action-%ld", scenario, (long)round, (long)actionIndex + 1];
            [self assertGroupingReducedAction:action counts:counts pool:pool sharing:sharing name:name];
            if (round == 1 && actionIndex == 0) [self compareAndReplayFirstGroupingAction:action after:counts pool:pool sharing:sharing name:name];
        }
    }
    [self tap:@"grouping.next"]; // Can the common remainder make another round/bag?
    XCTAssertTrue([self.app.staticTexts[@"grouping.prompt"].label containsString:sharing ? @"還能讓每個小朋友再拿 1 顆嗎" : @"還夠再分成完整的一包嗎"]);
    [self tap:@"grouping.next"];
    [self assertGroupingCounts:sharing ? @[@5, @5, @5, @5] : @[@4, @4, @4, @4, @4] pool:3 sharing:sharing];
    NSString *remainder = [[self element:@"groupingTeachingBoard"].value description];
    XCTAssertEqual([remainder componentsSeparatedByString:@"共同剩下：3 顆糖果"].count, 2U);
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:sharing ? @"不是每個小朋友各剩一份" : @"不是完整的包"]);
    [self capture:[@"rm-" stringByAppendingFormat:@"%@-common-remainder-three", scenario] application:self.app];
    [self tap:@"grouping.next"];
    XCTAssertTrue([self.app.staticTexts[@"grouping.explanation"].label containsString:sharing ? @"最多有 5 顆" : @"可以分成 5 包"]);
    [self capture:[@"rm-" stringByAppendingFormat:@"%@-distinct-answer-unit", scenario] application:self.app];
    [self tap:@"explanation.close"];
    [self assertUnanswered:question identifier:@"story.text" progress:progress];
    [self capture:[@"rm-" stringByAppendingFormat:@"%@-original-question-still-blank", scenario] application:self.app];
}

- (void)testSystemReduceMotionPreservesStaticTeachingAndUnansweredQuestions {
    if (![self confirmOwnedSimulator] || ![self enableRealSystemReduceMotion]) return;
    [self verifyMakeTen];
    [self verifyBreakTen];
    [self verifyVerticalExchanges];
    [self verifyGrouping:YES];
    [self verifyGrouping:NO];
    [self.settings activate];
    XCUIElement *toggle = [self resolveSystemReduceMotionSwitch];
    if (!toggle) return;
    [self waitForValue:@"1" element:toggle application:self.settings name:@"System Reduce Motion remained ON through every app launch"];
    [self capture:@"rm-settings-05-still-enabled-after-all-teaching" application:self.settings];
    // tearDown restores and verifies the original switch, even after a failure.
}

@end
