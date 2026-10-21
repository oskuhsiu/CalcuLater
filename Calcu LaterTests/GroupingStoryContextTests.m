#import <XCTest/XCTest.h>
#import "GroupingStoryContext.h"
#import "WordProblem.h"
#import "WordProblemTemplate.h"
#import "WordProblemGenerator.h"
#import "ArithmeticProblem.h"

// Exercise the real generator with one template; no probabilistic catalog coverage.
@interface WordProblemGenerator (GroupingCatalogTesting)
+ (WordProblem *)generateOnceFromTemplates:(NSArray<WordProblemTemplate *> *)templates
                                     grade:(NSInteger)grade excluding:(nullable NSString *)lastTemplateID;
@end

@interface GroupingStoryContextTests : XCTestCase
@end

@implementation GroupingStoryContextTests

// Independent reviewed inventory: meaning, item name/unit, group noun, original numeric domain.
// A new ×/÷ catalog record MUST be explicitly classified here rather than silently inheriting a route.
- (NSDictionary<NSString *, NSArray *> *)groupingInventory {
    return @{
        @"g2_mul_dumpling": @[@(GroupingStoryMeaningBuildEqualGroups), @"水餃", @"個", @"盤", @[@2, @9, @2, @9]],
        @"g2_mul_row": @[@(GroupingStoryMeaningBuildEqualGroups), @"學生", @"個", @"排", @[@2, @9, @2, @9]],
        @"g2_mul_day_page": @[@(GroupingStoryMeaningBuildEqualGroups), @"書", @"頁", @"天", @[@2, @9, @2, @9]],
        @"g2_mul_legs_dog": @[@(GroupingStoryMeaningBuildEqualGroups), @"腿", @"條", @"隻狗", @[@4, @4, @2, @9]],
        @"g2_mul_flower": @[@(GroupingStoryMeaningBuildEqualGroups), @"花", @"朵", @"束", @[@3, @9, @2, @9]],
        @"g2_mul_candy": @[@(GroupingStoryMeaningBuildEqualGroups), @"糖果", @"顆", @"盒", @[@4, @9, @2, @9]],
        @"g2_mul_basket": @[@(GroupingStoryMeaningBuildEqualGroups), @"蘋果", @"顆", @"籃", @[@4, @9, @2, @9]],
        @"g2_mul_wheel": @[@(GroupingStoryMeaningBuildEqualGroups), @"輪子", @"個", @"台車", @[@3, @4, @2, @9]],
        @"g2_mul_finger": @[@(GroupingStoryMeaningBuildEqualGroups), @"手指", @"根", @"隻手", @[@5, @5, @2, @9]],
        @"g2_mul_packet": @[@(GroupingStoryMeaningBuildEqualGroups), @"餅乾", @"塊", @"包", @[@3, @9, @2, @9]],
        @"g2_mul_egg_box": @[@(GroupingStoryMeaningBuildEqualGroups), @"雞蛋", @"顆", @"盒", @[@6, @9, @2, @9]],
        @"g2_mul_chair": @[@(GroupingStoryMeaningBuildEqualGroups), @"椅子", @"把", @"張桌子", @[@2, @6, @2, @9]],
        @"g2_mul_jiaozi": @[@(GroupingStoryMeaningBuildEqualGroups), @"貢丸", @"顆", @"碗麵", @[@2, @5, @2, @9]],
        @"g3_mul_class_size": @[@(GroupingStoryMeaningBuildEqualGroups), @"學生", @"個", @"班", @[@20, @35, @3, @9]],
        @"g3_mul_box": @[@(GroupingStoryMeaningBuildEqualGroups), @"巧克力", @"顆", @"盒", @[@12, @30, @3, @9]],
        @"g3_mul_seat": @[@(GroupingStoryMeaningBuildEqualGroups), @"座位", @"個", @"排", @[@15, @30, @4, @9]],
        @"g3_mul_school3": @[@(GroupingStoryMeaningBuildEqualGroups), @"蘋果", @"顆", @"箱", @[@105, @320, @3, @9]],
        @"g3_mul_pages3": @[@(GroupingStoryMeaningBuildEqualGroups), @"書", @"頁", @"天", @[@35, @120, @3, @9]],
        @"g3_mul_factory3": @[@(GroupingStoryMeaningBuildEqualGroups), @"玩具", @"個", @"天", @[@105, @320, @3, @9]],
        @"g3_div_share_candy": @[@(GroupingStoryMeaningShareEqually), @"糖果", @"顆", @"個小朋友", @[@12, @81, @2, @9]],
        @"g3_div_pack": @[@(GroupingStoryMeaningMakeGroupsOf), @"糖果", @"顆", @"包", @[@12, @81, @2, @9]],
        @"g3_div_group": @[@(GroupingStoryMeaningShareEqually), @"學生", @"個", @"組", @[@12, @81, @2, @9]],
        @"g3_div_plate": @[@(GroupingStoryMeaningMakeGroupsOf), @"水餃", @"顆", @"盤", @[@12, @81, @2, @9]],
        @"g3_div_row": @[@(GroupingStoryMeaningShareEqually), @"座位", @"個", @"排", @[@12, @81, @2, @9]],
        @"g3_div_big_share": @[@(GroupingStoryMeaningShareEqually), @"產品", @"個", @"個箱子", @[@60, @360, @2, @9]],
        @"g3_div_big_pack": @[@(GroupingStoryMeaningMakeGroupsOf), @"水果", @"顆", @"袋", @[@60, @360, @3, @9]],
        @"g3_rem_share_candy": @[@(GroupingStoryMeaningShareEqually), @"糖果", @"顆", @"個小朋友", @[@13, @79, @3, @9]],
        @"g3_rem_pack": @[@(GroupingStoryMeaningMakeGroupsOf), @"糖果", @"顆", @"包", @[@13, @79, @3, @9]],
        @"g3_rem_plate": @[@(GroupingStoryMeaningMakeGroupsOf), @"水餃", @"顆", @"盤", @[@13, @79, @3, @9]],
        @"g3_rem_team": @[@(GroupingStoryMeaningMakeGroupsOf), @"球員", @"人", @"隊", @[@13, @79, @3, @9]],
        @"g3_rem_seat": @[@(GroupingStoryMeaningMakeGroupsOf), @"學生", @"人", @"排", @[@13, @79, @3, @9]],
        @"g3_rem_box_big": @[@(GroupingStoryMeaningMakeGroupsOf), @"零件", @"個", @"盒", @[@50, @280, @3, @9]],
    };
}

