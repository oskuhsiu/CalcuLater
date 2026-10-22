#import <XCTest/XCTest.h>
#import "ConceptLearningPath.h"
#import "ArithmeticProblem.h"
#import "ArithmeticTeachingSequence.h"
#import "GroupingTeachingSequence.h"
#import "Lesson.h"
#import "WordProblem.h"

@interface ConceptLearningPathTests : XCTestCase
@end

@implementation ConceptLearningPathTests

- (ConceptLearningPath *)pathWithID:(NSString *)pathID {
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        if ([path.pathID isEqualToString:pathID]) return path;
    }
    XCTFail(@"Missing concept path: %@", pathID);
    return nil;
}

- (NSArray<ConceptLearningExample *> *)examplesInPath:(ConceptLearningPath *)path {
    XCTAssertNotNil(path.firstExample);
    XCTAssertNotNil(path.relatedExample);
    if (!path.firstExample || !path.relatedExample) return @[];
    return [@[path.firstExample, path.relatedExample] arrayByAddingObjectsFromArray:path.explorationExamples];
}

- (NSArray<GroupingTeachingStep *> *)groupingSteps:(GroupingTeachingStepKind)kind
                                         sequence:(GroupingTeachingSequence *)sequence {
    NSMutableArray<GroupingTeachingStep *> *result = [NSMutableArray array];
    for (GroupingTeachingStep *step in sequence.steps) {
        if (step.kind == kind) [result addObject:step];
    }
    return [result copy];
}

- (void)assertProblem:(ArithmeticProblem *)actual equals:(ArithmeticProblem *)expected {
    XCTAssertEqual(actual.number1, expected.number1);
    XCTAssertEqual(actual.number2, expected.number2);
    XCTAssertEqualObjects(actual.operatorSymbol, expected.operatorSymbol);
    XCTAssertEqual(actual.answer, expected.answer);
    XCTAssertEqual(actual.auxiliaryDistractor, expected.auxiliaryDistractor);
    XCTAssertEqual(actual.isMultiStep, expected.isMultiStep);
}

- (void)assertFullStory:(WordProblem *)actual equals:(WordProblem *)expected {
    XCTAssertNotNil(actual);
    XCTAssertEqualObjects(actual.storyText, expected.storyText);
    XCTAssertEqualObjects(actual.templateID, expected.templateID);
    XCTAssertEqual(actual.grade, expected.grade);
    XCTAssertEqual(actual.number1, expected.number1);
    XCTAssertEqual(actual.number2, expected.number2);
    XCTAssertEqualObjects(actual.operatorSymbol, expected.operatorSymbol);
    XCTAssertEqual(actual.answer, expected.answer);
    XCTAssertEqualObjects(actual.unit, expected.unit);
    XCTAssertEqual(actual.missingAddend, expected.missingAddend);
    XCTAssertEqual(actual.missingSubtrahend, expected.missingSubtrahend);
    XCTAssertEqual(actual.missingMinuend, expected.missingMinuend);
    XCTAssertEqual(actual.remainder, expected.remainder);
    XCTAssertEqual(actual.number3, expected.number3);
    XCTAssertEqualObjects(actual.operator2, expected.operator2);
    XCTAssertEqual(actual.intermediate, expected.intermediate);
    XCTAssertEqual(actual.isFractionAnswer, expected.isFractionAnswer);
    XCTAssertEqual(actual.answerNumerator, expected.answerNumerator);
    XCTAssertEqual(actual.answerDenominator, expected.answerDenominator);
    XCTAssertEqualObjects(actual.strategyText, expected.strategyText);
    XCTAssertNotNil(actual.groupingContext);
    XCTAssertEqual(actual.groupingContext.meaning, expected.groupingContext.meaning);
    XCTAssertEqualObjects(actual.groupingContext.itemName, expected.groupingContext.itemName);
    XCTAssertEqualObjects(actual.groupingContext.itemUnit, expected.groupingContext.itemUnit);
    XCTAssertEqualObjects(actual.groupingContext.groupName, expected.groupingContext.groupName);
    XCTAssertEqualObjects(actual.groupingContext.answerUnit, expected.groupingContext.answerUnit);
    XCTAssertEqualObjects(actual.groupingContext.leftoverUnit, expected.groupingContext.leftoverUnit);
}

