#import <XCTest/XCTest.h>
#import "GroupingTeachingSequence.h"
#import "WordProblem.h"

@interface GroupingTeachingSequenceTests : XCTestCase
@end

@implementation GroupingTeachingSequenceTests

- (GroupingStoryContext *)context:(GroupingStoryMeaning)meaning {
    return [[GroupingStoryContext alloc] initWithMeaning:meaning itemName:@"糖果" itemUnit:@"顆"
        groupName:meaning == GroupingStoryMeaningShareEqually ? @"個小朋友" : @"包"
        answerUnit:meaning == GroupingStoryMeaningMakeGroupsOf ? @"包" : @"顆"];
}

- (WordProblem *)story:(NSInteger)a divisor:(NSInteger)b answer:(NSInteger)answer remainder:(NSInteger)remainder
               context:(GroupingStoryContext *)context overrides:(NSDictionary *)overrides {
    NSString *operation = context.meaning == GroupingStoryMeaningBuildEqualGroups ? @"×" : @"÷";
    return [[WordProblem alloc] initWithStory:@"依照題目的規則分糖果。" templateID:@"fixture" grade:3
        number1:a number2:b operator:overrides[@"operator"] ?: operation answer:answer
        unit:overrides[@"unit"] ?: context.answerUnit ?: @"顆"
        missingAddend:[overrides[@"missingAddend"] boolValue]
        missingSubtrahend:[overrides[@"missingSubtrahend"] boolValue]
        missingMinuend:[overrides[@"missingMinuend"] boolValue] remainder:remainder
        number3:[overrides[@"number3"] integerValue] operator2:overrides[@"operator2"]
        intermediate:[overrides[@"intermediate"] integerValue]
        isFractionAnswer:[overrides[@"isFractionAnswer"] boolValue]
        answerNumerator:[overrides[@"answerNumerator"] integerValue]
        answerDenominator:[overrides[@"answerDenominator"] integerValue]
        groupingContext:context strategyText:@"每一步都遵守同一個規則。"];
}

- (GroupingTeachingSequence *)division:(NSInteger)a by:(NSInteger)b meaning:(GroupingStoryMeaning)meaning {
    WordProblem *story = [self story:a divisor:b answer:a / b remainder:a % b context:[self context:meaning] overrides:@{}];
    return [GroupingTeachingSequence sequenceForWordProblem:story];
}

- (GroupingTeachingSequence *)bare:(NSInteger)a by:(NSInteger)b operation:(NSString *)operation
                            answer:(NSInteger)answer meaning:(GroupingStoryMeaning)meaning {
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation answer:answer];
    return [GroupingTeachingSequence sequenceForArithmeticProblem:problem meaning:meaning];
}

- (NSArray<GroupingTeachingStep *> *)stepsOfKind:(GroupingTeachingStepKind)kind sequence:(GroupingTeachingSequence *)sequence {
    NSMutableArray *result = [NSMutableArray array];
    for (GroupingTeachingStep *step in sequence.steps) if (step.kind == kind) [result addObject:step];
    return [result copy];
}

- (NSInteger)sum:(NSArray<NSNumber *> *)counts {
    NSInteger sum = 0;
    for (NSNumber *count in counts) sum += count.integerValue;
    return sum;
}

