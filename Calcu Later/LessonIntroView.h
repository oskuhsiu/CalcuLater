#import <UIKit/UIKit.h>

@class Lesson, ArithmeticProblem, LessonIntroView;

NS_ASSUME_NONNULL_BEGIN

@protocol LessonIntroViewDelegate <NSObject>
- (void)lessonIntroDidFinish:(LessonIntroView *)introView;
@end

/// One countable, child-paced teaching surface for L1–L5 introductions and
/// the actual make-ten / break-ten question. Only the child changes the step.
@interface LessonIntroView : UIView

@property (nonatomic, weak, nullable) id<LessonIntroViewDelegate> delegate;
@property (nonatomic, readonly) NSInteger currentStepIndex;
@property (nonatomic, readonly) NSInteger numberOfSteps;
@property (nonatomic, copy, readonly) NSString *currentNarration;

/// Canonical L1–L5 examples. “開始練習” remains available to skip the example.
- (instancetype)initWithLesson:(Lesson *)lesson;

/// Snapshots a valid, ordinary L4/L5 problem. Returns nil for mismatched
/// operators, answers, multi-step inputs or operands outside the lesson domain.
/// Invalid explicit input is never replaced by a canonical example.
/// The completion action says “回到題目” and never answers the question itself.
- (nullable instancetype)initWithProblem:(ArithmeticProblem *)problem lesson:(Lesson *)lesson;
+ (BOOL)supportsProblem:(ArithmeticProblem *)problem lesson:(Lesson *)lesson;

/// Presents/resumes the selected step. There is no timed progression.
- (void)play;
- (void)goToPreviousStep;
- (void)goToNextStep;
/// Reconstructs this step's own before-state, without restarting the lesson.
- (void)replayCurrentStep;

/// Cancels motion and speech and settles the selected state, never a future
/// step. Backgrounding, hiding, detaching and resizing do the same.
- (void)stopPlayback;

@end

NS_ASSUME_NONNULL_END
