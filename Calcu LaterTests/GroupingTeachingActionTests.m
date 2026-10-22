#import <XCTest/XCTest.h>
#import "GroupingTeachingAction.h"
#import "WordProblem.h"

@interface GroupingTeachingActionTests : XCTestCase @end
@implementation GroupingTeachingActionTests
- (GroupingTeachingSequence *)sequence:(NSInteger)total divisor:(NSInteger)divisor sharing:(BOOL)sharing {
    GroupingStoryContext *context = [[GroupingStoryContext alloc] initWithMeaning:sharing ? GroupingStoryMeaningShareEqually : GroupingStoryMeaningMakeGroupsOf
        itemName:@"糖果" itemUnit:@"顆" groupName:sharing ? @"個小朋友" : @"包" answerUnit:sharing ? @"顆" : @"包"];
    WordProblem *story = [[WordProblem alloc] initWithStory:@"這是原來完整的分糖果故事。" templateID:@"focused-story" grade:3
        number1:total number2:divisor operator:@"÷" answer:total / divisor unit:context.answerUnit
        missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:total % divisor number3:0 operator2:nil intermediate:0
        isFractionAnswer:NO answerNumerator:0 answerDenominator:0 groupingContext:context strategyText:@"故事規則不能變。"];
    return [GroupingTeachingSequence sequenceForWordProblem:story];
}
- (NSInteger)indexOf:(GroupingTeachingStepKind)kind sequence:(GroupingTeachingSequence *)sequence {
    for (NSInteger i = 0; i < (NSInteger)sequence.steps.count; i++) if (sequence.steps[i].kind == kind) return i;
    return NSNotFound;
}
- (void)assertIdentities:(NSArray<NSArray<NSNumber *> *> *)groups counts:(NSArray<NSNumber *> *)counts pool:(NSInteger)pool total:(NSInteger)total {
    XCTAssertEqual(groups.count, counts.count);
    NSMutableSet *identities = [NSMutableSet set];
    for (NSInteger identity = 0; identity < pool; identity++) [identities addObject:@(identity)];
    NSInteger sum = pool;
    for (NSInteger group = 0; group < (NSInteger)groups.count; group++) {
        XCTAssertEqual(groups[group].count, counts[group].unsignedIntegerValue);
        for (NSNumber *identity in groups[group]) {
            XCTAssertFalse([identities containsObject:identity]);
            XCTAssertGreaterThanOrEqual(identity.integerValue, 0); XCTAssertLessThan(identity.integerValue, total);
            [identities addObject:identity]; sum++;
        }
    }
    XCTAssertEqual(sum, total); XCTAssertEqual(identities.count, (NSUInteger)total);
}
- (void)testSharingActionsContinuouslyDistributeOneEachWithoutChangingStory {
    GroupingTeachingSequence *sequence = [self sequence:23 divisor:4 sharing:YES];
    NSInteger index = [self indexOf:GroupingTeachingStepKindShareRound sequence:sequence];
    GroupingTeachingStep *original = sequence.steps[index];
    NSArray<GroupingTeachingAction *> *actions = [GroupingTeachingAction focusedActionsForSequence:sequence stepIndex:index];
    XCTAssertEqual(actions.count, 4u);
    for (NSInteger i = 0; i < 4; i++) {
        GroupingTeachingAction *action = actions[i];
        XCTAssertEqual(action.sequence, sequence); XCTAssertEqual(action.actionIndex, i);
        XCTAssertEqual(action.actionCount, 4); XCTAssertEqual(action.isRoundComplete, i == 3);
        XCTAssertEqual(action.snapshot.poolCountBefore.integerValue, 23 - i);
        XCTAssertEqual(action.snapshot.poolCountAfter.integerValue, 22 - i);
        XCTAssertEqual(action.snapshot.transferCount, 1);
        XCTAssertEqualObjects(action.snapshot.activeGroupIndices, @[@(i)]);
        for (NSInteger group = 0; group < 4; group++) XCTAssertEqual(action.snapshot.groupCountsAfter[group].integerValue, group <= i ? 1 : 0);
        [self assertIdentities:action.groupIdentitiesBefore counts:action.snapshot.groupCountsBefore pool:23 - i total:23];
        [self assertIdentities:action.groupIdentitiesAfter counts:action.snapshot.groupCountsAfter pool:22 - i total:23];
        XCTAssertTrue(([action.progressText containsString:[NSString stringWithFormat:@"第 %ld / 4 位", (long)i + 1]]));
        XCTAssertTrue([action.snapshot.explanation containsString:@"每個小朋友只再拿 1 顆"]);
        XCTAssertNil(action.snapshot.visibleAnswer); XCTAssertNil(action.snapshot.visibleRemainder);
    }
    XCTAssertEqualObjects(original.groupCountsBefore, (@[@0, @0, @0, @0]));
    XCTAssertEqualObjects(original.groupCountsAfter, (@[@1, @1, @1, @1]));
    XCTAssertEqualObjects(original.poolCountAfter, @19);
    XCTAssertEqualObjects(sequence.wordProblem.storyText, @"這是原來完整的分糖果故事。");
    XCTAssertEqual(sequence.context.meaning, GroupingStoryMeaningShareEqually);
    XCTAssertTrue([actions.lastObject.snapshot.explanation containsString:original.explanation]);
}
- (void)testPackingCreatesOneCompleteBagAndRetainsAllEarlierIdentities {
    GroupingTeachingSequence *sequence = [self sequence:23 divisor:4 sharing:NO];
    NSUInteger seen = 0; NSArray *previous = @[];
    for (NSInteger index = 0; index < (NSInteger)sequence.steps.count; index++) {
        if (sequence.steps[index].kind != GroupingTeachingStepKindPackGroup) continue;
        NSArray<GroupingTeachingAction *> *actions = [GroupingTeachingAction focusedActionsForSequence:sequence stepIndex:index];
        XCTAssertEqual(actions.count, 1u); GroupingTeachingAction *action = actions.firstObject;
        XCTAssertTrue(action.isRoundComplete); XCTAssertEqual(action.snapshot.transferCount, 4);
        XCTAssertEqual(action.groupIdentitiesBefore.count, seen);
        XCTAssertEqual(action.groupIdentitiesAfter.count, seen + 1);
        XCTAssertEqualObjects(action.groupIdentitiesBefore, previous);
        XCTAssertEqualObjects(action.snapshot.poolCountAfter, @(23 - 4 * (seen + 1)));
        XCTAssertTrue(([action.progressText containsString:[NSString stringWithFormat:@"第 %ld 包", (long)seen + 1]]));
        [self assertIdentities:action.groupIdentitiesAfter counts:action.snapshot.groupCountsAfter pool:action.snapshot.poolCountAfter.integerValue total:23];
        previous = action.groupIdentitiesAfter; seen++;
    }
    XCTAssertEqual(seen, 5u); XCTAssertEqual(sequence.context.meaning, GroupingStoryMeaningMakeGroupsOf);
}
- (void)testEverySupportedSmallDivisionConservesOriginalIdentityPartitions {
    for (NSInteger total = 0; total <= 90; total++) for (NSInteger divisor = 1; divisor <= 10; divisor++) for (NSNumber *sharing in @[@YES, @NO]) {
        GroupingTeachingSequence *sequence = [self sequence:total divisor:divisor sharing:sharing.boolValue];
        if (!sequence.isSupported) continue;
        for (NSInteger index = 0; index < (NSInteger)sequence.steps.count; index++) {
            GroupingTeachingStep *original = sequence.steps[index];
            NSArray<GroupingTeachingAction *> *actions = [GroupingTeachingAction focusedActionsForSequence:sequence stepIndex:index];
            if (!actions.count) continue;
            NSArray *unchangedBefore = [original.groupCountsBefore copy], *unchangedAfter = [original.groupCountsAfter copy];
            GroupingTeachingAction *previous = nil;
            for (GroupingTeachingAction *action in actions) {
                [self assertIdentities:action.groupIdentitiesBefore counts:action.snapshot.groupCountsBefore pool:action.snapshot.poolCountBefore.integerValue total:total];
                [self assertIdentities:action.groupIdentitiesAfter counts:action.snapshot.groupCountsAfter pool:action.snapshot.poolCountAfter.integerValue total:total];
                XCTAssertEqual(action.snapshot.poolCountBefore.integerValue - action.snapshot.poolCountAfter.integerValue, action.snapshot.transferCount);
                XCTAssertNil(action.snapshot.visibleAnswer);
                if (previous) {
                    XCTAssertEqualObjects(previous.groupIdentitiesAfter, action.groupIdentitiesBefore);
                    XCTAssertEqualObjects(previous.snapshot.poolCountAfter, action.snapshot.poolCountBefore);
                }
                previous = action;
            }
            GroupingTeachingAction *full = [GroupingTeachingAction fullActionForSequence:sequence stepIndex:index];
            XCTAssertEqual(full.snapshot, original); XCTAssertTrue(full.isFullAction); XCTAssertTrue(full.isRoundComplete);
            XCTAssertEqualObjects(full.groupIdentitiesBefore, actions.firstObject.groupIdentitiesBefore);
            XCTAssertEqualObjects(full.groupIdentitiesAfter, actions.lastObject.groupIdentitiesAfter);
            XCTAssertEqualObjects(original.groupCountsBefore, unchangedBefore); XCTAssertEqualObjects(original.groupCountsAfter, unchangedAfter);
        }
    }
}
- (void)testReplayAndPreviousSelectionReturnIdenticalRecords {
    GroupingTeachingSequence *sequence = [self sequence:23 divisor:4 sharing:YES];
    NSArray *first = [GroupingTeachingAction focusedActionsForSequence:sequence stepIndex:2];
    [GroupingTeachingAction focusedActionsForSequence:sequence stepIndex:10];
    NSArray *again = [GroupingTeachingAction focusedActionsForSequence:sequence stepIndex:2];
    for (NSUInteger index = 0; index < first.count; index++) {
        GroupingTeachingAction *a = first[index], *b = again[index];
        XCTAssertEqualObjects(a.groupIdentitiesBefore, b.groupIdentitiesBefore); XCTAssertEqualObjects(a.groupIdentitiesAfter, b.groupIdentitiesAfter);
        XCTAssertEqualObjects(a.snapshot.poolCountAfter, b.snapshot.poolCountAfter);
    }
}
- (void)testUnsupportedNontransformingAndMultiplicationInputsHaveNoDivisionActions {
    GroupingTeachingSequence *zero = [self sequence:3 divisor:4 sharing:YES];
    for (NSInteger index = 0; index < (NSInteger)zero.steps.count; index++) XCTAssertEqual([GroupingTeachingAction focusedActionsForSequence:zero stepIndex:index].count, 0u);
    GroupingTeachingSequence *outside = [self sequence:91 divisor:9 sharing:YES];
    XCTAssertNil([GroupingTeachingAction fullActionForSequence:outside stepIndex:2]);
    XCTAssertNil([GroupingTeachingAction fullActionForSequence:zero stepIndex:NSNotFound]);
    ArithmeticProblem *problem = [[ArithmeticProblem alloc] initWithNumber1:3 number2:4 operator:@"×" answer:12];
    GroupingTeachingSequence *multiply = [GroupingTeachingSequence sequenceForArithmeticProblem:problem meaning:GroupingStoryMeaningBuildEqualGroups];
    for (NSInteger index = 0; index < (NSInteger)multiply.steps.count; index++) XCTAssertNil([GroupingTeachingAction fullActionForSequence:multiply stepIndex:index]);
}
- (void)testWrongCountCoachingUsesChosenUnitAndActualCurrentQuantities {
    GroupingTeachingSequence *share = [self sequence:23 divisor:4 sharing:YES], *pack = [self sequence:23 divisor:4 sharing:NO];
    NSString *sharing = [GroupingPredictionFeedback feedbackForSequence:share stepIndex:1 chosenValue:2];
    for (NSString *phrase in @[@"你選 2 顆", @"現在有 0 顆", @"只再拿 1 顆", @"共同待分還有 23 顆"]) XCTAssertTrue([sharing containsString:phrase]);
    NSString *packing = [GroupingPredictionFeedback feedbackForSequence:pack stepIndex:1 chosenValue:2];
    for (NSString *phrase in @[@"你選 2 包", @"現在有 0 包", @"待分區有 23 顆", @"再拿 4 顆", @"只會多 1 包"]) XCTAssertTrue([packing containsString:phrase]);
    XCTAssertNil(share.steps[1].visibleAnswer); XCTAssertNil(pack.steps[1].visibleAnswer);
    XCTAssertFalse([sharing containsString:@"答案是 5"]); XCTAssertFalse([packing containsString:@"答案是 5"]);
}
- (void)testWrongContinuationExplainsFairSharingVersusCompleteBag {
    for (NSNumber *sharing in @[@YES, @NO]) {
        GroupingTeachingSequence *sequence = [self sequence:23 divisor:4 sharing:sharing.boolValue];
        for (NSInteger index = 0; index < (NSInteger)sequence.steps.count; index++) {
            if (sequence.steps[index].predictionKind != GroupingTeachingPredictionKindCanContinue) continue;
            NSString *feedback = [GroupingPredictionFeedback feedbackForSequence:sequence stepIndex:index chosenValue:1];
            for (NSString *phrase in @[@"你選「還可以」", @"只有 3 顆", @"要 4 顆", @"還差 1 顆"]) XCTAssertTrue([feedback containsString:phrase]);
            XCTAssertTrue([feedback containsString:sharing.boolValue ? @"沒有讓每位都再拿 1 顆" : @"不完整的一組還不能算一組"]);
            NSString *correct = [GroupingPredictionFeedback feedbackForSequence:sequence stepIndex:index chosenValue:0];
            XCTAssertTrue([correct containsString:@"你選「不夠了」"]); XCTAssertTrue([correct containsString:@"不計分"]);
            XCTAssertNil(sequence.steps[index].visibleAnswer);
        }
    }
}
@end
