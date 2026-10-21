#import <XCTest/XCTest.h>
#import "ArithmeticTeachingSequence.h"

@interface ArithmeticTeachingSequenceTests : XCTestCase
@end

@implementation ArithmeticTeachingSequenceTests

- (ArithmeticTeachingSequence *)sequence:(NSInteger)first operation:(NSString *)operation
                                 second:(NSInteger)second answer:(NSInteger)answer {
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:first
        number2:second operator:operation answer:answer];
    return [ArithmeticTeachingSequence sequenceForProblem:problem];
}

- (NSArray<ArithmeticTeachingStep *> *)stepsOfKind:(ArithmeticTeachingStepKind)kind
                                       sequence:(ArithmeticTeachingSequence *)sequence {
    NSMutableArray<ArithmeticTeachingStep *> *result = [NSMutableArray array];
    for (ArithmeticTeachingStep *step in sequence.steps) {
        if (step.kind == kind) [result addObject:step];
    }
    return result;
}

- (NSInteger)weightedValue:(NSArray<NSNumber *> *)counts {
    NSInteger value = 0;
    for (NSNumber *count in counts) value = value * 10 + count.integerValue;
    return value;
}

/// Checks the rendering contract, not merely the final numeric answer.
- (void)assertSequenceContract:(ArithmeticTeachingSequence *)sequence {
    XCTAssertTrue(sequence.isValid);
    XCTAssertGreaterThan(sequence.columnCount, 0);
    XCTAssertLessThanOrEqual(sequence.columnCount, 5);
    XCTAssertEqual(sequence.steps.firstObject.kind, ArithmeticTeachingStepKindAlignment);
    XCTAssertEqual(sequence.steps.lastObject.kind, ArithmeticTeachingStepKindCompletion);
    for (id digit in sequence.steps.firstObject.visibleAnswerDigits) {
        XCTAssertEqualObjects(digit, [NSNull null]);
    }
    NSInteger nextWriteColumn = sequence.columnCount - 1;
    NSArray *previousVisible = nil;
    NSArray<NSNumber *> *previousWorking = nil;
    NSUInteger stepIndex = 0;
    for (ArithmeticTeachingStep *step in sequence.steps) {
        XCTAssertEqual(step.firstDigits.count, sequence.columnCount);
        XCTAssertEqual(step.secondDigits.count, sequence.columnCount);
        XCTAssertEqual(step.workingDigits.count, sequence.columnCount);
        XCTAssertEqual(step.workingDigitsBefore.count, sequence.columnCount);
        XCTAssertEqual(step.carryDigits.count, sequence.columnCount);
        XCTAssertEqual(step.visibleAnswerDigits.count, sequence.columnCount);
        XCTAssertEqual([self weightedValue:step.firstDigits], sequence.problem.number1);
        XCTAssertEqual([self weightedValue:step.secondDigits], sequence.problem.number2);
        XCTAssertGreaterThan(step.title.length, 0u);
        XCTAssertGreaterThan(step.explanation.length, 0u);
        if (previousWorking) XCTAssertEqualObjects(step.workingDigitsBefore, previousWorking);
        if (step.kind == ArithmeticTeachingStepKindAlignment || step.kind == ArithmeticTeachingStepKindCompletion) {
            XCTAssertEqual(step.activeColumn, NSNotFound);
        } else {
            XCTAssertGreaterThanOrEqual(step.activeColumn, 0);
            XCTAssertLessThan(step.activeColumn, sequence.columnCount);
        }
        if (step.kind == ArithmeticTeachingStepKindPrediction) {
            XCTAssertNotNil(step.expectedAnswer);
            XCTAssertGreaterThan(step.prompt.length, 0u);
            XCTAssertGreaterThanOrEqual(step.expectedAnswer.integerValue, 0);
            XCTAssertLessThanOrEqual(step.expectedAnswer.integerValue, 19);
            XCTAssertLessThan(stepIndex + 1, sequence.steps.count);
            ArithmeticTeachingStep *next = sequence.steps[stepIndex + 1];
            XCTAssertTrue(next.kind == ArithmeticTeachingStepKindColumnCalculation ||
                          next.kind == ArithmeticTeachingStepKindRegroup);
            XCTAssertEqualObjects(step.expectedAnswer,
                next.kind == ArithmeticTeachingStepKindRegroup ? @10 : next.columnValue);
        } else {
            XCTAssertNil(step.expectedAnswer);
            XCTAssertEqualObjects(step.prompt, @"");
        }
        if (step.kind == ArithmeticTeachingStepKindRegroup) {
            XCTAssertGreaterThanOrEqual(step.sourceColumn, 0);
            XCTAssertLessThan(step.sourceColumn, sequence.columnCount);
            XCTAssertGreaterThanOrEqual(step.destinationColumn, 0);
            XCTAssertLessThan(step.destinationColumn, sequence.columnCount);
            XCTAssertTrue(step.sourceColumn == step.destinationColumn + 1 ||
                          step.destinationColumn == step.sourceColumn + 1);
            XCTAssertEqual([self weightedValue:step.workingDigitsBefore], [self weightedValue:step.workingDigits]);
            BOOL carry = step.sourceColumn > step.destinationColumn;
            XCTAssertGreaterThan(stepIndex, 0u);
            XCTAssertEqual(sequence.steps[stepIndex - 1].kind,
                carry ? ArithmeticTeachingStepKindColumnCalculation : ArithmeticTeachingStepKindPrediction);
            for (NSInteger column = 0; column < sequence.columnCount; column++) {
                NSInteger delta = step.workingDigits[column].integerValue - step.workingDigitsBefore[column].integerValue;
                NSInteger expected = column == step.sourceColumn ? (carry ? -10 : -1)
                    : column == step.destinationColumn ? (carry ? 1 : 10) : 0;
                XCTAssertEqual(delta, expected);
            }
        } else {
            XCTAssertEqual(step.sourceColumn, NSNotFound);
            XCTAssertEqual(step.destinationColumn, NSNotFound);
        }
        if (step.kind == ArithmeticTeachingStepKindColumnCalculation || step.kind == ArithmeticTeachingStepKindWriteAnswer) {
            XCTAssertNotNil(step.columnValue);
        } else {
            XCTAssertNil(step.columnValue);
        }
        if (step.kind == ArithmeticTeachingStepKindColumnCalculation) {
            NSUInteger writeIndex = stepIndex + 1;
            if (sequence.steps[writeIndex].kind == ArithmeticTeachingStepKindRegroup) writeIndex++;
            XCTAssertLessThan(writeIndex, sequence.steps.count);
            XCTAssertEqual(sequence.steps[writeIndex].kind, ArithmeticTeachingStepKindWriteAnswer);
            XCTAssertEqual(sequence.steps[writeIndex].activeColumn, step.activeColumn);
        }
        if (step.kind == ArithmeticTeachingStepKindWriteAnswer) {
            XCTAssertEqual(step.activeColumn, nextWriteColumn);
            nextWriteColumn--;
            XCTAssertGreaterThanOrEqual(step.columnValue.integerValue, 0);
            XCTAssertLessThanOrEqual(step.columnValue.integerValue, 9);
        }
        for (NSInteger column = 0; column < sequence.columnCount; column++) {
            XCTAssertGreaterThanOrEqual(step.workingDigits[column].integerValue, 0);
            XCTAssertLessThanOrEqual(step.workingDigits[column].integerValue, 19);
            id visible = step.visibleAnswerDigits[column];
            if (visible != [NSNull null]) {
                XCTAssertGreaterThanOrEqual([visible integerValue], 0);
                XCTAssertLessThanOrEqual([visible integerValue], 9);
                XCTAssertGreaterThanOrEqual(column, sequence.answerStartColumn);
            }
            if (previousVisible && ![previousVisible[column] isEqual:visible]) {
                XCTAssertEqual(step.kind, ArithmeticTeachingStepKindWriteAnswer);
                XCTAssertEqual(column, step.activeColumn);
                XCTAssertEqualObjects(previousVisible[column], [NSNull null]);
                XCTAssertEqualObjects(visible, step.columnValue);
            }
        }
        previousVisible = step.visibleAnswerDigits;
        previousWorking = step.workingDigits;
        stepIndex++;
    }
    XCTAssertEqual(nextWriteColumn, -1);
    for (NSInteger column = 0; column < sequence.columnCount; column++) {
        id digit = sequence.steps.lastObject.visibleAnswerDigits[column];
        if (column < sequence.answerStartColumn) XCTAssertEqualObjects(digit, [NSNull null]);
        else XCTAssertTrue([digit isKindOfClass:[NSNumber class]]);
    }
    NSInteger reconstructed = 0;
    for (id digit in sequence.steps.lastObject.visibleAnswerDigits) {
        reconstructed = reconstructed * 10 + (digit == [NSNull null] ? 0 : [digit integerValue]);
    }
    XCTAssertEqual(reconstructed, sequence.problem.answer);
}

