#import "PracticeProgressStore.h"
#import "PracticeSession.h"

@interface PracticeProgressStore ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, strong) NSHashTable<PracticeSession *> *recordedSessions;
@end
@implementation PracticeProgressStore
+ (PracticeProgressStore *)sharedInstance {
    static PracticeProgressStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [[self alloc] initWithDefaults:NSUserDefaults.standardUserDefaults]; });
    return store;
}
- (instancetype)init { return [self initWithDefaults:NSUserDefaults.standardUserDefaults]; }
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults;
        _recordedSessions = [NSHashTable weakObjectsHashTable];
    }
    return self;
}
- (NSInteger)completedSessions { return MAX(0, [self.defaults integerForKey:@"practice.v1.sessions"]); }
- (NSInteger)completedQuestions { return MAX(0, [self.defaults integerForKey:@"practice.v1.questions"]); }
- (NSInteger)independentAnswers { return MAX(0, [self.defaults integerForKey:@"practice.v1.independent"]); }
- (void)recordFinishedSession:(PracticeSession *)session {
    if (!session.finished || session.questions.count == 0 || [self.recordedSessions containsObject:session]) return;
    [self.recordedSessions addObject:session];
    [self.defaults setInteger:self.completedSessions + 1 forKey:@"practice.v1.sessions"];
    [self.defaults setInteger:self.completedQuestions + session.questions.count forKey:@"practice.v1.questions"];
    [self.defaults setInteger:self.independentAnswers + session.independentCount forKey:@"practice.v1.independent"];
}
@end