- (void)assertContract:(GroupingTeachingSequence *)sequence {
    XCTAssertTrue(sequence.isSupported);
    XCTAssertEqual(sequence.status, GroupingTeachingStatusSupported);
    XCTAssertGreaterThan(sequence.steps.count, 0u);
    XCTAssertLessThanOrEqual(sequence.steps.count, 32u);
    XCTAssertEqual(sequence.steps.firstObject.kind, GroupingTeachingStepKindObserve);
    XCTAssertEqual(sequence.steps.lastObject.kind, GroupingTeachingStepKindCompletion);
    XCTAssertEqual([self stepsOfKind:GroupingTeachingStepKindWriteAnswer sequence:sequence].count, 1u);
    XCTAssertEqual([self stepsOfKind:GroupingTeachingStepKindVerify sequence:sequence].count, 1u);
    BOOL build = sequence.context.meaning == GroupingStoryMeaningBuildEqualGroups;
    BOOL share = sequence.context.meaning == GroupingStoryMeaningShareEqually;
    NSInteger g = build || share ? sequence.problem.number2 : sequence.problem.answer;
    NSInteger s = build ? sequence.problem.number1 : (share ? sequence.problem.answer : sequence.problem.number2);
    NSInteger total = build ? sequence.problem.answer : sequence.problem.number1;
    XCTAssertLessThanOrEqual(g + (sequence.remainder > 0 ? 1 : 0), 9);
    XCTAssertLessThanOrEqual(s, 10);
    XCTAssertLessThanOrEqual(total, 90);
    XCTAssertEqual(sequence.steps.firstObject.groupCountsAfter.count, share ? g : 0);
    BOOL written = NO, inspected = NO;
    GroupingTeachingStep *previous = nil;
    NSUInteger index = 0;
    for (GroupingTeachingStep *step in sequence.steps) {
        XCTAssertGreaterThan(step.title.length, 0u);
        XCTAssertGreaterThan(step.explanation.length, 0u);
        XCTAssertGreaterThan(step.spokenExplanation.length, 0u);
        XCTAssertFalse([step.groupCountsBefore isKindOfClass:[NSMutableArray class]]);
        XCTAssertFalse([step.groupCountsAfter isKindOfClass:[NSMutableArray class]]);
        XCTAssertFalse([step.activeGroupIndices isKindOfClass:[NSMutableArray class]]);
        if (previous) {
            XCTAssertEqualObjects(step.groupCountsBefore, previous.groupCountsAfter);
            XCTAssertEqualObjects(step.poolCountBefore, previous.poolCountAfter);
        }
        for (NSArray<NSNumber *> *counts in @[step.groupCountsBefore, step.groupCountsAfter]) {
            XCTAssertLessThanOrEqual(counts.count, g);
            for (NSNumber *count in counts) {
                XCTAssertGreaterThanOrEqual(count.integerValue, 0);
                XCTAssertLessThanOrEqual(count.integerValue, 10);
                XCTAssertEqual(count.integerValue, share ? counts.firstObject.integerValue : s);
            }
            if (share) XCTAssertEqual(counts.count, g);
        }
        if (build) {
            XCTAssertNil(step.poolCountBefore);
            XCTAssertNil(step.poolCountAfter);
            XCTAssertNil(step.visibleRemainder);
            XCTAssertNotNil(step.unopenedGroupCount);
            XCTAssertEqual(step.unopenedGroupCount.integerValue, g - (NSInteger)step.groupCountsAfter.count);
            XCTAssertEqual([self sum:step.groupCountsAfter] + step.unopenedGroupCount.integerValue * s, total);
        } else {
            XCTAssertNil(step.unopenedGroupCount);
            XCTAssertNotNil(step.poolCountBefore);
            XCTAssertNotNil(step.poolCountAfter);
            XCTAssertGreaterThanOrEqual(step.poolCountBefore.integerValue, 0);
            XCTAssertGreaterThanOrEqual(step.poolCountAfter.integerValue, 0);
            XCTAssertEqual([self sum:step.groupCountsBefore] + step.poolCountBefore.integerValue, total);
            XCTAssertEqual([self sum:step.groupCountsAfter] + step.poolCountAfter.integerValue, total);
        }
        BOOL action = step.kind == GroupingTeachingStepKindBuildGroup ||
            step.kind == GroupingTeachingStepKindShareRound || step.kind == GroupingTeachingStepKindPackGroup;
        if (action) {
            XCTAssertGreaterThan(step.actionTitle.length, 0u);
            XCTAssertEqual(step.transferCount, share ? g : s);
            if (share) {
                XCTAssertEqual(step.activeGroupIndices.count, g);
                for (NSInteger recipient = 0; recipient < g; recipient++) {
                    XCTAssertEqual(step.groupCountsAfter[recipient].integerValue - step.groupCountsBefore[recipient].integerValue, 1);
                    XCTAssertEqual(step.activeGroupIndices[recipient].integerValue, recipient);
                }
            } else {
                XCTAssertEqual(step.groupCountsAfter.count, step.groupCountsBefore.count + 1);
                XCTAssertEqual(step.groupCountsAfter.lastObject.integerValue, s);
                XCTAssertEqualObjects(step.activeGroupIndices, (@[@(step.groupCountsBefore.count)]));
            }
            if (!build) XCTAssertEqual(step.poolCountBefore.integerValue - step.poolCountAfter.integerValue, step.transferCount);
        } else {
            XCTAssertEqualObjects(step.groupCountsBefore, step.groupCountsAfter);
            XCTAssertEqualObjects(step.poolCountBefore, step.poolCountAfter);
            XCTAssertEqual(step.activeGroupIndices.count, 0u);
            XCTAssertEqual(step.transferCount, 0);
            XCTAssertEqualObjects(step.actionTitle, @"");
        }
        if (step.kind == GroupingTeachingStepKindPredict) {
            XCTAssertNotNil(step.expectedAnswer);
            XCTAssertGreaterThan(step.prompt.length, 0u);
            XCTAssertLessThan(index + 1, sequence.steps.count);
            GroupingTeachingStep *next = sequence.steps[index + 1];
            if (step.predictionKind == GroupingTeachingPredictionKindCanContinue) {
                XCTAssertEqualObjects(step.expectedAnswer, @NO);
                XCTAssertEqual(next.kind, GroupingTeachingStepKindInspectRemainder);
            } else {
                XCTAssertEqual(step.predictionKind, GroupingTeachingPredictionKindCount);
                NSInteger expected = share ? next.groupCountsAfter.firstObject.integerValue
                    : (build ? [self sum:next.groupCountsAfter] : (NSInteger)next.groupCountsAfter.count);
                XCTAssertEqual(step.expectedAnswer.integerValue, expected);
            }
        } else {
            XCTAssertNil(step.expectedAnswer);
            XCTAssertEqualObjects(step.prompt, @"");
            XCTAssertEqual(step.predictionKind, GroupingTeachingPredictionKindNone);
        }
        if (step.kind == GroupingTeachingStepKindWriteAnswer) written = YES;
        if (written) XCTAssertEqualObjects(step.visibleAnswer, @(sequence.problem.answer));
        else XCTAssertNil(step.visibleAnswer);
        if (step.kind == GroupingTeachingStepKindInspectRemainder) inspected = YES;
        if (inspected) XCTAssertEqualObjects(step.visibleRemainder, @(sequence.remainder));
        else XCTAssertNil(step.visibleRemainder);
        previous = step;
        index++;
    }
    XCTAssertEqual(sequence.steps.lastObject.groupCountsAfter.count, g);
    if (!build) {
        XCTAssertEqual(sequence.steps.lastObject.poolCountAfter.integerValue, sequence.remainder);
        XCTAssertLessThan(sequence.remainder, sequence.problem.number2);
    }
}

