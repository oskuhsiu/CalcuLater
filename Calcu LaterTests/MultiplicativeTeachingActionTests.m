#import <XCTest/XCTest.h>
#import "MultiplicativeTeachingAction.h"

static NSArray<NSNumber *> *MTAIdentifiers(NSArray<MultiplicativeTeachingUnit *> *units) {
    NSMutableArray<NSNumber *> *identifiers = [NSMutableArray arrayWithCapacity:units.count];
    for (MultiplicativeTeachingUnit *unit in units) [identifiers addObject:@(unit.identifier)];
    return [identifiers copy];
}
static NSArray<MultiplicativeTeachingUnit *> *MTAOwnedUnits(MultiplicativeTeachingActionSnapshot *snapshot) {
    NSMutableArray<MultiplicativeTeachingQuantity *> *quantities = [NSMutableArray array];
    if (snapshot.accumulator) [quantities addObject:snapshot.accumulator];
    if (snapshot.unprocessedInput) [quantities addObject:snapshot.unprocessedInput];
    if (snapshot.pool) [quantities addObject:snapshot.pool];
    [quantities addObjectsFromArray:snapshot.recipients];
    NSMutableArray<MultiplicativeTeachingUnit *> *units = [NSMutableArray array];
    for (MultiplicativeTeachingQuantity *quantity in quantities)
        for (NSArray<MultiplicativeTeachingUnit *> *column in quantity.columns) [units addObjectsFromArray:column];
    return [units copy];
}
static NSInteger MTAValue(NSArray<MultiplicativeTeachingUnit *> *units) {
    NSInteger result = 0;
    for (MultiplicativeTeachingUnit *unit in units) result += unit.value;
    return result;
}
static NSArray<NSNumber *> *MTACarryCounts(MultiplicativeTeachingActionSnapshot *snapshot) {
    return @[@(snapshot.carryUnits[0].count), @(snapshot.carryUnits[1].count), @(snapshot.carryUnits[2].count)];
}
static BOOL MTAMatchesMultiply(MultiplicativeTeachingActionSnapshot *snapshot, MultiplicativeMultiplicationState *source) {
    return snapshot.accumulator && !snapshot.unprocessedInput && !snapshot.pool && snapshot.recipients.count == 0
        && [snapshot.accumulator.counts isEqual:source.accumulatorCounts]
        && [MTACarryCounts(snapshot) isEqual:source.carryCounts]
        && [snapshot.processedInputColumns isEqual:source.processedInputColumns];
}
static BOOL MTAMatchesDivide(MultiplicativeTeachingActionSnapshot *snapshot, MultiplicativeDivisionState *source) {
    if (snapshot.accumulator || !snapshot.unprocessedInput || !snapshot.pool
        || ![snapshot.unprocessedInput.counts isEqual:source.unprocessedInputCounts]
        || ![snapshot.pool.counts isEqual:source.poolCounts] || snapshot.recipients.count != source.recipientCounts.count) return NO;
    for (NSUInteger index = 0; index < snapshot.recipients.count; index++)
        if (![snapshot.recipients[index].counts isEqual:source.recipientCounts[index]]) return NO;
    return YES;
}

@interface MultiplicativeTeachingActionTests : XCTestCase
@end

