#import <XCTest/XCTest.h>
#import "ArithmeticProblem.h"
#import "WordProblem.h"
#import "WordProblemTemplate.h"

@interface WordProblemExplanationTests : XCTestCase
@end

@implementation WordProblemExplanationTests

- (WordProblem *)divisionWithDividend:(NSInteger)dividend divisor:(NSInteger)divisor unit:(NSString *)unit {
    return [[WordProblem alloc] initWithStory:@"測試分裝故事" templateID:@"test_division" grade:3
                                     number1:dividend number2:divisor operator:@"÷"
                                      answer:dividend / divisor unit:unit
                               missingAddend:NO missingSubtrahend:NO missingMinuend:NO
                                   remainder:dividend % divisor
                                     number3:0 operator2:nil intermediate:0
                            isFractionAnswer:NO answerNumerator:0 answerDenominator:0];
}

- (void)testRemainderExplanationReconstructsDividendAndKeepsAnswerUnitOnQuotient {
    WordProblem *problem = [self divisionWithDividend:23 divisor:4 unit:@"包"];
    XCTAssertEqualObjects(problem.workedExplanationText,
                          @"23 ÷ 4 = 5 餘 3\n驗算：5 × 4 + 3 = 23\n這題只答商：5 包");
    XCTAssertFalse([problem.workedExplanationText containsString:@"5 × 4 = 23"]);
    XCTAssertFalse([problem.workedExplanationText containsString:@"3 包"]);
    XCTAssertEqualObjects([problem equationTextRevealingAnswer:NO], @"23 ÷ 4 = ?");
    XCTAssertEqualObjects([problem equationTextRevealingAnswer:YES], @"23 ÷ 4 = 5 餘 3");
    // 改善教學說明，不改動四選一仍然只回答商的契約。
    ArithmeticProblem *choiceProblem = [problem toArithmeticProblem];
    XCTAssertEqual(choiceProblem.answer, 5);
    XCTAssertEqual(choiceProblem.auxiliaryDistractor, 3);
    XCTAssertEqual(problem.answer * problem.number2 + problem.remainder, problem.number1);
}

- (void)testExactDivisionAndEmptyUnitDoNotInventARemainderOrUnit {
    WordProblem *exact = [self divisionWithDividend:20 divisor:4 unit:@"顆"];
    XCTAssertEqualObjects(exact.workedExplanationText,
                          @"20 ÷ 4 = 5\n驗算：5 × 4 = 20\n答案：5 顆");
    XCTAssertEqualObjects([exact equationTextRevealingAnswer:YES], @"20 ÷ 4 = 5 顆");
    WordProblem *unitless = [self divisionWithDividend:13 divisor:9 unit:@""];
    XCTAssertEqualObjects(unitless.workedExplanationText,
                          @"13 ÷ 9 = 1 餘 4\n驗算：1 × 9 + 4 = 13\n這題只答商：1");
}

- (void)testRemainderEqualToQuotientIsStillExplainedWithoutBecomingAWrongChoice {
    WordProblem *problem = [self divisionWithDividend:8 divisor:3 unit:@"包"];
    XCTAssertEqualObjects(problem.workedExplanationText,
                          @"8 ÷ 3 = 2 餘 2\n驗算：2 × 3 + 2 = 8\n這題只答商：2 包");
    XCTAssertEqual([problem toArithmeticProblem].answer, 2);
    XCTAssertEqual([problem toArithmeticProblem].auxiliaryDistractor, 0);
}

