// Sanity tests：確認 WordProblemGenerator 對 missing addend / 有餘除法 / 數值範圍的處理正確。
// 不驗 UI；只跑 generator 抽多題後檢查 model 不變式（answer 與 number1/number2 一致、
// remainder 與 missingAddend 在對應題型才會出現等）。
#import <XCTest/XCTest.h>
#import "WordProblem.h"
#import "WordProblemGenerator.h"
#import "WordProblemTemplate.h"
#import "ArithmeticProblem.h"
#import "DistractorGenerator.h"

@interface WordProblemGeneratorTests : XCTestCase
@end

@implementation WordProblemGeneratorTests

#pragma mark - 全題庫 sanity

- (void)testAllTemplatesGenerateValidProblems {
    // Sanity 大量抽題：對每個年級各抽 (templates.count × 30) 次以高機率涵蓋所有 templateID。
    // 同時用 NSCountedSet 追蹤命中分佈，確認沒有 templateID 從未被選中
    // （pickTemplate 死循環 / pool 為空之類的 regression 會被這條抓到）。
    // 過去版本用 `for (t in all) for (30 次) generateForGrade:t.grade`，但內層仍隨機抽
    // 模板，並不是真的「每個模板各 30 次」；改成顯式做覆蓋斷言更誠實。
    NSArray<WordProblemTemplate *> *all = [WordProblemCatalog allTemplates];
    XCTAssertGreaterThan(all.count, 100, @"題庫應 > 100 個模板");

    NSCountedSet<NSString *> *seen = [NSCountedSet set];
    for (WordProblemTemplate *t in all) {
        for (NSInteger i = 0; i < 30; i++) {
            WordProblem *p = [WordProblemGenerator generateForGrade:t.grade];
            XCTAssertNotNil(p);
            XCTAssertGreaterThan(p.answer, -1, @"答案不可為負: %@", p.templateID);
            XCTAssertGreaterThan(p.number1, 0);
            XCTAssertGreaterThan(p.number2, 0);
            [seen addObject:p.templateID];
        }
    }
    // 預期每個 templateID 至少被抽中一次（量很大，理論上必然命中；
    // 若有 templateID 從未出現代表 pickTemplate / templates list 有 regression）。
    for (WordProblemTemplate *t in all) {
        XCTAssertGreaterThan([seen countForObject:t.templateID], 0,
                             @"templateID %@ 從未被抽到 — pickTemplate 可能 broken", t.templateID);
    }
}

#pragma mark - Missing Addend

- (void)testMissingAddendInternalCalculation {
    // 找一個 missingAddend 模板，跑 50 次，確認 answer = number1 - number2，且都 > 0
    NSArray<WordProblemTemplate *> *g1 = [WordProblemCatalog templatesForGrade:1];
    WordProblemTemplate *missTemplate = nil;
    for (WordProblemTemplate *t in g1) {
        if (t.missingAddend) { missTemplate = t; break; }
    }
    XCTAssertNotNil(missTemplate, @"G1 應該至少有一個 missingAddend 模板");

    // 連續抽 200 題（即使被排序到別的模板也沒關係，只驗中籤到 missingAddend 的）
    NSInteger checked = 0;
    for (NSInteger i = 0; i < 200; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:1];
        if (!p.missingAddend) continue;
        checked++;
        XCTAssertEqual(p.answer, p.number1 - p.number2,
                       @"missingAddend 題 ans 應等於 number1-number2 (%@)", p.templateID);
        XCTAssertGreaterThan(p.answer, 0, @"missing addend 必須 > 0");
        XCTAssertEqualObjects(p.operatorSymbol, @"-", @"missingAddend 內部 op 必為 '-'");
    }
    XCTAssertGreaterThan(checked, 0, @"200 題中應該至少抽到一些 missingAddend 題");
}

#pragma mark - 有餘數除法

- (void)testRemainderDivisionInvariants {
    // 三年級題庫應有 requireRemainder 模板；抽到時 remainder > 0 且 answer 為商。
    NSInteger checked = 0;
    for (NSInteger i = 0; i < 500; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:3];
        if (p.remainder == 0) continue;
        checked++;
        // 等式應該滿足: number1 = answer * number2 + remainder
        NSInteger reconstructed = p.answer * p.number2 + p.remainder;
        XCTAssertEqual(reconstructed, p.number1,
                       @"有餘除法應滿足 a = q*b + r (%@: %ld ÷ %ld = %ld⋯%ld)",
                       p.templateID, (long)p.number1, (long)p.number2,
                       (long)p.answer, (long)p.remainder);
        XCTAssertGreaterThan(p.remainder, 0);
        XCTAssertLessThan(p.remainder, p.number2, @"餘數必小於除數");
        XCTAssertGreaterThan(p.answer, 0, @"商必須 > 0");
        XCTAssertEqualObjects(p.operatorSymbol, @"÷");
    }
    XCTAssertGreaterThan(checked, 0, @"500 題 G3 中應該至少抽到一些有餘除法題");
}

