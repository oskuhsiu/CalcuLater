#import <UIKit/UIKit.h>
#import "MultiplicativeTeachingAction.h"

NS_ASSUME_NONNULL_BEGIN

/// Immutable fixed-scale material placement. Owner keys are accumulator, input,
/// pool and recipient.N (zero-based). Carry is an annotation, never another owner.
@interface MTPPlaceValueUnitPlacement : NSObject
@property (nonatomic, strong, readonly) MultiplicativeTeachingUnit *unit;
@property (nonatomic, copy, readonly) NSString *owner;
@property (nonatomic, assign, readonly) CGRect frame;
@property (nonatomic, assign, readonly) BOOL inTransit;
@property (nonatomic, assign, readonly) BOOL carryAnnotation;
- (instancetype)initWithUnit:(MultiplicativeTeachingUnit *)unit owner:(NSString *)owner frame:(CGRect)frame inTransit:(BOOL)inTransit carryAnnotation:(BOOL)carryAnnotation;
@end

/// One deterministic presentation frame, not a new canonical arithmetic state.
@interface MTPPlaceValueProjection : NSObject
@property (nonatomic, copy, readonly) NSArray<MTPPlaceValueUnitPlacement *> *placements;
@property (nonatomic, copy, readonly) NSDictionary<NSNumber *, NSString *> *ownersByIdentifier;
@property (nonatomic, copy, readonly) NSDictionary<NSNumber *, MultiplicativeTeachingUnit *> *ownedUnitsByIdentifier;
@property (nonatomic, copy, readonly) NSSet<NSNumber *> *carryIdentifiers;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *labelTexts;
@property (nonatomic, strong, readonly) MultiplicativeTeachingActionSnapshot *canonicalSnapshot;
@property (nonatomic, assign, readonly) BOOL complete;
@end

/// Geometry and phase program for ONE observed action. No clock, future sequence,
/// prediction value, answer field, mutable view position, or navigation belongs here.
@interface MultiplicativePlaceValueScene : NSObject
@property (nonatomic, strong, readonly) MultiplicativeTeachingAction *action;
@property (nonatomic, strong, readonly) UIFont *font;
@property (nonatomic, assign, readonly) CGFloat width;
@property (nonatomic, assign, readonly) CGRect requiredRect;
@property (nonatomic, assign, readonly) CGRect cradleRect;
@property (nonatomic, assign, readonly) BOOL geometryValid;
@property (nonatomic, copy, readonly) NSString *geometryFailure;
@property (nonatomic, assign, readonly) BOOL stationary;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, copy, readonly) NSDictionary<NSNumber *, NSValue *> *beforeFrames;
@property (nonatomic, copy, readonly) NSDictionary<NSNumber *, NSValue *> *afterFrames;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSValue *> *labelFrames;
@property (nonatomic, copy, readonly) NSSet<NSNumber *> *omittedIdentifiers;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *transferOrder;
@property (nonatomic, copy, readonly) NSDictionary<NSNumber *, NSValue *> *sweptFrames;
+ (instancetype)sceneWithAction:(MultiplicativeTeachingAction *)action width:(CGFloat)width font:(UIFont *)font;
- (MTPPlaceValueProjection *)projectionAtElapsed:(NSTimeInterval)elapsed;
- (MTPPlaceValueProjection *)projectionAfter:(BOOL)after;
@end

FOUNDATION_EXPORT CGSize MTPPlaceValueBodySize(NSInteger column);
FOUNDATION_EXPORT NSDictionary<NSString *, NSArray<MultiplicativeTeachingUnit *> *> *MTPPlaceValueOwners(MultiplicativeTeachingActionSnapshot *snapshot);
FOUNDATION_EXPORT NSArray<NSString *> *MTPPlaceValueOwnerOrder(MultiplicativeTeachingActionSnapshot *snapshot);
FOUNDATION_EXPORT NSString *MTPPlaceValueOwnerName(NSString *owner, MultiplicativeTeachingActionSnapshot *snapshot);
FOUNDATION_EXPORT NSString *MTPPlaceValuePlaceName(NSInteger column);
FOUNDATION_EXPORT CGFloat MTPPlaceValueTextHeight(NSString *text, UIFont *font, CGFloat width);
NS_ASSUME_NONNULL_END
