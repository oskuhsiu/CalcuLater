#import <XCTest/XCTest.h>
#include <stdlib.h>
#import "MultiplicativeTeachingSequence.h"

static NSInteger MTTestWeighted(NSArray<NSNumber *> *counts) {
    NSInteger value = 0;
    for (NSNumber *count in counts) value = value * 10 + count.integerValue;
    return value;
}

static BOOL MTTestCounts(NSArray<NSNumber *> *counts, NSInteger maximum) {
    if (counts.count != 3) return NO;
    for (id count in counts) {
        if (![count isKindOfClass:NSNumber.class] || [count integerValue] < 0 || [count integerValue] > maximum) return NO;
    }
    return YES;
}

static BOOL MTTestMultiplyStatesEqual(MultiplicativeMultiplicationState *a, MultiplicativeMultiplicationState *b) {
    return [a.accumulatorCounts isEqual:b.accumulatorCounts] && [a.carryCounts isEqual:b.carryCounts]
        && [a.processedInputColumns isEqual:b.processedInputColumns];
}

static BOOL MTTestDivideStatesEqual(MultiplicativeDivisionState *a, MultiplicativeDivisionState *b) {
    return [a.unprocessedInputCounts isEqual:b.unprocessedInputCounts] && [a.poolCounts isEqual:b.poolCounts]
        && [a.recipientCounts isEqual:b.recipientCounts];
}

@interface MultiplicativeTeachingSequenceTests : XCTestCase
@end

@implementation MultiplicativeTeachingSequenceTests

- (MultiplicativeTeachingSequence *)sequence:(NSInteger)a operation:(NSString *)operation second:(NSInteger)b answer:(NSInteger)answer {
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation answer:answer];
    return [MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem];
}

- (NSArray<MultiplicativeTeachingStep *> *)steps:(MultiplicativeTeachingSequence *)sequence kind:(MultiplicativeTeachingStepKind)kind {
    NSMutableArray *steps = [NSMutableArray array];
    for (MultiplicativeTeachingStep *step in sequence.steps) if (step.kind == kind) [steps addObject:step];
    return steps;
}

