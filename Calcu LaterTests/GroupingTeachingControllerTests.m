#import <XCTest/XCTest.h>
#import "GroupingTeachingViewController.h"
#import "GroupingTeachingFocusView.h"
#import "GroupingTeachingBoardView.h"
#import "WordProblem.h"
#import "SpeechManager.h"

@interface GroupingTeachingViewController (Testing)
- (void)next;
- (void)previous;
- (void)replay;
- (void)changeViewMode;
- (void)skipToRoundResult;
- (void)compareBeforeAfter;
- (void)choosePrediction:(UIButton *)button;
- (void)close;
- (SpeechManager *)speechManager;
@end
/// Observe explicit requests and cancellation without asserting audible output.
@interface CLGroupingSpeechRecorder : SpeechManager
@property (nonatomic, strong) NSMutableArray<NSString *> *requests;
@property (nonatomic) NSUInteger stopCount;
@property (nonatomic, copy) NSString *currentRequest;
@end
@implementation CLGroupingSpeechRecorder
- (void)speak:(NSString *)text {
    if (!self.requests) self.requests = [NSMutableArray array];
    [self.requests addObject:[text copy]];
    self.currentRequest = text;
}
- (void)stop { self.stopCount++; self.currentRequest = nil; }
@end
@interface CLSpeechRecordingGroupingController : GroupingTeachingViewController
@property (nonatomic, strong) CLGroupingSpeechRecorder *recorder;
@end
@implementation CLSpeechRecordingGroupingController
- (SpeechManager *)speechManager {
    if (!self.recorder) self.recorder = [[CLGroupingSpeechRecorder alloc] init];
    return self.recorder;
}
@end

