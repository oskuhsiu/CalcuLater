#import <XCTest/XCTest.h>
#import "GroupingTeachingViewController.h"
#import "GroupingTeachingFocusView.h"
#import "GroupingTeachingBoardView.h"
#import "WordProblem.h"

@interface GroupingTeachingViewController (Testing)
- (void)next;
- (void)previous;
- (void)replay;
- (void)changeViewMode;
- (void)skipToRoundResult;
- (void)compareBeforeAfter;
- (void)choosePrediction:(UIButton *)button;
- (void)close;
@end
@interface GroupingTeachingControllerTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) GroupingTeachingViewController *controller;
@end
@implementation GroupingTeachingControllerTests
- (void)tearDown {
    [self.controller viewWillDisappear:NO];
    [self.window.rootViewController.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    self.window.hidden = YES; self.window.rootViewController = nil;
    self.controller = nil; self.window = nil;
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
    self.controller = [[GroupingTeachingViewController alloc] initWithProblem:[story toArithmeticProblem] wordProblem:story];
    [self.window.rootViewController addChildViewController:self.controller];
    self.controller.view.frame = CGRectMake(0, 0, 393, 852);
    [self.window.rootViewController.view addSubview:self.controller.view];
    [self.controller didMoveToParentViewController:self.window.rootViewController];
    [self.controller.view setNeedsLayout]; [self.controller.view layoutIfNeeded];
}
- (GroupingTeachingAction *)action { return [self.controller valueForKey:@"selectedAction"]; }
- (GroupingTeachingFocusView *)focus { return [self.controller valueForKey:@"focusView"]; }
- (UIScrollView *)scroll { return [self.controller valueForKey:@"scroll"]; }
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
    __block BOOL returned = NO;
    self.controller.returnToQuestion = ^{ returned = YES; };
    [self.controller close];
    XCTAssertTrue(returned);
    XCTAssertNil(board.currentStep.visibleAnswer);
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