- (NSDictionary<NSString *, NSArray<NSNumber *> *> *)textOnlyInventory {
    return @{
        @"g2_mul_age": @[@2, @5, @3, @9],
        @"g2_mul_price_pen": @[@5, @9, @2, @9],
        @"g2_mul_price_snack": @[@6, @9, @2, @9],
        @"g3_mul_multiple": @[@15, @45, @3, @9],
        @"g3_mul_bag": @[@12, @25, @3, @9],
        @"g3_mul_ticket3": @[@120, @280, @3, @8],
        @"g3_mul_week_day": @[@3, @25, @7, @7],
        @"g3_mul_hour_min": @[@2, @9, @60, @60],
        @"g3_mul_min_sec": @[@2, @9, @60, @60],
        @"g3_mul_m_cm": @[@2, @9, @100, @100],
        @"g3_mul_kg_g": @[@2, @9, @1000, @1000],
        @"g3_mul_l_ml": @[@2, @9, @1000, @1000],
        @"g3_mul_km_m": @[@2, @9, @1000, @1000],
        @"g3_mul_dozen": @[@2, @9, @12, @12],
        @"g3_div_multiple": @[@12, @81, @2, @9],
        @"g3_div_min_hour": @[@60, @540, @60, @60],
        @"g3_div_cm_m": @[@100, @900, @100, @100],
        @"g3_mul_square_peri": @[@5, @60, @4, @4],
        @"g3_div_avg_page": @[@60, @360, @2, @9],
        @"g3_div_avg_money": @[@60, @360, @2, @9],
    };
}

- (WordProblemTemplate *)templateWithID:(NSString *)templateID {
    for (WordProblemTemplate *t in [WordProblemCatalog allTemplates]) {
        if ([t.templateID isEqualToString:templateID]) return t;
    }
    XCTFail(@"Missing catalog template %@", templateID);
    return nil;
}

- (WordProblem *)generatedProblem:(WordProblemTemplate *)t {
    return [WordProblemGenerator generateOnceFromTemplates:@[t] grade:t.grade excluding:nil];
}

