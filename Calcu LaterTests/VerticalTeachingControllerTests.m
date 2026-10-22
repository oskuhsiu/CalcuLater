#import <XCTest/XCTest.h>
#import "VerticalTeachingViewController.h"
#import "VerticalArithmeticBoardView.h"
#import "ArithmeticProblem.h"

@interface VerticalTeachingViewController (ControllerTesting)
- (void)showCurrentStepAnimated:(BOOL)animated;
- (void)next;
- (void)previous;
- (void)replay;
- (void)restart;
- (void)focusCurrentContent;
@end

@interface VerticalTeachingControllerTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) VerticalTeachingViewController *controller;
@end

@implementation VerticalTeachingControllerTests
- (void)tearDown {
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    [board cancelAnimations];
    [self.controller.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [self.controller.view removeFromSuperview];
    [self.controller removeFromParentViewController];
    self.controller = nil;
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    self.window = nil;
    [super tearDown];
}
- (void)open:(NSInteger)first second:(NSInteger)second operation:(NSString *)operation {
    NSInteger answer = [operation isEqualToString:@"+"] ? first + second : first - second;
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:first number2:second operator:operation answer:answer];
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 852, 852)];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.hidden = NO;
    self.controller = [[VerticalTeachingViewController alloc] initWithProblem:problem wordProblem:nil];
    [self.window.rootViewController addChildViewController:self.controller];
    [self.window.rootViewController.view addSubview:self.controller.view];
    [self.controller didMoveToParentViewController:self.window.rootViewController];
    self.controller.view.autoresizingMask = UIViewAutoresizingNone;
    [self resize:CGSizeMake(375, 812)];
}
- (void)resize:(CGSize)size {
    self.controller.view.frame = CGRectMake(0, 0, size.width, size.height);
    // Width-dependent wrapping can invalidate intrinsic size after first layout.
    for (NSUInteger pass = 0; pass < 4; pass++) {
        [self.controller.view setNeedsLayout];
        [self.controller.view layoutIfNeeded];
    }
}
- (BOOL)contains:(UIView *)view {
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGRect frame = [view convertRect:view.bounds toView:scroll];
    return CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), frame);
}
- (void)select:(NSUInteger)index animated:(BOOL)animated {
    [self.controller setValue:@(index) forKey:@"stepIndex"];
    [self.controller showCurrentStepAnimated:animated];
}
- (UIButton *)choice:(NSInteger)value {
    UIStackView *choices = [self.controller valueForKey:@"choices"];
    for (UIButton *button in choices.arrangedSubviews) if (button.tag == value) return button;
    return nil;
}
- (void)testWrongAndCorrectColumnFeedbackIsVisibleAndInspectionReturnsWithoutRevealingAnAnswer {
    [self open:27 second:15 operation:@"+"];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self resize:CGSizeMake(375, 812)];
    [self select:1 animated:NO];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    NSString *before = board.accessibilityValue;
    [[self choice:11] sendActionsForControlEvents:UIControlEventTouchUpInside];
    UILabel *feedback = [self.controller valueForKey:@"choiceFeedback"];
    XCTAssertTrue([feedback.text containsString:@"你選 11 個一"]);
    XCTAssertTrue([feedback.text containsString:@"個位的 7 + 5 個一"]);
    XCTAssertTrue([feedback.text containsString:@"不計分"]);
    XCTAssertTrue([self contains:feedback]);
    XCTAssertFalse([self choice:11].enabled);
    XCTAssertTrue([self choice:12].enabled);
    XCTAssertEqual(board.currentStepIndex, 1);
    XCTAssertEqualObjects(board.accessibilityValue, before);
    [self.controller focusCurrentContent];
    UIButton *focus = [self.controller valueForKey:@"focusButton"];
    XCTAssertEqualObjects(focus.currentTitle, @"回到選項");
    XCTAssertFalse(board.isPlaying);
    [self.controller focusCurrentContent];
    XCTAssertEqualObjects(focus.currentTitle, @"看數量");
    XCTAssertTrue([self contains:[self.controller valueForKey:@"choices"]]);
    [[self choice:12] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertTrue([feedback.text containsString:@"7 + 5 = 12 個一"]);
    XCTAssertTrue([self contains:feedback]);
    XCTAssertEqualObjects([self choice:12].accessibilityValue, @"和這一步的數量相同");
    XCTAssertFalse([feedback.text containsString:@"42"]);
    XCTAssertEqualObjects(board.accessibilityValue, before);
    [self.controller next];
    [self.controller previous];
    XCTAssertFalse([self choice:12].enabled);
    XCTAssertTrue([((UILabel *)[self.controller valueForKey:@"choiceFeedback"]).text containsString:@"7 + 5 = 12 個一"]);
    [self.controller restart];
    [self.controller next];
    XCTAssertTrue([self choice:11].enabled);
    XCTAssertTrue([self choice:12].enabled);
    XCTAssertEqual([[self.controller valueForKey:@"lastAttemptedValues"] count], 0u);
}
- (void)testBothZeroBorrowPredictionsExplainTheChosenUnitsWithoutLeakingTheNextExchange {
    [self open:500 second:128 operation:@"-"];
    ArithmeticTeachingSequence *sequence = [self.controller valueForKey:@"sequence"];
    NSUInteger tested = 0;
    for (NSUInteger index = 0; index + 1 < sequence.steps.count; index++) {
        if (sequence.steps[index].kind != ArithmeticTeachingStepKindPrediction
            || sequence.steps[index + 1].kind != ArithmeticTeachingStepKindRegroup) continue;
        [self select:index animated:NO];
        [[self choice:1] sendActionsForControlEvents:UIControlEventTouchUpInside];
        UILabel *feedback = [self.controller valueForKey:@"choiceFeedback"];
        NSString *unit = tested == 0 ? @"十" : @"一";
        NSString *source = tested == 0 ? @"百" : @"十";
        NSString *selection = [NSString stringWithFormat:@"你選 1 個%@", unit];
        XCTAssertTrue([feedback.text containsString:selection]);
        NSString *equality = [NSString stringWithFormat:@"1 個%@ = 10 個%@", source, unit];
        XCTAssertTrue([feedback.text containsString:equality]);
        XCTAssertTrue([self contains:feedback]);
        VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
        XCTAssertEqual(board.currentStepIndex, (NSInteger)index);
        XCTAssertTrue([board.accessibilityValue containsString:@"答案還沒寫"]);
        XCTAssertFalse([feedback.text containsString:@"372"]);
        if (tested == 0) XCTAssertFalse([feedback.text containsString:@"10 個一"]);
        tested++;
    }
    XCTAssertEqual(tested, 2u);
}
- (void)testActualControllerReframesAfterResizeAndReplayRetainsTheSelectedSnapshot {
    [self open:27 second:15 operation:@"+"];
    [self select:3 animated:YES];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    NSString *snapshot = board.accessibilityValue;
    [self resize:CGSizeMake(852, 393)];
    XCTAssertFalse(board.isPlaying, @"Rotation must not silently begin another playback.");
    [self.controller focusCurrentContent];
    [self.controller replay];
    CGRect concrete = [board convertRect:board.currentConcreteTransformationRect toView:scroll];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), concrete));
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertTrue([snapshot containsString:@"答案還沒寫"]);
}
- (void)testOversizedActionShowsAPausedInspectionRouteRatherThanPlayingOffscreen {
    [self open:27 second:15 operation:@"+"];
    [self resize:CGSizeMake(320, 270)];
    [self select:3 animated:YES];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    UILabel *notice = [self.controller valueForKey:@"playbackNotice"];
    UIButton *focus = [self.controller valueForKey:@"focusButton"];
    XCTAssertNotNil(notice.superview);
    XCTAssertTrue([notice.text containsString:@"先停在這一步"]);
    XCTAssertTrue([notice.text containsString:@"直拿手機"]);
    XCTAssertEqualObjects(focus.currentTitle, @"看交換");
    XCTAssertFalse(board.isPlaying);
    XCTAssertEqual([[board valueForKey:@"animatedLayers"] count], 0u);
    [self.controller focusCurrentContent];
    XCTAssertEqualObjects(focus.currentTitle, @"看直式");
    XCTAssertEqual(board.currentStepIndex, 3);
    [self resize:CGSizeMake(375, 812)];
    [self.controller replay];
    XCTAssertNil(notice.superview);
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertTrue([board.accessibilityValue containsString:@"答案還沒寫"]);
}
- (void)testOmittedLeadingZeroKeepsExplanationVisibleOnEntryAndReplayAfterInspection {
    [self open:100 second:1 operation:@"-"];
    [self resize:CGSizeMake(852, 393)];
    ArithmeticTeachingSequence *sequence = [self.controller valueForKey:@"sequence"];
    NSUInteger index = [sequence.steps indexOfObjectPassingTest:^BOOL(ArithmeticTeachingStep *step, NSUInteger position, BOOL *stop) {
        return step.kind == ArithmeticTeachingStepKindWriteAnswer && step.activeColumn == 0;
    }];
    XCTAssertNotEqual(index, NSNotFound);
    [self select:index animated:YES];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    UILabel *heading = [self.controller valueForKey:@"heading"];
    UILabel *narration = [self.controller valueForKey:@"narration"];
    XCTAssertTrue([narration.text containsString:@"最左邊多出來的 0 不用寫"]);
    XCTAssertTrue([self contains:heading]);
    XCTAssertTrue([self contains:narration]);
    XCTAssertTrue(CGRectIsNull(board.currentActionRect));
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateStill);
    NSString *snapshot = board.accessibilityValue;
    [self.controller focusCurrentContent];
    XCTAssertFalse([self contains:narration], @"Inspect written work before checking that Replay restores the explanation.");
    [self.controller replay];
    XCTAssertTrue([self contains:heading]);
    XCTAssertTrue([self contains:narration]);
    XCTAssertTrue(CGRectIsNull(board.currentActionRect));
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateStill);
    XCTAssertEqual(board.currentStepIndex, (NSInteger)index);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertNil(((UILabel *)[self.controller valueForKey:@"playbackNotice"]).superview);
    XCTAssertEqual([[board valueForKey:@"animatedLayers"] count], 0u);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
}
@end
