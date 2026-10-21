#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A finite, child-paced practice run. UI timers never own progression.
/// Questions may be ArithmeticProblem or WordProblem; the session only tracks
/// how the learner completed them, not their arithmetic or presentation.
@interface PracticeSession : NSObject
@property (nonatomic, copy, readonly) NSArray *questions;
@property (nonatomic, readonly) NSUInteger currentIndex;
@property (nonatomic, readonly, nullable) id currentQuestion;
@property (nonatomic, readonly) NSUInteger attempts;
@property (nonatomic, readonly) BOOL usedHelp;
@property (nonatomic, readonly) BOOL awaitingNext;
@property (nonatomic, readonly) BOOL finished;
@property (nonatomic, readonly) NSUInteger independentCount;
@property (nonatomic, readonly) NSUInteger retriedCount;
@property (nonatomic, readonly) NSUInteger guidedCount;
@property (nonatomic, copy, readonly) NSArray *reviewQuestions;

- (instancetype)initWithQuestions:(NSArray *)questions NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
/// Returns NO if this question has already resolved or the session is finished.
/// Three accepted misses resolve as guided; the answer remains until advance.
- (BOOL)submitCorrect:(BOOL)correct;
- (void)markHelpUsed;
- (void)revealAnswer;
/// Only a resolved question can advance; repeated callbacks cannot skip items.
- (BOOL)advance;
@end

NS_ASSUME_NONNULL_END
