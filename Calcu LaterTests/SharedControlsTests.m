#include <math.h>
#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "ArithmeticProblem.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"
#import "MascotView.h"
#import "MultipleChoiceAnswerView.h"

@interface MCQDelegateRecorder : NSObject <MultipleChoiceAnswerViewDelegate>
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, assign) NSInteger value;
@property (nonatomic, assign) MCQResult result;
@property (nonatomic, copy) void (^onChoice)(MultipleChoiceAnswerView *view);
@end
@implementation MCQDelegateRecorder
- (void)mcqView:(MultipleChoiceAnswerView *)view didChoose:(NSInteger)value result:(MCQResult)result {
    self.count++;
    self.value = value;
    self.result = result;
    if (self.onChoice) self.onChoice(view);
}
@end

@interface SharedControlsTests : XCTestCase
@end

@implementation SharedControlsTests

- (MultipleChoiceAnswerView *)configuredChoices {
    MultipleChoiceAnswerView *view = [[MultipleChoiceAnswerView alloc] initWithFrame:CGRectMake(0, 0, 343, 260)];
    [view configureWithChoiceTitles:@[@"4", @"5", @"6", @"7"] correctIndex:1];
    [view layoutIfNeeded];
    return view;
}

- (UIButton *)button:(NSInteger)index inView:(MultipleChoiceAnswerView *)view {
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:UIButton.class] && child.tag == index) return (UIButton *)child;
    }
    XCTFail(@"Missing answer button %ld", (long)index);
    return nil;
}

- (void)waitForReady:(MultipleChoiceAnswerView *)view {
    XCTestExpectation *ready = [self expectationForPredicate:[NSPredicate predicateWithFormat:@"acceptingAnswers == YES"]
                                                     evaluatedWithObject:view handler:nil];
    [self waitForExpectations:@[ready] timeout:3];
}

- (void)testUnconfiguredViewDoesNotAcceptAnswers {
    MultipleChoiceAnswerView *view = [[MultipleChoiceAnswerView alloc] initWithFrame:CGRectZero];
    MCQDelegateRecorder *recorder = [[MCQDelegateRecorder alloc] init];
    view.delegate = recorder;
    XCTAssertFalse(view.isAcceptingAnswers);
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [self button:i inView:view];
        XCTAssertFalse(button.enabled);
        [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        NSString *expectedIdentifier = [NSString stringWithFormat:@"answer.%ld", (long)i];
        XCTAssertEqualObjects(button.accessibilityIdentifier, expectedIdentifier);
    }
    XCTAssertEqual(recorder.count, 0u);
}

- (void)testWrongAnswerGatesOtherChoicesBeforeDelegateSideEffects {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    MCQDelegateRecorder *recorder = [[MCQDelegateRecorder alloc] init];
    view.delegate = recorder;
    recorder.onChoice = ^(MultipleChoiceAnswerView *answerView) {
        XCTAssertFalse(answerView.isAcceptingAnswers);
        // Programmatic/reentrant activation is rejected even though hit testing is bypassed.
        [[self button:2 inView:answerView] sendActionsForControlEvents:UIControlEventTouchUpInside];
    };
    [[self button:0 inView:view] sendActionsForControlEvents:UIControlEventTouchDown];
    [[self button:0 inView:view] sendActionsForControlEvents:UIControlEventTouchUpInside];
    [[self button:1 inView:view] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(recorder.count, 1u);
    XCTAssertEqual(recorder.result, MCQResultWrong);
    XCTAssertFalse(view.isAcceptingAnswers);
    for (NSInteger i = 0; i < 4; i++) XCTAssertFalse([self button:i inView:view].enabled);
    XCTAssertEqualObjects([self button:2 inView:view].accessibilityValue, @"尚未作答");

    [self waitForReady:view];
    XCTAssertFalse([self button:0 inView:view].enabled);
    XCTAssertTrue([self button:1 inView:view].enabled);
    XCTAssertTrue([self button:2 inView:view].enabled);
    XCTAssertTrue([self button:3 inView:view].enabled);
    XCTAssertEqualObjects([self button:0 inView:view].accessibilityValue, @"已試過，還不是答案");
    BOOL hasVisibleFeedback = NO;
    for (UIView *child in [self button:0 inView:view].subviews) {
        if ([child isKindOfClass:UILabel.class]
            && [((UILabel *)child).text containsString:@"再想一想"]) hasVisibleFeedback = YES;
    }
    XCTAssertTrue(hasVisibleFeedback);
}

- (void)testCorrectAnswerLocksBeforeCallbackAndCannotBeAwardedTwice {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    MCQDelegateRecorder *recorder = [[MCQDelegateRecorder alloc] init];
    view.delegate = recorder;
    recorder.onChoice = ^(MultipleChoiceAnswerView *answerView) {
        XCTAssertFalse(answerView.isAcceptingAnswers);
        [[self button:1 inView:answerView] sendActionsForControlEvents:UIControlEventTouchUpInside];
    };
    UIButton *correct = [self button:1 inView:view];
    [correct sendActionsForControlEvents:UIControlEventTouchUpInside];
    [correct sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(recorder.count, 1u);
    XCTAssertEqual(recorder.result, MCQResultCorrect);
    XCTAssertEqualObjects(correct.accessibilityValue, @"答對了");
    XCTAssertTrue((correct.accessibilityTraits & UIAccessibilityTraitSelected) != 0);
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [self button:i inView:view];
        XCTAssertFalse(button.enabled);
        XCTAssertEqualWithAccuracy(button.alpha, 1.0, 0.001);
        XCTAssertEqualObjects([button titleColorForState:UIControlStateDisabled], ChildUI.brownText);
    }
}

- (void)testReconfigureResetsPressedWrongAndCorrectPresentation {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    UIButton *wrong = [self button:0 inView:view];
    [wrong sendActionsForControlEvents:UIControlEventTouchDown];
    [wrong sendActionsForControlEvents:UIControlEventTouchUpInside];
    [view configureWithChoiceTitles:@[@"1", @"2", @"3", @"4"] correctIndex:2];
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [self button:i inView:view];
        XCTAssertTrue(button.enabled);
        XCTAssertTrue(CGAffineTransformIsIdentity(button.transform));
        XCTAssertEqual(button.layer.animationKeys.count, 0u);
        XCTAssertEqualObjects(button.accessibilityValue, @"尚未作答");
    }
    [[self button:2 inView:view] sendActionsForControlEvents:UIControlEventTouchUpInside];
    [view reset];
    XCTAssertTrue(view.isAcceptingAnswers);
    XCTAssertFalse([self button:2 inView:view].selected);
    XCTAssertEqualObjects([self button:2 inView:view].accessibilityValue, @"尚未作答");
}