/// One diagnostic per input in the bounded sweep, not hundreds of thousands of
/// individual XCTest assertions. Fixtures below separately name rendering contracts.
- (NSString *)contractFailure:(MultiplicativeTeachingSequence *)sequence {
    if (!sequence.isSupported || sequence.columnCount != 3 || sequence.steps.count >= 24 || sequence.steps.count < 2) return @"bounds/status";
    if (sequence.steps.firstObject.kind != MultiplicativeTeachingStepKindObserve
        || sequence.steps.lastObject.kind != MultiplicativeTeachingStepKindCompletion) return @"bookends";
    ArithmeticProblem *problem = sequence.problem;
    BOOL multiplication = sequence.operation == MultiplicativeTeachingOperationMultiplication;
    NSArray *previousVisible = @[[NSNull null], [NSNull null], [NSNull null]];
    NSIndexSet *previousCompleted = [NSIndexSet indexSet];
    MultiplicativeTeachingStep *previous = nil;
    NSUInteger previousRowCount = 0;
    BOOL inspectedRemainder = NO, quotientStarted = NO;
    NSUInteger inspectCount = 0, verifyCount = 0;
    NSInteger nextWriteColumn = multiplication ? 2 : sequence.operandStartColumn;
    MultiplicativeTeachingStep *initial = sequence.steps.firstObject;
    if (multiplication) {
        if (MTTestWeighted(initial.multiplication.before.accumulatorCounts) != 0
            || MTTestWeighted(initial.multiplication.before.carryCounts) != 0
            || initial.multiplication.before.processedInputColumns.count != 0) return @"initial multiplication inventory";
    } else {
        if (![initial.division.before.unprocessedInputCounts isEqual:sequence.operandDigits]
            || MTTestWeighted(initial.division.before.poolCounts) != 0) return @"initial division inventory";
        for (NSArray *recipient in initial.division.before.recipientCounts) if (MTTestWeighted(recipient) != 0) return @"preallocated quotient units";
    }
    for (MultiplicativeTeachingStep *step in sequence.steps) {
        BOOL writing = step.kind == MultiplicativeTeachingStepKindWriteDigit;
        BOOL predicting = step.kind == MultiplicativeTeachingStepKindPredict;
        BOOL exchanging = step.kind == MultiplicativeTeachingStepKindRegroupUp || step.kind == MultiplicativeTeachingStepKindRegroupDown;
        BOOL columnless = step.kind == MultiplicativeTeachingStepKindObserve || step.kind == MultiplicativeTeachingStepKindInspectRemainder
            || step.kind == MultiplicativeTeachingStepKindVerify || step.kind == MultiplicativeTeachingStepKindCompletion;
        if (!step.title.length || !step.explanation.length || !step.spokenExplanation.length) return @"empty copy";
        if (columnless ? step.activeColumn != NSNotFound : (step.activeColumn < 0 || step.activeColumn > 2)) return @"active column";
        if (exchanging) {
            if (step.sourceColumn < 0 || step.sourceColumn > 2 || step.destinationColumn < 0 || step.destinationColumn > 2
                || labs(step.sourceColumn - step.destinationColumn) != 1) return @"exchange adjacency";
        } else if (step.sourceColumn != NSNotFound || step.destinationColumn != NSNotFound) return @"nonexchange indices";
        if (predicting) {
            if (!step.prompt.length || !step.expectedAnswer || step.expectedAnswer.integerValue < 0 || step.expectedAnswer.integerValue > 89) return @"prediction";
        } else if (step.prompt.length || step.expectedAnswer) return @"prediction leakage";
        if (writing != (step.writtenDigit != nil) || (!writing && step.writeDisposition != MultiplicativeTeachingWriteDispositionNone)) return @"write metadata";
        if (step.visibleAnswerDigits.count != 3) return @"answer width";
        for (NSInteger column = 0; column < 3; column++) {
            id digit = step.visibleAnswerDigits[column];
            if (digit != [NSNull null] && (![digit isKindOfClass:NSNumber.class] || [digit integerValue] < 0 || [digit integerValue] > 9)) return @"answer digit";
            if (![previousVisible[column] isEqual:digit] && (!writing || column != step.activeColumn
                || previousVisible[column] != [NSNull null] || ![digit isEqual:step.writtenDigit])) return @"early/wrong digit reveal";
        }
        NSMutableIndexSet *expectedCompleted = [previousCompleted mutableCopy];
        if (writing) [expectedCompleted addIndex:step.activeColumn];
        if (![expectedCompleted isEqual:step.completedColumns]) return @"completed columns";
        if (writing) {
            if (step.activeColumn != nextWriteColumn || [previousCompleted containsIndex:step.activeColumn]
                || step.writtenDigit.integerValue < 0 || step.writtenDigit.integerValue > 9) return @"write order or duplicate";
            nextWriteColumn += multiplication ? -1 : 1;
            if (step.writeDisposition == MultiplicativeTeachingWriteDispositionWritten
                && ![step.visibleAnswerDigits[step.activeColumn] isEqual:step.writtenDigit]) return @"written zero omitted";
        }
        if (step.kind == MultiplicativeTeachingStepKindInspectRemainder) {
            if (multiplication || previous.kind != MultiplicativeTeachingStepKindWriteDigit || previous.activeColumn != 2
                || MTTestWeighted(step.division.after.unprocessedInputCounts) != 0
                || step.division.after.poolCounts[0].integerValue != 0 || step.division.after.poolCounts[1].integerValue != 0
                || ![step.visibleRemainder isEqual:step.division.after.poolCounts[2]]) return @"early remainder inspection";
            inspectedRemainder = YES;
            inspectCount++;
        }
        if (step.kind == MultiplicativeTeachingStepKindVerify) verifyCount++;
        if (multiplication ? step.visibleRemainder != nil : (inspectedRemainder != (step.visibleRemainder != nil))) return @"remainder reveal";
        if (step.visibleRemainder && step.visibleRemainder.integerValue != problem.number1 % problem.number2) return @"wrong remainder";
        NSUInteger expectedRows = previousRowCount + (!multiplication && writing ? 1 : 0);
        if (step.visibleDivisionRows.count != expectedRows) return @"future/missing division row";
        for (NSUInteger index = 0; index < previousRowCount; index++) {
            MultiplicativeDivisionWorkRow *old = previous.visibleDivisionRows[index];
            MultiplicativeDivisionWorkRow *current = step.visibleDivisionRows[index];
            if (old.column != current.column || old.partialCount != current.partialCount
                || old.distributedCount != current.distributedCount || old.remainderCount != current.remainderCount) return @"rewritten earlier division row";
        }

        if (multiplication) {
            if (!step.multiplication || step.division) return @"multiply payload";
            MultiplicativeMultiplicationPayload *payload = step.multiplication;
            MultiplicativeMultiplicationState *before = payload.before, *after = payload.after;
            if (!MTTestCounts(before.accumulatorCounts, 89) || !MTTestCounts(after.accumulatorCounts, 89)
                || !MTTestCounts(before.carryCounts, 8) || !MTTestCounts(after.carryCounts, 8)) return @"multiply count bounds";
            if (previous && !MTTestMultiplyStatesEqual(previous.multiplication.after, before)) return @"multiply before discontinuity";
            NSInteger generatedValue = 0;
            for (NSInteger column = 0; column < 3; column++) {
                if ([after.processedInputColumns containsIndex:column]) generatedValue += sequence.operandDigits[column].integerValue * (column == 0 ? 100 : column == 1 ? 10 : 1);
                if (after.carryCounts[column].integerValue > after.accumulatorCounts[column].integerValue) return @"carry ownership";
            }
            if (MTTestWeighted(after.accumulatorCounts) != generatedValue * problem.number2) return @"multiply weighted invariant";
            BOOL calculate = step.kind == MultiplicativeTeachingStepKindMultiplyPlace;
            BOOL regroup = step.kind == MultiplicativeTeachingStepKindRegroupUp;
            NSMutableIndexSet *expectedProcessed = [before.processedInputColumns mutableCopy];
            if (calculate) [expectedProcessed addIndex:step.activeColumn];
            if (![expectedProcessed isEqual:after.processedInputColumns]) return @"input processed twice or out of order";
            if (calculate) {
                NSInteger column = step.activeColumn;
                if (payload.generatedUnitCount != sequence.operandDigits[column].integerValue * problem.number2
                    || payload.incomingCarryUnitCount != before.accumulatorCounts[column].integerValue
                    || payload.incomingCarryUnitCount != before.carryCounts[column].integerValue
                    || after.carryCounts[column].integerValue != 0) return @"carry multiplied or counted twice";
                if (previous.kind != MultiplicativeTeachingStepKindPredict
                    || previous.expectedAnswer.integerValue != after.accumulatorCounts[column].integerValue) return @"multiply prediction relation";
            } else if (payload.generatedUnitCount || payload.incomingCarryUnitCount) return @"multiply action metadata";
            if (regroup) {
                if (step.destinationColumn != step.sourceColumn - 1 || payload.exchangeBundleCount < 1 || payload.exchangeBundleCount > 8
                    || payload.exchangeBundleCount != before.accumulatorCounts[step.sourceColumn].integerValue / 10
                    || after.carryCounts[step.destinationColumn].integerValue != payload.exchangeBundleCount) return @"upward bundle contract";
            } else if (payload.exchangeBundleCount) return @"spurious upward exchange";
            for (NSInteger column = 0; column < 3; column++) {
                NSInteger delta = after.accumulatorCounts[column].integerValue - before.accumulatorCounts[column].integerValue;
                NSInteger expected = calculate && column == step.activeColumn ? payload.generatedUnitCount
                    : regroup && column == step.sourceColumn ? -10 * payload.exchangeBundleCount
                    : regroup && column == step.destinationColumn ? payload.exchangeBundleCount : 0;
                if (delta != expected) return @"multiply count delta";
                NSInteger expectedCarry = before.carryCounts[column].integerValue;
                if ((calculate || payload.writesFinalCarry) && column == step.activeColumn) expectedCarry = 0;
                if (regroup && column == step.destinationColumn) expectedCarry = payload.exchangeBundleCount;
                if (after.carryCounts[column].integerValue != expectedCarry) return @"carry annotation delta";
            }
            if (payload.writesFinalCarry && (!writing || step.activeColumn != sequence.operandStartColumn - 1
                || [after.processedInputColumns containsIndex:step.activeColumn])) return @"final carry multiplied";
            if (writing && (step.writeDisposition != MultiplicativeTeachingWriteDispositionWritten
                || step.writtenDigit.integerValue != after.accumulatorCounts[step.activeColumn].integerValue)) return @"multiply written value";
        } else {
            if (!step.division || step.multiplication) return @"divide payload";
            MultiplicativeDivisionPayload *payload = step.division;
            MultiplicativeDivisionState *before = payload.before, *after = payload.after;
            if (previous && !MTTestDivideStatesEqual(previous.division.after, before)) return @"division before discontinuity";
            for (MultiplicativeDivisionState *state in @[before, after]) {
                if (!MTTestCounts(state.unprocessedInputCounts, 9) || !MTTestCounts(state.poolCounts, 89)
                    || state.recipientCounts.count != (NSUInteger)problem.number2) return @"division state bounds";
                NSInteger value = MTTestWeighted(state.unprocessedInputCounts) + MTTestWeighted(state.poolCounts);
                for (NSArray<NSNumber *> *recipient in state.recipientCounts) {
                    if (!MTTestCounts(recipient, 9) || ![recipient isEqual:state.recipientCounts.firstObject]) return @"unequal recipients";
                    value += MTTestWeighted(recipient);
                }
                if (value != problem.number1) return @"division conservation";
            }
            BOOL bring = step.kind == MultiplicativeTeachingStepKindBringDown;
            BOOL share = step.kind == MultiplicativeTeachingStepKindDistribute;
            BOOL regroup = step.kind == MultiplicativeTeachingStepKindRegroupDown;
            if (bring && payload.broughtDownUnitCount != before.unprocessedInputCounts[step.activeColumn].integerValue) return @"bring down original only";
            if (!bring && payload.broughtDownUnitCount) return @"spurious bring down";
            if (share) {
                if (payload.unitsPerRecipient != before.poolCounts[step.activeColumn].integerValue / problem.number2
                    || payload.totalTransferredUnitCount != payload.unitsPerRecipient * problem.number2
                    || after.poolCounts[step.activeColumn].integerValue >= problem.number2) return @"share amount/common remainder";
                if (previous.kind != MultiplicativeTeachingStepKindPredict || previous.expectedAnswer.integerValue != payload.unitsPerRecipient) return @"divide prediction relation";
            } else if (payload.unitsPerRecipient || payload.totalTransferredUnitCount) return @"spurious distribution";
            if (regroup) {
                if (step.destinationColumn != step.sourceColumn + 1 || payload.exchangeLargerUnitCount < 1
                    || payload.exchangeLargerUnitCount >= problem.number2
                    || payload.exchangeLargerUnitCount != before.poolCounts[step.sourceColumn].integerValue) return @"downward exchange";
            } else if (payload.exchangeLargerUnitCount) return @"spurious downward exchange";
            for (NSInteger column = 0; column < 3; column++) {
                NSInteger inputDelta = after.unprocessedInputCounts[column].integerValue - before.unprocessedInputCounts[column].integerValue;
                if (inputDelta != (bring && column == step.activeColumn ? -payload.broughtDownUnitCount : 0)) return @"input brought down twice";
                NSInteger poolDelta = after.poolCounts[column].integerValue - before.poolCounts[column].integerValue;
                NSInteger expectedPool = bring && column == step.activeColumn ? payload.broughtDownUnitCount
                    : share && column == step.activeColumn ? -payload.totalTransferredUnitCount
                    : regroup && column == step.sourceColumn ? -payload.exchangeLargerUnitCount
                    : regroup && column == step.destinationColumn ? 10 * payload.exchangeLargerUnitCount : 0;
                if (poolDelta != expectedPool) return @"pool transition";
                for (NSInteger recipient = 0; recipient < problem.number2; recipient++) {
                    NSInteger delta = after.recipientCounts[recipient][column].integerValue - before.recipientCounts[recipient][column].integerValue;
                    if (delta != (share && column == step.activeColumn ? payload.unitsPerRecipient : 0)) return @"recipient transition";
                }
            }
            if (writing) {
                NSInteger digit = step.writtenDigit.integerValue;
                BOOL suppress = digit == 0 && !quotientStarted && step.activeColumn < 2;
                if (digit != after.recipientCounts.firstObject[step.activeColumn].integerValue
                    || step.writeDisposition != (suppress ? MultiplicativeTeachingWriteDispositionSuppressedLeadingZero : MultiplicativeTeachingWriteDispositionWritten)) return @"quotient zero policy";
                if (suppress ? step.visibleAnswerDigits[step.activeColumn] != [NSNull null]
                             : ![step.visibleAnswerDigits[step.activeColumn] isEqual:step.writtenDigit]) return @"quotient visibility";
                if (!suppress) quotientStarted = YES;
                MultiplicativeDivisionWorkRow *row = step.visibleDivisionRows.lastObject;
                if (previous.kind != MultiplicativeTeachingStepKindDistribute || row.column != step.activeColumn
                    || row.partialCount != previous.division.before.poolCounts[row.column].integerValue
                    || row.distributedCount != previous.division.totalTransferredUnitCount
                    || row.remainderCount != after.poolCounts[row.column].integerValue
                    || row.partialCount != row.distributedCount + row.remainderCount) return @"long division work row";
            }
        }
        previousVisible = step.visibleAnswerDigits;
        previousCompleted = step.completedColumns;
        previousRowCount = step.visibleDivisionRows.count;
        previous = step;
    }
    if (inspectCount != (multiplication ? 0u : 1u) || verifyCount != 1
        || sequence.steps[sequence.steps.count - 2].kind != MultiplicativeTeachingStepKindVerify) return @"missing remainder inspection or verification";
    NSMutableIndexSet *allInputColumns = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(sequence.operandStartColumn, 3 - sequence.operandStartColumn)];
    if (multiplication) {
        if (![previous.multiplication.after.processedInputColumns isEqual:allInputColumns]) return @"input zero column skipped";
        NSInteger finalCarryColumn = sequence.operandStartColumn - 1;
        if (finalCarryColumn >= 0 && previous.multiplication.after.accumulatorCounts[finalCarryColumn].integerValue > 0) [allInputColumns addIndex:finalCarryColumn];
    }
    if (![previousCompleted isEqual:allInputColumns]) return @"unwritten zero or carry column";
    NSInteger writtenAnswer = 0;
    for (id digit in previousVisible) writtenAnswer = writtenAnswer * 10 + (digit == [NSNull null] ? 0 : [digit integerValue]);
    if (writtenAnswer != problem.answer || previousVisible.lastObject == [NSNull null]) return @"final answer";
    if (!multiplication && (MTTestWeighted(previous.division.after.unprocessedInputCounts) != 0
        || MTTestWeighted(previous.division.after.poolCounts) != problem.number1 % problem.number2
        || MTTestWeighted(previous.division.after.recipientCounts.firstObject) != problem.answer)) return @"final division inventory";
    return nil;
}

