#import <XCTest/XCTest.h>
#import "ArithmeticProblem.h"
#import "ProblemGenerator.h"

// 私有隨機入口只由測試子類覆寫；每個測試明確控制抽到哪個邊界，沒有機率式斷言。
@interface ProblemGenerator (DeterministicTesting)
+ (uint32_t)randomBelow:(uint32_t)upperBound;
@end

@interface ScriptedProblemGenerator : ProblemGenerator
+ (void)setDraws:(NSArray<NSNumber *> *)draws;
@end

@implementation ScriptedProblemGenerator
static NSArray<NSNumber *> *scriptedDraws;
static NSUInteger drawIndex;

+ (void)setDraws:(NSArray<NSNumber *> *)draws {
    scriptedDraws = [draws copy];
    drawIndex = 0;
}

+ (uint32_t)randomBelow:(uint32_t)upperBound {
    NSAssert(upperBound > 0 && drawIndex < scriptedDraws.count, @"Unexpected random draw");
    uint32_t value = scriptedDraws[drawIndex++].unsignedIntValue;
    if (value == UINT32_MAX) return upperBound - 1;
    NSAssert(value < upperBound, @"Scripted value is outside the requested range");
    return value;
}
@end

@interface ProblemGeneratorTests : XCTestCase
@end

@implementation ProblemGeneratorTests

- (ArithmeticProblem *)problemForTier:(DrillTier)tier operator:(NSString *)op
                               first:(NSNumber *)first second:(NSNumber *)second {
    [ScriptedProblemGenerator setDraws:@[@0, first, second]];
    return [ScriptedProblemGenerator generateForTier:tier
                                      allowAddition:[op isEqualToString:@"+"]
                                   allowSubtraction:[op isEqualToString:@"-"]
                                allowMultiplication:[op isEqualToString:@"×"]
                                      allowDivision:[op isEqualToString:@"÷"]];
}

- (void)testEveryOperationRespectsItsTierAtBothSamplingBoundaries {
    NSArray<NSNumber *> *bounds = @[@0, @(UINT32_MAX)];
    for (DrillTier tier = DrillTierD1; tier <= DrillTierD3; tier++) {
        NSInteger ceiling = tier == DrillTierD1 ? 20 : (tier == DrillTierD2 ? 100 : 999);
        for (NSString *op in @[@"+", @"-", @"×", @"÷"]) {
            for (NSNumber *first in bounds) {
                for (NSNumber *second in bounds) {
                    ArithmeticProblem *p = [self problemForTier:tier operator:op first:first second:second];
                    XCTAssertEqualObjects(p.operatorSymbol, op);
                    XCTAssertGreaterThan(p.number1, 0);
                    XCTAssertGreaterThan(p.number2, 0);
                    XCTAssertLessThanOrEqual(p.number1, ceiling);
                    XCTAssertLessThanOrEqual(p.number2, ceiling);
                    XCTAssertGreaterThanOrEqual(p.answer, 0);
                    XCTAssertLessThanOrEqual(p.answer, ceiling);
                    if ([op isEqualToString:@"+"]) {
                        XCTAssertEqual(p.answer, p.number1 + p.number2);
                    } else if ([op isEqualToString:@"-"]) {
                        XCTAssertEqual(p.answer, p.number1 - p.number2);
                    } else if ([op isEqualToString:@"×"]) {
                        XCTAssertEqual(p.answer, p.number1 * p.number2);
                        XCTAssertLessThanOrEqual(p.number2, 9);
                        if (tier != DrillTierD3) XCTAssertLessThanOrEqual(p.number1, 9);
                    } else {
                        XCTAssertEqual(p.number1 % p.number2, 0);
                        XCTAssertEqual(p.answer * p.number2, p.number1);
                        XCTAssertGreaterThanOrEqual(p.number2, 2);
                        XCTAssertLessThanOrEqual(p.number2, 9);
                    }
                    if (tier == DrillTierD3) {
                        XCTAssertGreaterThanOrEqual(p.number1, 100);
                        if ([op isEqualToString:@"+"] || [op isEqualToString:@"-"]) {
                            XCTAssertGreaterThanOrEqual(p.number2, 100);
                        }
                    }
                }
            }
        }
    }
}