@implementation MultiplicativeTeachingActionTests
- (MultiplicativeTeachingActionPlan *)plan:(NSInteger)a operation:(NSString *)operation second:(NSInteger)b {
    NSInteger answer = [operation isEqualToString:@"÷"] ? a / b : a * b;
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation answer:answer];
    return [MultiplicativeTeachingActionPlan planForSequence:[MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem]];
}
- (NSArray<MultiplicativeTeachingAction *> *)actions:(MultiplicativeTeachingActionPlan *)plan
                                              kind:(MultiplicativeTeachingStepKind)kind column:(NSInteger)column {
    NSMutableArray<MultiplicativeTeachingAction *> *result = [NSMutableArray array];
    for (MultiplicativeTeachingAction *action in plan.actions)
        if (action.sourceStep.kind == kind && action.activeColumn == column) [result addObject:action];
    return [result copy];
}
- (NSString *)snapshotFailure:(MultiplicativeTeachingActionSnapshot *)snapshot {
    NSArray<MultiplicativeTeachingUnit *> *units = MTAOwnedUnits(snapshot);
    NSArray<NSNumber *> *identifiers = MTAIdentifiers(units);
    if ([NSSet setWithArray:identifiers].count != identifiers.count) return @"one identity is owned twice";
    for (MultiplicativeTeachingUnit *unit in units) {
        if (unit.column < 0 || unit.column > 2 || unit.value != (unit.column == 0 ? 100 : (unit.column == 1 ? 10 : 1))) return @"unit place/value";
    }
    for (NSInteger column = 0; column < 3; column++) {
        for (MultiplicativeTeachingUnit *unit in snapshot.carryUnits[column])
            if (unit.column != column || ![snapshot.accumulator.columns[column] containsObject:unit]) return @"carry not an annotation subset";
    }
    if (snapshot.visibleAnswerDigits.count != 3 || snapshot.carryUnits.count != 3 || snapshot.spokenDescription.length == 0) return @"snapshot shape/text";
    return nil;
}