#pragma mark - 各年級數值範圍對齊 108 課綱

- (void)testGrade1AnswersWithin100 {
    // G1 加減答案應在 100 以內（少數退位題可能略低；上限即可）
    for (NSInteger i = 0; i < 300; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:1];
        XCTAssertLessThanOrEqual(p.answer, 100, @"G1 答案應 ≤ 100 (%@)", p.templateID);
        XCTAssertLessThanOrEqual(p.number1, 100, @"G1 number1 應 ≤ 100");
        XCTAssertLessThanOrEqual(p.number2, 100, @"G1 number2 應 ≤ 100");
    }
}

- (void)testGrade2AnswersWithin1000 {
    for (NSInteger i = 0; i < 300; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:2];
        // 乘法 9×9=81 在 G2 仍合理；加減上限 999；放寬到 1000
        XCTAssertLessThanOrEqual(p.answer, 1000, @"G2 答案應 ≤ 1000 (%@)", p.templateID);
    }
}

- (void)testGrade3AnswersWithin10000 {
    for (NSInteger i = 0; i < 300; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:3];
        XCTAssertLessThanOrEqual(p.answer, 10000, @"G3 答案應 ≤ 10000 (%@)", p.templateID);
    }
}

#pragma mark - Missing Subtrahend

- (void)testMissingSubtrahendInvariants {
    NSInteger checked = 0;
    for (NSInteger i = 0; i < 300; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:1];
        if (!p.missingSubtrahend) continue;
        checked++;
        // a - ? = b → answer = a - b > 0
        XCTAssertEqual(p.answer, p.number1 - p.number2,
                       @"missingSubtrahend ans = a-b (%@)", p.templateID);
        XCTAssertGreaterThan(p.answer, 0);
        XCTAssertEqualObjects(p.operatorSymbol, @"-");
        XCTAssertFalse(p.missingAddend, @"missingAddend 與 missingSubtrahend 互斥");
    }
    XCTAssertGreaterThan(checked, 0, @"G1 應抽到 missingSubtrahend 題");
}

#pragma mark - 二步驟

- (void)testTwoStepInvariants {
    NSInteger checked = 0;
    for (NSInteger grade = 2; grade <= 3; grade++) {
        for (NSInteger i = 0; i < 400; i++) {
            WordProblem *p = [WordProblemGenerator generateForGrade:grade];
            if (!p.operator2) continue;
            checked++;
            // 重算驗證: applyOp(applyOp(a, op1, b), op2, c) == answer
            NSInteger step1 = [self applyOp:p.operatorSymbol to:p.number1 and:p.number2];
            XCTAssertEqual(step1, p.intermediate,
                           @"intermediate 應為第一步結果 (%@)", p.templateID);
            XCTAssertGreaterThan(step1, 0, @"中間結果不可 ≤ 0 (%@)", p.templateID);
            NSInteger step2 = [self applyOp:p.operator2 to:step1 and:p.number3];
            XCTAssertEqual(step2, p.answer,
                           @"answer 應為第二步結果 (%@)", p.templateID);
            XCTAssertGreaterThan(step2, 0, @"最終答案不可 ≤ 0 (%@)", p.templateID);
            // operator2 只能是 + / -
            BOOL op2Valid = [p.operator2 isEqualToString:@"+"] || [p.operator2 isEqualToString:@"-"];
            XCTAssertTrue(op2Valid, @"op2 必為 +/- (%@: %@)", p.templateID, p.operator2);
            // 故事必含 {a} {b} {c} 全代換完成（不應殘留花括號）
            XCTAssertFalse([p.storyText containsString:@"{"], @"story 含未代換 token: %@", p.storyText);
        }
    }
    XCTAssertGreaterThan(checked, 0, @"應抽到二步驟題");
}

- (NSInteger)applyOp:(NSString *)op to:(NSInteger)x and:(NSInteger)y {
    if ([op isEqualToString:@"+"]) return x + y;
    return x - y;
}

#pragma mark - Missing Minuend

