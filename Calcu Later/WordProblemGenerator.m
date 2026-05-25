#import "WordProblemGenerator.h"
#import "WordProblem.h"
#import "WordProblemTemplate.h"

@implementation WordProblemGenerator

+ (WordProblem *)generateForGrade:(NSInteger)grade {
    return [self generateForGrade:grade excludingTemplate:nil];
}

+ (WordProblem *)generateForGrade:(NSInteger)grade
                excludingTemplate:(NSString *)lastTemplateID {
    NSInteger g = MAX(1, MIN(3, grade));
    NSArray<WordProblemTemplate *> *templates = [WordProblemCatalog templatesForGrade:g];
    if (templates.count == 0) {
        return [[WordProblem alloc] initWithStory:@"小明有 1 顆糖果，又拿到 1 顆，共有幾顆糖果？"
                                       templateID:@"fallback"
                                            grade:g
                                          number1:1 number2:1 operator:@"+" answer:2 unit:@"顆"];
    }

    WordProblemTemplate *t = [self pickTemplate:templates excluding:lastTemplateID];

    NSInteger a = 0, b = 0, ans = 0;
    BOOL ok = NO;
    // 最多嘗試 50 次避免極端模板組合不出有效題目
    for (NSInteger attempt = 0; attempt < 50; attempt++) {
        a = [self randomBetween:t.minA and:t.maxA];
        b = [self randomBetween:t.minB and:t.maxB];

        if ([t.operatorSymbol isEqualToString:@"+"]) {
            ans = a + b;
            if (ans <= 999) { ok = YES; break; }
        } else if ([t.operatorSymbol isEqualToString:@"−"] || [t.operatorSymbol isEqualToString:@"-"]) {
            if (t.requireAGreaterEqualB && a < b) continue;
            // 額外避免 a == b（答案 0 不合題意）
            if (a == b) continue;
            ans = a - b;
            ok = YES;
            break;
        } else if ([t.operatorSymbol isEqualToString:@"×"]) {
            ans = a * b;
            if (ans <= 999) { ok = YES; break; }
        } else if ([t.operatorSymbol isEqualToString:@"÷"]) {
            if (b == 0) continue;
            if (t.requireDivisible) {
                // 強制 a 為 b 的整數倍：在 [minA, maxA] 內找一個能被 b 整除的 a
                NSInteger low = MAX(t.minA, b);
                NSInteger high = t.maxA;
                if (low > high) continue;
                NSInteger minQ = (low + b - 1) / b;
                NSInteger maxQ = high / b;
                if (minQ > maxQ) continue;
                NSInteger q = [self randomBetween:minQ and:maxQ];
                a = q * b;
                ans = q;
                // 排除 a == b（例如 9 ÷ 9 = 1）這種退化題型；
                // 並且要求 ans ≥ 2（除以自己等於 1 太單調，缺乏教學價值）。
                if (a == b) continue;
                if (a >= t.minA && a <= t.maxA && ans >= 1) { ok = YES; break; }
            } else {
                // 非整除模板：必須 a 確實被 b 整除才算合法答案，否則整數截斷會
                // 產生數學上錯誤的結果（10 ÷ 3 ≠ 3）。
                if (a % b != 0) continue;
                ans = a / b;
                if (ans >= 1 && a != b) { ok = YES; break; }
            }
        } else {
            // 未知運算子：直接放棄走 fallback。
            break;
        }
    }

    if (!ok) {
        // 模板約束無解（不該發生，但放個 safety net 避免送出 a/b/ans 不一致的題）。
        NSLog(@"[WordProblemGenerator] template %@ exhausted retries, using safe fallback",
              t.templateID);
        return [[WordProblem alloc] initWithStory:@"小明有 1 顆糖果，又拿到 1 顆，共有幾顆糖果？"
                                       templateID:@"fallback"
                                            grade:g
                                          number1:1 number2:1 operator:@"+" answer:2 unit:@"顆"];
    }

    NSString *story = [self renderPattern:t.storyPattern a:a b:b];
    // 內部統一儲存運算子用 "-"（與既有 ArithmeticProblem / hint 系統相容）
    NSString *opForModel = [t.operatorSymbol isEqualToString:@"−"] ? @"-" : t.operatorSymbol;
    return [[WordProblem alloc] initWithStory:story
                                   templateID:t.templateID
                                        grade:g
                                      number1:a number2:b
                                     operator:opForModel
                                       answer:ans
                                         unit:t.unit];
}

#pragma mark - Helpers

+ (WordProblemTemplate *)pickTemplate:(NSArray<WordProblemTemplate *> *)templates
                            excluding:(NSString *)excludeID {
    if (templates.count == 1 || !excludeID) {
        return templates[arc4random_uniform((uint32_t)templates.count)];
    }
    // 最多重抽 5 次避開 excludeID（避免模板太少時死循環）
    for (NSInteger i = 0; i < 5; i++) {
        WordProblemTemplate *t = templates[arc4random_uniform((uint32_t)templates.count)];
        if (![t.templateID isEqualToString:excludeID]) return t;
    }
    return templates[arc4random_uniform((uint32_t)templates.count)];
}

+ (NSInteger)randomBetween:(NSInteger)low and:(NSInteger)high {
    if (high < low) return low;
    NSInteger range = high - low + 1;
    return low + (NSInteger)arc4random_uniform((uint32_t)range);
}

+ (NSString *)renderPattern:(NSString *)pattern a:(NSInteger)a b:(NSInteger)b {
    NSString *s = pattern;
    s = [s stringByReplacingOccurrencesOfString:@"{a}" withString:[NSString stringWithFormat:@"%ld", (long)a]];
    s = [s stringByReplacingOccurrencesOfString:@"{b}" withString:[NSString stringWithFormat:@"%ld", (long)b]];
    return s;
}

@end