/// One useful diagnostic per bounded input, instead of hundreds of thousands of
/// XCTest assertions. The portable harness exercises the SAME C kernel; this
/// sweep is specifically the native Foundation mapping/reveal boundary.
- (NSString *)contractFailure:(MultiplicativeTeachingActionPlan *)plan {
    if (!plan.isSupported || plan.actions.count == 0 || plan.actions.count > 48) return @"support/action bound";
    MultiplicativeTeachingSequence *sequence = plan.sourceSequence;
    BOOL multiply = sequence.operation == MultiplicativeTeachingOperationMultiplication;
    MultiplicativeTeachingActionSnapshot *previous = plan.initialSnapshot;
    for (NSUInteger sourceIndex = 0; sourceIndex < sequence.steps.count; sourceIndex++) {
        MultiplicativeTeachingStep *source = sequence.steps[sourceIndex];
        NSArray<MultiplicativeTeachingAction *> *actions = [plan actionsForSourceStepAtIndex:(NSInteger)sourceIndex];
        if (!actions.count || actions.count > 9) return @"source action count";
        if ([plan beforeSnapshotForSourceStepAtIndex:(NSInteger)sourceIndex] != actions.firstObject.before
            || [plan resultSnapshotForSourceStepAtIndex:(NSInteger)sourceIndex] != actions.lastObject.after) return @"inspection endpoint alias";
        if (multiply ? !MTAMatchesMultiply(actions.firstObject.before, source.multiplication.before)
                     : !MTAMatchesDivide(actions.firstObject.before, source.division.before)) return @"original before endpoint";
        if (multiply ? !MTAMatchesMultiply(actions.lastObject.after, source.multiplication.after)
                     : !MTAMatchesDivide(actions.lastObject.after, source.division.after)) return @"original after endpoint";
        for (NSUInteger index = 0; index < actions.count; index++) {
            MultiplicativeTeachingAction *action = actions[index];
            if (action.sourceStep != source || action.sourceStepIndex != (NSInteger)sourceIndex
                || action.indexWithinStep != (NSInteger)index || action.countWithinStep != (NSInteger)actions.count
                || action.isSourceStepComplete != (index == actions.count - 1)) return @"source/action mapping";
            if (action.before != previous) return @"adjacent immutable snapshot continuity";
            NSString *failure = [self snapshotFailure:action.after];
            if (failure) return failure;
            if (action.title.length == 0 || action.instruction.length == 0 || action.resultExplanation.length == 0
                || action.spokenBefore.length == 0 || action.spokenAfter.length == 0) return @"missing current-action language";
            NSInteger beforeValue = MTAValue(MTAOwnedUnits(action.before));
            NSInteger afterValue = MTAValue(MTAOwnedUnits(action.after));
            NSInteger generatedValue = action.kind == MultiplicativeTeachingActionKindGenerateGroup ? MTAValue(action.outputUnits) : 0;
            if (afterValue != beforeValue + generatedValue) return @"generation/conservation boundary";
            if (!multiply && beforeValue != sequence.problem.number1) return @"division lost original value";
            BOOL writes = source.kind == MultiplicativeTeachingStepKindWriteDigit;
            if (writes) {
                if (actions.count != 1 || ![action.writtenDigit isEqual:source.writtenDigit]
                    || action.writeDisposition != source.writeDisposition) return @"write disposition mapping";
            } else if (action.writtenDigit || action.writeDisposition != MultiplicativeTeachingWriteDispositionNone
                       || ![action.after.visibleAnswerDigits isEqual:action.before.visibleAnswerDigits]
                       || ![action.after.completedColumns isEqual:action.before.completedColumns]
                       || ![action.after.visibleDivisionRows isEqual:action.before.visibleDivisionRows]) return @"premature written work";
            if (source.kind != MultiplicativeTeachingStepKindInspectRemainder
                && action.after.visibleRemainder != action.before.visibleRemainder
                && ![action.after.visibleRemainder isEqual:action.before.visibleRemainder]) return @"premature remainder label";
            if (action.isSourceStepComplete && (![action.after.visibleAnswerDigits isEqual:source.visibleAnswerDigits]
                || ![action.after.completedColumns isEqual:source.completedColumns]
                || ![action.after.visibleDivisionRows isEqual:source.visibleDivisionRows]
                || (action.after.visibleRemainder != source.visibleRemainder && ![action.after.visibleRemainder isEqual:source.visibleRemainder]))) return @"source reveal endpoint";
            switch (action.kind) {
                case MultiplicativeTeachingActionKindGenerateGroup:
                    if (action.inputUnits.count || action.outputUnits.count < 1 || action.outputUnits.count > 9
                        || actions.count != (NSUInteger)sequence.problem.number2 || action.groupIndex != (NSInteger)index) return @"generated group shape";
                    for (MultiplicativeTeachingUnit *unit in action.ownedIncomingCarryUnits)
                        if (![MTAOwnedUnits(action.before) containsObject:unit] || ![MTAOwnedUnits(action.after) containsObject:unit]
                            || [action.outputUnits containsObject:unit]) return @"incoming carry generated or lost";
                    break;
                case MultiplicativeTeachingActionKindExchangeUp:
                    if (action.inputUnits.count != 10 || action.outputUnits.count != 1 || MTAValue(action.inputUnits) != MTAValue(action.outputUnits)) return @"ten-to-one exchange";
                    break;
                case MultiplicativeTeachingActionKindExchangeDown:
                    if (action.inputUnits.count != 1 || action.outputUnits.count != 10 || MTAValue(action.inputUnits) != MTAValue(action.outputUnits)) return @"one-to-ten exchange";
                    break;
                case MultiplicativeTeachingActionKindBringDown:
                case MultiplicativeTeachingActionKindDistributeRecipient:
                    if (![MTAIdentifiers(action.inputUnits) isEqual:MTAIdentifiers(action.outputUnits)]) return @"transfer identity mismatch";
                    for (MultiplicativeTeachingUnit *unit in action.inputUnits) if (unit.column != action.activeColumn) return @"transfer changed place";
                    break;
                case MultiplicativeTeachingActionKindZeroGroups:
                case MultiplicativeTeachingActionKindZeroDistribution:
                    if (actions.count != 1) return @"zero busywork";
                    /* fall through */
                case MultiplicativeTeachingActionKindInspect:
                    if (action.inputUnits.count || action.outputUnits.count) return @"fake stationary units";
                    break;
            }
            previous = action.after;
        }
    }
    return nil;
}