- (void)testAllMultiplicationFactsAndZeroKeepGivenFactorRoles {
    for (NSInteger a = 0; a <= 9; a++) {
        for (NSInteger b = 0; b <= 9; b++) {
            GroupingTeachingSequence *sequence = [self bare:a by:b operation:@"×" answer:a * b meaning:GroupingStoryMeaningBuildEqualGroups];
            [self assertContract:sequence];
            XCTAssertEqual([self stepsOfKind:GroupingTeachingStepKindBuildGroup sequence:sequence].count, b);
            XCTAssertEqual(sequence.steps.firstObject.unopenedGroupCount.integerValue, b);
            XCTAssertEqual(sequence.steps.lastObject.groupCountsAfter.count, b);
            XCTAssertEqual([self sum:sequence.steps.lastObject.groupCountsAfter], a * b);
        }
    }
    GroupingTeachingSequence *threeByFour = [self bare:3 by:4 operation:@"×" answer:12 meaning:GroupingStoryMeaningBuildEqualGroups];
    GroupingTeachingSequence *fourByThree = [self bare:4 by:3 operation:@"×" answer:12 meaning:GroupingStoryMeaningBuildEqualGroups];
    XCTAssertEqualObjects(threeByFour.steps.lastObject.groupCountsAfter, (@[@3, @3, @3, @3]));
    XCTAssertEqualObjects(fourByThree.steps.lastObject.groupCountsAfter, (@[@4, @4, @4]));
}

