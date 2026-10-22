#import <XCTest/XCTest.h>
#import "ConceptLearningPath.h"
#import "ConceptLearningPathViewController.h"
#import "ArithmeticProblem.h"
#import "SpeechManager.h"
#import "ChildUIKit.h"

@interface ConceptLearningPathViewController (QuestionControlsTests)
- (ConceptLearningExample *)currentExample;
- (SpeechManager *)questionSpeechManager;
- (void)readQuestion;
- (void)stopQuestionReading;
- (void)previous;
- (void)next;
- (void)changeNumbers;
- (void)previousNumbers;
- (void)openTeaching;
- (void)close;
@end

/// A silent selector-compatible service, not an AVSpeechSynthesizer. Retaining
/// old completions deliberately lets tests simulate a delayed cancelled read.
@interface DiscoveryQuestionSpeechSpy : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *requests;
@property (nonatomic, strong) NSMutableArray *completions;
@property (nonatomic, copy) void (^currentCompletion)(void);
@property (nonatomic) NSUInteger stopCount;
@property (nonatomic) BOOL receivedRangeCallback;
- (void)speak:(NSString *)text willSpeakRange:(void (^)(NSRange))range onFinish:(void (^)(void))finish;
- (void)stop;
- (void)completeCurrentReading;
@end
@implementation DiscoveryQuestionSpeechSpy
- (instancetype)init {
    self = [super init];
    if (self) { _requests = [NSMutableArray array]; _completions = [NSMutableArray array]; }
    return self;
}
- (void)speak:(NSString *)text willSpeakRange:(void (^)(NSRange))range onFinish:(void (^)(void))finish {
    [self completeCurrentReading]; // SpeechManager interrupts its former owner synchronously.
    [self.requests addObject:text];
    self.receivedRangeCallback |= range != nil;
    self.currentCompletion = finish;
    if (finish) [self.completions addObject:[finish copy]];
}
- (void)completeCurrentReading {
    void (^finish)(void) = self.currentCompletion;
    self.currentCompletion = nil;
    if (finish) finish();
}
- (void)stop { self.stopCount++; [self completeCurrentReading]; }
@end

@interface DiscoveryQuestionController : ConceptLearningPathViewController
@property (nonatomic, strong) DiscoveryQuestionSpeechSpy *speechSpy;
@property (nonatomic) BOOL recordDismissalOnly;
@property (nonatomic) NSUInteger dismissalCount;
@property (nonatomic) NSUInteger stopCountAtDismissal;
@property (nonatomic) NSUInteger disappearanceCount;
@property (nonatomic) NSUInteger stopCountBeforeDisappearanceHook;
@end
@implementation DiscoveryQuestionController
- (SpeechManager *)questionSpeechManager { return (SpeechManager *)self.speechSpy; }
- (void)viewWillDisappear:(BOOL)animated {
    self.disappearanceCount++;
    self.stopCountBeforeDisappearanceHook = self.speechSpy.stopCount;
    [super viewWillDisappear:animated];
}
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    if (self.recordDismissalOnly) {
        self.dismissalCount++;
        self.stopCountAtDismissal = self.speechSpy.stopCount;
        if (completion) completion();
        return;
    }
    [super dismissViewControllerAnimated:animated completion:completion];
}
// Do not override presentViewController: the real page-sheet test must reach
// production's presentation-time speech cancellation, not a presentation spy.
@end

@interface ConceptQuestionListeningAndComparisonTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) DiscoveryQuestionController *controller;
@property (nonatomic, strong) DiscoveryQuestionSpeechSpy *speech;
@end
@implementation ConceptQuestionListeningAndComparisonTests
- (void)removeHost {
    [self.controller stopQuestionReading];
    if (self.controller.presentedViewController) [self.controller dismissViewControllerAnimated:NO completion:nil];
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    self.controller = nil; self.window = nil; self.speech = nil;
}
- (void)tearDown { [self removeHost]; [super tearDown]; }
- (ConceptLearningPath *)path:(NSString *)pathID {
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) if ([path.pathID isEqualToString:pathID]) return path;
    XCTFail(@"Missing path %@", pathID); return nil;
}
- (void)settleLayout {
    for (NSUInteger pass = 0; pass < 4; pass++) {
        [self.window setNeedsLayout]; [self.window layoutIfNeeded];
        [self.controller.view setNeedsLayout]; [self.controller.view layoutIfNeeded];
    }
}
- (void)showPath:(ConceptLearningPath *)path size:(CGSize)size category:(UIContentSizeCategory)category {
    [self removeHost];
    self.speech = [[DiscoveryQuestionSpeechSpy alloc] init];
    self.controller = [[DiscoveryQuestionController alloc] initWithPath:path];
    self.controller.speechSpy = self.speech;
    self.controller.traitOverrides.preferredContentSizeCategory = category;
    self.window = [[UIWindow alloc] initWithFrame:(CGRect){CGPointZero, size}];
    [self.controller.traitCollection performAsCurrentTraitCollection:^{
        self.window.rootViewController = self.controller;
        self.window.hidden = NO;
        [self.controller loadViewIfNeeded];
    }];
    self.controller.view.frame = self.window.bounds;
    [self settleLayout];
    XCTAssertNotNil(self.controller.view.window);
    XCTAssertEqualWithAccuracy(self.controller.view.bounds.size.width, size.width, 0.5);
    XCTAssertEqualWithAccuracy(self.controller.view.bounds.size.height, size.height, 0.5);
    XCTAssertEqualObjects(self.controller.traitCollection.preferredContentSizeCategory, category);
}
- (void)showPath:(NSString *)pathID {
    [self showPath:[self path:pathID] size:CGSizeMake(393, 852) category:UIContentSizeCategoryLarge];
}
- (UIView *)find:(NSString *)identifier inView:(UIView *)view {
    if ([view.accessibilityIdentifier isEqualToString:identifier]) return view;
    for (UIView *child in view.subviews) {
        UIView *found = [self find:identifier inView:child];
        if (found) return found;
    }
    return nil;
}
- (UIView *)view:(NSString *)identifier {
    UIView *view = [self find:identifier inView:self.controller.view];
    XCTAssertNotNil(view, @"%@", identifier); return view;
}
- (UIButton *)readButton { return (UIButton *)[self view:@"concept.read"]; }
- (void)tapRead { [self.readButton sendActionsForControlEvents:UIControlEventTouchUpInside]; }
- (NSDictionary *)savedProgress {
    NSMutableDictionary *saved = [NSMutableDictionary dictionary];
    NSDictionary *defaults = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (NSString *key in defaults) {
        if ([key hasPrefix:@"lesson."] || [key hasPrefix:@"practice.v1."]) saved[key] = defaults[key];
    }
    return saved;
}
- (void)assertQuestionUnchanged:(ConceptLearningExample *)example stage:(NSUInteger)stage variation:(NSUInteger)variation {
    XCTAssertEqual(self.controller.currentExample, example);
    XCTAssertEqual([[self.controller valueForKey:@"stageIndex"] unsignedIntegerValue], stage);
    XCTAssertEqual([[self.controller valueForKey:@"explorationIndex"] unsignedIntegerValue], variation);
    XCTAssertEqualObjects(((UILabel *)[self view:@"concept.equation"]).text, example.equationText);
    XCTAssertEqualObjects(((UILabel *)[self view:@"concept.question"]).text, example.questionText);
    XCTAssertEqualObjects(((UILabel *)[self view:@"concept.focus"]).text, example.focusText);
    XCTAssertTrue([example.equationText hasSuffix:@" = ?"]);
    for (NSUInteger choice = 0; choice < 4; choice++) {
        XCTAssertNil(([self find:[NSString stringWithFormat:@"answer.%lu", (unsigned long)choice] inView:self.controller.view]));
    }
    XCTAssertNil([self find:@"session.next" inView:self.controller.view]);
}
- (NSString *)expectedReading:(ConceptLearningExample *)example {
    NSDictionary *operators = @{@"+": @"加", @"-": @"減", @"×": @"乘以", @"÷": @"除以"};
    ArithmeticProblem *question = example.problem;
    return [NSString stringWithFormat:@"%@\n%ld %@ %ld 等於多少？\n%@", example.questionText,
        (long)question.number1, operators[question.operatorSymbol], (long)question.number2, example.focusText];
}
- (void)assertButtonCanBeFullyRevealed:(NSString *)identifier {
    [self settleLayout];
    UIButton *button = (UIButton *)[self view:identifier];
    UIScrollView *scroll = (UIScrollView *)[self view:@"concept.content"];
    if ([button isDescendantOfView:scroll]) {
        [scroll scrollRectToVisible:[button convertRect:button.bounds toView:scroll] animated:NO];
        [self settleLayout];
        CGRect viewport = CGRectIntersection([scroll convertRect:scroll.bounds toView:self.window], self.window.bounds);
        CGRect buttonFrame = [button convertRect:button.bounds toView:self.window];
        XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -1, -1), buttonFrame),
                      @"The complete %@ target must reach the actual viewport", identifier);
    } else {
        XCTAssertTrue(CGRectContainsRect(CGRectInset(self.controller.view.safeAreaLayoutGuide.layoutFrame, -1, -1), button.frame));
    }
    XCTAssertGreaterThanOrEqual(button.bounds.size.width, 44);
    XCTAssertGreaterThanOrEqual(button.bounds.size.height, 44);
    XCTAssertEqual(button.titleLabel.numberOfLines, 0);
    XCTAssertFalse(button.titleLabel.adjustsFontSizeToFitWidth);
    UIFont *expected = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:20 weight:UIFontWeightBold]
        compatibleWithTraitCollection:self.controller.traitCollection];
    XCTAssertEqualWithAccuracy(button.titleLabel.font.pointSize, expected.pointSize, 0.01);
    CGSize required = [button.titleLabel sizeThatFits:CGSizeMake(button.titleLabel.bounds.size.width, CGFLOAT_MAX)];
    XCTAssertLessThanOrEqual(required.height, button.titleLabel.bounds.size.height + 1);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(UIEdgeInsetsInsetRect(button.bounds, button.contentEdgeInsets), -1, -1), button.titleLabel.frame));
}
- (void)testListeningIsExplicitAndUsesEveryCurrentQuestionWithoutWorkedSolutionContent {
    NSDictionary *before = [self savedProgress];
    for (ConceptLearningPath *path in ConceptLearningPath.allPaths) {
        [self showPath:path size:CGSizeMake(393, 852) category:UIContentSizeCategoryLarge];
        NSArray *examples = [@[path.firstExample, path.relatedExample] arrayByAddingObjectsFromArray:path.explorationExamples];
        for (NSUInteger index = 0; index < examples.count; index++) {
            XCTAssertEqual(self.speech.requests.count, index, @"Opening/changing a question never automatically reads it.");
            XCTAssertEqual(self.controller.currentExample, examples[index]);
            XCTAssertEqualObjects(self.readButton.currentTitle, @"聽題目");
            [self tapRead];
            XCTAssertEqual(self.speech.requests.count, index + 1);
            XCTAssertEqualObjects(self.speech.requests.lastObject, [self expectedReading:examples[index]]);
            XCTAssertFalse(self.speech.receivedRangeCallback, @"No stale word-highlighting callback is introduced.");
            XCTAssertNil(self.controller.presentedViewController, @"Listening must not open a worked demonstration.");
            [self assertQuestionUnchanged:examples[index] stage:MIN(index, 2) variation:index > 1 ? index - 2 : 0];
            if (index < 2) [self.controller next];
            else if (index + 1 < examples.count) [self.controller changeNumbers];
            else [self.controller stopQuestionReading];
        }
    }
    XCTAssertEqualObjects([self savedProgress], before);
}
- (void)testListenStopAndReplayAreWiredActionsThatKeepTheQuestionUnansweredAndUnscored {
    NSDictionary *before = [self savedProgress];
    [self showPath:@"carry"];
    ConceptLearningExample *question = self.controller.currentExample;
    XCTAssertEqual(self.speech.requests.count, 0u);
    [self tapRead];
    XCTAssertEqualObjects(self.readButton.currentTitle, @"停止朗讀");
    XCTAssertEqualObjects(self.readButton.accessibilityValue, @"正在朗讀題目");
    [self tapRead];
    XCTAssertEqual(self.speech.stopCount, 1u);
    XCTAssertEqualObjects(self.readButton.currentTitle, @"再聽一次");
    [self tapRead];
    XCTAssertEqual(self.speech.requests.count, 2u);
    XCTAssertEqualObjects(self.speech.requests[0], self.speech.requests[1]);
    [self.speech completeCurrentReading];
    XCTAssertEqualObjects(self.readButton.currentTitle, @"再聽一次");
    XCTAssertEqualObjects(self.readButton.accessibilityValue, @"沒有朗讀");
    [self assertQuestionUnchanged:question stage:0 variation:0];
    XCTAssertNil(self.controller.presentedViewController);
    XCTAssertEqualObjects([self savedProgress], before);
}
- (void)testLateCompletionCannotRelabelOrStopANewerNumberOrStageReading {
    [self showPath:@"carry"];
    [self.controller next]; [self.controller next]; [self.controller changeNumbers];
    [self tapRead];
    void (^oldNumberFinish)(void) = self.speech.completions.lastObject;
    [self.controller changeNumbers];
    XCTAssertEqual(self.speech.stopCount, 1u);
    XCTAssertEqualObjects(self.readButton.currentTitle, @"聽題目");
    [self tapRead];
    oldNumberFinish();
    XCTAssertEqualObjects(self.readButton.currentTitle, @"停止朗讀");
    XCTAssertEqual([self.controller valueForKey:@"readingSpeechManager"], self.speech);
    XCTAssertEqual(self.speech.stopCount, 1u);
    XCTAssertTrue([self.speech.requests.lastObject containsString:@"43 加 18 等於多少？"]);
    void (^oldStageFinish)(void) = self.speech.completions.lastObject;
    [self.controller previous];
    [self tapRead];
    oldStageFinish(); oldNumberFinish();
    XCTAssertEqualObjects(self.readButton.currentTitle, @"停止朗讀");
    XCTAssertEqual(self.speech.stopCount, 2u);
    XCTAssertTrue([self.speech.requests.lastObject containsString:@"36 加 18 等於多少？"]);
    [self.speech completeCurrentReading];
    XCTAssertEqualObjects(self.readButton.currentTitle, @"再聽一次");
}
- (void)testStageAndBothNumberDirectionsStopReadingWithoutAutomaticallyRestarting {
    [self showPath:@"carry"];
    [self tapRead]; [self.controller previous];
    XCTAssertEqual(self.speech.stopCount, 0u, @"A disabled stage-back action does not change or stop this question.");
    [self.controller next];
    XCTAssertEqual(self.speech.stopCount, 1u); XCTAssertEqual(self.speech.requests.count, 1u);
    [self tapRead]; [self.controller previous];
    XCTAssertEqual(self.speech.stopCount, 2u); XCTAssertEqual(self.speech.requests.count, 2u);
    [self.controller next]; [self.controller next];
    [self tapRead]; [self.controller changeNumbers];
    XCTAssertEqual(self.speech.stopCount, 3u); XCTAssertEqual(self.speech.requests.count, 3u);
    [self tapRead]; [self.controller previousNumbers];
    XCTAssertEqual(self.speech.stopCount, 4u); XCTAssertEqual(self.speech.requests.count, 4u);
    XCTAssertEqualObjects(self.readButton.currentTitle, @"聽題目");
    XCTAssertEqualObjects(self.controller.currentExample.equationText, @"43 + 16 = ?");
    XCTAssertEqual([[self.controller valueForKey:@"stageIndex"] unsignedIntegerValue], 2u);
}
- (void)testBackgroundAndLeavingStopOwnedReadingOnceAndNeverAutomaticallyResume {
    [self showPath:@"sharing"];
    ConceptLearningExample *question = self.controller.currentExample;
    [self tapRead];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    XCTAssertEqual(self.speech.stopCount, 1u);
    [self tapRead];
    XCTAssertEqual(self.speech.requests.count, 1u, @"A delayed action while inactive cannot restart speech.");
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self.controller viewWillAppear:NO]; [self.controller viewDidAppear:NO];
    XCTAssertEqual(self.speech.requests.count, 1u);
    XCTAssertEqualObjects(self.readButton.currentTitle, @"再聽一次");
    [self tapRead];
    [self.controller viewWillDisappear:NO];
    XCTAssertEqual(self.speech.stopCount, 2u);
    [self tapRead];
    XCTAssertEqual(self.speech.requests.count, 2u, @"A delayed action during disappearance cannot restart speech.");
    [self.controller viewWillAppear:NO]; [self.controller viewDidAppear:NO];
    XCTAssertEqual(self.speech.requests.count, 2u);
    [self assertQuestionUnchanged:question stage:0 variation:0];
    [self tapRead];
    XCTAssertEqual(self.speech.requests.count, 3u, @"Returning must enable a new explicit read.");
    XCTAssertEqualObjects(self.speech.requests.lastObject, [self expectedReading:question]);
}
- (void)testIdleOrReplacedReadingDoesNotStopSpeechOwnedByAnotherScreen {
    [self showPath:@"packing"];
    [self.controller stopQuestionReading];
    [self.controller next];
    XCTAssertEqual(self.speech.stopCount, 0u);
    [self tapRead];
    [self.speech speak:@"另一個畫面的朗讀" willSpeakRange:nil onFinish:nil];
    XCTAssertNil([self.controller valueForKey:@"readingSpeechManager"]);
    XCTAssertEqualObjects(self.readButton.currentTitle, @"再聽一次");
    [self.controller stopQuestionReading];
    [self.controller next];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    [self.controller viewWillDisappear:NO];
    XCTAssertEqual(self.speech.stopCount, 0u, @"An inactive discovery screen cannot cancel the new shared-speech owner.");
}
- (void)testRealTeachingPageSheetsStopReadingAndGuardBothNumberDirections {
    NSDictionary *before = [self savedProgress];
    for (NSString *pathID in @[@"carry", @"sharing"]) {
        [self showPath:pathID];
        [self.controller next]; [self.controller next]; [self.controller changeNumbers];
        ConceptLearningExample *question = self.controller.currentExample;
        [self tapRead];
        NSUInteger disappearanceCount = self.controller.disappearanceCount;
        [self.controller openTeaching];
        XCTAssertEqual(self.speech.stopCount, 1u, @"Presentation must stop the reading even if the underlying page remains visible.");
        UIViewController *sheet = self.controller.presentedViewController;
        XCTAssertNotNil(sheet);
        if (!sheet) return;
        XCTAssertEqual(sheet.modalPresentationStyle, UIModalPresentationPageSheet);
        NSPredicate *visible = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
            return sheet.viewIfLoaded.window != nil && !sheet.isBeingPresented;
        }];
        XCTNSPredicateExpectation *presented = [[XCTNSPredicateExpectation alloc] initWithPredicate:visible object:sheet];
        XCTAssertEqual([XCTWaiter waitForExpectations:@[presented] timeout:3], XCTWaiterResultCompleted);
        // If UIKit adapts this sheet and makes the presenter disappear, speech
        // must already be stopped BEFORE the production disappearance hook.
        // Otherwise no disappearance occurred and stopCount itself proves that
        // presentation stopped speech independently of viewWillDisappear:.
        if (self.controller.disappearanceCount != disappearanceCount) {
            XCTAssertEqual(self.controller.stopCountBeforeDisappearanceHook, 1u);
        }
        XCTAssertEqual(self.speech.stopCount, 1u);
        [self.controller readQuestion]; [self.controller previousNumbers]; [self.controller changeNumbers];
        [self.controller previous]; [self.controller next]; [self.controller openTeaching];
        XCTAssertEqual(self.controller.presentedViewController, sheet);
        XCTAssertEqual(self.speech.requests.count, 1u);
        [self assertQuestionUnchanged:question stage:2 variation:1];
        XCTAssertEqual([[sheet valueForKey:@"answeredSteps"] count], 0u);
        XCTestExpectation *dismissed = [self expectationWithDescription:@"Return from the real teaching page sheet"];
        [self.controller dismissViewControllerAnimated:NO completion:^{ [dismissed fulfill]; }];
        [self waitForExpectations:@[dismissed] timeout:3];
        [self assertQuestionUnchanged:question stage:2 variation:1];
        XCTAssertEqual(self.speech.requests.count, 1u);
        XCTAssertEqualObjects(self.readButton.currentTitle, @"再聽一次");
        [self tapRead];
        XCTAssertEqual(self.speech.requests.count, 2u, @"Sheet dismissal must allow another explicit read of the retained question.");
        XCTAssertEqualObjects(self.speech.requests.lastObject, [self expectedReading:question]);
    }
    XCTAssertEqualObjects([self savedProgress], before);
}
- (void)testCloseStopsBeforeDismissalAndAReopenedPathDoesNotResumeReading {
    [self showPath:@"carry"];
    self.controller.recordDismissalOnly = YES;
    [self tapRead];
    ConceptLearningExample *question = self.controller.currentExample;
    [self.controller close];
    XCTAssertEqual(self.controller.dismissalCount, 1u);
    XCTAssertEqual(self.controller.stopCountAtDismissal, 1u);
    XCTAssertEqual(self.speech.requests.count, 1u);
    [self assertQuestionUnchanged:question stage:0 variation:0];
    [self showPath:@"carry"];
    XCTAssertEqual(self.speech.requests.count, 0u);
    XCTAssertEqualObjects(self.readButton.currentTitle, @"聽題目");
}
- (void)testPreviousNumberIsTheInverseOfForwardIncludingWrapAndStageReturn {
    NSDictionary *before = [self savedProgress];
    for (ConceptLearningPath *path in ConceptLearningPath.allPaths) {
        [self showPath:path size:CGSizeMake(393, 852) category:UIContentSizeCategoryLarge];
        [self.controller previousNumbers]; [self.controller changeNumbers];
        XCTAssertEqual(self.controller.currentExample, path.firstExample);
        [self.controller next]; [self.controller next];
        XCTAssertEqualObjects(((UIButton *)[self view:@"concept.previous"]).currentTitle, @"上一階段");
        XCTAssertEqualObjects(((UIButton *)[self view:@"concept.change"]).currentTitle, @"下一組數字");
        XCTAssertTrue([((UILabel *)[self view:@"concept.stage"]).text containsString:@"學習階段"]);
        for (NSUInteger index = 0; index < path.explorationExamples.count; index++) {
            [self assertQuestionUnchanged:path.explorationExamples[index] stage:2 variation:index];
            [((UIButton *)[self view:@"concept.previousNumbers"]) sendActionsForControlEvents:UIControlEventTouchUpInside];
            NSUInteger previous = (index + path.explorationExamples.count - 1) % path.explorationExamples.count;
            [self assertQuestionUnchanged:path.explorationExamples[previous] stage:2 variation:previous];
            [((UIButton *)[self view:@"concept.change"]) sendActionsForControlEvents:UIControlEventTouchUpInside];
            [self assertQuestionUnchanged:path.explorationExamples[index] stage:2 variation:index];
            [self.controller previous];
            XCTAssertEqual(self.controller.currentExample, path.relatedExample);
            [self.controller next];
            [self assertQuestionUnchanged:path.explorationExamples[index] stage:2 variation:index];
            [self.controller changeNumbers];
        }
        XCTAssertEqual(self.controller.currentExample, path.explorationExamples.firstObject);
        XCTAssertTrue([((UIButton *)[self view:@"concept.previousNumbers"]).accessibilityHint containsString:@"最後一組"]);
        [self.controller previousNumbers];
        XCTAssertTrue([((UIButton *)[self view:@"concept.change"]).accessibilityHint containsString:@"第一組"]);
        XCTAssertEqual(self.speech.requests.count, 0u);
    }
    XCTAssertEqualObjects([self savedProgress], before);
}
- (void)testAllListeningTitlesAndComparisonControlsFitLiveNarrowAndMaximumTextChanges {
    [self showPath:[self path:@"sharing"] size:CGSizeMake(320, 568) category:UIContentSizeCategoryLarge];
    [self.controller next]; [self.controller next]; [self.controller changeNumbers];
    ConceptLearningExample *question = self.controller.currentExample;
    NSArray *categories = @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge,
                            UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge,
                            UIContentSizeCategoryAccessibilityExtraExtraExtraLarge, UIContentSizeCategoryLarge];
    NSArray *widths = @[@320, @320, @320, @1024, @320, @320];
    for (NSUInteger pass = 0; pass < categories.count; pass++) {
        self.window.frame = CGRectMake(0, 0, [widths[pass] doubleValue], [widths[pass] doubleValue] > 600 ? 768 : 568);
        self.controller.view.frame = self.window.bounds;
        self.controller.traitOverrides.preferredContentSizeCategory = categories[pass];
        [self settleLayout];
        XCTAssertEqualWithAccuracy(self.controller.view.bounds.size.width, [widths[pass] doubleValue], 0.5);
        XCTAssertEqualWithAccuracy(self.controller.view.bounds.size.height, [widths[pass] doubleValue] > 600 ? 768 : 568, 0.5);
        XCTAssertEqualObjects(self.controller.traitCollection.preferredContentSizeCategory, categories[pass]);
        XCTAssertEqualObjects(self.readButton.currentTitle, @"聽題目");
        for (NSString *identifier in @[@"concept.close", @"concept.read", @"concept.previousNumbers", @"concept.change", @"concept.previous", @"concept.next"]) {
            [self assertButtonCanBeFullyRevealed:identifier];
        }
        [self tapRead];
        XCTAssertEqualObjects(self.readButton.currentTitle, @"停止朗讀");
        [self assertButtonCanBeFullyRevealed:@"concept.read"];
        [self tapRead];
        XCTAssertEqualObjects(self.readButton.currentTitle, @"再聽一次");
        [self assertButtonCanBeFullyRevealed:@"concept.read"];
        [self assertQuestionUnchanged:question stage:2 variation:1];
        // Reset by real reversible navigation, so all three read titles are
        // measured on every live category/width pass, not just the first one.
        [self.controller changeNumbers]; [self.controller previousNumbers];
        [self assertQuestionUnchanged:question stage:2 variation:1];
    }
}
- (void)testDirectionalLayoutAndAccessibilityKeepActionsAndEquationUnambiguous {
    [self showPath:[self path:@"carry"] size:CGSizeMake(1024, 768) category:UIContentSizeCategoryLarge];
    self.controller.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self.controller next]; [self.controller next];
    [self settleLayout];
    UIView *equation = [self view:@"concept.equation"];
    XCTAssertEqual(equation.semanticContentAttribute, UISemanticContentAttributeForceLeftToRight);
    UILabel *stage = (UILabel *)[self view:@"concept.stage"];
    XCTAssertTrue(stage.accessibilityTraits & UIAccessibilityTraitHeader);
    UIButton *previous = (UIButton *)[self view:@"concept.previousNumbers"];
    UIButton *next = (UIButton *)[self view:@"concept.change"];
    UIStackView *numbers = (UIStackView *)previous.superview;
    XCTAssertEqual(numbers.effectiveUserInterfaceLayoutDirection, UIUserInterfaceLayoutDirectionRightToLeft);
    XCTAssertEqual(numbers.axis, UILayoutConstraintAxisHorizontal);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(previous.frame), CGRectGetMaxX(next.frame));
    for (UIButton *button in @[previous, next, self.readButton]) {
        XCTAssertTrue(button.isAccessibilityElement);
        XCTAssertGreaterThan(button.accessibilityLabel.length, 0u);
        XCTAssertGreaterThan(button.accessibilityHint.length, 0u);
    }
    [self tapRead];
    XCTAssertEqualObjects(self.readButton.accessibilityLabel, @"停止朗讀");
    XCTAssertTrue([self.speech.requests.lastObject containsString:@"43 加 16 等於多少？"]);
}
@end