- (void)testCatalogHasFiveDistinctPathsWithThreeDeliberateStages {
    NSArray<ConceptLearningPath *> *paths = [ConceptLearningPath allPaths];
    NSArray<NSString *> *expectedIDs = @[@"carry", @"borrow", @"equal-groups", @"sharing", @"packing"];
    XCTAssertEqualObjects([paths valueForKey:@"pathID"], expectedIDs);
    XCTAssertFalse([paths isKindOfClass:[NSMutableArray class]]);
    NSMutableSet<NSString *> *titles = [NSMutableSet set];
    for (ConceptLearningPath *path in paths) {
        XCTAssertGreaterThan(path.title.length, 0u);
        XCTAssertGreaterThan(path.summaryText.length, 0u);
        XCTAssertGreaterThan(path.iconName.length, 0u);
        [titles addObject:path.title];
        XCTAssertEqual(path.explorationExamples.count, 3u);
        XCTAssertFalse([path.explorationExamples isKindOfClass:[NSMutableArray class]]);
        XCTAssertNotEqual(path.firstExample, path.relatedExample);
        NSArray<ConceptLearningExample *> *examples = [self examplesInPath:path];
        XCTAssertEqual(examples.count, 5u);
        NSMutableSet<NSString *> *equations = [NSMutableSet set];
        for (ConceptLearningExample *example in examples) {
            XCTAssertGreaterThan(example.questionText.length, 0u);
            XCTAssertGreaterThan(example.focusText.length, 0u);
            [equations addObject:example.equationText];
        }
        NSUInteger distinctCount = [path.pathID isEqualToString:@"borrow"] ? 4 : 5;
        XCTAssertEqual(equations.count, distinctCount, @"Only the explicit zero-tens comparison repeats a question.");
        if ([path.pathID isEqualToString:@"borrow"]) {
            XCTAssertEqualObjects(path.relatedExample.equationText, path.explorationExamples[1].equationText);
            XCTAssertNotEqualObjects(path.relatedExample.focusText, path.explorationExamples[1].focusText);
        }
        NSMutableArray *editableChoices = [path.explorationExamples mutableCopy];
        [editableChoices removeAllObjects];
        XCTAssertEqual(path.explorationExamples.count, 3u);
    }
    XCTAssertEqual(titles.count, expectedIDs.count);
}

- (void)testCuratedStageOrderIsStableRatherThanRandomPractice {
    NSDictionary<NSString *, NSArray<NSString *> *> *expected = @{
        @"carry": @[@"27 + 15 = ?", @"36 + 18 = ?", @"43 + 16 = ?", @"43 + 17 = ?", @"43 + 18 = ?"],
        @"borrow": @[@"42 − 16 = ?", @"102 − 38 = ?", @"112 − 38 = ?", @"102 − 38 = ?", @"203 − 57 = ?"],
        @"equal-groups": @[@"3 × 2 = ?", @"3 × 3 = ?", @"4 × 3 = ?", @"3 × 4 = ?", @"2 × 5 = ?"],
        @"sharing": @[@"12 ÷ 3 = ?", @"13 ÷ 3 = ?", @"17 ÷ 4 = ?", @"18 ÷ 4 = ?", @"19 ÷ 4 = ?"],
        @"packing": @[@"12 ÷ 3 = ?", @"13 ÷ 3 = ?", @"17 ÷ 4 = ?", @"18 ÷ 4 = ?", @"19 ÷ 4 = ?"]
    };
    for (NSUInteger read = 0; read < 3; read++) {
        for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
            NSArray *actual = [[self examplesInPath:path] valueForKey:@"equationText"];
            XCTAssertEqualObjects(actual, expected[path.pathID]);
        }
    }
}