- (void)testSameDivisionNumbersKeepSharingAndPackingDifferent {
    NSArray<NSArray<NSNumber *> *> *fixtures = @[@[@24, @4], @[@23, @4], @[@8, @3], @[@9, @9], @[@2, @5], @[@0, @5]];
    for (NSArray<NSNumber *> *pair in fixtures) {
        NSInteger a = pair[0].integerValue, b = pair[1].integerValue;
        GroupingTeachingSequence *share = [self division:a by:b meaning:GroupingStoryMeaningShareEqually];
        GroupingTeachingSequence *pack = [self division:a by:b meaning:GroupingStoryMeaningMakeGroupsOf];
        [self assertContract:share];
        [self assertContract:pack];
        XCTAssertEqual([self stepsOfKind:GroupingTeachingStepKindShareRound sequence:share].count, a / b);
        XCTAssertEqual([self stepsOfKind:GroupingTeachingStepKindPackGroup sequence:pack].count, a / b);
        XCTAssertEqual(share.steps.firstObject.groupCountsAfter.count, b);
        XCTAssertEqual(pack.steps.firstObject.groupCountsAfter.count, 0u);
        XCTAssertEqualObjects(share.context.answerUnit, @"顆");
        XCTAssertEqualObjects(pack.context.answerUnit, @"包");
        XCTAssertEqualObjects(pack.context.leftoverUnit, @"顆");
    }
    GroupingTeachingSequence *share = [self division:23 by:4 meaning:GroupingStoryMeaningShareEqually];
    GroupingTeachingSequence *pack = [self division:23 by:4 meaning:GroupingStoryMeaningMakeGroupsOf];
    XCTAssertEqualObjects(share.steps.lastObject.groupCountsAfter, (@[@5, @5, @5, @5]));
    XCTAssertEqualObjects(pack.steps.lastObject.groupCountsAfter, (@[@4, @4, @4, @4, @4]));
    GroupingTeachingStep *shareWrite = [self stepsOfKind:GroupingTeachingStepKindWriteAnswer sequence:share].firstObject;
    GroupingTeachingStep *packWrite = [self stepsOfKind:GroupingTeachingStepKindWriteAnswer sequence:pack].firstObject;
    XCTAssertEqualObjects(shareWrite.explanation, @"每個小朋友分到的糖果最多有 5 顆。另外共同剩下的糖果有 3 顆。");
    XCTAssertEqualObjects(packWrite.explanation, @"可以分成 5 包。另外共同剩下的糖果有 3 顆。");
    GroupingTeachingStep *shareInspect = [self stepsOfKind:GroupingTeachingStepKindInspectRemainder sequence:share].firstObject;
    GroupingTeachingStep *packInspect = [self stepsOfKind:GroupingTeachingStepKindInspectRemainder sequence:pack].firstObject;
    XCTAssertTrue([shareInspect.explanation containsString:@"再讓每個小朋友拿 1 顆需要 4 顆"]);
    XCTAssertTrue([packInspect.explanation containsString:@"不到一包需要的 4 顆"]);
    XCTAssertFalse([packInspect.explanation containsString:@"剩下 3 包"]);
}