// Fixed operands preserve reviewed metadata and semantic flags, but do not modify production domains.
- (WordProblem *)problemWithID:(NSString *)templateID a:(NSInteger)a b:(NSInteger)b {
    WordProblemTemplate *source = [self templateWithID:templateID];
    WordProblemTemplate *fixed = [[WordProblemTemplate alloc] initWithID:source.templateID grade:source.grade
                                                              operator:source.operatorSymbol pattern:source.storyPattern unit:source.unit
                                                                  minA:a maxA:a minB:b maxB:b
                                                    requireAGreaterEqB:source.requireAGreaterEqualB requireDivisible:source.requireDivisible
                                                         missingAddend:source.missingAddend missingSubtrahend:source.missingSubtrahend
                                                        missingMinuend:source.missingMinuend requireRemainder:source.requireRemainder
                                                             operator2:source.operator2 minC:source.minC maxC:source.maxC isFraction:source.isFraction
                                                       groupingContext:source.groupingContext strategyPattern:source.strategyPattern];
    return [self generatedProblem:fixed];
}

- (void)testEveryMultiplicationAndDivisionCatalogEntryHasAnExplicitReviewedRoute {
    NSDictionary<NSString *, NSArray *> *grouping = [self groupingInventory];
    NSDictionary<NSString *, NSArray<NSNumber *> *> *textOnly = [self textOnlyInventory];
    NSMutableSet<NSString *> *expected = [NSMutableSet setWithArray:grouping.allKeys];
    [expected addObjectsFromArray:textOnly.allKeys];
    XCTAssertEqual(grouping.count, 32u);
    XCTAssertEqual(textOnly.count, 20u);
    XCTAssertEqual(expected.count, 52u);
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSUInteger grade2Multiply = 0, grade3Multiply = 0, exactDivision = 0, remainderDivision = 0;
    NSUInteger builds = 0, shares = 0, packs = 0;
    for (WordProblemTemplate *t in [WordProblemCatalog allTemplates]) {
        BOOL multiply = [t.operatorSymbol isEqualToString:@"×"];
        BOOL divide = [t.operatorSymbol isEqualToString:@"÷"];
        if (!multiply && !divide) {
            XCTAssertNil(t.groupingContext, @"%@ is not a grouping route", t.templateID);
            continue;
        }
        XCTAssertFalse([seen containsObject:t.templateID]);
        [seen addObject:t.templateID];
        XCTAssertTrue([expected containsObject:t.templateID], @"Unreviewed ×/÷ route: %@", t.templateID);
        if (![expected containsObject:t.templateID]) continue;
        XCTAssertGreaterThan(t.strategyPattern.length, 0u, @"%@ needs role-aware text", t.templateID);
        XCTAssertFalse(t.isFraction || t.missingAddend || t.missingSubtrahend || t.missingMinuend);
        XCTAssertNil(t.operator2);
        NSArray<NSNumber *> *actualBounds = @[@(t.minA), @(t.maxA), @(t.minB), @(t.maxB)];
        if (multiply) {
            XCTAssertFalse(t.requireDivisible || t.requireRemainder);
            if (t.grade == 2) grade2Multiply++; else if (t.grade == 3) grade3Multiply++;
        } else {
            XCTAssertNotEqual(t.requireDivisible, t.requireRemainder);
            if (t.requireRemainder) remainderDivision++; else exactDivision++;
        }
        NSArray *record = grouping[t.templateID];
        if (record) {
            GroupingStoryContext *context = t.groupingContext;
            XCTAssertNotNil(context, @"%@", t.templateID);
            XCTAssertEqual(context.meaning, [record[0] integerValue]);
            XCTAssertEqualObjects(context.itemName, record[1]);
            XCTAssertEqualObjects(context.itemUnit, record[2]);
            XCTAssertEqualObjects(context.groupName, record[3]);
            XCTAssertEqualObjects(actualBounds, record[4], @"Numeric domain changed: %@", t.templateID);
            XCTAssertEqualObjects(context.answerUnit, t.unit);
            XCTAssertEqualObjects(context.leftoverUnit, context.itemUnit);
            if (context.meaning == GroupingStoryMeaningBuildEqualGroups) {
                builds++;
                XCTAssertTrue(multiply);
                XCTAssertEqualObjects(context.answerUnit, context.itemUnit);
            } else if (context.meaning == GroupingStoryMeaningShareEqually) {
                shares++;
                XCTAssertTrue(divide);
                XCTAssertEqualObjects(context.answerUnit, context.itemUnit);
            } else {
                packs++;
                XCTAssertTrue(divide);
                XCTAssertEqualObjects(context.answerUnit, context.groupName);
            }
        } else {
            XCTAssertNil(t.groupingContext, @"Text-only story acquired object counters: %@", t.templateID);
            XCTAssertEqualObjects(actualBounds, textOnly[t.templateID]);
        }
    }
    XCTAssertEqualObjects(seen, expected);
    XCTAssertEqual(grade2Multiply, 16u);
    XCTAssertEqual(grade3Multiply, 18u);
    XCTAssertEqual(exactDivision, 12u);
    XCTAssertEqual(remainderDivision, 6u);
    XCTAssertEqual(builds, 19u);
    XCTAssertEqual(shares, 5u);
    XCTAssertEqual(packs, 8u);
}

