#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import <QuartzCore/QuartzCore.h>
#import "LessonIntroView.h"
#import "Lesson.h"
#import "ArithmeticProblem.h"
#import "ExplanationViewController.h"
#import "SpeechManager.h"
#import "ChildUIKit.h"

@interface LessonIntroView (TeachingTests)
- (void)renderStepAnimated:(BOOL)animated;
- (SpeechManager *)speechManager;
- (void)applyDotStateForStep:(NSInteger)step;
- (void)frameNewStepScene:(CGRect)scene frames:(CGRect)frames counters:(CGRect)counters;
- (NSArray *)makeTenTransferLegs;
- (NSTimeInterval)makeTenTransferDuration;
- (CGRect)makeTenTransferBounds:(NSArray *)legs;
- (BOOL)prefersReducedMotion;
- (BOOL)isRequiredActionVisible;
- (void)validatePlaybackVisibility;
- (void)completeStepAnimation:(UIViewPropertyAnimator *)animator generation:(NSUInteger)generation
    step:(NSInteger)step position:(UIViewAnimatingPosition)position;
@end

/// Exercises the reduced-motion branch without changing a device preference or
/// disabling animations globally. It can only opt in, never override a user's
/// enabled Reduce Motion setting.
@interface CLReducedMotionIntroView : LessonIntroView
@property (nonatomic) BOOL forceReducedMotion;
@end
@implementation CLReducedMotionIntroView
- (BOOL)prefersReducedMotion { return self.forceReducedMotion || [super prefersReducedMotion]; }
@end

/// Records the real explicit speech entry point without speaking test audio.
/// The production default remains the shared SpeechManager; cancellation calls
/// use that same service, so lifecycle assertions observe the actual callers.
@interface CLIntroSpeechRecorder : SpeechManager
@property (nonatomic, strong) NSMutableArray<NSString *> *requests;
@property (nonatomic) NSUInteger stopCount;
@end
@implementation CLIntroSpeechRecorder
- (void)speak:(NSString *)text {
    if (!self.requests) self.requests = [NSMutableArray array];
    [self.requests addObject:[text copy]];
}
- (void)stop { self.stopCount++; }
@end
@interface CLSpeechRecordingIntroView : CLReducedMotionIntroView
@property (nonatomic, strong) CLIntroSpeechRecorder *recorder;
@end
@implementation CLSpeechRecordingIntroView
- (SpeechManager *)speechManager {
    if (!self.recorder) self.recorder = [[CLIntroSpeechRecorder alloc] init];
    return self.recorder;
}
@end

@interface CLIntroFinishObserver : NSObject <LessonIntroViewDelegate>
@property (nonatomic) NSInteger finishCount;
@end
@implementation CLIntroFinishObserver
- (void)lessonIntroDidFinish:(LessonIntroView *)introView { self.finishCount++; }
@end

/// Records the real renderer's snapshots, including the before-state used for
/// Replay. No substitute renderer and no globally disabled animations.
@interface CLRecordingIntroView : LessonIntroView
@property (nonatomic, strong) NSMutableArray<NSNumber *> *renderedSteps;
@property (nonatomic, strong) NSMutableArray<NSArray<NSDictionary *> *> *snapshots;
@property (nonatomic, strong) NSMutableArray<NSValue *> *viewportSnapshots;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *geometrySnapshots;
@property (nonatomic) NSUInteger framingCount;
@property (nonatomic) NSUInteger snapshotCountAtFraming;
@property (nonatomic) BOOL animatorExistedAtFraming;
@end
@implementation CLRecordingIntroView
- (void)applyDotStateForStep:(NSInteger)step {
    [super applyDotStateForStep:step];
    if (!self.renderedSteps) self.renderedSteps = [NSMutableArray array];
    if (!self.snapshots) self.snapshots = [NSMutableArray array];
    if (!self.viewportSnapshots) self.viewportSnapshots = [NSMutableArray array];
    [self.renderedSteps addObject:@(step)];
    NSMutableArray *snapshot = [NSMutableArray array];
    for (UIView *dot in [self valueForKey:@"dots"]) {
        [snapshot addObject:@{@"center": [NSValue valueWithCGPoint:dot.center],
            @"frame": [NSValue valueWithCGRect:dot.frame], @"alpha": @(dot.alpha),
            @"crossed": [dot valueForKey:@"crossedOut"]}];
    }
    [self.snapshots addObject:snapshot];
    UIScrollView *scroll = [self valueForKey:@"scrollView"];
    UIView *stage = [self valueForKey:@"stage"];
    [self.viewportSnapshots addObject:[NSValue valueWithCGRect:[scroll convertRect:scroll.bounds toView:stage]]];
    if (!self.geometrySnapshots) self.geometrySnapshots = [NSMutableArray array];
    [self.geometrySnapshots addObject:@{@"step": @(step), @"intro": [NSValue valueWithCGRect:self.bounds],
        @"stage": [NSValue valueWithCGRect:stage.bounds],
        @"firstFrame": [NSValue valueWithCGRect:[[self valueForKey:@"firstFrame"] frame]],
        @"secondFrame": [NSValue valueWithCGRect:[[self valueForKey:@"secondFrame"] frame]]}];
}
- (void)frameNewStepScene:(CGRect)scene frames:(CGRect)frames counters:(CGRect)counters {
    [super frameNewStepScene:scene frames:frames counters:counters];
    self.framingCount++;
    self.snapshotCountAtFraming = self.snapshots.count;
    self.animatorExistedAtFraming = [self valueForKey:@"stepAnimator"] != nil;
}
@end

@interface LessonIntroViewTests : XCTestCase
@property (nonatomic, strong) UIWindow *hostWindow;
@property (nonatomic, weak) UIWindow *previousKeyWindow;
@property (nonatomic, strong) LessonIntroView *intro;
@end

@implementation LessonIntroViewTests

- (void)releaseHost {
    [self.intro stopPlayback];
    [self.intro removeFromSuperview];
    self.intro = nil;
    self.hostWindow.hidden = YES;
    self.hostWindow.rootViewController = nil;
    self.hostWindow = nil;
    // Real presentation probes temporarily own the scene's key window. Leave
    // the application's original window as we found it, including between
    // widths within the same test. Geometry-only fixtures never become key.
    if (self.previousKeyWindow && !self.previousKeyWindow.hidden
        && self.previousKeyWindow.windowScene.activationState == UISceneActivationStateForegroundActive) {
        [self.previousKeyWindow makeKeyWindow];
    }
    self.previousKeyWindow = nil;
}
- (void)tearDown {
    [self releaseHost];
    [super tearDown];
}

- (Lesson *)lessonAtIndex:(NSUInteger)index { return [LessonCatalog addSubLessons][index]; }
- (ArithmeticProblem *)problemA:(NSInteger)a b:(NSInteger)b make:(BOOL)make {
    return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:make ? @"+" : @"-" answer:make ? a + b : a - b];
}
- (LessonIntroView *)hostIntro:(LessonIntroView *)intro width:(CGFloat)width height:(CGFloat)height {
    [self releaseHost];
    self.hostWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    UIViewController *host = [[UIViewController alloc] init];
    self.hostWindow.rootViewController = host;
    self.hostWindow.hidden = NO;
    // Complete synthetic-window layout before the simulator can substitute its
    // screen size for the compact/wide geometry being checked.
    host.view.frame = self.hostWindow.bounds;
    self.intro = intro;
    self.intro.frame = host.view.bounds;
    self.intro.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host.view addSubview:self.intro];
    [host.view setNeedsLayout];
    [host.view layoutIfNeeded];
    [self.intro play];
    [self.intro layoutIfNeeded];
    return self.intro;
}
- (LessonIntroView *)showLessonAtIndex:(NSUInteger)index width:(CGFloat)width height:(CGFloat)height {
    return [self hostIntro:[[LessonIntroView alloc] initWithLesson:[self lessonAtIndex:index]] width:width height:height];
}
- (LessonIntroView *)showProblemA:(NSInteger)a b:(NSInteger)b make:(BOOL)make width:(CGFloat)width {
    LessonIntroView *intro = [[LessonIntroView alloc] initWithProblem:[self problemA:a b:b make:make]
        lesson:[self lessonAtIndex:make ? 3 : 4]];
    XCTAssertNotNil(intro);
    return [self hostIntro:intro width:width height:500];
}
/// Synthetic windows remain useful for synchronous layout matrices, but in a
/// scene-based app they do not establish a native render tree. Presentation probes
/// must use the foreground scene exactly as the production SceneDelegate does.
/// The fixed-size child fits INSIDE the physical iPad window, never an oversized
/// fake window, and no visibility gate or animation behavior is overridden.
- (LessonIntroView *)showPresentationProblemA:(NSInteger)a width:(CGFloat)width {
    return [self showPresentationProblemA:a width:width category:nil];
}
- (LessonIntroView *)showPresentationProblemA:(NSInteger)a width:(CGFloat)width
    category:(UIContentSizeCategory)category {
    [self releaseHost];
    BOOL nativeAnimationEnvironment = UIView.areAnimationsEnabled && !CATransaction.disableActions;
    XCTAssertTrue(nativeAnimationEnvironment,
        @"Native motion requires animations enabled and no leaked disable-actions transaction (enabled=%d disabled=%d).",
        UIView.areAnimationsEnabled, CATransaction.disableActions);
    if (!nativeAnimationEnvironment) return nil; // Do not drain or reset another component's transaction.
    UIWindowScene *foregroundScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]
            && scene.activationState == UISceneActivationStateForegroundActive
            && ((UIWindowScene *)scene).screen == UIScreen.mainScreen) {
            foregroundScene = (UIWindowScene *)scene;
            break;
        }
    }
    XCTAssertNotNil(foregroundScene, @"Native presentation requires the app's active physical window scene.");
    if (!foregroundScene) return nil;
    CGRect sceneBounds = foregroundScene.coordinateSpace.bounds;
    XCTAssertGreaterThanOrEqual(sceneBounds.size.width, 736, @"Run every wide presentation probe on the components iPad host.");
    XCTAssertGreaterThanOrEqual(sceneBounds.size.height, 500);
    if (sceneBounds.size.width < width || sceneBounds.size.height < 500) return nil;
    for (UIWindow *window in foregroundScene.windows) {
        if (window.isKeyWindow) { self.previousKeyWindow = window; break; }
    }
    self.hostWindow = [[UIWindow alloc] initWithWindowScene:foregroundScene];
    self.hostWindow.frame = sceneBounds;
    UIViewController *host = [[UIViewController alloc] init];
    self.hostWindow.rootViewController = host;
    if (category) host.traitOverrides.preferredContentSizeCategory = category;
    [self.hostWindow makeKeyAndVisible];
    [self.hostWindow layoutIfNeeded];
    __block LessonIntroView *intro;
    if (category) {
        [host.traitCollection performAsCurrentTraitCollection:^{
            intro = [[LessonIntroView alloc] initWithProblem:[self problemA:a b:9 make:YES]
                lesson:[self lessonAtIndex:3]];
        }];
    } else {
        intro = [[LessonIntroView alloc] initWithProblem:[self problemA:a b:9 make:YES]
            lesson:[self lessonAtIndex:3]];
    }
    self.intro = intro;
    intro.autoresizingMask = UIViewAutoresizingNone;
    intro.frame = CGRectMake(floor((host.view.bounds.size.width - width) / 2),
        floor((host.view.bounds.size.height - 500) / 2), width, 500);
    [host.view addSubview:intro];
    [host.view setNeedsLayout]; [host.view layoutIfNeeded];
    [intro play];
    [intro layoutIfNeeded];
    [CATransaction flush];
    XCTAssertEqual(self.hostWindow.windowScene, foregroundScene);
    XCTAssertTrue(self.hostWindow.isKeyWindow);
    XCTAssertEqualWithAccuracy(self.hostWindow.bounds.size.width, sceneBounds.size.width, 0.5);
    XCTAssertEqualWithAccuracy(self.hostWindow.bounds.size.height, sceneBounds.size.height, 0.5);
    XCTAssertTrue(CGRectContainsRect(self.hostWindow.bounds, [intro convertRect:intro.bounds toView:self.hostWindow]));
    return intro;
}

- (void)settleIntro:(LessonIntroView *)intro atStep:(NSInteger)step {
    [intro setValue:@(step) forKey:@"step"];
    [intro renderStepAnimated:NO];
}
- (NSArray<UIView *> *)visibleDotsInIntro:(LessonIntroView *)intro {
    NSMutableArray *visible = [NSMutableArray array];
    for (UIView *dot in [intro valueForKey:@"dots"]) if (dot.alpha > 0.5) [visible addObject:dot];
    return visible;
}
- (NSInteger)countInFrame:(NSString *)key intro:(LessonIntroView *)intro {
    UIView *frame = [intro valueForKey:key];
    NSInteger count = 0;
    for (UIView *dot in [self visibleDotsInIntro:intro]) if (CGRectContainsPoint(frame.frame, dot.center)) count++;
    return count;
}
- (NSInteger)crossedCount:(LessonIntroView *)intro {
    NSInteger count = 0;
    for (UIView *dot in [self visibleDotsInIntro:intro]) if ([[dot valueForKey:@"crossedOut"] boolValue]) count++;
    return count;
}
- (void)attachGeometryForIntro:(LessonIntroView *)intro name:(NSString *)name {
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    NSMutableString *trace = [NSMutableString stringWithFormat:
        @"intro=%@ stage=%@ stageFrame=%@ selectedStep=%ld animator=%@\nscroll=%@ contentSize=%@ offset=%@\n",
        NSStringFromCGRect(intro.bounds), NSStringFromCGRect(stage.bounds), NSStringFromCGRect(stage.frame),
        (long)intro.currentStepIndex, [intro valueForKey:@"stepAnimator"], NSStringFromCGRect(scroll.bounds),
        NSStringFromCGSize(scroll.contentSize), NSStringFromCGPoint(scroll.contentOffset)];
    [trace appendFormat:@"ambientCategory=%@ windowCategory=%@ rootCategory=%@ introCategory=%@ animationsEnabled=%d disableActions=%d\n",
        UITraitCollection.currentTraitCollection.preferredContentSizeCategory,
        intro.window.traitCollection.preferredContentSizeCategory,
        intro.window.rootViewController.traitCollection.preferredContentSizeCategory,
        intro.traitCollection.preferredContentSizeCategory, UIView.areAnimationsEnabled, CATransaction.disableActions];
    UILabel *instruction = [intro valueForKey:@"visibilityInstruction"];
    NSLayoutConstraint *spacing = [intro valueForKey:@"scrollBottomSpacing"];
    [trace appendFormat:@"instruction=%@ hidden=%d fitting=%@ reservedBottomSpacing=%.3f footer=%@ insets=%@\n",
        NSStringFromCGRect(instruction.frame), instruction.hidden,
        NSStringFromCGSize([instruction sizeThatFits:CGSizeMake(MAX(1, intro.bounds.size.width - 32), CGFLOAT_MAX)]),
        (double)spacing.constant, NSStringFromCGRect([[intro valueForKey:@"buttonStack"] frame]),
        NSStringFromUIEdgeInsets(scroll.adjustedContentInset)];
    for (NSString *key in @[@"headerLabel", @"progressLabel", @"narration", @"visibilityInstruction"]) {
        UILabel *label = [intro valueForKey:key];
        [trace appendFormat:@"%@ category=%@ font=%.3f lineHeight=%.3f preferredWidth=%.3f frame=%@\n", key,
            label.traitCollection.preferredContentSizeCategory, (double)label.font.pointSize, (double)label.font.lineHeight,
            (double)label.preferredMaxLayoutWidth, NSStringFromCGRect(label.frame)];
    }
    for (NSString *key in @[@"firstFrame", @"secondFrame", @"firstCountLabel", @"secondCountLabel"]) {
        UIView *part = [intro valueForKey:key];
        [trace appendFormat:@"%@=%@ alpha=%.3f\n", key, NSStringFromCGRect(part.frame), (double)part.alpha];
    }
    for (UIView *dot in [intro valueForKey:@"dots"]) {
        [trace appendFormat:@"%@ identity=%p frame=%@ alpha=%.3f crossed=%@ selected=%@\n",
            dot.accessibilityIdentifier, (__bridge void *)dot, NSStringFromCGRect(dot.frame), (double)dot.alpha,
            [dot valueForKey:@"crossedOut"], [dot valueForKey:@"selectedForTen"]];
    }
    if ([intro isKindOfClass:CLRecordingIntroView.class]) {
        CLRecordingIntroView *recording = (CLRecordingIntroView *)intro;
        [trace appendFormat:@"framingCount=%lu\nrendered geometry=%@\n", (unsigned long)recording.framingCount,
            recording.geometrySnapshots];
    }
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:trace];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeDeleteOnSuccess;
    [self addAttachment:attachment];
}
- (void)assertVisibleDotsFitWithoutOverlapping:(LessonIntroView *)intro {
    UIView *stage = [intro valueForKey:@"stage"];
    UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
    NSArray<UIView *> *dots = [self visibleDotsInIntro:intro];
    BOOL attachedGeometry = NO;
    for (NSUInteger index = 0; index < dots.count; index++) {
        CGRect dot = dots[index].frame;
        if (!CGRectContainsRect(CGRectInset(stage.bounds, -0.5, -0.5), dot) && !attachedGeometry) {
            [self attachGeometryForIntro:intro name:@"Counter outside final stage bounds"];
            attachedGeometry = YES;
        }
        XCTAssertTrue(CGRectContainsRect(CGRectInset(stage.bounds, -0.5, -0.5), dot));
        XCTAssertTrue(CGRectContainsRect(first.frame, dot) || CGRectContainsRect(second.frame, dot));
        XCTAssertGreaterThanOrEqual(dot.size.width, 30);
        for (UILabel *label in @[[intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
            if (label.alpha > 0.5) XCTAssertFalse(CGRectIntersectsRect(dot, label.frame));
        }
        for (NSUInteger other = index + 1; other < dots.count; other++) {
            XCTAssertFalse(CGRectIntersectsRect(dot, dots[other].frame));
        }
    }
}
- (void)assertEquationHidden:(LessonIntroView *)intro a:(NSInteger)a b:(NSInteger)b make:(BOOL)make {
    NSString *expected = [NSString stringWithFormat:@"%ld %@ %ld = ?", (long)a, make ? @"+" : @"−", (long)b];
    XCTAssertEqualObjects([[intro valueForKey:@"problemLabel"] text], expected);
}

- (CGRect)counterBoundsInSnapshots:(NSArray<NSArray<NSDictionary *> *> *)snapshots {
    CGRect bounds = CGRectNull;
    for (NSArray<NSDictionary *> *snapshot in snapshots) {
        for (NSDictionary *dot in snapshot) {
            if ([dot[@"alpha"] doubleValue] > 0.01) bounds = CGRectUnion(bounds, [dot[@"frame"] CGRectValue]);
        }
    }
    return bounds;
}

- (void)assertLastTransitionIsFramedBeforeItsTargetIsApplied:(CLRecordingIntroView *)intro {
    XCTAssertGreaterThanOrEqual(intro.snapshots.count, 2u);
    if (intro.snapshots.count < 2) return;
    XCTAssertGreaterThan(intro.framingCount, 0u);
    XCTAssertFalse(intro.animatorExistedAtFraming);
    XCTAssertEqual(intro.snapshotCountAtFraming + 1, intro.snapshots.count);
    NSUInteger source = intro.snapshots.count - 2;
    XCTAssertEqual(intro.renderedSteps[source].integerValue, intro.currentStepIndex - 1);
    XCTAssertEqual(intro.renderedSteps.lastObject.integerValue, intro.currentStepIndex);
    CGRect movement = [self counterBoundsInSnapshots:@[intro.snapshots[source], intro.snapshots.lastObject]];
    // This viewport is recorded inside applyDotStateForStep:, not after the
    // animation or a test-driven scroll. Both endpoints must already fit.
    CGRect viewport = intro.viewportSnapshots.lastObject.CGRectValue;
    XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -0.5, -0.5), movement));
}

