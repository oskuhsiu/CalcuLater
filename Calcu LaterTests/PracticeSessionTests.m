#import <XCTest/XCTest.h>
#import "PracticeSession.h"
#import "PracticeProgressStore.h"

@interface PracticeSessionTests : XCTestCase
@end
@implementation PracticeSessionTests
- (void)testAResolvedQuestionWaitsForOneDeliberateAdvance {
    PracticeSession *s = [[PracticeSession alloc] initWithQuestions:@[@1, @2]];
    XCTAssertFalse([s advance]);
    XCTAssertTrue([s submitCorrect:YES]);
    XCTAssertTrue(s.awaitingNext);
    XCTAssertEqual(s.currentIndex, 0u);
    XCTAssertFalse([s submitCorrect:YES]);
    XCTAssertEqual(s.independentCount, 1u);
    XCTAssertTrue([s advance]);
    XCTAssertFalse([s advance]);
    XCTAssertEqual(s.currentIndex, 1u);
}
- (void)testHelpAndRetryAreHonestSeparateOutcomes {
    PracticeSession *s = [[PracticeSession alloc] initWithQuestions:@[@1, @2, @3]];
    [s submitCorrect:YES]; [s advance];
    [s submitCorrect:NO]; [s submitCorrect:YES]; [s advance];
    [s markHelpUsed]; [s markHelpUsed]; [s submitCorrect:YES]; [s advance];
    XCTAssertTrue(s.finished);
    XCTAssertEqual(s.independentCount, 1u);
    XCTAssertEqual(s.retriedCount, 1u);
    XCTAssertEqual(s.guidedCount, 1u);
    XCTAssertEqualObjects(s.reviewQuestions, (@[@2, @3]));
}
- (void)testThreeMissesKeepTheExplanationOnTheSameQuestion {
    PracticeSession *s = [[PracticeSession alloc] initWithQuestions:@[@1, @2]];
    [s submitCorrect:NO]; [s submitCorrect:NO]; [s submitCorrect:NO];
    XCTAssertTrue(s.awaitingNext);
    XCTAssertEqual(s.currentIndex, 0u);
    XCTAssertEqual(s.guidedCount, 1u);
    XCTAssertEqual(s.reviewQuestions.count, 1u);
    [s revealAnswer];
    XCTAssertFalse([s submitCorrect:YES]);
    XCTAssertEqual(s.guidedCount, 1u);
}
- (void)testReplayingHelpAfterSuccessDoesNotRewriteTheOutcome {
    PracticeSession *s = [[PracticeSession alloc] initWithQuestions:@[@1]];
    [s submitCorrect:YES]; [s markHelpUsed]; [s revealAnswer];
    XCTAssertEqual(s.independentCount, 1u);
    XCTAssertEqual(s.guidedCount, 0u);
    XCTAssertEqual(s.reviewQuestions.count, 0u);
}
- (void)testOnlyFinishedRunsAreRecordedAndOnlyOnce {
    NSString *suite = [@"PracticeSessionTests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    PracticeProgressStore *store = [[PracticeProgressStore alloc] initWithDefaults:defaults];
    PracticeSession *s = [[PracticeSession alloc] initWithQuestions:@[@1]];
    [store recordFinishedSession:s];
    XCTAssertEqual(store.completedSessions, 0);
    [s submitCorrect:YES]; [s advance];
    [store recordFinishedSession:s]; [store recordFinishedSession:s];
    XCTAssertEqual(store.completedSessions, 1);
    XCTAssertEqual(store.completedQuestions, 1);
    XCTAssertEqual(store.independentAnswers, 1);
    [defaults removePersistentDomainForName:suite];
}
@end
