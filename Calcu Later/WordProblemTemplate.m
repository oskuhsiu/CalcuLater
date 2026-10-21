#import "WordProblemTemplate.h"
#import "GroupingStoryContext.h"

@implementation WordProblemTemplate

- (instancetype)initWithID:(NSString *)templateID
                     grade:(NSInteger)grade
                  operator:(NSString *)operatorSymbol
                   pattern:(NSString *)storyPattern
                      unit:(NSString *)unit
                      minA:(NSInteger)minA
                      maxA:(NSInteger)maxA
                      minB:(NSInteger)minB
                      maxB:(NSInteger)maxB
        requireAGreaterEqB:(BOOL)requireAGE
          requireDivisible:(BOOL)requireDiv
             missingAddend:(BOOL)missingAddend
         missingSubtrahend:(BOOL)missingSubtrahend
            missingMinuend:(BOOL)missingMinuend
          requireRemainder:(BOOL)requireRemainder
                 operator2:(NSString *)operator2
                      minC:(NSInteger)minC
                      maxC:(NSInteger)maxC
                isFraction:(BOOL)isFraction {
    return [self initWithID:templateID grade:grade operator:operatorSymbol pattern:storyPattern unit:unit
                      minA:minA maxA:maxA minB:minB maxB:maxB
        requireAGreaterEqB:requireAGE requireDivisible:requireDiv
             missingAddend:missingAddend missingSubtrahend:missingSubtrahend missingMinuend:missingMinuend
          requireRemainder:requireRemainder operator2:operator2 minC:minC maxC:maxC isFraction:isFraction
           groupingContext:nil strategyPattern:nil];
}

- (instancetype)initWithID:(NSString *)templateID
                     grade:(NSInteger)grade
                  operator:(NSString *)operatorSymbol
                   pattern:(NSString *)storyPattern
                      unit:(NSString *)unit
                      minA:(NSInteger)minA
                      maxA:(NSInteger)maxA
                      minB:(NSInteger)minB
                      maxB:(NSInteger)maxB
        requireAGreaterEqB:(BOOL)requireAGE
          requireDivisible:(BOOL)requireDiv
             missingAddend:(BOOL)missingAddend
         missingSubtrahend:(BOOL)missingSubtrahend
            missingMinuend:(BOOL)missingMinuend
          requireRemainder:(BOOL)requireRemainder
                 operator2:(NSString *)operator2
                      minC:(NSInteger)minC
                      maxC:(NSInteger)maxC
                isFraction:(BOOL)isFraction
           groupingContext:(GroupingStoryContext *)groupingContext
           strategyPattern:(NSString *)strategyPattern {
    self = [super init];
    if (self) {
        _templateID = [templateID copy];
        _grade = grade;
        _operatorSymbol = [operatorSymbol copy];
        _storyPattern = [storyPattern copy];
        _unit = [unit copy] ?: @"";
        _groupingContext = [groupingContext copy];
        _strategyPattern = [strategyPattern copy];
        _minA = minA;
        _maxA = maxA;
        _minB = minB;
        _maxB = maxB;
        _requireAGreaterEqualB = requireAGE;
        _requireDivisible = requireDiv;
        _missingAddend = missingAddend;
        _missingSubtrahend = missingSubtrahend;
        _missingMinuend = missingMinuend;
        _requireRemainder = requireRemainder;
        _operator2 = [operator2 copy];
        _minC = minC;
        _maxC = maxC;
        _isFraction = isFraction;
    }
    return self;
}

@end


#pragma mark - Catalog

/// These helpers are used only at the reviewed catalog call sites below. They do not
/// classify an arbitrary template by its ID, operation, answer unit or Chinese prose.
static WordProblemTemplate *WithTeaching(WordProblemTemplate *t, GroupingStoryContext *context, NSString *strategy) {
    return [[WordProblemTemplate alloc] initWithID:t.templateID grade:t.grade
                                         operator:t.operatorSymbol pattern:t.storyPattern unit:t.unit
                                             minA:t.minA maxA:t.maxA minB:t.minB maxB:t.maxB
                               requireAGreaterEqB:t.requireAGreaterEqualB requireDivisible:t.requireDivisible
                                    missingAddend:t.missingAddend missingSubtrahend:t.missingSubtrahend
                                   missingMinuend:t.missingMinuend requireRemainder:t.requireRemainder
                                        operator2:t.operator2 minC:t.minC maxC:t.maxC isFraction:t.isFraction
                                  groupingContext:context strategyPattern:strategy];
}

static WordProblemTemplate *TG(WordProblemTemplate *t, GroupingStoryMeaning meaning,
                               NSString *itemName, NSString *itemUnit, NSString *groupName, NSString *strategy) {
    GroupingStoryContext *context = [[GroupingStoryContext alloc] initWithMeaning:meaning
                                                                       itemName:itemName itemUnit:itemUnit
                                                                      groupName:groupName answerUnit:t.unit];
    return WithTeaching(t, context, strategy);
}

static WordProblemTemplate *TT(WordProblemTemplate *t, NSString *strategy) {
    return WithTeaching(t, nil, strategy);
}

/// 內部 helper：標準題型（無 missingAddend / 無餘數要求 / 單步驟）。
static WordProblemTemplate *T(NSString *tid, NSInteger grade, NSString *op,
                              NSString *pattern, NSString *unit,
                              NSInteger minA, NSInteger maxA,
                              NSInteger minB, NSInteger maxB,
                              BOOL aGEb, BOOL divisible) {
    return [[WordProblemTemplate alloc] initWithID:tid
                                              grade:grade
                                           operator:op
                                            pattern:pattern
                                               unit:unit
                                               minA:minA maxA:maxA
                                               minB:minB maxB:maxB
                                  requireAGreaterEqB:aGEb
                                    requireDivisible:divisible
                                       missingAddend:NO
                                   missingSubtrahend:NO
                                      missingMinuend:NO
                                    requireRemainder:NO
                                           operator2:nil
                                                minC:0 maxC:0
                                          isFraction:NO];
}

/// 未知數在前題型：operator 必為 "−"（內部以 a−b=ans 算出缺漏加數），
/// pattern 用 {b} 代「已知加數」、{a} 代「總和」，並在故事文字中明確點出「原本有幾顆 / 還缺幾個」。
/// requireAGreaterEqualB 設 YES 確保 ans > 0。
static WordProblemTemplate *TM(NSString *tid, NSInteger grade,
                               NSString *pattern, NSString *unit,
                               NSInteger minA, NSInteger maxA,
                               NSInteger minB, NSInteger maxB) {
    return [[WordProblemTemplate alloc] initWithID:tid
                                              grade:grade
                                           operator:@"−"
                                            pattern:pattern
                                               unit:unit
                                               minA:minA maxA:maxA
                                               minB:minB maxB:maxB
                                  requireAGreaterEqB:YES
                                    requireDivisible:NO
                                       missingAddend:YES
                                   missingSubtrahend:NO
                                      missingMinuend:NO
                                    requireRemainder:NO
                                           operator2:nil
                                                minC:0 maxC:0
                                          isFraction:NO];
}

/// 被減數未知 (missing minuend)：operator 必為 "+"（內部以 a+b=ans 算出被減數），
/// pattern 用 {a} 代「已知減數」、{b} 代「剩餘量」，等式渲染為「? − {n1} = {n2}」。
/// 故事為「原本有 ?，吃了 a 個，還剩 b 個」。
static WordProblemTemplate *TMM(NSString *tid, NSInteger grade,
                                NSString *pattern, NSString *unit,
                                NSInteger minA, NSInteger maxA,
                                NSInteger minB, NSInteger maxB) {
    return [[WordProblemTemplate alloc] initWithID:tid
                                              grade:grade
                                           operator:@"+"
                                            pattern:pattern
                                               unit:unit
                                               minA:minA maxA:maxA
                                               minB:minB maxB:maxB
                                  requireAGreaterEqB:NO
                                    requireDivisible:NO
                                       missingAddend:NO
                                   missingSubtrahend:NO
                                      missingMinuend:YES
                                    requireRemainder:NO
                                           operator2:nil
                                                minC:0 maxC:0
                                          isFraction:NO];
}

