#import <Foundation/Foundation.h>
@class PracticeSession;

NS_ASSUME_NONNULL_BEGIN
/// Device-local, anonymous practice totals. No account, network or child profile.
@interface PracticeProgressStore : NSObject
@property (class, nonatomic, readonly) PracticeProgressStore *sharedInstance;
@property (nonatomic, readonly) NSInteger completedSessions;
@property (nonatomic, readonly) NSInteger completedQuestions;
@property (nonatomic, readonly) NSInteger independentAnswers;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (void)recordFinishedSession:(PracticeSession *)session;
@end
NS_ASSUME_NONNULL_END
