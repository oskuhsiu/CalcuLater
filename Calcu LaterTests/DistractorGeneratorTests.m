#import <XCTest/XCTest.h>
#import "ArithmeticProblem.h"
#import "DistractorGenerator.h"

@interface DistractorGeneratorTests : XCTestCase
@end

@implementation DistractorGeneratorTests

- (ArithmeticProblem *)plus:(NSInteger)a and:(NSInteger)b {
    return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"+" answer:a + b];
}

- (ArithmeticProblem *)minus:(NSInteger)a sub:(NSInteger)b {
    return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"-" answer:a - b];
}

- (void)testProducesThreeDistractors {
    NSArray *d = [DistractorGenerator distractorsForProblem:[self plus:7 and:5]];
    XCTAssertEqual(d.count, 3);
}

- (void)testDistractorsExcludeCorrectAnswer {
    ArithmeticProblem *p = [self plus:8 and:6];
    NSArray *d = [DistractorGenerator distractorsForProblem:p];
    for (NSNumber *n in d) {
        XCTAssertNotEqual(n.integerValue, p.answer);
    }
}

- (void)testDistractorsAreUnique {
    ArithmeticProblem *p = [self plus:28 and:47];
    NSArray *d = [DistractorGenerator distractorsForProblem:p];
    XCTAssertEqual(d.count, [NSSet setWithArray:d].count);
}

- (void)testDistractorsNonNegative {
    ArithmeticProblem *p = [self minus:10 sub:9];
    NSArray *d = [DistractorGenerator distractorsForProblem:p];
    for (NSNumber *n in d) {
        XCTAssertGreaterThanOrEqual(n.integerValue, 0);
    }
}

- (void)testChoicesIncludeCorrectAnswer {
    ArithmeticProblem *p = [self plus:13 and:6];
    NSArray *c = [DistractorGenerator choicesForProblem:p];
    XCTAssertEqual(c.count, 4);
    XCTAssertTrue([c containsObject:@(p.answer)]);
}

- (void)testEdgeCaseZeroPlusZero {
    ArithmeticProblem *p = [self plus:0 and:0];
    NSArray *d = [DistractorGenerator distractorsForProblem:p];
    XCTAssertEqual(d.count, 3);
    for (NSNumber *n in d) {
        XCTAssertNotEqual(n.integerValue, 0);
        XCTAssertGreaterThanOrEqual(n.integerValue, 0);
    }
}

@end