- (void)testAlignmentNeverRevealsAnswerAndKeepsPaddedPlaces {
    ArithmeticTeachingSequence *sequence = [self sequence:5 operation:@"+" second:18 answer:23];
    [self assertSequenceContract:sequence];
    XCTAssertEqual(sequence.columnCount, 2);
    XCTAssertEqual(sequence.firstOperandStartColumn, 1);
    XCTAssertEqual(sequence.secondOperandStartColumn, 0);
    XCTAssertEqual(sequence.answerStartColumn, 0);
    ArithmeticTeachingStep *initial = sequence.steps.firstObject;
    XCTAssertEqualObjects(initial.firstDigits, (@[@0, @5]));
    XCTAssertEqualObjects(initial.secondDigits, (@[@1, @8]));
    XCTAssertEqualObjects(initial.workingDigits, initial.firstDigits);
    XCTAssertEqualObjects(initial.visibleAnswerDigits, (@[[NSNull null], [NSNull null]]));
    XCTAssertEqualObjects(initial.carryDigits, (@[@0, @0]));
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleAnswerDigits, (@[@2, @3]));
}

- (void)testNoCarryAndNoBorrowStillAskBeforeWriting {
    NSArray *sequences = @[[self sequence:12 operation:@"+" second:34 answer:46],
                          [self sequence:48 operation:@"-" second:23 answer:25]];
    for (ArithmeticTeachingSequence *sequence in sequences) {
        [self assertSequenceContract:sequence];
        XCTAssertEqual(sequence.steps.count, 8u);
        XCTAssertEqual([self stepsOfKind:ArithmeticTeachingStepKindRegroup sequence:sequence].count, 0u);
        for (NSInteger index = 1; index <= 4; index += 3) {
            XCTAssertEqual(sequence.steps[index].kind, ArithmeticTeachingStepKindPrediction);
            XCTAssertEqual(sequence.steps[index + 1].kind, ArithmeticTeachingStepKindColumnCalculation);
            XCTAssertEqual(sequence.steps[index + 2].kind, ArithmeticTeachingStepKindWriteAnswer);
        }
    }
}