- (void)testBoundedRangeContractsCoverEveryGeneratedD3ProblemAndRemainders {
    for (NSInteger a = 0; a <= 999; a++) {
        for (NSInteger b = 1; b <= 9; b++) {
            @autoreleasepool {
                MultiplicativeTeachingSequence *division = [self sequence:a operation:@"÷" second:b answer:a / b];
                NSString *failure = [self contractFailure:division];
                XCTAssertNil(failure, @"%ld ÷ %ld: %@", (long)a, (long)b, failure);
                MultiplicativeTeachingSequence *multiplication = [self sequence:a operation:@"×" second:b answer:a * b];
                if (a * b <= 999) {
                    failure = [self contractFailure:multiplication];
                    XCTAssertNil(failure, @"%ld × %ld: %@", (long)a, (long)b, failure);
                } else {
                    XCTAssertEqual(multiplication.status, MultiplicativeTeachingStatusOutsideBounds);
                    XCTAssertEqual(multiplication.steps.count, 0u);
                }
            }
        }
    }
}

- (void)test126Times4CarriesTwoThenOneAndWritesInternalZero {
    MultiplicativeTeachingSequence *sequence = [self sequence:126 operation:@"×" second:4 answer:504];
    NSArray<MultiplicativeTeachingStep *> *calculations = [self steps:sequence kind:MultiplicativeTeachingStepKindMultiplyPlace];
    NSArray<MultiplicativeTeachingStep *> *exchanges = [self steps:sequence kind:MultiplicativeTeachingStepKindRegroupUp];
    NSArray<MultiplicativeTeachingStep *> *writes = [self steps:sequence kind:MultiplicativeTeachingStepKindWriteDigit];
    XCTAssertEqual(calculations.count, 3u);
    XCTAssertEqual(exchanges.count, 2u);
    XCTAssertEqualObjects(calculations[0].multiplication.after.accumulatorCounts, (@[@0, @0, @24]));
    XCTAssertEqual(exchanges[0].multiplication.exchangeBundleCount, 2);
    XCTAssertEqualObjects(exchanges[0].multiplication.after.accumulatorCounts, (@[@0, @2, @4]));
    XCTAssertEqualObjects(exchanges[0].visibleAnswerDigits, (@[[NSNull null], [NSNull null], [NSNull null]]));
    XCTAssertEqual(calculations[1].multiplication.generatedUnitCount, 8);
    XCTAssertEqual(calculations[1].multiplication.incomingCarryUnitCount, 2);
    XCTAssertEqualObjects(calculations[1].multiplication.after.accumulatorCounts, (@[@0, @10, @4]));
    XCTAssertEqualObjects(exchanges[1].multiplication.after.accumulatorCounts, (@[@1, @0, @4]));
    XCTAssertEqual(calculations[2].multiplication.generatedUnitCount, 4);
    XCTAssertEqual(calculations[2].multiplication.incomingCarryUnitCount, 1);
    XCTAssertEqualObjects(writes[0].visibleAnswerDigits, (@[[NSNull null], [NSNull null], @4]));
    XCTAssertEqualObjects(writes[1].visibleAnswerDigits, (@[[NSNull null], @0, @4]));
    XCTAssertEqualObjects(writes[2].visibleAnswerDigits, (@[@5, @0, @4]));
    NSArray<MultiplicativeTeachingStep *> *predictions = [self steps:sequence kind:MultiplicativeTeachingStepKindPredict];
    XCTAssertEqualObjects(predictions[1].prompt, @"2 個十乘以 4，再加上換來的 2 個十，一共有幾個十？");
    XCTAssertEqualObjects(predictions[1].explanation, @"可以先想想，也可以直接看示範；這裡不計分。");
    XCTAssertFalse([predictions[1].spokenExplanation containsString:@"一共有 10"]);
}