- (void)testEveryExampleUsesItsSupportedTeachingRouteWithoutPrefillingAnswers {
    NSUInteger verticalCount = 0, groupingCount = 0;
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        for (ConceptLearningExample *example in [self examplesInPath:path]) {
            if (example.wordProblem) {
                groupingCount++;
                // Story routing must retain explicit meaning and remainder; no bare-arithmetic fallback.
                for (NSNumber *predictions in @[@YES, @NO]) {
                    GroupingTeachingSequence *sequence = [GroupingTeachingSequence
                        sequenceForWordProblem:example.wordProblem includePredictions:predictions.boolValue];
                    XCTAssertTrue(sequence.isSupported, @"%@ / %@", path.pathID, example.equationText);
                    XCTAssertEqual(sequence.status, GroupingTeachingStatusSupported);
                    XCTAssertGreaterThan(sequence.steps.count, 0u);
                    XCTAssertLessThanOrEqual(sequence.steps.count, 32u);
                    XCTAssertEqual(sequence.steps.firstObject.kind, GroupingTeachingStepKindObserve);
                    XCTAssertEqual(sequence.steps.lastObject.kind, GroupingTeachingStepKindCompletion);
                    XCTAssertEqual(sequence.remainder, example.wordProblem.remainder);
                    XCTAssertEqual([self groupingSteps:GroupingTeachingStepKindWriteAnswer sequence:sequence].count, 1u);
                    BOOL divides = [example.wordProblem.operatorSymbol isEqualToString:@"÷"];
                    XCTAssertEqual([self groupingSteps:GroupingTeachingStepKindInspectRemainder sequence:sequence].count, divides ? 1u : 0u);
                    [self assertFullStory:sequence.wordProblem equals:example.wordProblem];
                    BOOL written = NO, inspected = NO;
                    for (GroupingTeachingStep *step in sequence.steps) {
                        if (step.kind == GroupingTeachingStepKindWriteAnswer) written = YES;
                        if (step.kind == GroupingTeachingStepKindInspectRemainder) inspected = YES;
                        if (!written) XCTAssertNil(step.visibleAnswer);
                        else XCTAssertEqualObjects(step.visibleAnswer, @(example.wordProblem.answer));
                        if (!inspected) XCTAssertNil(step.visibleRemainder);
                        else XCTAssertEqualObjects(step.visibleRemainder, @(example.wordProblem.remainder));
                        if (!predictions.boolValue) XCTAssertNotEqual(step.kind, GroupingTeachingStepKindPredict);
                    }
                    XCTAssertTrue(written);
                }
            } else {
                verticalCount++;
                ArithmeticTeachingSequence *sequence = [ArithmeticTeachingSequence sequenceForProblem:example.problem];
                XCTAssertTrue(sequence.isValid, @"%@ / %@", path.pathID, example.equationText);
                XCTAssertEqual(sequence.steps.firstObject.kind, ArithmeticTeachingStepKindAlignment);
                XCTAssertEqual(sequence.steps.lastObject.kind, ArithmeticTeachingStepKindCompletion);
                BOOL written = NO;
                for (ArithmeticTeachingStep *step in sequence.steps) {
                    if (step.kind == ArithmeticTeachingStepKindWriteAnswer) written = YES;
                    if (!written) {
                        for (id digit in step.visibleAnswerDigits) XCTAssertEqualObjects(digit, [NSNull null]);
                    }
                }
                XCTAssertTrue(written);
            }
        }
    }
    XCTAssertEqual(verticalCount, 10u);
    XCTAssertEqual(groupingCount, 15u);
}

