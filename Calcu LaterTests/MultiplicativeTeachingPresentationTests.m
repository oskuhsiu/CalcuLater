#import <XCTest/XCTest.h>
#import "MultiplicativeTeachingPresentation.h"

@interface MultiplicativeTeachingPresentationTests : XCTestCase
@end
@implementation MultiplicativeTeachingPresentationTests
- (MultiplicativeTeachingActionPlan *)plan:(NSInteger)a second:(NSInteger)b operation:(NSString *)operation {
    NSInteger answer = [operation isEqualToString:@"×"] ? a * b : a / b;
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation answer:answer];
    MultiplicativeTeachingActionPlan *plan = [MultiplicativeTeachingActionPlan planForSequence:
        [MultiplicativeTeachingSequence sequenceForArithmeticProblem:problem]];
    XCTAssertTrue(plan.supported);
    return plan;
}
- (void)testDivisionPreparationRetainsTheCompleteOriginalAnchorAndNoAction {
    MultiplicativeTeachingActionPlan *plan = [self plan:899 second:9 operation:@"÷"];
    MultiplicativeTeachingPresentation *p = [MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"division"
        predictSourceIndex:7 review:NO returnSelection:nil];
    XCTAssertNotNil(p); XCTAssertEqual(p.phase, MTPPresentationPhaseSourcePreparation);
    XCTAssertNil(p.action); XCTAssertEqual(p.actionIndex, (NSInteger)NSNotFound);
    XCTAssertEqual(p.snapshot, plan.actions[15].before);
    XCTAssertEqual(p.snapshot, plan.actions[14].after);
    XCTAssertNotEqual(p.snapshot, plan.actions[14].before);
    XCTAssertEqual(p.preparationKey.anchor, p.snapshot);
    XCTAssertEqualObjects(p.snapshot.pool.counts, (@[@0, @89, @0]));
    XCTAssertEqualObjects(p.snapshot.unprocessedInput.counts, (@[@0, @0, @9]));
    XCTAssertEqual(p.snapshot.recipients.count, 9u);
    for (MultiplicativeTeachingQuantity *recipient in p.snapshot.recipients) XCTAssertEqualObjects(recipient.counts, (@[@0, @0, @0]));
    XCTAssertEqualObjects(p.snapshot.visibleAnswerDigits, (@[NSNull.null, NSNull.null, NSNull.null]));
    XCTAssertEqualObjects(p.snapshot.completedColumns, [NSIndexSet indexSetWithIndex:0]);
    XCTAssertEqual(p.snapshot.visibleDivisionRows.count, 1u);
    XCTAssertEqual(p.snapshot.visibleDivisionRows.firstObject.column, 0);
    XCTAssertEqual(p.snapshot.visibleDivisionRows.firstObject.remainderCount, 8);
    XCTAssertNil(p.snapshot.visibleRemainder);
    XCTAssertEqualObjects(p.prompt, plan.sourceSequence.steps[7].prompt);
}
- (void)testMultiplicationPreparationPreservesCarryOwnershipAndWrittenOnesOnly {
    MultiplicativeTeachingActionPlan *plan = [self plan:99 second:9 operation:@"×"];
    MultiplicativeTeachingPresentation *p = [MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"multiply"
        predictSourceIndex:5 review:NO returnSelection:nil];
    XCTAssertEqual(p.snapshot, plan.actions[21].before);
    XCTAssertEqualObjects(p.snapshot.accumulator.counts, (@[@0, @8, @1]));
    XCTAssertEqualObjects(p.snapshot.visibleAnswerDigits, (@[NSNull.null, NSNull.null, @1]));
    XCTAssertEqualObjects(p.snapshot.completedColumns, [NSIndexSet indexSetWithIndex:2]);
    XCTAssertEqual(p.snapshot.carryUnits[1].count, 8u);
    for (NSUInteger i = 0; i < 8; i++) {
        XCTAssertEqual(p.snapshot.carryUnits[1][i].identifier, i + 82);
        XCTAssertTrue([p.snapshot.accumulator.columns[1] containsObject:p.snapshot.carryUnits[1][i]]);
    }
    XCTAssertEqual(p.snapshot.accumulator.columns[2].firstObject.identifier, 81u);
    XCTAssertNil(p.action); XCTAssertEqual(p.snapshot.visibleDivisionRows.count, 0u);
}
- (void)testOptionalProposalParsingAcceptsTheWholeRangeButNeverSuppliesADefault {
    for (NSString *text in @[@"", @" ", @"-1", @"1000", @"3.5", @"9x", @"１２"]) {
        NSString *message = nil;
        XCTAssertNil([MultiplicativeTeachingPresentation proposalFromText:text validationMessage:&message], @"%@", text);
        XCTAssertGreaterThan(message.length, 0u);
    }
    for (NSNumber *value in @[@0, @8, @10, @81, @89, @153, @999]) {
        NSString *message = @"old";
        XCTAssertEqualObjects([MultiplicativeTeachingPresentation proposalFromText:value.stringValue validationMessage:&message], value);
        XCTAssertNil(message);
    }
    XCTAssertEqualObjects([MultiplicativeTeachingPresentation proposalFromText:@" 0008 " validationMessage:nil], @8);
}
- (void)testDivisionWrongProposalsExplainHypothesesWithoutMutatingTheAnchor {
    MultiplicativeTeachingActionPlan *plan = [self plan:899 second:9 operation:@"÷"];
    MultiplicativeTeachingPresentation *p = [MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"d"
        predictSourceIndex:7 review:NO returnSelection:nil];
    MultiplicativeTeachingActionSnapshot *anchor = p.snapshot;
    NSString *tooLarge = [p feedbackForProposal:10 matchesExpected:NO givenNumber1:899 givenNumber2:9];
    XCTAssertTrue([tooLarge containsString:@"90 個十"]); XCTAssertTrue([tooLarge containsString:@"89 個十"]);
    XCTAssertTrue([tooLarge containsString:@"還沒有分出去"]);
    NSString *tooSmall = [p feedbackForProposal:8 matchesExpected:NO givenNumber1:899 givenNumber2:9];
    XCTAssertTrue([tooSmall containsString:@"72 個十"]); XCTAssertTrue([tooSmall containsString:@"17 個十"]);
    XCTAssertTrue([tooSmall containsString:@"各多拿 1 個"]); XCTAssertFalse([tooSmall containsString:@"餘數"]);
    for (NSNumber *value in @[@0, @8, @10, @999]) {
        XCTAssertGreaterThan([p feedbackForProposal:value.integerValue matchesExpected:NO givenNumber1:899 givenNumber2:9].length, 0u);
        XCTAssertEqual(p.snapshot, anchor);
        XCTAssertEqualObjects(p.snapshot.pool.counts, (@[@0, @89, @0]));
    }
    NSString *matching = [p feedbackForProposal:9 matchesExpected:YES givenNumber1:899 givenNumber2:9];
    XCTAssertFalse([matching containsString:@"餘數"]); XCTAssertFalse([matching containsString:@"8"]);
    XCTAssertEqual(p.snapshot, anchor);
}
- (void)testCarryMisconceptionsUseOnlyTheEightAlreadyOwnedTens {
    MultiplicativeTeachingActionPlan *plan = [self plan:99 second:9 operation:@"×"];
    MultiplicativeTeachingPresentation *p = [MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"m"
        predictSourceIndex:5 review:NO returnSelection:nil];
    NSString *omitted = [p feedbackForProposal:81 matchesExpected:NO givenNumber1:99 givenNumber2:9];
    XCTAssertTrue([omitted containsString:@"原來已有 8 個十"]);
    XCTAssertTrue([omitted containsString:@"沒有消失"]);
    NSString *multipliedAgain = [p feedbackForProposal:153 matchesExpected:NO givenNumber1:99 givenNumber2:9];
    XCTAssertTrue([multipliedAgain containsString:@"再乘了 9 次"]);
    XCTAssertTrue([multipliedAgain containsString:@"只在累積區一次"]);
    for (NSString *feedback in @[omitted, multipliedAgain,
        [p feedbackForProposal:89 matchesExpected:YES givenNumber1:99 givenNumber2:9]]) {
        XCTAssertFalse([feedback containsString:@"89"]); XCTAssertFalse([feedback containsString:@"891"]);
    }
    XCTAssertEqualObjects(p.snapshot.accumulator.counts, (@[@0, @8, @1]));
    XCTAssertEqualObjects(p.snapshot.visibleAnswerDigits, (@[NSNull.null, NSNull.null, @1]));
}
- (void)testZeroPlaceCarryAndTooSmallPoolFeedbackPreserveExistingQuantities {
    MultiplicativeTeachingActionPlan *carryPlan = [self plan:104 second:3 operation:@"×"];
    NSInteger source = NSNotFound;
    for (NSUInteger i = 0; i < carryPlan.sourceSequence.steps.count; i++) {
        MultiplicativeTeachingStep *step = carryPlan.sourceSequence.steps[i];
        if (step.kind == MultiplicativeTeachingStepKindPredict && step.activeColumn == 1) source = (NSInteger)i;
    }
    XCTAssertNotEqual(source, (NSInteger)NSNotFound);
    MultiplicativeTeachingPresentation *carry = [MultiplicativeTeachingPresentation preparationInPlan:carryPlan sessionID:@"carry"
        predictSourceIndex:source review:NO returnSelection:nil];
    XCTAssertEqualObjects(carry.snapshot.accumulator.counts, (@[@0, @1, @2]));
    XCTAssertTrue([[carry feedbackForProposal:0 matchesExpected:NO givenNumber1:104 givenNumber2:3] containsString:@"原來已有 1 個十"]);
    XCTAssertTrue([[carry feedbackForProposal:3 matchesExpected:NO givenNumber1:104 givenNumber2:3] containsString:@"只在累積區一次"]);
    MultiplicativeTeachingActionPlan *divisionPlan = [self plan:101 second:2 operation:@"÷"];
    for (NSUInteger i = 0; i < divisionPlan.sourceSequence.steps.count; i++) {
        MultiplicativeTeachingStep *step = divisionPlan.sourceSequence.steps[i];
        if (step.kind == MultiplicativeTeachingStepKindPredict && step.activeColumn == 2) source = (NSInteger)i;
    }
    MultiplicativeTeachingPresentation *division = [MultiplicativeTeachingPresentation preparationInPlan:divisionPlan sessionID:@"last-one"
        predictSourceIndex:source review:NO returnSelection:nil];
    NSString *feedback = [division feedbackForProposal:1 matchesExpected:NO givenNumber1:101 givenNumber2:2];
    XCTAssertTrue([feedback containsString:@"需要 2 個一"]); XCTAssertTrue([feedback containsString:@"只有 1 個一"]);
    XCTAssertNil(division.snapshot.visibleRemainder);
    MultiplicativeTeachingActionPlan *zeroCarryPlan = [self plan:126 second:4 operation:@"×"];
    MultiplicativeTeachingPresentation *zeroCarry = [MultiplicativeTeachingPresentation preparationInPlan:zeroCarryPlan sessionID:@"groups"
        predictSourceIndex:1 review:NO returnSelection:nil];
    XCTAssertTrue([[zeroCarry feedbackForProposal:10 matchesExpected:NO givenNumber1:126 givenNumber2:4] containsString:@"相加"]);
    XCTAssertTrue([[zeroCarry feedbackForProposal:18 matchesExpected:NO givenNumber1:126 givenNumber2:4] containsString:@"還少看一組"]);
}
- (void)testAttemptAndSessionIdentityRejectStaleCallbacksAtIdenticalQuantities {
    MultiplicativeTeachingActionPlan *plan = [self plan:899 second:9 operation:@"÷"];
    MultiplicativeTeachingPresentation *a = [MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"s1"
        predictSourceIndex:7 review:NO returnSelection:nil];
    MultiplicativeTeachingPresentation *b = [MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"s1"
        predictSourceIndex:7 review:YES returnSelection:nil];
    MultiplicativeTeachingPresentation *c = [MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"s2"
        predictSourceIndex:7 review:YES returnSelection:nil];
    XCTAssertEqual(a.snapshot, b.snapshot); XCTAssertNotEqualObjects(a.preparationKey.attemptID, b.preparationKey.attemptID);
    XCTAssertTrue([a acceptsPreparationKey:a.preparationKey]);
    XCTAssertFalse([b acceptsPreparationKey:a.preparationKey]); XCTAssertFalse([c acceptsPreparationKey:b.preparationKey]);
    MultiplicativeTeachingPresentation *action = [MultiplicativeTeachingPresentation actionInPlan:plan sessionID:@"s1" index:15 endpoint:MTPPresentationEndpointBefore];
    XCTAssertEqual(action.snapshot, a.snapshot); XCTAssertFalse([action acceptsPreparationKey:a.preparationKey]);
    XCTAssertNil([MultiplicativeTeachingPresentation preparationInPlan:plan sessionID:@"s1" predictSourceIndex:8 review:NO returnSelection:nil]);
    XCTAssertNil([MultiplicativeTeachingPresentation actionInPlan:plan sessionID:@"s1" index:14 endpoint:MTPPresentationEndpointBefore]);
}
- (void)testDirectResultsEndAtTheLastActionAfterAndNeverTheFollowingWrite {
    MultiplicativeTeachingActionPlan *division = [self plan:899 second:9 operation:@"÷"];
    MultiplicativeTeachingPresentation *d = [MultiplicativeTeachingPresentation inspectionInPlan:division sessionID:@"d"
        sourceStepIndex:8 endpoint:MTPPresentationEndpointAfter returnSelection:nil];
    XCTAssertEqual(d.snapshot, division.actions[23].after); XCTAssertNotEqual(d.snapshot, division.actions[24].after);
    XCTAssertEqualObjects(d.snapshot.pool.counts, (@[@0, @8, @0]));
    for (MultiplicativeTeachingQuantity *recipient in d.snapshot.recipients) XCTAssertEqualObjects(recipient.counts, (@[@0, @9, @0]));
    XCTAssertEqualObjects(d.snapshot.visibleAnswerDigits, (@[NSNull.null, NSNull.null, NSNull.null]));
    XCTAssertEqual(d.snapshot.visibleDivisionRows.count, 1u); XCTAssertNil(d.snapshot.visibleRemainder); XCTAssertNil(d.action);
    MultiplicativeTeachingActionPlan *multiply = [self plan:99 second:9 operation:@"×"];
    MultiplicativeTeachingPresentation *m = [MultiplicativeTeachingPresentation inspectionInPlan:multiply sessionID:@"m"
        sourceStepIndex:6 endpoint:MTPPresentationEndpointAfter returnSelection:nil];
    XCTAssertEqual(m.snapshot, multiply.actions[29].after);
    XCTAssertEqualObjects(m.snapshot.accumulator.counts, (@[@0, @89, @1]));
    XCTAssertEqual(m.snapshot.carryUnits[1].count, 0u);
    XCTAssertEqualObjects(m.snapshot.visibleAnswerDigits, (@[NSNull.null, NSNull.null, @1]));
    XCTAssertNil(m.action);
}
@end
