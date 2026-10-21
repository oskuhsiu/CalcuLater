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
    if (templates.count == 0) return [self safeFallbackForGrade:g];

    // 一年級：降低「兩個運算元都是個位數」的出現機率。最多重抽 maxRounds 輪，
    // 每輪若得到 both-single-digit 就以高機率丟棄重抽；保留低殘餘機率，
    // 讓基礎「個位＋個位」題可以有、但機率低（同時略為提高一年級難度）。
    NSInteger maxRounds = (g == 1) ? 6 : 1;
    WordProblem *problem = nil;
    for (NSInteger round = 0; round < maxRounds; round++) {
        WordProblem *cand = [self generateOnceFromTemplates:templates grade:g excluding:lastTemplateID];
        if (!cand) continue;
        problem = cand;  // 留作後援（即使最後一輪仍是個位＋個位也有題可出）
        if (g != 1) break;
        if (![self bothSingleDigit:cand]) break;   // 至少一個兩位數 → 採用
        if (arc4random_uniform(100) >= 85) break;  // 15% 殘餘機率保留個位＋個位
    }
    return problem ?: [self safeFallbackForGrade:g];
}

+ (WordProblem *)safeFallbackForGrade:(NSInteger)g {
    return [[WordProblem alloc] initWithStory:@"小明有 1 顆糖果，又拿到 1 顆，共有幾顆糖果？"
                                   templateID:@"fallback"
                                        grade:g
                                      number1:1 number2:1 operator:@"+" answer:2 unit:@"顆"];
}

/// 「兩個運算元都是個位數」判定（僅單步驟加減題；二步驟 / 分數視為已足夠難，回 NO）。
+ (BOOL)bothSingleDigit:(WordProblem *)p {
    if (p.operator2 != nil || p.isFractionAnswer) return NO;
    return labs((long)p.number1) < 10 && labs((long)p.number2) < 10;
}

