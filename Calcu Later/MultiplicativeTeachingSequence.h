#import <Foundation/Foundation.h>
#import "ArithmeticProblem.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MultiplicativeTeachingStatus) {
    MultiplicativeTeachingStatusSupported,
    MultiplicativeTeachingStatusInvalidProblem,
    MultiplicativeTeachingStatusUnsupportedOperation,
    MultiplicativeTeachingStatusOutsideBounds,
    MultiplicativeTeachingStatusUnsupportedZeroMultiplier
};

typedef NS_ENUM(NSInteger, MultiplicativeTeachingOperation) {
    MultiplicativeTeachingOperationUnknown,
    MultiplicativeTeachingOperationMultiplication,
    MultiplicativeTeachingOperationDivision
};

typedef NS_ENUM(NSInteger, MultiplicativeTeachingStepKind) {
    MultiplicativeTeachingStepKindObserve,
    MultiplicativeTeachingStepKindPredict,
    MultiplicativeTeachingStepKindMultiplyPlace,
    MultiplicativeTeachingStepKindRegroupUp,
    MultiplicativeTeachingStepKindBringDown,
    MultiplicativeTeachingStepKindDistribute,
    MultiplicativeTeachingStepKindWriteDigit,
    MultiplicativeTeachingStepKindRegroupDown,
    MultiplicativeTeachingStepKindInspectRemainder,
    MultiplicativeTeachingStepKindVerify,
    MultiplicativeTeachingStepKindCompletion
};

typedef NS_ENUM(NSInteger, MultiplicativeTeachingWriteDisposition) {
    MultiplicativeTeachingWriteDispositionNone,
    MultiplicativeTeachingWriteDispositionWritten,
    MultiplicativeTeachingWriteDispositionSuppressedLeadingZero
};