- (void)testZeroInputDigitConsumesCarryAndFinalCarryIsNotMultiplied {
    MultiplicativeTeachingSequence *zero = [self sequence:104 operation:@"×" second:3 answer:312];
    NSArray<MultiplicativeTeachingStep *> *calculations = [self steps:zero kind:MultiplicativeTeachingStepKindMultiplyPlace];
    XCTAssertEqual(calculations[1].multiplication.generatedUnitCount, 0);
    XCTAssertEqual(calculations[1].multiplication.incomingCarryUnitCount, 1);
    XCTAssertEqualObjects(calculations[1].multiplication.after.accumulatorCounts, (@[@0, @1, @2]));
    MultiplicativeTeachingSequence *carry = [self sequence:99 operation:@"×" second:9 answer:891];
    calculations = [self steps:carry kind:MultiplicativeTeachingStepKindMultiplyPlace];
    XCTAssertEqual(calculations.count, 2u);
    XCTAssertEqualObjects(calculations.lastObject.multiplication.after.accumulatorCounts, (@[@0, @89, @1]));
    NSArray<MultiplicativeTeachingStep *> *writes = [self steps:carry kind:MultiplicativeTeachingStepKindWriteDigit];
    XCTAssertEqual(writes.count, 3u);
    XCTAssertTrue(writes.lastObject.multiplication.writesFinalCarry);
    XCTAssertEqualObjects(writes.lastObject.writtenDigit, @8);
    XCTAssertFalse([writes.lastObject.multiplication.after.processedInputColumns containsIndex:0]);
    XCTAssertEqualObjects(writes.lastObject.multiplication.after.carryCounts, (@[@0, @0, @0]));
    XCTAssertEqualObjects(writes.lastObject.visibleAnswerDigits, (@[@8, @9, @1]));
}

