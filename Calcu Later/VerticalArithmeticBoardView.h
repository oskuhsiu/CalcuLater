#import <UIKit/UIKit.h>
#import "ArithmeticTeachingSequence.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VerticalArithmeticPlaybackState) {
    VerticalArithmeticPlaybackStateStill,
    VerticalArithmeticPlaybackStatePlaying,
    VerticalArithmeticPlaybackStateCompleted,
    VerticalArithmeticPlaybackStateInterrupted,
    VerticalArithmeticPlaybackStateReducedMotion
};

/// A child-paced, deterministic rendering of one immutable teaching snapshot.
/// The owner controls Back / Next / Replay; this view never advances the lesson.
@interface VerticalArithmeticBoardView : UIView
@property (nonatomic, strong, readonly, nullable) ArithmeticTeachingSequence *sequence;
@property (nonatomic, assign, readonly) NSInteger currentStepIndex;
@property (nonatomic, strong, readonly, nullable) ArithmeticTeachingStep *currentStep;
/// Actual laid-out regrouping regions, in board coordinates. CGRectNull on
/// other steps. Prefer the complete grid+concrete exchange when it fits; the
/// concrete region lets a compact-height owner prioritize countable motion.
@property (nonatomic, assign, readonly) CGRect currentTransformationRect;
@property (nonatomic, assign, readonly) CGRect currentConcreteTransformationRect;
/// Actual notation and action bounds; no guessed fraction of the overall board.
@property (nonatomic, assign, readonly) CGRect currentWrittenRect;
@property (nonatomic, assign, readonly) CGRect currentActionRect;
@property (nonatomic, assign, readonly) CGRect currentPlaybackRect;
@property (nonatomic, assign, readonly) VerticalArithmeticPlaybackState playbackState;
@property (nonatomic, assign, readonly, getter=isPlaying) BOOL playing;

/// Plays only after the complete action fits the unobscured viewport.
/// visibleRect is in board coordinates. If the notation also fits, animate its
/// packet too; otherwise keep notation still and animate only the concrete action.
/// Returns NO without motion when the required region does not fit. Reduce Motion
/// accepts a fully visible static snapshot, with its own observable playback state.
- (BOOL)playCurrentActionInVisibleRect:(CGRect)visibleRect;

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