- (void)testAdvertisedCeilingsAreIncludedNotRoundedDown {
    NSArray<NSNumber *> *ceilings = @[@20, @100, @999];
    for (DrillTier tier = DrillTierD1; tier <= DrillTierD3; tier++) {
        NSInteger ceiling = ceilings[tier - 1].integerValue;
        ArithmeticProblem *addition = [self problemForTier:tier operator:@"+"
                                                   first:@(UINT32_MAX) second:@(UINT32_MAX)];
        XCTAssertEqual(addition.answer, ceiling);
        ArithmeticProblem *subtraction = [self problemForTier:tier operator:@"-"
                                                      first:@(UINT32_MAX) second:@0];
        XCTAssertEqual(subtraction.number1, ceiling);
        // 20/100 可被 4 整除；999 可被 9 整除。
        ArithmeticProblem *division = [self problemForTier:tier operator:@"÷"
                                                   first:(tier == DrillTierD3 ? @7 : @2)
                                                  second:@(UINT32_MAX)];
        XCTAssertEqual(division.number1, ceiling);
    }
}

- (void)testMixedTierCanSelectEachConcreteTier {
    NSArray<NSNumber *> *ceilings = @[@20, @100, @999];
    for (NSUInteger index = 0; index < ceilings.count; index++) {
        [ScriptedProblemGenerator setDraws:@[@(index), @0, @(UINT32_MAX), @(UINT32_MAX)]];
        ArithmeticProblem *p = [ScriptedProblemGenerator generateForTier:DrillTierMixed
                                                           allowAddition:YES allowSubtraction:NO
                                                     allowMultiplication:NO allowDivision:NO];
        XCTAssertEqual(p.answer, ceilings[index].integerValue);
    }
}

- (void)testOperationSelectionAndAllDisabledFallback {
    NSArray<NSString *> *operators = @[@"+", @"-", @"×", @"÷"];
    for (NSUInteger index = 0; index < operators.count; index++) {
        [ScriptedProblemGenerator setDraws:@[@(index), @0, @0]];
        ArithmeticProblem *p = [ScriptedProblemGenerator generateForTier:DrillTierD1
                                                           allowAddition:YES allowSubtraction:YES
                                                     allowMultiplication:YES allowDivision:YES];
        XCTAssertEqualObjects(p.operatorSymbol, operators[index]);
    }
    [ScriptedProblemGenerator setDraws:@[@0, @(UINT32_MAX), @(UINT32_MAX)]];
    ArithmeticProblem *p = [ScriptedProblemGenerator generateForTier:DrillTierD2
                                               allowAddition:NO
                                            allowSubtraction:NO
                                         allowMultiplication:NO
                                               allowDivision:NO];
    XCTAssertEqualObjects(p.operatorSymbol, @"+");
    XCTAssertEqual(p.answer, 100);
}

- (void)testInvalidTierUsesTheSameD2FallbackForContentAndLabels {
    for (NSNumber *invalidTier in @[@(-1), @0, @5]) {
        DrillTier tier = (DrillTier)invalidTier.integerValue;
        ArithmeticProblem *p = [self problemForTier:tier operator:@"+"
                                            first:@(UINT32_MAX) second:@(UINT32_MAX)];
        XCTAssertEqual(p.answer, 100);
        XCTAssertEqualObjects([ProblemGenerator titleForTier:tier], [ProblemGenerator titleForTier:DrillTierD2]);
        XCTAssertEqualObjects([ProblemGenerator detailForTier:tier], [ProblemGenerator detailForTier:DrillTierD2]);
    }
}

- (void)testTierDescriptionsStateTheActualCeilingsAndThreeDigitScope {
    XCTAssertTrue([[ProblemGenerator titleForTier:DrillTierD1] containsString:@"20 以內"]);
    XCTAssertTrue([[ProblemGenerator titleForTier:DrillTierD2] containsString:@"100 以內"]);
    XCTAssertEqualObjects([ProblemGenerator titleForTier:DrillTierD3], @"D3（三位數）");
    XCTAssertTrue([[ProblemGenerator detailForTier:DrillTierD3] containsString:@"999"]);
    XCTAssertTrue([[ProblemGenerator detailForTier:DrillTierD3] containsString:@"三位數乘一位數"]);
    XCTAssertTrue([[ProblemGenerator detailForTier:DrillTierD3] containsString:@"三位數除以一位數"]);
    XCTAssertTrue([[ProblemGenerator detailForTier:DrillTierMixed] containsString:@"D1～D3"]);
}

@end