- (void)test108DividedBy4SeparatesRegroupingFromBringingDown {
    MultiplicativeTeachingSequence *sequence = [self sequence:108 operation:@"÷" second:4 answer:27];
    NSArray<MultiplicativeTeachingStep *> *writes = [self steps:sequence kind:MultiplicativeTeachingStepKindWriteDigit];
    NSArray<MultiplicativeTeachingStep *> *exchanges = [self steps:sequence kind:MultiplicativeTeachingStepKindRegroupDown];
    NSArray<MultiplicativeTeachingStep *> *brings = [self steps:sequence kind:MultiplicativeTeachingStepKindBringDown];
    XCTAssertEqual(writes[0].writeDisposition, MultiplicativeTeachingWriteDispositionSuppressedLeadingZero);
    XCTAssertTrue([writes[0].completedColumns containsIndex:0]);
    XCTAssertEqualObjects(writes[0].visibleAnswerDigits, (@[[NSNull null], [NSNull null], [NSNull null]]));
    XCTAssertEqual(exchanges.count, 2u);
    XCTAssertEqualObjects(exchanges[0].division.before.poolCounts, (@[@1, @0, @0]));
    XCTAssertEqualObjects(exchanges[0].division.after.poolCounts, (@[@0, @10, @0]));
    XCTAssertEqualObjects(exchanges[0].division.after.unprocessedInputCounts, (@[@0, @0, @8]));
    XCTAssertEqual(brings[1].division.broughtDownUnitCount, 0);
    XCTAssertEqualObjects(exchanges[1].division.after.poolCounts, (@[@0, @0, @20]));
    XCTAssertEqualObjects(exchanges[1].division.after.unprocessedInputCounts, (@[@0, @0, @8]));
    XCTAssertEqual(brings[2].division.broughtDownUnitCount, 8);
    XCTAssertEqualObjects(brings[2].division.after.poolCounts, (@[@0, @0, @28]));
    XCTAssertEqualObjects(brings[2].division.after.unprocessedInputCounts, (@[@0, @0, @0]));
    XCTAssertEqualObjects(writes.lastObject.visibleAnswerDigits, (@[[NSNull null], @2, @7]));
    XCTAssertNil(writes.lastObject.visibleRemainder);
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleRemainder, @0);
    XCTAssertEqual(sequence.steps.lastObject.division.after.recipientCounts.count, 4u);
    for (NSArray *recipient in sequence.steps.lastObject.division.after.recipientCounts) XCTAssertEqualObjects(recipient, (@[@0, @2, @7]));
}

