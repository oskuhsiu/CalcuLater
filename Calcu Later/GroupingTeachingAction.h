#import <Foundation/Foundation.h>
#import "GroupingTeachingSequence.h"

NS_ASSUME_NONNULL_BEGIN
/// A reversible view of ONE original division step, not a new story or lesson.
/// Sharing focuses one recipient; packing still makes one complete given-size bag.
@interface GroupingTeachingAction : NSObject
@property (nonatomic, strong, readonly) GroupingTeachingSequence *sequence;
@property (nonatomic, assign, readonly) NSInteger stepIndex;
/// NSNotFound denotes the original complete action. Otherwise zero-based.
@property (nonatomic, assign, readonly) NSInteger actionIndex;
@property (nonatomic, assign, readonly) NSInteger actionCount;
@property (nonatomic, assign, readonly, getter=isFullAction) BOOL fullAction;
@property (nonatomic, assign, readonly, getter=isRoundComplete) BOOL roundComplete;
@property (nonatomic, strong, readonly) GroupingTeachingStep *snapshot;
@property (nonatomic, copy, readonly) NSString *progressText;
/// Original object IDs; source IDs are [0, poolCount), and its tail leaves first.
/// Replay/back/overview never replace an object or change an original lesson step.
@property (nonatomic, copy, readonly) NSArray<NSArray<NSNumber *> *> *groupIdentitiesBefore;
@property (nonatomic, copy, readonly) NSArray<NSArray<NSNumber *> *> *groupIdentitiesAfter;
+ (nullable instancetype)fullActionForSequence:(GroupingTeachingSequence *)sequence stepIndex:(NSInteger)stepIndex;
+ (NSArray<GroupingTeachingAction *> *)focusedActionsForSequence:(GroupingTeachingSequence *)sequence stepIndex:(NSInteger)stepIndex;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/// Unit-aware unscored coaching for the actual choice, not a generic retry.
/// Does not mutate a prediction, advance the lesson, or write the main answer.
@interface GroupingPredictionFeedback : NSObject
+ (NSString *)feedbackForSequence:(GroupingTeachingSequence *)sequence stepIndex:(NSInteger)stepIndex chosenValue:(NSInteger)value;
@end
NS_ASSUME_NONNULL_END
