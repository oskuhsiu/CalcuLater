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
    // 多步驟題的 op-specific 分支會跳過：對「100+50-30=120」這種 AP=(100,50,+,120) 來說，
    // n1-n2=50 既不是孩子典型錯誤也只是 raw input，當干擾沒意義。
    NSString *op = problem.operatorSymbol;
    BOOL isMul = [op isEqualToString:@"×"] || [op isEqualToString:@"*"];
    BOOL isDiv = [op isEqualToString:@"÷"] || [op isEqualToString:@"/"];
    if (problem.isMultiStep) {
        // skip op-specific block; ±1/±10/digit-reversal/aux 已足夠
    } else if ([op isEqualToString:@"+"]) {
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

    // 進位/借位忘了（多步驟題不適用，因為 n1±n2 ≠ answer）
    if (!problem.isMultiStep) {
        if ([op isEqualToString:@"+"]) {
            NSInteger noCarry = [self plainAddNoCarry:problem.number1 and:problem.number2];
            add(noCarry);
        } else if ([op isEqualToString:@"-"]) {
            NSInteger noBorrow = [self plainSubNoBorrow:problem.number1 and:problem.number2];
            add(noBorrow);
        }
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

    // 「auxiliaryDistractor」(目前用於二步驟的 intermediate)：洗牌後強制把它放到前面，
    // 保證在後續 truncate 到 3 時不會被丟掉。沒有 aux 或 aux 等於 correct 就跳過。
    if (problem.auxiliaryDistractor > 0 && problem.auxiliaryDistractor != correct) {
        NSNumber *aux = @(problem.auxiliaryDistractor);
        [arr removeObject:aux];
        [arr insertObject:aux atIndex:0];
    }

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

#pragma mark - Fraction choices

+ (NSArray<NSString *> *)fractionChoicesForNumerator:(NSInteger)num
                                         denominator:(NSInteger)denom
                                     outCorrectIndex:(NSInteger *)outCorrectIndex {
    // 生成候選干擾「對」(num, denom)：必為真分數、不重複、與正解不同。
    NSMutableArray<NSValue *> *pool = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSString *correctKey = [NSString stringWithFormat:@"%ld/%ld", (long)num, (long)denom];
    [seen addObject:correctKey];

    void (^tryAdd)(NSInteger, NSInteger) = ^(NSInteger n, NSInteger d) {
        if (n <= 0 || d <= 1) return;
        if (n >= d) return;  // 必為真分數
        NSString *key = [NSString stringWithFormat:@"%ld/%ld", (long)n, (long)d];
        if ([seen containsObject:key]) return;
        [seen addObject:key];
        // NSValue 包 (n, d) 一對。用 NSRange 兼用作 (location, length) 包這兩個值。
        [pool addObject:[NSValue valueWithRange:NSMakeRange((NSUInteger)n, (NSUInteger)d)]];
    };

    // 典型錯誤：分子 ±1、分母 ±1、分子分母對調（只在對調仍合法時）
    tryAdd(num + 1, denom);
    tryAdd(num - 1, denom);
    tryAdd(num, denom + 1);
    tryAdd(num, denom - 1);
    tryAdd(denom, num);                  // 顛倒（多半被過濾）
    tryAdd(num + 1, denom + 1);
    tryAdd(num - 1, denom - 1);
    tryAdd(num * 2, denom);              // 通常不合法（num≥denom），被過濾
    tryAdd(num, denom * 2);
    tryAdd(num + 2, denom);

    // 洗牌取 3
    NSMutableArray *shuffled = [pool mutableCopy];
    [self shuffle:shuffled];
    // 終極 fallback：保證 shuffled 一定有 3 個。原本只試「denom+count+2」單一序列，
    // 一旦撞 seen 就 break 留下空缺；改為掃 (1..N, denom+k) 直到湊滿，
    // 並用大跳的 denom 確保不會無限撞 seen。
    NSInteger guard = 0;
    while (shuffled.count < 3 && guard < 64) {
        guard++;
        NSInteger nd = denom + guard + 1;       // 3,4,5,... → 不會碰到 denom*2 撞 seen
        NSInteger nn = 1 + (guard % MAX(1, nd - 1));   // 1,2,3,... 循環取分子
        NSUInteger before = pool.count;
        tryAdd(nn, nd);
        if (pool.count > before) {
            [shuffled addObject:pool.lastObject];
        }
    }
    if (shuffled.count > 3) {
        [shuffled removeObjectsInRange:NSMakeRange(3, shuffled.count - 3)];
    }

    // 組合 4 個 title，含正解，再洗牌
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    [titles addObject:correctKey];
    for (NSValue *v in shuffled) {
        NSRange r = v.rangeValue;
        [titles addObject:[NSString stringWithFormat:@"%lu/%lu",
                           (unsigned long)r.location, (unsigned long)r.length]];
    }
    [self shuffle:titles];

    if (outCorrectIndex) {
        // indexOfObject: 回 NSUInteger (NSNotFound = NSUIntegerMax)，
        // 直接寫入 NSInteger* 會在 miss 時變成 -1（位元被當帶號重解），讓下游的
        // NSNotFound 哨兵比對失效。先存 NSUInteger 局部變數，明確判斷再 cast。
        NSUInteger idx = [titles indexOfObject:correctKey];
        NSAssert(idx != NSNotFound, @"fractionChoices titles must contain correctKey");
        *outCorrectIndex = (idx == NSNotFound) ? 0 : (NSInteger)idx;
    }
    return [titles copy];
}

+ (void)shuffle:(NSMutableArray *)arr {
    NSUInteger n = arr.count;
    for (NSUInteger i = n; i > 1; i--) {
        uint32_t j = arc4random_uniform((uint32_t)i);
        [arr exchangeObjectAtIndex:i - 1 withObjectAtIndex:j];
    }
}

@end