/// 依選定模板生成一題（pick template + 最多 50 次嘗試湊出有效數值）。湊不出回 nil。
+ (WordProblem *)generateOnceFromTemplates:(NSArray<WordProblemTemplate *> *)templates
                                     grade:(NSInteger)g
                                 excluding:(NSString *)lastTemplateID {
    WordProblemTemplate *t = [self pickTemplate:templates excluding:lastTemplateID];

    NSInteger a = 0, b = 0, c = 0, ans = 0, intermediate = 0;
    BOOL ok = NO;
    BOOL isTwoStep = (t.operator2 != nil);
    // 最多嘗試 50 次避免極端模板組合不出有效題目
    for (NSInteger attempt = 0; attempt < 50; attempt++) {
        a = [self randomBetween:t.minA and:t.maxA];
        b = [self randomBetween:t.minB and:t.maxB];

        if (t.isFraction) {
            // 真分數：a (分子) < b (分母)，且都 > 0。
            if (a <= 0 || b <= 1) continue;
            if (a >= b) continue;
            // ans 對分數題無實質意義（MCQ 用 numerator/denominator 比對），設為 0 占位。
            ans = 0;
            ok = YES;
            break;
        }

        if (isTwoStep) {
            c = [self randomBetween:t.minC and:t.maxC];
            intermediate = [self applyOp:t.operatorSymbol to:a and:b];
            // 中間結果必須 > 0（避免「-3」這種對小孩無意義的中間值）
            if (intermediate <= 0) continue;
            ans = [self applyOp:t.operator2 to:intermediate and:c];
            // 最終答案必須 > 0
            if (ans <= 0) continue;
            // 加法 safety cap（避免 a+b+c 暴衝；減法不會超出）
            if (ans > 99999) continue;
            ok = YES;
            break;
        }

        if ([t.operatorSymbol isEqualToString:@"+"]) {
            ans = a + b;
            // 上限放寬到 99999 以涵蓋三年級 10000 以內加法（如 8500 + 1200）。
            // 題庫真正範圍由各 template 的 minA/maxA/minB/maxB 控制；這裡只是 safety cap。
            if (ans <= 99999) { ok = YES; break; }
        } else if ([t.operatorSymbol isEqualToString:@"−"] || [t.operatorSymbol isEqualToString:@"-"]) {
            if (t.requireAGreaterEqualB && a < b) continue;
            // 額外避免 a == b（答案 0 不合題意）
            if (a == b) continue;
            ans = a - b;
            ok = YES;
            break;
        } else if ([t.operatorSymbol isEqualToString:@"×"]) {
            ans = a * b;
            // 上限放寬：涵蓋三年級三位數×一位數（如 320×9=2880）與單位換算（9×1000=9000）。
            if (ans <= 99999) { ok = YES; break; }
        } else if ([t.operatorSymbol isEqualToString:@"÷"]) {
            if (b == 0) continue;
            if (t.requireRemainder) {
                // 有餘數除法：必須 a%b != 0。a,b 已隨機從範圍中選出，若剛好整除就跳過重抽。
                if (a % b == 0) continue;
                ans = a / b;
                // 排除商為 0（被除數比除數還小，題意不通順）。
                if (ans < 1) continue;
                ok = YES;
                break;
            } else if (t.requireDivisible) {
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
                // 不再 blanket skip q=1：原本 `if (a == b) continue;` 是為了避免
                // 「9 ÷ 9 = 1」這種無聊的「自己除自己」，但同時也把單位換算題
                // 「60 分鐘 = 1 小時」「100 公分 = 1 公尺」這些「課綱定義級別」的
                // 教學題給擋掉了。改為由 template 透過 minA 自然控制：
                // 例如倍數題 `g3_div_multiple` 用 minA=12 自然就讓 q≥2；
                // 單位換算題 minA=b 才能讓 q=1 的定義題出現。
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
        // 模板約束無解（不該發生，但放個 safety net）。回 nil 交由上層重抽 / 後援。
        NSLog(@"[WordProblemGenerator] template %@ exhausted retries", t.templateID);
        return nil;
    }

    NSString *story = [self renderPattern:t.storyPattern a:a b:b c:c];
    // 內部統一儲存運算子用 "-"（與既有 ArithmeticProblem / hint 系統相容）
    NSString *opForModel = [self normalizeOp:t.operatorSymbol];
    NSString *op2ForModel = isTwoStep ? [self normalizeOp:t.operator2] : nil;
    // 有餘數除法：a 不被 b 整除時 ans 為商、remainder 為餘數。
    NSInteger remainder = 0;
    if (t.requireRemainder && [t.operatorSymbol isEqualToString:@"÷"]) {
        remainder = a % b;
    }
    return [[WordProblem alloc] initWithStory:story
                                   templateID:t.templateID
                                        grade:g
                                      number1:a number2:b
                                     operator:opForModel
                                       answer:ans
                                         unit:t.unit
                                missingAddend:t.missingAddend
                            missingSubtrahend:t.missingSubtrahend
                               missingMinuend:t.missingMinuend
                                    remainder:remainder
                                      number3:c
                                    operator2:op2ForModel
                                 intermediate:intermediate
                             isFractionAnswer:t.isFraction
                              answerNumerator:t.isFraction ? a : 0
                            answerDenominator:t.isFraction ? b : 0
                              groupingContext:t.groupingContext
                                 strategyText:t.strategyPattern ? [self renderPattern:t.strategyPattern a:a b:b c:c] : nil];
}

+ (NSString *)normalizeOp:(NSString *)op {
    // 模板用 U+2212 "−"（較粗）；內部 ArithmeticProblem 用 ASCII "-"
    if ([op isEqualToString:@"−"]) return @"-";
    return op;
}

/// 套用 "+" / "−" 運算（目前二步驟只支援加減同優先級，乘除不需要）。
/// 不支援的 op 回傳 NSIntegerMin 當作 sentinel；呼叫端會看到 intermediate ≤ 0 而觸發 retry。
/// 改成回傳 sentinel 而非「靜默回傳 x」是為了避免未來有人加 T2(..., @"×", ...)
/// 而 applyOp 把 a×b 默默退化成 a，產生數學錯誤但通過全部 sanity check 的題目。
+ (NSInteger)applyOp:(NSString *)op to:(NSInteger)x and:(NSInteger)y {
    if ([op isEqualToString:@"+"]) return x + y;
    if ([op isEqualToString:@"−"] || [op isEqualToString:@"-"]) return x - y;
    NSAssert(NO, @"applyOp unsupported op: %@", op);
    NSLog(@"[WordProblemGenerator] applyOp unsupported op: %@", op);
    return NSIntegerMin;
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

+ (NSString *)renderPattern:(NSString *)pattern a:(NSInteger)a b:(NSInteger)b c:(NSInteger)c {
    NSString *s = pattern;
    s = [s stringByReplacingOccurrencesOfString:@"{a}" withString:[NSString stringWithFormat:@"%ld", (long)a]];
    s = [s stringByReplacingOccurrencesOfString:@"{b}" withString:[NSString stringWithFormat:@"%ld", (long)b]];
    s = [s stringByReplacingOccurrencesOfString:@"{c}" withString:[NSString stringWithFormat:@"%ld", (long)c]];
    return s;
}

@end
