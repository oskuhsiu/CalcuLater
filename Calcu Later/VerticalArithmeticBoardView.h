#import <UIKit/UIKit.h>
#import "ArithmeticTeachingSequence.h"

NS_ASSUME_NONNULL_BEGIN

/// A child-paced, deterministic rendering of one immutable teaching snapshot.
/// The owner controls Back / Next / Replay; this view never advances the lesson.
@interface VerticalArithmeticBoardView : UIView
@property (nonatomic, strong, readonly, nullable) ArithmeticTeachingSequence *sequence;
@property (nonatomic, assign, readonly) NSInteger currentStepIndex;
@property (nonatomic, strong, readonly, nullable) ArithmeticTeachingStep *currentStep;

/// Invalid sequences or indices clear the entire board and return NO.
/// Animated regrouping uses the step's own before/after counts, including replay.
- (BOOL)configureWithSequence:(nullable ArithmeticTeachingSequence *)sequence
                   stepIndex:(NSInteger)stepIndex
                    animated:(BOOL)animated;
- (BOOL)showStepAtIndex:(NSInteger)stepIndex animated:(BOOL)animated;

/// Immediately settles on the selected snapshot, without revealing any later step.
/// Also called on resize, removal, hiding, backgrounding and Reduce Motion changes.
- (void)cancelAnimations;

/// Height includes the grid, exchange illustration and wrapped count captions.
/// Pass the actual available width; the owner should allow vertical scrolling.
- (CGSize)sizeThatFits:(CGSize)size;
@end

NS_ASSUME_NONNULL_END
