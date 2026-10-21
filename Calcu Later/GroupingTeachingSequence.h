#import <Foundation/Foundation.h>
#import "ArithmeticProblem.h"
#import "GroupingStoryContext.h"

@class WordProblem;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GroupingTeachingStatus) {
    GroupingTeachingStatusSupported,
    GroupingTeachingStatusMissingOrUnsupportedMeaning,
    GroupingTeachingStatusOutsideConcreteBounds,
    GroupingTeachingStatusInvalidProblem
};

typedef NS_ENUM(NSInteger, GroupingTeachingStepKind) {
    GroupingTeachingStepKindObserve,
    GroupingTeachingStepKindPredict,
    GroupingTeachingStepKindBuildGroup,
    GroupingTeachingStepKindShareRound,
    GroupingTeachingStepKindPackGroup,
    GroupingTeachingStepKindInspectRemainder,
    GroupingTeachingStepKindWriteAnswer,
    GroupingTeachingStepKindVerify,
    GroupingTeachingStepKindCompletion
};

typedef NS_ENUM(NSInteger, GroupingTeachingPredictionKind) {
    GroupingTeachingPredictionKindNone,
    GroupingTeachingPredictionKindCount,
    GroupingTeachingPredictionKindCanContinue
};

/// A settled, immutable mathematical state. No timing, layout or playback state.
@interface GroupingTeachingStep : NSObject
@property (nonatomic, assign, readonly) GroupingTeachingStepKind kind;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *explanation;
/// Current state only, with item/group units. Never reads a future answer aloud.
@property (nonatomic, copy, readonly) NSString *spokenExplanation;
/// Describes THIS step's transformation; empty for non-transforming steps.
@property (nonatomic, copy, readonly) NSString *actionTitle;
/// Nonempty only on Predict. Prediction is optional, ungraded, and never mutates a step.
@property (nonatomic, copy, readonly) NSString *prompt;
@property (nonatomic, assign, readonly) GroupingTeachingPredictionKind predictionKind;
/// Only Predict: a count or @YES/@NO. Never include in labels or spoken text.
@property (nonatomic, copy, readonly, nullable) NSNumber *expectedAnswer;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *groupCountsBefore;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *groupCountsAfter;
/// Division only. Both nil for multiplication, which must not pre-display its product.
@property (nonatomic, copy, readonly, nullable) NSNumber *poolCountBefore;
@property (nonatomic, copy, readonly, nullable) NSNumber *poolCountAfter;
/// Multiplication only: known groups still to build AFTER this step, not empty result boxes.
@property (nonatomic, copy, readonly, nullable) NSNumber *unopenedGroupCount;
/// Zero-based groups changed by THIS step. Empty for non-transforming steps.
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *activeGroupIndices;
/// Total items transferred: Build/Pack = one group's size; Share = recipient count
/// (one item to EACH recipient, not a total of one). Zero on non-transforming steps.
@property (nonatomic, assign, readonly) NSInteger transferCount;
/// Nil before WriteAnswer, including when the answer is zero. Then retained.
@property (nonatomic, copy, readonly, nullable) NSNumber *visibleAnswer;
/// Division only: nil before InspectRemainder, then the exact remainder (including zero).
@property (nonatomic, copy, readonly, nullable) NSNumber *visibleRemainder;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface GroupingTeachingSequence : NSObject
@property (nonatomic, assign, readonly) GroupingTeachingStatus status;
@property (nonatomic, assign, readonly, getter=isSupported) BOOL supported;
/// Defensive numeric snapshot: every read returns a fresh mutable ArithmeticProblem.
/// Answer/remainder are validation data, NOT a source for pre-filling the board.
@property (nonatomic, strong, readonly) ArithmeticProblem *problem;
/// Full immutable copied story, present only for the story route. No lossy arithmetic bridge.
@property (nonatomic, strong, readonly, nullable) WordProblem *wordProblem;
@property (nonatomic, copy, readonly, nullable) GroupingStoryContext *context;
@property (nonatomic, assign, readonly) NSInteger remainder;
/// At most 32 steps. Every unsupported/invalid result has an empty array.
@property (nonatomic, copy, readonly) NSArray<GroupingTeachingStep *> *steps;
/// Requires producer-supplied context; never infers meaning or remainder from a template ID.
+ (instancetype)sequenceForWordProblem:(nullable WordProblem *)problem;
+ (instancetype)sequenceForWordProblem:(nullable WordProblem *)problem
                  includePredictions:(BOOL)includePredictions;
/// Explicit meaning, generic labelled counters. Only this bare route derives division
/// remainder from operands. * and / normalize here only. No story may use this as fallback.
+ (instancetype)sequenceForArithmeticProblem:(nullable ArithmeticProblem *)problem
                                   meaning:(GroupingStoryMeaning)meaning;
+ (instancetype)sequenceForArithmeticProblem:(nullable ArithmeticProblem *)problem
                                   meaning:(GroupingStoryMeaning)meaning
                        includePredictions:(BOOL)includePredictions;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