/// 未知數在中題型 (missing subtrahend)：operator 必為 "−"，等式渲染為「a − ? = b」。
/// pattern 用 {a} 代總量、{b} 代剩餘量；故事為「原有 a，拿走幾個後還剩 b」。
static WordProblemTemplate *TS(NSString *tid, NSInteger grade,
                               NSString *pattern, NSString *unit,
                               NSInteger minA, NSInteger maxA,
                               NSInteger minB, NSInteger maxB) {
    return [[WordProblemTemplate alloc] initWithID:tid
                                              grade:grade
                                           operator:@"−"
                                            pattern:pattern
                                               unit:unit
                                               minA:minA maxA:maxA
                                               minB:minB maxB:maxB
                                  requireAGreaterEqB:YES
                                    requireDivisible:NO
                                       missingAddend:NO
                                   missingSubtrahend:YES
                                      missingMinuend:NO
                                    requireRemainder:NO
                                           operator2:nil
                                                minC:0 maxC:0
                                          isFraction:NO];
}

/// 有餘數除法題型：operator 必為 "÷"，generator 會選出 a%b != 0 的組合。
/// 等式渲染為「a ÷ b = q⋯r」；目前題目只問商（answer = q），餘數僅顯示。
static WordProblemTemplate *TR(NSString *tid, NSInteger grade,
                               NSString *pattern, NSString *unit,
                               NSInteger minA, NSInteger maxA,
                               NSInteger minB, NSInteger maxB) {
    return [[WordProblemTemplate alloc] initWithID:tid
                                              grade:grade
                                           operator:@"÷"
                                            pattern:pattern
                                               unit:unit
                                               minA:minA maxA:maxA
                                               minB:minB maxB:maxB
                                  requireAGreaterEqB:NO
                                    requireDivisible:NO
                                       missingAddend:NO
                                   missingSubtrahend:NO
                                      missingMinuend:NO
                                    requireRemainder:YES
                                           operator2:nil
                                                minC:0 maxC:0
                                          isFraction:NO];
}

/// 分數識別題：minA/maxA = 分子範圍、minB/maxB = 分母範圍。
/// generator 會強制 a < b（真分數）；pattern 用 {a} 代分子、{b} 代分母。
/// operator 設 "+"（無實質意義，僅占位避免 dispatch 出錯）。
static WordProblemTemplate *TF(NSString *tid, NSInteger grade,
                               NSString *pattern, NSString *unit,
                               NSInteger minA, NSInteger maxA,
                               NSInteger minB, NSInteger maxB) {
    return [[WordProblemTemplate alloc] initWithID:tid
                                              grade:grade
                                           operator:@"+"
                                            pattern:pattern
                                               unit:unit
                                               minA:minA maxA:maxA
                                               minB:minB maxB:maxB
                                  requireAGreaterEqB:NO
                                    requireDivisible:NO
                                       missingAddend:NO
                                   missingSubtrahend:NO
                                      missingMinuend:NO
                                    requireRemainder:NO
                                           operator2:nil
                                                minC:0 maxC:0
                                          isFraction:YES];
}

/// 二步驟題型（a OP1 b OP2 c）：op 與 op2 只能是 "+" 或 "−"（同優先級）。
/// pattern 同時用 {a} {b} {c}；故事必須暗示三個數字、一個未知數。
/// requireAGreaterEqB=NO；generator 會檢查中間結果與最終答案皆 > 0。
static WordProblemTemplate *T2(NSString *tid, NSInteger grade,
                               NSString *op1, NSString *op2,
                               NSString *pattern, NSString *unit,
                               NSInteger minA, NSInteger maxA,
                               NSInteger minB, NSInteger maxB,
                               NSInteger minC, NSInteger maxC) {
    return [[WordProblemTemplate alloc] initWithID:tid
                                              grade:grade
                                           operator:op1
                                            pattern:pattern
                                               unit:unit
                                               minA:minA maxA:maxA
                                               minB:minB maxB:maxB
                                  requireAGreaterEqB:NO
                                    requireDivisible:NO
                                       missingAddend:NO
                                   missingSubtrahend:NO
                                      missingMinuend:NO
                                    requireRemainder:NO
                                           operator2:op2
                                                minC:minC maxC:maxC
                                          isFraction:NO];
}

@implementation WordProblemCatalog

#pragma mark - Grade 1（108 課綱：100 以內加減）