- (void)testStoryBuildAndHumanRemainderUnitsStayExplicit {
    WordProblem *buildStory = [self story:3 divisor:4 answer:12 remainder:0
        context:[self context:GroupingStoryMeaningBuildEqualGroups] overrides:@{}];
    GroupingTeachingSequence *build = [GroupingTeachingSequence sequenceForWordProblem:buildStory];
    [self assertContract:build];
    XCTAssertEqualObjects(build.steps.lastObject.groupCountsAfter, (@[@3, @3, @3, @3]));
    XCTAssertEqualObjects(build.wordProblem.unit, @"顆");
    GroupingStoryContext *teamContext = [[GroupingStoryContext alloc] initWithMeaning:GroupingStoryMeaningMakeGroupsOf
        itemName:@"球員" itemUnit:@"人" groupName:@"隊" answerUnit:@"隊"];
    WordProblem *teamStory = [self story:23 divisor:4 answer:5 remainder:3 context:teamContext overrides:@{}];
    GroupingTeachingSequence *team = [GroupingTeachingSequence sequenceForWordProblem:teamStory];
    [self assertContract:team];
    GroupingTeachingStep *write = [self stepsOfKind:GroupingTeachingStepKindWriteAnswer sequence:team].firstObject;
    XCTAssertEqualObjects(write.explanation, @"可以分成 5 隊。另外共同剩下的球員有 3 人。");
    for (GroupingTeachingStep *step in team.steps) {
        XCTAssertFalse([step.spokenExplanation containsString:@"人球員"]);
        XCTAssertFalse([step.spokenExplanation containsString:@"剩下 3 隊"]);
    }
}

- (void)testCurrentOnlyPredictionAndSpeechNeverPrefillAnAnswer {
    GroupingTeachingSequence *sequence = [self division:23 by:4 meaning:GroupingStoryMeaningShareEqually];
    GroupingTeachingStep *initial = sequence.steps.firstObject;
    XCTAssertEqualObjects(initial.explanation, @"把糖果 23 顆平均分給 4 個小朋友。每一輪都讓每個小朋友拿 1 顆。");
    XCTAssertEqualObjects(initial.spokenExplanation, @"把糖果 23 顆平均分給 4 個小朋友。每一輪都讓每個小朋友拿 1 顆。 4 個小朋友，每個小朋友的糖果現在有 0 顆；共同待分的糖果還有 23 顆。");
    GroupingTeachingStep *prediction = sequence.steps[1];
    XCTAssertEqualObjects(prediction.prompt, @"每個小朋友再拿 1 顆後，每個小朋友會有幾顆？");
    XCTAssertEqualObjects(prediction.expectedAnswer, @1);
    XCTAssertEqualObjects(prediction.groupCountsBefore, prediction.groupCountsAfter);
    XCTAssertEqualObjects(prediction.poolCountBefore, prediction.poolCountAfter);
    XCTAssertNil(prediction.visibleAnswer);
    XCTAssertNil(prediction.visibleRemainder);
    GroupingTeachingSequence *pack = [self division:23 by:4 meaning:GroupingStoryMeaningMakeGroupsOf];
    XCTAssertEqualObjects(pack.steps.firstObject.groupCountsAfter, @[]);
    XCTAssertEqualObjects(pack.steps.firstObject.explanation, @"糖果共有 23 顆，每包要有 4 顆。一次分出完整的一包，看看能分成幾包。");
    // A current group count can legitimately equal the final answer. Do not test
    // prose using a numeric substring ban; inspect the actual role-aware sentences.
}

- (void)testBoundsDoNotSwapMeaningOrTruncateTheOriginalQuestion {
    NSArray *supported = @[
        [self bare:10 by:9 operation:@"×" answer:90 meaning:GroupingStoryMeaningBuildEqualGroups],
        [self division:90 by:9 meaning:GroupingStoryMeaningShareEqually],
        [self division:80 by:9 meaning:GroupingStoryMeaningMakeGroupsOf]
    ];
    for (GroupingTeachingSequence *sequence in supported) [self assertContract:sequence];
    NSArray *outside = @[
        [self bare:11 by:1 operation:@"×" answer:11 meaning:GroupingStoryMeaningBuildEqualGroups],
        [self bare:0 by:10 operation:@"×" answer:0 meaning:GroupingStoryMeaningBuildEqualGroups],
        [self bare:11 by:0 operation:@"×" answer:0 meaning:GroupingStoryMeaningBuildEqualGroups],
        [self division:90 by:9 meaning:GroupingStoryMeaningMakeGroupsOf],
        [self division:80 by:9 meaning:GroupingStoryMeaningShareEqually],
        [self division:91 by:10 meaning:GroupingStoryMeaningMakeGroupsOf],
        [self bare:NSIntegerMax by:1 operation:@"×" answer:NSIntegerMax meaning:GroupingStoryMeaningBuildEqualGroups],
        [self bare:NSIntegerMax by:1 operation:@"÷" answer:NSIntegerMax meaning:GroupingStoryMeaningMakeGroupsOf]
    ];
    for (GroupingTeachingSequence *sequence in outside) {
        XCTAssertEqual(sequence.status, GroupingTeachingStatusOutsideConcreteBounds);
        XCTAssertFalse(sequence.isSupported);
        XCTAssertEqual(sequence.steps.count, 0u);
    }
    GroupingTeachingSequence *share = outside[4];
    XCTAssertEqual(share.problem.number1, 80);
    XCTAssertEqual(share.problem.number2, 9);
    XCTAssertEqual(share.remainder, 8);
    XCTAssertEqual(share.context.meaning, GroupingStoryMeaningShareEqually);
}