/// Independent containment proof: do not trust the admission method or a
/// playback-state string to certify actual window/ancestor geometry.
- (void)assertRequiredActionIsContainedInActualClips:(LessonIntroView *)intro {
    UIView *stage = [intro valueForKey:@"stage"];
    CGRect required = [[intro valueForKey:@"requiredActionBounds"] CGRectValue];
    XCTAssertFalse(CGRectIsNull(required) || CGRectIsEmpty(required));
    XCTAssertNotNil(intro.window);
    CGRect windowScene = [stage convertRect:required toView:intro.window];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(intro.window.bounds, -0.5, -0.5), windowScene));
    for (UIView *ancestor = stage; ancestor; ancestor = ancestor.superview) {
        XCTAssertFalse(ancestor.hidden);
        XCTAssertGreaterThan(ancestor.alpha, 0.01);
        if (ancestor.clipsToBounds) {
            CGRect scene = [stage convertRect:required toView:ancestor];
            XCTAssertTrue(CGRectContainsRect(CGRectInset(ancestor.bounds, -0.5, -0.5), scene),
                @"The complete action %@ is clipped by %@ %@", NSStringFromCGRect(scene), ancestor.class,
                NSStringFromCGRect(ancestor.bounds));
        }
    }
    for (UIView *part in @[[intro valueForKey:@"firstFrame"], [intro valueForKey:@"secondFrame"],
        [intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
        if (part.alpha > 0.01) XCTAssertTrue(CGRectContainsRect(required, part.frame));
    }
    for (UIView *dot in [self visibleDotsInIntro:intro]) XCTAssertTrue(CGRectContainsRect(required, dot.frame));
    CGRect accessible = UIAccessibilityConvertFrameToScreenCoordinates(required, stage);
    XCTAssertTrue(CGRectEqualToRect(stage.accessibilityFrame, accessible));
    XCTAssertTrue([intro isRequiredActionVisible]);
}
- (void)assertVisibilityPausedWithoutObscuringInspection:(LessonIntroView *)intro {
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateVisibilityPaused);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertNil([intro valueForKey:@"visibilityDisplayLink"]);
    XCTAssertEqualObjects([intro valueForKey:@"activeAnimationGeneration"], @0);
    XCTAssertFalse([intro prefersReducedMotion]);
    XCTAssertTrue([[[intro valueForKey:@"progressLabel"] accessibilityValue] containsString:@"點點圖未完整顯示"]);
    [intro layoutIfNeeded];
    UILabel *instruction = [intro valueForKey:@"visibilityInstruction"];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIStackView *footer = [intro valueForKey:@"buttonStack"];
    XCTAssertFalse(instruction.hidden);
    XCTAssertTrue(CGRectContainsRect(intro.bounds, instruction.frame));
    XCTAssertFalse(CGRectIntersectsRect(instruction.frame, scroll.frame));
    XCTAssertFalse(CGRectIntersectsRect(instruction.frame, footer.frame));
    XCTAssertGreaterThanOrEqual(instruction.bounds.size.height + 0.5,
        [instruction sizeThatFits:CGSizeMake(instruction.bounds.size.width, CGFLOAT_MAX)].height);
    XCTAssertGreaterThanOrEqual(instruction.font.pointSize, 18);
    XCTAssertTrue([instruction.text containsString:@"滑動"] && [instruction.text containsString:@"前後步"]);
    XCTAssertFalse([instruction.text containsString:@"轉動"]);
    XCTAssertTrue([[[intro valueForKey:@"replayButton"] accessibilityHint] containsString:@"完整點點圖能顯示時"]);
    XCTAssertGreaterThanOrEqual(scroll.bounds.size.height, 32);
    for (NSString *key in @[@"previousButton", @"nextButton", @"replayButton", @"startButton"]) {
        UIButton *button = [intro valueForKey:key];
        XCTAssertTrue(button.enabled);
        XCTAssertTrue(CGRectContainsRect(intro.bounds, [button.superview convertRect:button.frame toView:intro]));
    }
    for (UIView *dot in [intro valueForKey:@"dots"]) {
        XCTAssertEqualWithAccuracy(dot.bounds.size.width, 32, 0.001);
        XCTAssertEqualWithAccuracy(dot.bounds.size.height, 32, 0.001);
    }
}

- (void)testAllFourFooterControlsFitCompactAndWideLayouts {
    for (NSNumber *width in @[@288, @320, @343, @358, @736]) {
        LessonIntroView *intro = [self showLessonAtIndex:0 width:width.doubleValue height:420];
        NSMutableArray<NSValue *> *frames = [NSMutableArray array];
        for (NSString *key in @[@"previousButton", @"nextButton", @"replayButton", @"startButton"]) {
            UIButton *button = [intro valueForKey:key];
            CGRect rect = [button.superview convertRect:button.frame toView:intro];
            XCTAssertTrue(CGRectContainsRect(intro.bounds, rect));
            XCTAssertGreaterThanOrEqual(rect.size.height, 60);
            XCTAssertGreaterThanOrEqual(rect.size.width, 60);
            for (NSValue *other in frames) XCTAssertFalse(CGRectIntersectsRect(rect, other.CGRectValue));
            [frames addObject:[NSValue valueWithCGRect:rect]];
        }
        UIStackView *footer = [intro valueForKey:@"buttonStack"];
        if (width.doubleValue == 288) XCTAssertEqual(footer.axis, UILayoutConstraintAxisVertical);
        if (width.doubleValue == 736) XCTAssertEqual(footer.axis, UILayoutConstraintAxisHorizontal);
    }
}

- (void)testAllCanonicalIntroStepsStayCountableOnSmallPhoneAndIPad {
    for (NSNumber *width in @[@288, @343, @736]) {
        for (NSUInteger lesson = 0; lesson < 5; lesson++) {
            LessonIntroView *intro = [self showLessonAtIndex:lesson width:width.doubleValue height:420];
            for (NSInteger step = 0; step < intro.numberOfSteps; step++) {
                [self settleIntro:intro atStep:step];
                [self assertVisibleDotsFitWithoutOverlapping:intro];
            }
        }
    }
}

- (void)testAdditionUsesNineActualDotsInsteadOfOverflowingSingleRow {
    LessonIntroView *intro = [self showLessonAtIndex:1 width:288 height:420];
    [self settleIntro:intro atStep:3];
    NSArray<UIView *> *dots = [self visibleDotsInIntro:intro];
    XCTAssertEqual(dots.count, 9u);
    XCTAssertNotEqualWithAccuracy(dots.firstObject.center.y, dots.lastObject.center.y, 1);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testEveryValidMakeTenProblemConservesAllDotsAndUsesTwoTenFrames {
    for (NSNumber *width in @[@288, @736]) {
        for (NSInteger a = 2; a <= 9; a++) {
            for (NSInteger b = 11 - a; b <= 9; b++) {
                @autoreleasepool {
                    LessonIntroView *intro = [self showProblemA:a b:b make:YES width:width.doubleValue];
                    NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
                    XCTAssertEqual(identities.count, (NSUInteger)(a + b));
                    XCTAssertEqualObjects([[intro valueForKey:@"firstFrame"] valueForKey:@"capacity"], @10);
                    XCTAssertEqualObjects([[intro valueForKey:@"secondFrame"] valueForKey:@"capacity"], @10);
                    NSInteger need = 10 - a, rest = b - need;
                    for (NSInteger step = 0; step < intro.numberOfSteps; step++) {
                        [self settleIntro:intro atStep:step];
                        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
                        XCTAssertEqual([self visibleDotsInIntro:intro].count, (NSUInteger)(step == 0 ? a : a + b));
                        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], step < 3 ? a : 10);
                        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], step == 0 ? 0 : step < 3 ? b : rest);
                        XCTAssertEqual([self crossedCount:intro], 0);
                        UIView *firstFrame = [intro valueForKey:@"firstFrame"];
                        for (NSInteger offset = 0; offset < b; offset++) {
                            UIView *dot = identities[a + offset];
                            if (step >= 3) XCTAssertEqual(CGRectContainsPoint(firstFrame.frame, dot.center), offset < need);
                            XCTAssertEqual([[dot valueForKey:@"selectedForTen"] boolValue], step >= 2 && offset < need);
                        }
                        if (step < intro.numberOfSteps - 1) [self assertEquationHidden:intro a:a b:b make:YES];
                        else {
                            NSString *sum = [NSString stringWithFormat:@"10 + %ld = %ld", (long)rest, (long)(a + b)];
                            XCTAssertTrue([intro.currentNarration containsString:sum]);
                        }
                        [self assertVisibleDotsFitWithoutOverlapping:intro];
                    }
                }
            }
        }
    }
}

/// Evaluate the exact production keyframe schedule, including each hold and
/// each leg, rather than interpolating only the two settled snapshots.
- (NSArray<NSValue *> *)centersForLegs:(NSArray *)legs atTime:(NSTimeInterval)time source:(NSArray<NSValue *> *)source {
    NSMutableArray<NSValue *> *centers = [source mutableCopy];
    for (id leg in legs) {
        NSTimeInterval start = [[leg valueForKey:@"startTime"] doubleValue];
        if (time < start) continue;
        NSTimeInterval duration = [[leg valueForKey:@"duration"] doubleValue];
        CGPoint from = [[leg valueForKey:@"fromCenter"] CGPointValue];
        CGPoint to = [[leg valueForKey:@"toCenter"] CGPointValue];
        CGFloat fraction = MIN(1, (time - start) / duration);
        centers[[[leg valueForKey:@"dotIndex"] unsignedIntegerValue]] = [NSValue valueWithCGPoint:fraction >= 1 ? to :
            CGPointMake(from.x + (to.x - from.x) * fraction, from.y + (to.y - from.y) * fraction)];
    }
    return centers;
}

- (void)assertTransferCenters:(NSArray<NSValue *> *)centers fitIntro:(LessonIntroView *)intro {
    UIView *stage = [intro valueForKey:@"stage"];
    for (NSUInteger index = 0; index < centers.count; index++) {
        CGPoint point = centers[index].CGPointValue;
        CGRect counter = CGRectMake(point.x - 16, point.y - 16, 32, 32);
        XCTAssertTrue(CGRectContainsRect(CGRectInset(stage.bounds, -0.01, -0.01), counter));
        for (UILabel *label in @[[intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
            XCTAssertFalse(CGRectIntersectsRect(counter, label.frame));
        }
        for (NSUInteger other = index + 1; other < centers.count; other++) {
            CGPoint otherPoint = centers[other].CGPointValue;
            XCTAssertFalse(CGRectIntersectsRect(counter, CGRectMake(otherPoint.x - 16, otherPoint.y - 16, 32, 32)));
        }
    }
}

- (void)testAllMakeTenTransferLegsKeepEveryUnitCountableAndUntouchedUnitsFixed {
    for (NSNumber *width in @[@288, @320, @359, @543, @544, @736]) {
        NSInteger cases = 0;
        for (NSInteger a = 2; a <= 9; a++) {
            for (NSInteger b = 11 - a; b <= 9; b++) {
                @autoreleasepool {
                    cases++;
                    LessonIntroView *intro = [self showProblemA:a b:b make:YES width:width.doubleValue];
                    [self settleIntro:intro atStep:2];
                    NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
                    NSArray<NSValue *> *source = [identities valueForKey:@"center"];
                    NSArray *legs = [intro makeTenTransferLegs];
                    XCTAssertGreaterThan(legs.count, 0u);
                    NSTimeInterval previousEnd = 0;
                    NSInteger previousIndex = a - 1;
                    CGPoint previousPoint = CGPointZero;
                    NSMutableSet *moved = [NSMutableSet set];
                    for (id leg in legs) {
                        NSInteger index = [[leg valueForKey:@"dotIndex"] integerValue];
                        NSTimeInterval start = [[leg valueForKey:@"startTime"] doubleValue];
                        NSTimeInterval duration = [[leg valueForKey:@"duration"] doubleValue];
                        CGPoint from = [[leg valueForKey:@"fromCenter"] CGPointValue];
                        CGPoint to = [[leg valueForKey:@"toCenter"] CGPointValue];
                        XCTAssertGreaterThan(duration, 0);
                        XCTAssertGreaterThanOrEqual(start + 0.000001, previousEnd);
                        XCTAssertTrue(index == previousIndex || index == previousIndex + 1);
                        XCTAssertGreaterThanOrEqual(index, a);
                        XCTAssertLessThan(index, 10);
                        if (index == previousIndex) XCTAssertTrue(CGPointEqualToPoint(from, previousPoint));
                        else {
                            XCTAssertGreaterThanOrEqual(start - previousEnd + 0.000001, 0.12);
                            XCTAssertTrue(CGPointEqualToPoint(from, source[index].CGPointValue));
                        }
                        // Every turn, midpoint, and intervening eighth is probed.
                        // At most this one counter can be between its endpoints.
                        for (NSUInteger sample = 0; sample <= 8; sample++) {
                            NSArray<NSValue *> *centers = [self centersForLegs:legs atTime:start + duration * sample / 8.0 source:source];
                            [self assertTransferCenters:centers fitIntro:intro];
                            for (NSInteger untouched = 0; untouched < a + b; untouched++) {
                                if (untouched < a || untouched >= 10) XCTAssertEqualObjects(centers[untouched], source[untouched]);
                            }
                        }
                        [moved addObject:@(index)];
                        previousEnd = start + duration; previousIndex = index; previousPoint = to;
                    }
                    XCTAssertEqual(moved.count, (NSUInteger)(10 - a));
                    NSTimeInterval duration = [intro makeTenTransferDuration];
                    XCTAssertGreaterThanOrEqual(duration - previousEnd + 0.000001, 0.12);
                    XCTAssertLessThanOrEqual(duration, 6.68 + 0.000001);
                    NSArray<NSValue *> *target = [self centersForLegs:legs atTime:duration source:source];
                    for (NSInteger step = 3; step <= 4; step++) {
                        [self settleIntro:intro atStep:step];
                        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
                        XCTAssertEqualObjects([identities valueForKey:@"center"], target);
                        for (NSInteger index = 0; index < a + b; index++) {
                            XCTAssertEqualWithAccuracy(identities[index].alpha, 1, 0.001);
                            XCTAssertEqualWithAccuracy(identities[index].bounds.size.width, 32, 0.001);
                            if (index < a || index >= 10) XCTAssertEqualObjects([NSValue valueWithCGPoint:identities[index].center], source[index]);
                        }
                    }
                }
            }
        }
        XCTAssertEqual(cases, 36);
    }
}

- (void)testTransferFramingContainsTheActualCorridorBeforeAnimationStarts {
    for (NSNumber *width in @[@288, @544, @736]) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
            lesson:[self lessonAtIndex:3]];
        [self hostIntro:intro width:width.doubleValue height:500];
        [self settleIntro:intro atStep:2];
        [intro goToNextStep];
        [self assertLastTransitionIsFramedBeforeItsTargetIsApplied:intro];
        CGRect path = [intro makeTenTransferBounds:[intro makeTenTransferLegs]];
        XCTAssertTrue(CGRectContainsRect(intro.viewportSnapshots.lastObject.CGRectValue, path));
        XCTAssertFalse(intro.animatorExistedAtFraming);
        [self assertRequiredActionIsContainedInActualClips:intro];
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)attachPresentationForIntro:(LessonIntroView *)intro expected:(NSArray<NSValue *> *)centers context:(NSString *)context {
    [self attachGeometryForIntro:intro name:[context stringByAppendingString:@" geometry"]];
    UIWindow *window = intro.window;
    UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
    NSMutableString *trace = [NSMutableString stringWithFormat:
        @"%@\napplicationState=%ld screen=%@ scene=%@ activation=%ld sceneBounds=%@\n"
        @"window=%@ key=%d hidden=%d windowBounds=%@ windowPresentation=%@\n"
        @"playbackState=%ld generation=%lu activeGeneration=%@ animator=%@ state=%ld running=%d fraction=%.6f\n"
        @"animationsEnabled=%d disableActions=%d\n",
        context, (long)UIApplication.sharedApplication.applicationState, NSStringFromCGRect(UIScreen.mainScreen.bounds),
        window.windowScene, (long)window.windowScene.activationState, NSStringFromCGRect(window.windowScene.coordinateSpace.bounds),
        window, window.isKeyWindow, window.hidden, NSStringFromCGRect(window.bounds), window.layer.presentationLayer,
        (long)intro.playbackState, (unsigned long)intro.playbackGeneration, [intro valueForKey:@"activeAnimationGeneration"],
        animator, (long)animator.state, animator.isRunning, (double)animator.fractionComplete,
        UIView.areAnimationsEnabled, CATransaction.disableActions];
    for (UIView *ancestor = [intro valueForKey:@"stage"]; ancestor; ancestor = ancestor.superview) {
        [trace appendFormat:@"ancestor=%@ frame=%@ bounds=%@ clips=%d hidden=%d alpha=%.3f presentation=%@\n",
            ancestor.class, NSStringFromCGRect(ancestor.frame), NSStringFromCGRect(ancestor.bounds),
            ancestor.clipsToBounds, ancestor.hidden, (double)ancestor.alpha, ancestor.layer.presentationLayer];
    }
    NSArray<UIView *> *dots = [intro valueForKey:@"dots"];
    [trace appendFormat:@"expectedCount=%lu actualCount=%lu\n", (unsigned long)centers.count, (unsigned long)dots.count];
    for (NSUInteger index = 0; index < dots.count; index++) {
        UIView *dot = dots[index];
        CALayer *presentation = dot.layer.presentationLayer;
        NSString *expected = index < centers.count ? NSStringFromCGPoint(centers[index].CGPointValue) : @"<no expected center>";
        [trace appendFormat:@"%@ identity=%p expected=%@ model=%@ presentation=%@ position=%@ bounds=%@ opacity=%.3f animations=%@\n",
            dot.accessibilityIdentifier, (__bridge void *)dot, expected,
            NSStringFromCGPoint(dot.layer.position), presentation, NSStringFromCGPoint(presentation.position),
            NSStringFromCGRect(presentation.bounds), (double)presentation.opacity, dot.layer.animationKeys];
    }
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:trace];
    attachment.name = context;
    attachment.lifetime = XCTAttachmentLifetimeDeleteOnSuccess;
    [self addAttachment:attachment];
}