- (void)testEveryBoundedProblemMapsCanonicalSourceEndpoints {
    NSInteger productCases = 0, divisionCases = 0;
    for (NSInteger operation = 0; operation < 2; operation++) {
        for (NSInteger a = 0; a <= 999; a++) {
            for (NSInteger b = 1; b <= 9; b++) {
                if (operation == 0 && a * b > 999) continue;
                @autoreleasepool {
                    MultiplicativeTeachingActionPlan *plan = [self plan:a operation:operation == 0 ? @"×" : @"÷" second:b];
                    NSString *failure = [self contractFailure:plan];
                    if (failure) { XCTFail(@"%ld %@ %ld: %@", (long)a, operation == 0 ? @"×" : @"÷", (long)b, failure); return; }
                }
                if (operation == 0) productCases++; else divisionCases++;
            }
        }
    }
    XCTAssertEqual(productCases, 2831);
    XCTAssertEqual(divisionCases, 9000);
}

- (void)testNinetyNineTimesNineBuildsNineCountableGroupsBeforeEightSingleExchanges {
    MultiplicativeTeachingActionPlan *plan = [self plan:99 operation:@"×" second:9];
    NSArray *ones = [self actions:plan kind:MultiplicativeTeachingStepKindMultiplyPlace column:2];
    XCTAssertEqual(ones.count, 9u);
    for (MultiplicativeTeachingAction *action in ones) {
        XCTAssertEqual(action.outputUnits.count, 9u);
        XCTAssertEqual(action.inputUnits.count, 0u);
        XCTAssertEqual(action.after.accumulator.columns[2].count, (NSUInteger)(9 * (action.groupIndex + 1)));
        XCTAssertEqual(action.after.carryUnits[1].count, 0u);
        XCTAssertTrue([action.after.visibleAnswerDigits[2] isKindOfClass:NSNull.class]);
    }
    NSArray *exchange = [self actions:plan kind:MultiplicativeTeachingStepKindRegroupUp column:2];
    XCTAssertEqual(exchange.count, 8u);
    for (MultiplicativeTeachingAction *action in exchange) {
        XCTAssertEqual(action.inputUnits.count, 10u);
        XCTAssertEqual(action.outputUnits.count, 1u);
        XCTAssertEqual(action.after.carryUnits[1].count, (NSUInteger)(action.indexWithinStep + 1));
        XCTAssertEqual(action.before.accumulator.weightedValue, action.after.accumulator.weightedValue);
    }
}

- (void)testIncomingCarryIsOwnedOnceAndNeverIncludedInGeneratedGroups {
    MultiplicativeTeachingActionPlan *plan = [self plan:99 operation:@"×" second:9];
    NSArray<MultiplicativeTeachingAction *> *tens = [self actions:plan kind:MultiplicativeTeachingStepKindMultiplyPlace column:1];
    XCTAssertEqual(tens.count, 9u);
    NSArray *incoming = tens.firstObject.ownedIncomingCarryUnits;
    XCTAssertEqual(incoming.count, 8u);
    for (MultiplicativeTeachingAction *action in tens) {
        XCTAssertEqualObjects(action.ownedIncomingCarryUnits, incoming);
        XCTAssertEqual(action.outputUnits.count, 9u);
        XCTAssertEqual(action.after.accumulator.columns[1].count, (NSUInteger)(8 + 9 * (action.groupIndex + 1)));
        for (MultiplicativeTeachingUnit *unit in incoming) {
            XCTAssertTrue([action.before.accumulator.columns[1] containsObject:unit]);
            XCTAssertTrue([action.after.accumulator.columns[1] containsObject:unit]);
            XCTAssertFalse([action.outputUnits containsObject:unit]);
        }
        XCTAssertEqual(action.after.carryUnits[1].count, action.isSourceStepComplete ? 0u : 8u);
    }
}

- (void)testZeroDigitUsesOneStationaryActionAndKeepsIncomingCarry {
    MultiplicativeTeachingActionPlan *plan = [self plan:105 operation:@"×" second:9];
    NSArray<MultiplicativeTeachingAction *> *tens = [self actions:plan kind:MultiplicativeTeachingStepKindMultiplyPlace column:1];
    XCTAssertEqual(tens.count, 1u);
    MultiplicativeTeachingAction *zero = tens.firstObject;
    XCTAssertEqual(zero.kind, MultiplicativeTeachingActionKindZeroGroups);
    XCTAssertEqual(zero.outputUnits.count, 0u);
    XCTAssertEqual(zero.inputUnits.count, 0u);
    XCTAssertEqual(zero.ownedIncomingCarryUnits.count, 4u);
    XCTAssertEqualObjects(MTAIdentifiers(MTAOwnedUnits(zero.before)), MTAIdentifiers(MTAOwnedUnits(zero.after)));
    XCTAssertEqual(zero.after.accumulator.columns[1].count, 4u);
    XCTAssertEqual(zero.after.carryUnits[1].count, 0u);
}

