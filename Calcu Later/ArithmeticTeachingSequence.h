#import <Foundation/Foundation.h>
#import "ArithmeticProblem.h"

NS_ASSUME_NONNULL_BEGIN

/// A stable, child-paced lesson. Only WriteAnswer reveals an answer digit.
typedef NS_ENUM(NSInteger, ArithmeticTeachingStepKind) {
    ArithmeticTeachingStepKindAlignment,
    ArithmeticTeachingStepKindPrediction,
    ArithmeticTeachingStepKindRegroup,
    ArithmeticTeachingStepKindColumnCalculation,
    ArithmeticTeachingStepKindWriteAnswer,
    ArithmeticTeachingStepKindCompletion
};

/// Immutable state after one teaching action; contains no UI, timing or playback state.
/// All digit arrays have sequence.columnCount entries. Index 0 is the leftmost,
/// highest place. Arrays are copied, and their NSNumber/NSNull entries are immutable.
@interface ArithmeticTeachingStep : NSObject
@property (nonatomic, assign, readonly) ArithmeticTeachingStepKind kind;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *explanation;
/// Nonempty only for Prediction. expectedAnswer is nil on every other kind.
@property (nonatomic, copy, readonly) NSString *prompt;
@property (nonatomic, copy, readonly, nullable) NSNumber *expectedAnswer;
/// NSNotFound on Alignment and Completion; otherwise a valid array index.
@property (nonatomic, assign, readonly) NSInteger activeColumn;
/// Adjacent valid indices on Regroup only; NSNotFound otherwise.
/// Addition moves 10 units source→destination (left); subtraction moves 1 unit
/// source→destination (right), where it becomes 10 smaller units.
@property (nonatomic, assign, readonly) NSInteger sourceColumn;
@property (nonatomic, assign, readonly) NSInteger destinationColumn;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *firstDigits;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *secondDigits;
/// Borrowed first-operand counts for subtraction. For addition, combined counts
/// in columns already calculated and first-operand counts in unvisited columns.
/// These are counts, not necessarily digits: a column may temporarily contain 10–19.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *workingDigits;
/// The preceding state, for value-preserving regroup animations. Equal to
/// workingDigits for actions that do not change counts.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *workingDigitsBefore;
/// Incoming carry annotations; 0 means no annotation. A carry is already included
/// in workingDigits and MUST NOT be added again. Consumed at ColumnCalculation.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *carryDigits;
/// NSNumber digits already written; NSNull means unrevealed OR leading padding.
/// Leading answer zeros are never shown. The answer zero itself is written at
/// the rightmost column. Never use problem.answer to prefill the answer row.
@property (nonatomic, copy, readonly) NSArray *visibleAnswerDigits;
/// Non-nil only for ColumnCalculation and WriteAnswer. The former can exceed 9;
/// the latter is the single digit to write, including a suppressed leading zero.
@property (nonatomic, copy, readonly, nullable) NSNumber *columnValue;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface ArithmeticTeachingSequence : NSObject
/// Defensive snapshot: each read returns a new ArithmeticProblem, so mutating
/// either the original input or this returned object cannot change the lesson.
@property (nonatomic, strong, readonly) ArithmeticProblem *problem;
@property (nonatomic, assign, readonly, getter=isValid) BOOL valid;
/// Invalid/unsupported input: valid=NO, columnCount=0, steps=@[].
@property (nonatomic, assign, readonly) NSInteger columnCount;
@property (nonatomic, copy, readonly) NSArray<ArithmeticTeachingStep *> *steps;
/// First non-padding column of each operand and the answer. NSNotFound if invalid.
/// Useful for omitting zero padding without collapsing column alignment.
@property (nonatomic, assign, readonly) NSInteger firstOperandStartColumn;
@property (nonatomic, assign, readonly) NSInteger secondOperandStartColumn;
@property (nonatomic, assign, readonly) NSInteger answerStartColumn;
/// Supports nonnegative + and - (also Unicode −). Rejects inconsistent answers,
/// isMultiStep, unsupported operations, and any operand/result above 99,999.
+ (instancetype)sequenceForProblem:(nullable ArithmeticProblem *)problem;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