@interface GroupingTeachingControllerTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) GroupingTeachingViewController *controller;
@end
@implementation GroupingTeachingControllerTests
- (void)releaseHost {
    [self.controller viewWillDisappear:NO];
    [self.window.rootViewController.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [self.controller willMoveToParentViewController:nil];
    [self.controller.view removeFromSuperview]; [self.controller removeFromParentViewController];
    self.window.hidden = YES; self.window.rootViewController = nil;
    self.controller = nil; self.window = nil;
}
- (void)tearDown {
    [self releaseHost];
    [super tearDown];
}
- (void)openSharingTotal:(NSInteger)total divisor:(NSInteger)divisor maximumText:(BOOL)maximumText {
    GroupingStoryContext *context = [[GroupingStoryContext alloc] initWithMeaning:GroupingStoryMeaningShareEqually itemName:@"糖果" itemUnit:@"顆" groupName:@"個小朋友" answerUnit:@"顆"];
    WordProblem *story = [[WordProblem alloc] initWithStory:@"保留原來的完整故事。" templateID:@"focus-controller" grade:3 number1:total number2:divisor operator:@"÷" answer:total / divisor unit:@"顆"
        missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:total % divisor number3:0 operator2:nil intermediate:0
        isFractionAnswer:NO answerNumerator:0 answerDenominator:0 groupingContext:context strategyText:@"每輪每人只有一顆。"];
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 393, 852)];
    self.window.rootViewController = [[UIViewController alloc] init]; self.window.hidden = NO;
    if (maximumText) self.window.rootViewController.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    self.controller = [[CLSpeechRecordingGroupingController alloc] initWithProblem:[story toArithmeticProblem] wordProblem:story];
    [self.window.rootViewController addChildViewController:self.controller];
    self.controller.view.frame = CGRectMake(0, 0, 393, 852);
    [self.window.rootViewController.view addSubview:self.controller.view];
    [self.controller didMoveToParentViewController:self.window.rootViewController];
    [self.controller.view setNeedsLayout]; [self.controller.view layoutIfNeeded];
}
- (GroupingTeachingAction *)action { return [self.controller valueForKey:@"selectedAction"]; }
- (GroupingTeachingFocusView *)focus { return [self.controller valueForKey:@"focusView"]; }
- (UIScrollView *)scroll { return [self.controller valueForKey:@"scroll"]; }
- (CLGroupingSpeechRecorder *)recorder { return ((CLSpeechRecordingGroupingController *)self.controller).recorder; }
- (UIButton *)contentButton:(NSString *)identifier {
    UIStackView *content = [self.controller valueForKey:@"content"];
    for (UIView *view in content.arrangedSubviews) {
        if ([view isKindOfClass:UIButton.class] && [view.accessibilityIdentifier isEqualToString:identifier]) return (UIButton *)view;
    }
    XCTFail(@"Missing existing control %@", identifier);
    return nil;
}
- (UIButton *)predictionButton:(NSInteger)value {
    UIStackView *choices = [self.controller valueForKey:@"choices"];
    for (UIButton *button in choices.arrangedSubviews) if (button.tag == value) return button;
    XCTFail(@"Missing current prediction choice %ld", (long)value);
    return nil;
}
- (NSDictionary *)readOnlyTeachingState {
    GroupingTeachingSequence *sequence = [self.controller valueForKey:@"sequence"];
    GroupingTeachingBoardView *board = [self.controller valueForKey:@"board"];
    UILabel *feedback = [self.controller valueForKey:@"choiceFeedback"];
    WordProblem *story = sequence.wordProblem;
    NSMutableDictionary *attempts = [[self.controller valueForKey:@"attemptedValues"] mutableCopy];
    for (NSNumber *key in attempts.allKeys) attempts[key] = [attempts[key] copy];
    return @{
        @"selection": [self.controller dictionaryWithValuesForKeys:@[@"stepIndex", @"actionIndex", @"selectedAction", @"showingOverview", @"inspectingBefore", @"inspectingPrediction"]],
        @"answered": [[self.controller valueForKey:@"answeredSteps"] copy],
        @"attempts": attempts,
        @"lastChoices": [[self.controller valueForKey:@"lastPredictedValues"] copy],
        @"problem": [sequence.problem dictionaryWithValuesForKeys:@[@"number1", @"number2", @"operatorSymbol", @"answer", @"auxiliaryDistractor", @"isMultiStep"]],
        @"story": [story dictionaryWithValuesForKeys:@[@"storyText", @"templateID", @"number1", @"number2", @"operatorSymbol", @"answer", @"remainder", @"unit", @"strategyText"]],
        // The defensive story copy owns a fresh context object on every read.
        // Compare every semantic role/unit, not that object's identity.
        @"storyContext": [story.groupingContext dictionaryWithValuesForKeys:@[@"meaning", @"itemName", @"itemUnit", @"groupName", @"answerUnit", @"leftoverUnit"]] ?: @{},
        @"unansweredEquation": [story equationTextRevealingAnswer:NO],
        @"board": [board dictionaryWithValuesForKeys:@[@"currentStep", @"currentStepIndex", @"accessibilityValue"]],
        @"quantities": [board.currentStep dictionaryWithValuesForKeys:@[@"groupCountsBefore", @"groupCountsAfter", @"poolCountBefore", @"poolCountAfter", @"visibleAnswer", @"visibleRemainder"]],
        @"focused": [self.focus dictionaryWithValuesForKeys:@[@"action", @"displayedGroupCounts", @"displayedPoolCount", @"inFlightCount", @"showingBeforeState", @"playbackState", @"playbackGeneration", @"spokenDescription"]],
        @"feedback": feedback.text ?: @""
    };
}
- (void)assertReadRequests:(NSString *)expected {
    NSDictionary *before = [self readOnlyTeachingState];
    NSUInteger requests = self.recorder.requests.count;
    GroupingTeachingBoardView *board = [self.controller valueForKey:@"board"];
    XCTAssertNil(board.currentStep.visibleAnswer); XCTAssertNil(board.currentStep.visibleRemainder);
    // Exercise the existing control target with a recorder. Real touch/scroll
    // reachability remains covered by the unchanged focused-action UI tests.
    [[self contentButton:@"grouping.read"] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(self.recorder.requests.count, requests + 1);
    XCTAssertEqualObjects(self.recorder.requests.lastObject, expected);
    XCTAssertEqualObjects(self.recorder.currentRequest, expected);
    XCTAssertEqualObjects([self readOnlyTeachingState], before);
    XCTAssertNil(board.currentStep.visibleAnswer); XCTAssertNil(board.currentStep.visibleRemainder);
}
- (void)assertPredictionChoiceCancelsRequest:(UIButton *)button {
    XCTAssertNotNil(self.recorder.currentRequest);
    NSUInteger stops = self.recorder.stopCount, requests = self.recorder.requests.count;
    [self.controller choosePrediction:button];
    XCTAssertEqual(self.recorder.stopCount, stops + 1);
    XCTAssertEqual(self.recorder.requests.count, requests, @"A new choice stops old coaching but must not speak automatically.");
    XCTAssertNil(self.recorder.currentRequest);
}
- (void)assertPredictionChoiceIgnored:(UIButton *)button {
    NSDictionary *before = [self readOnlyTeachingState];
    NSString *requested = self.recorder.currentRequest;
    NSUInteger stops = self.recorder.stopCount, requests = self.recorder.requests.count;
    [self.controller choosePrediction:button];
    XCTAssertEqual(self.recorder.stopCount, stops);
    XCTAssertEqual(self.recorder.requests.count, requests);
    XCTAssertEqualObjects(self.recorder.currentRequest, requested);
    XCTAssertEqualObjects([self readOnlyTeachingState], before);
}
- (void)testFocusedNextPreviousAndOverviewKeepOneContinuousPartialState {
    [self openSharingTotal:23 divisor:4 maximumText:YES];
    [self.controller next]; [self.controller next];
    XCTAssertNotNil(self.action);
    XCTAssertFalse(self.action.isFullAction);
    XCTAssertEqual(self.action.actionIndex, 0);
    [self.focus cancelPlayback];
    XCTAssertEqualObjects(self.action.snapshot.groupCountsAfter, (@[@1, @0, @0, @0]));
    XCTAssertEqualObjects(self.action.snapshot.poolCountAfter, @22);
    [self.controller changeViewMode];
    GroupingTeachingBoardView *overview = [self.controller valueForKey:@"board"];
    XCTAssertEqual(overview.currentStep, self.action.snapshot);
    XCTAssertTrue([overview.accessibilityValue containsString:@"第 4 個小朋友有 0 顆"]);
    self.scroll.contentOffset = CGPointMake(0, MIN(400, self.scroll.contentSize.height - self.scroll.bounds.size.height));
    CGPoint inspection = self.scroll.contentOffset;
    [self.controller changeViewMode]; [self.controller changeViewMode];
    XCTAssertEqualWithAccuracy(self.scroll.contentOffset.y, inspection.y, 0.5);
    [self.controller next];
    XCTAssertEqual(self.action.actionIndex, 1);
    XCTAssertEqualObjects(self.action.snapshot.groupCountsAfter, (@[@1, @1, @0, @0]));
    XCTAssertEqualObjects(self.action.snapshot.poolCountAfter, @21);
    [self.controller previous];
    XCTAssertEqual(self.action.actionIndex, 0);
    XCTAssertEqualObjects(self.action.snapshot.poolCountAfter, @22);
    XCTAssertNil(self.action.snapshot.visibleAnswer);
}
- (void)testUpperBoundRoundCanBeInspectedWithoutNinetyRequiredNextTaps {
    [self openSharingTotal:90 divisor:9 maximumText:YES];
    [self.controller next]; [self.controller next];
    XCTAssertEqual(self.action.actionIndex, 0);
    XCTAssertEqualObjects(self.action.snapshot.poolCountAfter, @89);
    [self.controller skipToRoundResult];
    XCTAssertEqual(self.action.actionIndex, 8);
    XCTAssertEqualObjects(self.action.snapshot.poolCountAfter, @81);
    XCTAssertEqualObjects(self.action.snapshot.groupCountsAfter, (@[@1, @1, @1, @1, @1, @1, @1, @1, @1]));
    XCTAssertNil(self.action.snapshot.visibleAnswer);
    UILabel *notice = [self.controller valueForKey:@"visibilityNotice"];
    XCTAssertTrue([notice.text containsString:@"剛才沒播放的動作不算看過"]);
    XCTAssertFalse([self.focus.accessibilityValue containsString:@"播放完成"]);
    [self.controller next];
    XCTAssertNil(self.action);
    XCTAssertEqual([[self.controller valueForKey:@"stepIndex"] integerValue], 3);
    XCTAssertEqual([[self.controller valueForKey:@"answeredSteps"] count], 0u);
}
- (void)testWrongPredictionFeedbackIsRevealedWithoutAdvancingOrWritingAnswer {
    [self openSharingTotal:23 divisor:4 maximumText:YES];
    [self.controller next];
    UIStackView *choices = [self.controller valueForKey:@"choices"];
    UIButton *wrong = nil;
    for (UIButton *button in choices.arrangedSubviews) if (button.tag == 2) wrong = button;
    XCTAssertNotNil(wrong);
    [self.controller choosePrediction:wrong];
    UILabel *feedback = [self.controller valueForKey:@"choiceFeedback"];
    CGRect frame = [feedback convertRect:feedback.bounds toView:self.scroll];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(self.scroll.bounds, -0.5, -0.5), frame), @"feedback %@ viewport %@", NSStringFromCGRect(frame), NSStringFromCGRect(self.scroll.bounds));
    XCTAssertTrue([feedback.text containsString:@"你選 2 顆"]);
    XCTAssertTrue([feedback.text containsString:@"共同待分還有 23 顆"]);
    XCTAssertEqual([[self.controller valueForKey:@"stepIndex"] integerValue], 1);
    XCTAssertEqual([[self.controller valueForKey:@"answeredSteps"] count], 0u);
    GroupingTeachingBoardView *board = [self.controller valueForKey:@"board"];
    XCTAssertNil(board.currentStep.visibleAnswer);
    [self.controller changeViewMode];
    XCTAssertTrue([board.accessibilityValue containsString:@"待分的糖果：23 顆"]);
    [self.controller changeViewMode];
    XCTAssertEqual([[self.controller valueForKey:@"stepIndex"] integerValue], 1);
    XCTAssertFalse(wrong.enabled);
    XCTAssertEqual(self.recorder.requests.count, 0u, @"Choosing and inspecting must not request speech automatically.");
    GroupingTeachingStep *prediction = board.currentStep;
    NSString *wrongCountSpeech = [NSString stringWithFormat:@"%@ %@", prediction.spokenExplanation, feedback.text];
    [self assertReadRequests:wrongCountSpeech];
    XCTAssertEqual([self.recorder.requests.lastObject componentsSeparatedByString:prediction.prompt].count, 2u);
    NSUInteger stops = self.recorder.stopCount;
    __block BOOL returned = NO;
    self.controller.returnToQuestion = ^{ returned = YES; };
    [self.controller close];
    XCTAssertTrue(returned);
    XCTAssertNil(board.currentStep.visibleAnswer);
    XCTAssertGreaterThan(self.recorder.stopCount, stops);

    // Preserve the original close-from-wrong-state callback above, then release
    // its window and child before starting a separate correction/restart flow.
    [self releaseHost];
    [self openSharingTotal:23 divisor:4 maximumText:YES];
    XCTAssertEqualObjects(self.controller.traitCollection.preferredContentSizeCategory, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge);
    [self.controller next];
    board = [self.controller valueForKey:@"board"];
    feedback = [self.controller valueForKey:@"choiceFeedback"];
    prediction = board.currentStep;
    [self assertReadRequests:prediction.spokenExplanation];
    [self assertPredictionChoiceCancelsRequest:[self predictionButton:2]];
    [self assertReadRequests:wrongCountSpeech];
    [self assertPredictionChoiceIgnored:[self predictionButton:2]]; // Repeated, disabled wrong choice.
    UIButton *foreignChoice = [UIButton buttonWithType:UIButtonTypeCustom];
    foreignChoice.tag = 1;
    XCTAssertTrue(foreignChoice.enabled);
    [self assertPredictionChoiceIgnored:foreignChoice]; // Not a current choice, despite its valid value.
    [self assertPredictionChoiceCancelsRequest:[self predictionButton:0]];
    XCTAssertTrue([feedback.text containsString:@"你選 0 顆"]);
    [self assertReadRequests:[NSString stringWithFormat:@"%@ %@", prediction.spokenExplanation, feedback.text]];
    [self assertPredictionChoiceCancelsRequest:[self predictionButton:1]];
    XCTAssertEqual(self.recorder.requests.count, 3u);
    XCTAssertTrue([feedback.text containsString:@"你選 1 顆"]);
    XCTAssertFalse([feedback.text containsString:@"你選 2 顆"]);
    XCTAssertEqual([[self.controller valueForKey:@"answeredSteps"] count], 1u);
    [self assertReadRequests:[NSString stringWithFormat:@"%@ %@", prediction.spokenExplanation, feedback.text]];
    XCTAssertNotEqualObjects(self.recorder.requests.lastObject, wrongCountSpeech);
    [self assertPredictionChoiceIgnored:[self predictionButton:1]]; // Already answered.

    // Partial-action speech keeps its actual before/after state. Neither the
    // whole round nor the previous prediction's coaching may replace it.
    NSUInteger requests = self.recorder.requests.count;
    stops = self.recorder.stopCount;
    [self.controller next]; [self.focus cancelPlayback];
    XCTAssertGreaterThan(self.recorder.stopCount, stops);
    XCTAssertEqual(self.recorder.requests.count, requests);
    XCTAssertFalse(self.action.isFullAction);
    XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@1, @0, @0, @0]));
    XCTAssertEqual(self.focus.displayedPoolCount, 22);
    [self assertReadRequests:self.focus.spokenDescription];
    [self.controller compareBeforeAfter];
    XCTAssertTrue(self.focus.isShowingBeforeState);
    XCTAssertEqualObjects(self.focus.displayedGroupCounts, (@[@0, @0, @0, @0]));
    XCTAssertEqual(self.focus.displayedPoolCount, 23);
    [self assertReadRequests:self.focus.spokenDescription];
    [self.controller compareBeforeAfter];
    XCTAssertFalse(self.focus.isShowingBeforeState);
    [self assertReadRequests:self.focus.spokenDescription];
    [self.controller changeViewMode];
    [self assertReadRequests:self.action.snapshot.spokenExplanation];

    requests = self.recorder.requests.count;
    GroupingTeachingSequence *sequence = [self.controller valueForKey:@"sequence"];
    for (NSUInteger advance = 0; advance < sequence.steps.count && board.currentStep.predictionKind != GroupingTeachingPredictionKindCanContinue; advance++) {
        if (self.action) [self.controller skipToRoundResult];
        [self.controller next];
    }
    XCTAssertEqual(self.recorder.requests.count, requests);
    XCTAssertEqual(board.currentStep.predictionKind, GroupingTeachingPredictionKindCanContinue);
    XCTAssertEqualObjects(board.currentStep.poolCountAfter, @3);
    XCTAssertEqualObjects(board.currentStep.groupCountsAfter, (@[@5, @5, @5, @5]));
    prediction = board.currentStep;
    [self assertReadRequests:prediction.spokenExplanation]; // No previous prediction's feedback.
    [self assertPredictionChoiceCancelsRequest:[self predictionButton:1]];
    XCTAssertTrue([feedback.text containsString:@"你選「還可以」"]);
    XCTAssertTrue([feedback.text containsString:@"共同待分只有 3 顆"]);
    XCTAssertTrue([feedback.text containsString:@"要 4 顆，還差 1 顆"]);
    XCTAssertEqual([[self.controller valueForKey:@"answeredSteps"] count], 1u);
    [self assertReadRequests:[NSString stringWithFormat:@"%@ %@", prediction.spokenExplanation, feedback.text]];
    XCTAssertEqual([self.recorder.requests.lastObject componentsSeparatedByString:prediction.prompt].count, 2u);
    [self assertPredictionChoiceIgnored:[self predictionButton:1]];
    [self assertPredictionChoiceCancelsRequest:[self predictionButton:0]];
    XCTAssertTrue([feedback.text containsString:@"你選「不夠了」"]);
    XCTAssertEqual([[self.controller valueForKey:@"answeredSteps"] count], 2u);
    [self assertReadRequests:[NSString stringWithFormat:@"%@ %@", prediction.spokenExplanation, feedback.text]];

    requests = self.recorder.requests.count; stops = self.recorder.stopCount;
    [self.controller replay];
    XCTAssertGreaterThan(self.recorder.stopCount, stops);
    XCTAssertEqual(self.recorder.requests.count, requests);
    stops = self.recorder.stopCount;
    [[self contentButton:@"grouping.restart"] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertGreaterThan(self.recorder.stopCount, stops);
    XCTAssertEqual(self.recorder.requests.count, requests);
    XCTAssertEqual([[self.controller valueForKey:@"stepIndex"] integerValue], 0);
    XCTAssertEqual([[self.controller valueForKey:@"answeredSteps"] count], 0u);
    XCTAssertEqual([[self.controller valueForKey:@"lastPredictedValues"] count], 0u);
    XCTAssertEqual([[self.controller valueForKey:@"attemptedValues"] count], 0u);
    XCTAssertEqualObjects(board.currentStep.poolCountAfter, @23);
    XCTAssertEqualObjects(board.currentStep.groupCountsAfter, (@[@0, @0, @0, @0]));
    [self assertReadRequests:board.currentStep.spokenExplanation];
    [self.controller next];
    XCTAssertEqual(board.currentStep, sequence.steps[1]);
    [self assertReadRequests:board.currentStep.spokenExplanation];
    requests = self.recorder.requests.count; stops = self.recorder.stopCount;
    [self.controller previous];
    XCTAssertGreaterThan(self.recorder.stopCount, stops);
    XCTAssertEqual(self.recorder.requests.count, requests);
    stops = self.recorder.stopCount;
    [self.controller viewWillDisappear:NO];
    XCTAssertGreaterThan(self.recorder.stopCount, stops);
    XCTAssertEqual(self.recorder.requests.count, requests);
}
- (void)testCompareBeforeSurvivesPassiveLandscapeAndRestoresMatchingButton {
    [self openSharingTotal:23 divisor:4 maximumText:YES];
    [self.controller next]; [self.controller next];
    [self.focus cancelPlayback];
    [self.controller compareBeforeAfter];
    XCTAssertTrue(self.focus.isShowingBeforeState);
    UIButton *compare = [self.controller valueForKey:@"compareButton"];
    XCTAssertEqualObjects(compare.currentTitle, @"看動作後");
    GroupingTeachingAction *selected = self.action;
    self.controller.view.frame = CGRectMake(0, 0, 852, 393);
    [self.controller.view setNeedsLayout]; [self.controller.view layoutIfNeeded];
    XCTAssertEqual(self.action, selected);
    XCTAssertTrue(self.focus.isShowingBeforeState);
    XCTAssertEqualObjects(compare.currentTitle, @"看動作後");
    XCTAssertNil([self.focus valueForKey:@"clock"]);
    [self.controller compareBeforeAfter];
    XCTAssertFalse(self.focus.isShowingBeforeState);
    XCTAssertEqualObjects(compare.currentTitle, @"看動作前");
}
@end