- (void)testAdditionCombinesThenExchangesTenAndConsumesCarryOnce {
    ArithmeticTeachingSequence *sequence = [self sequence:28 operation:@"+" second:47 answer:75];
    [self assertSequenceContract:sequence];
    NSArray<ArithmeticTeachingStep *> *exchanges = [self stepsOfKind:ArithmeticTeachingStepKindRegroup sequence:sequence];
    XCTAssertEqual(exchanges.count, 1u);
    ArithmeticTeachingStep *exchange = exchanges.firstObject;
    XCTAssertEqualObjects(exchange.workingDigitsBefore, (@[@2, @15]));
    XCTAssertEqualObjects(exchange.workingDigits, (@[@3, @5]));
    XCTAssertEqualObjects(exchange.carryDigits, (@[@1, @0]));
    XCTAssertEqualObjects(exchange.visibleAnswerDigits, (@[[NSNull null], [NSNull null]]));
    NSArray<ArithmeticTeachingStep *> *calculations = [self stepsOfKind:ArithmeticTeachingStepKindColumnCalculation sequence:sequence];
    XCTAssertEqualObjects(calculations[0].columnValue, @15);
    XCTAssertEqualObjects(calculations[1].columnValue, @7);
    XCTAssertEqualObjects(calculations[1].workingDigits, (@[@7, @5]));
    XCTAssertEqualObjects(calculations[1].carryDigits, (@[@0, @0]));
}