- (void)testInvalidArithmeticAndAllSpecialStoryFlagsProduceNoSteps {
    GroupingStoryContext *share = [self context:GroupingStoryMeaningShareEqually];
    NSMutableArray<GroupingTeachingSequence *> *invalid = [NSMutableArray array];
    NSArray *arithmetic = @[
        @[@23, @4, @6, @3], @[@23, @4, @5, @0], @[@23, @4, @5, @4],
        @[@23, @4, @5, @(-1)], @[@(-1), @4, @0, @0], @[@23, @(-4), @0, @0],
        @[@23, @4, @(-1), @3], @[@1, @0, @0, @0]
    ];
    for (NSArray *values in arithmetic) {
        WordProblem *story = [self story:[values[0] integerValue] divisor:[values[1] integerValue]
            answer:[values[2] integerValue] remainder:[values[3] integerValue] context:share overrides:@{}];
        [invalid addObject:[GroupingTeachingSequence sequenceForWordProblem:story]];
    }
    for (NSDictionary *override in @[@{@"missingAddend": @YES}, @{@"missingSubtrahend": @YES},
        @{@"missingMinuend": @YES}, @{@"operator2": @""}, @{@"number3": @1}, @{@"intermediate": @1},
        @{@"isFractionAnswer": @YES}, @{@"answerNumerator": @1}, @{@"answerDenominator": @2}, @{@"unit": @"包"}]) {
        WordProblem *story = [self story:23 divisor:4 answer:5 remainder:3 context:share overrides:override];
        [invalid addObject:[GroupingTeachingSequence sequenceForWordProblem:story]];
    }
    WordProblem *multiplyWithRemainder = [self story:3 divisor:4 answer:12 remainder:1
        context:[self context:GroupingStoryMeaningBuildEqualGroups] overrides:@{}];
    [invalid addObject:[GroupingTeachingSequence sequenceForWordProblem:multiplyWithRemainder]];
    [invalid addObject:[self bare:NSIntegerMax by:2 operation:@"×" answer:0 meaning:GroupingStoryMeaningBuildEqualGroups]];
    [invalid addObject:[self bare:2 by:3 operation:@"×" answer:5 meaning:GroupingStoryMeaningBuildEqualGroups]];
    [invalid addObject:[self bare:2 by:3 operation:@"×" answer:6 meaning:GroupingStoryMeaningShareEqually]];
    [invalid addObject:[self bare:6 by:3 operation:@"÷" answer:2 meaning:GroupingStoryMeaningBuildEqualGroups]];
    [invalid addObject:[GroupingTeachingSequence sequenceForWordProblem:nil]];
    [invalid addObject:[GroupingTeachingSequence sequenceForArithmeticProblem:nil meaning:GroupingStoryMeaningMakeGroupsOf]];
    GroupingStoryContext *badUnits = [[GroupingStoryContext alloc] initWithMeaning:GroupingStoryMeaningMakeGroupsOf
        itemName:@"糖果" itemUnit:@"顆" groupName:@"包" answerUnit:@"顆"];
    [invalid addObject:[GroupingTeachingSequence sequenceForWordProblem:[self story:23 divisor:4 answer:5 remainder:3 context:badUnits overrides:@{}]]];
    ArithmeticProblem *multiStep = [[ArithmeticProblem alloc] initWithNumber1:6 number2:3 operator:@"÷" answer:2];
    multiStep.isMultiStep = YES;
    [invalid addObject:[GroupingTeachingSequence sequenceForArithmeticProblem:multiStep meaning:GroupingStoryMeaningMakeGroupsOf]];
    for (GroupingTeachingSequence *sequence in invalid) {
        XCTAssertEqual(sequence.status, GroupingTeachingStatusInvalidProblem);
        XCTAssertFalse(sequence.isSupported);
        XCTAssertEqual(sequence.steps.count, 0u);
    }
}

