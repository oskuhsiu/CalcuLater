#import <XCTest/XCTest.h>
#import "ArithmeticProblem.h"
#import "Lesson.h"

@interface Lesson (DeterministicTesting)
- (uint32_t)randomBelow:(uint32_t)upperBound;
@end

@interface SeededLesson : Lesson
@property (nonatomic, assign) uint32_t randomState;
@end

@implementation SeededLesson
- (uint32_t)randomBelow:(uint32_t)upperBound {
    NSAssert(upperBound > 0, @"Cannot draw from an empty lesson pool");
    self.randomState = self.randomState * 1664525u + 1013904223u;
    return self.randomState % upperBound;
}
@end

@interface LessonTests : XCTestCase
@end

@implementation LessonTests

- (SeededLesson *)seededCopyOfLesson:(Lesson *)lesson seed:(uint32_t)seed {
    SeededLesson *copy = [[SeededLesson alloc] initWithID:lesson.lessonID title:lesson.title
                                              iconName:lesson.iconName kind:lesson.kind
                                         questionCount:lesson.questionCount
                                   multiplicationFactor:lesson.multiplicationFactor];
    copy.randomState = seed;
    return copy;
}

- (NSString *)keyForProblem:(ArithmeticProblem *)problem {
    return [NSString stringWithFormat:@"%ld%@%ld", (long)problem.number1,
            problem.operatorSymbol, (long)problem.number2];
}

- (void)assertUniqueProblems:(NSArray<ArithmeticProblem *> *)problems count:(NSUInteger)count {
    XCTAssertEqual(problems.count, count);
    NSMutableSet<NSString *> *keys = [NSMutableSet set];
    for (ArithmeticProblem *problem in problems) [keys addObject:[self keyForProblem:problem]];
    XCTAssertEqual(keys.count, count, @"A built-in lesson must not repeat a question");
}

- (void)testMultiplicationSessionsCoverAllNineFactsExactlyOnce {
    NSSet<NSNumber *> *expected = [NSSet setWithArray:@[@1, @2, @3, @4, @5, @6, @7, @8, @9]];
    for (Lesson *catalogLesson in [LessonCatalog multiplicationLessons]) {
        SeededLesson *lesson = [self seededCopyOfLesson:catalogLesson seed:42];
        NSArray<ArithmeticProblem *> *session = [lesson generateSessionProblems];
        [self assertUniqueProblems:session count:9];
        NSMutableSet<NSNumber *> *multipliers = [NSMutableSet set];
        for (ArithmeticProblem *problem in session) {
            XCTAssertEqualObjects(problem.operatorSymbol, @"×");
            XCTAssertEqual(problem.number1, lesson.multiplicationFactor);
            XCTAssertEqual(problem.answer, problem.number1 * problem.number2);
            [multipliers addObject:@(problem.number2)];
        }
        XCTAssertEqualObjects(multipliers, expected);
    }
}

- (void)testAdditionSessionsCoverTotalsWithoutOverweightingZero {
    NSArray<Lesson *> *catalog = [LessonCatalog addSubLessons];
    for (NSUInteger index = 0; index < 2; index++) {
        Lesson *lesson = [self seededCopyOfLesson:catalog[index] seed:17];
        NSInteger upper = index == 0 ? 5 : 10;
        NSArray<ArithmeticProblem *> *session = [lesson generateSessionProblems];
        [self assertUniqueProblems:session count:10];
        NSUInteger zeroCount = 0;
        NSMutableSet<NSNumber *> *positiveTotals = [NSMutableSet set];
        for (ArithmeticProblem *problem in session) {
            XCTAssertEqualObjects(problem.operatorSymbol, @"+");
            XCTAssertGreaterThan(problem.number1, 0);
            XCTAssertGreaterThanOrEqual(problem.number2, 0);
            XCTAssertEqual(problem.answer, problem.number1 + problem.number2);
            XCTAssertLessThanOrEqual(problem.answer, upper);
            if (problem.number2 == 0) zeroCount++;
            else [positiveTotals addObject:@(problem.answer)];
        }
        XCTAssertEqual(zeroCount, 1, @"Teach +0 without letting it dominate a ten-question session");
        for (NSInteger total = 2; total <= upper; total++) {
            XCTAssertTrue([positiveTotals containsObject:@(total)]);
        }
    }
}