- (BOOL)assertCommittedPresentationForDots:(NSArray<UIView *> *)dots centers:(NSArray<NSValue *> *)centers
    intro:(LessonIntroView *)intro context:(NSString *)context {
    XCTAssertGreaterThan(dots.count, 0u);
    XCTAssertEqual(dots.count, centers.count);
    if (dots.count == 0 || dots.count != centers.count) return NO;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
    BOOL matched = NO;
    do {
        [CATransaction flush];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        matched = YES;
        for (NSUInteger index = 0; index < dots.count; index++) {
            CALayer *presentation = dots[index].layer.presentationLayer;
            CGPoint expected = centers[index].CGPointValue;
            if (!presentation || fabs(presentation.position.x - expected.x) > 1
                || fabs(presentation.position.y - expected.y) > 1 || fabs(presentation.opacity - 1) > 0.001) {
                matched = NO;
                break;
            }
        }
    } while (!matched && deadline.timeIntervalSinceNow > 0);
    if (!matched) [self attachPresentationForIntro:intro expected:centers context:context];
    XCTAssertTrue(matched, @"%@: the native presentation, not merely the model, must reach the specified pose.", context);
    // A missing presentation is a failed case, not a zero-position counter.
    // Stop this case at its first failed boundary rather than manufacturing
    // thousands of overlap/opacity reports from Objective-C messages to nil.
    if (!matched) return NO;
    for (NSUInteger index = 0; index < dots.count; index++) {
        CALayer *presentation = dots[index].layer.presentationLayer;
        XCTAssertNotNil(presentation);
        XCTAssertEqualWithAccuracy(presentation.opacity, 1, 0.001);
        XCTAssertEqualWithAccuracy(presentation.position.x, centers[index].CGPointValue.x, 1);
        XCTAssertEqualWithAccuracy(presentation.position.y, centers[index].CGPointValue.y, 1);
        XCTAssertEqualWithAccuracy(presentation.bounds.size.width, 32, 0.001);
        XCTAssertEqualWithAccuracy(presentation.bounds.size.height, 32, 0.001);
        XCTAssertTrue(CATransform3DIsIdentity(presentation.transform));
        XCTAssertEqualWithAccuracy(presentation.anchorPoint.x, 0.5, 0.001);
        XCTAssertEqualWithAccuracy(presentation.anchorPoint.y, 0.5, 0.001);
        XCTAssertEqualWithAccuracy(presentation.frame.size.width, 32, 0.001);
        XCTAssertEqualWithAccuracy(presentation.frame.size.height, 32, 0.001);
    }
    return YES;
}

- (void)testNativePausedTransferPresentationMatchesEachLegMidpointWithoutLosingAUnit {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"The moving-presentation probe needs Reduce Motion off; endpoint coverage is separate.");
    for (NSNumber *width in @[@288, @544, @736]) {
        for (NSNumber *aValue in @[@2, @9]) {
            NSInteger a = aValue.integerValue;
            LessonIntroView *intro = [self showPresentationProblemA:a width:width.doubleValue];
            if (!intro) return; // The host precondition already failed.
            [self settleIntro:intro atStep:2];
            NSArray<UIView *> *dots = [[intro valueForKey:@"dots"] copy];
            XCTAssertEqual(dots.count, (NSUInteger)(a + 9));
            NSArray<NSValue *> *source = [dots valueForKey:@"center"];
            NSString *fixture = [NSString stringWithFormat:@"%ld + 9 at width %@", (long)a, width];
            // Prove the real render tree exists BEFORE the production animator
            // is constructed. This does not help Replay: that still begins
            // immediately from the separately committed destination below.
            if (![self assertCommittedPresentationForDots:dots centers:source intro:intro
                context:[fixture stringByAppendingString:@" initial source"]]) return;
            NSArray *legs = [intro makeTenTransferLegs];
            for (NSString *playback in @[@"first play", @"Replay", @"Back then Next"]) {
                if ([playback isEqualToString:@"Replay"]) [intro replayCurrentStep];
                else {
                    if ([playback isEqualToString:@"Back then Next"]) [intro goToPreviousStep];
                    [intro goToNextStep];
                }
                UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
                XCTAssertNotNil(animator, @"%@ at width %@", playback, width);
                if (!animator) {
                    [self attachPresentationForIntro:intro expected:source context:[fixture stringByAppendingString:playback]];
                    return;
                }
                XCTAssertEqual(animator.state, UIViewAnimatingStateActive);
                XCTAssertTrue(animator.isRunning);
                // UIKit forbids changing the scrubbing policy after pausing.
                // Configure it while running, then probe the real paused timeline.
                animator.scrubsLinearly = YES;
                [animator pauseAnimation];
                XCTAssertEqual(animator.state, UIViewAnimatingStateActive);
                XCTAssertFalse(animator.isRunning);
                // Probe the actual zero pose as well as every routed leg. For
                // Replay this must replace a previously COMMITTED destination.
                // Waiting dots may not remain in destination cells until their
                // turn, even though model endpoint counts/identities look right.
                NSMutableArray<NSNumber *> *times = [NSMutableArray arrayWithObject:@0];
                for (id leg in legs) {
                    NSTimeInterval time = [[leg valueForKey:@"startTime"] doubleValue]
                        + [[leg valueForKey:@"duration"] doubleValue] / 2;
                    [times addObject:@(time)];
                }
                for (NSNumber *sample in times) {
                    NSTimeInterval time = sample.doubleValue;
                    [self assertRequiredActionIsContainedInActualClips:intro];
                    animator.fractionComplete = time / [intro makeTenTransferDuration];
                    NSArray<NSValue *> *expected = [self centersForLegs:legs atTime:time source:source];
                    NSString *context = [NSString stringWithFormat:@"%@ %@ time %.6f / %.6f", fixture, playback,
                        time, [intro makeTenTransferDuration]];
                    if (![self assertCommittedPresentationForDots:dots centers:expected intro:intro context:context]) return;
                    XCTAssertEqualObjects([intro valueForKey:@"dots"], dots);
                    XCTAssertEqualObjects([intro valueForKey:@"stepAnimator"], animator);
                    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
                    NSMutableArray<NSValue *> *actual = [NSMutableArray array];
                    for (NSUInteger index = 0; index < dots.count; index++) {
                        CALayer *presentation = dots[index].layer.presentationLayer;
                        [actual addObject:[NSValue valueWithCGPoint:presentation.position]];
                    }
                    // Independently checks every 32-point disk, text clearance,
                    // source waiting positions, arrived targets and stationary
                    // original remainder. Wrong future targets cause collisions.
                    [self assertTransferCenters:actual fitIntro:intro];
                    [self assertRequiredActionIsContainedInActualClips:intro];
                    XCTAssertEqual(intro.currentStepIndex, 3);
                    [self assertEquationHidden:intro a:a b:9 make:YES];
                }
                [intro stopPlayback];
                XCTAssertNil([intro valueForKey:@"stepAnimator"]);
                XCTAssertEqualObjects([intro valueForKey:@"dots"], dots);
                XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
                XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], a - 1);
                // Do not let same-transaction model setup accidentally make the
                // next Replay test easier than pressing Replay on a real result.
                if (![self assertCommittedPresentationForDots:dots centers:[dots valueForKey:@"center"] intro:intro
                    context:[NSString stringWithFormat:@"%@ %@ committed destination", fixture, playback]]) return;
            }
        }
    }
}

- (void)testResizeDuringAStagedTransferSettlesTheSelectedStepInTheNewGeometry {
    LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:736];
    [self settleIntro:intro atStep:3];
    for (NSValue *size in @[[NSValue valueWithCGSize:CGSizeMake(736, 420)], [NSValue valueWithCGSize:CGSizeMake(288, 420)]]) {
        [intro replayCurrentStep];
        intro.frame = (CGRect){CGPointZero, size.CGSizeValue};
        [intro setNeedsLayout]; [intro layoutIfNeeded];
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqual(intro.currentStepIndex, 3);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
        [self assertVisibleDotsFitWithoutOverlapping:intro];
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testNativeTransferCompletionBelongsToItsGenerationNotSynchronousTargetCounts {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"Natural motion completion is distinct from the reduced-motion endpoint.");
    for (NSNumber *aValue in @[@2, @9]) {
        NSInteger a = aValue.integerValue;
        LessonIntroView *intro = [self showPresentationProblemA:a width:736];
        if (!intro) return;
        [self settleIntro:intro atStep:2];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateIdle);
        NSUInteger before = intro.playbackGeneration;
        NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
        if (![self assertCommittedPresentationForDots:identities centers:[identities valueForKey:@"center"] intro:intro
            context:[NSString stringWithFormat:@"%ld + 9 natural completion source", (long)a]]) return;
        CFTimeInterval requestedAt = CACurrentMediaTime();
        [intro goToNextStep];
        NSUInteger generation = intro.playbackGeneration;
        XCTAssertEqual(generation, before + 1);
        XCTAssertEqual(intro.playbackStepIndex, 3);
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        UIViewPropertyAnimator *nativeAnimator = [intro valueForKey:@"stepAnimator"];
        XCTAssertNotNil(nativeAnimator);
        __block CFTimeInterval completedAt = 0;
        [nativeAnimator addCompletion:^(UIViewAnimatingPosition position) {
            completedAt = CACurrentMediaTime();
        }];
        [self assertRequiredActionIsContainedInActualClips:intro];
        // These are already endpoint quantities. They alone must not pass a
        // completion gate while the actual presentation is still in transit.
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], a - 1);
        XCTAssertTrue([[[intro valueForKey:@"stage"] accessibilityValue] hasPrefix:@"這一步完成後："]);
        XCTAssertTrue([[[intro valueForKey:@"progressLabel"] accessibilityValue] containsString:@"動態播放中"]);
        NSPredicate *naturallyCompleted = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
            LessonIntroView *view = object;
            return view.playbackGeneration == generation && view.playbackStepIndex == 3 && view.currentStepIndex == 3
                && view.playbackState == LessonIntroPlaybackStateCompleted;
        }];
        XCTNSPredicateExpectation *completed = [[XCTNSPredicateExpectation alloc] initWithPredicate:naturallyCompleted object:intro];
        [self waitForExpectations:@[completed] timeout:8];
        XCTAssertGreaterThan(completedAt, 0);
        XCTAssertGreaterThanOrEqual(completedAt - requestedAt + 1.0 / 60.0, [intro makeTenTransferDuration],
            @"Use the actual callback time, not later predicate polling, to verify the finite native timeline.");
        if (![self assertCommittedPresentationForDots:identities centers:[identities valueForKey:@"center"] intro:intro
            context:[NSString stringWithFormat:@"%ld + 9 natural completion destination", (long)a]]) return;
        [self assertRequiredActionIsContainedInActualClips:intro];
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqualObjects([intro valueForKey:@"activeAnimationGeneration"], @0);
        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
        XCTAssertEqualObjects([[intro valueForKey:@"progressLabel"] accessibilityValue],
            ([NSString stringWithFormat:@"第 %lu 次播放，第 4 小步，動態播放完成", (unsigned long)generation]));
        XCTAssertFalse([[[intro valueForKey:@"stage"] accessibilityValue] hasPrefix:@"這一步完成後："]);
        [self assertVisibleDotsFitWithoutOverlapping:intro];
        [self assertEquationHidden:intro a:a b:9 make:YES];
        [intro stopPlayback];
        // A later static render must not erase an actual, already observed end.
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCompleted);
        [intro goToPreviousStep];
        XCTAssertEqual(intro.currentStepIndex, 2);
        XCTAssertEqual(intro.playbackStepIndex, 3);
        NSString *backStatus = [[intro valueForKey:@"progressLabel"] accessibilityValue];
        XCTAssertTrue([backStatus containsString:@"先前第 4 小步（動態播放完成）"]);
        XCTAssertTrue([backStatus containsString:@"目前第 3 小步是靜止圖示"]);
        XCTAssertFalse([backStatus containsString:@"第 3 小步，動態播放完成"]);
        [self assertEquationHidden:intro a:a b:9 make:YES];
    }
}

- (void)testLateWrongAnimatorGenerationOrSelectedStepCannotCertifyCompletion {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression needs an active native animator.");
    LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:736];
    [self settleIntro:intro atStep:3];
    [intro replayCurrentStep];
    UIViewPropertyAnimator *oldAnimator = [intro valueForKey:@"stepAnimator"];
    NSUInteger oldGeneration = intro.playbackGeneration;
    [intro stopPlayback];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled);
    [intro completeStepAnimation:oldAnimator generation:oldGeneration step:3 position:UIViewAnimatingPositionEnd];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled);
    [intro replayCurrentStep];
    UIViewPropertyAnimator *currentAnimator = [intro valueForKey:@"stepAnimator"];
    NSUInteger generation = intro.playbackGeneration;
    XCTAssertEqual(generation, oldGeneration + 1);
    XCTAssertNotEqual(currentAnimator, oldAnimator);
    [intro completeStepAnimation:oldAnimator generation:generation step:3 position:UIViewAnimatingPositionEnd];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
    [intro completeStepAnimation:currentAnimator generation:oldGeneration step:3 position:UIViewAnimatingPositionEnd];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
    [intro completeStepAnimation:currentAnimator generation:generation step:2 position:UIViewAnimatingPositionEnd];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
    [intro setValue:@4 forKey:@"step"];
    [intro completeStepAnimation:currentAnimator generation:generation step:3 position:UIViewAnimatingPositionEnd];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
    XCTAssertEqualObjects([intro valueForKey:@"stepAnimator"], currentAnimator);
    [intro setValue:@3 forKey:@"step"];
    [intro stopPlayback];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}

- (void)testBackReplayAndNextInvalidateAnOlderRunningGeneration {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression needs active native animators.");
    for (NSString *action in @[@"back", @"replay", @"next"]) {
        LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:736];
        [self settleIntro:intro atStep:3];
        [intro replayCurrentStep];
        UIViewPropertyAnimator *oldAnimator = [intro valueForKey:@"stepAnimator"];
        NSUInteger oldGeneration = intro.playbackGeneration;
        if ([action isEqualToString:@"back"]) [intro goToPreviousStep];
        else if ([action isEqualToString:@"replay"]) [intro replayCurrentStep];
        else [intro goToNextStep];
        BOOL back = [action isEqualToString:@"back"];
        NSInteger selectedStep = back ? 2 : [action isEqualToString:@"next"] ? 4 : 3;
        LessonIntroPlaybackState expected = back ? LessonIntroPlaybackStateCancelled : LessonIntroPlaybackStateRunning;
        XCTAssertEqual(intro.currentStepIndex, selectedStep);
        XCTAssertEqual(intro.playbackState, expected);
        XCTAssertEqual(intro.playbackGeneration, oldGeneration + (back ? 0 : 1));
        XCTAssertNotEqual([intro valueForKey:@"stepAnimator"], oldAnimator);
        [intro completeStepAnimation:oldAnimator generation:oldGeneration step:3 position:UIViewAnimatingPositionEnd];
        XCTAssertEqual(intro.playbackState, expected);
        XCTAssertEqual(intro.currentStepIndex, selectedStep);
        if (selectedStep < 4) [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testLifecycleInterruptionInvalidatesTheRunningGenerationWithoutNaturalCompletion {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression needs active native animators.");
    for (NSString *action in @[@"stop", @"background", @"motion", @"hidden", @"alpha", @"detach", @"height", @"width"]) {
        LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:736];
        intro.autoresizingMask = UIViewAutoresizingNone;
        [self settleIntro:intro atStep:3];
        [intro replayCurrentStep];
        UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
        NSUInteger generation = intro.playbackGeneration;
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        if ([action isEqualToString:@"background"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        } else if ([action isEqualToString:@"motion"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        } else if ([action isEqualToString:@"hidden"]) intro.hidden = YES;
        else if ([action isEqualToString:@"alpha"]) intro.alpha = 0;
        else if ([action isEqualToString:@"detach"]) [intro removeFromSuperview];
        else if ([action isEqualToString:@"height"] || [action isEqualToString:@"width"]) {
            intro.frame = CGRectMake(0, 0, [action isEqualToString:@"width"] ? 288 : 736, 420);
            [intro setNeedsLayout]; [intro layoutIfNeeded];
        } else [intro stopPlayback];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled, @"%@", action);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqualObjects([intro valueForKey:@"activeAnimationGeneration"], @0);
        XCTAssertEqual(intro.playbackGeneration, generation);
        XCTAssertEqual(intro.playbackStepIndex, 3);
        XCTAssertEqual(intro.currentStepIndex, 3);
        [intro completeStepAnimation:animator generation:generation step:3 position:UIViewAnimatingPositionEnd];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled);
        XCTAssertTrue([[[intro valueForKey:@"progressLabel"] accessibilityValue] containsString:@"動態已停止"]);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testFinishingAtStartOrCurrentSettlesWithoutClaimingNaturalCompletion {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression needs active native animators.");
    for (NSNumber *position in @[@(UIViewAnimatingPositionStart), @(UIViewAnimatingPositionCurrent)]) {
        LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:736];
        [self settleIntro:intro atStep:3];
        [intro replayCurrentStep];
        UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
        [animator pauseAnimation];
        animator.fractionComplete = 0.2;
        [animator stopAnimation:NO];
        [animator finishAnimationAtPosition:position.integerValue];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqual(intro.currentStepIndex, 3);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testReducedMotionHasItsOwnGenerationAndNeverClaimsNaturalCompletion {
    CLReducedMotionIntroView *intro = [[CLReducedMotionIntroView alloc] initWithProblem:[self problemA:9 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    intro.forceReducedMotion = YES;
    [self hostIntro:intro width:736 height:500];
    [self settleIntro:intro atStep:2];
    [intro goToNextStep];
    NSUInteger generation = intro.playbackGeneration;
    XCTAssertGreaterThan(generation, 0u);
    XCTAssertEqual(intro.playbackStepIndex, 3);
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateReducedMotion);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqualObjects([intro valueForKey:@"activeAnimationGeneration"], @0);
    XCTAssertTrue([[[intro valueForKey:@"progressLabel"] accessibilityValue] containsString:@"減少動態，直接顯示這一步"]);
    XCTAssertFalse([[[intro valueForKey:@"stage"] accessibilityValue] hasPrefix:@"這一步完成後："]);
    [intro replayCurrentStep];
    XCTAssertEqual(intro.playbackGeneration, generation + 1);
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateReducedMotion);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [self assertEquationHidden:intro a:9 b:9 make:YES];
}

- (void)testPreLayoutPlaybackRequestsAreCancelledWithoutLosingTheirIdentity {
    LessonIntroView *intro = [[LessonIntroView alloc] initWithProblem:[self problemA:9 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateIdle);
    XCTAssertEqual(intro.playbackGeneration, 0u);
    [intro replayCurrentStep];
    XCTAssertEqual(intro.playbackGeneration, 1u);
    XCTAssertEqual(intro.playbackStepIndex, 0);
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    [intro goToNextStep];
    XCTAssertEqual(intro.playbackGeneration, 2u);
    XCTAssertEqual(intro.playbackStepIndex, 1);
    XCTAssertEqual(intro.currentStepIndex, 1);
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateCancelled);
    XCTAssertTrue([[[intro valueForKey:@"progressLabel"] accessibilityValue] containsString:@"第 2 次播放，第 2 小步，動態已停止"]);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    [self assertEquationHidden:intro a:9 b:9 make:YES];
}

- (void)testEnablingReducedMotionDuringPlaybackInvalidatesTheOldAnimator {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression begins with native motion enabled.");
    CLReducedMotionIntroView *intro = [[CLReducedMotionIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:736 height:500];
    [self settleIntro:intro atStep:3];
    [intro replayCurrentStep];
    UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
    NSUInteger generation = intro.playbackGeneration;
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
    intro.forceReducedMotion = YES;
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateReducedMotion);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    [intro completeStepAnimation:animator generation:generation step:3 position:UIViewAnimatingPositionEnd];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateReducedMotion);
    intro.forceReducedMotion = NO;
    [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    XCTAssertNil([intro valueForKey:@"stepAnimator"], @"Changing a preference never automatically replays or advances.");
    XCTAssertEqual(intro.playbackGeneration, generation);
    XCTAssertEqual(intro.currentStepIndex, 3);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}

- (void)testEveryValidBreakTenProblemRemovesOnlyCrossedDotsAndKeepsOriginalOnes {
    for (NSNumber *width in @[@288, @736]) {
        for (NSInteger a = 11; a <= 18; a++) {
            for (NSInteger b = a % 10 + 1; b <= 9; b++) {
                @autoreleasepool {
                    LessonIntroView *intro = [self showProblemA:a b:b make:NO width:width.doubleValue];
                    NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
                    NSMutableArray<NSValue *> *onesPositions = [NSMutableArray array];
                    for (NSInteger i = 10; i < a; i++) [onesPositions addObject:[NSValue valueWithCGPoint:identities[i].center]];
                    XCTAssertEqualObjects([[intro valueForKey:@"secondFrame"] valueForKey:@"capacity"], @10);
                    for (NSInteger step = 0; step < intro.numberOfSteps; step++) {
                        [self settleIntro:intro atStep:step];
                        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
                        XCTAssertEqual([self visibleDotsInIntro:intro].count, (NSUInteger)(step < 2 ? a : a - b));
                        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], step < 2 ? 10 : 10 - b);
                        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], a % 10);
                        XCTAssertEqual([self crossedCount:intro], step == 1 ? b : 0);
                        for (NSInteger i = 0; i < a; i++) {
                            UIView *dot = identities[i];
                            if (i >= 10) {
                                XCTAssertEqualWithAccuracy(dot.alpha, 1, 0.001);
                                XCTAssertTrue(CGPointEqualToPoint(dot.center, onesPositions[i - 10].CGPointValue));
                                XCTAssertFalse([[dot valueForKey:@"crossedOut"] boolValue]);
                            } else {
                                BOOL removed = step >= 2 && i >= 10 - b;
                                XCTAssertEqualWithAccuracy(dot.alpha, removed ? 0 : 1, 0.001);
                            }
                        }
                        if (step < intro.numberOfSteps - 1) [self assertEquationHidden:intro a:a b:b make:NO];
                        else {
                            NSString *sum = [NSString stringWithFormat:@"%ld + %ld = %ld", (long)(10 - b), (long)(a % 10), (long)(a - b)];
                            XCTAssertTrue([intro.currentNarration containsString:sum]);
                        }
                        [self assertVisibleDotsFitWithoutOverlapping:intro];
                    }
                }
            }
        }
    }
}