- (void)testPredictionCopyAsksWithoutStatingTheOutcome {
    ArithmeticTeachingSequence *addition = [self sequence:28 operation:@"+" second:47 answer:75];
    NSArray<ArithmeticTeachingStep *> *addQuestions = [self stepsOfKind:ArithmeticTeachingStepKindPrediction sequence:addition];
    XCTAssertEqualObjects(addQuestions[0].expectedAnswer, @15);
    XCTAssertEqualObjects(addQuestions[0].explanation, @"來看個位。把這一欄的兩個數合在一起。");
    XCTAssertEqualObjects(addQuestions[0].prompt, @"個位：8 + 7，一共有幾個一？");
    XCTAssertEqualObjects(addQuestions[1].expectedAnswer, @7);
    XCTAssertEqualObjects(addQuestions[1].explanation, @"來看十位。把兩個數和剛才換來的 1 個十合在一起。");
    XCTAssertEqualObjects(addQuestions[1].prompt, @"十位：2 + 4 + 1，一共有幾個十？");

    ArithmeticTeachingSequence *subtraction = [self sequence:500 operation:@"-" second:128 answer:372];
    NSArray<ArithmeticTeachingStep *> *subQuestions = [self stepsOfKind:ArithmeticTeachingStepKindPrediction sequence:subtraction];
    XCTAssertEqualObjects(subQuestions[0].expectedAnswer, @10);
    XCTAssertEqualObjects(subQuestions[0].explanation, @"個位的數量不夠減，先從百位換到十位。");
    XCTAssertEqualObjects(subQuestions[0].prompt, @"1 個百可以換成幾個十？");
    XCTAssertEqualObjects(subQuestions[2].expectedAnswer, @2);
    XCTAssertEqualObjects(subQuestions[2].explanation, @"個位現在有 10 個一，拿走 8 個一。");
    XCTAssertEqualObjects(subQuestions[2].prompt, @"10 − 8，還剩幾個一？");
    // Exact fixtures inspect what is said, not a digit-substring heuristic:
    // an operand or an incoming carry may legitimately equal the expected answer.
}

- (void)testCarryChain999Plus1MakesThreeSeparateExchanges {
    ArithmeticTeachingSequence *sequence = [self sequence:999 operation:@"+" second:1 answer:1000];
    [self assertSequenceContract:sequence];
    NSArray<ArithmeticTeachingStep *> *exchanges = [self stepsOfKind:ArithmeticTeachingStepKindRegroup sequence:sequence];
    XCTAssertEqual(exchanges.count, 3u);
    NSArray *expected = @[@[@0, @9, @10, @0], @[@0, @10, @0, @0], @[@1, @0, @0, @0]];
    for (NSInteger index = 0; index < 3; index++) {
        XCTAssertEqual(exchanges[index].sourceColumn, 3 - index);
        XCTAssertEqual(exchanges[index].destinationColumn, 2 - index);
        XCTAssertEqualObjects(exchanges[index].workingDigits, expected[index]);
    }
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleAnswerDigits, (@[@1, @0, @0, @0]));
}