- (void)testMissingMeaningAndLegacyStoriesNeverInferFromKnownTemplateID {
    WordProblem *legacy = [[WordProblem alloc] initWithStory:@"每包有 3 顆糖果，4 包有幾顆？"
        templateID:@"g2_mul_candy" grade:2 number1:3 number2:4 operator:@"×" answer:12 unit:@"顆"];
    NSArray *unsupported = @[
        [GroupingTeachingSequence sequenceForWordProblem:legacy],
        [self bare:3 by:4 operation:@"×" answer:12 meaning:(GroupingStoryMeaning)NSIntegerMax],
        [self bare:3 by:4 operation:@"+" answer:7 meaning:GroupingStoryMeaningBuildEqualGroups]
    ];
    for (GroupingTeachingSequence *sequence in unsupported) {
        XCTAssertEqual(sequence.status, GroupingTeachingStatusMissingOrUnsupportedMeaning);
        XCTAssertEqual(sequence.steps.count, 0u);
    }
}

- (void)testBareAliasesAndRemainderInferenceAreIsolatedFromStoryRoute {
    GroupingTeachingSequence *bare = [self bare:23 by:4 operation:@"/" answer:5 meaning:GroupingStoryMeaningMakeGroupsOf];
    [self assertContract:bare];
    XCTAssertEqualObjects(bare.problem.operatorSymbol, @"÷");
    XCTAssertEqual(bare.remainder, 3);
    XCTAssertNil(bare.wordProblem);
    [self assertContract:[self bare:3 by:4 operation:@"*" answer:12 meaning:GroupingStoryMeaningBuildEqualGroups]];
    WordProblem *missingRemainder = [self story:23 divisor:4 answer:5 remainder:0
        context:[self context:GroupingStoryMeaningMakeGroupsOf] overrides:@{}];
    XCTAssertEqual([GroupingTeachingSequence sequenceForWordProblem:missingRemainder].status, GroupingTeachingStatusInvalidProblem);
    WordProblem *aliasStory = [self story:23 divisor:4 answer:5 remainder:3
        context:[self context:GroupingStoryMeaningMakeGroupsOf] overrides:@{@"operator": @"/"}];
    XCTAssertEqual([GroupingTeachingSequence sequenceForWordProblem:aliasStory].status, GroupingTeachingStatusMissingOrUnsupportedMeaning);
}

