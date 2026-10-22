#import <Foundation/Foundation.h>
#import "MultiplicativeTeachingSequence.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MultiplicativeTeachingActionStatus) {
    MultiplicativeTeachingActionStatusSupported,
    MultiplicativeTeachingActionStatusUnsupportedSource,
    MultiplicativeTeachingActionStatusInvalidSource
};
typedef NS_ENUM(NSInteger, MultiplicativeTeachingActionKind) {
    MultiplicativeTeachingActionKindInspect,
    MultiplicativeTeachingActionKindGenerateGroup,
    MultiplicativeTeachingActionKindZeroGroups,
    MultiplicativeTeachingActionKindExchangeUp,
    MultiplicativeTeachingActionKindBringDown,
    MultiplicativeTeachingActionKindDistributeRecipient,
    MultiplicativeTeachingActionKindZeroDistribution,
    MultiplicativeTeachingActionKindExchangeDown
};
typedef NS_ENUM(NSInteger, MultiplicativeTeachingUnitOrigin) {
    MultiplicativeTeachingUnitOriginOriginalInput,
    MultiplicativeTeachingUnitOriginGeneratedGroup,
    MultiplicativeTeachingUnitOriginExchange
};

/// One countable unit at ONE immutable place. IDs are deterministic and unique
/// within a plan, not across different problems. An exchange retires IDs and
/// creates new IDs at a different place; a transfer preserves the original ID.
@interface MultiplicativeTeachingUnit : NSObject
@property (nonatomic, assign, readonly) NSUInteger identifier;
@property (nonatomic, assign, readonly) NSInteger column;
@property (nonatomic, assign, readonly) NSInteger value; // 100, 10 or 1, never 0.
@property (nonatomic, assign, readonly) MultiplicativeTeachingUnitOrigin origin;
@property (nonatomic, assign, readonly) NSInteger sourceStepIndex; // NSNotFound for original input.
@property (nonatomic, assign, readonly) NSInteger groupIndex; // Zero-based generated group, otherwise NSNotFound.
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// An owned quantity. Column arrays are immutable [hundreds, tens, ones].
/// The same unit cannot belong to two owned quantities in one snapshot.
@interface MultiplicativeTeachingQuantity : NSObject
@property (nonatomic, copy, readonly) NSArray<NSArray<MultiplicativeTeachingUnit *> *> *columns;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *counts;
@property (nonatomic, assign, readonly) NSInteger weightedValue;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// A complete settled endpoint, independently inspectable after cancellation,
/// resize, Back, Replay or reduced motion. There is no playback state to reset.
@interface MultiplicativeTeachingActionSnapshot : NSObject
@property (nonatomic, assign, readonly) MultiplicativeTeachingOperation operation;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingQuantity *accumulator;
/// Annotation subset of accumulator, NOT a second owned quantity. These are the
/// very same unit objects already counted in accumulator. Never add them again.
@property (nonatomic, copy, readonly) NSArray<NSArray<MultiplicativeTeachingUnit *> *> *carryUnits;
@property (nonatomic, copy, readonly) NSIndexSet *processedInputColumns;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingQuantity *unprocessedInput;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingQuantity *pool;
/// Exactly the known divisor's recipients for division; empty for multiplication.
@property (nonatomic, copy, readonly) NSArray<MultiplicativeTeachingQuantity *> *recipients;
/// Only the original WriteDigit changes these. A completed blank column is a
/// suppressed leading zero, not an unvisited or input-padding column.
@property (nonatomic, copy, readonly) NSArray *visibleAnswerDigits;
@property (nonatomic, copy, readonly) NSIndexSet *completedColumns;
@property (nonatomic, copy, readonly) NSArray<MultiplicativeDivisionWorkRow *> *visibleDivisionRows;
/// Only the original InspectRemainder reveals this; a common pool is not labelled
/// a final remainder before then.
@property (nonatomic, copy, readonly, nullable) NSNumber *visibleRemainder;
/// All current quantities and written state. No future totals, carry or digits.
@property (nonatomic, copy, readonly) NSString *spokenDescription;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// One explicit child-chosen action within one original teaching step. The model
/// does not autoplay, impose completion, score, or claim that motion was watched.
@interface MultiplicativeTeachingAction : NSObject
@property (nonatomic, assign, readonly) MultiplicativeTeachingActionKind kind;
@property (nonatomic, strong, readonly) MultiplicativeTeachingStep *sourceStep;
@property (nonatomic, assign, readonly) NSInteger sourceStepIndex;
@property (nonatomic, assign, readonly) NSInteger indexWithinStep;
@property (nonatomic, assign, readonly) NSInteger countWithinStep;
@property (nonatomic, assign, readonly, getter=isSourceStepComplete) BOOL sourceStepComplete;
@property (nonatomic, assign, readonly) NSInteger activeColumn;
@property (nonatomic, assign, readonly) NSInteger sourceColumn;
@property (nonatomic, assign, readonly) NSInteger destinationColumn;
@property (nonatomic, assign, readonly) NSInteger recipientIndex; // NSNotFound outside one-recipient distribution.
@property (nonatomic, assign, readonly) NSInteger groupIndex; // NSNotFound outside generated groups.
@property (nonatomic, assign, readonly) NSInteger groupCount; // Original known multiplier/divisor.
@property (nonatomic, strong, readonly) MultiplicativeTeachingActionSnapshot *before;
@property (nonatomic, strong, readonly) MultiplicativeTeachingActionSnapshot *after;
/// Generation: empty inputs, <=9 newly generated outputs. Transfer: identical
/// input/output IDs at the SAME place. Exchange: exactly 10->1 or 1->10 at adjacent
/// places, equal weighted value. These lists are the explicit exchange lineage.
/// Inspect/zero actions: both empty. They never invent invisible moving pieces.
@property (nonatomic, copy, readonly) NSArray<MultiplicativeTeachingUnit *> *inputUnits;
@property (nonatomic, copy, readonly) NSArray<MultiplicativeTeachingUnit *> *outputUnits;
/// MultiplyPlace only: already-owned carry, excluded from generated outputUnits.
@property (nonatomic, copy, readonly) NSArray<MultiplicativeTeachingUnit *> *ownedIncomingCarryUnits;
/// Use these action-specific strings, NOT sourceStep.explanation for a partial
/// action: the original narrative describes the whole source-step result.
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *instruction;
@property (nonatomic, copy, readonly) NSString *resultExplanation;
@property (nonatomic, copy, readonly) NSString *spokenBefore;
@property (nonatomic, copy, readonly) NSString *spokenAfter;
/// Only the original single WriteDigit action exposes a written digit/disposition.
@property (nonatomic, copy, readonly, nullable) NSNumber *writtenDigit;
@property (nonatomic, assign, readonly) MultiplicativeTeachingWriteDisposition writeDisposition;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface MultiplicativeTeachingActionPlan : NSObject
@property (nonatomic, assign, readonly) MultiplicativeTeachingActionStatus status;
@property (nonatomic, assign, readonly, getter=isSupported) BOOL supported;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingSequence *sourceSequence;
@property (nonatomic, strong, readonly, nullable) MultiplicativeTeachingActionSnapshot *initialSnapshot;
/// Immutable, finite actions. A controller may select any endpoint explicitly;
/// visiting this array is not evidence of learning, watching, or mastery.
@property (nonatomic, copy, readonly) NSArray<MultiplicativeTeachingAction *> *actions;
+ (instancetype)planForSequence:(nullable MultiplicativeTeachingSequence *)sequence;
- (NSArray<MultiplicativeTeachingAction *> *)actionsForSourceStepAtIndex:(NSInteger)index;
- (nullable MultiplicativeTeachingActionSnapshot *)beforeSnapshotForSourceStepAtIndex:(NSInteger)index;
/// Explicit full SETTLED result inspection, not permission to animate all of a
/// large source step at once. No hidden subactions run and no write steps skip.
- (nullable MultiplicativeTeachingActionSnapshot *)resultSnapshotForSourceStepAtIndex:(NSInteger)index;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