- (void)testDivisionUsesOneCommonPoolAndOneRecipientPerAction {
    MultiplicativeTeachingActionPlan *plan = [self plan:89 operation:@"÷" second:9];
    NSArray<MultiplicativeTeachingAction *> *ones = [self actions:plan kind:MultiplicativeTeachingStepKindDistribute column:2];
    XCTAssertEqual(ones.count, 9u);
    for (MultiplicativeTeachingAction *action in ones) {
        XCTAssertEqual(action.inputUnits.count, 9u);
        XCTAssertEqual(action.recipientIndex, action.indexWithinStep);
        XCTAssertEqual(action.before.pool.columns[2].count, (NSUInteger)(89 - 9 * action.indexWithinStep));
        XCTAssertEqual(action.after.pool.columns[2].count, (NSUInteger)(89 - 9 * (action.indexWithinStep + 1)));
        for (NSInteger recipient = 0; recipient < 9; recipient++) {
            XCTAssertEqual(action.after.recipients[recipient].columns[2].count, recipient <= action.recipientIndex ? 9u : 0u);
        }
        XCTAssertNil(action.after.visibleRemainder);
        XCTAssertTrue([action.after.visibleAnswerDigits[2] isKindOfClass:NSNull.class]);
    }
    XCTAssertEqual(ones.lastObject.after.pool.weightedValue, 8);
}

- (void)testHundredSplitsOneAtATimeWithoutMovingOriginalTensEarly {
    MultiplicativeTeachingActionPlan *plan = [self plan:899 operation:@"÷" second:9];
    NSArray<MultiplicativeTeachingAction *> *splits = [self actions:plan kind:MultiplicativeTeachingStepKindRegroupDown column:0];
    XCTAssertEqual(splits.count, 8u);
    for (MultiplicativeTeachingAction *action in splits) {
        XCTAssertEqual(action.inputUnits.count, 1u);
        XCTAssertEqual(action.inputUnits.firstObject.value, 100);
        XCTAssertEqual(action.outputUnits.count, 10u);
        XCTAssertEqual(action.outputUnits.firstObject.value, 10);
        XCTAssertEqual(action.after.pool.columns[0].count, (NSUInteger)(7 - action.indexWithinStep));
        XCTAssertEqual(action.after.pool.columns[1].count, (NSUInteger)(10 * (action.indexWithinStep + 1)));
        XCTAssertEqual(action.after.unprocessedInput.columns[1].count, 9u);
        XCTAssertEqualObjects(action.before.unprocessedInput.columns[1], action.after.unprocessedInput.columns[1]);
    }
    MultiplicativeTeachingAction *bring = [self actions:plan kind:MultiplicativeTeachingStepKindBringDown column:1].firstObject;
    XCTAssertEqual(bring.inputUnits.count, 9u);
    XCTAssertEqualObjects(bring.inputUnits, bring.outputUnits);
    XCTAssertEqual(bring.before.pool.columns[1].count, 80u);
    XCTAssertEqual(bring.after.pool.columns[1].count, 89u);
}