- (void)testCarryAndBorrowExamplesActuallyExerciseTheirAdvertisedRegrouping {
    for (NSString *pathID in @[@"carry", @"borrow"]) {
        NSArray<ConceptLearningExample *> *examples = [self examplesInPath:[self pathWithID:pathID]];
        for (NSUInteger index = 0; index < examples.count; index++) {
            ArithmeticProblem *problem = examples[index].problem;
            ArithmeticTeachingSequence *sequence = [ArithmeticTeachingSequence sequenceForProblem:problem];
            NSUInteger regroups = 0;
            for (ArithmeticTeachingStep *step in sequence.steps) {
                if (step.kind != ArithmeticTeachingStepKindRegroup) continue;
                regroups++;
                if ([pathID isEqualToString:@"carry"]) XCTAssertGreaterThan(step.sourceColumn, step.destinationColumn);
                else XCTAssertLessThan(step.sourceColumn, step.destinationColumn);
            }
            if ([pathID isEqualToString:@"carry"]) {
                XCTAssertEqualObjects(problem.operatorSymbol, @"+");
                NSInteger onesTotal = problem.number1 % 10 + problem.number2 % 10;
                if (index == 2) {
                    XCTAssertEqual(onesTotal, 9);
                    XCTAssertEqual(regroups, 0u, @"The contrast must include a genuine no-carry example.");
                } else {
                    XCTAssertGreaterThanOrEqual(onesTotal, 10);
                    XCTAssertEqual(regroups, 1u);
                }
            } else {
                XCTAssertEqualObjects(problem.operatorSymbol, @"-");
                XCTAssertLessThan(problem.number1 % 10, problem.number2 % 10);
                if (index == 0) XCTAssertEqual(regroups, 1u);
                else {
                    XCTAssertEqual((problem.number1 / 10) % 10, index == 2 ? 1 : 0);
                    XCTAssertEqual(regroups, 2u, @"The 112/102 contrast has two exchanges in different orders.");
                }
            }
        }
    }
}

- (void)testCarryVariationIsolatesOnesTotalsBelowAtAndAboveTen {
    NSArray<ConceptLearningExample *> *choices = [self pathWithID:@"carry"].explorationExamples;
    for (NSUInteger i = 0; i < choices.count; i++) {
        ArithmeticProblem *problem = choices[i].problem;
        XCTAssertEqual(problem.number1, 43);
        XCTAssertEqual(problem.number2, 16 + i);
        XCTAssertEqual(problem.number2 / 10, 1);
        XCTAssertEqual(problem.number1 % 10 + problem.number2 % 10, 9 + i);
        XCTAssertTrue([choices[i].focusText containsString:@"43 不變"]);
        XCTAssertTrue([choices[i].focusText containsString:@"9、10、11"]);
        XCTAssertTrue([choices[i].focusText containsString:@"哪一次"]);
    }
}

- (void)testBorrowContrastChangesOnlyTensAndKeepsBothExchangeOrdersInspectable {
    NSArray<ConceptLearningExample *> *choices = [self pathWithID:@"borrow"].explorationExamples;
    ArithmeticProblem *ordinary = choices[0].problem, *zero = choices[1].problem;
    XCTAssertEqual(ordinary.number1, 112);
    XCTAssertEqual(zero.number1, 102);
    XCTAssertEqual(ordinary.number1 / 100, zero.number1 / 100);
    XCTAssertEqual(ordinary.number1 % 10, zero.number1 % 10);
    XCTAssertEqual(ordinary.number2, zero.number2);
    XCTAssertTrue([choices[0].focusText containsString:@"只改被減數的十位"]);
    XCTAssertTrue([choices[1].focusText containsString:@"十位是零"]);
    for (NSUInteger i = 0; i < 2; i++) {
        ArithmeticTeachingSequence *sequence = [ArithmeticTeachingSequence sequenceForProblem:choices[i].problem];
        NSMutableArray<ArithmeticTeachingStep *> *exchanges = [NSMutableArray array];
        for (ArithmeticTeachingStep *step in sequence.steps) {
            if (step.kind == ArithmeticTeachingStepKindRegroup) [exchanges addObject:step];
        }
        XCTAssertEqual(exchanges.count, 2u);
        if (exchanges.count != 2) continue;
        XCTAssertEqual(exchanges[0].sourceColumn, i == 0 ? 1 : 0);
        XCTAssertEqual(exchanges[0].destinationColumn, i == 0 ? 2 : 1);
        XCTAssertEqual(exchanges[1].sourceColumn, i == 0 ? 0 : 1);
        XCTAssertEqual(exchanges[1].destinationColumn, i == 0 ? 1 : 2);
        if (i == 1) {
            XCTAssertEqualObjects(exchanges[0].workingDigitsBefore, (@[@1, @0, @2]));
            XCTAssertEqualObjects(exchanges[0].workingDigits, (@[@0, @10, @2]));
            XCTAssertEqualObjects(exchanges[1].workingDigitsBefore, (@[@0, @10, @2]));
            XCTAssertEqualObjects(exchanges[1].workingDigits, (@[@0, @9, @12]));
        }
    }
}