/// Every place-count array is [hundreds, tens, ones], NOT an array of base-ten
/// digits: an active count can reach 89. All nested collections are immutable.
@interface MultiplicativeMultiplicationState : NSObject
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *accumulatorCounts;
/// Annotations for units ALREADY in accumulatorCounts. Never add them again.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *carryCounts;
/// Original multiplicand columns whose contribution has been generated.
/// A final carry column is not an additional multiplied input column.
@property (nonatomic, copy, readonly) NSIndexSet *processedInputColumns;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface MultiplicativeMultiplicationPayload : NSObject
@property (nonatomic, strong, readonly) MultiplicativeMultiplicationState *before;
@property (nonatomic, strong, readonly) MultiplicativeMultiplicationState *after;
/// MultiplyPlace only: original digit × multiplier, excluding the incoming carry.
@property (nonatomic, assign, readonly) NSInteger generatedUnitCount;
/// MultiplyPlace only: already-owned current-place units consumed exactly once.
@property (nonatomic, assign, readonly) NSInteger incomingCarryUnitCount;
/// RegroupUp only: k groups of TEN smaller units become k adjacent larger units.
@property (nonatomic, assign, readonly) NSInteger exchangeBundleCount;
/// Only a WriteDigit that writes the carry above the highest input place.
@property (nonatomic, assign, readonly) BOOL writesFinalCarry;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface MultiplicativeDivisionState : NSObject
/// Original input units not yet brought into the common working pool.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *unprocessedInputCounts;
/// One COMMON pool. A remaining quantity is never copied into every recipient.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *poolCounts;
/// Exactly divisor rows; each row is [hundreds, tens, ones] ALREADY distributed.
/// Empty future quotient-sized boxes are never allocated.
@property (nonatomic, copy, readonly) NSArray<NSArray<NSNumber *> *> *recipientCounts;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface MultiplicativeDivisionPayload : NSObject
@property (nonatomic, strong, readonly) MultiplicativeDivisionState *before;
@property (nonatomic, strong, readonly) MultiplicativeDivisionState *after;
/// BringDown only. Original units move into the pool at the SAME place.
@property (nonatomic, assign, readonly) NSInteger broughtDownUnitCount;
/// Distribute only. Every known recipient receives this many active-place units.
@property (nonatomic, assign, readonly) NSInteger unitsPerRecipient;
/// Distribute only: unitsPerRecipient × divisor; zero has no moving pieces.
@property (nonatomic, assign, readonly) NSInteger totalTransferredUnitCount;
/// RegroupDown only: k larger units split into 10k adjacent smaller units.
@property (nonatomic, assign, readonly) NSInteger exchangeLargerUnitCount;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Written long-division work, revealed only with the current WriteDigit step.
/// All counts use THIS column's actual place (e.g. 10 tens, not 10 ones).
@interface MultiplicativeDivisionWorkRow : NSObject
@property (nonatomic, assign, readonly) NSInteger column;
@property (nonatomic, assign, readonly) NSInteger partialCount;
@property (nonatomic, assign, readonly) NSInteger distributedCount;
@property (nonatomic, assign, readonly) NSInteger remainderCount;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// A settled mathematical snapshot. No timing, UIKit, playback, scoring or
/// child-choice state. Exactly one operation-specific payload is non-nil.
@interface MultiplicativeTeachingStep : NSObject
@property (nonatomic, assign, readonly) MultiplicativeTeachingStepKind kind;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *explanation;
/// Current state only. Never contains a future answer or expected prediction.
@property (nonatomic, copy, readonly) NSString *spokenExplanation;
/// Predict only; participation is optional and ungraded.
@property (nonatomic, copy, readonly) NSString *prompt;
/// Nonnil only on Predict, for choice checking only. Never render or speak this
/// property as the answer; prompt/spokenExplanation deliberately omit its result.
@property (nonatomic, copy, readonly, nullable) NSNumber *expectedAnswer;
/// NSNotFound on Observe, InspectRemainder, Verify and Completion; otherwise 0…2.
@property (nonatomic, assign, readonly) NSInteger activeColumn;
/// Adjacent 0…2 indices on RegroupUp/Down only; NSNotFound otherwise.
@property (nonatomic, assign, readonly) NSInteger sourceColumn;
@property (nonatomic, assign, readonly) NSInteger destinationColumn;
@property (nonatomic, strong, readonly, nullable) MultiplicativeMultiplicationPayload *multiplication;
@property (nonatomic, strong, readonly, nullable) MultiplicativeDivisionPayload *division;
/// Three NSNumber digits/NSNulls. Only WriteDigit reveals a cell. Never render
/// problem.answer or expectedAnswer instead; do not derive blanks from answer width.
@property (nonatomic, copy, readonly) NSArray *visibleAnswerDigits;
/// Columns with a completed write decision. A blank member is a suppressed
/// leading quotient zero; unvisited and input-padding columns are not members.
@property (nonatomic, copy, readonly) NSIndexSet *completedColumns;
/// WriteDigit only (including a deliberately suppressed leading zero).
@property (nonatomic, copy, readonly, nullable) NSNumber *writtenDigit;
@property (nonatomic, assign, readonly) MultiplicativeTeachingWriteDisposition writeDisposition;
/// Division only. No future rows; empty until the first WriteDigit.
@property (nonatomic, copy, readonly) NSArray<MultiplicativeDivisionWorkRow *> *visibleDivisionRows;
/// Division only: nil before InspectRemainder, then retained, including @0.
@property (nonatomic, copy, readonly, nullable) NSNumber *visibleRemainder;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface MultiplicativeTeachingSequence : NSObject
@property (nonatomic, assign, readonly) MultiplicativeTeachingStatus status;
@property (nonatomic, assign, readonly, getter=isSupported) BOOL supported;
@property (nonatomic, assign, readonly) MultiplicativeTeachingOperation operation;
/// A fresh defensive snapshot on every read. Answer is validation data, not UI data.
@property (nonatomic, strong, readonly) ArithmeticProblem *problem;
/// Supported lessons always have 3 columns: 百位、十位、個位. Unsupported: 0.
@property (nonatomic, assign, readonly) NSInteger columnCount;
/// First actual input column, based on number1 only; 0 itself starts at 個位.
/// NSNotFound on unsupported input. There is deliberately no answerStartColumn.
@property (nonatomic, assign, readonly) NSInteger operandStartColumn;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *operandDigits;
/// Supported lessons have <24 finite child-paced steps; otherwise empty.
@property (nonatomic, copy, readonly) NSArray<MultiplicativeTeachingStep *> *steps;
/// Bare numeric route ONLY. Never pass a lossy WordProblem bridge here.
/// a is 0…999, b is 1…9; multiplication product must be ≤999. ×0 is explicitly
/// unsupported; ÷0, inconsistent answers and isMultiStep are invalid. Bounds are
/// checked before arithmetic. * and / normalize only in this factory. Bare integer
/// division derives its one common remainder; stories and decimals are out of scope.
+ (instancetype)sequenceForArithmeticProblem:(nullable ArithmeticProblem *)problem;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