- (void)testCanonicalStrategiesKeepTheFamiliarEightPlusFiveAndTwelveMinusFive {
    LessonIntroView *make = [self showLessonAtIndex:3 width:288 height:420];
    [self assertEquationHidden:make a:8 b:5 make:YES];
    [self settleIntro:make atStep:3];
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:make], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:make], 3);
    XCTAssertTrue([make.currentNarration containsString:@"8 + 2"]);
    LessonIntroView *subtract = [self showLessonAtIndex:4 width:288 height:420];
    [self assertEquationHidden:subtract a:12 b:5 make:NO];
    [self settleIntro:subtract atStep:3];
    XCTAssertEqual([self visibleDotsInIntro:subtract].count, 7u);
}

- (void)testExplicitProblemIsAValidatedValueSnapshot {
    ArithmeticProblem *problem = [self problemA:2 b:9 make:YES];
    LessonIntroView *intro = [[LessonIntroView alloc] initWithProblem:problem lesson:[self lessonAtIndex:3]];
    problem.number1 = 99; problem.number2 = 70; problem.answer = 0;
    problem.operatorSymbol = @"×"; problem.isMultiStep = YES;
    [self hostIntro:intro width:288 height:500];
    [self assertEquationHidden:intro a:2 b:9 make:YES];
    [self settleIntro:intro atStep:3];
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 11u);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
}

- (void)testInvalidExplicitInputsAreRejectedInsteadOfShowingCanonicalExamples {
    NSArray<NSArray *> *invalid = @[
        @[@2, @8, @"+", @10, @3], @[@1, @9, @"+", @10, @3], @[@10, @1, @"+", @11, @3],
        @[@9, @10, @"+", @19, @3], @[@8, @5, @"-", @3, @3], @[@8, @5, @"−", @3, @3],
        @[@8, @5, @"×", @40, @3], @[@8, @5, @"+", @12, @3], @[@8, @5, @"+", @13, @0],
        @[@10, @5, @"-", @5, @4], @[@19, @9, @"-", @10, @4], @[@18, @8, @"-", @10, @4],
        @[@11, @0, @"-", @11, @4], @[@11, @10, @"-", @1, @4], @[@12, @5, @"+", @17, @4],
        @[@12, @5, @"-", @8, @4], @[@12, @5, @"–", @7, @4], @[@(-1), @9, @"+", @8, @3],
        @[@(NSIntegerMax), @9, @"+", @0, @3], @[@(NSIntegerMin), @9, @"-", @0, @4]
    ];
    for (NSArray *row in invalid) {
        ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:[row[0] integerValue]
            number2:[row[1] integerValue] operator:row[2] answer:[row[3] integerValue]];
        Lesson *lesson = [self lessonAtIndex:[row[4] unsignedIntegerValue]];
        XCTAssertFalse([LessonIntroView supportsProblem:problem lesson:lesson]);
        LessonIntroView *intro = [[LessonIntroView alloc] initWithProblem:problem lesson:lesson];
        XCTAssertNil(intro);
    }
    ArithmeticProblem *multi = [self problemA:8 b:5 make:YES];
    multi.isMultiStep = YES;
    XCTAssertNil([[LessonIntroView alloc] initWithProblem:multi lesson:[self lessonAtIndex:3]]);
    ArithmeticProblem *unicodeMinus = [self problemA:11 b:9 make:NO];
    unicodeMinus.operatorSymbol = @"−";
    XCTAssertNotNil([[LessonIntroView alloc] initWithProblem:unicodeMinus lesson:[self lessonAtIndex:4]]);
}

- (void)testBackRestoresTransferredAndCrossedOutStatesWithoutRevealingTheAnswer {
    LessonIntroView *make = [self showProblemA:2 b:9 make:YES width:288];
    [self settleIntro:make atStep:4];
    [make goToPreviousStep];
    [self assertEquationHidden:make a:2 b:9 make:YES];
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:make], 10);
    [make goToPreviousStep];
    XCTAssertEqual(make.currentStepIndex, 2);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:make], 2);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:make], 9);
    LessonIntroView *subtract = [self showProblemA:18 b:9 make:NO width:288];
    [self settleIntro:subtract atStep:2];
    [subtract goToPreviousStep];
    XCTAssertEqual([self visibleDotsInIntro:subtract].count, 18u);
    XCTAssertEqual([self crossedCount:subtract], 9);
    [subtract goToPreviousStep];
    [subtract goToPreviousStep];
    XCTAssertEqual(subtract.currentStepIndex, 0);
    XCTAssertEqual([self crossedCount:subtract], 0);
    [self assertEquationHidden:subtract a:18 b:9 make:NO];
}

- (void)testReplayReconstructsTheSelectedStepsOwnBeforeStateAndPreservesDotIdentity {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:288 height:500];
    [self settleIntro:intro atStep:3];
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    [intro.renderedSteps removeAllObjects]; [intro.snapshots removeAllObjects]; [intro.viewportSnapshots removeAllObjects];
    [intro replayCurrentStep];
    XCTAssertEqualObjects(intro.renderedSteps, (@[@2, @3]));
    UIView *second = [intro valueForKey:@"secondFrame"];
    for (NSInteger i = 2; i < 11; i++) {
        CGPoint before = [intro.snapshots.firstObject[i][@"center"] CGPointValue];
        XCTAssertTrue(CGRectContainsPoint(second.frame, before));
    }
    XCTAssertEqual(intro.currentStepIndex, 3);
    XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
    [intro stopPlayback];
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
    [self settleIntro:intro atStep:0];
    [intro.renderedSteps removeAllObjects]; [intro.snapshots removeAllObjects]; [intro.viewportSnapshots removeAllObjects];
    [intro replayCurrentStep];
    XCTAssertEqualObjects(intro.renderedSteps, (@[@(-1), @0]));
    for (NSDictionary *dot in intro.snapshots.firstObject) XCTAssertEqualWithAccuracy([dot[@"alpha"] doubleValue], 0, 0.001);
    [intro stopPlayback];
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 2u);
}

- (void)testBreakTenReplayRestoresCrossedDotsBeforeRemovingThemAgain {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:288 height:500];
    [self settleIntro:intro atStep:2];
    [intro.renderedSteps removeAllObjects]; [intro.snapshots removeAllObjects]; [intro.viewportSnapshots removeAllObjects];
    [intro replayCurrentStep];
    XCTAssertEqualObjects(intro.renderedSteps, (@[@1, @2]));
    NSArray<NSDictionary *> *before = intro.snapshots.firstObject;
    for (NSInteger i = 1; i < 10; i++) {
        XCTAssertTrue([before[i][@"crossed"] boolValue]);
        XCTAssertEqualWithAccuracy([before[i][@"alpha"] doubleValue], 1, 0.001);
    }
    [intro stopPlayback];
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 9u);
}

- (void)testFirstPresentationFramesInitialTenQuantitiesWithoutAdvancingOrRevealingFutureDots {
    for (NSValue *sizeValue in @[[NSValue valueWithCGSize:CGSizeMake(288, 500)],
        [NSValue valueWithCGSize:CGSizeMake(359, 539)], [NSValue valueWithCGSize:CGSizeMake(736, 260)]]) {
        CGSize size = sizeValue.CGSizeValue;
        for (NSNumber *make in @[@YES, @NO]) {
            for (NSNumber *current in @[@YES, @NO]) {
                NSInteger a = make.boolValue ? (current.boolValue ? 2 : 8) : (current.boolValue ? 18 : 12);
                NSInteger b = current.boolValue ? 9 : 5;
                Lesson *lesson = [self lessonAtIndex:make.boolValue ? 3 : 4];
                CLRecordingIntroView *intro = current.boolValue
                    ? [[CLRecordingIntroView alloc] initWithProblem:[self problemA:a b:b make:make.boolValue] lesson:lesson]
                    : [[CLRecordingIntroView alloc] initWithLesson:lesson];
                [self hostIntro:intro width:size.width height:size.height];
                UIScrollView *scroll = [intro valueForKey:@"scrollView"];
                UIView *stage = [intro valueForKey:@"stage"];
                CGRect viewport = [scroll convertRect:scroll.bounds toView:stage];
                for (NSString *key in @[@"firstFrame", @"secondFrame", @"firstCountLabel", @"secondCountLabel"]) {
                    UIView *part = [intro valueForKey:key];
                    if (part.alpha > 0.01) XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -0.5, -0.5), part.frame));
                }
                XCTAssertEqual(intro.framingCount, 1u);
                XCTAssertFalse(intro.animatorExistedAtFraming);
                XCTAssertNil([intro valueForKey:@"stepAnimator"]);
                XCTAssertEqual(intro.currentStepIndex, 0);
                XCTAssertEqual([self visibleDotsInIntro:intro].count, (NSUInteger)a);
                XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], make.boolValue ? a : 10);
                XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], make.boolValue ? 0 : a % 10);
                XCTAssertEqual([self crossedCount:intro], 0);
                [self assertEquationHidden:intro a:a b:b make:make.boolValue];
                for (NSString *key in @[@"firstFrame", @"secondFrame"]) {
                    UIView *frame = [intro valueForKey:key];
                    XCTAssertEqualWithAccuracy(frame.bounds.size.height, 100, 0.001);
                    XCTAssertEqualObjects([frame valueForKey:@"capacity"], @10);
                }
                [self assertVisibleDotsFitWithoutOverlapping:intro];
            }
        }
    }
}

- (void)testUnattachedAndHiddenPreparationDoNotConsumeInitialPresentationFraming {
    for (NSNumber *hidden in @[@NO, @YES]) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
            lesson:[self lessonAtIndex:4]];
        intro.frame = CGRectMake(0, 0, 359, 539);
        [intro play];
        XCTAssertEqual(intro.framingCount, 0u);
        intro.hidden = hidden.boolValue;
        [self hostIntro:intro width:359 height:539];
        XCTAssertEqual(intro.framingCount, hidden.boolValue ? 0u : 1u);
        intro.hidden = NO;
        [intro play];
        XCTAssertEqual(intro.framingCount, 1u);
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        UIView *stage = [intro valueForKey:@"stage"];
        UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
        CGRect viewport = [scroll convertRect:scroll.bounds toView:stage];
        XCTAssertTrue(CGRectContainsRect(viewport, CGRectUnion(first.frame, second.frame)));
    }
}

- (void)testRepeatedPresentationAndLifecycleChangesPreserveInitialSceneInspectionOffset {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:359 height:539];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    CGFloat chosenOffset = 32;
    [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
    for (NSString *interruption in @[@"play", @"background", @"hidden", @"alpha", @"detach", @"resize", @"back"]) {
        NSUInteger expectedFramingCount = intro.framingCount;
        if ([interruption isEqualToString:@"background"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        } else if ([interruption isEqualToString:@"hidden"]) {
            intro.hidden = YES; intro.hidden = NO;
        } else if ([interruption isEqualToString:@"alpha"]) {
            intro.alpha = 0; intro.alpha = 1;
        } else if ([interruption isEqualToString:@"detach"]) {
            UIView *host = intro.superview;
            [intro removeFromSuperview]; [host addSubview:intro];
        } else if ([interruption isEqualToString:@"resize"]) {
            intro.frame = CGRectMake(0, 0, 736, 260);
        } else if ([interruption isEqualToString:@"back"]) {
            [intro goToNextStep];
            expectedFramingCount++;
            [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
            [intro goToPreviousStep];
        }
        [intro play];
        XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, chosenOffset);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        XCTAssertEqual(intro.framingCount, expectedFramingCount);
        XCTAssertEqual(intro.currentStepIndex, 0);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
        [self assertEquationHidden:intro a:18 b:9 make:NO];
    }
}

- (void)testTooShortInitialPresentationDoesNotRetryFramingAfterResize {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:288 height:360];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGRect counters = [self counterBoundsInSnapshots:@[intro.snapshots.lastObject]];
    XCTAssertGreaterThan(counters.size.height, scroll.bounds.size.height);
    XCTAssertEqual(intro.framingCount, 1u);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, 0, 0.001);
    intro.frame = CGRectMake(0, 0, 288, 500);
    [intro play];
    XCTAssertEqual(intro.framingCount, 1u);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, 0, 0.001);
    XCTAssertEqual(intro.currentStepIndex, 0);
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 18u);
}

- (void)testSimpleLessonsKeepTheirOriginalPresentationViewport {
    for (NSUInteger index = 0; index < 3; index++) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithLesson:[self lessonAtIndex:index]];
        [self hostIntro:intro width:288 height:500];
        [intro play];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        XCTAssertEqual(intro.framingCount, 0u);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, 0, 0.001);
        XCTAssertEqual(intro.currentStepIndex, 0);
    }
}

- (void)testCompactNextFramesBothTenFramesBeforeFirstPlayWithoutASetupScroll {
    for (NSNumber *make in @[@YES, @NO]) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc]
            initWithProblem:[self problemA:make.boolValue ? 2 : 18 b:9 make:make.boolValue]
            lesson:[self lessonAtIndex:make.boolValue ? 3 : 4]];
        [self hostIntro:intro width:288 height:500];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        XCTAssertEqual(intro.framingCount, 1u);
        for (NSInteger step = 1; step < intro.numberOfSteps; step++) {
            [intro goToNextStep];
            XCTAssertEqual(intro.framingCount, (NSUInteger)step + 1);
            [self assertLastTransitionIsFramedBeforeItsTargetIsApplied:intro];
            UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
            CGRect viewport = intro.viewportSnapshots.lastObject.CGRectValue;
            XCTAssertTrue(CGRectContainsRect(viewport, CGRectUnion(first.frame, second.frame)));
            for (UIView *label in @[[intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
                XCTAssertTrue(CGRectContainsRect(viewport, label.frame));
            }
            XCTAssertGreaterThan(scroll.contentOffset.y, 0);
            [self assertVisibleDotsFitWithoutOverlapping:intro];
            [intro stopPlayback];
        }
    }
}

- (void)testWideShortNextFitsBothFullTenFramesBeforeItsFirstPlay {
    for (NSNumber *width in @[@544, @736]) {
        for (NSNumber *make in @[@YES, @NO]) {
            CLRecordingIntroView *intro = [[CLRecordingIntroView alloc]
                initWithProblem:[self problemA:make.boolValue ? 9 : 18 b:9 make:make.boolValue]
                lesson:[self lessonAtIndex:make.boolValue ? 3 : 4]];
            [self hostIntro:intro width:width.doubleValue height:260];
            UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
            XCTAssertEqualWithAccuracy(first.frame.origin.y, second.frame.origin.y, 0.001);
            XCTAssertGreaterThanOrEqual(second.frame.origin.x - CGRectGetMaxX(first.frame), 24);
            XCTAssertGreaterThanOrEqual(first.bounds.size.width, 240);
            XCTAssertGreaterThanOrEqual(second.bounds.size.width, 240);
            XCTAssertEqualWithAccuracy(first.bounds.size.height, 100, 0.001);
            XCTAssertEqualWithAccuracy(second.bounds.size.height, 100, 0.001);
            XCTAssertEqualObjects([first valueForKey:@"capacity"], @10);
            XCTAssertEqualObjects([second valueForKey:@"capacity"], @10);
            for (NSInteger step = 1; step < intro.numberOfSteps; step++) {
                [intro goToNextStep];
                [self assertLastTransitionIsFramedBeforeItsTargetIsApplied:intro];
                CGRect viewport = intro.viewportSnapshots.lastObject.CGRectValue;
                XCTAssertTrue(CGRectContainsRect(viewport, CGRectUnion(first.frame, second.frame)));
                for (UIView *label in @[[intro valueForKey:@"firstCountLabel"], [intro valueForKey:@"secondCountLabel"]]) {
                    XCTAssertTrue(CGRectContainsRect(viewport, label.frame));
                }
                for (UIView *dot in [intro valueForKey:@"dots"]) {
                    XCTAssertEqualWithAccuracy(dot.bounds.size.width, 32, 0.001);
                    XCTAssertEqualWithAccuracy(dot.bounds.size.height, 32, 0.001);
                }
                [self assertVisibleDotsFitWithoutOverlapping:intro];
                [intro stopPlayback];
            }
        }
    }
}

