#import "PracticeSession.h"

@interface PracticeSession ()
@property (nonatomic, copy, readwrite) NSArray *questions;
@property (nonatomic, readwrite) NSUInteger currentIndex;
@property (nonatomic, readwrite) NSUInteger attempts;
@property (nonatomic, readwrite) BOOL usedHelp;
@property (nonatomic, readwrite) BOOL awaitingNext;
@property (nonatomic, readwrite) NSUInteger independentCount;
@property (nonatomic, readwrite) NSUInteger retriedCount;
@property (nonatomic, readwrite) NSUInteger guidedCount;
@property (nonatomic, strong) NSMutableArray *reviewItems;
@end

@implementation PracticeSession
- (instancetype)initWithQuestions:(NSArray *)questions {
    self = [super init];
    if (self) {
        _questions = [questions copy];
        _reviewItems = [NSMutableArray array];
    }
    return self;
}
- (id)currentQuestion { return self.finished ? nil : self.questions[self.currentIndex]; }
- (BOOL)finished { return self.currentIndex >= self.questions.count; }
- (NSArray *)reviewQuestions { return [self.reviewItems copy]; }
- (void)addCurrentToReview {
    id question = self.currentQuestion;
    if (question && [self.reviewItems indexOfObjectIdenticalTo:question] == NSNotFound) {
        [self.reviewItems addObject:question];
    }
}
- (BOOL)submitCorrect:(BOOL)correct {
    if (self.finished || self.awaitingNext) return NO;
    self.attempts++;
    if (!correct) {
        [self addCurrentToReview];
        if (self.attempts >= 3) [self revealAnswer];
        return YES;
    }
    self.awaitingNext = YES;
    if (self.usedHelp) self.guidedCount++;
    else if (self.attempts == 1) self.independentCount++;
    else self.retriedCount++;
    return YES;
}
- (void)markHelpUsed {
    if (self.finished || self.awaitingNext) return;
    self.usedHelp = YES;
    [self addCurrentToReview];
}
- (void)revealAnswer {
    if (self.finished || self.awaitingNext) return;
    [self markHelpUsed];
    self.guidedCount++;
    self.awaitingNext = YES;
}
- (BOOL)advance {
    if (self.finished || !self.awaitingNext) return NO;
    self.currentIndex++;
    self.attempts = 0;
    self.usedHelp = NO;
    self.awaitingNext = NO;
    return YES;
}
@end
