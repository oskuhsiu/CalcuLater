#import <XCTest/XCTest.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "MultiplicativePlaceValueBoardView.h"
#import "MultiplicativePlaceValueScene.h"
#import "ChildUIKit.h"

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
// Fixture isolation only: never hide foreign windows or infer order from key status.
// Include a hidden model if its native presentation or animation may still paint.
static BOOL MTPFixtureWindowMayPaint(UIWindow *window) {
    CALayer *layer = window.layer, *paint = layer.presentationLayer;
    return layer.animationKeys.count || !((layer.hidden || layer.opacity <= 0)
        && (!paint || paint.hidden || paint.opacity <= 0));
}
static CGFloat MTPFixtureLevelAboveScene(UIWindowScene *scene, UIWindow *fixture) {
    CGFloat highest = UIWindowLevelNormal;
    for (UIWindow *window in scene.windows) if (window != fixture && MTPFixtureWindowMayPaint(window)) {
        if (!isfinite(window.windowLevel)) return NAN;
        highest = MAX(highest, window.windowLevel);
    }
    CGFloat level = highest + 1;
    return isfinite(level) && level > highest ? level : NAN;
}
static BOOL MTPFixtureHasStrictWindowOrder(UIWindow *fixture, UIWindowScene *scene) {
    if (!fixture || !scene || fixture.windowScene != scene || ![scene.windows containsObject:fixture]
        || !isfinite(fixture.windowLevel)) return NO;
    for (UIWindow *window in scene.windows) if (window != fixture && MTPFixtureWindowMayPaint(window)
        && (!isfinite(window.windowLevel) || !(fixture.windowLevel > window.windowLevel))) return NO;
    return YES;
}
// Only public, read-only metadata. Never load a root view or inspect UI text.
// Bound both the tree depth and the total visited nodes, including paint-only nodes.
static void MTPAppendWindowLayerDiagnostic(NSMutableArray<NSString *> *lines, CALayer *layer,
                                            NSUInteger depth, NSUInteger *remaining, BOOL presented) {
    if (!layer || !*remaining) return;
    --*remaining;
    CALayer *paint = presented ? layer : layer.presentationLayer;
    [lines addObject:[NSString stringWithFormat:@"windowLayer depth=%lu presented=%d class=%@ delegateClass=%@ model=%p frame=%@ bounds=%@ position=%@ hidden=%d opacity=%g z=%g clips=%d mask=%d contents=%d backgroundAlpha=%g shadow=%g animated=%d transformIdentity=%d sublayerTransformIdentity=%d; paint=%p modelLink=%d frame=%@ bounds=%@ position=%@ hidden=%d opacity=%g z=%g clips=%d mask=%d contents=%d backgroundAlpha=%g shadow=%g transformIdentity=%d sublayerTransformIdentity=%d children=%lu/%lu",
        (unsigned long)depth, presented, NSStringFromClass(layer.class), NSStringFromClass([(id)layer.delegate class]), layer.modelLayer,
        NSStringFromCGRect(layer.frame), NSStringFromCGRect(layer.bounds), NSStringFromCGPoint(layer.position), layer.hidden, (double)layer.opacity, (double)layer.zPosition,
        layer.masksToBounds, layer.mask != nil, layer.contents != nil, (double)(layer.backgroundColor ? CGColorGetAlpha(layer.backgroundColor) : 0), (double)layer.shadowOpacity, layer.animationKeys.count != 0,
        CATransform3DIsIdentity(layer.transform), CATransform3DIsIdentity(layer.sublayerTransform), paint, paint.modelLayer == (presented ? layer.modelLayer : layer),
        NSStringFromCGRect(paint.frame), NSStringFromCGRect(paint.bounds), NSStringFromCGPoint(paint.position), paint.hidden, (double)paint.opacity, (double)paint.zPosition,
        paint.masksToBounds, paint.mask != nil, paint.contents != nil, (double)(paint.backgroundColor ? CGColorGetAlpha(paint.backgroundColor) : 0), (double)paint.shadowOpacity,
        CATransform3DIsIdentity(paint.transform), CATransform3DIsIdentity(paint.sublayerTransform), (unsigned long)layer.sublayers.count, (unsigned long)paint.sublayers.count]];
    if (depth >= 3) return;
    for (CALayer *child in layer.sublayers) {
        if (!*remaining) break;
        MTPAppendWindowLayerDiagnostic(lines, child, depth + 1, remaining, presented);
    }
    if (!presented) for (CALayer *child in paint.sublayers) {
        if (!*remaining) break;
        if (!child.modelLayer || ![layer.sublayers containsObject:child.modelLayer])
            MTPAppendWindowLayerDiagnostic(lines, child, depth + 1, remaining, YES);
    }
}
static NSString *MTPFixtureWindowSnapshot(UIWindowScene *scene, UIWindow *fixture) {
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:
        @"sceneWindowSnapshot sceneState=%ld totalWindows=%lu windowLimit=16 layerNodesPerWindow=16 depthLimit=3",
        (long)scene.activationState, (unsigned long)scene.windows.count]];
    NSUInteger windows = 0;
    for (UIWindow *window in scene.windows) {
        if (windows++ == 16) { [lines addObject:@"additional windows omitted"]; break; }
        UIViewController *root = window.rootViewController; UIView *loadedRoot = root.viewIfLoaded;
        [lines addObject:[NSString stringWithFormat:@"sceneWindow=%p class=%@ current=%d key=%d level=%g hidden=%d alpha=%g frame=%@ potentiallyVisible=%d rootClass=%@ loadedRootClass=%@",
            window, NSStringFromClass(window.class), window == fixture, window.isKeyWindow, (double)window.windowLevel, window.hidden, (double)window.alpha,
            NSStringFromCGRect(window.frame), MTPFixtureWindowMayPaint(window), NSStringFromClass(root.class), NSStringFromClass(loadedRoot.class)]];
        NSUInteger remaining = 16;
        MTPAppendWindowLayerDiagnostic(lines, window.layer, 0, &remaining, NO);
        if (!remaining) [lines addObject:@"window layer node limit reached"];
    }
    return [lines componentsJoinedByString:@"\n"];
}
static NSString * const MTPNativeCoverMarker = @"mtp.native.standalone.cover";
// Serialize each CURRENT parent tree separately. A retained old presentation
// object would not prove that it remains in the current native paint tree.
static NSString *MTPCurrentParentPaintDiagnostic(CALayer *parent, CALayer *cover, NSString *phase) {
    CALayer *paint = parent.presentationLayer;
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:
        @"%@ parent=%p currentPaint=%p parentModelLink=%d modelChildren=%lu paintChildren=%lu cover=%p coverParent=%p coverHidden=%d coverOpacity=%g childLimit=256",
        phase, parent, paint, paint.modelLayer == parent, (unsigned long)parent.sublayers.count, (unsigned long)paint.sublayers.count,
        cover, cover.superlayer, cover.hidden, (double)cover.opacity]];
    NSArray<CALayer *> *children = paint.sublayers;
    NSUInteger count = 0, markerMatches = 0;
    for (CALayer *child in children) {
        if (count == 256) { [lines addObject:@"additional paint children omitted"]; break; }
        BOOL marked = [child.name isEqualToString:MTPNativeCoverMarker];
        if (marked) markerMatches++;
        [lines addObject:[NSString stringWithFormat:@"paintChild index=%lu identity=%p class=%@ model=%p modelClass=%@ isCover=%d markerMatches=%d inModelChildren=%d frame=%@ bounds=%@ hidden=%d opacity=%g z=%g backgroundAlpha=%g contents=%d mask=%d shadow=%g",
            (unsigned long)count, child, NSStringFromClass(child.class), child.modelLayer, NSStringFromClass(((CALayer *)child.modelLayer).class), child.modelLayer == cover, marked,
            child.modelLayer && [parent.sublayers containsObject:child.modelLayer], NSStringFromCGRect(child.frame), NSStringFromCGRect(child.bounds), child.hidden, (double)child.opacity, (double)child.zPosition,
            (double)(child.backgroundColor ? CGColorGetAlpha(child.backgroundColor) : 0), child.contents != nil, child.mask != nil, (double)child.shadowOpacity]];
        count++;
    }
    [lines addObject:[NSString stringWithFormat:@"enumerated=%lu complete=%d fixedMarkerMatches=%lu modelMarkerMatches=%d",
        (unsigned long)count, count == children.count, (unsigned long)markerMatches, [cover.name isEqualToString:MTPNativeCoverMarker]]];
    return [lines componentsJoinedByString:@"\n"];
}
// Observation only: current public trees are not a compositor/display fence.
// Fixed role/model links identify owned layers; detached getters are kept separate.
static NSString *MTPNativeCoverLayerState(CALayer *layer) {
    if (!layer) return @"exists=0";
    NSArray<NSString *> *keys = layer.animationKeys;
    NSMutableArray<NSString *> *boundedKeys = [NSMutableArray array];
    for (NSUInteger index = 0; index < MIN(keys.count,8u); index++)
        [boundedKeys addObject:[keys[index] substringToIndex:MIN(keys[index].length,80u)]];
    return [NSString stringWithFormat:@"exists=1 identity=%p model=%p parent=%p class=%@ frame=%@ bounds=%@ position=%@ anchor=%@ anchorZ=%g hidden=%d opacity=%g z=%g backgroundAlpha=%g contents=%d mask=%d shadow=%g clips=%d corner=%g transformIdentity=%d sublayerTransformIdentity=%d speed=%g timeOffset=%g beginTime=%g animationCount=%lu keysFirst8=%@",
        layer, layer.modelLayer, layer.superlayer, NSStringFromClass(layer.class), NSStringFromCGRect(layer.frame), NSStringFromCGRect(layer.bounds), NSStringFromCGPoint(layer.position), NSStringFromCGPoint(layer.anchorPoint), (double)layer.anchorPointZ,
        layer.hidden, (double)layer.opacity, (double)layer.zPosition, (double)(layer.backgroundColor ? CGColorGetAlpha(layer.backgroundColor) : 0), layer.contents != nil, layer.mask != nil, (double)layer.shadowOpacity,
        layer.masksToBounds, (double)layer.cornerRadius, CATransform3DIsIdentity(layer.transform), CATransform3DIsIdentity(layer.sublayerTransform), (double)layer.speed, layer.timeOffset, layer.beginTime, (unsigned long)keys.count, boundedKeys];
}
static BOOL MTPNativeCoverReachesRoot(CALayer *layer, CALayer *root) {
    if (!root) return NO;
    for (NSUInteger depth = 0; layer && depth < 16; depth++, layer = layer.superlayer) if (layer == root) return YES;
    return NO;
}
static void MTPAppendCoverGeometry(NSMutableArray<NSString *> *lines, NSString *role, CALayer *layer,
                                   CALayer *root, CGRect originalRequired, CGRect currentRequired) {
    BOOL connected = layer && MTPNativeCoverReachesRoot(layer,root);
    CGRect rect = connected ? [root convertRect:layer.bounds fromLayer:layer] : CGRectNull;
    [lines addObject:[NSString stringWithFormat:@"role=%@ %@ connectedToCurrentParentWithin16=%d rectInParent=%@ intersectsOriginalRequired=%d containsOriginalRequired=%d intersectsCurrentRequired=%d containsCurrentRequired=%d",
        role, MTPNativeCoverLayerState(layer), connected, NSStringFromCGRect(rect),
        connected && CGRectIntersectsRect(rect,originalRequired), connected && CGRectContainsRect(rect,originalRequired),
        connected && CGRectIntersectsRect(rect,currentRequired), connected && CGRectContainsRect(rect,currentRequired)]];
}
static void MTPAppendCoverChildren(NSMutableArray<NSString *> *lines, NSString *tree, NSArray<CALayer *> *children,
                                   NSArray<CALayer *> *modelChildren, CALayer *parent, CALayer *root,
                                   CALayer *board, CALayer *cover, CALayer *descendant, NSSet<CALayer *> *owned,
                                   CGRect originalRequired, CGRect currentRequired, BOOL presented) {
    NSUInteger count = 0, markers = 0, coverLinks = 0, descendantLinks = 0;
    for (CALayer *child in children) {
        if (count == 32) break;
        CALayer *model = presented ? child.modelLayer : child;
        BOOL marked = [child.name isEqualToString:MTPNativeCoverMarker];
        markers += marked; coverLinks += model == cover; descendantLinks += descendant && model == descendant;
        NSString *role = [NSString stringWithFormat:@"%@[%lu] parentLink=%d modelInCurrentChildren=%d fixedCoverMarker=%d isBoard=%d isCover=%d isDescendant=%d isOwnedRoot=%d",
            tree, (unsigned long)count, child.superlayer == parent, model && [modelChildren containsObject:model], marked,
            model == board, model == cover, descendant && model == descendant, model && [owned containsObject:model]];
        MTPAppendCoverGeometry(lines,role,child,root,originalRequired,currentRequired);
        count++;
    }
    [lines addObject:[NSString stringWithFormat:@"tree=%@ parent=%p parentExists=%d parentConnectedToCurrentRootWithin16=%d total=%lu enumerated=%lu complete=%d currentTreeFixedMarkerMatches=%lu currentTreeCoverModelLinks=%lu currentTreeDescendantModelLinks=%lu childLimit=32",
        tree, parent, parent != nil, MTPNativeCoverReachesRoot(parent,root), (unsigned long)children.count, (unsigned long)count, count == children.count, (unsigned long)markers, (unsigned long)coverLinks, (unsigned long)descendantLinks]];
}
static NSString *MTPNativeCoverObservation(MultiplicativePlaceValueBoardView *board, CALayer *parent,
                                          CALayer *cover, CALayer *descendant, MultiplicativeTeachingAction *action,
                                          void *originalClockIdentity, BOOL originalClockPaused, void *originalTransactionIdentity,
                                          CGRect originalRequired, NSString *mode, BOOL inside, NSString *phase) {
    CFTimeInterval monotonic = CACurrentMediaTime(); NSTimeInterval wall = NSDate.date.timeIntervalSince1970;
    CADisplayLink *clock = [board valueForKey:@"clock"]; id transaction = [board valueForKey:@"transaction"];
    CALayer *paint = parent.presentationLayer;
    NSArray<CALayer *> *modelChildren = parent.sublayers.copy, *paintChildren = paint.sublayers.copy;
    CALayer *coverPaint = nil, *boardPaint = parent == board.layer ? paint : nil;
    // Match only the freshly read CURRENT parent's children, never a retained getter.
    for (NSUInteger index = 0; index < MIN(paintChildren.count,32u); index++) { CALayer *child = paintChildren[index]; if (child.modelLayer == cover) coverPaint = child; if (child.modelLayer == board.layer) boardPaint = child; }
    BOOL modelConnected = MTPNativeCoverReachesRoot(board.layer,parent), paintConnected = MTPNativeCoverReachesRoot(boardPaint,paint);
    CGRect required = board.requiredActionRect;
    CGRect modelOriginal = modelConnected ? [parent convertRect:originalRequired fromLayer:board.layer] : CGRectNull;
    CGRect modelRequired = modelConnected ? [parent convertRect:required fromLayer:board.layer] : CGRectNull;
    CGRect paintOriginal = paintConnected ? [paint convertRect:originalRequired fromLayer:boardPaint] : CGRectNull;
    CGRect paintRequired = paintConnected ? [paint convertRect:required fromLayer:boardPaint] : CGRectNull;
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:
        @"case mode=%@ inside=%d phase=%@ monotonic=%.9f wallUnix=%.6f state=%ld interruption=%ld generation=%lu endpoint=%ld fullSnapshot=%d action=%p originalAction=%p sameAction=%d snapshot=%p originalBefore=%p originalAfter=%p snapshotIsBefore=%d snapshotIsAfter=%d clock=%p originalClock=%p sameOriginalClock=%d clockExists=%d clockPaused=%d originalClockWasPaused=%d transaction=%p originalTransaction=%p sameOriginalTransaction=%d callerDisableActions=%d callerDuration=%g",
        mode, inside, phase, monotonic, wall, (long)board.playbackState, (long)board.interruptionReason, (unsigned long)board.playbackGeneration, (long)board.endpoint, board.displayingFullSnapshot,
        board.action, action, board.action == action, board.snapshot, action.before, action.after, board.snapshot == action.before, board.snapshot == action.after,
        clock, originalClockIdentity, clock && (__bridge void *)clock == originalClockIdentity, clock != nil, clock ? clock.paused : NO, originalClockPaused,
        transaction, originalTransactionIdentity, transaction && (__bridge void *)transaction == originalTransactionIdentity, CATransaction.disableActions, CATransaction.animationDuration]];
    [lines addObject:[NSString stringWithFormat:@"geometry boardFrame=%@ boardBounds=%@ originalRequiredInBoard=%@ currentRequiredInBoard=%@ requestedInBoard=%@ modelBoardConnected=%d paintBoardConnected=%d originalRequiredInModelParent=%@ currentRequiredInModelParent=%@ originalRequiredInPaintParent=%@ currentRequiredInPaintParent=%@ boardClips=%d retainedCoverNameMatches=%d retainedCoverAttachedToModelParent=%d retainedDescendantAttachedToCover=%d legacyModelMarkerMatchesMeansRetainedNameOnly=1",
        NSStringFromCGRect(board.frame), NSStringFromCGRect(board.bounds), NSStringFromCGRect(originalRequired), NSStringFromCGRect(required), NSStringFromCGRect([[board valueForKey:@"requestedVisibleRect"] CGRectValue]),
        modelConnected, paintConnected, NSStringFromCGRect(modelOriginal), NSStringFromCGRect(modelRequired), NSStringFromCGRect(paintOriginal), NSStringFromCGRect(paintRequired), board.clipsToBounds,
        [cover.name isEqualToString:MTPNativeCoverMarker], cover.superlayer == parent, descendant && descendant.superlayer == cover]];
    NSSet<CALayer *> *owned = [board ownedRootLayers];
    MTPAppendCoverGeometry(lines,@"modelBoard",board.layer,parent,modelOriginal,modelRequired);
    MTPAppendCoverGeometry(lines,@"currentTreeBoardPaint",boardPaint,paint,paintOriginal,paintRequired);
    MTPAppendCoverGeometry(lines,@"retainedModelCover",cover,parent,modelOriginal,modelRequired);
    MTPAppendCoverGeometry(lines,@"currentTreeCoverPaint",coverPaint,paint,paintOriginal,paintRequired);
    MTPAppendCoverGeometry(lines,@"coverPresentationGetterNotMembershipProof",cover.presentationLayer,paint,paintOriginal,paintRequired);
    MTPAppendCoverGeometry(lines,@"retainedModelDescendant",descendant,parent,modelOriginal,modelRequired);
    MTPAppendCoverGeometry(lines,@"descendantPresentationGetterNotMembershipProof",descendant.presentationLayer,paint,paintOriginal,paintRequired);
    MTPAppendCoverChildren(lines,@"parent.model",modelChildren,modelChildren,parent,parent,board.layer,cover,descendant,owned,modelOriginal,modelRequired,NO);
    MTPAppendCoverChildren(lines,@"parent.currentPaint",paintChildren,modelChildren,paint,paint,board.layer,cover,descendant,owned,paintOriginal,paintRequired,YES);
    if (descendant) {
        NSArray<CALayer *> *descendantModels = cover.sublayers.copy, *descendantPaints = coverPaint.sublayers.copy;
        MTPAppendCoverChildren(lines,@"cover.retainedModelChildren",descendantModels,descendantModels,cover,parent,board.layer,cover,descendant,owned,modelOriginal,modelRequired,NO);
        MTPAppendCoverChildren(lines,@"cover.currentTreePaintChildren",descendantPaints,descendantModels,coverPaint,paint,board.layer,cover,descendant,owned,paintOriginal,paintRequired,YES);
    }
    for (NSNumber *presented in @[@NO,@YES]) {
        CALayer *ancestor = presented.boolValue ? paint : parent; NSUInteger depth = 0;
        for (; ancestor && depth < 8; depth++, ancestor = ancestor.superlayer)
            [lines addObject:[NSString stringWithFormat:@"parentAncestry presented=%d depth=%lu %@", presented.boolValue, (unsigned long)depth, MTPNativeCoverLayerState(ancestor)]];
        [lines addObject:[NSString stringWithFormat:@"parentAncestry presented=%d enumerated=%lu complete=%d depthLimit=8", presented.boolValue, (unsigned long)depth, ancestor == nil]];
    }
    [lines addObject:[NSString stringWithFormat:@"observationEnd monotonic=%.9f wallUnix=%.6f publicTreesOnly=1 pixelsNotEstablished=1", CACurrentMediaTime(), NSDate.date.timeIntervalSince1970]];
    return [lines componentsJoinedByString:@"\n"];
}
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
// Shared read-only rejection capture for real board and controller fixtures.
NSString *MTPNativeVisibilityDiagnostic(MultiplicativePlaceValueBoardView *board) {
    CGRect requested = [[board valueForKey:@"requestedVisibleRect"] CGRectValue];
    CADisplayLink *clock = [board valueForKey:@"clock"];
    id transaction = [board valueForKey:@"transaction"];
    BOOL requiresPaint = clock != nil;
    NSDictionary<NSNumber *, UIView *> *units = [board valueForKey:@"unitViews"];
    NSDictionary<NSString *, UILabel *> *labels = [board valueForKey:@"labels"];
    MTPPlaceValueProjection *projection = [board valueForKey:@"projection"];
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:
        @"visibility rejection applicationState=%ld sceneState=%ld sceneBounds=%@ windowBounds=%@ windowSafe=%@ boardBounds=%@ required=%@ requested=%@ category=%@ sceneWidth=%g sceneValid=%d geometryFailure=%@ installedPaintLawful=%d requiresPresentation=%d units=%lu/%lu labels=%lu/%lu",
        (long)UIApplication.sharedApplication.applicationState, (long)board.window.windowScene.activationState,
        NSStringFromCGRect(board.window.windowScene.coordinateSpace.bounds), NSStringFromCGRect(board.window.bounds), NSStringFromCGRect(board.window.safeAreaLayoutGuide.layoutFrame),
        NSStringFromCGRect(board.bounds), NSStringFromCGRect(board.requiredActionRect), NSStringFromCGRect(requested), board.traitCollection.preferredContentSizeCategory,
        (double)board.scene.width, board.scene.geometryValid, board.scene.geometryFailure, [board installedPaintIsLawful], requiresPaint,
        (unsigned long)units.count, (unsigned long)projection.placements.count, (unsigned long)labels.count, (unsigned long)board.scene.labelFrames.count]];
    [lines addObject:[NSString stringWithFormat:@"playback monotonic=%.9f state=%ld interruption=%ld generation=%lu revision=%lu endpoint=%ld fullSnapshot=%d clock=%p transaction=%p startTimestamp=%@ lastTimestamp=%@ snapshotIsBefore=%d snapshotIsAfter=%d",
        CACurrentMediaTime(), (long)board.playbackState, (long)board.interruptionReason, (unsigned long)board.playbackGeneration,
        (unsigned long)board.layoutRevision, (long)board.endpoint, board.displayingFullSnapshot, clock, transaction,
        [board valueForKey:@"startTimestamp"], [board valueForKey:@"lastTimestamp"], board.snapshot == board.action.before, board.snapshot == board.action.after]];
    for (MTPPlaceValueUnitPlacement *placement in projection.placements) {
        UIView *view = units[@(placement.unit.identifier)];
        [lines addObject:[NSString stringWithFormat:@"unit=%lu exists=%d attached=%d/%d unitIdentity=%d owner=%@/%@ carry=%@/%d frame=%@/%@ body=%@/%@ stable=%d paintTreeStable=%d noAdditionalPaint=%d inRequired=%d",
            (unsigned long)placement.unit.identifier, view != nil, view.superview == board, view.layer.superlayer == board.layer, [view valueForKey:@"unit"] == placement.unit, [view valueForKey:@"owner"], placement.owner,
            [view valueForKey:@"carryAnnotation"], placement.carryAnnotation, NSStringFromCGRect(view.frame), NSStringFromCGRect(placement.frame), NSStringFromCGSize(view.bounds.size), NSStringFromCGSize(MTPPlaceValueBodySize(placement.unit.column)),
            [board layerIsStable:view.layer requirePresentation:requiresPaint], [board paintTreeIsStable:view.layer requirePresentation:requiresPaint], [board ownedSurfaceHasNoAdditionalPaint:view.layer],
            CGRectContainsRect(board.requiredActionRect, view.layer.presentationLayer ? ((CALayer *)view.layer.presentationLayer).frame : view.frame)]];
        MTPAppendLayerDiagnostic(lines, view.layer, 0);
    }
    for (NSString *key in board.scene.labelFrames) {
        UILabel *label = labels[key];
        [lines addObject:[NSString stringWithFormat:@"label=%@ exists=%d attached=%d/%d textMatches=%d shrink=%d textShadow=%@ frame=%@/%@ font=%g/%g measuredHeight=%g stable=%d paintTreeStable=%d noAdditionalPaint=%d",
            key, label != nil, label.superview == board, label.layer.superlayer == board.layer, [label.text isEqualToString:projection.labelTexts[key]], label.adjustsFontSizeToFitWidth, label.shadowColor, NSStringFromCGRect(label.frame), NSStringFromCGRect(board.scene.labelFrames[key].CGRectValue),
            (double)label.font.pointSize, (double)board.scene.font.pointSize, (double)(label.font ? MTPPlaceValueTextHeight(label.text ?: @"", label.font, label.bounds.size.width) : NAN),
            [board layerIsStable:label.layer requirePresentation:requiresPaint], [board paintTreeIsStable:label.layer requirePresentation:requiresPaint], [board ownedSurfaceHasNoAdditionalPaint:label.layer]]];
        MTPAppendLayerDiagnostic(lines, label.layer, 0);
    }
    UIView *cradle = [board valueForKey:@"cradle"];
    [lines addObject:[NSString stringWithFormat:@"cradle=%@ expected=%@ knownGuide=%d ownedRootsUnobscured=%d",
        cradle, NSStringFromCGRect(board.scene.cradleRect), cradle && [board cradleHasOnlyKnownGuidePaint], [board layerChildrenAreUnobscured:board.layer targets:[board ownedRootLayers]]]];
    if (cradle) MTPAppendLayerDiagnostic(lines, cradle.layer, 0);
    CGRect visible = CGRectIntersection(board.bounds, requested);
    visible = CGRectIntersection(visible, [board convertRect:board.window.bounds fromView:board.window]);
    visible = CGRectIntersection(visible, [board convertRect:board.window.safeAreaLayoutGuide.layoutFrame fromView:board.window]);
    for (UIView *view = board; view; view = view.superview) {
        CALayer *layer = view.layer, *paint = layer.presentationLayer;
        [lines addObject:[NSString stringWithFormat:@"ancestor=%@ view=%p layer=%p frame=%@ hidden=%d alpha=%g stable=%d modelParentMatches=%d presentationParentMatches=%d parents=%p/%p/%p siblingsUnobscured=%d clipBefore=%@",
            NSStringFromClass(view.class), view, layer, NSStringFromCGRect(view.frame), view.hidden, (double)view.alpha,
            [board layerIsStable:layer requirePresentation:YES], layer.superlayer == view.superview.layer, paint.superlayer.modelLayer == view.superview.layer, layer.superlayer, paint.superlayer.modelLayer, view.superview.layer,
            view == board.window || [board layerChildrenAreUnobscured:layer.superlayer targets:[NSSet setWithObject:layer]], NSStringFromCGRect(visible)]];
        if (![board layerIsStable:layer requirePresentation:YES]) MTPAppendLayerDiagnostic(lines, layer, 4);
        if (layer.masksToBounds || view.clipsToBounds || [view isKindOfClass:UIScrollView.class]) {
            CGRect clip = layer.cornerRadius > 0 ? CGRectInset(layer.bounds, layer.cornerRadius, layer.cornerRadius) : layer.bounds;
            visible = CGRectIntersection(visible, [board.layer convertRect:clip fromLayer:layer]);
        }
        if ([view isKindOfClass:UIScrollView.class]) {
            UIScrollView *scroll = (UIScrollView *)view;
            [lines addObject:[NSString stringWithFormat:@"scroll=%p bounds=%@ offset=%@ dragging=%d tracking=%d decelerating=%d",
                scroll, NSStringFromCGRect(scroll.bounds), NSStringFromCGPoint(scroll.contentOffset), scroll.dragging, scroll.tracking, scroll.decelerating]];
        }
        if (view == board.window) break;
    }
    [lines addObject:[NSString stringWithFormat:@"effectiveClip=%@ containsRequired=%d", NSStringFromCGRect(visible), CGRectContainsRect(visible, board.requiredActionRect)]];
    for (UIWindow *window in board.window.windowScene.windows) {
        [lines addObject:[NSString stringWithFormat:@"sceneWindow=%p current=%d key=%d level=%g currentLevel=%g hidden=%d alpha=%g frame=%@ mayCover=%d",
            window, window == board.window, window.isKeyWindow, (double)window.windowLevel, (double)board.window.windowLevel,
            window.hidden, (double)window.alpha, NSStringFromCGRect(window.frame), window != board.window && [board occluderMayCoverAction:window]]];
    }
    NSArray<UIScrollView *> *scrolls = [transaction valueForKey:@"scrollViews"];
    NSArray<NSValue *> *offsets = [transaction valueForKey:@"scrollOffsets"];
    for (NSUInteger index = 0; index < scrolls.count; index++)
        [lines addObject:[NSString stringWithFormat:@"capturedScroll=%p currentOffset=%@ originalOffset=%@ matches=%d",
            scrolls[index], NSStringFromCGPoint(scrolls[index].contentOffset), offsets[index], CGPointEqualToPoint(scrolls[index].contentOffset, offsets[index].CGPointValue)]];
    for (UIViewController *presented = board.window.rootViewController.presentedViewController; presented; presented = presented.presentedViewController) {
        UIView *view = presented.viewIfLoaded;
        [lines addObject:[NSString stringWithFormat:@"presentedController=%p loadedView=%p sameWindow=%d boardDescendant=%d mayCover=%d",
            presented, view, view && view.window == board.window, view && [board isDescendantOfView:view], view && [board occluderMayCoverAction:view]]];
    }
    [lines addObject:MTPFixtureWindowSnapshot(board.window.windowScene, board.window)];
    return [lines componentsJoinedByString:@"\n"];
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
- (NSString *)visibilityDiagnostic { return MTPNativeVisibilityDiagnostic(self); }

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
@interface MultiplicativePlaceValueBoardViewTests : XCTestCase {
    NSString *_preElevationWindowDiagnostic;
}
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
    if (!scene) return;
    for (UIWindow *window in scene.windows) if (window.isKeyWindow) self.previousKeyWindow = window;
    _preElevationWindowDiagnostic = MTPFixtureWindowSnapshot(scene, nil);
    self.window = [[UIWindow alloc] initWithWindowScene:scene]; self.window.rootViewController = [[UIViewController alloc] init];
    CGFloat fixtureLevel = MTPFixtureLevelAboveScene(scene, self.window);
    XCTAssertTrue(isfinite(fixtureLevel), @"No finite strictly higher fixture level: %@", _preElevationWindowDiagnostic);
    if (!isfinite(fixtureLevel)) return;
    // Set the owned window once. Later higher windows must fail, never cause a raise.
    self.window.windowLevel = fixtureLevel;
    XCTAssertTrue(MTPFixtureHasStrictWindowOrder(self.window, scene), @"%@", MTPFixtureWindowSnapshot(scene, self.window));
    self.window.rootViewController.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge; [self.window makeKeyAndVisible];
    XCTAssertTrue(MTPFixtureHasStrictWindowOrder(self.window, scene), @"Order changed during makeKeyAndVisible: %@", MTPFixtureWindowSnapshot(scene, self.window));
    [self.window layoutIfNeeded]; [self.window.rootViewController.view layoutIfNeeded];
    CGRect safe = self.window.rootViewController.view.safeAreaLayoutGuide.layoutFrame;
    self.viewport = [[UIScrollView alloc] initWithFrame:safe]; self.viewport.clipsToBounds = YES; [self.window.rootViewController.view addSubview:self.viewport];
    self.board = [[MTPNativeBoard alloc] initWithFrame:CGRectMake(0, 0, safe.size.width, safe.size.height)]; self.board.allowsMotion = YES;
    self.board.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge; [self.viewport addSubview:self.board];
    [self presentFrame]; XCTAssertEqual(self.board.window.windowScene, scene); XCTAssertGreaterThan(self.viewport.bounds.size.width, 0);
    XCTAssertEqual(scene.activationState, UISceneActivationStateForegroundActive);
    XCTAssertTrue(MTPFixtureHasStrictWindowOrder(self.window, scene), @"Order changed after native presentation: %@", MTPFixtureWindowSnapshot(scene, self.window));
    CALayer *paint = self.window.layer.presentationLayer;
    XCTAssertNotNil(paint); XCTAssertEqual(paint.modelLayer, self.window.layer); XCTAssertFalse(paint.hidden); XCTAssertGreaterThan(paint.opacity, 0);
}
- (void)tearDown {
    if (_preElevationWindowDiagnostic.length && (self.board.captureVisibilityFailure || self.testRun.failureCount)) {
        XCTAttachment *attachment = [XCTAttachment attachmentWithString:_preElevationWindowDiagnostic];
        attachment.name = @"native-pre-elevation-scene-windows";
        attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:attachment];
    }
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
    [self fitAction:action width:self.viewport.bounds.size.width];
    NSDictionary<NSString *, UILabel *> *preparedLabels = [[self.board valueForKey:@"labels"] copy];
    for (UILabel *label in preparedLabels.allValues) {
        XCTAssertNotNil(label.layer.presentationLayer);
        XCTAssertEqual(label.layer.presentationLayer.modelLayer, label.layer);
        XCTAssertFalse(label.layer.needsDisplay); XCTAssertFalse(label.layer.needsLayout);
    }
    XCTAssertEqual([self.board playInVisibleRect:self.board.bounds], MTPPlaceValuePlaybackStateRunning);
    NSDictionary<NSString *, UILabel *> *runningLabels = [self.board valueForKey:@"labels"];
    XCTAssertEqualObjects([NSSet setWithArray:runningLabels.allKeys], [NSSet setWithArray:preparedLabels.allKeys]);
    for (NSString *key in preparedLabels) {
        XCTAssertEqual(runningLabels[key], preparedLabels[key], @"Admission must retain the exact presented before caption, not install uncommitted replacement paint.");
        XCTAssertNotNil(runningLabels[key].layer.presentationLayer);
        XCTAssertEqual(runningLabels[key].layer.presentationLayer.modelLayer, runningLabels[key].layer);
        XCTAssertFalse(runningLabels[key].layer.needsDisplay); XCTAssertFalse(runningLabels[key].layer.needsLayout);
    }
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
        NSUInteger viewIndex = [viewParent.subviews indexOfObjectIdenticalTo:self.board];
        UIWindow *viewWindow = self.board.window; CGRect boardFrame = self.board.frame;
        XCTAssertEqual(viewParent, self.viewport); XCTAssertEqual(parent, viewParent.layer); XCTAssertEqual(viewWindow, self.window);
        XCTAssertNotEqual(index, NSNotFound); XCTAssertNotEqual(viewIndex, NSNotFound);
        XCTAssertEqual(self.board.layer.presentationLayer.superlayer.modelLayer, parent);
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
            [self presentFrame]; XCTAssertEqual(self.board.layer.superlayer,wrapper); XCTAssertEqual(wrapper.superlayer,parent); XCTAssertNil(wrapper.delegate);
            // Raw reparenting may make UIKit report nil superview; that does not
            // prove window detachment. Assert the real mismatch, not a fake parent.
            XCTAssertNotEqual(self.board.layer.superlayer, self.board.superview.layer,
                @"mode=%@ during=%@ nativeSuperviewClass=%@ sameWindow=%d", mode, during, NSStringFromClass(self.board.superview.class), self.board.window == viewWindow);
            CALayer *boardPaint = self.board.layer.presentationLayer;
            if (boardPaint) XCTAssertEqual(boardPaint.superlayer.modelLayer, wrapper);
            if (!wrapper.hidden) { XCTAssertNotNil(wrapper.presentationLayer); XCTAssertEqualWithAccuracy(wrapper.presentationLayer.opacity,wrapper.opacity,.0001); }
            if (during.boolValue) { [self.board recheckVisibility]; XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); }
            else XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace);
            XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
        } @finally {
            [CATransaction begin]; [CATransaction setDisableActions:YES];
            @try {
                [self.board removeFromSuperview];
                [viewParent insertSubview:self.board atIndex:MIN(viewIndex,viewParent.subviews.count)];
                [wrapper removeFromSuperlayer];
            } @finally { [CATransaction commit]; }
            [self presentFrame];
            XCTAssertEqual(self.board.superview,viewParent); XCTAssertEqual(self.board.window,viewWindow);
            XCTAssertEqual(self.board.layer.superlayer,parent); XCTAssertNil(wrapper.superlayer);
            XCTAssertEqual([viewParent.subviews indexOfObjectIdenticalTo:self.board],viewIndex);
            XCTAssertEqual([parent.sublayers indexOfObjectIdenticalTo:self.board.layer],index);
            XCTAssertTrue(CGRectEqualToRect(self.board.frame,boardFrame));
            XCTAssertNotNil(self.board.layer.presentationLayer);
            XCTAssertEqual(self.board.layer.presentationLayer.superlayer.modelLayer,parent);
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
    // Exercise the exact empty-before scene eligible for prepared-caption reuse.
    // Changed drawing settings must be replaced, not repaired in place and
    // described as already-presented canonical text. Native layer observations
    // below do not certify that a changed glyph raster is already visible.
    MultiplicativeTeachingAction *generate = [self action:[self plan:1 op:@"×" b:1] kind:MultiplicativeTeachingActionKindGenerateGroup column:2 last:NO];
    NSDictionary *(^ownAppearance)(CALayer *) = ^NSDictionary *(CALayer *layer) {
        return @{@"borderWidth":@(layer.borderWidth), @"borderColor":layer.borderWidth && layer.borderColor ? [UIColor colorWithCGColor:layer.borderColor] : NSNull.null,
            @"background":layer.backgroundColor && CGColorGetAlpha(layer.backgroundColor) ? [UIColor colorWithCGColor:layer.backgroundColor] : NSNull.null,
            @"cornerRadius":@(layer.cornerRadius), @"clips":@(layer.masksToBounds), @"contentsRect":[NSValue valueWithCGRect:layer.contentsRect],
            @"contentsCenter":[NSValue valueWithCGRect:layer.contentsCenter], @"contentsGravity":layer.contentsGravity ?: NSNull.null};
    };
    NSDictionary *(^drawing)(UILabel *) = ^NSDictionary *(UILabel *label) {
        return @{@"color":label.textColor, @"lines":@(label.numberOfLines), @"break":@(label.lineBreakMode),
            @"alignment":@(label.textAlignment), @"strategy":@(label.lineBreakStrategy), @"enabled":@(label.enabled),
            @"highlighted":@(label.highlighted), @"highlightColor":label.highlightedTextColor ?: NSNull.null,
            @"attributed":label.attributedText ?: NSNull.null, @"ownLayer":ownAppearance(label.layer)};
    };
    for (NSString *mutation in @[@"clear", @"singleLine", @"truncating", @"attributedTail", @"centered", @"breakStrategy",
                                 @"highlighted", @"disabled", @"border", @"background", @"cornerClip", @"contentsRect", @"contentsCenter", @"contentsGravity",
                                 @"pendingDisplay", @"pendingLayout", @"restoredColor", @"pendingContentsRect"]) {
        [self fitAction:generate width:MIN(320,self.viewport.bounds.size.width)];
        UILabel *prepared = [[self.board valueForKey:@"labels"] objectForKey:@"context"];
        XCTAssertNotNil(prepared); XCTAssertNotNil(prepared.layer.presentationLayer);
        XCTAssertEqual(prepared.layer.presentationLayer.modelLayer,prepared.layer);
        if ([mutation isEqualToString:@"clear"] || [mutation isEqualToString:@"restoredColor"]) prepared.textColor = UIColor.clearColor;
        else if ([mutation isEqualToString:@"singleLine"]) prepared.numberOfLines = 1;
        else if ([mutation isEqualToString:@"truncating"]) prepared.lineBreakMode = NSLineBreakByTruncatingTail;
        else if ([mutation isEqualToString:@"attributedTail"]) {
            NSMutableAttributedString *styled = [[NSMutableAttributedString alloc] initWithString:prepared.text attributes:@{NSFontAttributeName:prepared.font, NSForegroundColorAttributeName:prepared.textColor}];
            XCTAssertGreaterThan(styled.length,1u);
            [styled addAttribute:NSForegroundColorAttributeName value:UIColor.clearColor range:NSMakeRange(styled.length-1,1)]; prepared.attributedText = styled;
        } else if ([mutation isEqualToString:@"centered"]) prepared.textAlignment = NSTextAlignmentCenter;
        else if ([mutation isEqualToString:@"breakStrategy"]) prepared.lineBreakStrategy = NSLineBreakStrategyNone;
        else if ([mutation isEqualToString:@"highlighted"]) { prepared.highlightedTextColor = UIColor.clearColor; prepared.highlighted = YES; }
        else if ([mutation isEqualToString:@"disabled"]) prepared.enabled = NO;
        else if ([mutation isEqualToString:@"border"]) { prepared.layer.borderColor = UIColor.redColor.CGColor; prepared.layer.borderWidth = MAX(prepared.bounds.size.width,prepared.bounds.size.height); }
        else if ([mutation isEqualToString:@"background"]) prepared.layer.backgroundColor = UIColor.redColor.CGColor;
        else if ([mutation isEqualToString:@"cornerClip"]) { prepared.layer.masksToBounds = YES; prepared.layer.cornerRadius = MAX(prepared.bounds.size.width,prepared.bounds.size.height); }
        else if ([mutation isEqualToString:@"contentsRect"]) prepared.layer.contentsRect = CGRectEqualToRect(prepared.layer.contentsRect,CGRectMake(0,0,.5,1)) ? CGRectMake(.5,0,.5,1) : CGRectMake(0,0,.5,1);
        else if ([mutation isEqualToString:@"contentsCenter"]) prepared.layer.contentsCenter = CGRectEqualToRect(prepared.layer.contentsCenter,CGRectMake(.25,.25,.5,.5)) ? CGRectMake(.125,.125,.25,.25) : CGRectMake(.25,.25,.5,.5);
        else if ([mutation isEqualToString:@"contentsGravity"]) prepared.layer.contentsGravity = [prepared.layer.contentsGravity isEqualToString:kCAGravityTopLeft] ? kCAGravityBottomRight : kCAGravityTopLeft;
        if (![mutation hasPrefix:@"pending"]) {
            // Passively observe public native-layer agreement, including a
            // settled border/clip/contents-layout mutation. No glyph readback,
            // CA flush, synthesized presentation, or admission retry occurs.
            XCTestExpectation *settled = [self expectationForPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
                UILabel *label = object;
                CALayer *paint = label.layer.presentationLayer;
                return paint && paint.modelLayer == label.layer && !label.layer.needsDisplay && !label.layer.needsLayout
                    && label.layer.contents == paint.contents && [ownAppearance(label.layer) isEqualToDictionary:ownAppearance(paint)]
                    && [self.board paintTreeIsStable:label.layer requirePresentation:YES];
            }] evaluatedWithObject:prepared handler:nil];
            [self waitForExpectations:@[settled] timeout:2];
            XCTAssertNotNil(prepared.layer.presentationLayer);
            XCTAssertEqual(prepared.layer.presentationLayer.modelLayer,prepared.layer);
            XCTAssertFalse(prepared.layer.needsDisplay); XCTAssertFalse(prepared.layer.needsLayout);
        }
        if ([mutation isEqualToString:@"restoredColor"]) {
            prepared.textColor = ChildUI.brownText; [prepared.layer setNeedsDisplay]; XCTAssertTrue(prepared.layer.needsDisplay);
        } else if ([mutation isEqualToString:@"pendingDisplay"]) {
            [prepared.layer setNeedsDisplay]; XCTAssertTrue(prepared.layer.needsDisplay);
        } else if ([mutation isEqualToString:@"pendingLayout"]) {
            [prepared.layer setNeedsLayout]; XCTAssertTrue(prepared.layer.needsLayout);
        } else if ([mutation isEqualToString:@"pendingContentsRect"]) {
            prepared.layer.contentsRect = CGRectEqualToRect(prepared.layer.presentationLayer.contentsRect,CGRectMake(0,0,.5,1)) ? CGRectMake(.5,0,.5,1) : CGRectMake(0,0,.5,1);
            XCTAssertFalse(CGRectEqualToRect(prepared.layer.contentsRect,prepared.layer.presentationLayer.contentsRect));
        }
        NSDictionary *mutatedDrawing = drawing(prepared);
        XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateRunning);
        ((CADisplayLink *)[self.board valueForKey:@"clock"]).paused = YES;
        UILabel *replacement = [[self.board valueForKey:@"labels"] objectForKey:@"context"];
        XCTAssertNotEqual(replacement,prepared,@"%@ must take the unchanged rebuild path.",mutation);
        XCTAssertNil(prepared.superview); XCTAssertEqualObjects(drawing(prepared),mutatedDrawing);
        XCTAssertEqualObjects(replacement.textColor,ChildUI.brownText); XCTAssertEqual(replacement.numberOfLines,0);
        XCTAssertEqual(replacement.lineBreakMode,NSLineBreakByWordWrapping);
        XCTAssertEqual(replacement.layer.borderWidth,0); XCTAssertEqual(replacement.layer.cornerRadius,0);
    }
    [self.board cancelPlaybackWithReason:MTPPlaceValueInterruptionReasonCancelled];
    [self fitAction:generate width:MIN(320,self.viewport.bounds.size.width)]; self.board.injectLabelAnimation = YES;
    XCTAssertEqual([self.board playInVisibleRect:self.board.bounds],MTPPlaceValuePlaybackStateInsufficientSpace);
    XCTAssertNil([self.board valueForKey:@"clock"]); self.board.injectLabelAnimation = NO;
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
    CALayer *cover = [CALayer layer]; cover.name = MTPNativeCoverMarker;
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
        void *originalClockIdentity = (__bridge void *)[self.board valueForKey:@"clock"];
        BOOL originalClockPaused = ((CADisplayLink *)[self.board valueForKey:@"clock"]).paused;
        void *originalTransactionIdentity = (__bridge void *)[self.board valueForKey:@"transaction"];
        CGRect originalRequired = self.board.requiredActionRect;
        CALayer *cover = [self addStandaloneCoverInsideBoard:inside.boolValue z:[mode isEqualToString:@"animatedZ"] ? -1 : ([mode isEqualToString:@"highZBelowIndex"] ? 10 : 0)
            first:[mode isEqualToString:@"highZBelowIndex"] outside:([mode isEqualToString:@"animatedPosition"] || [mode isEqualToString:@"uncommittedDescendantRemoval"]) hidden:NO];
        CALayer *parent = cover.superlayer, *descendant = nil;
        if ([mode isEqualToString:@"uncommittedDescendantRemoval"]) {
            descendant = [CALayer layer]; descendant.frame = [cover convertRect:self.board.requiredActionRect fromLayer:self.board.layer]; descendant.backgroundColor = UIColor.redColor.CGColor;
            [cover addSublayer:descendant]; [self presentFrame]; XCTAssertNotNil(descendant.presentationLayer);
        }
        NSString *removalDiagnostic = nil;
        NSMutableArray<NSString *> *observations = [NSMutableArray array];
        void (^observe)(NSString *) = ^(NSString *phase) {
            [observations addObject:MTPNativeCoverObservation(self.board,parent,cover,descendant,action,
                originalClockIdentity,originalClockPaused,originalTransactionIdentity,originalRequired,mode,inside.boolValue,phase)];
        };
        @try {
            observe(@"before mode mutation; after original fixture boundary");
            if ([mode isEqualToString:@"animatedZ"]) {
                MTPAddFrozenPaintAnimation(cover,@"zPosition",@3);
                observe(@"immediately after frozen z mutation before existing native boundary"); [self presentFrame];
                XCTAssertEqual(cover.zPosition,-1); XCTAssertGreaterThan(cover.presentationLayer.zPosition,0);
            }
            if ([mode isEqualToString:@"animatedPosition"]) {
                CGRect target = [parent convertRect:self.board.requiredActionRect fromLayer:self.board.layer]; CGPoint center = CGPointMake(CGRectGetMidX(target),CGRectGetMidY(target));
                MTPAddFrozenPaintAnimation(cover,@"position",[NSValue valueWithCGPoint:CGPointMake(2*center.x-cover.position.x,2*center.y-cover.position.y)]);
                observe(@"immediately after frozen position mutation before existing native boundary"); [self presentFrame];
                XCTAssertFalse(CGRectIntersectsRect(cover.frame,target)); XCTAssertTrue(CGRectIntersectsRect(cover.presentationLayer.frame,target));
            }
            BOOL pending = [mode hasPrefix:@"uncommitted"];
            if (pending) {
                XCTAssertEqual(parent.presentationLayer.sublayers.lastObject.modelLayer,cover);
                [CATransaction begin]; [CATransaction setDisableActions:YES]; [CATransaction setAnimationDuration:6.5];
            }
            @try {
                if (pending) observe(@"before pending mutation; caller transaction open");
                if ([mode isEqualToString:@"uncommittedReorder"]) [parent insertSublayer:cover atIndex:0];
                if ([mode isEqualToString:@"uncommittedRemoval"]) [cover removeFromSuperlayer];
                if ([mode isEqualToString:@"uncommittedHiddenRemoval"] || [mode isEqualToString:@"uncommittedZeroOpacityRemoval"]) {
                    NSString *beforeHide = MTPCurrentParentPaintDiagnostic(parent, cover, @"before hide");
                    if ([mode isEqualToString:@"uncommittedHiddenRemoval"]) cover.hidden = YES; else cover.opacity = 0;
                    NSString *afterHide = MTPCurrentParentPaintDiagnostic(parent, cover, @"after hide before removal");
                    observe(@"after scalar mutation before removal; caller transaction open");
                    [cover removeFromSuperlayer]; XCTAssertNil(cover.superlayer);
                    NSString *afterRemoval = MTPCurrentParentPaintDiagnostic(parent, cover, @"after removal");
                    observe(@"immediately after scalar cover removal; caller transaction open");
                    removalDiagnostic = [NSString stringWithFormat:@"mode=%@ inside=%@\n%@\n%@\n%@", mode, inside, beforeHide, afterHide, afterRemoval];
                    CALayer *oldPaint = nil;
                    for (CALayer *paint in parent.presentationLayer.sublayers) if (paint.modelLayer == cover) oldPaint = paint;
                    // Require the actual old paint. Do not assume whether a
                    // separate detached model.presentationLayer getter is nil.
                    XCTAssertNotNil(oldPaint); XCTAssertFalse(oldPaint.hidden); XCTAssertGreaterThan(oldPaint.opacity,0);
                }
                if ([mode isEqualToString:@"uncommittedDescendantRemoval"]) [descendant removeFromSuperlayer];
                observe(@"after mode mutation before original recheck");
                XCTAssertNotNil(parent.presentationLayer); [self.board recheckVisibility];
                observe(@"immediately after original recheck");
                XCTAssertEqual(self.board.playbackState,MTPPlaceValuePlaybackStateInterrupted); XCTAssertEqual(self.board.snapshot,action.after); XCTAssertNil([self.board valueForKey:@"clock"]);
                if (pending) XCTAssertEqualWithAccuracy(CATransaction.animationDuration,6.5,.0001);
            } @finally { if (pending) [CATransaction commit]; }
        } @finally {
            [cover removeAllAnimations]; [cover removeFromSuperlayer]; [self presentFrame];
            observe(@"after original cleanup and native boundary");
            XCTAttachment *observationAttachment = [XCTAttachment attachmentWithString:[observations componentsJoinedByString:@"\n\n"]];
            observationAttachment.name = [NSString stringWithFormat:@"native-cover-observations-%@-%@", inside.boolValue ? @"inside" : @"outside", mode];
            observationAttachment.lifetime = XCTAttachmentLifetimeKeepAlways; [self addAttachment:observationAttachment];
            if (removalDiagnostic) {
                XCTAttachment *attachment = [XCTAttachment attachmentWithString:removalDiagnostic];
                attachment.name = @"native-cover-removal-current-presentation"; attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
                [self addAttachment:attachment];
            }
        }
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
