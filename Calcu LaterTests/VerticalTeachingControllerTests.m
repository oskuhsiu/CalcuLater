#import <XCTest/XCTest.h>
#import "VerticalTeachingViewController.h"
#import "VerticalArithmeticBoardView.h"
#import "ArithmeticProblem.h"
#import "SpeechManager.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface VerticalTeachingViewController (ControllerTesting)
- (void)showCurrentStepAnimated:(BOOL)animated;
- (void)next;
- (void)previous;
- (void)replay;
- (void)restart;
- (void)focusCurrentContent;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
- (SpeechManager *)speechManager;
@end

/// Observe speech requests only, not audible output or playback/visibility.
@interface VTSpeechRecorder : SpeechManager
@property (nonatomic, strong) NSMutableArray<NSString *> *requests;
@end
@implementation VTSpeechRecorder
- (void)speak:(NSString *)text {
    if (!self.requests) self.requests = [NSMutableArray array];
    [self.requests addObject:[text copy]];
}
- (void)stop {}
@end
@interface VTSpeechRecordingController : VerticalTeachingViewController
@property (nonatomic, strong) VTSpeechRecorder *recorder;
@end
@implementation VTSpeechRecordingController
- (SpeechManager *)speechManager {
    if (!self.recorder) self.recorder = [[VTSpeechRecorder alloc] init];
    return self.recorder;
}
@end

// This drives the registered completion deterministically; it does not rotate
// a device. The original XCUITest scenarios remain the actual rotation gate.
@interface VTCompletionCoordinator : NSObject <UIViewControllerTransitionCoordinator>
@property (nonatomic, copy) void (^completion)(id<UIViewControllerTransitionCoordinatorContext> context);
@property (nonatomic, strong) UIView *testContainer;
- (void)complete;
@end
@implementation VTCompletionCoordinator
- (BOOL)animateAlongsideTransition:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))animation
                        completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))completion {
    self.completion = completion;
    if (animation) animation(self);
    return YES;
}
- (BOOL)animateAlongsideTransitionInView:(UIView *)view animation:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))animation
                              completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))completion {
    return [self animateAlongsideTransition:animation completion:completion];
}
- (void)notifyWhenInteractionEndsUsingBlock:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))handler {}
- (void)notifyWhenInteractionChangesUsingBlock:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))handler {}
- (BOOL)isAnimated { return YES; }
- (BOOL)initiallyInteractive { return NO; }
- (BOOL)isInteractive { return NO; }
- (BOOL)isInterruptible { return YES; }
- (BOOL)isCancelled { return NO; }
- (UIModalPresentationStyle)presentationStyle { return UIModalPresentationNone; }
- (NSTimeInterval)transitionDuration { return 0.3; }
- (CGFloat)percentComplete { return 1; }
- (CGFloat)completionVelocity { return 1; }
- (UIViewAnimationCurve)completionCurve { return UIViewAnimationCurveEaseInOut; }
- (CGAffineTransform)targetTransform { return CGAffineTransformIdentity; }
- (UIView *)containerView {
    if (!self.testContainer) self.testContainer = [[UIView alloc] init];
    return self.testContainer;
}
- (UIViewController *)viewControllerForKey:(UITransitionContextViewControllerKey)key { return nil; }
- (UIView *)viewForKey:(UITransitionContextViewKey)key { return nil; }
- (void)complete {
    void (^completion)(id<UIViewControllerTransitionCoordinatorContext>) = self.completion;
    self.completion = nil;
    if (completion) completion(self);
}
@end

@interface VerticalTeachingControllerTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIWindow *previousKeyWindow;
@property (nonatomic, strong) VerticalTeachingViewController *controller;
@end