- (void)testCompletionIsActionableWithoutRequiringAnAnswerChoice {
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        for (ConceptLearningExample *example in [self examplesInPath:path]) {
            if (example.wordProblem) {
                GroupingTeachingSequence *sequence = [GroupingTeachingSequence sequenceForWordProblem:example.wordProblem];
                GroupingTeachingStep *completion = sequence.steps.lastObject;
                GroupingTeachingStep *verification = sequence.steps[sequence.steps.count - 2];
                XCTAssertEqual(completion.kind, GroupingTeachingStepKindCompletion);
                XCTAssertEqualObjects(completion.title, @"回頭想一想");
                XCTAssertEqualObjects(completion.explanation, @"可以回到題目，想想每一步為什麼這樣做；也可以重看剛才的步驟。");
                XCTAssertEqualObjects(completion.groupCountsAfter, verification.groupCountsAfter);
                XCTAssertEqualObjects(completion.poolCountAfter, verification.poolCountAfter);
                XCTAssertEqualObjects(completion.visibleAnswer, verification.visibleAnswer);
                XCTAssertEqualObjects(completion.visibleRemainder, verification.visibleRemainder);
            } else {
                ArithmeticTeachingStep *completion = [ArithmeticTeachingSequence sequenceForProblem:example.problem].steps.lastObject;
                XCTAssertEqual(completion.kind, ArithmeticTeachingStepKindCompletion);
                XCTAssertEqualObjects(completion.title, @"把每一位連起來");
                XCTAssertFalse([completion.explanation containsString:@"選出答案"]);
                XCTAssertFalse([completion.explanation containsString:@"選項"]);
                XCTAssertTrue([completion.explanation containsString:@"可以回到題目，也可以重看"]);
                XCTAssertFalse([completion.explanation containsString:@"每一步交換"],
                    @"A no-carry example must not imply that an exchange took place.");
            }
        }
    }
}

- (void)testMultiplicationKeepsFirstOperandAsGroupSizeAndSecondAsGroupCount {
    ConceptLearningPath *path = [self pathWithID:@"equal-groups"];
    for (ConceptLearningExample *example in [self examplesInPath:path]) {
        WordProblem *story = example.wordProblem;
        XCTAssertEqual(story.groupingContext.meaning, GroupingStoryMeaningBuildEqualGroups);
        XCTAssertEqualObjects(story.unit, @"顆");
        XCTAssertEqualObjects(story.groupingContext.groupName, @"包");
        XCTAssertEqual(story.answer, story.number1 * story.number2);
        XCTAssertEqual(story.remainder, 0);
        GroupingTeachingSequence *sequence = [GroupingTeachingSequence sequenceForWordProblem:story];
        NSArray<GroupingTeachingStep *> *builds = [self groupingSteps:GroupingTeachingStepKindBuildGroup sequence:sequence];
        XCTAssertEqual(builds.count, (NSUInteger)story.number2);
        XCTAssertEqual(sequence.steps.firstObject.groupCountsAfter.count, 0u);
        XCTAssertEqualObjects(sequence.steps.firstObject.unopenedGroupCount, @(story.number2));
        for (GroupingTeachingStep *step in builds) {
            XCTAssertEqual(step.transferCount, story.number1);
            XCTAssertEqual(step.groupCountsAfter.count, step.groupCountsBefore.count + 1);
            XCTAssertNil(step.poolCountBefore);
            XCTAssertNil(step.poolCountAfter);
        }
        XCTAssertEqual(sequence.steps.lastObject.groupCountsAfter.count, (NSUInteger)story.number2);
        for (NSNumber *count in sequence.steps.lastObject.groupCountsAfter) XCTAssertEqual(count.integerValue, story.number1);
    }
    // Same product, intentionally different concrete models: 4 × 3 is not four groups of three.
    GroupingTeachingSequence *fourByThree = [GroupingTeachingSequence sequenceForWordProblem:path.explorationExamples[0].wordProblem];
    GroupingTeachingSequence *threeByFour = [GroupingTeachingSequence sequenceForWordProblem:path.explorationExamples[1].wordProblem];
    XCTAssertEqualObjects(fourByThree.steps.lastObject.groupCountsAfter, (@[@4, @4, @4]));
    XCTAssertEqualObjects(threeByFour.steps.lastObject.groupCountsAfter, (@[@3, @3, @3, @3]));
}