- (void)test408DividedBy4WritesInternalZeroWithoutMovingPhantomUnits {
    MultiplicativeTeachingSequence *sequence = [self sequence:408 operation:@"÷" second:4 answer:102];
    NSArray<MultiplicativeTeachingStep *> *writes = [self steps:sequence kind:MultiplicativeTeachingStepKindWriteDigit];
    NSArray<MultiplicativeTeachingStep *> *shares = [self steps:sequence kind:MultiplicativeTeachingStepKindDistribute];
    XCTAssertEqualObjects(writes[0].visibleAnswerDigits, (@[@1, [NSNull null], [NSNull null]]));
    XCTAssertEqual(writes[1].writeDisposition, MultiplicativeTeachingWriteDispositionWritten);
    XCTAssertEqualObjects(writes[1].visibleAnswerDigits, (@[@1, @0, [NSNull null]]));
    XCTAssertEqual(shares[1].division.unitsPerRecipient, 0);
    XCTAssertEqual(shares[1].division.totalTransferredUnitCount, 0);
    XCTAssertTrue(MTTestDivideStatesEqual(shares[1].division.before, shares[1].division.after));
    XCTAssertEqualObjects(writes.lastObject.visibleAnswerDigits, (@[@1, @0, @2]));
    XCTAssertEqual([self steps:sequence kind:MultiplicativeTeachingStepKindRegroupDown].count, 0u);
}