- (void)test500Minus128ShowsZeroToTenBeforeTenToNine {
    ArithmeticTeachingSequence *sequence = [self sequence:500 operation:@"-" second:128 answer:372];
    [self assertSequenceContract:sequence];
    NSArray<ArithmeticTeachingStep *> *exchanges = [self stepsOfKind:ArithmeticTeachingStepKindRegroup sequence:sequence];
    XCTAssertEqual(exchanges.count, 2u);
    XCTAssertEqualObjects(exchanges[0].workingDigitsBefore, (@[@5, @0, @0]));
    XCTAssertEqualObjects(exchanges[0].workingDigits, (@[@4, @10, @0]));
    XCTAssertEqualObjects(exchanges[1].workingDigitsBefore, (@[@4, @10, @0]));
    XCTAssertEqualObjects(exchanges[1].workingDigits, (@[@4, @9, @10]));
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleAnswerDigits, (@[@3, @7, @2]));
    for (ArithmeticTeachingStep *step in sequence.steps) {
        XCTAssertEqual([self weightedValue:step.workingDigits], 500);
    }
}

- (void)test1000Minus1ExchangesThroughEachZeroAndSuppressesLeadingAnswerZero {
    ArithmeticTeachingSequence *sequence = [self sequence:1000 operation:@"-" second:1 answer:999];
    [self assertSequenceContract:sequence];
    NSArray<ArithmeticTeachingStep *> *exchanges = [self stepsOfKind:ArithmeticTeachingStepKindRegroup sequence:sequence];
    XCTAssertEqual(exchanges.count, 3u);
    XCTAssertEqualObjects(exchanges[0].workingDigits, (@[@0, @10, @0, @0]));
    XCTAssertEqualObjects(exchanges[1].workingDigits, (@[@0, @9, @10, @0]));
    XCTAssertEqualObjects(exchanges[2].workingDigits, (@[@0, @9, @9, @10]));
    XCTAssertEqual(sequence.answerStartColumn, 1);
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleAnswerDigits, (@[[NSNull null], @9, @9, @9]));
}

- (void)testSeparateBorrowEventsRetainPreviousExchanges {
    ArithmeticTeachingSequence *sequence = [self sequence:8132 operation:@"-" second:4365 answer:3767];
    [self assertSequenceContract:sequence];
    NSArray<ArithmeticTeachingStep *> *exchanges = [self stepsOfKind:ArithmeticTeachingStepKindRegroup sequence:sequence];
    XCTAssertEqual(exchanges.count, 3u);
    XCTAssertEqualObjects(exchanges[0].workingDigits, (@[@8, @1, @2, @12]));
    XCTAssertEqualObjects(exchanges[1].workingDigits, (@[@8, @0, @12, @12]));
    XCTAssertEqualObjects(exchanges[2].workingDigits, (@[@7, @10, @12, @12]));
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleAnswerDigits, (@[@3, @7, @6, @7]));
}

- (void)testZeroAnswerIsOneVisibleZeroNotAnEmptyRow {
    for (ArithmeticTeachingSequence *sequence in @[[self sequence:0 operation:@"+" second:0 answer:0],
                                                   [self sequence:100 operation:@"-" second:100 answer:0]]) {
        [self assertSequenceContract:sequence];
        XCTAssertEqual(sequence.answerStartColumn, sequence.columnCount - 1);
        XCTAssertEqualObjects(sequence.steps.lastObject.visibleAnswerDigits.lastObject, @0);
        for (NSInteger column = 0; column < sequence.answerStartColumn; column++) {
            XCTAssertEqualObjects(sequence.steps.lastObject.visibleAnswerDigits[column], [NSNull null]);
        }
    }
}

