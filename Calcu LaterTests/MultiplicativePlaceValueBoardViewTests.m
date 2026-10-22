#import <XCTest/XCTest.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "MultiplicativePlaceValueBoardView.h"
#import "MultiplicativePlaceValueScene.h"

@interface MultiplicativePlaceValueBoardView (NativeTests)
- (BOOL)motionAllowed;
- (void)installScenePaint;
- (BOOL)actualVisibilityContainsRequiredRect;
- (BOOL)installedPaintIsLawful;
- (BOOL)ownedSurfaceHasNoAdditionalPaint:(CALayer *)layer;
- (BOOL)cradleHasOnlyKnownGuidePaint;
- (BOOL)layerIsStable:(CALayer *)layer requirePresentation:(BOOL)requirePresentation;
- (BOOL)paintTreeIsStable:(CALayer *)layer requirePresentation:(BOOL)requirePresentation;
- (BOOL)layerChildrenAreUnobscured:(CALayer *)parent targets:(NSSet<CALayer *> *)targets;
- (BOOL)occluderMayCoverAction:(UIView *)view;
- (NSSet<CALayer *> *)ownedRootLayers;
- (void)tick:(CADisplayLink *)link transaction:(id)transaction;
- (void)advanceClockAtTimestamp:(CFTimeInterval)timestamp transaction:(id)transaction clock:(CADisplayLink *)clock;
- (void)renderElapsed:(NSTimeInterval)elapsed transaction:(id)transaction clock:(CADisplayLink *)clock;
@end
static void MTPAddFrozenPaintAnimation(CALayer *layer, NSString *keyPath, id destination) {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
    animation.fromValue = [layer valueForKeyPath:keyPath]; animation.toValue = destination;
    animation.duration = 10; animation.speed = 0; animation.timeOffset = 5; animation.fillMode = kCAFillModeBoth; animation.removedOnCompletion = NO;
    [layer addAnimation:animation forKey:@"native.unstable.paint"];
}
// Capture model and native presentation state without committing, laying out,
// removing layers, allowing unknown paint, or changing the admission result.
static void MTPAppendLayerDiagnostic(NSMutableArray<NSString *> *lines, CALayer *layer, NSUInteger depth) {
    CALayer *paint = layer.presentationLayer;
    [lines addObject:[NSString stringWithFormat:@"layer depth=%lu model=%@ %p frame=%@ bounds=%@ position=%@ hidden=%d opacity=%g z=%g mask=%@ animations=%@ transformIdentity=%d sublayerTransformIdentity=%d clips=%d corner=%g shadow=%g contents=%d; paint=%@ %p modelLink=%d frame=%@ hidden=%d opacity=%g children=%lu",
        (unsigned long)depth, NSStringFromClass(layer.class), layer, NSStringFromCGRect(layer.frame), NSStringFromCGRect(layer.bounds), NSStringFromCGPoint(layer.position), layer.hidden, (double)layer.opacity, (double)layer.zPosition, layer.mask, layer.animationKeys,
        CATransform3DIsIdentity(layer.transform), CATransform3DIsIdentity(layer.sublayerTransform), layer.masksToBounds, (double)layer.cornerRadius, (double)layer.shadowOpacity, layer.contents != nil,
        NSStringFromClass(paint.class), paint, paint.modelLayer == layer, NSStringFromCGRect(paint.frame), paint.hidden, (double)paint.opacity, (unsigned long)paint.sublayers.count]];
    if (paint) [lines addObject:[NSString stringWithFormat:@"paint stability bounds=%@ position=%@ anchor=%@/%@ anchorZ=%g/%g z=%g/%g mask=%@ animations=%@ transformIdentity=%d sublayerTransformIdentity=%d clips=%d/%d corner=%g/%g",
        NSStringFromCGRect(paint.bounds), NSStringFromCGPoint(paint.position), NSStringFromCGPoint(layer.anchorPoint), NSStringFromCGPoint(paint.anchorPoint),
        (double)layer.anchorPointZ, (double)paint.anchorPointZ, (double)layer.zPosition, (double)paint.zPosition, paint.mask, paint.animationKeys,
        CATransform3DIsIdentity(paint.transform), CATransform3DIsIdentity(paint.sublayerTransform), layer.masksToBounds, paint.masksToBounds, (double)layer.cornerRadius, (double)paint.cornerRadius]];
    for (CALayer *child in layer.sublayers) {
        if (depth < 4) MTPAppendLayerDiagnostic(lines, child, depth + 1);
        else [lines addObject:[NSString stringWithFormat:@"deeper model subtree not expanded: %@ %p children=%lu", NSStringFromClass(child.class), child, (unsigned long)child.sublayers.count]];
    }
    for (CALayer *child in paint.sublayers) {
        [lines addObject:[NSString stringWithFormat:@"paint child depth=%lu class=%@ model=%@ %p inModelChildren=%d frame=%@ hidden=%d opacity=%g",
            (unsigned long)depth + 1, NSStringFromClass(child.class), NSStringFromClass(((CALayer *)child.modelLayer).class), child.modelLayer,
            child.modelLayer && [layer.sublayers containsObject:child.modelLayer], NSStringFromCGRect(child.frame), child.hidden, (double)child.opacity]];
    }
}
@interface MTPNativeBoard : MultiplicativePlaceValueBoardView
@property (nonatomic) BOOL allowsMotion;
@property (nonatomic) BOOL injectLabelAnimation;
@property (nonatomic) BOOL captureVisibilityFailure;
@property (nonatomic, copy) NSString *visibilityFailureDiagnostic;
- (NSString *)visibilityDiagnostic;
@end
@implementation MTPNativeBoard
- (BOOL)motionAllowed { return self.allowsMotion; }
- (BOOL)actualVisibilityContainsRequiredRect {
    BOOL admitted = [super actualVisibilityContainsRequiredRect];
    if (!admitted && self.captureVisibilityFailure && !self.visibilityFailureDiagnostic) {
        // Preserve the FIRST rejected focus frame, before playInVisibleRect:
        // replaces it with the recovery overview. This is observation only.
        self.visibilityFailureDiagnostic = [self visibilityDiagnostic];
    }
    return admitted;
}
- (NSString *)visibilityDiagnostic {
    CGRect requested = [[self valueForKey:@"requestedVisibleRect"] CGRectValue];
    BOOL requiresPaint = [self valueForKey:@"clock"] != nil;
    NSDictionary<NSNumber *, UIView *> *units = [self valueForKey:@"unitViews"];
    NSDictionary<NSString *, UILabel *> *labels = [self valueForKey:@"labels"];
    MTPPlaceValueProjection *projection = [self valueForKey:@"projection"];
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:
        @"visibility rejection applicationState=%ld sceneState=%ld sceneBounds=%@ windowBounds=%@ windowSafe=%@ boardBounds=%@ required=%@ requested=%@ category=%@ sceneWidth=%g sceneValid=%d geometryFailure=%@ installedPaintLawful=%d requiresPresentation=%d units=%lu/%lu labels=%lu/%lu",
        (long)UIApplication.sharedApplication.applicationState, (long)self.window.windowScene.activationState,
        NSStringFromCGRect(self.window.windowScene.coordinateSpace.bounds), NSStringFromCGRect(self.window.bounds), NSStringFromCGRect(self.window.safeAreaLayoutGuide.layoutFrame),
        NSStringFromCGRect(self.bounds), NSStringFromCGRect(self.requiredActionRect), NSStringFromCGRect(requested), self.traitCollection.preferredContentSizeCategory,
        (double)self.scene.width, self.scene.geometryValid, self.scene.geometryFailure, [self installedPaintIsLawful], requiresPaint,
        (unsigned long)units.count, (unsigned long)projection.placements.count, (unsigned long)labels.count, (unsigned long)self.scene.labelFrames.count]];
    for (MTPPlaceValueUnitPlacement *placement in projection.placements) {
        UIView *view = units[@(placement.unit.identifier)];
        [lines addObject:[NSString stringWithFormat:@"unit=%lu exists=%d attached=%d/%d unitIdentity=%d owner=%@/%@ carry=%@/%d frame=%@/%@ body=%@/%@ stable=%d paintTreeStable=%d noAdditionalPaint=%d inRequired=%d",
            (unsigned long)placement.unit.identifier, view != nil, view.superview == self, view.layer.superlayer == self.layer, [view valueForKey:@"unit"] == placement.unit, [view valueForKey:@"owner"], placement.owner,
            [view valueForKey:@"carryAnnotation"], placement.carryAnnotation, NSStringFromCGRect(view.frame), NSStringFromCGRect(placement.frame), NSStringFromCGSize(view.bounds.size), NSStringFromCGSize(MTPPlaceValueBodySize(placement.unit.column)),
            [self layerIsStable:view.layer requirePresentation:requiresPaint], [self paintTreeIsStable:view.layer requirePresentation:requiresPaint], [self ownedSurfaceHasNoAdditionalPaint:view.layer],
            CGRectContainsRect(self.requiredActionRect, view.layer.presentationLayer ? ((CALayer *)view.layer.presentationLayer).frame : view.frame)]];
        MTPAppendLayerDiagnostic(lines, view.layer, 0);
    }
    for (NSString *key in self.scene.labelFrames) {
        UILabel *label = labels[key];
        [lines addObject:[NSString stringWithFormat:@"label=%@ exists=%d attached=%d/%d textMatches=%d shrink=%d textShadow=%@ frame=%@/%@ font=%g/%g measuredHeight=%g stable=%d paintTreeStable=%d noAdditionalPaint=%d",
            key, label != nil, label.superview == self, label.layer.superlayer == self.layer, [label.text isEqualToString:projection.labelTexts[key]], label.adjustsFontSizeToFitWidth, label.shadowColor, NSStringFromCGRect(label.frame), NSStringFromCGRect(self.scene.labelFrames[key].CGRectValue),
            (double)label.font.pointSize, (double)self.scene.font.pointSize, (double)(label.font ? MTPPlaceValueTextHeight(label.text ?: @"", label.font, label.bounds.size.width) : NAN),
            [self layerIsStable:label.layer requirePresentation:requiresPaint], [self paintTreeIsStable:label.layer requirePresentation:requiresPaint], [self ownedSurfaceHasNoAdditionalPaint:label.layer]]];
        MTPAppendLayerDiagnostic(lines, label.layer, 0);
    }
    UIView *cradle = [self valueForKey:@"cradle"];
    [lines addObject:[NSString stringWithFormat:@"cradle=%@ expected=%@ knownGuide=%d ownedRootsUnobscured=%d",
        cradle, NSStringFromCGRect(self.scene.cradleRect), cradle && [self cradleHasOnlyKnownGuidePaint], [self layerChildrenAreUnobscured:self.layer targets:[self ownedRootLayers]]]];
    if (cradle) MTPAppendLayerDiagnostic(lines, cradle.layer, 0);
    CGRect visible = CGRectIntersection(self.bounds, requested);
    visible = CGRectIntersection(visible, [self convertRect:self.window.bounds fromView:self.window]);
    visible = CGRectIntersection(visible, [self convertRect:self.window.safeAreaLayoutGuide.layoutFrame fromView:self.window]);
    for (UIView *view = self; view; view = view.superview) {
        CALayer *layer = view.layer, *paint = layer.presentationLayer;
        [lines addObject:[NSString stringWithFormat:@"ancestor=%@ view=%p layer=%p frame=%@ hidden=%d alpha=%g stable=%d modelParentMatches=%d presentationParentMatches=%d parents=%p/%p/%p siblingsUnobscured=%d clipBefore=%@",
            NSStringFromClass(view.class), view, layer, NSStringFromCGRect(view.frame), view.hidden, (double)view.alpha,
            [self layerIsStable:layer requirePresentation:YES], layer.superlayer == view.superview.layer, paint.superlayer.modelLayer == view.superview.layer, layer.superlayer, paint.superlayer.modelLayer, view.superview.layer,
            view == self.window || [self layerChildrenAreUnobscured:layer.superlayer targets:[NSSet setWithObject:layer]], NSStringFromCGRect(visible)]];
        if (![self layerIsStable:layer requirePresentation:YES]) MTPAppendLayerDiagnostic(lines, layer, 4);
        if (layer.masksToBounds || view.clipsToBounds || [view isKindOfClass:UIScrollView.class]) {
            CGRect clip = layer.cornerRadius > 0 ? CGRectInset(layer.bounds, layer.cornerRadius, layer.cornerRadius) : layer.bounds;
            visible = CGRectIntersection(visible, [self.layer convertRect:clip fromLayer:layer]);
        }
        if (view == self.window) break;
    }
    [lines addObject:[NSString stringWithFormat:@"effectiveClip=%@ containsRequired=%d", NSStringFromCGRect(visible), CGRectContainsRect(visible, self.requiredActionRect)]];
    for (UIWindow *window in self.window.windowScene.windows) {
        [lines addObject:[NSString stringWithFormat:@"sceneWindow=%p current=%d key=%d level=%g currentLevel=%g hidden=%d alpha=%g frame=%@ mayCover=%d",
            window, window == self.window, window.isKeyWindow, (double)window.windowLevel, (double)self.window.windowLevel,
            window.hidden, (double)window.alpha, NSStringFromCGRect(window.frame), window != self.window && [self occluderMayCoverAction:window]]];
    }
    return [lines componentsJoinedByString:@"\n"];
}
- (void)installScenePaint {
    [super installScenePaint];
    if (self.injectLabelAnimation) {
        UILabel *label = [[self valueForKey:@"labels"] objectForKey:@"title"];
        MTPAddFrozenPaintAnimation(label.layer, @"position", [NSValue valueWithCGPoint:CGPointMake(label.layer.position.x, label.layer.position.y + 4096)]);
    }
}
@end

