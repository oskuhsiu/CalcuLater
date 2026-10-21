#import "ProblemGenerator.h"
#import "ArithmeticProblem.h"

@implementation ProblemGenerator

+ (DrillTier)normalizedTier:(DrillTier)tier {
    if (tier >= DrillTierD1 && tier <= DrillTierMixed) return tier;
    return DrillTierD2;
}

+ (NSString *)titleForTier:(DrillTier)tier {
    switch ([self normalizedTier:tier]) {
        case DrillTierD1: return @"D1（20 以內）";
        case DrillTierD2: return @"D2（100 以內）";
        case DrillTierD3: return @"D3（三位數）";
        case DrillTierMixed: return @"D4（混合）";
    }
    return @"D2（100 以內）";
}

+ (NSString *)detailForTier:(DrillTier)tier {
    switch ([self normalizedTier:tier]) {
        case DrillTierD1:
            return @"20 以內加減、一位數乘法與整除；題目中的數和答案都不超過 20。";
        case DrillTierD2:
            return @"100 以內加減、九九乘法與整除；題目中的數和答案都不超過 100。";
        case DrillTierD3:
            return @"三位數加減、三位數乘一位數、三位數除以一位數（整除）；題目中的數和答案都不超過 999。";
        case DrillTierMixed:
            return @"混合 D1～D3 的題目，依照勾選的運算練習；不出負數，除法都能整除。";
    }
    return @"";
}

// 集中隨機來源，讓範圍邊界可以用固定抽樣重現，而不靠大量碰運氣的測試。
+ (uint32_t)randomBelow:(uint32_t)upperBound {
    return arc4random_uniform(upperBound);
}

+ (NSInteger)randomBetween:(NSInteger)low and:(NSInteger)high {
    NSAssert(low <= high, @"ProblemGenerator requires a nonempty number range");
    return low + [self randomBelow:(uint32_t)(high - low + 1)];
}

+ (ArithmeticProblem *)generateForTier:(DrillTier)tier
                       allowAddition:(BOOL)allowAdd
                    allowSubtraction:(BOOL)allowSub
                  allowMultiplication:(BOOL)allowMul
                        allowDivision:(BOOL)allowDiv {
    // 至少有一個運算
    NSMutableArray<NSString *> *ops = [NSMutableArray array];
    if (allowAdd) [ops addObject:@"+"];
    if (allowSub) [ops addObject:@"-"];
    if (allowMul) [ops addObject:@"×"];
    if (allowDiv) [ops addObject:@"÷"];
    if (ops.count == 0) [ops addObject:@"+"];

    tier = [self normalizedTier:tier];
    if (tier == DrillTierMixed) {
        DrillTier ts[] = { DrillTierD1, DrillTierD2, DrillTierD3 };
        tier = ts[[self randomBelow:3]];
    }

    NSString *op = ops[[self randomBelow:(uint32_t)ops.count]];
    return [self generateOp:op tier:tier];
}

+ (ArithmeticProblem *)generateOp:(NSString *)op tier:(DrillTier)tier {
    NSInteger maxN = tier == DrillTierD1 ? 20 : (tier == DrillTierD3 ? 999 : 100);
    NSInteger minN = tier == DrillTierD3 ? 100 : 1;

    if ([op isEqualToString:@"+"]) {
        // 先留出另一個加數的空間；「20 以內」約束的是總和，不只是各個加數。
        NSInteger a = [self randomBetween:minN and:maxN - minN];
        NSInteger b = [self randomBetween:minN and:maxN - a];
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:a + b];
    }
    if ([op isEqualToString:@"-"]) {
        NSInteger a = [self randomBetween:minN and:maxN];
        NSInteger b = [self randomBetween:minN and:a];
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:a - b];
    }
    if ([op isEqualToString:@"×"]) {
        NSInteger a, b;
        if (tier == DrillTierD3) {
            b = [self randomBetween:2 and:9];
            a = [self randomBetween:100 and:maxN / b];
        } else {
            a = [self randomBetween:2 and:9];
            b = [self randomBetween:2 and:MIN(9, maxN / a)];
        }
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:a * b];
    }
    if ([op isEqualToString:@"÷"]) {
        NSInteger b = [self randomBetween:2 and:9];
        // 從商的合法區間直接取值，保證整除，且 D3 的被除數一定是三位數。
        NSInteger minQ = (minN + b - 1) / b;
        NSInteger q = [self randomBetween:minQ and:maxN / b];
        NSInteger a = b * q;
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:q];
    }
    return [[ArithmeticProblem alloc] initWithNumber1:0 number2:0 operator:@"+" answer:0];
}

@end
