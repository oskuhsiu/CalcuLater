#import <UIKit/UIKit.h>
#import "GroupingTeachingSequence.h"

NS_ASSUME_NONNULL_BEGIN

/// Renders only the selected immutable grouping snapshot. The owner controls
/// Next, Back and Replay; this view never chooses an answer or advances a step.
@interface GroupingTeachingBoardView : UIView
@property (nonatomic, strong, readonly, nullable) GroupingTeachingSequence *sequence;
@property (nonatomic, assign, readonly) NSInteger currentStepIndex;
@property (nonatomic, strong, readonly, nullable) GroupingTeachingStep *currentStep;
/// Union of actual current-step moving-counter source/destination frames, in
/// board coordinates. CGRectNull for non-transforming or zero-counter steps.
/// Available after configuring and laying out; useful for first-play scrolling.
@property (nonatomic, assign, readonly) CGRect currentTransformationRect;

/// Invalid sequences or indices clear the board and return NO. A replay starts
/// from this step's own before-state, not from whichever step was viewed before.
- (BOOL)configureWithSequence:(nullable GroupingTeachingSequence *)sequence
                   stepIndex:(NSInteger)stepIndex
                    animated:(BOOL)animated;
- (BOOL)showStepAtIndex:(NSInteger)stepIndex animated:(BOOL)animated;

/// Stops finite motion and restores the selected after-state, never a later one.
- (void)cancelAnimations;

/// Fit at the actual available width, allow vertical scrolling, lay out, then
/// call showStepAtIndex:animated:YES. Resizing intentionally settles any motion.
- (CGSize)sizeThatFits:(CGSize)size;
@end

NS_ASSUME_NONNULL_END