- (void)assertStaticBeforeAfterComparisonForPausedIntro:(LessonIntroView *)intro a:(NSInteger)a {
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    XCTAssertEqual(intro.currentStepIndex, 3);
    [self assertVisibilityPausedWithoutObscuringInspection:intro];
    // The fallback is useful even if no orientation can fit the animation.
    // A child can inspect both original frames, then compare the static result.
    CGFloat offset = scroll.contentOffset.y + 1;
    [scroll setContentOffset:CGPointMake(0, offset) animated:NO];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateVisibilityPaused);
    [intro goToPreviousStep];
    [intro layoutIfNeeded];
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], a);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 9);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, offset, 0.001);
    [self assertEquationHidden:intro a:a b:9 make:YES];
    [intro goToNextStep];
    [self assertVisibilityPausedWithoutObscuringInspection:intro];
    XCTAssertEqual(intro.currentStepIndex, 3);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], a - 1);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, offset, 0.001);
    XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
    [self assertEquationHidden:intro a:a b:9 make:YES];
}

- (void)testShortCompactCounterOnlyFitStaysStaticUntilTheWholeAnnotatedActionCanFit {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"Visibility fallback must remain distinct from real Reduce Motion.");
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:288 height:420];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
    CGFloat unobstructedHeight = scroll.bounds.size.height;
    XCTAssertGreaterThan(CGRectUnion(first.frame, second.frame).size.height, unobstructedHeight);
    CGFloat chosenOffset = scroll.contentOffset.y;
    for (NSInteger step = 1; step <= 3; step++) {
        [intro goToNextStep];
        // Intentional contract change: fitting only counters is insufficient.
        // Keep the original counter-size/quantity proof, but never call a
        // partial scene a visible demonstration or silently jump to one end.
        CGRect counters = [self counterBoundsInSnapshots:@[intro.snapshots.lastObject]];
        XCTAssertLessThanOrEqual(counters.size.height + 8, unobstructedHeight);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        [self assertVisibilityPausedWithoutObscuringInspection:intro];
        [self assertVisibleDotsFitWithoutOverlapping:intro];
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
    [self assertStaticBeforeAfterComparisonForPausedIntro:intro a:2];
}

- (void)testReplayAndBackPreserveAValidUserChosenOffsetInCompactAndWideLayouts {
    for (NSValue *sizeValue in @[[NSValue valueWithCGSize:CGSizeMake(288, 500)],
        [NSValue valueWithCGSize:CGSizeMake(736, 260)]]) {
        CGSize size = sizeValue.CGSizeValue;
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
            lesson:[self lessonAtIndex:3]];
        [self hostIntro:intro width:size.width height:size.height];
        [self settleIntro:intro atStep:3];
        [intro setNeedsLayout]; [intro layoutIfNeeded];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        [scroll layoutIfNeeded];
        // First explicitly frame the complete selected action, then choose a
        // different offset within its real four-point safety margin. Offset 32
        // in the old test hid the scene and no longer claims to be safe.
        [intro replayCurrentStep];
        [intro stopPlayback];
        CGFloat chosenOffset = scroll.contentOffset.y + 1;
        XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, chosenOffset);
        [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
        [self assertRequiredActionIsContainedInActualClips:intro];
        NSUInteger framingBeforeInspection = intro.framingCount;
        [intro replayCurrentStep];
        [self assertRequiredActionIsContainedInActualClips:intro];
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        XCTAssertEqual(intro.framingCount, framingBeforeInspection);
        [intro layoutIfNeeded];
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        [intro goToPreviousStep];
        [intro layoutIfNeeded];
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        XCTAssertEqual(intro.currentStepIndex, 2);
        XCTAssertEqual(intro.framingCount, framingBeforeInspection);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testTooShortViewportDoesNotJumpToOnlyOneEndOfTheTransformation {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"Visibility fallback must remain distinct from real Reduce Motion.");
    for (NSNumber *a in @[@2, @9]) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:a.integerValue b:9 make:YES]
            lesson:[self lessonAtIndex:3]];
        [self hostIntro:intro width:288 height:360];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        CGFloat offsetBeforeNext = scroll.contentOffset.y;
        NSArray *identities = [[intro valueForKey:@"dots"] copy];
        for (NSInteger step = 1; step <= 3; step++) {
            [intro goToNextStep];
            CGRect counters = [self counterBoundsInSnapshots:@[intro.snapshots.lastObject]];
            XCTAssertGreaterThan(counters.size.height, scroll.bounds.size.height);
            XCTAssertEqualWithAccuracy(scroll.contentOffset.y, offsetBeforeNext, 0.001);
            [self assertVisibilityPausedWithoutObscuringInspection:intro];
            NSUInteger generation = intro.playbackGeneration;
            [intro replayCurrentStep];
            XCTAssertEqual(intro.playbackGeneration, generation + 1);
            XCTAssertEqual(intro.currentStepIndex, step);
            XCTAssertEqualWithAccuracy(scroll.contentOffset.y, offsetBeforeNext, 0.001);
            [self assertVisibilityPausedWithoutObscuringInspection:intro];
            XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
            XCTAssertEqual([self visibleDotsInIntro:intro].count, (NSUInteger)a.integerValue + 9);
            [self assertVisibleDotsFitWithoutOverlapping:intro];
            [self assertEquationHidden:intro a:a.integerValue b:9 make:YES];
        }
        // At maximum supported instruction size it is still fully visible and
        // outside the independently scrollable diagram, never a clipped banner.
        UILabel *instruction = [intro valueForKey:@"visibilityInstruction"];
        instruction.font = [instruction.font fontWithSize:29.7];
        [intro setNeedsLayout]; [intro layoutIfNeeded];
        [self assertVisibilityPausedWithoutObscuringInspection:intro];
        [self assertStaticBeforeAfterComparisonForPausedIntro:intro a:a.integerValue];
    }
}

- (void)testImpossibleSceneOnlyResumesAfterExpansionAndExplicitReplay {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This checks visible motion recovery, not reduced-motion endpoints.");
    LessonIntroView *intro = [self hostIntro:[[LessonIntroView alloc] initWithProblem:[self problemA:9 b:9 make:YES]
        lesson:[self lessonAtIndex:3]] width:736 height:500];
    intro.autoresizingMask = UIViewAutoresizingNone;
    intro.frame = CGRectMake(0, 0, 288, 360);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    [self settleIntro:intro atStep:3];
    [intro replayCurrentStep];
    [self assertVisibilityPausedWithoutObscuringInspection:intro];
    NSUInteger generation = intro.playbackGeneration;
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGFloat offsetBeforeResize = scroll.contentOffset.y;
    intro.frame = CGRectMake(0, 0, 736, 500);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertEqual(intro.playbackGeneration, generation);
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateVisibilityPaused);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertNil([intro valueForKey:@"visibilityDisplayLink"]);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, offsetBeforeResize, 0.001);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [intro replayCurrentStep];
    XCTAssertEqual(intro.playbackGeneration, generation + 1);
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
    XCTAssertNotNil([intro valueForKey:@"stepAnimator"]);
    [self assertRequiredActionIsContainedInActualClips:intro];
    XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
    [self assertEquationHidden:intro a:9 b:9 make:YES];

    // Separate native AX5 regression for the observed 2 + 9 landscape pause.
    // Keep the original 9 + 9 fixture above intact. Only this CHILD changes
    // size; the real foreground iPad window and scene must never be resized.
    LessonIntroView *maximumText = [self showPresentationProblemA:2 width:718
        category:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    if (!maximumText) return;
    UIWindow *physicalWindow = self.hostWindow;
    CGRect physicalBounds = physicalWindow.bounds;
    CGRect sceneBounds = physicalWindow.windowScene.coordinateSpace.bounds;
    UIView *host = maximumText.superview;
    CGRect landscapeChild = CGRectMake(floor((host.bounds.size.width - 718) / 2),
        floor((host.bounds.size.height - 284) / 2), 718, 284);
    XCTAssertTrue(CGRectContainsRect(physicalBounds, [host convertRect:landscapeChild toView:physicalWindow]));
    NSArray<UIView *> *nativeIdentities = [[maximumText valueForKey:@"dots"] copy];
    XCTAssertEqual(nativeIdentities.count, 11u);
    XCTAssertEqual(maximumText.currentStepIndex, 0);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:maximumText], 2);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:maximumText], 0);
    XCTAssertEqual([self crossedCount:maximumText], 0);
    maximumText.frame = landscapeChild;
    [maximumText setNeedsLayout]; [maximumText layoutIfNeeded];
    XCTAssertEqualObjects(maximumText.traitCollection.preferredContentSizeCategory,
        UIContentSizeCategoryAccessibilityExtraExtraExtraLarge);
    XCTAssertTrue(CGRectEqualToRect(physicalWindow.bounds, physicalBounds));
    XCTAssertTrue(CGRectEqualToRect(physicalWindow.windowScene.coordinateSpace.bounds, sceneBounds));
    XCTAssertTrue(CGRectContainsRect(physicalBounds, [maximumText convertRect:maximumText.bounds toView:physicalWindow]));
    UIScrollView *nativeScroll = [maximumText valueForKey:@"scrollView"];
    UIView *footer = [maximumText valueForKey:@"buttonStack"];
    UIView *nativeStage = [maximumText valueForKey:@"stage"];
    UIView *sourceFrame = [maximumText valueForKey:@"secondFrame"];
    UILabel *guidance = [maximumText valueForKey:@"visibilityInstruction"];
    XCTAssertTrue(guidance.hidden);
    XCTAssertEqualWithAccuracy(footer.bounds.size.height, 132, 0.001);
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(nativeScroll.frame), CGRectGetMinY(footer.frame) - 12, 0.001);
    CGRect unobstructed = CGRectIntersection([nativeScroll convertRect:nativeScroll.bounds toView:physicalWindow], physicalBounds);
    XCTAssertEqualWithAccuracy(unobstructed.size.height, 108, 0.001);
    UIView *remainder = nativeIdentities.lastObject;
    CGPoint landscapeRemainder = remainder.center;
    XCTAssertEqualWithAccuracy(landscapeRemainder.x - CGRectGetMinX(sourceFrame.frame), sourceFrame.bounds.size.width * 3.5 / 5, 0.001);
    XCTAssertEqualWithAccuracy(landscapeRemainder.y - CGRectGetMinY(sourceFrame.frame), 75, 0.001);
    for (NSInteger selected = 1; selected <= 3; selected++) {
        NSUInteger beforeNext = maximumText.playbackGeneration;
        [maximumText goToNextStep];
        XCTAssertEqual(maximumText.playbackGeneration, beforeNext + 1);
        XCTAssertEqual(maximumText.currentStepIndex, selected);
        XCTAssertEqual(maximumText.playbackStepIndex, selected);
        [self assertVisibilityPausedWithoutObscuringInspection:maximumText];
        CGRect required = [[maximumText valueForKey:@"requiredActionBounds"] CGRectValue];
        XCTAssertEqualWithAccuracy(required.size.width, 584, 0.001);
        XCTAssertEqualWithAccuracy(required.size.height, 134, 0.001);
        XCTAssertGreaterThan(required.size.height, unobstructed.size.height + 0.5);
        XCTAssertEqualObjects([maximumText valueForKey:@"dots"], nativeIdentities);
        XCTAssertEqual([self visibleDotsInIntro:maximumText].count, 11u);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:maximumText], selected < 3 ? 2 : 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:maximumText], selected < 3 ? 9 : 1);
        XCTAssertEqual([self crossedCount:maximumText], 0);
        XCTAssertTrue(CGPointEqualToPoint(remainder.center, landscapeRemainder));
        [self assertVisibleDotsFitWithoutOverlapping:maximumText];
        [self assertEquationHidden:maximumText a:2 b:9 make:YES];
    }
    NSUInteger pausedGeneration = maximumText.playbackGeneration;
    NSString *pausedValue = [NSString stringWithFormat:@"第 %lu 次播放，第 4 小步，點點圖未完整顯示，先看圖再重播",
        (unsigned long)pausedGeneration];
    XCTAssertEqualObjects([[maximumText valueForKey:@"progressLabel"] accessibilityValue], pausedValue);
    if (![self assertCommittedPresentationForDots:nativeIdentities centers:[nativeIdentities valueForKey:@"center"]
        intro:maximumText context:@"AX5 2 + 9 insufficient landscape paused destination"]) return;
    [self assertVisibilityPausedWithoutObscuringInspection:maximumText];
    XCTAssertEqual(maximumText.playbackGeneration, pausedGeneration);
    XCTAssertEqualObjects([[maximumText valueForKey:@"progressLabel"] accessibilityValue], pausedValue);

    CGRect portraitChild = CGRectMake(floor((host.bounds.size.width - 377) / 2),
        floor((host.bounds.size.height - 661) / 2), 377, 661);
    XCTAssertTrue(CGRectContainsRect(physicalBounds, [host convertRect:portraitChild toView:physicalWindow]));
    maximumText.frame = portraitChild;
    [maximumText setNeedsLayout]; [maximumText layoutIfNeeded];
    XCTAssertTrue(CGRectEqualToRect(physicalWindow.bounds, physicalBounds));
    XCTAssertTrue(CGRectEqualToRect(physicalWindow.windowScene.coordinateSpace.bounds, sceneBounds));
    XCTAssertTrue(CGRectContainsRect(physicalBounds, [maximumText convertRect:maximumText.bounds toView:physicalWindow]));
    XCTAssertEqualObjects(maximumText.traitCollection.preferredContentSizeCategory,
        UIContentSizeCategoryAccessibilityExtraExtraExtraLarge);
    CGRect portraitRequired = [[maximumText valueForKey:@"requiredActionBounds"] CGRectValue];
    CGRect portraitCapacity = CGRectIntersection([nativeScroll convertRect:nativeScroll.bounds toView:physicalWindow], physicalBounds);
    XCTAssertLessThanOrEqual(portraitRequired.size.width, portraitCapacity.size.width + 0.5);
    XCTAssertLessThanOrEqual(portraitRequired.size.height, portraitCapacity.size.height + 0.5);
    // Expansion may lay out the endpoint but has no permission to frame or
    // resume it. Commit those real pixels before checking the quiet state.
    if (![self assertCommittedPresentationForDots:nativeIdentities centers:[nativeIdentities valueForKey:@"center"]
        intro:maximumText context:@"AX5 2 + 9 expanded portrait remains paused"]) return;
    [self assertVisibilityPausedWithoutObscuringInspection:maximumText];
    XCTAssertEqual(maximumText.playbackGeneration, pausedGeneration);
    XCTAssertEqual(maximumText.currentStepIndex, 3);
    XCTAssertEqual(maximumText.playbackStepIndex, 3);
    XCTAssertEqualObjects([[maximumText valueForKey:@"progressLabel"] accessibilityValue], pausedValue);
    XCTAssertEqualObjects([maximumText valueForKey:@"dots"], nativeIdentities);
    XCTAssertEqual([self visibleDotsInIntro:maximumText].count, 11u);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:maximumText], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:maximumText], 1);
    XCTAssertEqual([self crossedCount:maximumText], 0);
    CGPoint portraitRemainder = remainder.center;
    XCTAssertEqualWithAccuracy(portraitRemainder.x - CGRectGetMinX(sourceFrame.frame), sourceFrame.bounds.size.width * 3.5 / 5, 0.001);
    XCTAssertEqualWithAccuracy(portraitRemainder.y - CGRectGetMinY(sourceFrame.frame), 75, 0.001);
    [self assertVisibleDotsFitWithoutOverlapping:maximumText];
    [self assertEquationHidden:maximumText a:2 b:9 make:YES];

    CFTimeInterval requestedAt = CACurrentMediaTime();
    [maximumText replayCurrentStep];
    NSUInteger recoveryGeneration = maximumText.playbackGeneration;
    XCTAssertEqual(recoveryGeneration, pausedGeneration + 1);
    XCTAssertEqual(maximumText.currentStepIndex, 3);
    XCTAssertEqual(maximumText.playbackStepIndex, 3);
    XCTAssertEqual(maximumText.playbackState, LessonIntroPlaybackStateRunning);
    UIViewPropertyAnimator *nativeAnimator = [maximumText valueForKey:@"stepAnimator"];
    XCTAssertNotNil(nativeAnimator);
    XCTAssertEqualObjects([maximumText valueForKey:@"activeAnimationGeneration"], @(recoveryGeneration));
    __block CFTimeInterval completedAt = 0;
    __block UIViewAnimatingPosition completionPosition = UIViewAnimatingPositionCurrent;
    [nativeAnimator addCompletion:^(UIViewAnimatingPosition position) {
        completedAt = CACurrentMediaTime();
        completionPosition = position;
    }];
    [self assertRequiredActionIsContainedInActualClips:maximumText];
    XCTAssertTrue(guidance.hidden);
    XCTAssertTrue(CGPointEqualToPoint(remainder.center, portraitRemainder));
    XCTAssertEqualObjects([maximumText valueForKey:@"dots"], nativeIdentities);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:maximumText], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:maximumText], 1);
    XCTAssertEqual([self crossedCount:maximumText], 0);
    NSPredicate *naturallyCompleted = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        LessonIntroView *view = object;
        return view.playbackGeneration == recoveryGeneration && view.playbackStepIndex == 3 && view.currentStepIndex == 3
            && view.playbackState == LessonIntroPlaybackStateCompleted;
    }];
    XCTNSPredicateExpectation *completed = [[XCTNSPredicateExpectation alloc] initWithPredicate:naturallyCompleted object:maximumText];
    [self waitForExpectations:@[completed] timeout:8];
    XCTAssertEqual(completionPosition, UIViewAnimatingPositionEnd);
    XCTAssertGreaterThan(completedAt, 0);
    XCTAssertGreaterThanOrEqual(completedAt - requestedAt + 1.0 / 60.0, [maximumText makeTenTransferDuration]);
    XCTAssertLessThanOrEqual(completedAt - requestedAt, 8);
    if (![self assertCommittedPresentationForDots:nativeIdentities centers:[nativeIdentities valueForKey:@"center"]
        intro:maximumText context:@"AX5 2 + 9 explicit portrait Replay naturally completed destination"]) return;
    [self assertRequiredActionIsContainedInActualClips:maximumText];
    XCTAssertEqual(maximumText.playbackGeneration, recoveryGeneration);
    XCTAssertEqual(maximumText.currentStepIndex, 3);
    XCTAssertEqual(maximumText.playbackStepIndex, 3);
    XCTAssertEqual(maximumText.playbackState, LessonIntroPlaybackStateCompleted);
    XCTAssertNil([maximumText valueForKey:@"stepAnimator"]);
    XCTAssertNil([maximumText valueForKey:@"visibilityDisplayLink"]);
    XCTAssertEqualObjects([maximumText valueForKey:@"activeAnimationGeneration"], @0);
    XCTAssertEqualObjects([[maximumText valueForKey:@"progressLabel"] accessibilityValue],
        ([NSString stringWithFormat:@"第 %lu 次播放，第 4 小步，動態播放完成", (unsigned long)recoveryGeneration]));
    XCTAssertEqualObjects([maximumText valueForKey:@"dots"], nativeIdentities);
    XCTAssertEqual([self visibleDotsInIntro:maximumText].count, 11u);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:maximumText], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:maximumText], 1);
    XCTAssertEqual([self crossedCount:maximumText], 0);
    XCTAssertTrue(CGPointEqualToPoint(remainder.center, portraitRemainder));
    XCTAssertTrue(CGRectContainsRect(nativeStage.bounds, remainder.frame));
    [self assertVisibleDotsFitWithoutOverlapping:maximumText];
    [self assertEquationHidden:maximumText a:2 b:9 make:YES];
}