- (void)testDelegateMayReconfigureSynchronouslyWithoutOldFeedbackLeaking {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    MCQDelegateRecorder *recorder = [[MCQDelegateRecorder alloc] init];
    view.delegate = recorder;
    recorder.onChoice = ^(MultipleChoiceAnswerView *answerView) {
        [answerView configureWithChoiceTitles:@[@"11", @"12", @"13", @"14"] correctIndex:0];
        [answerView disableAllChoices];
    };
    [[self button:0 inView:view] sendActionsForControlEvents:UIControlEventTouchUpInside];
    // Wait for a separate view's feedback to finish, then verify that the old release
    // did not unlock this new question. No exact-duration/timestamp assertion is needed.
    MultipleChoiceAnswerView *clockView = [self configuredChoices];
    [[self button:0 inView:clockView] sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self waitForReady:clockView];
    XCTAssertFalse(view.isAcceptingAnswers);
    XCTAssertEqual(recorder.count, 1u);
    XCTAssertEqualObjects([self button:0 inView:view].currentTitle, @"11");
    XCTAssertEqualObjects([self button:0 inView:view].accessibilityValue, @"未選擇");
    for (NSInteger i = 0; i < 4; i++) XCTAssertFalse([self button:i inView:view].enabled);
}

- (void)testRevealHighlightsWithoutAwardingAnAnswer {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    MCQDelegateRecorder *recorder = [[MCQDelegateRecorder alloc] init];
    view.delegate = recorder;
    [view revealCorrectChoice];
    XCTAssertFalse(view.isAcceptingAnswers);
    XCTAssertEqual(recorder.count, 0u);
    XCTAssertEqualObjects([self button:1 inView:view].accessibilityValue, @"正確答案");
    XCTAssertTrue([self button:1 inView:view].selected);
    [[self button:1 inView:view] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(recorder.count, 0u);
}

- (void)testResetDoesNotExposeMissingOrEmptyChoices {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    [view configureWithChoiceTitles:@[@"1", @"", @"3"] correctIndex:0];
    [view reset];
    XCTAssertTrue([self button:0 inView:view].enabled);
    XCTAssertTrue([self button:2 inView:view].enabled);
    for (NSNumber *index in @[@1, @3]) {
        UIButton *button = [self button:index.integerValue inView:view];
        XCTAssertTrue(button.hidden);
        XCTAssertFalse(button.enabled);
        XCTAssertFalse(button.isAccessibilityElement);
    }
}

- (void)testInvalidOrOffscreenCorrectIndexFailsClosed {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    for (NSNumber *index in @[@(-1), @(NSNotFound), @4]) {
        [view configureWithChoiceTitles:@[@"1", @"2", @"3", @"4", @"5"] correctIndex:index.integerValue];
        XCTAssertFalse(view.isAcceptingAnswers);
        for (NSInteger i = 0; i < 4; i++) XCTAssertFalse([self button:i inView:view].enabled);
    }
    [view configureWithChoiceTitles:@[] correctIndex:0];
    XCTAssertFalse(view.isAcceptingAnswers);
    [view configureWithChoiceTitles:@[@""] correctIndex:0];
    XCTAssertFalse(view.isAcceptingAnswers);
}

- (void)testNumericAndStringModesKeepTheirDelegateValueContract {
    MultipleChoiceAnswerView *view = [self configuredChoices];
    MCQDelegateRecorder *recorder = [[MCQDelegateRecorder alloc] init];
    view.delegate = recorder;
    [view configureWithProblem:[[ArithmeticProblem alloc] initWithNumber1:2 number2:3 operator:@"+" answer:5]];
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [self button:i inView:view];
        if ([button.currentTitle isEqualToString:@"5"]) [button sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
    XCTAssertEqual(recorder.value, 5);
    XCTAssertEqual(recorder.result, MCQResultCorrect);
    [view configureWithChoiceTitles:@[@"1/4", @"2/4", @"3/4", @"4/4"] correctIndex:1];
    [[self button:1 inView:view] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(recorder.value, 1);
    XCTAssertEqualObjects([self button:1 inView:view].accessibilityLabel, @"選項 2，4 分之 2");
}

- (void)testDarkButtonTextMeetsContrastOnCandyPalette {
    CGFloat (^linear)(CGFloat) = ^CGFloat(CGFloat c) { return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4); };
    CGFloat (^luminance)(UIColor *) = ^CGFloat(UIColor *color) {
        CGFloat r = 0, g = 0, b = 0, a = 0;
        [color getRed:&r green:&g blue:&b alpha:&a];
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
    };
    for (NSInteger i = 0; i < 6; i++) {
        UIColor *color = [ChildUI candyColorAtIndex:i];
        ChildButton *button = [ChildButton buttonWithTitle:@"繼續練習" backgroundColor:color];
        XCTAssertEqualObjects([button titleColorForState:UIControlStateNormal], ChildUI.brownText);
        XCTAssertEqualObjects([button titleColorForState:UIControlStateDisabled], ChildUI.brownText);
        CGFloat ratio = (luminance(color) + 0.05) / (luminance(ChildUI.brownText) + 0.05);
        XCTAssertGreaterThanOrEqual(ratio, 4.5);
    }
}

- (void)testDisablingChildButtonRestoresTransform {
    ChildButton *button = [ChildButton buttonWithTitle:@"下一題" backgroundColor:ChildUI.skyBlue];
    button.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [button.layer addAnimation:[CABasicAnimation animationWithKeyPath:@"transform.scale"] forKey:@"test"];
    button.enabled = NO;
    XCTAssertTrue(CGAffineTransformIsIdentity(button.transform));
    XCTAssertEqual(button.layer.animationKeys.count, 0u);
}

- (void)testDecorativeBackgroundCannotInterceptTouchesOrVoiceOver {
    DecorativeBackgroundView *background = [DecorativeBackgroundView backgroundWithTheme:BackgroundThemeMainMenu];
    background.frame = CGRectMake(0, 0, 375, 667);
    [background layoutIfNeeded];
    XCTAssertGreaterThan(background.subviews.count, 0u);
    XCTAssertFalse(background.userInteractionEnabled);
    XCTAssertFalse(background.isAccessibilityElement);
    XCTAssertTrue(background.accessibilityElementsHidden);
    for (UIView *view in background.subviews) XCTAssertFalse(view.isAccessibilityElement);
}

- (void)testMascotDetachAndExplicitStopRemoveAllMotion {
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    MascotView *mascot = [[MascotView alloc] initWithVariant:MascotVariantPortrait];
    window.rootViewController = [[UIViewController alloc] init];
    window.hidden = NO;
    [window.rootViewController.view addSubview:mascot];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [mascot setEmotion:MascotEmotionTalking];
    UIImageView *image = [mascot valueForKey:@"imageView"];
    if (ChildUI.motionEnabled) XCTAssertNotNil([image.layer animationForKey:@"emotion"]);
    [mascot.layer addAnimation:[CABasicAnimation animationWithKeyPath:@"transform.translation.y"] forKey:@"test"];
    [mascot removeFromSuperview];
    XCTAssertEqual(mascot.layer.animationKeys.count, 0u);
    for (UIView *view in mascot.subviews) XCTAssertEqual(view.layer.animationKeys.count, 0u);
    XCTAssertTrue(CGAffineTransformIsIdentity(mascot.transform));
    [mascot stopAllAnimations];
    [window.rootViewController.view addSubview:mascot];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    XCTAssertEqual(mascot.layer.animationKeys.count, 0u);
    for (UIView *view in mascot.subviews) XCTAssertEqual(view.layer.animationKeys.count, 0u);
    window.hidden = YES;
}

@end