- (void)testCurrentGroupingDomainsIncludeAllSomeAndNoConcreteInstancesWithoutResampling {
    NSUInteger all = 0, some = 0, none = 0;
    for (NSString *templateID in [self groupingInventory]) {
        WordProblemTemplate *t = [self templateWithID:templateID];
        NSUInteger valid = 0, eligible = 0;
        for (NSInteger a = t.minA; a <= t.maxA; a++) {
            for (NSInteger b = t.minB; b <= t.maxB; b++) {
                NSInteger groupSize, groupCount, total, remainder = 0;
                if (t.groupingContext.meaning == GroupingStoryMeaningBuildEqualGroups) {
                    groupSize = a; groupCount = b; total = a * b;
                } else {
                    if (b <= 0 || a / b < 1) continue;
                    remainder = a % b;
                    if (t.requireDivisible && remainder != 0) continue;
                    if (t.requireRemainder && remainder == 0) continue;
                    BOOL share = t.groupingContext.meaning == GroupingStoryMeaningShareEqually;
                    groupSize = share ? a / b : b;
                    groupCount = share ? b : a / b;
                    total = a;
                }
                valid++;
                if (groupSize <= 10 && groupCount <= 9 && total <= 90 &&
                    groupCount + (remainder > 0 ? 1 : 0) <= 9) eligible++;
            }
        }
        XCTAssertGreaterThan(valid, 0u, @"%@", templateID);
        if (eligible == 0) { none++; XCTAssertTrue([templateID hasPrefix:@"g3_mul_"]); }
        else if (eligible == valid) { all++; XCTAssertTrue([templateID hasPrefix:@"g2_mul_"]); }
        else { some++; XCTAssertEqualObjects(t.operatorSymbol, @"÷"); }
    }
    XCTAssertEqual(all, 13u);
    XCTAssertEqual(some, 13u);
    XCTAssertEqual(none, 6u);
}

- (void)testGeneratorCarriesSnapshotsAndOperandOnlyStrategiesForEveryReviewedTemplate {
    NSMutableSet<NSString *> *expected = [NSMutableSet setWithArray:[self groupingInventory].allKeys];
    [expected addObjectsFromArray:[self textOnlyInventory].allKeys];
    for (NSString *templateID in expected) {
        WordProblemTemplate *t = [self templateWithID:templateID];
        WordProblem *p = [self generatedProblem:t];
        XCTAssertNotNil(p, @"%@", templateID);
        XCTAssertEqualObjects(p.templateID, templateID);
        XCTAssertEqualObjects(p.unit, t.unit);
        if (t.groupingContext) {
            XCTAssertNotNil(p.groupingContext);
            XCTAssertNotEqual(p.groupingContext, t.groupingContext);
            XCTAssertEqual(p.groupingContext.meaning, t.groupingContext.meaning);
            XCTAssertEqualObjects(p.groupingContext.itemName, t.groupingContext.itemName);
            XCTAssertEqualObjects(p.groupingContext.itemUnit, t.groupingContext.itemUnit);
            XCTAssertEqualObjects(p.groupingContext.groupName, t.groupingContext.groupName);
            XCTAssertEqualObjects(p.groupingContext.answerUnit, t.groupingContext.answerUnit);
        } else XCTAssertNil(p.groupingContext);
        NSString *strategy = [t.strategyPattern stringByReplacingOccurrencesOfString:@"{a}"
                                                                          withString:[NSString stringWithFormat:@"%ld", (long)p.number1]];
        strategy = [strategy stringByReplacingOccurrencesOfString:@"{b}" withString:[NSString stringWithFormat:@"%ld", (long)p.number2]];
        strategy = [strategy stringByReplacingOccurrencesOfString:@"{c}" withString:[NSString stringWithFormat:@"%ld", (long)p.number3]];
        XCTAssertEqualObjects(p.strategyText, strategy);
        XCTAssertEqualObjects(p.strategyHintText, strategy);
        XCTAssertFalse([strategy containsString:@"{"] || [strategy containsString:@"}"]);
        XCTAssertFalse([strategy containsString:@"答案："] || [strategy containsString:@" = "]);
        XCTAssertTrue([p.workedExplanationText hasPrefix:[strategy stringByAppendingString:@"\n"]]);
        XCTAssertEqual([p toArithmeticProblem].answer, p.answer);
        if ([p.operatorSymbol isEqualToString:@"×"]) XCTAssertEqual(p.answer, p.number1 * p.number2);
        else {
            XCTAssertEqual(p.answer, p.number1 / p.number2);
            XCTAssertEqual(p.remainder, p.number1 % p.number2);
        }
    }
}