- (void)testSameDivisionOperandsRetainDistinctSharingAndPackingQuestionsAndUnits {
    NSArray<ConceptLearningExample *> *sharing = [self examplesInPath:[self pathWithID:@"sharing"]];
    NSArray<ConceptLearningExample *> *packing = [self examplesInPath:[self pathWithID:@"packing"]];
    XCTAssertEqual(sharing.count, packing.count);
    if (sharing.count != packing.count) return;
    for (NSUInteger index = 0; index < sharing.count; index++) {
        WordProblem *share = sharing[index].wordProblem, *pack = packing[index].wordProblem;
        XCTAssertNotNil(share.groupingContext);
        XCTAssertNotNil(pack.groupingContext);
        XCTAssertEqual(share.groupingContext.meaning, GroupingStoryMeaningShareEqually);
        XCTAssertEqual(pack.groupingContext.meaning, GroupingStoryMeaningMakeGroupsOf);
        XCTAssertEqual(share.number1, pack.number1);
        XCTAssertEqual(share.number2, pack.number2);
        XCTAssertEqual(share.answer, pack.answer);
        XCTAssertEqual(share.remainder, pack.remainder);
        XCTAssertEqual(share.answer * share.number2 + share.remainder, share.number1);
        XCTAssertGreaterThanOrEqual(share.remainder, 0);
        XCTAssertLessThan(share.remainder, share.number2);
        XCTAssertEqualObjects(share.unit, @"顆");
        XCTAssertEqualObjects(pack.unit, @"包");
        XCTAssertEqualObjects(share.groupingContext.answerUnit, share.unit);
        XCTAssertEqualObjects(pack.groupingContext.answerUnit, pack.unit);
        XCTAssertEqualObjects(share.groupingContext.groupName, @"個小朋友");
        XCTAssertEqualObjects(pack.groupingContext.groupName, @"包");
        XCTAssertEqualObjects(share.groupingContext.leftoverUnit, @"顆");
        XCTAssertEqualObjects(pack.groupingContext.leftoverUnit, @"顆");
        XCTAssertNotEqualObjects(sharing[index].questionText, packing[index].questionText);
        XCTAssertEqualObjects(sharing[index].equationText, packing[index].equationText);
        GroupingTeachingSequence *shareSequence = [GroupingTeachingSequence sequenceForWordProblem:share];
        GroupingTeachingSequence *packSequence = [GroupingTeachingSequence sequenceForWordProblem:pack];
        XCTAssertEqual(shareSequence.steps.firstObject.groupCountsAfter.count, (NSUInteger)share.number2);
        XCTAssertEqual(packSequence.steps.firstObject.groupCountsAfter.count, 0u);
        XCTAssertEqual([self groupingSteps:GroupingTeachingStepKindShareRound sequence:shareSequence].count, (NSUInteger)share.answer);
        XCTAssertEqual([self groupingSteps:GroupingTeachingStepKindPackGroup sequence:shareSequence].count, 0u);
        XCTAssertEqual([self groupingSteps:GroupingTeachingStepKindPackGroup sequence:packSequence].count, (NSUInteger)pack.answer);
        XCTAssertEqual([self groupingSteps:GroupingTeachingStepKindShareRound sequence:packSequence].count, 0u);
        XCTAssertEqual(shareSequence.steps.lastObject.groupCountsAfter.count, (NSUInteger)share.number2);
        XCTAssertEqual(packSequence.steps.lastObject.groupCountsAfter.count, (NSUInteger)pack.answer);
        for (NSNumber *count in shareSequence.steps.lastObject.groupCountsAfter) XCTAssertEqual(count.integerValue, share.answer);
        for (NSNumber *count in packSequence.steps.lastObject.groupCountsAfter) XCTAssertEqual(count.integerValue, pack.number2);
        XCTAssertEqualObjects(shareSequence.steps.lastObject.poolCountAfter, @(share.remainder));
        XCTAssertEqualObjects(packSequence.steps.lastObject.poolCountAfter, @(pack.remainder));
        GroupingTeachingStep *shareWrite = [self groupingSteps:GroupingTeachingStepKindWriteAnswer sequence:shareSequence].firstObject;
        GroupingTeachingStep *packWrite = [self groupingSteps:GroupingTeachingStepKindWriteAnswer sequence:packSequence].firstObject;
        NSString *shareAnswer = [NSString stringWithFormat:@"每個小朋友分到的糖果最多有 %ld 顆。", (long)share.answer];
        NSString *packAnswer = [NSString stringWithFormat:@"可以分成 %ld 包。", (long)pack.answer];
        XCTAssertTrue([shareWrite.explanation hasPrefix:shareAnswer]);
        XCTAssertTrue([packWrite.explanation hasPrefix:packAnswer]);
        if (index == 0) XCTAssertEqual(share.remainder, 0);
        else {
            XCTAssertGreaterThan(share.remainder, 0);
            NSString *leftovers = [NSString stringWithFormat:@"另外共同剩下的糖果有 %ld 顆。", (long)share.remainder];
            XCTAssertTrue([shareWrite.explanation hasSuffix:leftovers]);
            XCTAssertTrue([packWrite.explanation hasSuffix:leftovers]);
        }
    }
}