- (void)testSubtractionIncludesTenAndBothZeroConcepts {
    Lesson *lesson = [self seededCopyOfLesson:[LessonCatalog addSubLessons][2] seed:81];
    NSArray<ArithmeticProblem *> *session = [lesson generateSessionProblems];
    [self assertUniqueProblems:session count:10];
    NSUInteger minusZeroCount = 0, zeroAnswerCount = 0;
    BOOL sawNontrivialSubtractionFromTen = NO;
    for (ArithmeticProblem *problem in session) {
        XCTAssertEqualObjects(problem.operatorSymbol, @"-");
        XCTAssertGreaterThanOrEqual(problem.number1, 1);
        XCTAssertLessThanOrEqual(problem.number1, 10);
        XCTAssertGreaterThanOrEqual(problem.number2, 0);
        XCTAssertLessThanOrEqual(problem.number2, problem.number1);
        XCTAssertEqual(problem.answer, problem.number1 - problem.number2);
        if (problem.number2 == 0) minusZeroCount++;
        if (problem.answer == 0) zeroAnswerCount++;
        if (problem.number1 == 10 && problem.number2 > 0 && problem.answer > 0) {
            sawNontrivialSubtractionFromTen = YES;
        }
    }
    XCTAssertEqual(minusZeroCount, 1);
    XCTAssertEqual(zeroAnswerCount, 1);
    XCTAssertTrue(sawNontrivialSubtractionFromTen);
}

- (void)testMakeAndBreakTenSessionsCoverEveryStartingNumber {
    NSArray<Lesson *> *catalog = [LessonCatalog addSubLessons];
    for (NSUInteger index = 3; index <= 4; index++) {
        Lesson *lesson = [self seededCopyOfLesson:catalog[index] seed:2026];
        NSArray<ArithmeticProblem *> *session = [lesson generateSessionProblems];
        [self assertUniqueProblems:session count:10];
        NSMutableSet<NSNumber *> *startingNumbers = [NSMutableSet set];
        for (ArithmeticProblem *problem in session) {
            [startingNumbers addObject:@(problem.number1)];
            XCTAssertGreaterThanOrEqual(problem.number2, 1);
            XCTAssertLessThanOrEqual(problem.number2, 9);
            if (index == 3) {
                XCTAssertEqualObjects(problem.operatorSymbol, @"+");
                XCTAssertGreaterThanOrEqual(problem.number1, 2);
                XCTAssertLessThanOrEqual(problem.number1, 9);
                XCTAssertEqual(problem.answer, problem.number1 + problem.number2);
                XCTAssertGreaterThan(problem.answer, 10);
                XCTAssertLessThanOrEqual(problem.answer, 18);
            } else {
                XCTAssertEqualObjects(problem.operatorSymbol, @"-");
                XCTAssertGreaterThanOrEqual(problem.number1, 11);
                XCTAssertLessThanOrEqual(problem.number1, 18);
                XCTAssertGreaterThan(problem.number2, problem.number1 % 10);
                XCTAssertEqual(problem.answer, problem.number1 - problem.number2);
            }
        }
        XCTAssertEqual(startingNumbers.count, 8);
    }
}

- (void)testSessionBoundariesNeverImmediatelyRepeat {
    NSMutableArray<Lesson *> *catalog = [[LessonCatalog addSubLessons] mutableCopy];
    [catalog addObjectsFromArray:[LessonCatalog multiplicationLessons]];
    for (Lesson *catalogLesson in catalog) {
        Lesson *lesson = [self seededCopyOfLesson:catalogLesson seed:12345];
        NSString *previousKey = nil;
        // 固定種子的重開流程，會經過不同洗牌順序，不依賴碰巧抽到某題。
        for (NSUInteger sessionIndex = 0; sessionIndex < 12; sessionIndex++) {
            NSArray<ArithmeticProblem *> *session = [lesson generateSessionProblems];
            [self assertUniqueProblems:session count:(NSUInteger)lesson.questionCount];
            for (ArithmeticProblem *problem in session) {
                NSString *key = [self keyForProblem:problem];
                XCTAssertNotEqualObjects(key, previousKey);
                previousKey = key;
            }
        }
    }
}

- (void)testLegacySingleProblemAPIConsumesTheSameCompleteDeck {
    Lesson *lesson = [self seededCopyOfLesson:[LessonCatalog multiplicationLessons][6] seed:7];
    NSString *previousKey = nil;
    for (NSUInteger sessionIndex = 0; sessionIndex < 3; sessionIndex++) {
        NSMutableSet<NSNumber *> *multipliers = [NSMutableSet set];
        for (NSUInteger i = 0; i < 9; i++) {
            ArithmeticProblem *problem = [lesson generateProblem];
            NSString *key = [self keyForProblem:problem];
            XCTAssertNotEqualObjects(key, previousKey);
            previousKey = key;
            [multipliers addObject:@(problem.number2)];
        }
        XCTAssertEqual(multipliers.count, 9);
    }
}

@end