- (void)testOneCommonRemainderAndMaximumPartialQuantity {
    MultiplicativeTeachingSequence *sequence = [self sequence:109 operation:@"÷" second:4 answer:27];
    MultiplicativeTeachingStep *lastShare = [self steps:sequence kind:MultiplicativeTeachingStepKindDistribute].lastObject;
    XCTAssertEqualObjects(lastShare.division.before.poolCounts, (@[@0, @0, @29]));
    XCTAssertEqual(lastShare.division.unitsPerRecipient, 7);
    XCTAssertEqual(lastShare.division.totalTransferredUnitCount, 28);
    XCTAssertEqualObjects(lastShare.division.after.poolCounts, (@[@0, @0, @1]));
    XCTAssertNil(lastShare.visibleRemainder);
    MultiplicativeTeachingStep *inspect = [self steps:sequence kind:MultiplicativeTeachingStepKindInspectRemainder].firstObject;
    XCTAssertEqualObjects(inspect.visibleRemainder, @1);
    XCTAssertTrue([inspect.explanation containsString:@"不是每份各剩 1"]);
    for (NSArray *recipient in inspect.division.after.recipientCounts) XCTAssertEqualObjects(recipient, (@[@0, @2, @7]));
    MultiplicativeTeachingStep *verify = [self steps:sequence kind:MultiplicativeTeachingStepKindVerify].firstObject;
    XCTAssertTrue([verify.explanation containsString:@"27 × 4 + 1 = 109"]);
    sequence = [self sequence:899 operation:@"÷" second:9 answer:99];
    NSArray<MultiplicativeTeachingStep *> *brings = [self steps:sequence kind:MultiplicativeTeachingStepKindBringDown];
    XCTAssertEqualObjects(brings[1].division.after.poolCounts, (@[@0, @89, @0]));
    XCTAssertEqualObjects(brings[2].division.after.poolCounts, (@[@0, @0, @89]));
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleRemainder, @8);
}

- (void)testZeroIdentityAliasesAndFixedThreePlaces {
    for (NSString *operation in @[@"×", @"÷"]) {
        MultiplicativeTeachingSequence *zero = [self sequence:0 operation:operation second:9 answer:0];
        XCTAssertEqual(zero.columnCount, 3);
        XCTAssertEqual(zero.operandStartColumn, 2);
        XCTAssertEqualObjects(zero.steps.lastObject.visibleAnswerDigits, (@[[NSNull null], [NSNull null], @0]));
        XCTAssertEqual([self steps:zero kind:MultiplicativeTeachingStepKindWriteDigit].count, 1u);
        MultiplicativeTeachingSequence *identity = [self sequence:999 operation:operation second:1 answer:999];
        XCTAssertNil([self contractFailure:identity]);
        XCTAssertEqualObjects(identity.steps.lastObject.visibleAnswerDigits, (@[@9, @9, @9]));
    }
    XCTAssertEqualObjects([self sequence:126 operation:@"*" second:4 answer:504].problem.operatorSymbol, @"×");
    XCTAssertEqualObjects([self sequence:109 operation:@"/" second:4 answer:27].problem.operatorSymbol, @"÷");
}

