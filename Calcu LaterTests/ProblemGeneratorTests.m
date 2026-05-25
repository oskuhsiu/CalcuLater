#import <XCTest/XCTest.h>
#import "ArithmeticProblem.h"
#import "ProblemGenerator.h"

@interface ProblemGeneratorTests : XCTestCase
@end

@implementation ProblemGeneratorTests

- (void)testD1WithAdditionOnly {
    for (NSInteger i = 0; i < 50; i++) {
        ArithmeticProblem *p = [ProblemGenerator generateForTier:DrillTierD1
                                                   allowAddition:YES
                                                allowSubtraction:NO
                                             allowMultiplication:NO
                                                   allowDivision:NO];
        XCTAssertEqualObjects(p.operatorSymbol, @"+");
        XCTAssertGreaterThan(p.number1, 0);
        XCTAssertGreaterThan(p.number2, 0);
        XCTAssertLessThanOrEqual(p.number1, 20);
        XCTAssertLessThanOrEqual(p.number2, 20);
        XCTAssertEqual(p.answer, p.number1 + p.number2);
    }
}

- (void)testD2WithSubtractionResultNonNegative {
    for (NSInteger i = 0; i < 50; i++) {
        ArithmeticProblem *p = [ProblemGenerator generateForTier:DrillTierD2
                                                   allowAddition:NO
                                                allowSubtraction:YES
                                             allowMultiplication:NO
                                                   allowDivision:NO];
        XCTAssertEqualObjects(p.operatorSymbol, @"-");
        XCTAssertGreaterThanOrEqual(p.answer, 0);
        XCTAssertGreaterThanOrEqual(p.number1, p.number2);
    }
}

- (void)testDivisionAlwaysExact {
    for (NSInteger i = 0; i < 50; i++) {
        ArithmeticProblem *p = [ProblemGenerator generateForTier:DrillTierD2
                                                   allowAddition:NO
                                                allowSubtraction:NO
                                             allowMultiplication:NO
                                                   allowDivision:YES];
        XCTAssertEqualObjects(p.operatorSymbol, @"÷");
        XCTAssertNotEqual(p.number2, 0);
        XCTAssertEqual(p.number1 % p.number2, 0);
        XCTAssertEqual(p.answer, p.number1 / p.number2);
    }
}

- (void)testFallsBackToAdditionIfNoOpsAllowed {
    ArithmeticProblem *p = [ProblemGenerator generateForTier:DrillTierD1
                                               allowAddition:NO
                                            allowSubtraction:NO
                                         allowMultiplication:NO
                                               allowDivision:NO];
    XCTAssertEqualObjects(p.operatorSymbol, @"+");
}

@end