- (void)testWriteDigitAndWorkRowsAreNotRevealedByResultInspection {
    MultiplicativeTeachingActionPlan *plan = [self plan:101 operation:@"÷" second:2];
    MultiplicativeTeachingAction *distribute = [self actions:plan kind:MultiplicativeTeachingStepKindDistribute column:1].lastObject;
    MultiplicativeTeachingActionSnapshot *inspected = [plan resultSnapshotForSourceStepAtIndex:distribute.sourceStepIndex];
    XCTAssertEqual(inspected, distribute.after);
    XCTAssertTrue([inspected.visibleAnswerDigits[1] isKindOfClass:NSNull.class]);
    XCTAssertEqual(inspected.visibleDivisionRows.count, 1u);
    MultiplicativeTeachingAction *write = [self actions:plan kind:MultiplicativeTeachingStepKindWriteDigit column:1].firstObject;
    XCTAssertEqualObjects(write.after.visibleAnswerDigits[1], @5);
    XCTAssertEqual(write.after.visibleDivisionRows.count, 2u);
    XCTAssertFalse([write.spokenBefore containsString:@"10 個十減 10 個十"]);
    XCTAssertTrue([write.spokenAfter containsString:@"10 個十減 10 個十，剩下 0 個十"]);
    XCTAssertEqual(inspected, write.before);
}

- (void)testLeadingZeroAndInteriorZeroHaveDifferentCompletedWriteStates {
    MultiplicativeTeachingActionPlan *leading = [self plan:101 operation:@"÷" second:2];
    MultiplicativeTeachingAction *hundreds = [self actions:leading kind:MultiplicativeTeachingStepKindWriteDigit column:0].firstObject;
    XCTAssertEqual(hundreds.writeDisposition, MultiplicativeTeachingWriteDispositionSuppressedLeadingZero);
    XCTAssertEqualObjects(hundreds.writtenDigit, @0);
    XCTAssertTrue([hundreds.after.visibleAnswerDigits[0] isKindOfClass:NSNull.class]);
    XCTAssertTrue([hundreds.after.completedColumns containsIndex:0]);
    XCTAssertTrue([hundreds.spokenAfter containsString:@"百位已看過，最前面的 0 不寫"]);
    MultiplicativeTeachingActionPlan *interior = [self plan:816 operation:@"÷" second:4];
    MultiplicativeTeachingAction *tens = [self actions:interior kind:MultiplicativeTeachingStepKindWriteDigit column:1].firstObject;
    XCTAssertEqual(tens.writeDisposition, MultiplicativeTeachingWriteDispositionWritten);
    XCTAssertEqualObjects(tens.after.visibleAnswerDigits[1], @0);
    XCTAssertTrue([tens.after.completedColumns containsIndex:1]);
    XCTAssertTrue([tens.spokenAfter containsString:@"答案的十位已寫 0"]);
}

- (void)testCommonRemainderIsRevealedOnlyByOriginalInspection {
    MultiplicativeTeachingActionPlan *plan = [self plan:17 operation:@"÷" second:5];
    BOOL inspected = NO;
    for (MultiplicativeTeachingAction *action in plan.actions) {
        if (action.sourceStep.kind == MultiplicativeTeachingStepKindInspectRemainder) {
            XCTAssertNil(action.before.visibleRemainder);
            inspected = YES;
        }
        if (inspected) XCTAssertEqualObjects(action.after.visibleRemainder, @2);
        else XCTAssertNil(action.after.visibleRemainder);
    }
    XCTAssertTrue(inspected);
    XCTAssertEqual(plan.actions.lastObject.after.pool.weightedValue, 2);
}

- (void)testZeroProblemsDoNotInventUnitsOrNineEmptyActions {
    for (NSString *operation in @[@"×", @"÷"]) {
        MultiplicativeTeachingActionPlan *plan = [self plan:0 operation:operation second:9];
        XCTAssertTrue(plan.isSupported);
        for (MultiplicativeTeachingAction *action in plan.actions) {
            XCTAssertEqual(MTAOwnedUnits(action.before).count, 0u);
            XCTAssertEqual(MTAOwnedUnits(action.after).count, 0u);
            XCTAssertEqual(action.inputUnits.count, 0u);
            XCTAssertEqual(action.outputUnits.count, 0u);
            XCTAssertEqual(action.countWithinStep, 1);
        }
        XCTAssertEqualObjects(plan.actions.lastObject.after.visibleAnswerDigits[2], @0);
    }
}