- (void)testCopiesInputProblemAndReturnsDefensiveSnapshots {
    NSMutableString *operation = [NSMutableString stringWithString:@"+"];
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:28 number2:47 operator:operation answer:75];
    ArithmeticTeachingSequence *sequence = [ArithmeticTeachingSequence sequenceForProblem:problem];
    [operation setString:@"-"];
    problem.number1 = 99999;
    problem.number2 = 99999;
    problem.answer = 1;
    problem.isMultiStep = YES;
    ArithmeticProblem *exposed = sequence.problem;
    exposed.number1 = 0;
    exposed.answer = 0;
    exposed.operatorSymbol = @"÷";
    [self assertSequenceContract:sequence];
    XCTAssertEqual(sequence.problem.number1, 28);
    XCTAssertEqual(sequence.problem.number2, 47);
    XCTAssertEqual(sequence.problem.answer, 75);
    XCTAssertEqualObjects(sequence.problem.operatorSymbol, @"+");
    XCTAssertFalse(sequence.problem.isMultiStep);
    XCTAssertEqualObjects(sequence.steps.firstObject.workingDigits, (@[@2, @8]));
    XCTAssertEqualObjects(sequence.steps.firstObject.visibleAnswerDigits, (@[[NSNull null], [NSNull null]]));
}

- (void)testUnicodeMinusIsNormalized {
    ArithmeticTeachingSequence *sequence = [self sequence:20 operation:@"−" second:3 answer:17];
    [self assertSequenceContract:sequence];
    XCTAssertEqualObjects(sequence.problem.operatorSymbol, @"-");
}

- (void)testInvalidInputsHaveNoRenderableSteps {
    NSArray<NSArray *> *cases = @[
        @[@2, @3, @"+", @4], @[@5, @2, @"-", @4],
        @[@(-1), @2, @"+", @1], @[@1, @(-1), @"-", @2],
        @[@1, @2, @"-", @(-1)], @[@1, @2, @"-", @0],
        @[@100000, @0, @"+", @100000], @[@0, @100000, @"+", @100000],
        @[@99999, @1, @"+", @100000], @[@(NSIntegerMax), @1, @"+", @0],
        @[@(NSIntegerMin), @0, @"-", @0],
        @[@2, @3, @"×", @6], @[@8, @2, @"÷", @4],
        @[@8, @0, @"÷", @0], @[@1, @1, @"?", @2], @[@1, @1, @"", @2]
    ];
    NSMutableArray<ArithmeticTeachingSequence *> *invalid = [NSMutableArray array];
    [invalid addObject:[ArithmeticTeachingSequence sequenceForProblem:nil]];
    for (NSArray *values in cases) {
        [invalid addObject:[self sequence:[values[0] integerValue] operation:values[2]
                                  second:[values[1] integerValue] answer:[values[3] integerValue]]];
    }
    ArithmeticProblem *multiStep = [[ArithmeticProblem alloc] initWithNumber1:2 number2:3 operator:@"+" answer:5];
    multiStep.isMultiStep = YES;
    [invalid addObject:[ArithmeticTeachingSequence sequenceForProblem:multiStep]];
    for (ArithmeticTeachingSequence *sequence in invalid) {
        XCTAssertFalse(sequence.isValid);
        XCTAssertEqual(sequence.columnCount, 0);
        XCTAssertEqual(sequence.steps.count, 0u);
        XCTAssertEqual(sequence.firstOperandStartColumn, NSNotFound);
        XCTAssertEqual(sequence.secondOperandStartColumn, NSNotFound);
        XCTAssertEqual(sequence.answerStartColumn, NSNotFound);
    }
}

- (void)testBoundaryAndRepresentativeProblemsRespectEverySnapshotInvariant {
    NSArray<NSArray *> *cases = @[
        @[@99998, @1, @"+", @99999], @[@99999, @0, @"+", @99999],
        @[@50000, @49999, @"+", @99999], @[@1, @9999, @"+", @10000],
        @[@56789, @43210, @"+", @99999], @[@9, @9, @"+", @18],
        @[@10000, @1, @"-", @9999], @[@99999, @99998, @"-", @1],
        @[@99999, @0, @"-", @99999], @[@10001, @9999, @"-", @2],
        @[@102, @38, @"-", @64], @[@1010, @19, @"-", @991],
        @[@500, @499, @"-", @1], @[@90000, @89999, @"-", @1]
    ];
    for (NSArray *values in cases) {
        [self assertSequenceContract:[self sequence:[values[0] integerValue] operation:values[2]
                                             second:[values[1] integerValue] answer:[values[3] integerValue]]];
    }
}

@end