- (void)testCurrentQuestionAndEquationNeverContainWorkedAnswers {
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        for (ConceptLearningExample *example in [self examplesInPath:path]) {
            ArithmeticProblem *problem = example.problem;
            NSString *symbol = [problem.operatorSymbol isEqualToString:@"-"] ? @"−" : problem.operatorSymbol;
            NSString *unanswered = [NSString stringWithFormat:@"%ld %@ %ld = ?", (long)problem.number1, symbol, (long)problem.number2];
            XCTAssertEqualObjects(example.equationText, unanswered);
            WordProblem *story = example.wordProblem;
            if (!story) {
                XCTAssertEqualObjects(example.questionText, @"這一題可以怎麼算？先想一想，再看每一小步。");
                continue;
            }
            XCTAssertEqualObjects(example.equationText, [story equationTextRevealingAnswer:NO]);
            XCTAssertNotEqualObjects(example.equationText, [story equationTextRevealingAnswer:YES]);
            XCTAssertEqualObjects(example.questionText, story.storyText);
            XCTAssertEqualObjects(example.focusText, [story strategyHintText]);
            // Match quantity roles, not numeric substrings: a given operand may equal the answer.
            NSString *expectedQuestion;
            if (story.groupingContext.meaning == GroupingStoryMeaningBuildEqualGroups) {
                expectedQuestion = [NSString stringWithFormat:@"每包有 %ld 顆糖果，有 %ld 包一樣多的糖果。一共有幾顆糖果？", (long)story.number1, (long)story.number2];
            } else if (story.groupingContext.meaning == GroupingStoryMeaningShareEqually) {
                expectedQuestion = [NSString stringWithFormat:@"把 %ld 顆糖果平均分給 %ld 個小朋友，每人分到一樣多的整顆糖果。每人最多分到幾顆？還剩幾顆？", (long)story.number1, (long)story.number2];
            } else {
                expectedQuestion = [NSString stringWithFormat:@"有 %ld 顆糖果，每 %ld 顆裝成一包。最多裝滿幾包？還剩幾顆？", (long)story.number1, (long)story.number2];
            }
            XCTAssertEqualObjects(example.questionText, expectedQuestion);
            XCTAssertFalse([example.focusText containsString:@"答案："]);
            XCTAssertFalse([example.focusText containsString:@" = "]);
        }
    }
}