- (void)testLegacyAndCustomInitializersNeverInferMeaningFromKnownIDsOrChineseText {
    NSString *story = @"有 23 顆糖果，每 4 顆裝一包，可以裝成幾包？";
    WordProblem *shortForm = [[WordProblem alloc] initWithStory:story templateID:@"g3_rem_pack" grade:3
                                                      number1:23 number2:4 operator:@"÷" answer:5 unit:@"包"];
    WordProblem *fullForm = [[WordProblem alloc] initWithStory:story templateID:@"g3_rem_pack" grade:3
                                                     number1:23 number2:4 operator:@"÷" answer:5 unit:@"包"
                                              missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:3
                                                    number3:0 operator2:nil intermediate:0 isFractionAnswer:NO
                                            answerNumerator:0 answerDenominator:0];
    WordProblemTemplate *custom = [[WordProblemTemplate alloc] initWithID:@"g3_rem_pack" grade:3 operator:@"÷"
                                                                pattern:story unit:@"包" minA:23 maxA:23 minB:4 maxB:4
                                                  requireAGreaterEqB:NO requireDivisible:NO missingAddend:NO
                                                  missingSubtrahend:NO missingMinuend:NO requireRemainder:YES
                                                          operator2:nil minC:0 maxC:0 isFraction:NO];
    XCTAssertNil(custom.groupingContext);
    XCTAssertNil(custom.strategyPattern);
    NSArray<WordProblem *> *problems = @[shortForm, fullForm, [self generatedProblem:custom]];
    for (WordProblem *p in problems) {
        XCTAssertNil(p.groupingContext);
        XCTAssertNil(p.strategyText);
        XCTAssertGreaterThan(p.strategyHintText.length, 0u);
        XCTAssertFalse([p.strategyHintText containsString:@"5"]);
        XCTAssertFalse([p.strategyHintText containsString:@"3"]);
        XCTAssertFalse([p.workedExplanationText containsString:@"3 顆糖果"]);
    }
}

- (void)testContextCopiesMutableLabelsAndRejectsUnknownOrEmptyMeaning {
    NSMutableString *item = [@"糖果" mutableCopy], *unit = [@"顆" mutableCopy];
    NSMutableString *group = [@"包" mutableCopy], *answer = [@"包" mutableCopy];
    GroupingStoryContext *context = [[GroupingStoryContext alloc] initWithMeaning:GroupingStoryMeaningMakeGroupsOf
                                                                       itemName:item itemUnit:unit groupName:group answerUnit:answer];
    GroupingStoryContext *snapshot = [context copy];
    [item setString:@"鉛筆"]; [unit setString:@"枝"]; [group setString:@"盒"]; [answer setString:@"盒"];
    XCTAssertEqualObjects(context.itemName, @"糖果");
    XCTAssertEqualObjects(snapshot.itemName, @"糖果");
    XCTAssertEqualObjects(snapshot.itemUnit, @"顆");
    XCTAssertEqualObjects(snapshot.groupName, @"包");
    XCTAssertEqualObjects(snapshot.answerUnit, @"包");
    XCTAssertEqualObjects(snapshot.leftoverUnit, @"顆");
    GroupingStoryContext *unknown = [[GroupingStoryContext alloc] initWithMeaning:(GroupingStoryMeaning)99
                                                                       itemName:@"糖果" itemUnit:@"顆" groupName:@"包" answerUnit:@"包"];
    GroupingStoryContext *blank = [[GroupingStoryContext alloc] initWithMeaning:GroupingStoryMeaningMakeGroupsOf
                                                                     itemName:@" \n" itemUnit:@"顆" groupName:@"包" answerUnit:@"包"];
    XCTAssertNil(unknown);
    XCTAssertNil(blank);
}