- (void)testHistoricalLandscapeClippedReplayMinimallyFramesTheEntireAction {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression needs actual motion, not the reduced-motion endpoint.");
    // Historical native geometry from run 39684382675/source 37256a7:
    // window 852×393, intro (67,80,718,284), scroll height 180, stage y 242.3.
    // This is a deliberate reproducer, not a claim about a newer native video.
    LessonIntroView *intro = [self hostIntro:[[LessonIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]] width:852 height:393];
    intro.autoresizingMask = UIViewAutoresizingNone;
    intro.frame = CGRectMake(67, 80, 718, 284);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    [self settleIntro:intro atStep:3];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    CGRect stageInWindow = [stage convertRect:stage.bounds toView:self.hostWindow];
    CGFloat clippedOffset = MAX(0, scroll.contentOffset.y + stageInWindow.origin.y - 242.3);
    [scroll setContentOffset:CGPointMake(0, clippedOffset) animated:NO];
    CGRect viewport = [scroll convertRect:scroll.bounds toView:self.hostWindow];
    XCTAssertEqualWithAccuracy(viewport.size.height, 180, 0.001);
    XCTAssertEqualWithAccuracy(stage.bounds.size.height, 138, 0.001);
    XCTAssertEqualWithAccuracy([stage convertRect:stage.bounds toView:self.hostWindow].origin.y, 242.3, 0.5);
    for (UIView *dot in [self visibleDotsInIntro:intro]) {
        XCTAssertGreaterThan(CGRectGetMinY([dot convertRect:dot.bounds toView:self.hostWindow]), CGRectGetMaxY(viewport));
    }
    XCTAssertFalse([intro isRequiredActionVisible]);
    NSUInteger generation = intro.playbackGeneration;
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    [intro replayCurrentStep];
    XCTAssertEqual(intro.playbackGeneration, generation + 1);
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
    XCTAssertGreaterThan(scroll.contentOffset.y, clippedOffset);
    [self assertRequiredActionIsContainedInActualClips:intro];
    XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}

- (void)testAnAttachedClippingAncestorCanPreventAnOtherwiseNominalFit {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"Visibility fallback is not the system preference.");
    LessonIntroView *intro = [self showProblemA:9 b:9 make:YES width:736];
    UIView *host = intro.superview;
    [intro removeFromSuperview];
    UIView *clip = [[UIView alloc] initWithFrame:CGRectMake(0, 120, 736, 220)];
    clip.clipsToBounds = YES;
    [host addSubview:clip];
    intro.autoresizingMask = UIViewAutoresizingNone;
    intro.frame = CGRectMake(0, -280, 736, 500);
    [clip addSubview:intro];
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    [self settleIntro:intro atStep:3];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGFloat chosenOffset = scroll.contentOffset.y;
    CGRect nominal = scroll.bounds;
    [intro replayCurrentStep];
    CGRect required = [[intro valueForKey:@"requiredActionBounds"] CGRectValue];
    XCTAssertLessThan(required.size.height, nominal.size.height);
    XCTAssertFalse([intro isRequiredActionVisible]);
    XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
    [self assertVisibilityPausedWithoutObscuringInspection:intro];
    // The recovery instruction and Replay really remain in the attached clip.
    for (UIView *control in @[[intro valueForKey:@"visibilityInstruction"], [intro valueForKey:@"replayButton"]]) {
        XCTAssertTrue(CGRectContainsRect(clip.bounds, [control convertRect:control.bounds toView:clip]));
    }
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [self assertEquationHidden:intro a:9 b:9 make:YES];
}

- (void)testRotatedClippingAncestorDoesNotExposeItsEnclosingRectangle {
    LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:736];
    intro.autoresizingMask = UIViewAutoresizingNone;
    [self settleIntro:intro atStep:3];
    [intro replayCurrentStep]; [intro stopPlayback];
    UIView *stage = [intro valueForKey:@"stage"];
    CGRect required = [[intro valueForKey:@"requiredActionBounds"] CGRectValue];
    UIView *clip = [[UIView alloc] initWithFrame:(CGRect){CGPointMake(40, 100), required.size}];
    clip.clipsToBounds = YES;
    [self.hostWindow.rootViewController.view addSubview:clip];
    [intro removeFromSuperview];
    [clip addSubview:intro];
    intro.transform = CGAffineTransformMakeRotation(M_PI / 18);
    CGPoint actionCenter = [stage convertPoint:CGPointMake(CGRectGetMidX(required), CGRectGetMidY(required)) toView:intro];
    CGPoint delta = CGPointMake(actionCenter.x - CGRectGetMidX(intro.bounds), actionCenter.y - CGRectGetMidY(intro.bounds));
    delta = CGPointApplyAffineTransform(delta, intro.transform);
    intro.center = CGPointMake(CGRectGetMidX(clip.bounds) - delta.x, CGRectGetMidY(clip.bounds) - delta.y);
    // The enclosing stage-space box lies about the corners of the real clip.
    XCTAssertTrue(CGRectContainsRect([stage convertRect:clip.bounds fromView:clip], required));
    XCTAssertFalse(CGRectContainsRect(clip.bounds, [stage convertRect:required toView:clip]));
    XCTAssertFalse([intro isRequiredActionVisible]);
}

- (void)testDisplayLinkCancelsAncestorOnlyClippingAndNeedsExplicitReplayAfterRestore {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression needs a real running display-link-guarded animator.");
    for (NSNumber *hide in @[@NO, @YES]) {
        LessonIntroView *intro = [self showPresentationProblemA:2 width:736];
        if (!intro) return;
        UIView *ancestor = [[UIView alloc] initWithFrame:self.hostWindow.bounds];
        ancestor.clipsToBounds = YES;
        ancestor.autoresizesSubviews = NO;
        [self.hostWindow.rootViewController.view addSubview:ancestor];
        [intro removeFromSuperview]; [ancestor addSubview:intro];
        [self settleIntro:intro atStep:3];
        [intro replayCurrentStep];
        [self assertRequiredActionIsContainedInActualClips:intro];
        UIViewPropertyAnimator *oldAnimator = [intro valueForKey:@"stepAnimator"];
        XCTAssertNotNil(oldAnimator);
        XCTAssertNotNil([intro valueForKey:@"visibilityDisplayLink"]);
        NSUInteger generation = intro.playbackGeneration;
        UIView *stage = [intro valueForKey:@"stage"];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        CGRect introBounds = intro.bounds, stageBounds = stage.bounds, ancestorBounds = ancestor.bounds;
        CGPoint offset = scroll.contentOffset;
        if (hide.boolValue) ancestor.hidden = YES;
        else {
            CGRect action = [stage convertRect:[[intro valueForKey:@"requiredActionBounds"] CGRectValue] toView:ancestor];
            ancestor.bounds = CGRectMake(0, 0, ancestor.bounds.size.width, CGRectGetMinY(action) + 20);
        }
        // No intro resize, scroll callback or direct validator call. The actual
        // main-run-loop display link alone must notice the ancestor change.
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
        do {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        } while ([intro valueForKey:@"stepAnimator"] && deadline.timeIntervalSinceNow > 0);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqualObjects([intro valueForKey:@"activeAnimationGeneration"], @0);
        XCTAssertEqual(intro.playbackState, hide.boolValue ? LessonIntroPlaybackStateCancelled : LessonIntroPlaybackStateVisibilityPaused);
        XCTAssertNil([intro valueForKey:@"visibilityDisplayLink"]);
        XCTAssertTrue(CGRectEqualToRect(intro.bounds, introBounds));
        XCTAssertTrue(CGRectEqualToRect(stage.bounds, stageBounds));
        XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, offset));
        [intro completeStepAnimation:oldAnimator generation:generation step:3 position:UIViewAnimatingPositionEnd];
        XCTAssertNotEqual(intro.playbackState, LessonIntroPlaybackStateCompleted);
        ancestor.bounds = ancestorBounds; ancestor.hidden = NO;
        [CATransaction flush];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        XCTAssertEqual(intro.playbackGeneration, generation);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertNil([intro valueForKey:@"visibilityDisplayLink"]);
        [intro replayCurrentStep];
        XCTAssertEqual(intro.playbackGeneration, generation + 1);
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        [self assertRequiredActionIsContainedInActualClips:intro];
        [intro completeStepAnimation:oldAnimator generation:generation step:3 position:UIViewAnimatingPositionEnd];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testManualScrollInvalidatesTheRunningGenerationAndRecoveryNeedsExplicitReplay {
    XCTSkipIf(UIAccessibilityIsReduceMotionEnabled(), @"This regression needs an active native animator.");
    for (NSNumber *useSafeOffset in @[@YES, @NO]) {
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
            lesson:[self lessonAtIndex:3]];
        [self hostIntro:intro width:736 height:260];
        intro.autoresizingMask = UIViewAutoresizingNone;
        [self settleIntro:intro atStep:3];
        [intro replayCurrentStep];
        [self assertRequiredActionIsContainedInActualClips:intro];
        UIViewPropertyAnimator *oldAnimator = [intro valueForKey:@"stepAnimator"];
        NSUInteger generation = intro.playbackGeneration;
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        NSArray *identities = [[intro valueForKey:@"dots"] copy];
        XCTAssertNotNil(oldAnimator);
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        [scroll setContentOffset:CGPointZero animated:NO];
        [self assertVisibilityPausedWithoutObscuringInspection:intro];
        XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, CGPointZero));
        XCTAssertEqual(intro.playbackGeneration, generation);
        XCTAssertEqual(intro.currentStepIndex, 3);
        [intro completeStepAnimation:oldAnimator generation:generation step:3 position:UIViewAnimatingPositionEnd];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateVisibilityPaused);
        // More space and a manually restored viewport do not schedule playback.
        self.hostWindow.frame = CGRectMake(0, 0, 736, 420);
        self.hostWindow.rootViewController.view.frame = self.hostWindow.bounds;
        intro.frame = CGRectMake(0, 0, 736, 420);
        [intro setNeedsLayout]; [intro layoutIfNeeded];
        UIView *stage = [intro valueForKey:@"stage"];
        UIView *footer = [intro valueForKey:@"buttonStack"];
        CGFloat replayViewportHeight = CGRectGetMinY(footer.frame) - 12 - CGRectGetMinY(scroll.frame);
        UIEdgeInsets insets = scroll.adjustedContentInset;
        CGFloat replayMaximumOffset = MAX(-insets.top,
            scroll.contentSize.height - replayViewportHeight + insets.bottom);
        CGRect action = [stage convertRect:[[intro valueForKey:@"requiredActionBounds"] CGRectValue] toView:scroll];
        if (useSafeOffset.boolValue) {
            // Choose inside BOTH the current instruction-visible viewport and
            // the larger viewport after Replay hides that instruction. An old
            // narrow-viewport offset can be visible yet no longer scroll-valid.
            CGFloat minimum = MAX(-insets.top, CGRectGetMaxY(action) - scroll.bounds.size.height);
            CGFloat maximum = MIN(replayMaximumOffset, CGRectGetMinY(action));
            XCTAssertGreaterThan(maximum, minimum);
            [scroll setContentOffset:CGPointMake(0, (minimum + maximum) / 2) animated:NO];
        } else {
            // Reproduce the original stale-offset premise using actual current
            // geometry, not an old small-height offset that may already be
            // invalid at this font size. It is legal now and becomes invalid
            // ONLY when explicit Replay releases the instruction's reservation.
            CGFloat minimum = MAX(replayMaximumOffset + 1,
                CGRectGetMaxY(action) - scroll.bounds.size.height);
            CGFloat maximum = MIN(scroll.contentSize.height - scroll.bounds.size.height + insets.bottom,
                CGRectGetMinY(action));
            XCTAssertGreaterThan(maximum, minimum);
            CGFloat selectedOffset = (minimum + maximum) / 2;
            XCTAssertGreaterThan(selectedOffset, replayMaximumOffset);
            XCTAssertLessThanOrEqual(selectedOffset,
                scroll.contentSize.height - scroll.bounds.size.height + insets.bottom);
            [scroll setContentOffset:CGPointMake(0, selectedOffset) animated:NO];
        }
        [self assertRequiredActionIsContainedInActualClips:intro];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateVisibilityPaused);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqual(intro.playbackGeneration, generation);
        CGPoint beforeReplay = scroll.contentOffset;
        NSUInteger framingCount = intro.framingCount;
        [self attachGeometryForIntro:intro name:useSafeOffset.boolValue ? @"Safe recovery before Replay" : @"Narrow viewport offset before Replay"];
        [intro replayCurrentStep];
        [self attachGeometryForIntro:intro name:useSafeOffset.boolValue ? @"Safe recovery after Replay" : @"Narrow viewport offset after Replay"];
        XCTAssertEqual(intro.playbackGeneration, generation + 1);
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        XCTAssertEqualWithAccuracy(scroll.bounds.size.height, replayViewportHeight, 0.001);
        if (useSafeOffset.boolValue) XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, beforeReplay));
        else {
            XCTAssertEqualWithAccuracy(scroll.contentOffset.x, beforeReplay.x, 0.001);
            XCTAssertEqualWithAccuracy(scroll.contentOffset.y, replayMaximumOffset, 0.001);
        }
        XCTAssertEqual(intro.framingCount, framingCount, @"A contained scene must not be reframed in either recovery case.");
        [self assertRequiredActionIsContainedInActualClips:intro];
        [intro completeStepAnimation:oldAnimator generation:generation step:3 position:UIViewAnimatingPositionEnd];
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
    }
}

- (void)testIdleBeyondTheOldTimerIntervalNeverAdvances {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:500];
    [intro goToNextStep];
    NSPredicate *advanced = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [(LessonIntroView *)object currentStepIndex] != 1;
    }];
    XCTNSPredicateExpectation *unexpectedAdvance = [[XCTNSPredicateExpectation alloc] initWithPredicate:advanced object:intro];
    unexpectedAdvance.inverted = YES;
    [self waitForExpectations:@[unexpectedAdvance] timeout:3.7];
    [self assertEquationHidden:intro a:8 b:5 make:YES];
}

- (void)testStopBackgroundDetachAndReduceMotionSettleOnlyTheSelectedState {
    LessonIntroView *intro = [self showProblemA:2 b:9 make:YES width:288];
    [self settleIntro:intro atStep:3];
    for (NSString *interruption in @[@"stop", @"background", @"motion", @"hidden", @"alpha", @"detach"]) {
        [intro replayCurrentStep];
        if ([interruption isEqualToString:@"background"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        } else if ([interruption isEqualToString:@"motion"]) {
            [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        } else if ([interruption isEqualToString:@"hidden"]) intro.hidden = YES;
        else if ([interruption isEqualToString:@"alpha"]) intro.alpha = 0;
        else if ([interruption isEqualToString:@"detach"]) [intro removeFromSuperview];
        else [intro stopPlayback];
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqual(intro.currentStepIndex, 3);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 10);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 1);
        [self assertEquationHidden:intro a:2 b:9 make:YES];
        intro.hidden = NO; intro.alpha = 1;
    }
}

- (void)testResizeCancelsMotionWithoutAdvancingOrClippingAnyOfEightOriginalOnes {
    LessonIntroView *intro = [self showProblemA:18 b:9 make:NO width:736];
    [self settleIntro:intro atStep:2];
    [intro replayCurrentStep];
    // Height-only changes do not alter the fixed-height stage's dimensions.
    // They must still settle the animation rather than relying on stage width.
    intro.frame = CGRectMake(0, 0, 736, 420);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [intro replayCurrentStep];
    intro.frame = CGRectMake(0, 0, 288, 420);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)assertReplayAdmissionForResizeFixture:(LessonIntroView *)intro {
    // Every fixture here is 260–300 points tall. At width >=544 the full
    // 134-point side-by-side scene fits; every stacked 288/316-point scene
    // is taller than its 84–196-point viewport. Neither case is inferred
    // from the implementation's playback state or admission predicate.
    BOOL shouldFit = intro.bounds.size.width >= 544;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateReducedMotion);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    } else if (shouldFit) {
        XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateRunning);
        XCTAssertNotNil([intro valueForKey:@"stepAnimator"]);
        [self assertRequiredActionIsContainedInActualClips:intro];
    } else {
        [self assertVisibilityPausedWithoutObscuringInspection:intro];
        XCTAssertTrue([[intro valueForKey:@"previousButton"] isEnabled]);
        XCTAssertTrue([[intro valueForKey:@"nextButton"] isEnabled]);
    }
}