- (void)testInspectionReplayAndCallerMutationCannotChangeSettledSnapshots {
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:89 number2:9 operator:@"÷" answer:9];
    MultiplicativeTeachingSequence *sequence = [MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem];
    MultiplicativeTeachingActionPlan *plan = [MultiplicativeTeachingActionPlan planForSequence:sequence];
    MultiplicativeTeachingAction *selected = [self actions:plan kind:MultiplicativeTeachingStepKindDistribute column:2][4];
    NSArray *beforeIDs = MTAIdentifiers(MTAOwnedUnits(selected.before));
    NSArray *afterIDs = MTAIdentifiers(MTAOwnedUnits(selected.after));
    NSString *spoken = selected.spokenAfter;
    problem.number1 = 1;
    problem.number2 = 1;
    sequence.problem.answer = 999;
    NSMutableArray *copiedColumns = [selected.after.pool.columns mutableCopy];
    NSMutableArray *copiedUnits = [selected.after.pool.columns[2] mutableCopy];
    [copiedColumns removeAllObjects];
    [copiedUnits removeAllObjects];
    for (NSInteger index = (NSInteger)sequence.steps.count - 1; index >= 0; index--) {
        XCTAssertNotNil([plan beforeSnapshotForSourceStepAtIndex:index]);
        XCTAssertNotNil([plan resultSnapshotForSourceStepAtIndex:index]);
    }
    XCTAssertEqualObjects(MTAIdentifiers(MTAOwnedUnits(selected.before)), beforeIDs);
    XCTAssertEqualObjects(MTAIdentifiers(MTAOwnedUnits(selected.after)), afterIDs);
    XCTAssertEqualObjects(selected.spokenAfter, spoken);
    XCTAssertFalse([plan.actions isKindOfClass:NSMutableArray.class]);
    XCTAssertFalse([selected.after.pool.columns isKindOfClass:NSMutableArray.class]);
    XCTAssertFalse([selected.after.pool.columns[2] isKindOfClass:NSMutableArray.class]);
    XCTAssertFalse([[plan actionsForSourceStepAtIndex:selected.sourceStepIndex] isKindOfClass:NSMutableArray.class]);
    XCTAssertEqual(plan.sourceSequence.problem.number1, 89);
}

- (void)testUnsupportedSourcesAndInvalidIndicesReturnEmptyWithoutFallback {
    XCTAssertFalse([MultiplicativeTeachingActionPlan planForSequence:nil].isSupported);
    NSArray<ArithmeticProblem *> *problems = @[
        [[ArithmeticProblem alloc] initWithNumber1:9 number2:0 operator:@"×" answer:0],
        [[ArithmeticProblem alloc] initWithNumber1:9 number2:0 operator:@"÷" answer:0],
        [[ArithmeticProblem alloc] initWithNumber1:1000 number2:1 operator:@"×" answer:1000],
        [[ArithmeticProblem alloc] initWithNumber1:8 number2:3 operator:@"+" answer:11],
        [[ArithmeticProblem alloc] initWithNumber1:8 number2:3 operator:@"×" answer:25]
    ];
    for (ArithmeticProblem *problem in problems) {
        MultiplicativeTeachingActionPlan *plan = [MultiplicativeTeachingActionPlan planForSequence:[MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem]];
        XCTAssertFalse(plan.isSupported);
        XCTAssertEqual(plan.actions.count, 0u);
        XCTAssertNil(plan.initialSnapshot);
        XCTAssertNil([plan resultSnapshotForSourceStepAtIndex:0]);
    }
    MultiplicativeTeachingActionPlan *plan = [self plan:99 operation:@"×" second:9];
    XCTAssertEqual([plan actionsForSourceStepAtIndex:-1].count, 0u);
    XCTAssertEqual([plan actionsForSourceStepAtIndex:NSIntegerMax].count, 0u);
    XCTAssertNil([plan beforeSnapshotForSourceStepAtIndex:NSIntegerMax]);
    XCTAssertNil([plan resultSnapshotForSourceStepAtIndex:(NSInteger)plan.sourceSequence.steps.count]);
}
@end
