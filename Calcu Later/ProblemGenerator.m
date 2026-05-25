#import "ProblemGenerator.h"
#import "ArithmeticProblem.h"

@implementation ProblemGenerator

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

    if (tier == DrillTierMixed) {
        DrillTier ts[] = { DrillTierD1, DrillTierD2, DrillTierD3 };
        tier = ts[arc4random_uniform(3)];
    }

    NSString *op = ops[arc4random_uniform((uint32_t)ops.count)];
    return [self generateOp:op tier:tier];
}

+ (ArithmeticProblem *)generateOp:(NSString *)op tier:(DrillTier)tier {
    NSInteger maxN = 20;
    NSInteger minN = 1;
    switch (tier) {
        case DrillTierD1: maxN = 20; break;
        case DrillTierD2: maxN = 99; break;
        case DrillTierD3: maxN = 999; break;
        default: maxN = 99; break;
    }

    if ([op isEqualToString:@"+"]) {
        NSInteger a = minN + arc4random_uniform((uint32_t)maxN);
        NSInteger b = minN + arc4random_uniform((uint32_t)maxN);
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:a + b];
    }
    if ([op isEqualToString:@"-"]) {
        NSInteger a = minN + arc4random_uniform((uint32_t)maxN);
        NSInteger b = minN + arc4random_uniform((uint32_t)maxN);
        if (a < b) { NSInteger t = a; a = b; b = t; }
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:a - b];
    }
    if ([op isEqualToString:@"×"]) {
        NSInteger upper = (tier == DrillTierD1) ? 9 : (tier == DrillTierD2 ? 12 : 25);
        NSInteger a = 2 + arc4random_uniform((uint32_t)(upper - 1));
        NSInteger b = 2 + arc4random_uniform((uint32_t)(upper - 1));
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:a * b];
    }
    if ([op isEqualToString:@"÷"]) {
        NSInteger b = 2 + arc4random_uniform(8);  // 2..9 為除數
        NSInteger upper = (tier == DrillTierD1) ? 9 : (tier == DrillTierD2 ? 12 : 25);
        NSInteger q = 1 + arc4random_uniform((uint32_t)upper);
        NSInteger a = b * q;
        return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:q];
    }
    return [[ArithmeticProblem alloc] initWithNumber1:0 number2:0 operator:@"+" answer:0];
}

@end