- (void)testInverseEquationsAndExplanationsUseTheUnknownAsTheAnswer {
    NSArray<NSString *> *hidden = @[@"? + 5 = 13", @"13 − ? = 5", @"? − 5 = 8"];
    NSArray<NSString *> *revealed = @[@"8 + 5 = 13\n答案：8 顆",
                                     @"13 − 8 = 5\n答案：8 顆",
                                     @"13 − 5 = 8\n答案：13 顆"];
    NSArray<NSString *> *calculations = @[@"13 − 5 = 8", @"13 − 5 = 8", @"5 + 8 = 13"];
    NSArray<NSString *> *checks = @[@"驗算：8 + 5 = 13", @"驗算：13 − 8 = 5", @"驗算：13 − 5 = 8"];
    for (NSUInteger kind = 0; kind < 3; kind++) {
        BOOL missingMinuend = kind == 2;
        WordProblem *problem = [[WordProblem alloc] initWithStory:@"測試反推故事" templateID:@"test_inverse" grade:1
                                                         number1:missingMinuend ? 5 : 13
                                                         number2:missingMinuend ? 8 : 5
                                                        operator:missingMinuend ? @"+" : @"-"
                                                          answer:missingMinuend ? 13 : 8 unit:@"顆"
                                                   missingAddend:kind == 0 missingSubtrahend:kind == 1
                                                  missingMinuend:missingMinuend remainder:0
                                                         number3:0 operator2:nil intermediate:0
                                                isFractionAnswer:NO answerNumerator:0 answerDenominator:0];
        XCTAssertEqualObjects([problem equationTextRevealingAnswer:NO], hidden[kind]);
        XCTAssertEqualObjects([problem equationTextRevealingAnswer:YES], revealed[kind]);
        XCTAssertTrue([problem.workedExplanationText containsString:calculations[kind]]);
        XCTAssertTrue([problem.workedExplanationText containsString:checks[kind]]);
        XCTAssertTrue([problem.workedExplanationText hasSuffix:missingMinuend ? @"答案：13 顆" : @"答案：8 顆"]);
    }
}

- (void)testTwoStepExplanationRetainsIntermediateAndFinalAnswer {
    WordProblem *problem = [[WordProblem alloc] initWithStory:@"測試二步驟故事" templateID:@"test_two_step" grade:2
                                                     number1:30 number2:20 operator:@"+" answer:43 unit:@"元"
                                              missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:0
                                                    number3:7 operator2:@"-" intermediate:50
                                           isFractionAnswer:NO answerNumerator:0 answerDenominator:0];
    XCTAssertEqualObjects(problem.workedExplanationText,
                          @"第一步：30 + 20 = 50\n第二步：50 − 7 = 43\n答案：43 元");
    XCTAssertEqualObjects([problem equationTextRevealingAnswer:NO], @"30 + 20 − 7 = ?");
    XCTAssertEqualObjects([problem equationTextRevealingAnswer:YES], @"30 + 20 − 7 = 43 元");
    XCTAssertEqual([problem toArithmeticProblem].answer, 43);
    XCTAssertEqual([problem toArithmeticProblem].auxiliaryDistractor, 50);
}

- (void)testFractionExplanationAndChocolateTemplateRequireEqualParts {
    WordProblem *problem = [[WordProblem alloc] initWithStory:@"測試分數故事" templateID:@"test_fraction" grade:3
                                                     number1:3 number2:8 operator:@"+" answer:0 unit:@""
                                              missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:0
                                                    number3:0 operator2:nil intermediate:0
                                           isFractionAnswer:YES answerNumerator:3 answerDenominator:8];
    XCTAssertEqualObjects(problem.workedExplanationText, @"把整個平均分成 8 等份\n取其中 3 份，就是 3/8");
    XCTAssertEqualObjects([problem equationTextRevealingAnswer:NO], @"答案：?");
    XCTAssertEqualObjects([problem equationTextRevealingAnswer:YES], @"答案：3/8");
    WordProblemTemplate *chocolate = nil;
    for (WordProblemTemplate *candidate in [WordProblemCatalog templatesForGrade:3]) {
        if ([candidate.templateID isEqualToString:@"g3_frac_chocbar"]) chocolate = candidate;
    }
    XCTAssertNotNil(chocolate);
    XCTAssertTrue([chocolate.storyPattern containsString:@"平均分成 {b} 等份"]);
    XCTAssertTrue([chocolate.storyPattern containsString:@"拿走 {a} 份"]);
}

- (void)testStandardArithmeticRetainsUnitsAndReadableOperators {
    WordProblem *subtraction = [[WordProblem alloc] initWithStory:@"測試故事" templateID:@"test_sub" grade:1
                                                         number1:12 number2:5 operator:@"-" answer:7 unit:@"本"];
    XCTAssertEqualObjects([subtraction equationTextRevealingAnswer:NO], @"12 − 5 = ?");
    XCTAssertEqualObjects([subtraction equationTextRevealingAnswer:YES], @"12 − 5 = 7 本");
    XCTAssertEqualObjects(subtraction.workedExplanationText, @"12 − 5 = 7\n答案：7 本");

    WordProblem *multiplication = [[WordProblem alloc] initWithStory:@"測試故事" templateID:@"test_mul" grade:2
                                                            number1:4 number2:3 operator:@"×" answer:12 unit:@"顆"];
    XCTAssertEqualObjects(multiplication.workedExplanationText, @"4 × 3\n= 4 + 4 + 4\n答案：12 顆");
}

@end
