#import "DistractorGenerator.h"
#import "ArithmeticProblem.h"

@implementation DistractorGenerator

+ (NSArray<NSNumber *> *)distractorsForProblem:(ArithmeticProblem *)problem {
    NSInteger correct = problem.answer;
    NSMutableOrderedSet<NSNumber *> *pool = [NSMutableOrderedSet orderedSet];

    void (^add)(NSInteger) = ^(NSInteger v) {
        if (v < 0) return;
        if (v == correct) return;
        [pool addObject:@(v)];
    };

    // ±1（最常見的計算誤差）
    add(correct - 1);
    add(correct + 1);

    // ±10（位數錯位常見錯誤）
    add(correct - 10);
    add(correct + 10);

    // 對運算符做反 — 教育心理學上常見「忘了符號」
    NSString *op = problem.operatorSymbol;
    BOOL isMul = [op isEqualToString:@"×"] || [op isEqualToString:@"*"];
    BOOL isDiv = [op isEqualToString:@"÷"] || [op isEqualToString:@"/"];
    if ([op isEqualToString:@"+"]) {
        add(problem.number1 - problem.number2);
        add(problem.number2 - problem.number1);
    } else if ([op isEqualToString:@"-"]) {
        add(problem.number1 + problem.number2);
    } else if (isMul) {
        // 乘法典型誤算
        add(problem.number1 + problem.number2);           // 寫成加法
        add(correct + problem.number1);                    // 多算一倍 a
        add(correct - problem.number1);                    // 少算一倍 a
        add(correct + problem.number2);                    // 多算一倍 b
        add(correct - problem.number2);                    // 少算一倍 b
        // 鄰近九九（同段相鄰）
        if (problem.number2 > 1) add(problem.number1 * (problem.number2 - 1));
        add(problem.number1 * (problem.number2 + 1));
        if (problem.number1 > 1) add((problem.number1 - 1) * problem.number2);
        add((problem.number1 + 1) * problem.number2);
        // 互換九九（孩子常背錯隔壁段）
        if (problem.number1 != problem.number2) {
            if (problem.number1 > 1) add((problem.number1 - 1) * (problem.number2 + 1));
        }
    } else if (isDiv) {
        if (problem.number2 != 0) add(problem.number1 - problem.number2);
        // 除法典型誤算：商 ±1（最常見的試商錯）
        add(correct + 1);
        add(correct - 1);
        // 把除數 / 被除數錯記
        if (problem.number2 != 0) {
            add(problem.number1 / (problem.number2 + 1));
            if (problem.number2 > 1) add(problem.number1 / (problem.number2 - 1));
        }
    }

    // 個位/十位顛倒 — 寫字錯
    if (correct >= 10 && correct < 100) {
        NSInteger ones = correct % 10;
        NSInteger tens = correct / 10;
        add(ones * 10 + tens);
    }

    // 多進位 / 少進位 — 直式加減常見錯
    add(correct + 10);
    add(correct - 10);

    // 進位/借位忘了
    if ([op isEqualToString:@"+"]) {
        NSInteger noCarry = [self plainAddNoCarry:problem.number1 and:problem.number2];
        add(noCarry);
    } else if ([op isEqualToString:@"-"]) {
        NSInteger noBorrow = [self plainSubNoBorrow:problem.number1 and:problem.number2];
        add(noBorrow);
    }

    // 把正解剔掉（保險）
    [pool removeObject:@(correct)];

    // 不夠 3 個 → 補 ±2, ±3, ±5
    NSArray<NSNumber *> *backups = @[ @(correct - 2), @(correct + 2), @(correct - 3),
                                       @(correct + 3), @(correct - 5), @(correct + 5) ];
    for (NSNumber *n in backups) {
        if (pool.count >= 6) break;
        add(n.integerValue);
    }

    // 隨機抽 3 個（洗牌後取前 3）
    NSMutableArray<NSNumber *> *arr = [pool.array mutableCopy];
    [self shuffle:arr];
    if (arr.count > 3) {
        [arr removeObjectsInRange:NSMakeRange(3, arr.count - 3)];
    }
    while (arr.count < 3) {
        // 終極 fallback：靠正解 + 任意小偏移
        NSInteger guess = correct + (NSInteger)arr.count + 1;
        if (guess != correct && ![arr containsObject:@(guess)] && guess >= 0) {
            [arr addObject:@(guess)];
        } else {
            [arr addObject:@(correct + 100 + (NSInteger)arr.count)];
        }
    }
    return [arr copy];
}

+ (NSArray<NSNumber *> *)choicesForProblem:(ArithmeticProblem *)problem {
    NSMutableArray<NSNumber *> *all = [[self distractorsForProblem:problem] mutableCopy];
    [all addObject:@(problem.answer)];
    [self shuffle:all];
    return [all copy];
}

#pragma mark - Helpers

/// 個位、十位分別相加但不進位 → 直式忘記進位的結果。
+ (NSInteger)plainAddNoCarry:(NSInteger)a and:(NSInteger)b {
    NSInteger result = 0;
    NSInteger place = 1;
    while (a > 0 || b > 0) {
        NSInteger d = (a % 10) + (b % 10);
        result += (d % 10) * place;
        a /= 10;
        b /= 10;
        place *= 10;
    }
    return result;
}

/// 直式忘記借位：當 a 的某位小於 b 對應位，就取絕對值（小孩典型錯誤：「不夠減就反過來減」）。
+ (NSInteger)plainSubNoBorrow:(NSInteger)a and:(NSInteger)b {
    NSInteger result = 0;
    NSInteger place = 1;
    while (a > 0 || b > 0) {
        NSInteger da = a % 10;
        NSInteger db = b % 10;
        NSInteger d = labs(da - db);
        result += d * place;
        a /= 10;
        b /= 10;
        place *= 10;
    }
    return result;
}

+ (void)shuffle:(NSMutableArray *)arr {
    NSUInteger n = arr.count;
    for (NSUInteger i = n; i > 1; i--) {
        uint32_t j = arc4random_uniform((uint32_t)i);
        [arr exchangeObjectAtIndex:i - 1 withObjectAtIndex:j];
    }
}

@end