- (void)testMissingMinuendInvariants {
    NSInteger checked = 0;
    for (NSInteger i = 0; i < 300; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:1];
        if (!p.missingMinuend) continue;
        checked++;
        // ? − number1 = number2 → answer = number1 + number2
        XCTAssertEqual(p.answer, p.number1 + p.number2,
                       @"missingMinuend ans = n1+n2 (%@)", p.templateID);
        XCTAssertGreaterThan(p.answer, 0);
        XCTAssertEqualObjects(p.operatorSymbol, @"+");
        XCTAssertFalse(p.missingAddend);
        XCTAssertFalse(p.missingSubtrahend);
    }
    XCTAssertGreaterThan(checked, 0, @"G1 應抽到 missingMinuend 題");
}

#pragma mark - 分數

- (void)testFractionProblemsAreProperFractions {
    NSInteger checked = 0;
    for (NSInteger i = 0; i < 400; i++) {
        WordProblem *p = [WordProblemGenerator generateForGrade:3];
        if (!p.isFractionAnswer) continue;
        checked++;
        XCTAssertGreaterThan(p.answerNumerator, 0);
        XCTAssertGreaterThan(p.answerDenominator, 1);
        XCTAssertLessThan(p.answerNumerator, p.answerDenominator,
                          @"必為真分數 (%@: %ld/%ld)",
                          p.templateID, (long)p.answerNumerator, (long)p.answerDenominator);
    }
    XCTAssertGreaterThan(checked, 0, @"G3 應抽到分數題");
}

- (void)testFractionChoicesAlwaysIncludeCorrect {
    for (NSInteger i = 0; i < 200; i++) {
        // 用任意合法分數測試 distractor
        NSInteger denom = 3 + (i % 7);
        NSInteger num = 1 + (i % (denom - 1));
        NSInteger correctIdx = -1;
        NSArray<NSString *> *choices = [DistractorGenerator
            fractionChoicesForNumerator:num denominator:denom outCorrectIndex:&correctIdx];
        XCTAssertEqual(choices.count, 4, @"分數選項應有 4 個");
        XCTAssertTrue(correctIdx >= 0 && correctIdx <= 3, @"correctIdx 應在 0~3");
        NSString *expectedCorrect = [NSString stringWithFormat:@"%ld/%ld", (long)num, (long)denom];
        XCTAssertEqualObjects(choices[correctIdx], expectedCorrect, @"correctIdx 指向正解");
        // 4 個選項都不重複
        NSSet *set = [NSSet setWithArray:choices];
        XCTAssertEqual(set.count, 4, @"分數選項不應重複: %@", choices);
        // 每個都是合法真分數字串
        for (NSString *s in choices) {
            NSArray *parts = [s componentsSeparatedByString:@"/"];
            XCTAssertEqual(parts.count, 2, @"格式應為 n/d");
            NSInteger n = [parts[0] integerValue];
            NSInteger d = [parts[1] integerValue];
            XCTAssertGreaterThan(n, 0);
            XCTAssertLessThan(n, d, @"選項必為真分數: %@", s);
        }
    }
}

#pragma mark - 二步驟 MCQ 選項必含 intermediate

- (void)testTwoStepChoicesAlwaysIncludeIntermediate {
    // intermediate（第一步結果）是孩子最典型的「忘了第二步」錯誤；MCQ 必須包含它。
    NSInteger checked = 0;
    for (NSInteger grade = 2; grade <= 3; grade++) {
        for (NSInteger i = 0; i < 400; i++) {
            WordProblem *wp = [WordProblemGenerator generateForGrade:grade];
            if (!wp.operator2) continue;
            // intermediate 等於 answer 時無法當干擾項（會剔除），跳過驗證
            if (wp.intermediate == wp.answer) continue;
            checked++;

            ArithmeticProblem *ap = [wp toArithmeticProblem];
            XCTAssertEqual(ap.auxiliaryDistractor, wp.intermediate,
                           @"toArithmeticProblem 應把 intermediate 設給 auxiliaryDistractor");

            NSArray<NSNumber *> *choices = [DistractorGenerator choicesForProblem:ap];
            XCTAssertEqual(choices.count, 4, @"MCQ 必有 4 個選項");
            BOOL hasIntermediate = [choices containsObject:@(wp.intermediate)];
            XCTAssertTrue(hasIntermediate,
                          @"二步驟 MCQ 選項應包含 intermediate (%@: ans=%ld inter=%ld choices=%@)",
                          wp.templateID, (long)wp.answer, (long)wp.intermediate, choices);
            BOOL hasAnswer = [choices containsObject:@(wp.answer)];
            XCTAssertTrue(hasAnswer, @"MCQ 選項必含正解");
        }
    }
    XCTAssertGreaterThan(checked, 0, @"應該抽到一些二步驟題");
}

@end