- (void)testRepeatedTenFrameResizesRenderFinalChildBoundsAndPreserveReplaySourceGeometry {
    NSArray<NSValue *> *sizes = @[
        [NSValue valueWithCGSize:CGSizeMake(736, 260)], // Wide height-only.
        [NSValue valueWithCGSize:CGSizeMake(288, 260)], // Wide to compact.
        [NSValue valueWithCGSize:CGSizeMake(288, 300)], // Compact height-only.
        [NSValue valueWithCGSize:CGSizeMake(736, 300)], // Compact to wide.
        [NSValue valueWithCGSize:CGSizeMake(544, 300)], // Narrowest side-by-side.
        [NSValue valueWithCGSize:CGSizeMake(543, 300)], // Cross the exact boundary.
        [NSValue valueWithCGSize:CGSizeMake(544, 300)],
        [NSValue valueWithCGSize:CGSizeMake(320, 300)],
        [NSValue valueWithCGSize:CGSizeMake(288, 300)]  // Same orientation, new width.
    ];
    for (NSNumber *make in @[@YES, @NO]) {
        NSInteger a = make.boolValue ? 2 : 18, selectedStep = make.boolValue ? 3 : 2;
        CLRecordingIntroView *intro = [[CLRecordingIntroView alloc]
            initWithProblem:[self problemA:a b:9 make:make.boolValue]
            lesson:[self lessonAtIndex:make.boolValue ? 3 : 4]];
        [self hostIntro:intro width:736 height:300];
        // This matrix is the fixed-Large geometry contract. Record an inherited
        // trait/font leak at its first boundary; do not pin or shrink fonts to
        // conceal it. Maximum text has its own unchanged visibility coverage.
        [self attachGeometryForIntro:intro name:@"Resize fixture initial traits and typography"];
        XCTAssertEqualObjects(intro.traitCollection.preferredContentSizeCategory, UIContentSizeCategoryLarge);
        UILabel *instruction = [intro valueForKey:@"visibilityInstruction"];
        XCTAssertEqualWithAccuracy(instruction.font.pointSize, 18, 0.001);
        [self settleIntro:intro atStep:selectedStep];
        NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        UIView *stage = [intro valueForKey:@"stage"];
        UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
        CGFloat chosenOffset = 32;
        [scroll setContentOffset:CGPointMake(0, chosenOffset) animated:NO];
        for (NSValue *sizeValue in sizes) {
            CGSize size = sizeValue.CGSizeValue;
            [intro replayCurrentStep];
            [self assertReplayAdmissionForResizeFixture:intro];
            NSUInteger framingCount = intro.framingCount;
            chosenOffset = scroll.contentOffset.y; // Immediately before the actual resize.
            intro.frame = (CGRect){CGPointZero, size};
            [intro setNeedsLayout];
            [intro layoutIfNeeded];
            // Observe immediately after one public layout pass. A second
            // layout, Play, Stop or Replay here would conceal stale geometry.
            NSString *context = [NSString stringWithFormat:@"%@ resize to %@", make.boolValue ? @"make" : @"break",
                NSStringFromCGSize(size)];
            [self attachGeometryForIntro:intro name:context];
            CGFloat stageWidth = size.width - 32;
            BOOL wide = size.width >= 544;
            BOOL compactMake = make.boolValue && !wide;
            CGFloat frameWidth = wide ? MIN(280, (stageWidth - 32) / 2)
                : MIN(280, stageWidth - (compactMake ? 48 : 8));
            CGFloat x = wide ? (stageWidth - frameWidth * 2 - 24) / 2
                : compactMake ? 44 + (stageWidth - 48 - frameWidth) / 2 : (stageWidth - frameWidth) / 2;
            CGRect expectedFirst = CGRectMake(x, 34, frameWidth, 100);
            CGRect expectedSecond = CGRectMake(wide ? x + frameWidth + 24 : x,
                wide ? 34 : compactMake ? 184 : 188, frameWidth, 100);
            XCTAssertEqualWithAccuracy(stage.bounds.size.width, stageWidth, 0.001);
            XCTAssertEqualWithAccuracy(stage.bounds.size.height, wide ? 138 : compactMake ? 320 : 292, 0.001);
            XCTAssertTrue(CGRectEqualToRect(first.frame, expectedFirst));
            XCTAssertTrue(CGRectEqualToRect(second.frame, expectedSecond));
            XCTAssertTrue(CGRectEqualToRect([intro.geometrySnapshots.lastObject[@"stage"] CGRectValue], stage.bounds));
            XCTAssertNil([intro valueForKey:@"stepAnimator"]);
            XCTAssertEqual(intro.currentStepIndex, selectedStep);
            XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
            XCTAssertEqual([self visibleDotsInIntro:intro].count, make.boolValue ? 11u : 9u);
            XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], make.boolValue ? 10 : 1);
            XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], make.boolValue ? 1 : 8);
            XCTAssertEqual(intro.framingCount, framingCount);
            XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, chosenOffset);
            XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
            [self assertEquationHidden:intro a:a b:9 make:make.boolValue];
            [self assertVisibleDotsFitWithoutOverlapping:intro];
            for (UIView *dot in identities) {
                XCTAssertEqualWithAccuracy(dot.bounds.size.width, 32, 0.001);
                XCTAssertEqualWithAccuracy(dot.bounds.size.height, 32, 0.001);
                if (dot.alpha > 0.5) XCTAssertTrue(CGRectContainsRect(stage.bounds, dot.frame));
            }

            NSUInteger snapshotsBeforeReplay = intro.snapshots.count;
            BOOL visibleBeforeReplay = [intro isRequiredActionVisible];
            CGFloat offsetBeforeReplay = scroll.contentOffset.y;
            [intro replayCurrentStep];
            [self attachGeometryForIntro:intro name:[context stringByAppendingString:@" Replay source"]];
            XCTAssertEqual(intro.snapshots.count, snapshotsBeforeReplay + 2);
            if (intro.snapshots.count < snapshotsBeforeReplay + 2) continue;
            NSArray<NSDictionary *> *source = intro.snapshots[snapshotsBeforeReplay];
            NSDictionary *sourceGeometry = intro.geometrySnapshots[intro.geometrySnapshots.count - 2];
            XCTAssertEqualObjects(sourceGeometry[@"step"], @(selectedStep - 1));
            XCTAssertTrue(CGRectEqualToRect([sourceGeometry[@"stage"] CGRectValue], stage.bounds));
            XCTAssertTrue(CGRectEqualToRect([sourceGeometry[@"firstFrame"] CGRectValue], expectedFirst));
            XCTAssertTrue(CGRectEqualToRect([sourceGeometry[@"secondFrame"] CGRectValue], expectedSecond));
            NSInteger sourceFirstCount = make.boolValue ? 2 : 10;
            for (NSUInteger index = 0; index < source.count; index++) {
                CGRect frame = [source[index][@"frame"] CGRectValue];
                CGRect expectedFrame = index < sourceFirstCount ? expectedFirst : expectedSecond;
                NSInteger slot = index < sourceFirstCount ? index : index - sourceFirstCount;
                CGPoint center = [source[index][@"center"] CGPointValue];
                XCTAssertEqualWithAccuracy([source[index][@"alpha"] doubleValue], 1, 0.001);
                XCTAssertTrue(CGRectContainsRect(stage.bounds, frame));
                XCTAssertTrue(CGRectContainsRect(expectedFrame, frame));
                XCTAssertEqualWithAccuracy(center.x, expectedFrame.origin.x + (slot % 5 + 0.5) * frameWidth / 5, 0.001);
                XCTAssertEqualWithAccuracy(center.y, expectedFrame.origin.y + (slot / 5 + 0.5) * 50, 0.001);
            }
            XCTAssertEqual(intro.currentStepIndex, selectedStep);
            XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
            if (visibleBeforeReplay) {
                XCTAssertEqual(intro.framingCount, framingCount);
                XCTAssertEqualWithAccuracy(scroll.contentOffset.y, offsetBeforeReplay, 0.001);
            }
            [self assertReplayAdmissionForResizeFixture:intro];
            [self assertEquationHidden:intro a:a b:9 make:make.boolValue];
        }
    }
}

- (void)testUnchangedStageLayoutDoesNotInterruptReplayOrRenderAnotherSnapshot {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:736 height:260];
    [self settleIntro:intro atStep:3];
    [intro replayCurrentStep];
    UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
    if (!UIAccessibilityIsReduceMotionEnabled()) XCTAssertNotNil(animator);
    NSUInteger snapshotCount = intro.snapshots.count;
    UIView *stage = [intro valueForKey:@"stage"];
    [stage setNeedsLayout];
    [stage layoutIfNeeded];
    XCTAssertEqual([intro valueForKey:@"stepAnimator"], animator);
    XCTAssertEqual(intro.snapshots.count, snapshotCount);
    XCTAssertEqual(intro.currentStepIndex, 3);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}

- (void)testDescendantStageWidthChangeSettlesMotionWithoutAnIntroBoundsChange {
    CLRecordingIntroView *intro = [[CLRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    [self hostIntro:intro width:736 height:260];
    [self settleIntro:intro atStep:2];
    NSArray<UIView *> *identities = [[intro valueForKey:@"dots"] copy];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    NSLayoutConstraint *contentWidth = nil;
    for (NSLayoutConstraint *constraint in scroll.constraints) {
        if (constraint.firstItem == stage.superview && constraint.firstAttribute == NSLayoutAttributeWidth
            && constraint.secondItem == scroll.frameLayoutGuide && constraint.secondAttribute == NSLayoutAttributeWidth) {
            contentWidth = constraint;
            break;
        }
    }
    XCTAssertNotNil(contentWidth);
    if (!contentWidth) return;
    CGRect introBounds = intro.bounds;
    NSString *narration = intro.currentNarration;
    [scroll setContentOffset:CGPointMake(0, 32) animated:NO];
    for (NSNumber *width in @[@512, @704]) {
        [intro replayCurrentStep];
        if (!UIAccessibilityIsReduceMotionEnabled()) XCTAssertNotNil([intro valueForKey:@"stepAnimator"]);
        NSUInteger framingCount = intro.framingCount;
        CGFloat chosenOffset = scroll.contentOffset.y; // After explicit Replay, immediately before resize.
        contentWidth.constant = width.doubleValue - intro.bounds.size.width;
        // Lay out only the actual constraint-owning descendant subtree. The
        // intro's size is unchanged, so a parent-size observer cannot repair it.
        [scroll setNeedsLayout];
        [scroll layoutIfNeeded];
        [self attachGeometryForIntro:intro name:[NSString stringWithFormat:@"Descendant stage width %@", width]];
        XCTAssertTrue(CGRectEqualToRect(intro.bounds, introBounds));
        XCTAssertEqualWithAccuracy(stage.bounds.size.width, width.doubleValue, 0.001);
        XCTAssertTrue(CGRectEqualToRect([intro.geometrySnapshots.lastObject[@"stage"] CGRectValue], stage.bounds));
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
        XCTAssertEqual(intro.currentStepIndex, 2);
        XCTAssertEqualObjects(intro.currentNarration, narration);
        XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
        XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 1);
        XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
        XCTAssertEqual(intro.framingCount, framingCount);
        XCTAssertGreaterThan(scroll.contentSize.height - scroll.bounds.size.height, chosenOffset);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.y, chosenOffset, 0.001);
        [self assertEquationHidden:intro a:18 b:9 make:NO];
        [self assertVisibleDotsFitWithoutOverlapping:intro];
    }
}

- (void)testShortScreensScrollInsteadOfShrinkingEitherTenFrame {
    LessonIntroView *intro = [self showProblemA:9 b:9 make:YES width:288];
    intro.frame = CGRectMake(0, 0, 288, 360);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    [self settleIntro:intro atStep:1];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    UIView *stage = [intro valueForKey:@"stage"];
    UIView *first = [intro valueForKey:@"firstFrame"], *second = [intro valueForKey:@"secondFrame"];
    [scroll layoutIfNeeded];
    XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.size.height);
    XCTAssertGreaterThanOrEqual(first.bounds.size.height, 90);
    XCTAssertGreaterThanOrEqual(second.bounds.size.height, 90);
    XCTAssertGreaterThanOrEqual(stage.bounds.size.height, CGRectGetMaxY(second.frame));
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 18u);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

- (void)testSkippingOrFinishingTwiceOnlyCallsCompletionOnce {
    for (NSNumber *finishAtEnd in @[@NO, @YES]) {
        LessonIntroView *intro = [self showProblemA:11 b:9 make:NO width:288];
        CLIntroFinishObserver *observer = [[CLIntroFinishObserver alloc] init];
        intro.delegate = observer;
        if (finishAtEnd.boolValue) {
            [self settleIntro:intro atStep:intro.numberOfSteps - 1];
            [intro goToNextStep];
        }
        UIButton *start = [intro valueForKey:@"startButton"];
        [start sendActionsForControlEvents:UIControlEventTouchUpInside];
        [start sendActionsForControlEvents:UIControlEventTouchUpInside];
        [intro play]; [intro goToNextStep]; [intro goToPreviousStep]; [intro replayCurrentStep];
        XCTAssertEqual(observer.finishCount, 1);
        XCTAssertFalse(start.enabled);
        XCTAssertFalse([[intro valueForKey:@"previousButton"] isEnabled]);
        XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    }
}

- (void)testUnattachedPlayDoesNotScheduleWorkOrFinishTheLesson {
    LessonIntroView *intro = [[LessonIntroView alloc] initWithLesson:[self lessonAtIndex:0]];
    CLIntroFinishObserver *observer = [[CLIntroFinishObserver alloc] init];
    intro.delegate = observer;
    [intro play];
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.currentStepIndex, 0);
    XCTAssertEqual(observer.finishCount, 0);
    [intro stopPlayback];
}

- (void)testRemovedIntroIsNotKeptAliveByPlayback {
    __weak LessonIntroView *weakIntro;
    @autoreleasepool {
        LessonIntroView *intro = [self showLessonAtIndex:0 width:288 height:420];
        [intro goToNextStep];
        weakIntro = intro;
        [intro removeFromSuperview];
        self.intro = nil;
    }
    XCTAssertNil(weakIntro);
}

- (void)testGridAnnotationsStayReadableAndFullNarrationSupportsLargeText {
    LessonIntroView *intro = [self showLessonAtIndex:3 width:288 height:420];
    for (NSString *key in @[@"firstCountLabel", @"secondCountLabel"]) {
        UILabel *label = [intro valueForKey:key];
        XCTAssertFalse(label.adjustsFontForContentSizeCategory);
        XCTAssertGreaterThanOrEqual(label.font.pointSize, 18);
        XCTAssertGreaterThanOrEqual(label.bounds.size.height, label.font.lineHeight);
    }
    UILabel *narration = [intro valueForKey:@"narration"];
    XCTAssertTrue(narration.adjustsFontForContentSizeCategory);
    XCTAssertEqual(narration.numberOfLines, 0);
    narration.font = [narration.font fontWithSize:40];
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertGreaterThan(narration.bounds.size.height, 40);
    XCTAssertEqualObjects(intro.currentNarration, narration.text);
    [self assertVisibleDotsFitWithoutOverlapping:intro];
}

#pragma mark - Reachable explanation regressions

- (LessonIntroView *)showNarrationProblemA:(NSInteger)a make:(BOOL)make size:(CGSize)size
    category:(UIContentSizeCategory)category {
    __block LessonIntroView *intro;
    UITraitCollection *traits = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:category];
    // Scope font creation to the actual requested category without changing the
    // app/window preference or leaking a global maximum-text trait to other tests.
    [traits performAsCurrentTraitCollection:^{
        intro = [[LessonIntroView alloc] initWithProblem:[self problemA:a b:9 make:make]
            lesson:[self lessonAtIndex:make ? 3 : 4]];
        intro.traitOverrides.preferredContentSizeCategory = category;
    }];
    [self hostIntro:intro width:size.width height:size.height];
    XCTAssertEqualObjects(intro.traitCollection.preferredContentSizeCategory, category);
    return intro;
}
- (CGRect)explanationRectForIntro:(LessonIntroView *)intro includeRead:(BOOL)includeRead {
    UIView *stage = [intro valueForKey:@"stage"];
    UILabel *narration = [intro valueForKey:@"narration"];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGRect required = [[intro valueForKey:@"requiredActionBounds"] CGRectValue];
    CGRect result = CGRectUnion([stage convertRect:required toView:scroll],
        [narration convertRect:narration.bounds toView:scroll]);
    if (includeRead) {
        UIButton *read = [intro valueForKey:@"readButton"];
        result = CGRectUnion(result, [read convertRect:read.bounds toView:scroll]);
    }
    return result;
}
- (void)assertCompleteExplanationInViewport:(LessonIntroView *)intro includeRead:(BOOL)includeRead {
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGRect explanation = [self explanationRectForIntro:intro includeRead:includeRead];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(scroll.bounds, -0.5, -0.5), explanation),
        @"The full teaching unit %@ must fit %@ without a helper scroll.",
        NSStringFromCGRect(explanation), NSStringFromCGRect(scroll.bounds));
    XCTAssertTrue(CGRectContainsRect(CGRectInset(intro.window.bounds, -0.5, -0.5),
        [scroll convertRect:explanation toView:intro.window]));
    UILabel *narration = [intro valueForKey:@"narration"];
    XCTAssertGreaterThanOrEqual(narration.bounds.size.height + 0.5,
        [narration sizeThatFits:CGSizeMake(narration.bounds.size.width, CGFLOAT_MAX)].height);
    XCTAssertFalse(narration.adjustsFontSizeToFitWidth);
    [self assertRequiredActionIsContainedInActualClips:intro];
}
- (BOOL)contentHasVisibleArea:(UIView *)content inButton:(UIButton *)button {
    if (!content || !button.window || content.window != button.window
        || CGRectIsEmpty(content.bounds)
        || CGRectIsEmpty([content convertRect:content.bounds toView:button])) return NO;
    for (UIView *ancestor = content; ancestor; ancestor = ancestor.superview) {
        if (ancestor.hidden || ancestor.alpha <= 0.01) return NO;
        if (ancestor == button) return YES;
    }
    return NO;
}
- (void)assertPinnedListeningAndFooterFit:(LessonIntroView *)intro {
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    NSMutableArray<NSValue *> *rects = [NSMutableArray array];
    for (NSString *key in @[@"previousButton", @"pinnedReadButton", @"nextButton", @"replayButton", @"startButton"]) {
        UIButton *button = [intro valueForKey:key];
        CGRect rect = [button convertRect:button.bounds toView:intro];
        XCTAssertFalse(button.hidden);
        XCTAssertTrue(button.enabled);
        XCTAssertGreaterThanOrEqual(rect.size.width, 60);
        XCTAssertGreaterThanOrEqual(rect.size.height, 60);
        XCTAssertTrue(CGRectContainsRect(CGRectInset(intro.bounds, -0.5, -0.5), rect));
        XCTAssertTrue(CGRectContainsRect(CGRectInset(intro.window.bounds, -0.5, -0.5),
            [button convertRect:button.bounds toView:intro.window]));
        XCTAssertFalse(CGRectIntersectsRect(rect, scroll.frame));
        for (NSValue *other in rects) XCTAssertFalse(CGRectIntersectsRect(rect, other.CGRectValue));
        [rects addObject:[NSValue valueWithCGRect:rect]];
        XCTAssertGreaterThan(button.accessibilityLabel.length, 0u);
        XCTAssertEqualObjects(button.largeContentTitle, button.accessibilityLabel);
        XCTAssertTrue(button.showsLargeContentViewer);
        XCTAssertFalse(button.titleLabel.adjustsFontSizeToFitWidth);
        CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
        UIView *hit = [intro hitTest:center withEvent:nil];
        XCTAssertTrue(hit == button || [hit isDescendantOfView:button]);
        // UIKit owns these content views. A zero title rectangle paints no
        // title even when its managed hidden bit is NO. Require exactly one
        // actually visible content area, not an implementation-specific flag.
        BOOL titleVisible = [self contentHasVisibleArea:button.titleLabel inButton:button];
        BOOL symbolVisible = [self contentHasVisibleArea:button.imageView inButton:button];
        XCTAssertNotEqual(titleVisible, symbolVisible, @"%@ must show its whole title or its symbol, never neither/both.", key);
        if (!titleVisible) {
            XCTAssertTrue(symbolVisible);
            XCTAssertFalse(button.imageView.hidden);
            XCTAssertNotNil([button imageForState:UIControlStateNormal]);
            XCTAssertNotNil(button.imageView.image);
            XCTAssertGreaterThanOrEqual(button.imageView.bounds.size.width, 24);
            CGRect symbol = [button.imageView convertRect:button.imageView.bounds toView:button];
            XCTAssertGreaterThanOrEqual(symbol.size.width, 24);
            XCTAssertGreaterThanOrEqual(symbol.size.height, 24);
            XCTAssertTrue(CGRectContainsRect(button.bounds, button.imageView.frame));
            XCTAssertTrue(CGRectContainsRect(button.bounds, symbol));
        } else {
            XCTAssertFalse(button.titleLabel.hidden);
            XCTAssertFalse(symbolVisible);
            XCTAssertEqualObjects(button.titleLabel.text, button.currentTitle);
            CGSize fullTitle = [button.currentTitle sizeWithAttributes:@{NSFontAttributeName:button.titleLabel.font}];
            XCTAssertGreaterThanOrEqual(button.titleLabel.bounds.size.width + 0.5, fullTitle.width);
            XCTAssertGreaterThanOrEqual(button.titleLabel.bounds.size.height + 0.5, button.titleLabel.font.lineHeight);
            XCTAssertTrue(CGRectContainsRect(button.bounds, button.titleLabel.frame));
            CGRect title = [button.titleLabel convertRect:button.titleLabel.bounds toView:button];
            XCTAssertGreaterThanOrEqual(title.size.width + 0.5, fullTitle.width);
            XCTAssertGreaterThanOrEqual(title.size.height + 0.5, button.titleLabel.font.lineHeight);
            XCTAssertTrue(CGRectContainsRect(button.bounds, title));
        }
    }
    UIButton *pinned = [intro valueForKey:@"pinnedReadButton"];
    XCTAssertFalse([pinned isDescendantOfView:scroll]);
    XCTAssertEqualObjects(pinned.accessibilityIdentifier, @"lessonIntro.readPinned");
    XCTAssertEqualObjects(pinned.accessibilityLabel, @"聽聽這一步");
    XCTAssertEqualObjects([[intro valueForKey:@"readButton"] accessibilityIdentifier], @"lessonIntro.read");
}