- (void)testCopiesMutableInputsAndReplayingOrLookingBackDoesNotMutateSnapshots {
    NSMutableString *operation = [NSMutableString stringWithString:@"/"];
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:23 number2:4 operator:operation answer:5];
    problem.auxiliaryDistractor = 99;
    GroupingTeachingSequence *sequence = [GroupingTeachingSequence sequenceForArithmeticProblem:problem meaning:GroupingStoryMeaningMakeGroupsOf];
    [operation setString:@"×"];
    problem.number1 = 0; problem.number2 = 0; problem.answer = 0; problem.isMultiStep = YES;
    ArithmeticProblem *exposed = sequence.problem;
    exposed.number1 = 99; exposed.operatorSymbol = @"+"; exposed.answer = 99;
    [self assertContract:sequence];
    XCTAssertEqual(sequence.problem.number1, 23);
    XCTAssertEqual(sequence.problem.number2, 4);
    XCTAssertEqual(sequence.problem.answer, 5);
    XCTAssertEqual(sequence.remainder, 3);
    XCTAssertEqual(sequence.problem.auxiliaryDistractor, 99);
    XCTAssertEqualObjects(sequence.problem.operatorSymbol, @"÷");
    GroupingTeachingStep *initial = sequence.steps.firstObject;
    GroupingTeachingStep *finished = sequence.steps.lastObject;
    XCTAssertEqualObjects(finished.visibleAnswer, @5);
    XCTAssertNil(initial.visibleAnswer);
    XCTAssertEqualObjects(initial.poolCountAfter, @23);
    XCTAssertEqualObjects(initial.groupCountsAfter, @[]);
    XCTAssertEqualObjects(sequence.steps[2].groupCountsBefore, @[]);
    XCTAssertEqualObjects(sequence.steps[2].groupCountsAfter, (@[@4]));
    XCTAssertEqualObjects(sequence.steps[4].groupCountsBefore, (@[@4]));
    XCTAssertEqualObjects(sequence.steps[4].groupCountsAfter, (@[@4, @4]));
    GroupingTeachingSequence *again = [GroupingTeachingSequence sequenceForArithmeticProblem:sequence.problem meaning:GroupingStoryMeaningMakeGroupsOf];
    XCTAssertEqual(again.steps.count, sequence.steps.count);
    for (NSUInteger index = 0; index < again.steps.count; index++) {
        XCTAssertEqualObjects(again.steps[index].groupCountsBefore, sequence.steps[index].groupCountsBefore);
        XCTAssertEqualObjects(again.steps[index].groupCountsAfter, sequence.steps[index].groupCountsAfter);
        XCTAssertEqualObjects(again.steps[index].poolCountAfter, sequence.steps[index].poolCountAfter);
        XCTAssertEqualObjects(again.steps[index].spokenExplanation, sequence.steps[index].spokenExplanation);
        XCTAssertEqualObjects(again.steps[index].visibleAnswer, sequence.steps[index].visibleAnswer);
    }
    WordProblem *story = [self story:23 divisor:4 answer:5 remainder:3 context:[self context:GroupingStoryMeaningShareEqually] overrides:@{}];
    GroupingTeachingSequence *storySequence = [GroupingTeachingSequence sequenceForWordProblem:story];
    XCTAssertNotEqual(story, storySequence.wordProblem);
    XCTAssertEqualObjects(storySequence.wordProblem.storyText, story.storyText);
    XCTAssertEqualObjects(storySequence.wordProblem.strategyText, story.strategyText);
    XCTAssertEqualObjects(storySequence.wordProblem.groupingContext.itemName, @"糖果");
}

- (void)testOptionalPredictionsChangeNoMathematicalActionOrReveal {
    WordProblem *story = [self story:23 divisor:4 answer:5 remainder:3 context:[self context:GroupingStoryMeaningShareEqually] overrides:@{}];
    GroupingTeachingSequence *with = [GroupingTeachingSequence sequenceForWordProblem:story];
    GroupingTeachingSequence *without = [GroupingTeachingSequence sequenceForWordProblem:story includePredictions:NO];
    [self assertContract:without];
    XCTAssertEqual([self stepsOfKind:GroupingTeachingStepKindPredict sequence:without].count, 0u);
    NSUInteger index = 0;
    for (GroupingTeachingStep *step in with.steps) {
        if (step.kind == GroupingTeachingStepKindPredict) continue;
        GroupingTeachingStep *other = without.steps[index++];
        XCTAssertEqual(other.kind, step.kind);
        XCTAssertEqualObjects(other.groupCountsBefore, step.groupCountsBefore);
        XCTAssertEqualObjects(other.groupCountsAfter, step.groupCountsAfter);
        XCTAssertEqualObjects(other.poolCountAfter, step.poolCountAfter);
        XCTAssertEqualObjects(other.visibleAnswer, step.visibleAnswer);
        XCTAssertEqualObjects(other.visibleRemainder, step.visibleRemainder);
    }
    XCTAssertEqual(index, without.steps.count);
}

@end