- (void)testEveryArithmeticReadIsIsolatedFromTheCatalogAndFullStory {
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        for (ConceptLearningExample *example in [self examplesInPath:path]) {
            ArithmeticProblem *original = example.problem;
            ArithmeticProblem *editable = example.problem;
            WordProblem *story = example.wordProblem;
            NSString *question = [example.questionText copy], *equation = [example.equationText copy];
            XCTAssertNotEqual(original, editable);
            editable.number1 = 99999;
            editable.number2 = 0;
            editable.operatorSymbol = @"/";
            editable.answer = -1;
            editable.auxiliaryDistractor = 999;
            editable.isMultiStep = YES;
            [self assertProblem:example.problem equals:original];
            XCTAssertEqualObjects(example.questionText, question);
            XCTAssertEqualObjects(example.equationText, equation);
            if (story) {
                GroupingTeachingSequence *sequence = [GroupingTeachingSequence sequenceForWordProblem:story];
                XCTAssertTrue(sequence.isSupported);
                XCTAssertNotEqual(sequence.wordProblem, story);
                [self assertFullStory:sequence.wordProblem equals:story];
                [self assertFullStory:example.wordProblem equals:story];
                XCTAssertEqual(story.number1, original.number1);
                XCTAssertEqual(story.number2, original.number2);
                XCTAssertEqual(story.answer, original.answer);
                XCTAssertEqualObjects(story.operatorSymbol, original.operatorSymbol);
                XCTAssertEqualObjects(story.storyText, question);
            } else {
                XCTAssertTrue([ArithmeticTeachingSequence sequenceForProblem:example.problem].isValid);
            }
        }
    }
}

- (void)testStoryArithmeticSnapshotsPreserveBridgeMetadata {
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        for (ConceptLearningExample *example in [self examplesInPath:path]) {
            if (!example.wordProblem) continue;
            // Even though concept paths do not score answers, copying a snapshot must not
            // silently discard the bridge's auxiliary remainder or multi-step metadata.
            [self assertProblem:example.problem equals:[example.wordProblem toArithmeticProblem]];
        }
    }
}

- (void)testConceptCatalogDoesNotReplaceOrReorderExistingL1ThroughL5Lessons {
    (void)[ConceptLearningPath allPaths];
    NSArray<Lesson *> *lessons = [LessonCatalog addSubLessons];
    XCTAssertEqualObjects([lessons valueForKey:@"lessonID"], (@[@"L1", @"L2", @"L3", @"L4", @"L5"]));
    XCTAssertEqualObjects([lessons valueForKey:@"title"], (@[@"5 以內加法", @"10 以內加法", @"10 以內減法", @"合十法（進位加）", @"破十法（退位減）"]));
    XCTAssertEqualObjects([lessons valueForKey:@"questionCount"], (@[@10, @10, @10, @10, @10]));
    XCTAssertEqualObjects([lessons valueForKey:@"kind"], (@[@(LessonKindAddSimple), @(LessonKindAddSimple), @(LessonKindSubSimple), @(LessonKindMakeTen), @(LessonKindBreakTen)]));
    for (Lesson *lesson in lessons) XCTAssertEqual(lesson.multiplicationFactor, 0);
}

@end