- (void)testSelectedMakeAndBreakStepsFrameWholeNarrationAndReadActionWhenTheyFit {
    for (NSNumber *a in @[@2, @9, @18]) {
        BOOL make = a.integerValue < 10;
        LessonIntroView *intro = [self showNarrationProblemA:a.integerValue make:make
            size:CGSizeMake(377, 661) category:UIContentSizeCategoryLarge];
        UIScrollView *scroll = [intro valueForKey:@"scrollView"];
        NSArray *identities = [[intro valueForKey:@"dots"] copy];
        XCTAssertEqualWithAccuracy(scroll.bounds.size.height, 485, 0.5);
        XCTAssertEqualWithAccuracy([[intro valueForKey:@"buttonStack"] bounds].size.height, 132, 0.5);
        for (NSInteger step = 1; step < intro.numberOfSteps; step++) {
            [intro goToNextStep];
            // Observe the public transition, before Stop, Replay or any scroll.
            [self assertCompleteExplanationInViewport:intro includeRead:YES];
            [self assertPinnedListeningAndFooterFit:intro];
            XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
            [self assertVisibleDotsFitWithoutOverlapping:intro];
            if (step < intro.numberOfSteps - 1) [self assertEquationHidden:intro a:a.integerValue b:9 make:make];
            CGPoint offset = scroll.contentOffset;
            [intro stopPlayback];
            [intro replayCurrentStep];
            XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, offset));
            [self assertCompleteExplanationInViewport:intro includeRead:YES];
            XCTAssertEqual(intro.currentStepIndex, step);
            [intro stopPlayback];
        }
    }
}
- (void)testSelectedStepCanFrameNarrationWithoutTheInContentReadButton {
    LessonIntroView *intro = [self showNarrationProblemA:2 make:YES size:CGSizeMake(377, 566)
        category:UIContentSizeCategoryLarge];
    [intro goToNextStep]; [intro goToNextStep];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGRect withRead = [self explanationRectForIntro:intro includeRead:YES];
    CGRect withoutRead = [self explanationRectForIntro:intro includeRead:NO];
    XCTAssertGreaterThan(withRead.size.height, scroll.bounds.size.height);
    XCTAssertLessThanOrEqual(withoutRead.size.height, scroll.bounds.size.height);
    [self assertCompleteExplanationInViewport:intro includeRead:NO];
    [self assertPinnedListeningAndFooterFit:intro];
    XCTAssertFalse(CGRectContainsRect(scroll.bounds, withRead));
    XCTAssertEqual(intro.playbackState, UIAccessibilityIsReduceMotionEnabled()
        ? LessonIntroPlaybackStateReducedMotion : LessonIntroPlaybackStateRunning);
    XCTAssertEqual(intro.currentStepIndex, 2);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}
- (void)testSafeManualDiagramInspectionReplayDoesNotChaseClippedNarration {
    LessonIntroView *intro = [self showNarrationProblemA:2 make:YES size:CGSizeMake(377, 661)
        category:UIContentSizeCategoryLarge];
    [intro goToNextStep]; [intro goToNextStep]; [intro goToNextStep];
    [intro stopPlayback];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    [scroll setContentOffset:CGPointZero animated:NO];
    [self assertRequiredActionIsContainedInActualClips:intro];
    XCTAssertFalse(CGRectContainsRect(scroll.bounds, [self explanationRectForIntro:intro includeRead:NO]));
    NSUInteger generation = intro.playbackGeneration;
    [intro replayCurrentStep];
    XCTAssertEqual(intro.playbackGeneration, generation + 1);
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, CGPointZero));
    [self assertRequiredActionIsContainedInActualClips:intro];
    [self assertPinnedListeningAndFooterFit:intro];
    [intro goToPreviousStep];
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, CGPointZero));
    [intro goToNextStep];
    [self assertCompleteExplanationInViewport:intro includeRead:YES];
    XCTAssertGreaterThan(scroll.contentOffset.y, 0);
    XCTAssertEqual(intro.currentStepIndex, 3);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}
- (void)testUncappedLargeNarrationDoesNotBlockOrWeakenCausalAdmission {
    LessonIntroView *intro = [self showNarrationProblemA:2 make:YES size:CGSizeMake(377, 661)
        category:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    [intro goToNextStep]; [intro goToNextStep]; [intro goToNextStep];
    UILabel *narration = [intro valueForKey:@"narration"];
    UIFont *expected = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:20 weight:UIFontWeightMedium]
        compatibleWithTraitCollection:intro.traitCollection];
    XCTAssertGreaterThan(expected.pointSize, 33);
    XCTAssertEqualWithAccuracy(narration.font.pointSize, expected.pointSize, 0.5);
    XCTAssertEqualObjects(narration.traitCollection.preferredContentSizeCategory,
        UIContentSizeCategoryAccessibilityExtraExtraExtraLarge);
    UIButton *read = [intro valueForKey:@"readButton"];
    UIFont *readFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightBold]
        compatibleWithTraitCollection:intro.traitCollection];
    XCTAssertGreaterThan(readFont.pointSize, 22);
    XCTAssertEqualWithAccuracy(read.titleLabel.font.pointSize, readFont.pointSize, 0.5);
    XCTAssertFalse(read.titleLabel.adjustsFontSizeToFitWidth);
    XCTAssertEqual(read.titleLabel.numberOfLines, 0);
    XCTAssertEqual(read.titleLabel.lineBreakMode, NSLineBreakByWordWrapping);
    XCTAssertGreaterThanOrEqual(read.bounds.size.height + 0.5,
        [read.titleLabel sizeThatFits:CGSizeMake(read.bounds.size.width - 24, CGFLOAT_MAX)].height + 24);
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    XCTAssertGreaterThan([self explanationRectForIntro:intro includeRead:NO].size.height, scroll.bounds.size.height);
    [self assertRequiredActionIsContainedInActualClips:intro];
    [self assertPinnedListeningAndFooterFit:intro];
    XCTAssertEqual(intro.playbackState, UIAccessibilityIsReduceMotionEnabled()
        ? LessonIntroPlaybackStateReducedMotion : LessonIntroPlaybackStateRunning);
    XCTAssertEqual(intro.currentStepIndex, 3);
    XCTAssertEqual([self visibleDotsInIntro:intro].count, 11u);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
}
- (void)testPinnedListeningAndNavigationFitCompactAndAX5WithoutFontCaps {
    for (UIContentSizeCategory category in @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        for (NSValue *sizeValue in @[[NSValue valueWithCGSize:CGSizeMake(288, 260)],
            [NSValue valueWithCGSize:CGSizeMake(288, 360)], [NSValue valueWithCGSize:CGSizeMake(377, 661)],
            [NSValue valueWithCGSize:CGSizeMake(736, 260)]]) {
            LessonIntroView *intro = [self showNarrationProblemA:2 make:YES size:sizeValue.CGSizeValue category:category];
            [self settleIntro:intro atStep:3];
            [intro replayCurrentStep];
            [intro layoutIfNeeded];
            [self assertPinnedListeningAndFooterFit:intro];
            UIScrollView *scroll = [intro valueForKey:@"scrollView"];
            XCTAssertGreaterThanOrEqual(scroll.bounds.size.height, 32);
            for (NSString *key in @[@"previousButton", @"nextButton", @"replayButton", @"startButton"]) {
                UIButton *button = [intro valueForKey:key];
                UIFont *expected = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                    scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightBold]
                    compatibleWithTraitCollection:intro.traitCollection];
                XCTAssertEqualWithAccuracy(button.titleLabel.font.pointSize, expected.pointSize, 0.5);
                if ([category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
                    XCTAssertGreaterThan(button.titleLabel.font.pointSize, 22);
                }
            }
            for (UIView *dot in [intro valueForKey:@"dots"]) {
                XCTAssertEqualWithAccuracy(dot.bounds.size.width, 32, 0.001);
                XCTAssertEqualWithAccuracy(dot.bounds.size.height, 32, 0.001);
            }
            if (sizeValue.CGSizeValue.width == 288 && !UIAccessibilityIsReduceMotionEnabled()) {
                XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateVisibilityPaused);
                XCTAssertNil([intro valueForKey:@"stepAnimator"]);
                XCTAssertNil([intro valueForKey:@"visibilityDisplayLink"]);
                UILabel *instruction = [intro valueForKey:@"visibilityInstruction"];
                XCTAssertFalse(instruction.hidden);
                XCTAssertTrue(CGRectContainsRect(intro.bounds, instruction.frame));
                XCTAssertFalse(CGRectIntersectsRect(instruction.frame, scroll.frame));
                XCTAssertTrue([instruction.accessibilityLabel containsString:@"按喇叭"]);
            }
            [self assertEquationHidden:intro a:2 b:9 make:YES];
            [self attachGeometryForIntro:intro name:[NSString stringWithFormat:@"Reachable listening %@ %@", category,
                NSStringFromCGSize(sizeValue.CGSizeValue)]];
        }
    }
}
- (void)testFooterButtonsCreateAndSwitchBetweenTextAndSymbolsAfterLiveTextSizeChanges {
    NSArray<NSString *> *keys = @[@"previousButton", @"nextButton", @"replayButton", @"startButton"];
    for (UIContentSizeCategory initial in @[UIContentSizeCategoryLarge,
            UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        // Exercise the production factory before any test reads titleLabel, in
        // a real foreground scene rather than a detached geometry-only fixture.
        LessonIntroView *intro = [self showPresentationProblemA:2 width:377 category:initial];
        XCTAssertNotNil(intro);
        if (!intro) return;
        [self settleIntro:intro atStep:3];
        NSArray<UIButton *> *buttons = [intro dictionaryWithValuesForKeys:keys].allValues;
        XCTAssertEqual(buttons.count, keys.count);
        UIViewController *host = self.hostWindow.rootViewController;
        for (UIContentSizeCategory category in @[initial, UIContentSizeCategoryLarge,
                UIContentSizeCategoryAccessibilityExtraExtraExtraLarge, UIContentSizeCategoryLarge]) {
            // Change inherited UIKit traits on the existing hierarchy. Do not
            // rebuild buttons, set test fonts, or only change the current-trait scope.
            host.traitOverrides.preferredContentSizeCategory = category;
            for (NSUInteger pass = 0; pass < 4; pass++) {
                [host.view setNeedsLayout]; [host.view layoutIfNeeded];
                [intro setNeedsLayout]; [intro layoutIfNeeded];
            }
            XCTAssertEqual(intro.window, self.hostWindow);
            XCTAssertNotNil(intro.window.windowScene);
            XCTAssertEqualObjects(intro.traitCollection.preferredContentSizeCategory, category);
            XCTAssertEqual(intro.currentStepIndex, 3);
            [self assertPinnedListeningAndFooterFit:intro];
            BOOL usesSymbols = UIContentSizeCategoryIsAccessibilityCategory(category);
            for (NSString *key in keys) {
                UIButton *button = [intro valueForKey:key];
                XCTAssertTrue([buttons containsObject:button], @"Live resizing must retain the original controls.");
                XCTAssertEqualObjects(button.traitCollection.preferredContentSizeCategory, category);
                UIFont *expected = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                    scaledFontForFont:[ChildUI roundedFontOfSize:18 weight:UIFontWeightBold]
                    compatibleWithTraitCollection:intro.traitCollection];
                XCTAssertEqualWithAccuracy(button.titleLabel.font.pointSize, expected.pointSize, 0.01);
                XCTAssertTrue(button.titleLabel.adjustsFontForContentSizeCategory);
                XCTAssertEqual([self contentHasVisibleArea:button.titleLabel inButton:button], !usesSymbols,
                    @"%@ at %@ must retain the intended full-text or symbol presentation", key, category);
                XCTAssertEqual([self contentHasVisibleArea:button.imageView inButton:button], usesSymbols,
                    @"%@ at %@ must retain the intended full-text or symbol presentation", key, category);
                XCTAssertEqualObjects(button.titleLabel.text, button.currentTitle);
                XCTAssertGreaterThan(button.currentTitle.length, 0u);
                XCTAssertEqualObjects(button.largeContentTitle, button.accessibilityLabel);
            }
        }
    }
}
- (void)testPinnedListeningSpeaksOnlyCurrentTextWithoutChangingMotionOrInspection {
    CLSpeechRecordingIntroView *intro = [[CLSpeechRecordingIntroView alloc] initWithProblem:[self problemA:2 b:9 make:YES]
        lesson:[self lessonAtIndex:3]];
    [self hostIntro:intro width:377 height:661];
    XCTAssertEqual(intro.recorder.requests.count, 0u);
    [intro goToNextStep]; [intro goToNextStep]; [intro goToNextStep];
    XCTAssertEqual(intro.recorder.requests.count, 0u, @"Selecting or replaying a step never starts speech.");
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGPoint offset = scroll.contentOffset;
    NSUInteger generation = intro.playbackGeneration;
    UIViewPropertyAnimator *animator = [intro valueForKey:@"stepAnimator"];
    UIButton *pinned = [intro valueForKey:@"pinnedReadButton"];
    for (NSUInteger repeat = 0; repeat < 2; repeat++) [pinned sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqualObjects(intro.recorder.requests, (@[intro.currentNarration, intro.currentNarration]));
    XCTAssertEqual(intro.currentStepIndex, 3);
    XCTAssertEqual(intro.playbackGeneration, generation);
    XCTAssertEqual([intro valueForKey:@"stepAnimator"], animator);
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, offset));
    [[intro valueForKey:@"readButton"] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(intro.recorder.requests.count, 3u);
    XCTAssertEqualObjects(intro.recorder.requests.lastObject, intro.currentNarration);
    NSUInteger stops = intro.recorder.stopCount;
    [intro goToPreviousStep];
    XCTAssertGreaterThan(intro.recorder.stopCount, stops);
    XCTAssertEqual(intro.recorder.requests.count, 3u);
    [pinned sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqualObjects(intro.recorder.requests.lastObject, intro.currentNarration);
    XCTAssertTrue([intro.recorder.requests.lastObject containsString:@"有雙圈的 8 個"]);
    stops = intro.recorder.stopCount;
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertGreaterThan(intro.recorder.stopCount, stops);
    XCTAssertEqual(intro.recorder.requests.count, 4u);
    intro.frame = CGRectMake(0, 0, 736, 260);
    [intro setNeedsLayout]; [intro layoutIfNeeded];
    XCTAssertEqual(intro.recorder.requests.count, 4u);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    [[intro valueForKey:@"startButton"] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertFalse(pinned.enabled);
    [pinned sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(intro.recorder.requests.count, 4u);
}
- (void)testReducedMotionKeepsExplicitListeningAndTheSameSelectedStaticStep {
    CLSpeechRecordingIntroView *intro = [[CLSpeechRecordingIntroView alloc] initWithProblem:[self problemA:18 b:9 make:NO]
        lesson:[self lessonAtIndex:4]];
    intro.forceReducedMotion = YES;
    [self hostIntro:intro width:288 height:360];
    [intro goToNextStep]; [intro goToNextStep];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateReducedMotion);
    XCTAssertNil([intro valueForKey:@"stepAnimator"]);
    XCTAssertEqual(intro.recorder.requests.count, 0u);
    NSArray *identities = [[intro valueForKey:@"dots"] copy];
    UIScrollView *scroll = [intro valueForKey:@"scrollView"];
    CGPoint offset = scroll.contentOffset;
    [self assertPinnedListeningAndFooterFit:intro];
    [[intro valueForKey:@"pinnedReadButton"] sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqualObjects(intro.recorder.requests, (@[intro.currentNarration]));
    XCTAssertEqual(intro.currentStepIndex, 2);
    XCTAssertTrue(CGPointEqualToPoint(scroll.contentOffset, offset));
    XCTAssertEqualObjects([intro valueForKey:@"dots"], identities);
    XCTAssertEqual([self countInFrame:@"firstFrame" intro:intro], 1);
    XCTAssertEqual([self countInFrame:@"secondFrame" intro:intro], 8);
    [self assertEquationHidden:intro a:18 b:9 make:NO];
    [intro replayCurrentStep];
    XCTAssertEqual(intro.playbackState, LessonIntroPlaybackStateReducedMotion);
    XCTAssertEqual(intro.recorder.requests.count, 1u);
    XCTAssertEqual(intro.currentStepIndex, 2);
}

- (void)testCurrentQuestionExplanationUsesTheFullSurfaceWithoutAnAnswerFooter {
    ExplanationViewController *controller = [[ExplanationViewController alloc]
        initWithArithmeticProblem:[self problemA:2 b:9 make:YES] wordProblem:nil lesson:[self lessonAtIndex:3]];
    self.hostWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    self.hostWindow.rootViewController = controller;
    self.hostWindow.hidden = NO;
    controller.view.frame = self.hostWindow.bounds;
    [controller.view setNeedsLayout]; [controller.view layoutIfNeeded];
    LessonIntroView *intro = [controller valueForKey:@"tenFrameTeaching"];
    self.intro = intro;
    XCTAssertNotNil(intro);
    XCTAssertGreaterThan(intro.bounds.size.height, 360);
    XCTAssertNil([controller valueForKey:@"explanation"]);
    XCTAssertNil([controller valueForKey:@"replayButton"]);
    XCTAssertNil([controller valueForKey:@"visualHeight"]);
    [self assertEquationHidden:intro a:2 b:9 make:YES];
    XCTAssertEqualObjects([[intro valueForKey:@"startButton"] titleForState:UIControlStateNormal], @"回到題目");
}

@end