- (void)testProblemAndTemplateCopyStrategyStringsWithoutPublicMutation {
    NSMutableString *strategy = [@"每 4 顆裝一包，數一數能裝成幾包。" mutableCopy];
    GroupingStoryContext *context = [self templateWithID:@"g3_rem_pack"].groupingContext;
    WordProblem *p = [[WordProblem alloc] initWithStory:@"測試" templateID:@"custom" grade:3
                                              number1:23 number2:4 operator:@"÷" answer:5 unit:@"包"
                                       missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:3
                                             number3:0 operator2:nil intermediate:0 isFractionAnswer:NO
                                     answerNumerator:0 answerDenominator:0 groupingContext:context strategyText:strategy];
    WordProblemTemplate *t = [[WordProblemTemplate alloc] initWithID:@"custom" grade:3 operator:@"÷"
                                                            pattern:@"測試" unit:@"包" minA:23 maxA:23 minB:4 maxB:4
                                              requireAGreaterEqB:NO requireDivisible:NO missingAddend:NO
                                              missingSubtrahend:NO missingMinuend:NO requireRemainder:YES
                                                      operator2:nil minC:0 maxC:0 isFraction:NO
                                               groupingContext:context strategyPattern:strategy];
    [strategy setString:@"不應改變已建立的提示"];
    XCTAssertEqualObjects(p.strategyHintText, @"每 4 顆裝一包，數一數能裝成幾包。");
    XCTAssertEqualObjects(t.strategyPattern, p.strategyText);
    XCTAssertNotEqual(p.groupingContext, context);
    XCTAssertNotEqual(t.groupingContext, context);
}

- (void)testBothPreviouslyAmbiguousDivisionStoriesExplicitlyRequireEqualGroups {
    WordProblem *groups = [self problemWithID:@"g3_div_group" a:24 b:4];
    WordProblem *rows = [self problemWithID:@"g3_div_row" a:24 b:4];
    XCTAssertTrue([groups.storyText containsString:@"平均分成 4 組"]);
    XCTAssertTrue([groups.strategyHintText containsString:@"每組人數一樣多"]);
    XCTAssertTrue([rows.storyText containsString:@"排成 4 排，每排的座位一樣多"]);
    XCTAssertTrue([rows.strategyHintText containsString:@"每排座位一樣多"]);
    XCTAssertEqual(groups.groupingContext.meaning, GroupingStoryMeaningShareEqually);
    XCTAssertEqual(rows.groupingContext.meaning, GroupingStoryMeaningShareEqually);
}

- (void)testAgeAndConversionRolesDoNotConflictWithGenericRepeatedAddition {
    WordProblem *age = [self problemWithID:@"g2_mul_age" a:3 b:5];
    XCTAssertEqualObjects(age.strategyHintText, @"先看弟弟的年齡：5 歲。哥哥是弟弟的 3 倍，所以把 5 歲重複 3 次。");
    XCTAssertTrue([age.workedExplanationText containsString:@"3 × 5 = 15"]);
    XCTAssertTrue([age.workedExplanationText hasSuffix:@"答案：15 歲"]);
    XCTAssertFalse([age.workedExplanationText containsString:@"3 + 3 + 3 + 3 + 3"]);
    XCTAssertFalse([age.strategyHintText containsString:@"15"]);
    NSArray<NSString *> *conversions = @[@"g3_mul_week_day", @"g3_mul_hour_min", @"g3_mul_min_sec", @"g3_mul_m_cm",
                                         @"g3_mul_kg_g", @"g3_mul_l_ml", @"g3_mul_km_m", @"g3_mul_dozen"];
    for (NSString *templateID in conversions) {
        WordProblemTemplate *t = [self templateWithID:templateID];
        WordProblem *p = [self problemWithID:templateID a:t.minA b:t.minB];
        XCTAssertNil(p.groupingContext);
        NSString *repeat = [NSString stringWithFormat:@"累加 %ld 次", (long)p.number1];
        XCTAssertTrue([p.strategyHintText containsString:repeat]);
        XCTAssertFalse([p.workedExplanationText containsString:@"\n= "]);
        NSString *equation = [NSString stringWithFormat:@"%ld × %ld = %ld", (long)p.number1, (long)p.number2, (long)p.answer];
        XCTAssertTrue([p.workedExplanationText containsString:equation]);
    }
}

