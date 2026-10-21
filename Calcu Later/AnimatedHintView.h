#import <UIKit/UIKit.h>
@class ArithmeticProblem;

NS_ASSUME_NONNULL_BEGIN

/// Animated vertical calculation with one coherent VoiceOver explanation.
@interface AnimatedHintView : UIView
- (void)configureWithProblem:(ArithmeticProblem *)problem;

/// Finish at the fully visible state and invalidate pending reveal sounds.
/// Also called automatically when hidden, detached, reconfigured, or backgrounded.
- (void)cancelAnimations;
@end

NS_ASSUME_NONNULL_END