/// These fixtures require a real attached UIWindowScene. Pure scene assertions do
/// not substitute for the presentation-layer and visibility checks in this suite.
@interface MultiplicativePlaceValueBoardViewTests : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, weak) UIWindow *previousKeyWindow;
@property (nonatomic, strong) UIScrollView *viewport;
@property (nonatomic, strong) MTPNativeBoard *board;
@end
@implementation MultiplicativePlaceValueBoardViewTests
- (void)setUp {
    [super setUp]; UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState == UISceneActivationStateForegroundActive) { scene = (UIWindowScene *)candidate; break; }
    XCTAssertNotNil(scene, @"This suite must execute in the foreground application's real UIWindowScene.");
    for (UIWindow *window in scene.windows) if (window.isKeyWindow) self.previousKeyWindow = window;
    self.window = [[UIWindow alloc] initWithWindowScene:scene]; self.window.rootViewController = [[UIViewController alloc] init];
    // Keep the legitimate underlying app window untouched. A known higher level,
    // rather than key status or array order, certifies this test window is above it.
    self.window.windowLevel = self.previousKeyWindow.windowLevel + 1;
    self.window.rootViewController.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge; [self.window makeKeyAndVisible];
    [self.window layoutIfNeeded]; [self.window.rootViewController.view layoutIfNeeded];
    CGRect safe = self.window.rootViewController.view.safeAreaLayoutGuide.layoutFrame;
    self.viewport = [[UIScrollView alloc] initWithFrame:safe]; self.viewport.clipsToBounds = YES; [self.window.rootViewController.view addSubview:self.viewport];
    self.board = [[MTPNativeBoard alloc] initWithFrame:CGRectMake(0, 0, safe.size.width, safe.size.height)]; self.board.allowsMotion = YES;
    self.board.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge; [self.viewport addSubview:self.board];
    [self presentFrame]; XCTAssertEqual(self.board.window.windowScene, scene); XCTAssertGreaterThan(self.viewport.bounds.size.width, 0);
}
- (void)tearDown {
    if (self.board.visibilityFailureDiagnostic.length) {
        XCTAttachment *attachment = [XCTAttachment attachmentWithString:self.board.visibilityFailureDiagnostic];
        attachment.name = @"native-first-visibility-rejection";
        attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:attachment];
    }
    [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled];
    [self.board.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
    [self.board removeFromSuperview];
    self.window.hidden = YES; self.window.rootViewController = nil; [self.previousKeyWindow makeKeyWindow];
    self.board = nil; self.viewport = nil; self.window = nil; [super tearDown];
}
- (void)presentFrame {
    [self.window layoutIfNeeded]; [CATransaction flush];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.025]];
}
- (MultiplicativeTeachingActionPlan *)plan:(NSInteger)a op:(NSString *)op b:(NSInteger)b {
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:[op isEqualToString:@"×"] ? a * b : a / b];
    return [MultiplicativeTeachingActionPlan planForSequence:[MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem]];
}
- (MultiplicativeTeachingAction *)action:(MultiplicativeTeachingActionPlan *)plan kind:(MultiplicativeTeachingActionKind)kind column:(NSInteger)column last:(BOOL)last {
    MultiplicativeTeachingAction *found = nil;
    for (MultiplicativeTeachingAction *action in plan.actions) if (action.kind == kind && action.activeColumn == column) { found = action; if (!last) break; }
    XCTAssertNotNil(found); return found;
}
- (NSSet<NSNumber *> *)identifiers:(NSArray<MultiplicativeTeachingUnit *> *)units {
    NSMutableSet *ids = [NSMutableSet set]; for (MultiplicativeTeachingUnit *unit in units) [ids addObject:@(unit.identifier)]; return ids.copy;
}
- (NSDictionary<NSNumber *, UIView *> *)views { return [self.board valueForKey:@"unitViews"]; }
- (void)fitAction:(MultiplicativeTeachingAction *)action width:(CGFloat)width {
    [self fitAction:action width:width selectionID:[NSString stringWithFormat:@"%ld.%ld", (long)action.sourceStepIndex, (long)action.indexWithinStep]];
}
- (void)fitAction:(MultiplicativeTeachingAction *)action width:(CGFloat)width selectionID:(NSString *)selectionID {
    [self.board configureWithAction:action sessionID:@"native.plan" selectionID:selectionID endpoint:MTPPlaceValueEndpointBefore];
    CGSize size = [self.board sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)]; self.board.frame = (CGRect){CGPointZero, size}; self.viewport.contentSize = size; self.viewport.contentOffset = CGPointZero;
    [self.board setNeedsLayout]; [self.board layoutIfNeeded]; [self presentFrame];
}
- (void)startPaused {
    CGRect visible = [self.board convertRect:self.viewport.bounds fromView:self.viewport];
    XCTAssertEqual([self.board playInVisibleRect:visible], MTPPlaceValuePlaybackStateRunning, @"%@; required=%@ viewport=%@", self.board.scene.geometryFailure, NSStringFromCGRect(self.board.requiredActionRect), NSStringFromCGRect(visible));
    ((CADisplayLink *)[self.board valueForKey:@"clock"]).paused = YES; [self presentFrame];
}
- (void)render:(NSTimeInterval)elapsed {
    CADisplayLink *clock = [self.board valueForKey:@"clock"]; id transaction = [self.board valueForKey:@"transaction"];
    XCTAssertNotNil(clock); XCTAssertNotNil(transaction); [self.board renderElapsed:elapsed transaction:transaction clock:clock]; [self presentFrame];
    if ([self.board valueForKey:@"clock"]) XCTAssertTrue([self.board actualVisibilityContainsRequiredRect], @"Committed motion paint must pass the real next-tick visibility gate.");
}
- (NSDictionary<NSNumber *, NSValue *> *)actualFrames {
    NSMutableDictionary *frames = [NSMutableDictionary dictionary];
    for (NSNumber *identifier in self.views) {
        UIView *view = self.views[identifier]; CALayer *layer = view.layer.presentationLayer;
        XCTAssertNotNil(layer, @"An attached, committed native presentation layer is required for %@.", identifier);
        frames[identifier] = [NSValue valueWithCGRect:layer ? layer.frame : view.frame];
    }
    return frames.copy;
}
- (void)assertTypedMaterialAndReadableLabels {
    NSArray<UIView *> *views = self.views.allValues;
    for (UIView *view in views) {
        MultiplicativeTeachingUnit *unit = [view valueForKey:@"unit"];
        XCTAssertTrue(CGSizeEqualToSize(view.bounds.size, MTPPlaceValueBodySize(unit.column))); XCTAssertTrue(CGRectContainsRect(self.board.bounds, view.frame));
        XCTAssertFalse([view.accessibilityLabel containsString:@"答案是"]);
    }
    for (NSUInteger i = 0; i < views.count; i++) for (NSUInteger j = i + 1; j < views.count; j++) {
        CGRect overlap = CGRectIntersection(views[i].frame, views[j].frame);
        XCTAssertTrue(CGRectIsNull(overlap) || overlap.size.width <= .001 || overlap.size.height <= .001);
    }
    NSDictionary *labels = [self.board valueForKey:@"labels"];
    for (UILabel *label in labels.allValues) {
        CGFloat h = MTPPlaceValueTextHeight(label.text, label.font, label.bounds.size.width);
        XCTAssertLessThanOrEqual(h, label.bounds.size.height + .001, @"%@", label.text);
        XCTAssertFalse(label.adjustsFontSizeToFitWidth); XCTAssertEqual(label.numberOfLines, 0);
        XCTAssertTrue(CGRectContainsRect(self.board.bounds, label.frame));
        for (UIView *unit in views) XCTAssertFalse(CGRectIntersectsRect(unit.frame, label.frame));
    }
}
- (void)attachContainmentFailureForCategory:(UIContentSizeCategory)category width:(CGFloat)width {
    // Read the same original model frames as the acceptance assertions, before
    // the intentional insufficient-space playback replaces them with recovery.
    NSMutableArray<NSString *> *outside = [NSMutableArray array];
    MTPPlaceValueProjection *projection = [self.board valueForKey:@"projection"];
    NSMutableDictionary<NSNumber *, NSValue *> *expected = [NSMutableDictionary dictionary];
    for (MTPPlaceValueUnitPlacement *placement in projection.placements) expected[@(placement.unit.identifier)] = [NSValue valueWithCGRect:placement.frame];
    for (NSNumber *identifier in self.views) {
        UIView *view = self.views[identifier];
        if (!CGRectContainsRect(self.board.bounds, view.frame)) {
            MultiplicativeTeachingUnit *unit = [view valueForKey:@"unit"];
            [outside addObject:[NSString stringWithFormat:@"unit=%@ column=%ld frame=%@ expected=%@ body=%@ expectedBody=%@",
                identifier, (long)unit.column, NSStringFromCGRect(view.frame), expected[identifier], NSStringFromCGSize(view.bounds.size), NSStringFromCGSize(MTPPlaceValueBodySize(unit.column))]];
        }
    }
    NSDictionary<NSString *, UILabel *> *labels = [self.board valueForKey:@"labels"];
    for (NSString *key in labels) {
        UILabel *label = labels[key];
        if (!CGRectContainsRect(self.board.bounds, label.frame)) {
            [outside addObject:[NSString stringWithFormat:@"label=%@ frame=%@ expected=%@ font=%g category=%@",
                key, NSStringFromCGRect(label.frame), self.board.scene.labelFrames[key], (double)label.font.pointSize, label.traitCollection.preferredContentSizeCategory]];
        }
    }
    if (!outside.count) return;
    NSString *context = [NSString stringWithFormat:@"requestedCategory=%@ actualCategory=%@ width=%g boardFrame=%@ boardBounds=%@ required=%@ sceneWidth=%g sceneFont=%g sceneValid=%d geometryFailure=%@ fullSnapshot=%d viewport=%@ contentSize=%@\n%@",
        category, self.board.traitCollection.preferredContentSizeCategory, (double)width, NSStringFromCGRect(self.board.frame), NSStringFromCGRect(self.board.bounds), NSStringFromCGRect(self.board.requiredActionRect),
        (double)self.board.scene.width, (double)self.board.scene.font.pointSize, self.board.scene.geometryValid, self.board.scene.geometryFailure, self.board.displayingFullSnapshot,
        NSStringFromCGRect(self.viewport.bounds), NSStringFromCGSize(self.viewport.contentSize), [outside componentsJoinedByString:@"\n"]];
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:context];
    attachment.name = [NSString stringWithFormat:@"native-containment-%@-%g", category, (double)width];
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}
- (void)assertActualFramesMatch:(NSDictionary<NSNumber *, NSValue *> *)expected {
    NSDictionary *actual = [self actualFrames]; XCTAssertEqualObjects([NSSet setWithArray:actual.allKeys], [NSSet setWithArray:expected.allKeys]);
    for (NSNumber *identifier in expected) {
        CGRect a = [actual[identifier] CGRectValue], b = [expected[identifier] CGRectValue];
        XCTAssertEqualWithAccuracy(a.origin.x, b.origin.x, .01); XCTAssertEqualWithAccuracy(a.origin.y, b.origin.y, .01);
        XCTAssertEqualWithAccuracy(a.size.width, b.size.width, .01); XCTAssertEqualWithAccuracy(a.size.height, b.size.height, .01);
    }
}
- (void)assertPaintRect:(CGRect)actual equals:(CGRect)expected {
    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, .01); XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, .01);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, .01); XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, .01);
}
- (void)assertIndependentExchangePaint:(MultiplicativeTeachingAction *)action atTime:(NSTimeInterval)time {
    BOOL up = action.kind == MultiplicativeTeachingActionKindExchangeUp;
    BOOL dock = up ? (time >= 1.70 && time < 2.40) : (time >= .45 && time <= .80);
    BOOL midpoint = fabs(time - (up ? 1.075 : 1.425)) < .000001;
    if (!dock && !midpoint) return;
    NSArray<MultiplicativeTeachingUnit *> *small = up ? action.inputUnits : action.outputUnits; BOOL vertical = small.firstObject.column == 2;
    XCTAssertEqual(small.count, 10u); CGRect cradle = self.board.scene.cradleRect;
    XCTAssertEqualWithAccuracy(cradle.size.width, vertical ? 20 : 254, .01); XCTAssertEqualWithAccuracy(cradle.size.height, vertical ? 254 : 164, .01);
    CGSize body = vertical ? CGSizeMake(16,16) : CGSizeMake(16,160), largeBody = vertical ? CGSizeMake(16,160) : CGSizeMake(160,160);
    CGRect large = CGRectMake(CGRectGetMidX(cradle) - largeBody.width / 2, CGRectGetMidY(cradle) - largeBody.height / 2, largeBody.width, largeBody.height);
    NSDictionary *actual = [self actualFrames]; CGRect united = CGRectNull, previous = CGRectNull;
    for (NSUInteger i = 0; i < small.count; i++) {
        CGRect joined = CGRectMake(large.origin.x + (vertical ? 0 : i * 16), large.origin.y + (vertical ? i * 16 : 0), body.width, body.height);
        CGRect separated = CGRectMake(cradle.origin.x + 2 + (vertical ? 0 : i * 26), cradle.origin.y + 2 + (vertical ? i * 26 : 0), body.width, body.height);
        CGRect expected = joined; if (midpoint) expected.origin = CGPointMake((joined.origin.x + separated.origin.x) / 2, (joined.origin.y + separated.origin.y) / 2);
        CGRect painted = [actual[@(small[i].identifier)] CGRectValue]; [self assertPaintRect:painted equals:expected]; united = CGRectUnion(united, painted);
        if (dock && i) XCTAssertEqualWithAccuracy(vertical ? CGRectGetMaxY(previous) : CGRectGetMaxX(previous), vertical ? CGRectGetMinY(painted) : CGRectGetMinX(painted), .01);
        previous = painted;
    }
    if (dock) [self assertPaintRect:united equals:large];
}
- (void)testTrueScaleExchangeCellsAndAtomicLineageInAllFourDirections {
    NSArray *plans = @[[self plan:126 op:@"×" b:4], [self plan:108 op:@"÷" b:4]];
    NSMutableArray *actions = [NSMutableArray array];
    for (MultiplicativeTeachingActionPlan *plan in plans) for (MultiplicativeTeachingAction *action in plan.actions)
        if (action.kind == MultiplicativeTeachingActionKindExchangeUp || action.kind == MultiplicativeTeachingActionKindExchangeDown) [actions addObject:action];
    NSMutableSet *directions = [NSMutableSet set];
    for (MultiplicativeTeachingAction *action in actions) {
        NSString *direction = [NSString stringWithFormat:@"%ld.%ld", (long)action.sourceColumn, (long)action.destinationColumn]; if ([directions containsObject:direction]) continue; [directions addObject:direction];
        [self fitAction:action width:self.viewport.bounds.size.width]; XCTAssertTrue(self.board.scene.geometryValid); [self startPaused];
        [self assertActualFramesMatch:self.board.scene.beforeFrames];
        BOOL up = action.kind == MultiplicativeTeachingActionKindExchangeUp;
        for (NSNumber *time in (up ? @[@.45, @.7625, @1.075, @1.3875, @1.70, @2.399] : @[@.449, @.45, @.80, @1.1125, @1.425, @1.7375, @2.05])) {
            [self render:time.doubleValue]; [self assertTypedMaterialAndReadableLabels]; [self assertIndependentExchangePaint:action atTime:time.doubleValue]; [self actualFrames];
            NSSet *expected = [self identifiers:(!up && time.doubleValue >= .45) ? action.outputUnits : action.inputUnits];
            XCTAssertEqualObjects([NSSet setWithArray:self.views.allKeys], expected);
            MTPPlaceValueProjection *projection = [self.board valueForKey:@"projection"]; NSInteger value = 0; for (MTPPlaceValueUnitPlacement *placement in projection.placements) value += placement.unit.value;
            NSInteger beforeValue = 0; for (MultiplicativeTeachingUnit *unit in action.inputUnits) beforeValue += unit.value; XCTAssertEqual(value, beforeValue);
            if (!up) for (MultiplicativeTeachingUnit *original in action.before.unprocessedInput.columns[2]) XCTAssertEqualObjects(projection.ownersByIdentifier[@(original.identifier)], @"input");
        }
        if (up) { [self render:2.401]; XCTAssertEqualObjects([NSSet setWithArray:self.views.allKeys], [self identifiers:action.outputUnits]); }
        NSTimeInterval duration = self.board.scene.duration; [self render:duration]; [self assertActualFramesMatch:self.board.scene.afterFrames]; XCTAssertEqual(self.board.snapshot, action.after);
    }
    XCTAssertEqual(directions.count, 4u);
}
- (void)testGenerationBirthsAreSerialAndOriginalCarryIsNotGeneratedAgain {
    MultiplicativeTeachingActionPlan *plan = [self plan:99 op:@"×" b:9];
    for (NSNumber *last in @[@NO, @YES]) {
        MultiplicativeTeachingAction *action = [self action:plan kind:MultiplicativeTeachingActionKindGenerateGroup column:1 last:last.boolValue];
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused]; XCTAssertEqual(self.views.count, 0u);
        NSSet *carry = [self identifiers:action.ownedIncomingCarryUnits]; XCTAssertEqual(carry.count, 8u);
        NSDictionary *previous = @{};
        for (NSUInteger i = 0; i < action.outputUnits.count; i++) {
            [self render:.45 + i * .55 + .001]; XCTAssertEqual(self.views.count, i + 1);
            for (NSNumber *identifier in carry) XCTAssertNil(self.views[identifier]);
            NSDictionary *current = [self actualFrames]; for (NSNumber *identifier in previous) XCTAssertTrue(CGRectEqualToRect([previous[identifier] CGRectValue], [current[identifier] CGRectValue])); previous = current;
            MTPPlaceValueProjection *projection = [self.board valueForKey:@"projection"];
            for (NSNumber *identifier in carry) { XCTAssertEqualObjects(projection.ownersByIdentifier[identifier], @"accumulator"); XCTAssertNotNil(projection.ownedUnitsByIdentifier[identifier]); }
        }
        [self render:self.board.scene.duration]; XCTAssertEqual(self.board.snapshot, action.after);
        for (MultiplicativeTeachingUnit *unit in action.ownedIncomingCarryUnits) XCTAssertTrue([action.after.accumulator.columns[1] containsObject:unit]);
    }
}
- (void)testSerialTransfersPreserveIdentityOwnershipAndWholeSweptClearance {
    NSArray *fixtures = @[@[@101,@2,@1], @[@408,@4,@0], @[@899,@9,@1], @[@899,@9,@2], @[@108,@4,@2,@YES]];
    for (NSArray<NSNumber *> *fixture in fixtures) {
        MultiplicativeTeachingAction *action = [self action:[self plan:fixture[0].integerValue op:@"÷" b:fixture[1].integerValue] kind:fixture.count > 3 ? MultiplicativeTeachingActionKindBringDown : MultiplicativeTeachingActionKindDistributeRecipient column:fixture[2].integerValue last:NO];
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused];
        NSArray *order = self.board.scene.transferOrder; NSTimeInterval travel = [[self.board.scene valueForKey:@"travelDuration"] doubleValue]; NSDictionary *labels = [self.board valueForKey:@"labels"];
        for (NSUInteger i = 0; i < order.count; i++) for (NSNumber *fraction in @[@0.0,@.25,@.5,@.75,@1.0]) {
            [self render:.45 + i * (travel + .25) + fraction.doubleValue * travel]; NSDictionary *frames = [self actualFrames]; NSNumber *identifier = order[i]; CGRect moving = [frames[identifier] CGRectValue];
            for (NSNumber *other in frames) if (![other isEqual:identifier]) XCTAssertFalse(CGRectIntersectsRect(moving, CGRectInset([frames[other] CGRectValue], -8, -8)));
            for (UILabel *label in labels.allValues) XCTAssertFalse(CGRectIntersectsRect(moving, CGRectInset(label.frame, -8, -8)));
            NSString *sourceOwner = action.kind == MultiplicativeTeachingActionKindBringDown ? @"input" : @"pool";
            NSString *targetOwner = action.kind == MultiplicativeTeachingActionKindBringDown ? @"pool" : [NSString stringWithFormat:@"recipient.%ld", (long)action.recipientIndex];
            NSString *expectedOwner = fraction.doubleValue >= 1 ? targetOwner : sourceOwner;
            XCTAssertEqualObjects([self.views[identifier] valueForKey:@"owner"], expectedOwner);
            XCTAssertEqualObjects([NSSet setWithArray:self.views.allKeys], [self identifiers:action.inputUnits]);
        }
        [self render:self.board.scene.duration]; [self assertActualFramesMatch:self.board.scene.afterFrames];
    }
}
- (void)testReplayAndBackNextUseFreshBeforeOriginsAfterCompletedPresentation {
    MultiplicativeTeachingActionPlan *multiply = [self plan:126 op:@"×" b:4], *divide = [self plan:108 op:@"÷" b:4];
    NSMutableArray *actions = [NSMutableArray array];
    for (MultiplicativeTeachingActionPlan *plan in @[multiply, divide]) for (MultiplicativeTeachingAction *action in plan.actions) if (action.kind == MultiplicativeTeachingActionKindExchangeUp || action.kind == MultiplicativeTeachingActionKindExchangeDown) [actions addObject:action];
    [actions addObject:[self action:divide kind:MultiplicativeTeachingActionKindDistributeRecipient column:1 last:NO]];
    for (MultiplicativeTeachingAction *action in actions) {
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused]; NSDictionary *first = [self actualFrames]; id firstScene = self.board.scene;
        [self render:self.board.scene.duration]; [self startPaused]; XCTAssertNotEqual(self.board.scene, firstScene); [self assertActualFramesMatch:first];
        [self render:self.board.scene.duration]; [self.board showBeforeState]; [self.board showAfterState]; [self startPaused]; [self assertActualFramesMatch:first];
        CADisplayLink *abandonedClock = [self.board valueForKey:@"clock"]; id abandonedTransaction = [self.board valueForKey:@"transaction"], abandonedScene = self.board.scene;
        NSString *abandonedSelection = self.board.selectionID; NSUInteger generation = self.board.playbackGeneration;
        [self render:1.0];
        MultiplicativeTeachingActionPlan *plan = [multiply.actions containsObject:action] ? multiply : divide;
        NSUInteger next = [plan.actions indexOfObjectIdenticalTo:action] + 1;
        XCTAssertLessThan(next,plan.actions.count); if (next >= plan.actions.count) continue;
        MultiplicativeTeachingAction *away = plan.actions[next]; NSString *awayID = NSUUID.UUID.UUIDString;
        [self fitAction:away width:self.viewport.bounds.size.width selectionID:awayID];
        XCTAssertEqual(self.board.action,away); XCTAssertEqual(self.board.snapshot,away.before); XCTAssertEqualObjects(self.board.selectionID,awayID); XCTAssertNil([self.board valueForKey:@"clock"]);
        NSString *returnID = NSUUID.UUID.UUIDString;
        [self fitAction:action width:self.viewport.bounds.size.width selectionID:returnID]; [self startPaused];
        XCTAssertEqualObjects(self.board.selectionID,returnID); XCTAssertNotEqualObjects(self.board.selectionID,abandonedSelection); XCTAssertNotEqual(self.board.scene,abandonedScene); XCTAssertGreaterThan(self.board.playbackGeneration,generation);
        id returnedTransaction = [self.board valueForKey:@"transaction"]; CADisplayLink *returnedClock = [self.board valueForKey:@"clock"];
        [self assertActualFramesMatch:first]; XCTAssertEqual(self.board.snapshot,action.before);
        [self.board tick:abandonedClock transaction:abandonedTransaction]; [self.board renderElapsed:100 transaction:abandonedTransaction clock:abandonedClock]; [self.board advanceClockAtTimestamp:NAN transaction:abandonedTransaction clock:abandonedClock];
        XCTAssertEqual([self.board valueForKey:@"transaction"],returnedTransaction); XCTAssertEqual([self.board valueForKey:@"clock"],returnedClock); XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateRunning); XCTAssertEqual(self.board.snapshot,action.before);
        [self assertActualFramesMatch:first];
        [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled];
    }
}
- (void)testOldTicksCannotCrossCancellationSelectionOrReusedPlanIdentifiers {
    MultiplicativeTeachingAction *oldAction = [self action:[self plan:126 op:@"×" b:4] kind:MultiplicativeTeachingActionKindExchangeUp column:2 last:NO];
    for (NSNumber *time in @[@0.1,@1.0,@1.8,@2.399]) {
        [self fitAction:oldAction width:self.viewport.bounds.size.width]; [self startPaused]; [self render:time.doubleValue];
        CADisplayLink *oldClock = [self.board valueForKey:@"clock"]; id oldTransaction = [self.board valueForKey:@"transaction"]; NSUInteger generation = self.board.playbackGeneration;
        [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled]; XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.snapshot, oldAction.after);
        MultiplicativeTeachingAction *newAction = [self action:[self plan:3 op:@"×" b:2] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
        [self.board configureWithAction:newAction sessionID:@"another.plan" selectionID:@"another.selection" endpoint:MTPPlaceValueEndpointBefore];
        CGSize size = [self.board sizeThatFits:self.viewport.bounds.size]; self.board.frame = (CGRect){CGPointZero, size}; [self.board layoutIfNeeded]; [self presentFrame]; [self startPaused];
        id transaction = [self.board valueForKey:@"transaction"]; [self.board tick:oldClock transaction:oldTransaction]; [self.board renderElapsed:100 transaction:oldTransaction clock:oldClock]; [self.board advanceClockAtTimestamp:NAN transaction:oldTransaction clock:oldClock];
        XCTAssertEqual([self.board valueForKey:@"transaction"], transaction); XCTAssertEqual(self.board.action, newAction); XCTAssertEqual(self.board.snapshot, newAction.before); XCTAssertEqual(self.views.count, 0u); XCTAssertGreaterThan(self.board.playbackGeneration, generation);
    }
}
- (void)testWholeActionAdmissionChecksRealClipsOverlaysTransformsAndOnePointLoss {
    MultiplicativeTeachingAction *action = [self action:[self plan:1 op:@"×" b:1] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    [self fitAction:action width:MIN(320, self.viewport.bounds.size.width)]; CGRect exact = self.board.requiredActionRect;
    XCTAssertEqual([self.board playInVisibleRect:exact], MTPPlaceValuePlaybackStateRunning); [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled];
    [self fitAction:action width:exact.size.width]; XCTAssertEqual([self.board playInVisibleRect:CGRectMake(0,0,exact.size.width,exact.size.height-1)], MTPPlaceValuePlaybackStateInsufficientSpace); XCTAssertNil([self.board valueForKey:@"clock"]);
    [self fitAction:action width:exact.size.width]; CGRect old = self.viewport.frame; self.viewport.frame = CGRectMake(old.origin.x, old.origin.y, old.size.width, exact.size.height - 1);
    XCTAssertEqual([self.board playInVisibleRect:self.board.bounds], MTPPlaceValuePlaybackStateInsufficientSpace); self.viewport.frame = old;
    [self fitAction:action width:exact.size.width]; UIView *cover = [[UIView alloc] initWithFrame:CGRectMake(0,0,20,20)]; [self.viewport addSubview:cover];
    XCTAssertEqual([self.board playInVisibleRect:self.board.bounds], MTPPlaceValuePlaybackStateInsufficientSpace); [cover removeFromSuperview];
    [self fitAction:action width:exact.size.width]; self.viewport.transform = CGAffineTransformMakeScale(.9,.9);
    XCTAssertEqual([self.board playInVisibleRect:self.board.bounds], MTPPlaceValuePlaybackStateInsufficientSpace); self.viewport.transform = CGAffineTransformIdentity;
    [self fitAction:action width:exact.size.width]; [self.board removeFromSuperview]; XCTAssertEqual([self.board playInVisibleRect:self.board.bounds], MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.interruptionReason,MTPPlaceValueInterruptionReasonDetached);
}
- (void)testManualRecoveryScrollBackgroundResizeAndDetachNeverAutoResume {
    MultiplicativeTeachingAction *action = [self action:[self plan:1 op:@"×" b:1] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; [self startPaused]; self.viewport.contentOffset = CGPointMake(0,1); [self.board recheckVisibility];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.snapshot, action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
    self.viewport.contentOffset = CGPointZero; [self.board showBeforeState]; [self.board setNeedsLayout]; [self.board layoutIfNeeded]; [self presentFrame]; XCTAssertEqual(self.board.snapshot, action.before); XCTAssertNil([self.board valueForKey:@"clock"]);
    [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; [self startPaused]; [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
    XCTAssertEqual(self.board.interruptionReason, MTPPlaceValueInterruptionReasonBackground); XCTAssertNil([self.board valueForKey:@"clock"]);
    [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; [self startPaused]; CGRect frame = self.board.frame; frame.size.width -= 1; self.board.frame = frame; [self.board layoutIfNeeded];
    XCTAssertEqual(self.board.interruptionReason, MTPPlaceValueInterruptionReasonLayoutChanged); XCTAssertEqual(self.board.snapshot, action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
    [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; [self startPaused]; [self.board removeFromSuperview]; XCTAssertEqual(self.board.interruptionReason, MTPPlaceValueInterruptionReasonDetached); [self.viewport addSubview:self.board]; [self presentFrame]; XCTAssertNil([self.board valueForKey:@"clock"]);
}
- (void)testReducedMotionIsManualAndSeparateFromNaturalCompletion {
    MultiplicativeTeachingAction *action = [self action:[self plan:1 op:@"×" b:1] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    [self fitAction:action width:self.viewport.bounds.size.width]; self.board.allowsMotion = NO;
    XCTAssertEqual([self.board playInVisibleRect:self.board.bounds], MTPPlaceValuePlaybackStateReducedMotion); XCTAssertNil([self.board valueForKey:@"clock"]); XCTAssertTrue(self.board.displayingFullSnapshot);
    [self.board showBeforeState]; XCTAssertEqual(self.board.snapshot, action.before); [self.board showAfterState]; XCTAssertEqual(self.board.snapshot, action.after);
    self.board.allowsMotion = YES; [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil]; XCTAssertNil([self.board valueForKey:@"clock"]);
    [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused]; self.board.allowsMotion = NO; [NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    XCTAssertEqual(self.board.playbackState, MTPPlaceValuePlaybackStateReducedMotion); XCTAssertFalse([self.board.spokenDescription containsString:@"播放完了"]);
    // Dependency coverage only. Actual Settings/Reduce Motion change is a separate
    // native UI evidence gate; this injected value does not claim that pass.
}
- (void)testNaturalClockCompletionDoesNotAdvanceTheAction {
    self.board.captureVisibilityFailure = YES;
    MultiplicativeTeachingAction *action = [self action:[self plan:1 op:@"×" b:1] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    [self fitAction:action width:self.viewport.bounds.size.width]; XCTAssertEqual([self.board playInVisibleRect:self.board.bounds], MTPPlaceValuePlaybackStateRunning);
    XCTestExpectation *finished = [self expectationForPredicate:[NSPredicate predicateWithFormat:@"playbackState == %ld", (long)MTPPlaceValuePlaybackStateCompleted] evaluatedWithObject:self.board handler:nil];
    [self waitForExpectations:@[finished] timeout:5]; XCTAssertEqual(self.board.action, action); XCTAssertEqual(self.board.snapshot, action.after); XCTAssertNil([self.board valueForKey:@"clock"]); [self assertActualFramesMatch:self.board.scene.afterFrames];
}
- (void)testNeutralOverviewRendersAll170OwnedUnitsWithoutActionSelection {
    MultiplicativeTeachingActionPlan *plan = [self plan:899 op:@"÷" b:9]; MultiplicativeTeachingAction *action = [self action:plan kind:MultiplicativeTeachingActionKindBringDown column:2 last:NO];
    [self.board configureWithSnapshot:action.after sessionID:@"full.inventory"]; CGSize size = [self.board sizeThatFits:CGSizeMake(320,CGFLOAT_MAX)]; self.board.frame = (CGRect){CGPointZero,size}; self.viewport.contentSize = size; [self.board layoutIfNeeded];
    XCTAssertNil(self.board.action); XCTAssertNil(self.board.scene); XCTAssertNil(self.board.selectionID); XCTAssertTrue(CGRectIsNull(self.board.requiredActionRect)); XCTAssertEqual(self.views.count, 170u);
    NSMutableSet *expected = [NSMutableSet set]; NSDictionary *owners = MTPPlaceValueOwners(action.after);
    for (NSString *owner in owners) for (MultiplicativeTeachingUnit *unit in owners[owner]) { [expected addObject:@(unit.identifier)]; XCTAssertEqualObjects([self.views[@(unit.identifier)] valueForKey:@"owner"], owner); XCTAssertEqual([self.views[@(unit.identifier)] valueForKey:@"unit"], unit); }
    XCTAssertEqualObjects([NSSet setWithArray:self.views.allKeys], expected); [self assertTypedMaterialAndReadableLabels];
    MultiplicativeTeachingAction *firstDistribution = [self action:plan kind:MultiplicativeTeachingActionKindDistributeRecipient column:1 last:NO];
    [self.board configureWithSnapshot:firstDistribution.before sessionID:@"neutral.prediction"]; size = [self.board sizeThatFits:CGSizeMake(320,CGFLOAT_MAX)]; self.board.frame = (CGRect){CGPointZero,size}; [self.board layoutIfNeeded];
    XCTAssertNil(self.board.scene); XCTAssertNil(self.board.action); XCTAssertEqual(self.board.snapshot, firstDistribution.before); XCTAssertEqual(firstDistribution.before.pool.columns[1].count,89u);
    for (MultiplicativeTeachingUnit *unit in firstDistribution.inputUnits) { UIView *view = self.views[@(unit.identifier)]; XCTAssertEqualObjects([view valueForKey:@"owner"], @"pool"); XCTAssertFalse([[view valueForKey:@"carryAnnotation"] boolValue]); }
    NSDictionary *labels = [self.board valueForKey:@"labels"]; XCTAssertNil(labels[@"context"]); XCTAssertNil(labels[@"owner"]); XCTAssertNil(labels[@"phase"]); XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateStatic);
}
- (void)testSmallLargeWideAndUncappedMaximumTextKeepTrueScale {
    MultiplicativeTeachingAction *action = [self action:[self plan:126 op:@"×" b:4] kind:MultiplicativeTeachingActionKindExchangeUp column:1 last:NO];
    CGFloat ordinaryHeight = 0, ordinaryFont = 0;
    for (NSString *category in @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        self.board.traitOverrides.preferredContentSizeCategory = category;
        // UIKit updates an attached view's traits immediately before layout.
        // Finish that boundary before fitAction configures and measures fonts.
        [self.board setNeedsLayout]; [self.board layoutIfNeeded];
        XCTAssertEqualObjects(self.board.traitCollection.preferredContentSizeCategory, category);
        for (NSNumber *width in @[@288,@343,@700]) {
            [self fitAction:action width:width.doubleValue];
            [self attachContainmentFailureForCategory:category width:width.doubleValue];
            [self assertTypedMaterialAndReadableLabels];
            UILabel *label = [[self.board valueForKey:@"labels"] objectForKey:@"title"];
            if ([category isEqualToString:UIContentSizeCategoryLarge] && width.integerValue == 343) { ordinaryHeight = self.board.requiredActionRect.size.height; ordinaryFont = label.font.pointSize; }
            if ([category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge] && width.integerValue == 343) { XCTAssertGreaterThan(label.font.pointSize, ordinaryFont); XCTAssertGreaterThan(label.font.pointSize,28); XCTAssertGreaterThan(self.board.requiredActionRect.size.height,ordinaryHeight); }
            XCTAssertEqual([self.board playInVisibleRect:CGRectMake(0,0,width.doubleValue,120)],MTPPlaceValuePlaybackStateInsufficientSpace); XCTAssertTrue(self.board.displayingFullSnapshot); XCTAssertNil([self.board valueForKey:@"clock"]);
        }
    }
    [self.board.traitOverrides removeTrait:UITraitPreferredContentSizeCategory.class];
}
- (void)testStationaryZeroAndInspectActionsPreserveExactRevealBoundaries {
    NSMutableSet *kinds = [NSMutableSet set];
    for (NSArray *fixture in @[@[@0,@9,@"÷"], @[@101,@2,@"÷"], @[@408,@4,@"÷"], @[@104,@3,@"×"]]) {
        MultiplicativeTeachingActionPlan *plan = [self plan:[fixture[0] integerValue] op:fixture[2] b:[fixture[1] integerValue]];
        for (MultiplicativeTeachingAction *action in plan.actions) {
            [kinds addObject:@(action.kind)]; if (action.inputUnits.count || action.outputUnits.count) continue;
            [self fitAction:action width:MIN(343,self.viewport.bounds.size.width)]; XCTAssertEqual(self.board.snapshot,action.before); XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateStationary); XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
            [self.board showBeforeState]; XCTAssertEqualObjects(self.board.snapshot.visibleAnswerDigits,action.before.visibleAnswerDigits); XCTAssertEqualObjects(self.board.snapshot.visibleDivisionRows,action.before.visibleDivisionRows); XCTAssertEqualObjects(self.board.snapshot.visibleRemainder,action.before.visibleRemainder);
            [self.board showAfterState]; XCTAssertEqualObjects(self.board.snapshot.visibleAnswerDigits,action.after.visibleAnswerDigits);
            if (action.writeDisposition == MultiplicativeTeachingWriteDispositionSuppressedLeadingZero) XCTAssertEqualObjects(self.board.snapshot.visibleAnswerDigits[action.activeColumn],NSNull.null);
            if ([fixture[0] integerValue] == 0) XCTAssertEqual(self.views.count,0u);
            if (action.sourceStep.kind == MultiplicativeTeachingStepKindInspectRemainder) { XCTAssertNil(action.before.visibleRemainder); XCTAssertNotNil(action.after.visibleRemainder); }
            if (action.kind == MultiplicativeTeachingActionKindZeroGroups && action.activeColumn == 1) { XCTAssertEqual(self.views.count,action.after.accumulator.columns[0].count+action.after.accumulator.columns[1].count+action.after.accumulator.columns[2].count); XCTAssertEqual(action.after.accumulator.columns[1].count,1u); }
        }
    }
    XCTAssertTrue([kinds containsObject:@(MultiplicativeTeachingActionKindInspect)]); XCTAssertTrue([kinds containsObject:@(MultiplicativeTeachingActionKindZeroGroups)]); XCTAssertTrue([kinds containsObject:@(MultiplicativeTeachingActionKindZeroDistribution)]);
}
- (void)testAnimatedAncestorsAndUncommittedGeometryCannotCertifyVisibility {
    MultiplicativeTeachingAction *action = [self action:[self plan:1 op:@"×" b:1] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    for (NSString *key in @[@"position", @"transform"]) for (NSNumber *during in @[@NO, @YES]) {
        [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; if (during.boolValue) [self startPaused];
        CALayer *layer = [key isEqualToString:@"position"] ? self.viewport.layer : self.window.rootViewController.view.layer;
        id model = [layer valueForKeyPath:key];
        id destination = [key isEqualToString:@"position"] ? [NSValue valueWithCGPoint:CGPointMake(layer.position.x + 4096, layer.position.y)] : [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(4096,0,0)];
        MTPAddFrozenPaintAnimation(layer, key, destination); [self presentFrame];
        CALayer *paint = layer.presentationLayer; XCTAssertNotNil(paint); XCTAssertEqualObjects([layer valueForKeyPath:key],model); XCTAssertNotEqualObjects([paint valueForKeyPath:key],model);
        if (during.boolValue) { [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); }
        else XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace);
        XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
        [layer removeAnimationForKey:@"native.unstable.paint"]; [self presentFrame]; XCTAssertNil([self.board valueForKey:@"clock"]);
    }
    [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; [self startPaused];
    CGRect original = self.viewport.frame; CALayer *paint = self.viewport.layer.presentationLayer; XCTAssertNotNil(paint);
    [CATransaction begin]; [CATransaction setDisableActions:YES]; [CATransaction setAnimationDuration:7.25];
    @try {
        self.viewport.frame = CGRectOffset(original,1,0); XCTAssertEqual(self.viewport.layer.animationKeys.count,0u);
        XCTAssertFalse(CGPointEqualToPoint(self.viewport.layer.position,self.viewport.layer.presentationLayer.position));
        [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted);
        XCTAssertEqualWithAccuracy(CATransaction.animationDuration,7.25,.0001); // The caller's transaction was not drained.
    } @finally { [CATransaction commit]; }
    self.viewport.frame = original; [self presentFrame]; XCTAssertNil([self.board valueForKey:@"clock"]);

    // A normal UIView ancestor is supported, including its actual coordinates
    // and clips. This is the positive control, not raw backing-layer reparenting.
    [self fitAction:action width:MIN(320,self.viewport.bounds.size.width-8)];
    UIView *wrapperView = [[UIView alloc] initWithFrame:CGRectOffset(self.board.frame,4,4)]; [self.viewport addSubview:wrapperView]; [wrapperView addSubview:self.board];
    @try {
        [self presentFrame]; [self startPaused];
        XCTAssertEqual(self.board.layer.superlayer,wrapperView.layer); XCTAssertEqual(self.board.layer.presentationLayer.superlayer.modelLayer,wrapperView.layer);
        CGRect layerRect = [self.window.layer convertRect:self.board.requiredActionRect fromLayer:self.board.layer];
        CGRect viewRect = [self.board convertRect:self.board.requiredActionRect toView:self.window]; XCTAssertTrue(CGRectEqualToRect(layerRect,viewRect));
        CGRect clipped = wrapperView.bounds; clipped.size.height = self.board.requiredActionRect.size.height / 2;
        wrapperView.clipsToBounds = YES; wrapperView.bounds = clipped; [self presentFrame];
        XCTAssertNotNil(wrapperView.layer.presentationLayer); XCTAssertTrue(wrapperView.layer.presentationLayer.masksToBounds);
        XCTAssertLessThan(wrapperView.layer.presentationLayer.bounds.size.height,self.board.requiredActionRect.size.height);
        [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.snapshot,action.after);
    } @finally { [self.viewport addSubview:self.board]; [wrapperView removeFromSuperview]; [self presentFrame]; }
    XCTAssertNil([self.board valueForKey:@"clock"]);

    // Adversarial unsupported interposition, not a normal UIKit host or a
    // reproduced app defect. Even an opaque identity raw wrapper is refused.
    for (NSString *mode in @[@"opaque",@"attenuated",@"hidden",@"translated",@"clipped"]) for (NSNumber *during in @[@NO,@YES]) {
        [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; if (during.boolValue) [self startPaused];
        CALayer *parent = self.board.layer.superlayer, *wrapper = [CALayer layer]; UIView *viewParent = self.board.superview;
        NSUInteger index = [parent.sublayers indexOfObjectIdenticalTo:self.board.layer];
        [CATransaction begin]; [CATransaction setDisableActions:YES];
        @try {
            wrapper.frame = parent.bounds;
            if ([mode isEqualToString:@"attenuated"]) wrapper.opacity = .5;
            if ([mode isEqualToString:@"hidden"]) wrapper.hidden = YES;
            if ([mode isEqualToString:@"translated"]) wrapper.position = CGPointMake(wrapper.position.x+64,wrapper.position.y+16);
            if ([mode isEqualToString:@"clipped"]) { wrapper.masksToBounds = YES; wrapper.bounds = CGRectMake(0,0,8,8); }
            [parent insertSublayer:wrapper atIndex:(unsigned)index]; [wrapper addSublayer:self.board.layer];
        } @finally { [CATransaction commit]; }
        @try {
            [self presentFrame]; XCTAssertEqual(self.board.superview,viewParent); XCTAssertEqual(self.board.layer.superlayer,wrapper); XCTAssertNil(wrapper.delegate);
            if (!wrapper.hidden) { XCTAssertNotNil(wrapper.presentationLayer); XCTAssertEqualWithAccuracy(wrapper.presentationLayer.opacity,wrapper.opacity,.0001); }
            if (during.boolValue) { [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); }
            else XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace);
            XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
        } @finally {
            [CATransaction begin]; [CATransaction setDisableActions:YES];
            @try { [parent insertSublayer:self.board.layer atIndex:(unsigned)MIN(index,parent.sublayers.count)]; [wrapper removeFromSuperlayer]; }
            @finally { [CATransaction commit]; }
            [self presentFrame];
        }
        XCTAssertNil([self.board valueForKey:@"clock"]);
    }
}
- (void)testCaptionMaterialAndCradlePaintAnimationsAreRefused {
    MultiplicativeTeachingAction *action = [self action:[self plan:126 op:@"×" b:4] kind:MultiplicativeTeachingActionKindExchangeUp column:2 last:NO];
    [self fitAction:action width:self.viewport.bounds.size.width]; self.board.injectLabelAnimation = YES;
    XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace); XCTAssertNil([self.board valueForKey:@"clock"]); self.board.injectLabelAnimation = NO;
    for (NSString *target in @[@"caption", @"captionOpacity", @"captionTransform", @"captionChild", @"material", @"cradle"]) {
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused];
        UIView *view = [target hasPrefix:@"caption"] ? [[self.board valueForKey:@"labels"] objectForKey:@"title"] : ([target isEqualToString:@"cradle"] ? [self.board valueForKey:@"cradle"] : self.views.allValues.firstObject);
        CALayer *layer = view.layer;
        if ([target isEqualToString:@"captionChild"]) { layer = [CALayer layer]; layer.frame = CGRectMake(0,0,10,10); layer.backgroundColor = UIColor.redColor.CGColor; [view.layer addSublayer:layer]; [self presentFrame]; }
        NSString *key = [target isEqualToString:@"captionOpacity"] ? @"opacity" : ([target isEqualToString:@"captionTransform"] ? @"transform" : @"position");
        id model = [layer valueForKeyPath:key], destination = @0;
        if ([key isEqualToString:@"position"]) destination = [NSValue valueWithCGPoint:CGPointMake(layer.position.x,layer.position.y+4096)];
        if ([key isEqualToString:@"transform"]) destination = [NSValue valueWithCATransform3D:CATransform3DMakeScale(.1,.1,1)];
        MTPAddFrozenPaintAnimation(layer,key,destination); [self presentFrame];
        CALayer *paint = layer.presentationLayer; XCTAssertNotNil(paint); XCTAssertEqualObjects([layer valueForKeyPath:key],model); XCTAssertNotEqualObjects([paint valueForKeyPath:key],model);
        [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
        [layer removeAllAnimations]; [self presentFrame]; XCTAssertNil([self.board valueForKey:@"clock"]);
    }
}
- (void)testAnimatedSiblingAndSameLevelNonKeyWindowCannotBeSkipped {
    MultiplicativeTeachingAction *action = [self action:[self plan:1 op:@"×" b:1] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    for (NSNumber *during in @[@NO,@YES]) {
        [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; if (during.boolValue) [self startPaused];
        UIView *cover = [[UIView alloc] initWithFrame:CGRectMake(self.viewport.bounds.size.width+100,12,40,40)]; cover.backgroundColor = UIColor.redColor; [self.viewport addSubview:cover];
        CGPoint inside = CGPointMake(32,32), outside = cover.layer.position;
        // At the paused half-time, actual paint is inside while the model is outside.
        MTPAddFrozenPaintAnimation(cover.layer,@"position",[NSValue valueWithCGPoint:CGPointMake(2*inside.x-outside.x,2*inside.y-outside.y)]); [self presentFrame];
        XCTAssertFalse(CGRectIntersectsRect(cover.frame,self.board.requiredActionRect)); XCTAssertNotNil(cover.layer.presentationLayer); XCTAssertTrue(CGRectIntersectsRect(cover.layer.presentationLayer.frame,self.board.requiredActionRect));
        if (during.boolValue) { [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); }
        else XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace);
        [cover removeFromSuperview]; [self presentFrame]; XCTAssertNil([self.board valueForKey:@"clock"]);
    }
    UIWindow *overlay = [[UIWindow alloc] initWithWindowScene:self.window.windowScene]; overlay.rootViewController = [[UIViewController alloc] init]; overlay.rootViewController.view.backgroundColor = UIColor.redColor;
    @try {
        overlay.windowLevel = self.window.windowLevel - 1; overlay.hidden = NO; [self presentFrame];
        [self fitAction:action width:MIN(320,self.viewport.bounds.size.width)]; [self startPaused]; // Known lower levels remain allowed.
        overlay.windowLevel = self.window.windowLevel; [self presentFrame]; XCTAssertFalse(overlay.isKeyWindow); XCTAssertTrue(self.window.isKeyWindow);
        XCTAssertNotNil(overlay.layer.presentationLayer); [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertNil([self.board valueForKey:@"clock"]);
        XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace);
        overlay.hidden = YES; [self presentFrame]; XCTAssertNil([self.board valueForKey:@"clock"]);
    } @finally { overlay.hidden = YES; overlay.rootViewController = nil; }
}
- (CALayer *)addStandaloneCoverInsideBoard:(BOOL)inside z:(CGFloat)z first:(BOOL)first outside:(BOOL)outside hidden:(BOOL)hidden {
    CALayer *parent = inside ? self.board.layer : self.viewport.layer;
    CALayer *cover = [CALayer layer];
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    @try {
        cover.frame = [parent convertRect:self.board.requiredActionRect fromLayer:self.board.layer];
        if (outside) cover.frame = CGRectMake(CGRectGetMinX(cover.frame)+12,CGRectGetMaxY(cover.frame)+8,20,20);
        cover.backgroundColor = UIColor.redColor.CGColor; cover.opaque = YES; cover.zPosition = z; cover.hidden = hidden;
        if (first) [parent insertSublayer:cover atIndex:0]; else [parent addSublayer:cover];
    } @finally { [CATransaction commit]; }
    [self presentFrame]; XCTAssertNil(cover.delegate); return cover;
}
- (void)testStandaloneLayerCoversRefuseAdmissionAndInterruptButSafeLayersRemainAllowed {
    MultiplicativeTeachingAction *action = [self action:[self plan:126 op:@"×" b:4] kind:MultiplicativeTeachingActionKindExchangeUp column:2 last:NO];
    for (NSNumber *inside in @[@NO,@YES]) {
        for (NSNumber *during in @[@NO,@YES]) {
            [self fitAction:action width:self.viewport.bounds.size.width]; if (during.boolValue) [self startPaused];
            UIView *host = inside.boolValue ? self.board : self.viewport; NSArray *views = host.subviews.copy;
            CALayer *cover = [self addStandaloneCoverInsideBoard:inside.boolValue z:10 first:NO outside:NO hidden:NO];
            @try {
                XCTAssertEqualObjects(host.subviews,views); XCTAssertGreaterThan(self.views.count,0u); XCTAssertNotNil(cover.presentationLayer);
                CGRect actual = [self.board.layer convertRect:cover.presentationLayer.frame fromLayer:cover.superlayer];
                XCTAssertTrue(CGRectIntersectsRect(actual,self.views.allValues.firstObject.frame));
                if (during.boolValue) {
                    [self.board advanceClockAtTimestamp:100 transaction:[self.board valueForKey:@"transaction"] clock:[self.board valueForKey:@"clock"]];
                    XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted);
                } else XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace);
                XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]); XCTAssertFalse([self.board.spokenDescription containsString:@"播放完了"]);
            } @finally { [cover removeFromSuperlayer]; [self presentFrame]; }
            XCTAssertNil([self.board valueForKey:@"clock"]);
        }
        for (NSString *safe in @[@"hidden",@"belowIndex",@"belowZ",@"outside"]) {
            [self fitAction:action width:self.viewport.bounds.size.width];
            if ([safe isEqualToString:@"outside"]) {
                CGRect frame = self.board.frame; frame.size.height += 48; self.board.frame = frame; self.viewport.contentSize = frame.size;
                [self.board layoutIfNeeded]; [self presentFrame];
            }
            CALayer *cover = [self addStandaloneCoverInsideBoard:inside.boolValue z:[safe isEqualToString:@"belowZ"] ? -1 : ([safe isEqualToString:@"belowIndex"] ? 0 : 10)
                first:[safe isEqualToString:@"belowIndex"] outside:[safe isEqualToString:@"outside"] hidden:[safe isEqualToString:@"hidden"]];
            @try {
                [self startPaused]; XCTAssertTrue([self.board actualVisibilityContainsRequiredRect]);
                [self.board advanceClockAtTimestamp:100 transaction:[self.board valueForKey:@"transaction"] clock:[self.board valueForKey:@"clock"]];
                XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateRunning); XCTAssertEqual(self.board.snapshot,action.before);
            } @finally { [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled]; [cover removeFromSuperlayer]; [self presentFrame]; }
        }
    }
}
- (void)testStandaloneLayerPaintOrderAnimationsAndGuideMutationFailClosed {
    MultiplicativeTeachingAction *action = [self action:[self plan:126 op:@"×" b:4] kind:MultiplicativeTeachingActionKindExchangeUp column:2 last:NO];
    for (NSNumber *inside in @[@NO,@YES]) for (NSString *mode in @[@"sameZAbove",@"highZBelowIndex",@"animatedZ",@"animatedPosition",@"uncommittedReorder",@"uncommittedRemoval",@"uncommittedHiddenRemoval",@"uncommittedZeroOpacityRemoval",@"uncommittedDescendantRemoval"]) {
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused];
        CALayer *cover = [self addStandaloneCoverInsideBoard:inside.boolValue z:[mode isEqualToString:@"animatedZ"] ? -1 : ([mode isEqualToString:@"highZBelowIndex"] ? 10 : 0)
            first:[mode isEqualToString:@"highZBelowIndex"] outside:([mode isEqualToString:@"animatedPosition"] || [mode isEqualToString:@"uncommittedDescendantRemoval"]) hidden:NO];
        CALayer *parent = cover.superlayer, *descendant = nil;
        if ([mode isEqualToString:@"uncommittedDescendantRemoval"]) {
            descendant = [CALayer layer]; descendant.frame = [cover convertRect:self.board.requiredActionRect fromLayer:self.board.layer]; descendant.backgroundColor = UIColor.redColor.CGColor;
            [cover addSublayer:descendant]; [self presentFrame]; XCTAssertNotNil(descendant.presentationLayer);
        }
        @try {
            if ([mode isEqualToString:@"animatedZ"]) {
                MTPAddFrozenPaintAnimation(cover,@"zPosition",@3); [self presentFrame];
                XCTAssertEqual(cover.zPosition,-1); XCTAssertGreaterThan(cover.presentationLayer.zPosition,0);
            }
            if ([mode isEqualToString:@"animatedPosition"]) {
                CGRect target = [parent convertRect:self.board.requiredActionRect fromLayer:self.board.layer]; CGPoint center = CGPointMake(CGRectGetMidX(target),CGRectGetMidY(target));
                MTPAddFrozenPaintAnimation(cover,@"position",[NSValue valueWithCGPoint:CGPointMake(2*center.x-cover.position.x,2*center.y-cover.position.y)]); [self presentFrame];
                XCTAssertFalse(CGRectIntersectsRect(cover.frame,target)); XCTAssertTrue(CGRectIntersectsRect(cover.presentationLayer.frame,target));
            }
            BOOL pending = [mode hasPrefix:@"uncommitted"];
            if (pending) {
                XCTAssertEqual(parent.presentationLayer.sublayers.lastObject.modelLayer,cover);
                [CATransaction begin]; [CATransaction setDisableActions:YES]; [CATransaction setAnimationDuration:6.5];
            }
            @try {
                if ([mode isEqualToString:@"uncommittedReorder"]) [parent insertSublayer:cover atIndex:0];
                if ([mode isEqualToString:@"uncommittedRemoval"]) [cover removeFromSuperlayer];
                if ([mode isEqualToString:@"uncommittedHiddenRemoval"] || [mode isEqualToString:@"uncommittedZeroOpacityRemoval"]) {
                    if ([mode isEqualToString:@"uncommittedHiddenRemoval"]) cover.hidden = YES; else cover.opacity = 0;
                    [cover removeFromSuperlayer]; XCTAssertNil(cover.superlayer);
                    CALayer *oldPaint = nil;
                    for (CALayer *paint in parent.presentationLayer.sublayers) if (paint.modelLayer == cover) oldPaint = paint;
                    // Require the actual old paint. Do not assume whether a
                    // separate detached model.presentationLayer getter is nil.
                    XCTAssertNotNil(oldPaint); XCTAssertFalse(oldPaint.hidden); XCTAssertGreaterThan(oldPaint.opacity,0);
                }
                if ([mode isEqualToString:@"uncommittedDescendantRemoval"]) [descendant removeFromSuperlayer];
                XCTAssertNotNil(parent.presentationLayer); [self.board recheckVisibility];
                XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
                if (pending) XCTAssertEqualWithAccuracy(CATransaction.animationDuration,6.5,.0001);
            } @finally { if (pending) [CATransaction commit]; }
        } @finally { [cover removeAllAnimations]; [cover removeFromSuperlayer]; [self presentFrame]; }
        XCTAssertNil([self.board valueForKey:@"clock"]);
    }
    for (NSString *target in @[@"material",@"caption"]) for (NSNumber *hidden in @[@NO,@YES]) {
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused];
        UIView *surface = [target isEqualToString:@"material"] ? self.views.allValues.firstObject : [[self.board valueForKey:@"labels"] objectForKey:@"title"];
        CALayer *cover = [CALayer layer]; cover.frame = surface.bounds; cover.backgroundColor = UIColor.redColor.CGColor; cover.hidden = hidden.boolValue;
        [surface.layer addSublayer:cover]; [self presentFrame];
        if (!hidden.boolValue) XCTAssertNotNil(cover.presentationLayer);
        [self.board recheckVisibility];
        XCTAssertEqual(self.board.playbackState,hidden.boolValue ? MTPPlaceValuePlaybackStateRunning : MTPPlaceValuePlaybackStateInterrupted);
        [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled]; [cover removeFromSuperlayer]; [self presentFrame];
    }
    [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused]; UIView *cradle = [self.board valueForKey:@"cradle"];
    [CATransaction begin]; [CATransaction setDisableActions:YES]; cradle.layer.backgroundColor = UIColor.redColor.CGColor; [CATransaction commit]; [self presentFrame];
    CALayer *cradlePaint = cradle.layer.presentationLayer; XCTAssertNotNil(cradlePaint); XCTAssertTrue(cradlePaint.backgroundColor != NULL);
    if (cradlePaint.backgroundColor) XCTAssertGreaterThan(CGColorGetAlpha(cradlePaint.backgroundColor),0); [self.board recheckVisibility];
    XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertNil([self.board valueForKey:@"clock"]);
}
- (void)testZeroWidthSelectionReplacementRetiresSpeechBeforeLayout {
    MultiplicativeTeachingActionPlan *plan = [self plan:899 op:@"÷" b:9]; MultiplicativeTeachingAction *last = plan.actions.lastObject;
    [self fitAction:last width:self.viewport.bounds.size.width]; [self.board showAfterState]; NSString *oldSpeech = self.board.spokenDescription;
    CGRect frame = self.board.frame; frame.size.width = 0; self.board.frame = frame;
    MultiplicativeTeachingAction *firstDistribution = [self action:plan kind:MultiplicativeTeachingActionKindDistributeRecipient column:1 last:NO];
    [self.board configureWithSnapshot:firstDistribution.before sessionID:@"zero.width.neutral"];
    XCTAssertEqual(self.board.snapshot,firstDistribution.before); XCTAssertNil(self.board.action); XCTAssertNil(self.board.scene); XCTAssertNil(self.board.selectionID);
    XCTAssertEqualObjects(self.board.spokenDescription,firstDistribution.before.spokenDescription); XCTAssertEqualObjects(self.board.accessibilityValue,self.board.spokenDescription); XCTAssertNotEqualObjects(self.board.spokenDescription,oldSpeech);
    XCTAssertEqual(self.board.subviews.count,0u); XCTAssertNil([self.board valueForKey:@"clock"]);
    [self.board configureWithAction:firstDistribution sessionID:@"zero.width.action" selectionID:@"first.recipient" endpoint:MTPPlaceValueEndpointBefore];
    XCTAssertEqualObjects(self.board.spokenDescription,firstDistribution.spokenBefore); XCTAssertEqualObjects(self.board.accessibilityValue,self.board.spokenDescription); XCTAssertEqual(self.board.snapshot,firstDistribution.before);
    [self.board showAfterState]; XCTAssertEqualObjects(self.board.spokenDescription,firstDistribution.spokenAfter); XCTAssertEqualObjects(self.board.accessibilityValue,self.board.spokenDescription);
    [self.board configureWithSnapshot:plan.actions.firstObject.before sessionID:@"zero.width.start"]; XCTAssertEqualObjects(self.board.spokenDescription,plan.actions.firstObject.before.spokenDescription);
    CGSize restored = [self.board sizeThatFits:CGSizeMake(self.viewport.bounds.size.width,CGFLOAT_MAX)]; self.board.frame = (CGRect){CGPointZero,restored}; self.viewport.contentSize = restored; [self.board layoutIfNeeded]; [self presentFrame];
    XCTAssertNil(self.board.action); XCTAssertNil(self.board.scene); XCTAssertNil(self.board.selectionID); XCTAssertNil([self.board valueForKey:@"clock"]); XCTAssertEqual(self.board.snapshot,plan.actions.firstObject.before);
    XCTAssertEqualObjects(self.board.spokenDescription,plan.actions.firstObject.before.spokenDescription); XCTAssertEqualObjects(self.board.accessibilityValue,self.board.spokenDescription); XCTAssertNotEqualObjects(self.board.spokenDescription,oldSpeech);
    [self assertTypedMaterialAndReadableLabels];
    NSMutableSet *expected = [NSMutableSet set];
    for (NSArray *units in MTPPlaceValueOwners(self.board.snapshot).allValues) [expected unionSet:[self identifiers:units]];
    XCTAssertEqualObjects([NSSet setWithArray:self.views.allKeys],expected);
}
- (void)testForegroundClockHitchCannotSkipBirthsTransferOrDockingAndComplete {
    NSArray<MultiplicativeTeachingAction *> *actions = @[
        [self action:[self plan:9 op:@"×" b:9] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO],
        [self action:[self plan:101 op:@"÷" b:2] kind:MultiplicativeTeachingActionKindDistributeRecipient column:1 last:NO],
        [self action:[self plan:126 op:@"×" b:4] kind:MultiplicativeTeachingActionKindExchangeUp column:2 last:NO]];
    for (MultiplicativeTeachingAction *action in actions) {
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused];
        CADisplayLink *clock = [self.board valueForKey:@"clock"]; id transaction = [self.board valueForKey:@"transaction"];
        NSUInteger samples = action.kind == MultiplicativeTeachingActionKindExchangeUp ? 18 : 5;
        for (NSUInteger i = 0; i <= samples; i++) {
            [self.board advanceClockAtTimestamp:100 + i * .1 transaction:transaction clock:clock]; [self presentFrame];
            XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateRunning); XCTAssertEqual(self.board.snapshot,action.before);
        }
        if (action.kind == MultiplicativeTeachingActionKindGenerateGroup) XCTAssertEqual(self.views.count,1u);
        if (action.kind == MultiplicativeTeachingActionKindExchangeUp) [self assertIndependentExchangePaint:action atTime:1.8];
        NSUInteger generation = self.board.playbackGeneration;
        [self.board advanceClockAtTimestamp:100 + self.board.scene.duration + 10 transaction:transaction clock:clock];
        XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.interruptionReason,MTPPlaceValueInterruptionReasonVisibility);
        XCTAssertEqual(self.board.snapshot,action.after); XCTAssertTrue(self.board.displayingFullSnapshot); XCTAssertNil([self.board valueForKey:@"clock"]); XCTAssertGreaterThan(self.board.playbackGeneration,generation);
        XCTAssertFalse([self.board.spokenDescription containsString:@"播放完了"]); XCTAssertTrue([self.board.statusExplanation containsString:@"停頓"]);
        [self.board advanceClockAtTimestamp:1000 transaction:transaction clock:clock]; [self presentFrame]; XCTAssertNil([self.board valueForKey:@"clock"]);
        [self.board showBeforeState]; XCTAssertEqual(self.board.snapshot,action.before); XCTAssertNil([self.board valueForKey:@"clock"]);
    }
}
- (void)testFirstTickStartsFreshAndInvalidClockTimesNeverAdvance {
    MultiplicativeTeachingAction *action = [self action:[self plan:9 op:@"×" b:9] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused];
    CADisplayLink *clock = [self.board valueForKey:@"clock"]; id transaction = [self.board valueForKey:@"transaction"];
    // A late first callback establishes t=0, rather than catching up from play().
    [self.board advanceClockAtTimestamp:1000000000 transaction:transaction clock:clock]; [self presentFrame];
    XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateRunning); XCTAssertEqual(self.board.snapshot,action.before); XCTAssertEqual(self.views.count,0u);
    [self.board advanceClockAtTimestamp:1000000000 transaction:transaction clock:clock]; XCTAssertEqual(self.views.count,0u);
    for (NSUInteger i = 1; i <= 4; i++) { [self.board advanceClockAtTimestamp:1000000000 + i * .1 transaction:transaction clock:clock]; [self presentFrame]; XCTAssertEqual(self.views.count,0u); }
    [self.board advanceClockAtTimestamp:1000000000.451 transaction:transaction clock:clock]; [self presentFrame]; XCTAssertEqual(self.views.count,1u);
    [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled];
    NSArray<NSNumber *> *invalidTimes = @[@(NAN), @(INFINITY), @(-INFINITY), @0, @(-1), @99];
    for (NSNumber *time in invalidTimes) {
        [self fitAction:action width:self.viewport.bounds.size.width]; [self startPaused]; clock = [self.board valueForKey:@"clock"]; transaction = [self.board valueForKey:@"transaction"];
        if (time.doubleValue == 99) { [self.board advanceClockAtTimestamp:100 transaction:transaction clock:clock]; [self presentFrame]; }
        [self.board advanceClockAtTimestamp:time.doubleValue transaction:transaction clock:clock];
        XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
        XCTAssertTrue([self.board.statusExplanation containsString:@"無法確認"]); XCTAssertFalse([self.board.spokenDescription containsString:@"播放完了"]);
        [self.board advanceClockAtTimestamp:1000 transaction:transaction clock:clock]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertNil([self.board valueForKey:@"clock"]);
    }
}
@end