- (void)testUnsupportedInputFailsBeforeAllocationOrArithmetic {
    NSArray<MultiplicativeTeachingSequence *> *invalid = @[
        [MultiplicativeTeachingSequence sequenceForArithmeticProblem:nil],
        [self sequence:10 operation:@"÷" second:0 answer:0],
        [self sequence:-1 operation:@"×" second:2 answer:0],
        [self sequence:1 operation:@"÷" second:-1 answer:0],
        [self sequence:126 operation:@"×" second:4 answer:500],
        [self sequence:109 operation:@"÷" second:4 answer:28],
        [self sequence:1 operation:@"×" second:1 answer:-1],
        [self sequence:126 operation:@"×" second:0 answer:1]
    ];
    for (MultiplicativeTeachingSequence *sequence in invalid) {
        XCTAssertEqual(sequence.status, MultiplicativeTeachingStatusInvalidProblem);
        XCTAssertEqual(sequence.columnCount, 0);
        XCTAssertEqual(sequence.operandStartColumn, NSNotFound);
        XCTAssertEqual(sequence.steps.count, 0u);
        XCTAssertNotNil(sequence.problem);
    }
    NSArray<MultiplicativeTeachingSequence *> *bounds = @[
        [self sequence:NSIntegerMax operation:@"×" second:NSIntegerMax answer:NSIntegerMax],
        [self sequence:1000 operation:@"÷" second:2 answer:500],
        [self sequence:100 operation:@"×" second:10 answer:1000],
        [self sequence:999 operation:@"×" second:9 answer:999],
        [self sequence:1 operation:@"×" second:1 answer:NSIntegerMax]
    ];
    for (MultiplicativeTeachingSequence *sequence in bounds) {
        XCTAssertEqual(sequence.status, MultiplicativeTeachingStatusOutsideBounds);
        XCTAssertEqual(sequence.steps.count, 0u);
        XCTAssertEqual(sequence.operandDigits.count, 0u);
    }
    XCTAssertEqual([self sequence:126 operation:@"×" second:0 answer:0].status, MultiplicativeTeachingStatusUnsupportedZeroMultiplier);
    XCTAssertEqual([self sequence:12 operation:@"+" second:4 answer:16].status, MultiplicativeTeachingStatusUnsupportedOperation);
    ArithmeticProblem *multi = [[ArithmeticProblem alloc] initWithNumber1:126 number2:4 operator:@"×" answer:504];
    multi.isMultiStep = YES;
    XCTAssertEqual([MultiplicativeTeachingSequence sequenceForArithmeticProblem:multi].status, MultiplicativeTeachingStatusInvalidProblem);
}

- (void)testInputAndNestedSnapshotsCannotMutateAnExistingLesson {
    NSMutableString *operator = [@"/" mutableCopy];
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:109 number2:4 operator:operator answer:27];
    problem.auxiliaryDistractor = 8; // Not a remainder. Numeric division derives 1.
    MultiplicativeTeachingSequence *sequence = [MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem];
    [operator setString:@"+"];
    problem.number1 = 999;
    problem.number2 = 9;
    problem.answer = 111;
    ArithmeticProblem *exposed = sequence.problem;
    exposed.number1 = 0;
    exposed.operatorSymbol = @"-";
    XCTAssertEqual(sequence.problem.number1, 109);
    XCTAssertEqual(sequence.problem.number2, 4);
    XCTAssertEqualObjects(sequence.problem.operatorSymbol, @"÷");
    XCTAssertEqualObjects(sequence.steps.lastObject.visibleRemainder, @1);
    XCTAssertNotEqual(sequence.problem, sequence.problem);
    MultiplicativeTeachingStep *initial = sequence.steps.firstObject;
    XCTAssertEqualObjects(initial.division.after.unprocessedInputCounts, (@[@1, @0, @9]));
    for (NSArray *row in initial.division.after.recipientCounts) {
        XCTAssertFalse([row isKindOfClass:NSMutableArray.class]);
        XCTAssertEqualObjects(row, (@[@0, @0, @0]));
    }
    XCTAssertFalse([initial.division.after.recipientCounts isKindOfClass:NSMutableArray.class]);
    XCTAssertFalse([initial.completedColumns isKindOfClass:NSMutableIndexSet.class]);
    XCTAssertEqual(initial.visibleDivisionRows.count, 0u);
    XCTAssertNil(initial.visibleRemainder);
    XCTAssertEqualObjects(initial.visibleAnswerDigits, (@[[NSNull null], [NSNull null], [NSNull null]]));
    NSMutableArray *copy = [sequence.steps.lastObject.division.after.recipientCounts.firstObject mutableCopy];
    copy[0] = @9;
    XCTAssertEqualObjects(sequence.steps.lastObject.division.after.recipientCounts.firstObject, (@[@0, @2, @7]));
    XCTAssertNil([self contractFailure:sequence]);
}
@end