@implementation VerticalTeachingControllerTests
- (void)tearDown {
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    [board cancelAnimations];
    [self.controller.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
    [self.controller.view removeFromSuperview];
    [self.controller removeFromParentViewController];
    self.controller = nil;
    self.window.hidden = YES;
    self.window.rootViewController = nil;
    self.window = nil;
    if (self.previousKeyWindow) {
        UIWindow *previous = self.previousKeyWindow;
        self.previousKeyWindow = nil;
        XCTAssertFalse(previous.hidden);
        XCTAssertEqual(previous.windowScene.activationState, UISceneActivationStateForegroundActive);
        [previous makeKeyWindow];
        XCTAssertTrue(previous.isKeyWindow);
    }
    [super tearDown];
}
- (void)open:(NSInteger)first second:(NSInteger)second operation:(NSString *)operation {
    [self open:first second:second operation:operation recordingSpeech:NO];
}
- (void)open:(NSInteger)first second:(NSInteger)second operation:(NSString *)operation recordingSpeech:(BOOL)recordingSpeech {
    NSInteger answer = [operation isEqualToString:@"+"] ? first + second : first - second;
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:first number2:second operator:operation answer:answer];
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 852, 852)];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.hidden = NO;
    Class controllerClass = recordingSpeech ? VTSpeechRecordingController.class : VerticalTeachingViewController.class;
    self.controller = [[controllerClass alloc] initWithProblem:problem wordProblem:nil];
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
- (BOOL)openCarryInForegroundScene {
    UIWindowScene *foreground = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow && !candidate.hidden && candidate.alpha > 0) {
                foreground = (UIWindowScene *)scene;
                self.previousKeyWindow = candidate;
                break;
            }
        }
        if (foreground) break;
    }
    XCTAssertNotNil(foreground, @"This is a real-scene test, not an unattached synthetic-window substitute.");
    XCTAssertNotNil(self.previousKeyWindow);
    XCTAssertEqual(UIApplication.sharedApplication.applicationState, UIApplicationStateActive);
    XCTAssertFalse(UIAccessibilityIsReduceMotionEnabled(), @"Natural motion needs the ordinary-motion native test configuration.");
    if (!foreground || !self.previousKeyWindow || UIAccessibilityIsReduceMotionEnabled()) return NO;
    CGRect bounds = foreground.coordinateSpace.bounds;
    BOOL usable = isfinite(bounds.origin.x) && isfinite(bounds.origin.y)
        && isfinite(bounds.size.width) && isfinite(bounds.size.height) && !CGRectIsEmpty(bounds);
    XCTAssertTrue(usable);
    if (!usable) return NO;
    self.window = [[UIWindow alloc] initWithWindowScene:foreground];
    self.window.frame = bounds;
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self.window layoutIfNeeded];
    [self.window.rootViewController.view layoutIfNeeded];
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:27 number2:15 operator:@"+" answer:42];
    self.controller = [[VerticalTeachingViewController alloc] initWithProblem:problem wordProblem:nil];
    __block BOOL presentationCompleted = NO;
    [self.window.rootViewController presentViewController:self.controller animated:NO completion:^{ presentationCompleted = YES; }];
    [self.controller.view layoutIfNeeded];
    XCTAssertTrue([foreground.windows containsObject:self.window]);
    XCTAssertTrue(self.window.isKeyWindow, @"The test window must be in front, then restore the original key window in tearDown.");
    XCTAssertFalse(self.window.hidden);
    XCTAssertEqual(self.window.rootViewController.view.window, self.window);
    XCTAssertEqual(self.window.windowScene.activationState, UISceneActivationStateForegroundActive);
    XCTAssertTrue(CGRectEqualToRect(self.window.frame, bounds));
    NSPredicate *presented = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        CALayer *visible = self.controller.view.layer.presentationLayer;
        return presentationCompleted && self.window.isKeyWindow && self.controller.view.window == self.window
            && self.window.windowScene.activationState == UISceneActivationStateForegroundActive
            && visible && !visible.hidden && visible.opacity > 0;
    }];
    XCTNSPredicateExpectation *ready = [[XCTNSPredicateExpectation alloc] initWithPredicate:presented object:nil];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ready] timeout:3];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Wait for the real initial presentation, not a fabricated model-only visible window.");
    XCTAssertEqual(self.controller.presentingViewController, self.window.rootViewController);
    XCTAssertEqual(self.controller.view.window, self.window);
    XCTAssertTrue(CGRectContainsRect(self.window.bounds, [self.controller.view convertRect:self.controller.view.bounds toView:self.window]),
        @"Use the system's actual page-sheet bounds inside this scene; never enlarge the window to fit the fixture.");
    return result == XCTWaiterResultCompleted;
}
- (VerticalArithmeticBoardView *)startFirstCarryWithControllerActions {
    [self.controller next]; // Optional prediction.
    [self.controller next]; // Column calculation.
    [self.controller next]; // First carry, without Replay or an extra resize pass.
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqual(board.currentStep.kind, ArithmeticTeachingStepKindRegroup);
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStatePlaying);
    XCTAssertNotNil([board valueForKey:@"animationDisplayLink"]);
    XCTAssertTrue(CGRectContainsRect(self.window.bounds, [board convertRect:board.currentPlaybackRect toView:self.window]));
    return board;
}
- (void)assertNaturalCompletion:(VerticalArithmeticBoardView *)board {
    NSPredicate *finished = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return board.playbackState == VerticalArithmeticPlaybackStateCompleted;
    }];
    XCTNSPredicateExpectation *completed = [[XCTNSPredicateExpectation alloc] initWithPredicate:finished object:nil];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[completed] timeout:3], XCTWaiterResultCompleted,
        @"Only real display-link completion counts; Still, Interrupted and Reduced Motion are not success.");
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateCompleted);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
    XCTAssertEqual([[board valueForKey:@"animatedLayers"] count], 0u);
}
- (UIView *)addStackSpacer:(CGFloat)height beforeBoard:(BOOL)beforeBoard {
    UIStackView *content = [self.controller valueForKey:@"content"];
    UIView *board = [self.controller valueForKey:@"board"];
    UIView *spacer = [[UIView alloc] init];
    [spacer.heightAnchor constraintEqualToConstant:height].active = YES;
    if (beforeBoard) [content insertArrangedSubview:spacer atIndex:[content.arrangedSubviews indexOfObject:board]];
    else [content addArrangedSubview:spacer];
    [self.controller.view setNeedsLayout];
    [self.controller.view layoutIfNeeded];
    return spacer;
}
- (void)testForegroundSceneControllerFirstCarryNaturallyCompletesWithoutReplayOrSyntheticResize {
    if (![self openCarryInForegroundScene]) return;
    VerticalArithmeticBoardView *board = [self startFirstCarryWithControllerActions];
    NSString *snapshot = board.accessibilityValue;
    [self assertNaturalCompletion:board];
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
}
- (void)testForegroundControllerDownstreamStackGrowthDoesNotInterruptAStationaryVisibleAction {
    if (![self openCarryInForegroundScene]) return;
    VerticalArithmeticBoardView *board = [self startFirstCarryWithControllerActions];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGRect frame = [board convertRect:board.bounds toView:scroll];
    CGSize contentSize = scroll.contentSize;
    CGPoint offset = scroll.contentOffset;
    [self addStackSpacer:80 beforeBoard:NO];
    XCTAssertTrue(CGRectEqualToRect(frame, [board convertRect:board.bounds toView:scroll]));
    XCTAssertGreaterThan(scroll.contentSize.height, contentSize.height);
    XCTAssertTrue(CGPointEqualToPoint(offset, scroll.contentOffset));
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStatePlaying);
    [self assertNaturalCompletion:board];
}
- (void)testForegroundControllerUpstreamStackMovementInterruptsWithoutResumingOrCompleting {
    if (![self openCarryInForegroundScene]) return;
    VerticalArithmeticBoardView *board = [self startFirstCarryWithControllerActions];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGRect frame = [board convertRect:board.bounds toView:scroll];
    NSString *snapshot = board.accessibilityValue;
    [self addStackSpacer:30 beforeBoard:YES];
    XCTAssertGreaterThan(CGRectGetMinY([board convertRect:board.bounds toView:scroll]), CGRectGetMinY(frame));
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
    [self.controller.view setNeedsLayout];
    [self.controller.view layoutIfNeeded];
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
    XCTAssertEqual([[board valueForKey:@"animatedLayers"] count], 0u);
}
- (void)testModeledContentSizeSettlementCannotConcealAnAlreadyClippedPlayback {
    if (![self openCarryInForegroundScene]) return;
    VerticalArithmeticBoardView *board = [self startFirstCarryWithControllerActions];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    NSString *snapshot = board.accessibilityValue;
    // Isolate the layout cancellation path from the independently covered scroll
    // delegate. This models an offset clamp without claiming UIKit callback order.
    id<UIScrollViewDelegate> delegate = scroll.delegate;
    scroll.delegate = nil;
    scroll.contentSize = CGSizeMake(scroll.contentSize.width, scroll.contentSize.height + scroll.bounds.size.height * 2);
    [scroll setContentOffset:CGPointMake(0, scroll.contentOffset.y + scroll.bounds.size.height) animated:NO];
    XCTAssertFalse(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), [board convertRect:board.currentPlaybackRect toView:scroll]));
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStatePlaying);
    [self.controller viewDidLayoutSubviews];
    scroll.delegate = delegate;
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
}
- (void)testForegroundControllerViewportAndBoardResizeInterruptsWithoutAutomaticReplay {
    if (![self openCarryInForegroundScene]) return;
    VerticalArithmeticBoardView *board = [self startFirstCarryWithControllerActions];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGSize viewport = scroll.bounds.size, boardSize = board.bounds.size;
    NSString *snapshot = board.accessibilityValue;
    // A real Auto Layout size change inside the actual scene, not an orientation
    // claim. The XCUITest still owns actual device rotation and its timing.
    CGFloat horizontalInset = MAX(20, (self.controller.view.bounds.size.width - 280) / 2);
    self.controller.additionalSafeAreaInsets = UIEdgeInsetsMake(0, horizontalInset, 20, horizontalInset);
    [self.controller.view layoutIfNeeded];
    XCTAssertFalse(CGSizeEqualToSize(scroll.bounds.size, viewport));
    XCTAssertLessThan(board.bounds.size.width, boardSize.width);
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
    [self.controller.view layoutIfNeeded];
    XCTAssertEqual(board.playbackState, VerticalArithmeticPlaybackStateInterrupted);
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
}
- (VTCompletionCoordinator *)beginModeledLandscapeTransition {
    VTCompletionCoordinator *coordinator = [[VTCompletionCoordinator alloc] init];
    [self.controller viewWillTransitionToSize:CGSizeMake(852, 393) withTransitionCoordinator:coordinator];
    XCTAssertNotNil(coordinator.completion, @"The production controller must register a real transition-completion callback.");
    [self resize:CGSizeMake(852, 393)];
    return coordinator;
}
- (void)testTransitionCompletionReframesAnOffsetOnlyDisplacementWithoutReplaying {
    [self open:27 second:15 operation:@"+"];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self select:3 animated:YES];
    VTCompletionCoordinator *coordinator = [self beginModeledLandscapeTransition];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    CGRect frame = [board convertRect:board.bounds toView:scroll];
    CGSize contentSize = scroll.contentSize;
    NSString *snapshot = board.accessibilityValue;
    VerticalArithmeticPlaybackState state = board.playbackState;
    // Model a late UIKit offset adjustment after its first semantic reframe.
    [scroll setContentOffset:CGPointMake(0, scroll.contentOffset.y + 90) animated:NO];
    CGPoint displaced = scroll.contentOffset;
    [self.controller viewDidLayoutSubviews];
    XCTAssertTrue(CGRectEqualToRect(frame, [board convertRect:board.bounds toView:scroll]));
    XCTAssertTrue(CGSizeEqualToSize(contentSize, scroll.contentSize));
    XCTAssertFalse(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), [board convertRect:board.currentActionRect toView:scroll]));
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, displaced), @"An ordinary offset-only scroll is not a new auto-framing request.");
    [coordinator complete];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), [board convertRect:board.currentActionRect toView:scroll]));
    XCTAssertFalse(CGPointEqualToPoint(scroll.contentOffset, displaced));
    XCTAssertEqual(board.playbackState, state);
    XCTAssertFalse(board.isPlaying);
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
}
- (void)testTransitionCompletionPreservesPanAndAccessibilityInspection {
    [self open:27 second:15 operation:@"+"];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self select:3 animated:YES];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    for (NSNumber *accessibility in @[@NO, @YES]) {
        [self.controller replay];
        VTCompletionCoordinator *coordinator = [self beginModeledLandscapeTransition];
        if (accessibility.boolValue) [scroll accessibilityScroll:UIAccessibilityScrollDirectionDown];
        else [self.controller scrollViewWillBeginDragging:scroll];
        XCTAssertTrue([[self.controller valueForKey:@"hasManualInspection"] boolValue]);
        [scroll setContentOffset:CGPointMake(0, scroll.contentOffset.y + 40) animated:NO];
        CGPoint inspection = scroll.contentOffset;
        [coordinator complete];
        XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, inspection));
        XCTAssertFalse(board.isPlaying);
        XCTAssertEqual(board.currentStepIndex, 3);
    }
}
- (void)testSupersededTransitionCompletionCannotReframeANewerVisitOfTheSameStep {
    [self open:27 second:15 operation:@"+"];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self select:3 animated:YES];
    VTCompletionCoordinator *coordinator = [self beginModeledLandscapeTransition];
    [self.controller previous];
    [self.controller next];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    [scroll setContentOffset:CGPointMake(0, scroll.contentOffset.y + 90) animated:NO];
    CGPoint newerVisit = scroll.contentOffset;
    VerticalArithmeticPlaybackState state = board.playbackState;
    [coordinator complete];
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, newerVisit));
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqual(board.playbackState, state);
}
- (UIButton *)choice:(NSInteger)value {
    UIStackView *choices = [self.controller valueForKey:@"choices"];
    for (UIButton *button in choices.arrangedSubviews) if (button.tag == value) return button;
    return nil;
}
- (VTSpeechRecorder *)speechRecorder { return ((VTSpeechRecordingController *)self.controller).recorder; }
- (void)assertReadRequests:(NSString *)expected {
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    NSInteger stepIndex = board.currentStepIndex;
    NSString *snapshot = board.accessibilityValue;
    VerticalArithmeticPlaybackState playback = board.playbackState;
    NSIndexSet *answered = [[self.controller valueForKey:@"answeredSteps"] copy];
    NSDictionary *lastAttempts = [[self.controller valueForKey:@"lastAttemptedValues"] copy];
    NSUInteger requests = self.speechRecorder.requests.count;
    UIButton *read = nil;
    for (UIView *view in ((UIStackView *)[self.controller valueForKey:@"content"]).arrangedSubviews) {
        if ([view isKindOfClass:UIButton.class] && [view.accessibilityIdentifier isEqualToString:@"teaching.read"]) read = (UIButton *)view;
    }
    XCTAssertNotNil(read);
    // Exercise the real target/action. This is not proof of touch reachability
    // or audible delivery, and does not replace native UI/audio acceptance.
    [read sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(self.speechRecorder.requests.count, requests + 1);
    XCTAssertEqualObjects(self.speechRecorder.requests.lastObject, expected);
    XCTAssertEqual(board.currentStepIndex, stepIndex);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertEqual(board.playbackState, playback);
    XCTAssertEqualObjects([self.controller valueForKey:@"answeredSteps"], answered);
    XCTAssertEqualObjects([self.controller valueForKey:@"lastAttemptedValues"], lastAttempts);
}
- (void)testWrongAndCorrectColumnFeedbackIsVisibleAndInspectionReturnsWithoutRevealingAnAnswer {
    [self open:27 second:15 operation:@"+" recordingSpeech:YES];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self resize:CGSizeMake(375, 812)];
    [self select:1 animated:NO];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    NSString *before = board.accessibilityValue;
    ArithmeticTeachingStep *prediction = board.currentStep;
    NSString *question = [NSString stringWithFormat:@"%@。%@。%@", prediction.title, prediction.explanation, prediction.prompt];
    XCTAssertEqual(self.speechRecorder.requests.count, 0u);
    [self assertReadRequests:question];
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
    XCTAssertEqual(self.speechRecorder.requests.count, 1u, @"Choosing must not request speech automatically.");
    NSString *wrongSpeech = [NSString stringWithFormat:@"%@ %@", question, feedback.text];
    [self assertReadRequests:wrongSpeech];
    XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:@"42"]);
    [self.controller focusCurrentContent];
    UIButton *focus = [self.controller valueForKey:@"focusButton"];
    XCTAssertEqualObjects(focus.currentTitle, @"回到選項");
    XCTAssertFalse(board.isPlaying);
    [self.controller focusCurrentContent];
    XCTAssertEqualObjects(focus.currentTitle, @"看數量");
    XCTAssertTrue([self contains:[self.controller valueForKey:@"choices"]]);
    XCTAssertEqual(self.speechRecorder.requests.count, 2u, @"Inspecting must not request speech automatically.");
    [[self choice:12] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertTrue([feedback.text containsString:@"7 + 5 = 12 個一"]);
    XCTAssertTrue([self contains:feedback]);
    XCTAssertEqualObjects([self choice:12].accessibilityValue, @"和這一步的數量相同");
    XCTAssertFalse([feedback.text containsString:@"42"]);
    XCTAssertEqualObjects(board.accessibilityValue, before);
    XCTAssertEqual(self.speechRecorder.requests.count, 2u);
    NSString *correctSpeech = [NSString stringWithFormat:@"%@ %@", question, feedback.text];
    [self assertReadRequests:correctSpeech];
    XCTAssertNotEqualObjects(self.speechRecorder.requests.lastObject, wrongSpeech);
    XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:@"42"]);
    [self.controller next];
    XCTAssertEqual(self.speechRecorder.requests.count, 3u);
    ArithmeticTeachingStep *calculation = board.currentStep;
    [self assertReadRequests:[NSString stringWithFormat:@"%@。%@", calculation.title, calculation.explanation]];
    [self.controller previous];
    XCTAssertFalse([self choice:12].enabled);
    XCTAssertTrue([((UILabel *)[self.controller valueForKey:@"choiceFeedback"]).text containsString:@"7 + 5 = 12 個一"]);
    XCTAssertEqual(self.speechRecorder.requests.count, 4u, @"Navigation must not request speech automatically.");
    [self assertReadRequests:correctSpeech];
    [self.controller restart];
    [self.controller next];
    XCTAssertTrue([self choice:11].enabled);
    XCTAssertTrue([self choice:12].enabled);
    XCTAssertEqual([[self.controller valueForKey:@"lastAttemptedValues"] count], 0u);
    XCTAssertEqual(self.speechRecorder.requests.count, 5u, @"Restart must not request speech automatically.");
    [self assertReadRequests:question];
    XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:@"你選"]);
}
- (void)testBothZeroBorrowPredictionsExplainTheChosenUnitsWithoutLeakingTheNextExchange {
    [self open:500 second:128 operation:@"-" recordingSpeech:YES];
    ArithmeticTeachingSequence *sequence = [self.controller valueForKey:@"sequence"];
    NSUInteger tested = 0;
    NSUInteger requests = 0;
    for (NSUInteger index = 0; index + 1 < sequence.steps.count; index++) {
        if (sequence.steps[index].kind != ArithmeticTeachingStepKindPrediction
            || sequence.steps[index + 1].kind != ArithmeticTeachingStepKindRegroup) continue;
        [self select:index animated:NO];
        XCTAssertEqual(self.speechRecorder.requests.count, requests);
        ArithmeticTeachingStep *prediction = sequence.steps[index];
        NSString *question = [NSString stringWithFormat:@"%@。%@。%@", prediction.title, prediction.explanation, prediction.prompt];
        [self assertReadRequests:question];
        requests++;
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
        XCTAssertEqual(self.speechRecorder.requests.count, requests, @"Choosing must not request speech automatically.");
        NSString *wrongSpeech = [NSString stringWithFormat:@"%@ %@", question, feedback.text];
        [self assertReadRequests:wrongSpeech];
        requests++;
        XCTAssertTrue([self.speechRecorder.requests.lastObject containsString:selection]);
        XCTAssertTrue([self.speechRecorder.requests.lastObject containsString:equality]);
        XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:@"372"]);
        if (tested == 0) XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:@"10 個一"]);
        [self.controller previous];
        [self.controller next];
        XCTAssertEqual(self.speechRecorder.requests.count, requests);
        [self assertReadRequests:wrongSpeech];
        requests++;
        [[self choice:10] sendActionsForControlEvents:UIControlEventTouchUpInside];
        XCTAssertEqual(self.speechRecorder.requests.count, requests);
        [self assertReadRequests:[NSString stringWithFormat:@"%@ %@", question, feedback.text]];
        requests++;
        NSString *correctSelection = [NSString stringWithFormat:@"你選 10 個%@", unit];
        XCTAssertTrue([self.speechRecorder.requests.lastObject containsString:correctSelection]);
        XCTAssertTrue([self.speechRecorder.requests.lastObject containsString:equality]);
        XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:selection]);
        XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:@"372"]);
        if (tested == 0) XCTAssertFalse([self.speechRecorder.requests.lastObject containsString:@"10 個一"]);
        tested++;
    }
    XCTAssertEqual(tested, 2u);
}
- (void)testActualControllerReframesAfterResizeAndReplayRetainsTheSelectedSnapshot {
    [self open:27 second:15 operation:@"+"];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self resize:CGSizeMake(393, 852)];
    [self select:3 animated:YES];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    NSString *snapshot = board.accessibilityValue;
    [self resize:CGSizeMake(852, 393)];
    XCTAssertFalse(board.isPlaying, @"Rotation must not silently begin another playback.");
    CGRect beforeInspection = [board convertRect:board.currentConcreteTransformationRect toView:scroll];
    XCTAssertLessThanOrEqual(beforeInspection.size.height, scroll.bounds.size.height - 16);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), beforeInspection),
        @"Rotation itself must frame the feasible exchange after text rewraps, before Focus or Replay can repair it.");
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    [self.controller focusCurrentContent];
    [self.controller replay];
    CGRect concrete = [board convertRect:board.currentConcreteTransformationRect toView:scroll];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), concrete));
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertTrue([snapshot containsString:@"答案還沒寫"]);
}
- (UIView *)insertUpstreamSpacer:(CGFloat)height {
    UIStackView *content = [self.controller valueForKey:@"content"];
    UIView *board = [self.controller valueForKey:@"board"];
    UIView *spacer = [[UIView alloc] init];
    [spacer.heightAnchor constraintEqualToConstant:height].active = YES;
    [content insertArrangedSubview:spacer atIndex:[content.arrangedSubviews indexOfObject:board]];
    [self resize:self.controller.view.bounds.size];
    return spacer;
}
- (void)testLaterUpstreamLayoutPassReframesTheActionWithoutAViewportResize {
    [self open:27 second:15 operation:@"+"];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self resize:CGSizeMake(852, 393)];
    [self select:3 animated:NO];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    // Reproduce the second-pass displacement independently of UIKit's current
    // wrapping order. The board and viewport keep exactly the same dimensions.
    UIView *spacer = [self insertUpstreamSpacer:120];
    [self.controller replay];
    CGSize viewportSize = scroll.bounds.size, boardSize = board.bounds.size;
    CGRect before = [board convertRect:board.currentConcreteTransformationRect toView:scroll];
    CGPoint offset = scroll.contentOffset;
    NSString *snapshot = board.accessibilityValue;
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), before));
    [spacer removeFromSuperview];
    [self resize:self.controller.view.bounds.size];
    CGRect after = [board convertRect:board.currentConcreteTransformationRect toView:scroll];
    XCTAssertTrue(CGSizeEqualToSize(scroll.bounds.size, viewportSize));
    XCTAssertTrue(CGSizeEqualToSize(board.bounds.size, boardSize));
    XCTAssertEqualWithAccuracy(CGRectGetMinY(before) - CGRectGetMinY(after), 134, 1,
        @"Removing the 120-point arranged view also removes one 14-point stack spacing.");
    XCTAssertLessThan(scroll.contentOffset.y, offset.y);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), after));
    XCTAssertFalse(board.isPlaying, @"A late layout correction cancels motion, never restarts it.");
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    XCTAssertEqual([[board valueForKey:@"animatedLayers"] count], 0u);
    XCTAssertNil([board valueForKey:@"animationDisplayLink"]);
    CGPoint settled = scroll.contentOffset;
    [self resize:self.controller.view.bounds.size];
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, settled), @"Stable geometry must not keep moving the viewport.");
}
- (void)testLateLayoutDoesNotOverrideManualInspectionOrPredictionState {
    [self open:27 second:15 operation:@"+"];
    self.controller.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [self resize:CGSizeMake(393, 852)];
    [self select:1 animated:NO];
    [[self choice:11] sendActionsForControlEvents:UIControlEventTouchUpInside];
    [[self choice:12] sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self.controller next];
    [self.controller next];
    [self resize:CGSizeMake(852, 393)];
    VerticalArithmeticBoardView *board = [self.controller valueForKey:@"board"];
    UIScrollView *scroll = [self.controller valueForKey:@"scroll"];
    UIView *spacer = [self insertUpstreamSpacer:120];
    [self.controller replay];
    NSString *snapshot = board.accessibilityValue;
    [self.controller scrollViewWillBeginDragging:scroll];
    [scroll setContentOffset:CGPointMake(0, 120) animated:NO];
    CGPoint inspection = scroll.contentOffset;
    [spacer removeFromSuperview];
    [self resize:self.controller.view.bounds.size];
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, inspection),
        @"A layout update cannot undo the learner's deliberate inspection scroll.");
    XCTAssertFalse(board.isPlaying);
    XCTAssertEqual(board.currentStepIndex, 3);
    XCTAssertEqualObjects(board.accessibilityValue, snapshot);
    [self.controller replay];
    CGRect action = [board convertRect:board.currentConcreteTransformationRect toView:scroll];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, 0, 7), action));
    [self.controller previous];
    [self.controller previous];
    XCTAssertFalse([self choice:11].enabled);
    XCTAssertFalse([self choice:12].enabled);
    XCTAssertEqualObjects([self choice:12].accessibilityValue, @"和這一步的數量相同");
    XCTAssertTrue([((UILabel *)[self.controller valueForKey:@"choiceFeedback"]).text containsString:@"7 + 5 = 12 個一"]);
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