- (void)testMoneyMeasurementComparisonAverageAndPerimeterKeepTheirOwnRoles {
    WordProblem *average = [self problemWithID:@"g3_div_avg_page" a:100 b:4];
    XCTAssertTrue([average.strategyHintText containsString:@"不代表每天實際讀得一樣多"]);
    XCTAssertTrue([average.workedExplanationText containsString:@"驗算：25 × 4 = 100"]);
    XCTAssertTrue([average.workedExplanationText hasSuffix:@"答案：25 頁"]);
    XCTAssertFalse([average.strategyHintText containsString:@"25"]);
    WordProblem *money = [self problemWithID:@"g3_div_avg_money" a:100 b:4];
    XCTAssertTrue([money.strategyHintText containsString:@"金額一樣多"]);
    XCTAssertTrue([money.strategyHintText containsString:@"不是硬幣的枚數"]);
    WordProblem *comparison = [self problemWithID:@"g3_div_multiple" a:24 b:3];
    XCTAssertTrue([comparison.strategyHintText containsString:@"先求其中 1 份的金額"]);
    XCTAssertTrue([comparison.strategyHintText containsString:@"不是把錢分給 3 個人"]);
    WordProblem *weight = [self problemWithID:@"g3_mul_bag" a:12 b:3];
    XCTAssertTrue([weight.strategyHintText containsString:@"總重量，不是袋數"]);
    WordProblem *perimeter = [self problemWithID:@"g3_mul_square_peri" a:5 b:4];
    XCTAssertTrue([perimeter.strategyHintText containsString:@"沿著四條邊走一圈"]);
    XCTAssertTrue([perimeter.workedExplanationText hasSuffix:@"答案：20 公分"]);
    for (NSString *templateID in [self textOnlyInventory]) {
        WordProblem *p = [self generatedProblem:[self templateWithID:templateID]];
        XCTAssertNil(p.groupingContext);
        XCTAssertFalse([p.workedExplanationText containsString:@"\n= "]);
    }
}

- (void)testRemainderUnitsAreItemUnitsAndSharingLeavesOneCommonPool {
    NSArray<NSString *> *templateIDs = @[@"g3_rem_share_candy", @"g3_rem_pack", @"g3_rem_plate",
                                         @"g3_rem_team", @"g3_rem_seat", @"g3_rem_box_big"];
    NSArray<NSString *> *leftovers = @[@"剩下的糖果有 3 顆", @"剩下的糖果有 3 顆", @"剩下的水餃有 3 顆",
                                       @"剩下的球員有 3 人", @"剩下的學生有 3 人", @"剩下的零件有 3 個"];
    for (NSUInteger i = 0; i < templateIDs.count; i++) {
        WordProblem *p = [self problemWithID:templateIDs[i] a:23 b:4];
        XCTAssertEqual(p.answer, 5);
        XCTAssertEqual(p.remainder, 3);
        XCTAssertTrue([p.workedExplanationText containsString:@"23 ÷ 4 = 5 餘 3"]);
        XCTAssertTrue([p.workedExplanationText containsString:@"驗算：5 × 4 + 3 = 23"]);
        XCTAssertTrue([p.workedExplanationText containsString:leftovers[i]]);
        NSString *answerLine = [NSString stringWithFormat:@"這題只答商：5 %@", p.unit];
        XCTAssertTrue([p.workedExplanationText hasSuffix:answerLine]);
        XCTAssertFalse([p.strategyHintText containsString:@"剩下 3"]);
        if (i == 0) XCTAssertTrue([p.workedExplanationText containsString:@"留在一起，還沒有分給任何人或組"]);
        else {
            NSString *wrongUnit = [NSString stringWithFormat:@"剩下的%@有 3 %@", p.groupingContext.itemName, p.unit];
            XCTAssertFalse([p.workedExplanationText containsString:wrongUnit]);
        }
        XCTAssertEqual([p toArithmeticProblem].answer, 5);
        XCTAssertEqual([p toArithmeticProblem].auxiliaryDistractor, 3);
    }
}

@end