// 對應 108 課綱：
//   N-1-2 / N-1-3：基本加減算式（20 以內為基礎）
//   N-1-4 / N-1-5：二位數加減一位數（不退位 → 退位）
//   N-1-6：100 以內的數的認識；加減進階
// 因此題庫覆蓋三段難度：
//   (a) 20 以內基礎（讓低年級新手有成就感）
//   (b) 100 以內不進退位（兩位數 + / − 一位數、整十相加等）
//   (c) 100 以內進退位（強化進階）
+ (NSArray<WordProblemTemplate *> *)grade1Templates {
    NSMutableArray *arr = [NSMutableArray array];

    // — 加法 a：20 以內基礎（個位 + 個位） —
    [arr addObject:T(@"g1_add_candy",    1, @"+", @"小明有 {a} 顆糖果，小美又給他 {b} 顆，小明現在有幾顆糖果？", @"顆", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_flower",   1, @"+", @"花瓶裡有 {a} 朵花，媽媽又插了 {b} 朵，花瓶裡現在有幾朵花？", @"朵", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_duck",     1, @"+", @"池塘裡有 {a} 隻小鴨，又游來了 {b} 隻，現在共有幾隻小鴨？", @"隻", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_cookie",   1, @"+", @"盤子裡有 {a} 塊餅乾，媽媽再放了 {b} 塊，盤子裡共有幾塊餅乾？", @"塊", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_sticker",  1, @"+", @"哥哥有 {a} 張貼紙，姐姐比哥哥多 {b} 張，姐姐有幾張貼紙？", @"張", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_balloon",  1, @"+", @"小華手上有 {a} 個氣球，媽媽又給他 {b} 個，小華現在有幾個氣球？", @"個", 1, 9, 1, 9, NO, NO)];

    // — 加法 b：100 以內不進位（兩位數 + 一位數 / 兩位數 + 整十 / 整十 + 整十） —
    [arr addObject:T(@"g1_add_book2",    1, @"+", @"書架上有 {a} 本書，再放上去 {b} 本，書架上共有幾本書？", @"本", 10, 90, 1, 9, NO, NO)];      // 兩位+一位 不進位
    [arr addObject:T(@"g1_add_kids2",    1, @"+", @"公園裡有 {a} 個小朋友在玩，又來了 {b} 個小朋友，現在有幾個小朋友？", @"個", 11, 80, 1, 8, NO, NO)];
    [arr addObject:T(@"g1_add_apple2",   1, @"+", @"樹上原本有 {a} 個蘋果，又長出 {b} 個，樹上共有幾個蘋果？", @"個", 20, 60, 10, 30, NO, NO)];     // 兩位+兩位 不進位（個位都 0）
    [arr addObject:T(@"g1_add_egg2",     1, @"+", @"冰箱裡有 {a} 顆蛋，媽媽再買 {b} 顆放進去，冰箱裡共有幾顆蛋？", @"顆", 10, 50, 10, 40, NO, NO)];
    [arr addObject:T(@"g1_add_pencil2",  1, @"+", @"鉛筆盒裡有 {a} 枝鉛筆，再放進 {b} 枝，鉛筆盒裡共有幾枝鉛筆？", @"枝", 20, 70, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_money1",   1, @"+", @"小華有 {a} 元，媽媽再給他 {b} 元，小華現在有幾元？", @"元", 10, 80, 1, 9, NO, NO)];

    // — 加法 c：100 以內進位（兩位數 + 一位數 / 個位數和 ≥ 10） —
    [arr addObject:T(@"g1_add_fish2",    1, @"+", @"魚缸裡有 {a} 條金魚，爸爸又買 {b} 條放進去，魚缸裡共有幾條金魚？", @"條", 14, 88, 4, 9, NO, NO)];
    [arr addObject:T(@"g1_add_bus2",     1, @"+", @"公車上原本有 {a} 個乘客，下一站又上來 {b} 個，公車上現在有幾個乘客？", @"個", 15, 85, 5, 9, NO, NO)];
    [arr addObject:T(@"g1_add_toy2",     1, @"+", @"箱子裡有 {a} 個玩具，弟弟又放進 {b} 個，箱子裡共有幾個玩具？", @"個", 16, 80, 4, 9, NO, NO)];

    // — 減法 a：20 以內基礎（含退位） —
    [arr addObject:T(@"g1_sub_candy",    1, @"−", @"盤子裡有 {a} 顆糖果，小明吃掉 {b} 顆，盤子裡還剩幾顆糖果？", @"顆", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_kids",     1, @"−", @"公園裡有 {a} 個小朋友，{b} 個小朋友回家了，公園裡還剩幾個小朋友？", @"個", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_card",     1, @"−", @"小華有 {a} 張卡片，給弟弟 {b} 張，小華還剩幾張卡片？", @"張", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_bird",     1, @"−", @"樹上有 {a} 隻小鳥，飛走了 {b} 隻，樹上還剩幾隻小鳥？", @"隻", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_diff_age", 1, @"−", @"姐姐 {a} 歲，妹妹 {b} 歲，姐姐比妹妹大幾歲？", @"歲", 5, 15, 1, 8, YES, NO)];

    // — 減法 b：100 以內不退位（兩位 − 一位 / 兩位 − 整十） —
    [arr addObject:T(@"g1_sub_egg2",     1, @"−", @"媽媽有 {a} 顆雞蛋，做蛋糕用掉 {b} 顆，還剩幾顆雞蛋？", @"顆", 25, 99, 1, 9, YES, NO)];        // 個位 a≥b 不退位（靠 a 的個位通常大），偶會退位但無妨
    [arr addObject:T(@"g1_sub_apple2",   1, @"−", @"水果店裡有 {a} 顆蘋果，賣掉了 {b} 顆，還剩幾顆蘋果？", @"顆", 30, 99, 10, 40, YES, NO)];
    [arr addObject:T(@"g1_sub_seat2",    1, @"−", @"教室裡有 {a} 個座位，坐了 {b} 個小朋友，還有幾個空位？", @"個", 30, 90, 10, 50, YES, NO)];
    [arr addObject:T(@"g1_sub_money1",   1, @"−", @"小明有 {a} 元，買糖花了 {b} 元，還剩幾元？", @"元", 20, 90, 5, 50, YES, NO)];

    // — 減法 c：100 以內退位 / 比較差量 —
    [arr addObject:T(@"g1_sub_flower2",  1, @"−", @"花園裡有 {a} 朵花，被風吹掉了 {b} 朵，還剩幾朵花？", @"朵", 24, 92, 8, 35, YES, NO)];
    [arr addObject:T(@"g1_sub_cookie2",  1, @"−", @"罐子裡有 {a} 塊餅乾，小華吃掉 {b} 塊，罐子裡還剩幾塊餅乾？", @"塊", 22, 95, 8, 38, YES, NO)];
    [arr addObject:T(@"g1_sub_diff_pencil2", 1, @"−", @"哥哥有 {a} 枝鉛筆，弟弟有 {b} 枝鉛筆，哥哥比弟弟多幾枝鉛筆？", @"枝", 20, 80, 8, 45, YES, NO)];
    [arr addObject:T(@"g1_sub_need2",    1, @"−", @"媽媽要做 {a} 個飯糰，已經做好 {b} 個，還要做幾個？", @"個", 30, 90, 10, 50, YES, NO)];
    [arr addObject:T(@"g1_sub_book2",    1, @"−", @"小華要讀完 {a} 本書，已經讀完 {b} 本，還剩幾本沒讀？", @"本", 25, 80, 8, 40, YES, NO)];

    // — 未知數在前（missing addend）：等式渲染為「? + b = a」，{a} 是總和、{b} 是已知加數 —
    [arr addObject:TM(@"g1_miss_candy",   1, @"盤子裡原本有幾顆糖果？又放進 {b} 顆後，盤子裡共有 {a} 顆糖果。", @"顆", 5, 18, 1, 9)];
    [arr addObject:TM(@"g1_miss_kids",    1, @"公園裡原本有幾個小朋友？又來了 {b} 個小朋友後，公園裡共有 {a} 個。", @"個", 5, 18, 1, 9)];
    [arr addObject:TM(@"g1_miss_money",   1, @"小華原本有幾元？媽媽再給他 {b} 元後，小華現在有 {a} 元。", @"元", 12, 80, 5, 30)];
    [arr addObject:TM(@"g1_miss_book",    1, @"書架上原本有幾本書？又放上去 {b} 本後，書架上共有 {a} 本書。", @"本", 12, 60, 4, 25)];
    [arr addObject:TM(@"g1_miss_bus",     1, @"公車原本有幾個乘客？下一站又上來 {b} 個後，公車上共有 {a} 個乘客。", @"位", 15, 70, 5, 25)];
    [arr addObject:TM(@"g1_miss_egg",     1, @"冰箱原本有幾顆蛋？媽媽再買 {b} 顆放進去後，冰箱裡共有 {a} 顆蛋。", @"顆", 14, 60, 6, 30)];

    // — 未知數在中（missing subtrahend）：等式渲染為「a − ? = b」，{a} 是總量、{b} 是剩餘量 —
    [arr addObject:TS(@"g1_subt_candy",   1, @"小明原本有 {a} 顆糖果，吃了幾顆後還剩 {b} 顆，他吃了幾顆？", @"顆", 6, 18, 1, 9)];
    [arr addObject:TS(@"g1_subt_bird",    1, @"樹上原有 {a} 隻小鳥，飛走幾隻後還剩 {b} 隻，飛走了幾隻？", @"隻", 6, 18, 1, 9)];
    [arr addObject:TS(@"g1_subt_money",   1, @"小華原有 {a} 元，買糖花了幾元後還剩 {b} 元，買糖花了幾元？", @"元", 25, 90, 8, 55)];
    [arr addObject:TS(@"g1_subt_seat",    1, @"教室原有 {a} 個小朋友，回家幾個後還剩 {b} 個，回家了幾個？", @"個", 18, 60, 6, 35)];

    // — 被減數未知（missing minuend）：等式渲染為「? − {a} = {b}」，{a} 已知減數、{b} 剩餘 —
    // 範圍要讓「拿走的 (a)」與「剩下的 (b)」量級相近，避免出現「回家 3 個還剩 60 個」這種
    // 數學正確但敘事奇怪的故事（小孩會看不懂為什麼只有 3 個離開）。
    [arr addObject:TMM(@"g1_minu_candy",  1, @"盤子原本有幾顆糖果？吃掉 {a} 顆後還剩 {b} 顆，盤子裡原本有幾顆？", @"顆", 3, 9, 1, 9)];
    [arr addObject:TMM(@"g1_minu_kids",   1, @"教室原本有幾個小朋友？回家 {a} 個後還剩 {b} 個，教室原本有幾個小朋友？", @"個", 8, 35, 8, 40)];
    [arr addObject:TMM(@"g1_minu_money",  1, @"小華原有多少元？花了 {a} 元後還剩 {b} 元，小華原本有幾元？", @"元", 15, 50, 10, 45)];

    // — 比較型「少」（求較小量）：「乙比甲少 b → a − b」，補足原本只有「多 b」的比較題 —
    [arr addObject:T(@"g1_sub_less_marble",  1, @"−", @"哥哥有 {a} 顆彈珠，弟弟比哥哥少 {b} 顆，弟弟有幾顆彈珠？", @"顆", 5, 18, 1, 8, YES, NO)];
    [arr addObject:T(@"g1_sub_less_sticker", 1, @"−", @"姐姐有 {a} 張貼紙，妹妹比姐姐少 {b} 張，妹妹有幾張貼紙？", @"張", 6, 18, 1, 8, YES, NO)];

    // — 序數→基數（排隊問題）：「從前面數第 a 個，後面還有 b 個 → 全隊 a + b」 —
    [arr addObject:T(@"g1_add_order_ticket", 1, @"+", @"排隊買票，從前面數小明是第 {a} 個，他後面還有 {b} 個人，這一排共有幾個人？", @"個", 2, 12, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_order_slide",  1, @"+", @"溜滑梯排隊，從前面數小華是第 {a} 個，後面還有 {b} 個人，這一排共有幾個人？", @"個", 2, 10, 1, 9, NO, NO)];

    // — 年齡（幾年後 a + b / 幾年前 a − b） —
    [arr addObject:T(@"g1_add_age_future",   1, @"+", @"小明今年 {a} 歲，再過 {b} 年他幾歲？", @"歲", 5, 12, 1, 8, NO, NO)];
    [arr addObject:T(@"g1_sub_age_past",     1, @"−", @"姐姐今年 {a} 歲，{b} 年前她幾歲？", @"歲", 8, 15, 1, 7, YES, NO)];

    // — 二步驟「連續式」題（連加 / 連減 / 加減混合）：對應 108 課綱 N-1 連加、連減、加減混合，
    //   以 20 以內為主。generator 會確保中間結果與最終答案皆 > 0。 —
    [arr addObject:T2(@"g1_two_addadd",    1, @"+", @"+", @"小明有 {a} 顆糖果，哥哥給他 {b} 顆，姐姐又給他 {c} 顆，小明現在共有幾顆糖果？", @"顆", 2, 8, 1, 6, 1, 5)];
    [arr addObject:T2(@"g1_two_busadd",    1, @"+", @"+", @"公車上有 {a} 個人，第一站上來 {b} 個，第二站又上來 {c} 個，現在車上有幾個人？", @"個", 3, 9, 1, 6, 1, 5)];
    [arr addObject:T2(@"g1_two_flower",    1, @"+", @"+", @"花瓶裡有 {a} 朵花，媽媽插了 {b} 朵，姐姐又插了 {c} 朵，花瓶裡共有幾朵花？", @"朵", 2, 8, 1, 5, 1, 5)];
    [arr addObject:T2(@"g1_two_subsub",    1, @"−", @"−", @"盤子裡有 {a} 顆糖果，小明先吃了 {b} 顆，又吃了 {c} 顆，盤子裡還剩幾顆糖果？", @"顆", 10, 18, 2, 6, 1, 5)];
    [arr addObject:T2(@"g1_two_bird",      1, @"−", @"−", @"樹上有 {a} 隻小鳥，飛走了 {b} 隻，又飛走了 {c} 隻，樹上還剩幾隻小鳥？", @"隻", 11, 18, 2, 6, 1, 5)];
    [arr addObject:T2(@"g1_two_mix_as",    1, @"+", @"−", @"小華有 {a} 元，媽媽給他 {b} 元，買貼紙花了 {c} 元，小華還剩幾元？", @"元", 5, 12, 3, 8, 2, 7)];
    [arr addObject:T2(@"g1_two_mix_sa",    1, @"−", @"+", @"公園裡有 {a} 個小朋友，{b} 個回家了，又來了 {c} 個，現在公園裡有幾個小朋友？", @"個", 8, 15, 2, 7, 1, 6)];

    return [arr copy];
}

#pragma mark - Grade 2（108 課綱：1000 以內加減 + 九九乘法 + 量與測量）

// 對應 108 課綱：
//   N-2-1：1000 以內的數的認識
//   N-2-2 / N-2-3：1000 以內加減（含進退位）
//   N-2-6 / N-2-7：乘法（九九乘法表）、同數累加
//   N-2-9：長度（公分、公尺、毫米的概念）
//   N-2-10：時間（時、分、日、週、月）
//   N-2-11：重量（公斤、公克的初步概念）
+ (NSArray<WordProblemTemplate *> *)grade2Templates {
    NSMutableArray *arr = [NSMutableArray array];

    // — 加法（百位數 / 三位數 + 二位數，含進位） —
    [arr addObject:T(@"g2_add_class",     2, @"+", @"一年一班有 {a} 個學生，二班有 {b} 個學生，兩班共有幾個學生？", @"個", 15, 35, 15, 35, NO, NO)];
    [arr addObject:T(@"g2_add_ball",      2, @"+", @"體育館有 {a} 顆紅球，{b} 顆藍球，紅球和藍球共有幾顆？", @"顆", 60, 280, 40, 220, NO, NO)];
    [arr addObject:T(@"g2_add_books",     2, @"+", @"學校買了 {a} 本數學書、{b} 本國語書，共買了幾本書？", @"本", 120, 480, 80, 380, NO, NO)];
    [arr addObject:T(@"g2_add_money",     2, @"+", @"鉛筆 {a} 元、書包 {b} 元，買兩樣共要付幾元？", @"元", 35, 180, 80, 380, NO, NO)];
    [arr addObject:T(@"g2_add_meals",     2, @"+", @"早上煮了 {a} 個包子、下午又煮了 {b} 個，今天共煮了幾個包子？", @"個", 45, 280, 38, 280, NO, NO)];
    [arr addObject:T(@"g2_add_visitors",  2, @"+", @"上午來了 {a} 位客人，下午又來了 {b} 位，今天共來了幾位客人？", @"位", 85, 380, 55, 280, NO, NO)];
    [arr addObject:T(@"g2_add_save",      2, @"+", @"哥哥存了 {a} 元，弟弟存了 {b} 元，他們一共存了幾元？", @"元", 125, 480, 85, 380, NO, NO)];
    [arr addObject:T(@"g2_add_pages",     2, @"+", @"小明昨天讀了 {a} 頁書，今天又讀了 {b} 頁，這兩天共讀了幾頁？", @"頁", 28, 280, 35, 280, NO, NO)];
    [arr addObject:T(@"g2_add_stamp",     2, @"+", @"姐姐收集了 {a} 張郵票，妹妹收集了 {b} 張郵票，兩人共收集了幾張郵票？", @"張", 85, 380, 65, 280, NO, NO)];
    [arr addObject:T(@"g2_add_gender",    2, @"+", @"班上有男生 {a} 人，女生 {b} 人，全班共有幾人？", @"人", 8, 30, 8, 30, NO, NO)];

    // — 減法（含退位，最大 999） —
    [arr addObject:T(@"g2_sub_change",    2, @"−", @"媽媽帶 {a} 元去買菜，花了 {b} 元，還剩幾元？", @"元", 250, 980, 85, 380, YES, NO)];
    [arr addObject:T(@"g2_sub_pages",     2, @"−", @"一本書共有 {a} 頁，小明已經讀了 {b} 頁，還剩幾頁沒讀？", @"頁", 180, 720, 55, 320, YES, NO)];
    [arr addObject:T(@"g2_sub_cards",     2, @"−", @"哥哥蒐集 {a} 張卡片，送給朋友 {b} 張後，哥哥還剩幾張卡片？", @"張", 220, 880, 65, 380, YES, NO)];
    [arr addObject:T(@"g2_sub_diff_kids", 2, @"−", @"A 班有 {a} 個學生，B 班有 {b} 個學生，A 班比 B 班多幾個學生？", @"個", 120, 480, 55, 220, YES, NO)];
    [arr addObject:T(@"g2_sub_sold",      2, @"−", @"麵包店做了 {a} 個麵包，賣掉 {b} 個，還剩幾個麵包？", @"個", 180, 720, 55, 320, YES, NO)];
    [arr addObject:T(@"g2_sub_save_left", 2, @"−", @"小華原本有 {a} 元，買玩具花了 {b} 元，還剩幾元？", @"元", 280, 980, 85, 380, YES, NO)];
    [arr addObject:T(@"g2_sub_seats",     2, @"−", @"禮堂有 {a} 個座位，坐了 {b} 個人，還有幾個空位？", @"個", 320, 880, 95, 380, YES, NO)];
    [arr addObject:T(@"g2_sub_short",     2, @"−", @"媽媽要 {a} 元才能買玩具，已經存了 {b} 元，還差幾元？", @"元", 280, 880, 85, 380, YES, NO)];

    // — 量與測量：長度（公分、公尺） —
    [arr addObject:T(@"g2_len_cm_total",  2, @"+", @"鉛筆長 {a} 公分，原子筆比鉛筆長 {b} 公分，原子筆有幾公分？", @"公分", 8, 20, 1, 10, NO, NO)];
    [arr addObject:T(@"g2_len_m_total",   2, @"+", @"繩子甲長 {a} 公尺、繩子乙長 {b} 公尺，兩條繩子接起來共幾公尺？", @"公尺", 8, 60, 5, 50, NO, NO)];
    [arr addObject:T(@"g2_len_walk_left", 2, @"−", @"從家裡到便利商店共 {a} 公尺，小華已經走了 {b} 公尺，還要再走幾公尺？", @"公尺", 60, 350, 25, 180, YES, NO)];
    [arr addObject:T(@"g2_len_height_diff", 2, @"−", @"哥哥身高 {a} 公分，弟弟身高 {b} 公分，哥哥比弟弟高幾公分？", @"公分", 115, 165, 95, 130, YES, NO)];

    // — 量與測量：時間（分鐘 / 小時） —
    [arr addObject:T(@"g2_time_min_total", 2, @"+", @"小明寫功課花了 {a} 分鐘，看課外書花了 {b} 分鐘，共花了幾分鐘？", @"分鐘", 15, 50, 10, 45, NO, NO)];
    [arr addObject:T(@"g2_time_min_left",  2, @"−", @"一節課 {a} 分鐘，已經上了 {b} 分鐘，還剩幾分鐘下課？", @"分鐘", 40, 80, 15, 55, YES, NO)];

    // — 量與測量：重量（公斤 / 公克） —
    [arr addObject:T(@"g2_wt_kg_total",   2, @"+", @"哥哥體重 {a} 公斤，弟弟體重 {b} 公斤，兩人體重共幾公斤？", @"公斤", 22, 45, 18, 38, NO, NO)];
    [arr addObject:T(@"g2_wt_g_diff",     2, @"−", @"一袋米 {a} 公克，倒出 {b} 公克煮飯後，還剩幾公克？", @"公克", 280, 900, 80, 380, YES, NO)];

    // — 乘法（九九乘法範圍） —
    [arr addObject:TG(T(@"g2_mul_dumpling",  2, @"×", @"每盤水餃有 {a} 個，{b} 盤共有幾個水餃？", @"個", 2, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"水餃", @"個", @"盤", @"每盤有 {a} 個水餃，共有 {b} 盤。把每盤一樣多的水餃合起來，求總數。")];
    [arr addObject:TG(T(@"g2_mul_row",       2, @"×", @"教室裡每排有 {a} 個學生，共有 {b} 排，教室裡共有幾個學生？", @"個", 2, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"學生", @"個", @"排", @"每排有 {a} 個學生，共有 {b} 排。把每排一樣多的學生人數合起來。")];
    [arr addObject:TG(T(@"g2_mul_day_page",  2, @"×", @"小明每天讀 {a} 頁書，{b} 天共讀了幾頁書？", @"頁", 2, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"書", @"頁", @"天", @"每天都讀 {a} 頁書，連續讀了 {b} 天。把每天讀的頁數合起來，求總頁數。")];
    [arr addObject:TG(T(@"g2_mul_legs_dog",  2, @"×", @"每隻狗有 4 條腿，{b} 隻狗共有幾條腿？", @"條", 4, 4, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"腿", @"條", @"隻狗", @"每隻狗有 {a} 條腿，共有 {b} 隻狗。這裡要累加的是腿的條數，不是狗的隻數。")];
    [arr addObject:TG(T(@"g2_mul_flower",    2, @"×", @"一束花有 {a} 朵，{b} 束花共有幾朵？", @"朵", 3, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"花", @"朵", @"束", @"每束有 {a} 朵花，共有 {b} 束。把每束一樣多的花合起來，求總朵數。")];
    [arr addObject:TG(T(@"g2_mul_candy",     2, @"×", @"一盒糖果有 {a} 顆，{b} 盒共有幾顆糖果？", @"顆", 4, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"糖果", @"顆", @"盒", @"每盒有 {a} 顆糖果，共有 {b} 盒。把每盒一樣多的糖果合起來，求總顆數。")];
    [arr addObject:TG(T(@"g2_mul_basket",    2, @"×", @"每籃裝 {a} 顆蘋果，{b} 籃共有幾顆蘋果？", @"顆", 4, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"蘋果", @"顆", @"籃", @"每籃有 {a} 顆蘋果，共有 {b} 籃。把每籃一樣多的蘋果合起來。")];
    [arr addObject:TG(T(@"g2_mul_wheel",     2, @"×", @"每台車有 {a} 個輪子，{b} 台車共有幾個輪子？", @"個", 3, 4, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"輪子", @"個", @"台車", @"每台車有 {a} 個輪子，共有 {b} 台車。這裡要累加的是輪子的個數，不是車的台數。")];
    [arr addObject:TG(T(@"g2_mul_finger",    2, @"×", @"每隻手有 {a} 根手指，{b} 隻手共有幾根手指？", @"根", 5, 5, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"手指", @"根", @"隻手", @"每隻手有 {a} 根手指，共有 {b} 隻手。把每隻手的手指根數合起來。")];
    [arr addObject:TT(T(@"g2_mul_age",       2, @"×", @"弟弟 {b} 歲，哥哥的年紀是弟弟的 {a} 倍，哥哥幾歲？", @"歲", 2, 5, 3, 9, NO, NO), @"先看弟弟的年齡：{b} 歲。哥哥是弟弟的 {a} 倍，所以把 {b} 歲重複 {a} 次。")];
    [arr addObject:TG(T(@"g2_mul_packet",    2, @"×", @"一包餅乾有 {a} 塊，買 {b} 包共有幾塊餅乾？", @"塊", 3, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"餅乾", @"塊", @"包", @"每包有 {a} 塊餅乾，共有 {b} 包。把每包一樣多的餅乾合起來。")];
    [arr addObject:TG(T(@"g2_mul_egg_box",   2, @"×", @"一盒雞蛋裝 {a} 顆，{b} 盒共有幾顆雞蛋？", @"顆", 6, 9, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"雞蛋", @"顆", @"盒", @"每盒有 {a} 顆雞蛋，共有 {b} 盒。把每盒一樣多的雞蛋合起來。")];
    [arr addObject:TG(T(@"g2_mul_chair",     2, @"×", @"每張桌子配 {a} 把椅子，{b} 張桌子共配幾把椅子？", @"把", 2, 6, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"椅子", @"把", @"張桌子", @"每張桌子配 {a} 把椅子，共有 {b} 張桌子。把每張桌子需要的椅子把數合起來。")];
    [arr addObject:TG(T(@"g2_mul_jiaozi",    2, @"×", @"每碗麵放 {a} 顆貢丸，{b} 碗共需要幾顆貢丸？", @"顆", 2, 5, 2, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"貢丸", @"顆", @"碗麵", @"每碗麵放 {a} 顆貢丸，共有 {b} 碗麵。把每碗需要的貢丸顆數合起來。")];

    // — 未知數在前（百以內，配合 G2 進階加減）—
    [arr addObject:TM(@"g2_miss_save",    2, @"小華原本存了幾元？媽媽再給他 {b} 元後，存錢筒裡共有 {a} 元。", @"元", 45, 380, 25, 180)];
    [arr addObject:TM(@"g2_miss_pages",   2, @"小明前天讀了幾頁書？昨天又讀了 {b} 頁後，這兩天共讀了 {a} 頁。", @"頁", 35, 220, 18, 120)];
    [arr addObject:TM(@"g2_miss_class",   2, @"一班原本有幾個學生？又轉入 {b} 個學生後，一班共有 {a} 個學生。", @"個", 25, 60, 5, 25)];
    [arr addObject:TM(@"g2_miss_stamp",   2, @"姐姐原本收集幾張郵票？阿姨再給她 {b} 張後，姐姐共有 {a} 張郵票。", @"張", 45, 350, 25, 180)];

    // — 比較型「少」（求較小量，含退位）—
    [arr addObject:T(@"g2_sub_less_class", 2, @"−", @"甲班有 {a} 個學生，乙班比甲班少 {b} 個，乙班有幾個學生？", @"個", 20, 38, 3, 15, YES, NO)];
    [arr addObject:T(@"g2_sub_less_save",  2, @"−", @"哥哥存了 {a} 元，弟弟比哥哥少存 {b} 元，弟弟存了幾元？", @"元", 120, 680, 30, 280, YES, NO)];

    // — 序數→基數（排隊問題，較大數） —
    [arr addObject:T(@"g2_add_order",      2, @"+", @"運動會排隊，從前面數小明是第 {a} 個，後面還有 {b} 個人，這一隊共有幾個人？", @"個", 5, 25, 5, 25, NO, NO)];

    // — 總價＝單價 × 數量（乘法的「錢」情境） —
    [arr addObject:TT(T(@"g2_mul_price_pen",  2, @"×", @"一枝筆 {a} 元，買 {b} 枝共要付幾元？", @"元", 5, 9, 2, 9, NO, NO), @"一枝筆要 {a} 元，買 {b} 枝。把每枝的價錢累加 {b} 次，求的是總價，不是筆的枝數。")];
    [arr addObject:TT(T(@"g2_mul_price_snack",2, @"×", @"一包餅乾 {a} 元，買 {b} 包共要付幾元？", @"元", 6, 9, 2, 9, NO, NO), @"一包餅乾要 {a} 元，買 {b} 包。把每包的價錢累加 {b} 次，求的是總價，不是餅乾的塊數。")];

    // — 二步驟題（同優先級 a±b±c）：對應 N-2-2「二步驟解題」 —
    [arr addObject:T2(@"g2_two_threeday", 2, @"+", @"+", @"小明第一天讀了 {a} 頁、第二天讀了 {b} 頁、第三天讀了 {c} 頁，三天共讀了幾頁？", @"頁", 25, 120, 18, 95, 15, 90)];
    [arr addObject:T2(@"g2_two_change",   2, @"+", @"−", @"哥哥有 {a} 元，姐姐再給他 {b} 元，後來買糖花了 {c} 元，哥哥還剩幾元？", @"元", 25, 80, 15, 60, 12, 50)];
    [arr addObject:T2(@"g2_two_classin",  2, @"+", @"−", @"班上原有 {a} 人，又轉入 {b} 人，後來 {c} 人請假，今天班上有幾人？", @"人", 22, 35, 3, 8, 2, 6)];
    [arr addObject:T2(@"g2_two_busride",  2, @"+", @"−", @"公車上原有 {a} 人，上車 {b} 人後又下車 {c} 人，公車上現在有幾人？", @"人", 18, 45, 8, 25, 5, 20)];
    [arr addObject:T2(@"g2_two_orchard",  2, @"−", @"−", @"果園有 {a} 顆蘋果，賣出 {b} 顆後，又被小鳥吃掉 {c} 顆，還剩幾顆蘋果？", @"顆", 80, 280, 25, 95, 8, 35)];
    [arr addObject:T2(@"g2_two_combine",  2, @"+", @"+", @"上午來了 {a} 位客人，中午來 {b} 位、下午來 {c} 位，今天共來幾位客人？", @"位", 25, 120, 18, 95, 22, 110)];
    [arr addObject:T2(@"g2_two_book",     2, @"−", @"−", @"一本書共 {a} 頁，小明今天讀了 {b} 頁、昨天讀了 {c} 頁，還剩幾頁沒讀？", @"頁", 60, 180, 18, 65, 12, 45)];

    return [arr copy];
}

#pragma mark - Grade 3（108 課綱：10000 以內加減 + 二三位數×一位數 + 除法 + 單位換算）

// 對應 108 課綱：
//   N-3-1：10000 以內的數的認識
//   N-3-2 / N-3-3：10000 以內加減（含進退位）
//   N-3-4：乘法（二三位數 × 一位數）
//   N-3-5：除法（除數為一位數的整除問題）
//   N-3-12 / N-3-13：時間（時、分、秒；單位換算）、長度（公里、公尺、公分）、容量（公升、毫升）、重量（公斤、公克）
//   ※ 有餘數除法、分數初步：需擴展 WordProblem model（待辦）
+ (NSArray<WordProblemTemplate *> *)grade3Templates {
    NSMutableArray *arr = [NSMutableArray array];

    // — 加法（四位數，10000 以內） —
    [arr addObject:T(@"g3_add_school",    3, @"+", @"學校原本有 {a} 位學生，今年又轉入 {b} 位，學校現在共有幾位學生？", @"位", 1250, 4800, 250, 1200, NO, NO)];
    [arr addObject:T(@"g3_add_library",   3, @"+", @"圖書館上午借出 {a} 本書，下午借出 {b} 本，今天共借出幾本書？", @"本", 380, 3800, 250, 2800, NO, NO)];
    [arr addObject:T(@"g3_add_money",     3, @"+", @"媽媽買菜花了 {a} 元，買水果花了 {b} 元，共花了幾元？", @"元", 285, 2800, 180, 1500, NO, NO)];
    [arr addObject:T(@"g3_add_zoo",       3, @"+", @"動物園今年來了 {a} 位大人和 {b} 位小朋友參觀，共幾位訪客？", @"位", 850, 4500, 450, 2800, NO, NO)];
    [arr addObject:T(@"g3_add_factory",   3, @"+", @"工廠上週生產 {a} 個產品，這週生產 {b} 個，兩週共生產幾個產品？", @"個", 1200, 4600, 850, 3800, NO, NO)];
    [arr addObject:T(@"g3_add_distance",  3, @"+", @"小華家到學校 {a} 公尺，學校到圖書館 {b} 公尺，小華家經過學校到圖書館共幾公尺？", @"公尺", 450, 2800, 280, 2200, NO, NO)];

    // — 減法（四位數） —
    [arr addObject:T(@"g3_sub_orchard",   3, @"−", @"果園有 {a} 顆蘋果，賣出 {b} 顆，還剩幾顆蘋果？", @"顆", 2850, 8500, 380, 2800, YES, NO)];
    [arr addObject:T(@"g3_sub_distance",  3, @"−", @"從家裡到外婆家 {a} 公尺，小華已經走了 {b} 公尺，還要再走幾公尺？", @"公尺", 1850, 8500, 450, 3800, YES, NO)];
    [arr addObject:T(@"g3_sub_savings",   3, @"−", @"哥哥存了 {a} 元，弟弟存了 {b} 元，哥哥比弟弟多存幾元？", @"元", 1280, 6500, 380, 2800, YES, NO)];
    [arr addObject:T(@"g3_sub_inventory", 3, @"−", @"倉庫原本有 {a} 箱貨物，運出 {b} 箱後，倉庫還剩幾箱貨物？", @"箱", 1280, 7800, 380, 3800, YES, NO)];
    [arr addObject:T(@"g3_sub_visitor",   3, @"−", @"今天博物館共有 {a} 位訪客，上午來了 {b} 位，下午來了幾位訪客？", @"位", 1850, 8500, 480, 3800, YES, NO)];
    [arr addObject:T(@"g3_sub_pages2",    3, @"−", @"一套書共 {a} 頁，小明已經讀了 {b} 頁，還剩幾頁沒讀？", @"頁", 1280, 6500, 380, 2800, YES, NO)];

    // — 乘法（一位數 × 二位數） —
    [arr addObject:TG(T(@"g3_mul_class_size", 3, @"×", @"每班有 {a} 個學生，學校有 {b} 班，全校共有幾個學生？", @"個", 20, 35, 3, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"學生", @"個", @"班", @"每班有 {a} 個學生，共有 {b} 班。把各班一樣多的學生人數合起來。")];
    [arr addObject:TG(T(@"g3_mul_box",       3, @"×", @"一盒巧克力有 {a} 顆，買 {b} 盒共有幾顆巧克力？", @"顆", 12, 30, 3, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"巧克力", @"顆", @"盒", @"每盒有 {a} 顆巧克力，共有 {b} 盒。把每盒一樣多的巧克力合起來。")];
    [arr addObject:TT(T(@"g3_mul_multiple",  3, @"×", @"小華有 {a} 元，小明的錢是小華的 {b} 倍，小明有幾元？", @"元", 15, 45, 3, 9, NO, NO), @"小華有 {a} 元，小明的錢是小華的 {b} 倍。把小華的金額當作 1 份，求 {b} 份是多少元。")];
    [arr addObject:TT(T(@"g3_mul_bag",       3, @"×", @"一袋米 {a} 公斤，{b} 袋共有幾公斤？", @"公斤", 12, 25, 3, 9, NO, NO), @"每袋米重 {a} 公斤，共有 {b} 袋。把每袋的重量累加 {b} 次，求的是總重量，不是袋數。")];
    [arr addObject:TG(T(@"g3_mul_seat",      3, @"×", @"電影院每排有 {a} 個座位，共 {b} 排，電影院共有幾個座位？", @"個", 15, 30, 4, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"座位", @"個", @"排", @"每排有 {a} 個座位，共有 {b} 排。把每排一樣多的座位數合起來。")];

    // — 乘法（一位數 × 三位數） —
    // 故事改為「每箱裝 {a} 顆…買 {b} 箱」這種「三位數重複 b 次」的情境，
    // 比「每班有 {a} 個學生」更貼近 N-3-4 的 1-digit × 3-digit。
    [arr addObject:TG(T(@"g3_mul_school3",   3, @"×", @"每箱蘋果 {a} 顆，水果店進了 {b} 箱，共有幾顆蘋果？", @"顆", 105, 320, 3, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"蘋果", @"顆", @"箱", @"每箱有 {a} 顆蘋果，共有 {b} 箱。把每箱一樣多的蘋果合起來。")];   // 三位數 × 一位數
    [arr addObject:TG(T(@"g3_mul_pages3",    3, @"×", @"小明每天讀 {a} 頁書，{b} 天共讀了幾頁？", @"頁", 35, 120, 3, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"書", @"頁", @"天", @"每天都讀 {a} 頁書，連續讀了 {b} 天。把每天讀的頁數合起來，求總頁數。")];
    [arr addObject:TG(T(@"g3_mul_factory3",  3, @"×", @"工廠每天生產 {a} 個玩具，{b} 天共生產幾個玩具？", @"個", 105, 320, 3, 9, NO, NO), GroupingStoryMeaningBuildEqualGroups, @"玩具", @"個", @"天", @"每天都生產 {a} 個玩具，連續生產 {b} 天。把每天的產量合起來，求玩具總個數。")];
    [arr addObject:TT(T(@"g3_mul_ticket3",   3, @"×", @"一張票 {a} 元，賣出 {b} 張共收到幾元？", @"元", 120, 280, 3, 8, NO, NO), @"一張票是 {a} 元，賣出 {b} 張。把每張票的價錢累加 {b} 次，求的是收到的總金額。")];

    // — 單位換算（透過乘法表達） —
    [arr addObject:TT(T(@"g3_mul_week_day",  3, @"×", @"一週有 7 天，{a} 週共有幾天？", @"天", 3, 25, 7, 7, NO, NO), @"1 週有 {b} 天。這裡有 {a} 週，所以把每週的 {b} 天累加 {a} 次，換成天數。")];
    [arr addObject:TT(T(@"g3_mul_hour_min",  3, @"×", @"一小時等於 60 分鐘，{a} 小時共有幾分鐘？", @"分鐘", 2, 9, 60, 60, NO, NO), @"1 小時有 {b} 分鐘。這裡有 {a} 小時，所以把 {b} 分鐘累加 {a} 次。")];
    [arr addObject:TT(T(@"g3_mul_min_sec",   3, @"×", @"一分鐘等於 60 秒，{a} 分鐘共有幾秒？", @"秒", 2, 9, 60, 60, NO, NO), @"1 分鐘有 {b} 秒。這裡有 {a} 分鐘，所以把 {b} 秒累加 {a} 次。")];
    [arr addObject:TT(T(@"g3_mul_m_cm",      3, @"×", @"1 公尺等於 100 公分，{a} 公尺等於幾公分？", @"公分", 2, 9, 100, 100, NO, NO), @"1 公尺有 {b} 公分。這裡有 {a} 公尺，所以把 {b} 公分累加 {a} 次。")];
    [arr addObject:TT(T(@"g3_mul_kg_g",      3, @"×", @"1 公斤等於 1000 公克，{a} 公斤等於幾公克？", @"公克", 2, 9, 1000, 1000, NO, NO), @"1 公斤有 {b} 公克。這裡有 {a} 公斤，所以把 {b} 公克累加 {a} 次。")];
    [arr addObject:TT(T(@"g3_mul_l_ml",      3, @"×", @"1 公升等於 1000 毫升，{a} 公升等於幾毫升？", @"毫升", 2, 9, 1000, 1000, NO, NO), @"1 公升有 {b} 毫升。這裡有 {a} 公升，所以把 {b} 毫升累加 {a} 次。")];
    [arr addObject:TT(T(@"g3_mul_km_m",      3, @"×", @"1 公里等於 1000 公尺，{a} 公里等於幾公尺？", @"公尺", 2, 9, 1000, 1000, NO, NO), @"1 公里有 {b} 公尺。這裡有 {a} 公里，所以把 {b} 公尺累加 {a} 次。")];
    [arr addObject:TT(T(@"g3_mul_dozen",     3, @"×", @"一打鉛筆有 12 枝，{a} 打共有幾枝鉛筆？", @"枝", 2, 9, 12, 12, NO, NO), @"1 打鉛筆有 {b} 枝。這裡有 {a} 打，所以把每打的 {b} 枝累加 {a} 次。")];

    // — 除法（除數為一位數，整除）—
    [arr addObject:TG(T(@"g3_div_share_candy",  3, @"÷", @"媽媽買了 {a} 顆糖果，平分給 {b} 個小朋友，每個小朋友可分到幾顆糖果？", @"顆", 12, 81, 2, 9, NO, YES), GroupingStoryMeaningShareEqually, @"糖果", @"顆", @"個小朋友", @"把 {a} 顆糖果平均分給 {b} 個小朋友。每輪每人分 1 顆，讓每個人分到的一樣多，再看每人有幾顆。")];
    [arr addObject:TG(T(@"g3_div_pack",         3, @"÷", @"有 {a} 顆糖果，每 {b} 顆裝成一包，可以裝成幾包？", @"包", 12, 81, 2, 9, NO, YES), GroupingStoryMeaningMakeGroupsOf, @"糖果", @"顆", @"包", @"每 {b} 顆糖果裝成一包。從 {a} 顆糖果中一次取出一包的份量，數一數能裝成幾包。")];
    [arr addObject:TG(T(@"g3_div_group",        3, @"÷", @"{a} 個學生平均分成 {b} 組，每組有幾個學生？", @"個", 12, 81, 2, 9, NO, YES), GroupingStoryMeaningShareEqually, @"學生", @"個", @"組", @"把 {a} 個學生平均分成 {b} 組，每組人數一樣多。求的是每組有幾個學生，不是組數。")];
    [arr addObject:TG(T(@"g3_div_plate",        3, @"÷", @"有 {a} 顆水餃，每盤放 {b} 顆，可以裝成幾盤？", @"盤", 12, 81, 2, 9, NO, YES), GroupingStoryMeaningMakeGroupsOf, @"水餃", @"顆", @"盤", @"每盤放 {b} 顆水餃。從 {a} 顆水餃中一次取出一盤的份量，數一數能裝成幾盤。")];
    [arr addObject:TG(T(@"g3_div_row",          3, @"÷", @"教室有 {a} 個座位排成 {b} 排，每排的座位一樣多，每排有幾個座位？", @"個", 12, 81, 2, 9, NO, YES), GroupingStoryMeaningShareEqually, @"座位", @"個", @"排", @"把 {a} 個座位平均排成 {b} 排，每排座位一樣多。求的是每排有幾個座位，不是排數。")];
    [arr addObject:TT(T(@"g3_div_multiple",     3, @"÷", @"小明有 {a} 元，是小華的 {b} 倍，小華有幾元？", @"元", 12, 81, 2, 9, NO, YES), @"小明的 {a} 元包含 {b} 份小華的錢。先求其中 1 份的金額，不是把錢分給 {b} 個人。")];

    // — 除法：較大被除數（覆蓋 N-3-5「除數為一位數」上限） —
    [arr addObject:TG(T(@"g3_div_big_share",    3, @"÷", @"工廠生產了 {a} 個產品，平均分裝到 {b} 個箱子，每箱有幾個？", @"個", 60, 360, 2, 9, NO, YES), GroupingStoryMeaningShareEqually, @"產品", @"個", @"個箱子", @"把 {a} 個產品平均分裝到 {b} 個箱子，讓每箱一樣多。求的是每箱的產品個數。")];
    [arr addObject:TG(T(@"g3_div_big_pack",     3, @"÷", @"商店有 {a} 顆水果，每 {b} 顆裝一袋，可以裝幾袋？", @"袋", 60, 360, 3, 9, NO, YES), GroupingStoryMeaningMakeGroupsOf, @"水果", @"顆", @"袋", @"每 {b} 顆水果裝成一袋。從 {a} 顆水果中一次取出一袋的份量，數一數能裝成幾袋。")];

    // — 單位換算（除法方向）—
    [arr addObject:TT(T(@"g3_div_min_hour",     3, @"÷", @"{a} 分鐘等於幾小時？", @"小時", 60, 540, 60, 60, NO, YES), @"每 {b} 分鐘是 1 小時。想一想 {a} 分鐘裡包含幾段 {b} 分鐘，換成小時數。")];
    [arr addObject:TT(T(@"g3_div_cm_m",         3, @"÷", @"{a} 公分等於幾公尺？", @"公尺", 100, 900, 100, 100, NO, YES), @"每 {b} 公分是 1 公尺。想一想 {a} 公分裡包含幾段 {b} 公分，換成公尺數。")];

    // — 正方形周長（邊長 × 4）：幾何情境的乘法 —
    [arr addObject:TT(T(@"g3_mul_square_peri", 3, @"×", @"一個正方形的邊長是 {a} 公分，它的周長是幾公分？", @"公分", 5, 60, 4, 4, NO, NO), @"正方形有 4 條一樣長的邊，每條邊長 {a} 公分。周長是沿著四條邊走一圈的長度，把四條邊長加起來。")];

    // — 比較型「少」（四位數，求較小量） —
    [arr addObject:T(@"g3_sub_less_factory", 3, @"−", @"甲工廠生產 {a} 個零件，乙工廠比甲工廠少 {b} 個，乙工廠生產幾個零件？", @"個", 1500, 8500, 380, 2800, YES, NO)];

    // — 平均（總量 ÷ 份數 = 平均，整除） —
    [arr addObject:TT(T(@"g3_div_avg_page",  3, @"÷", @"小明 {b} 天共讀了 {a} 頁書，平均每天讀幾頁？", @"頁", 60, 360, 2, 9, NO, YES), @"把總共 {a} 頁平均分成 {b} 天的份量，求平均每天的頁數；不代表每天實際讀得一樣多。")];
    [arr addObject:TT(T(@"g3_div_avg_money", 3, @"÷", @"{b} 個小朋友平分 {a} 元，平均每人分到幾元？", @"元", 60, 360, 2, 9, NO, YES), @"把 {a} 元平均分給 {b} 個小朋友，讓每個人分到的金額一樣多。求的是每人的元數，不是硬幣的枚數。")];

    // — 二步驟題（同優先級 a±b±c）：對應 N-3-2 三、四位數加減的二步驟解題 —
    [arr addObject:T2(@"g3_two_warehouse",3, @"+", @"−", @"倉庫原有 {a} 箱貨，進貨 {b} 箱後又出貨 {c} 箱，現在倉庫有幾箱貨？", @"箱", 800, 3500, 280, 1500, 200, 1800)];
    [arr addObject:T2(@"g3_two_factory",  3, @"+", @"−", @"工廠上週生產 {a} 個產品、本週生產 {b} 個，已出貨 {c} 個，倉庫還剩幾個產品？", @"個", 850, 2800, 650, 2200, 480, 1800)];
    [arr addObject:T2(@"g3_two_library",  3, @"−", @"−", @"圖書館有 {a} 本書，上午借出 {b} 本、下午借出 {c} 本，還剩幾本書？", @"本", 1200, 4500, 280, 1200, 280, 1200)];
    [arr addObject:T2(@"g3_two_save",     3, @"+", @"+", @"哥哥存了 {a} 元、姐姐存了 {b} 元、妹妹存了 {c} 元，三人一共存了幾元？", @"元", 480, 2800, 320, 2200, 180, 1800)];
    [arr addObject:T2(@"g3_two_shop",     3, @"−", @"−", @"小華有 {a} 元，買書花了 {b} 元、買筆花了 {c} 元，還剩幾元？", @"元", 580, 1800, 120, 580, 80, 380)];

    // — 分數識別（108 課綱 N-3-9）：真分數，{a} 分子、{b} 分母 —
    [arr addObject:TF(@"g3_frac_cake",    3, @"把一塊蛋糕平分成 {b} 份，小明吃掉 {a} 份，小明吃了幾分之幾的蛋糕？", @"", 1, 6, 3, 8)];
    [arr addObject:TF(@"g3_frac_pizza",   3, @"一個披薩平分成 {b} 片，姐姐吃了 {a} 片，姐姐吃了幾分之幾的披薩？", @"", 1, 5, 4, 8)];
    [arr addObject:TF(@"g3_frac_paper",   3, @"把一張色紙平分成 {b} 等份後，剪下 {a} 份，剪下的部分占整張紙的幾分之幾？", @"", 1, 6, 4, 9)];
    [arr addObject:TF(@"g3_frac_chocbar", 3, @"一條巧克力平均分成 {b} 等份，弟弟拿走 {a} 份，弟弟拿走整條巧克力的幾分之幾？", @"", 1, 5, 3, 7)];
    [arr addObject:TF(@"g3_frac_rope",    3, @"把一條繩子平分成 {b} 段，使用了 {a} 段，使用了整條繩子的幾分之幾？", @"", 1, 6, 4, 8)];
    [arr addObject:TF(@"g3_frac_apple",   3, @"一顆蘋果平均切成 {b} 塊，妹妹吃了 {a} 塊，妹妹吃了整顆蘋果的幾分之幾？", @"", 1, 5, 3, 8)];

    // — 有餘數除法（108 課綱 N-3-5 核心；題目只問商）—
    // 故事文字以「最多分幾顆/每盤裝幾包/可以裝成幾包」呈現，避免問餘數
    // （目前只在等式面板顯示「a ÷ b = q⋯r」讓孩子看到完整算式）。
    [arr addObject:TG(TR(@"g3_rem_share_candy", 3, @"{a} 顆糖果平分給 {b} 個小朋友，每人最多可以分到幾顆？", @"顆", 13, 79, 3, 9), GroupingStoryMeaningShareEqually, @"糖果", @"顆", @"個小朋友", @"把 {a} 顆糖果平均分給 {b} 個小朋友。每輪每人分 1 顆，直到剩下的不夠每人再分 1 顆；剩下的留在一起。")];
    [arr addObject:TG(TR(@"g3_rem_pack",        3, @"有 {a} 顆糖果，每 {b} 顆裝一包，可以裝成幾包？（剩下的不夠裝一包）", @"包", 13, 79, 3, 9), GroupingStoryMeaningMakeGroupsOf, @"糖果", @"顆", @"包", @"每 {b} 顆糖果裝成一包。從 {a} 顆糖果中一包一包地裝，只數完整的包；不夠一包的糖果留下。")];
    [arr addObject:TG(TR(@"g3_rem_plate",       3, @"有 {a} 顆水餃，每盤放 {b} 顆，最多可以裝滿幾盤？", @"盤", 13, 79, 3, 9), GroupingStoryMeaningMakeGroupsOf, @"水餃", @"顆", @"盤", @"每盤要放滿 {b} 顆水餃。從 {a} 顆水餃中一盤一盤地裝，只數裝滿的盤；不夠一盤的水餃留下。")];
    [arr addObject:TG(TR(@"g3_rem_team",        3, @"{a} 個球員分成每隊 {b} 人，最多可以分成幾隊？", @"隊", 13, 79, 3, 9), GroupingStoryMeaningMakeGroupsOf, @"球員", @"人", @"隊", @"每隊需要 {b} 人。把 {a} 個球員依這個人數組隊，只數人數完整的隊；不夠一隊的球員留下。")];
    [arr addObject:TG(TR(@"g3_rem_seat",        3, @"教室裡有 {a} 個學生要坐成每排 {b} 人，可以坐滿幾排？", @"排", 13, 79, 3, 9), GroupingStoryMeaningMakeGroupsOf, @"學生", @"人", @"排", @"每排坐滿 {b} 人。把 {a} 個學生依這個人數排座位，只數坐滿的排；不滿一排的學生另外計算。")];
    [arr addObject:TG(TR(@"g3_rem_box_big",     3, @"工廠生產了 {a} 個零件，每盒裝 {b} 個，最多可以裝滿幾盒？", @"盒", 50, 280, 3, 9), GroupingStoryMeaningMakeGroupsOf, @"零件", @"個", @"盒", @"每盒裝滿 {b} 個零件。從 {a} 個零件中一盒一盒地裝，只數裝滿的盒；不夠一盒的零件留下。")];

    return [arr copy];
}

#pragma mark - Public

+ (NSArray<WordProblemTemplate *> *)templatesForGrade:(NSInteger)grade {
    if (grade <= 1) return [self grade1Templates];
    if (grade == 2) return [self grade2Templates];
    return [self grade3Templates];
}

+ (NSArray<WordProblemTemplate *> *)allTemplates {
    NSMutableArray *all = [NSMutableArray array];
    [all addObjectsFromArray:[self grade1Templates]];
    [all addObjectsFromArray:[self grade2Templates]];
    [all addObjectsFromArray:[self grade3Templates]];
    return [all copy];
}

@end
