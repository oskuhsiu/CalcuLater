#import "WordProblemTemplate.h"

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
          requireDivisible:(BOOL)requireDiv {
    self = [super init];
    if (self) {
        _templateID = [templateID copy];
        _grade = grade;
        _operatorSymbol = [operatorSymbol copy];
        _storyPattern = [storyPattern copy];
        _unit = [unit copy] ?: @"";
        _minA = minA;
        _maxA = maxA;
        _minB = minB;
        _maxB = maxB;
        _requireAGreaterEqualB = requireAGE;
        _requireDivisible = requireDiv;
    }
    return self;
}

@end


#pragma mark - Catalog

/// 內部 helper：少打字。
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
                                    requireDivisible:divisible];
}

@implementation WordProblemCatalog

#pragma mark - Grade 1（20 以內加減；具象、常見情境）

+ (NSArray<WordProblemTemplate *> *)grade1Templates {
    // 加法：合併型 / 添加型；範圍以個位數 + 個位數，但允許答案進到 10 以上（不超過 20）
    NSMutableArray *arr = [NSMutableArray array];

    // — 加法 —
    [arr addObject:T(@"g1_add_candy",     1, @"+", @"小明有 {a} 顆糖果，小美又給他 {b} 顆，小明現在有幾顆糖果？", @"顆", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_flower",    1, @"+", @"花瓶裡有 {a} 朵花，媽媽又插了 {b} 朵，花瓶裡現在有幾朵花？", @"朵", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_kids",      1, @"+", @"公園裡有 {a} 個小朋友在玩，又來了 {b} 個小朋友，現在有幾個小朋友？", @"個", 2, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_duck",      1, @"+", @"池塘裡有 {a} 隻小鴨，又游來了 {b} 隻，現在共有幾隻小鴨？", @"隻", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_cookie",    1, @"+", @"盤子裡有 {a} 塊餅乾，媽媽再放了 {b} 塊，盤子裡共有幾塊餅乾？", @"塊", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_pencil",    1, @"+", @"鉛筆盒裡有 {a} 枝鉛筆，再放進 {b} 枝，鉛筆盒裡共有幾枝鉛筆？", @"枝", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_apple",     1, @"+", @"樹上原本有 {a} 個蘋果，又長出 {b} 個，樹上共有幾個蘋果？", @"個", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_toy",       1, @"+", @"箱子裡有 {a} 個玩具，弟弟又放進 {b} 個，箱子裡共有幾個玩具？", @"個", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_book",      1, @"+", @"書架上有 {a} 本書，再放上去 {b} 本，書架上共有幾本書？", @"本", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_sticker",   1, @"+", @"哥哥有 {a} 張貼紙，姐姐比哥哥多 {b} 張，姐姐有幾張貼紙？", @"張", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_fish",      1, @"+", @"魚缸裡有 {a} 條金魚，爸爸又買 {b} 條放進去，魚缸裡共有幾條金魚？", @"條", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_balloon",   1, @"+", @"小華手上有 {a} 個氣球，媽媽又給他 {b} 個，小華現在有幾個氣球？", @"個", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_bus",       1, @"+", @"公車上原本有 {a} 個乘客，下一站又上來 {b} 個，公車上現在有幾個乘客？", @"個", 1, 9, 1, 9, NO, NO)];
    [arr addObject:T(@"g1_add_egg",       1, @"+", @"冰箱裡有 {a} 顆蛋，媽媽再買 {b} 顆放進去，冰箱裡共有幾顆蛋？", @"顆", 1, 9, 1, 9, NO, NO)];

    // — 減法 —
    [arr addObject:T(@"g1_sub_candy",     1, @"−", @"盤子裡有 {a} 顆糖果，小明吃掉 {b} 顆，盤子裡還剩幾顆糖果？", @"顆", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_kids",      1, @"−", @"公園裡有 {a} 個小朋友，{b} 個小朋友回家了，公園裡還剩幾個小朋友？", @"個", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_card",      1, @"−", @"小華有 {a} 張卡片，給弟弟 {b} 張，小華還剩幾張卡片？", @"張", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_bird",      1, @"−", @"樹上有 {a} 隻小鳥，飛走了 {b} 隻，樹上還剩幾隻小鳥？", @"隻", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_egg",       1, @"−", @"媽媽有 {a} 顆雞蛋，做蛋糕用掉 {b} 顆，還剩幾顆雞蛋？", @"顆", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_apple",     1, @"−", @"水果店裡有 {a} 顆蘋果，賣掉了 {b} 顆，還剩幾顆蘋果？", @"顆", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_flower",    1, @"−", @"花園裡有 {a} 朵花，被風吹掉了 {b} 朵，還剩幾朵花？", @"朵", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_diff_pencil", 1, @"−", @"哥哥有 {a} 枝鉛筆，弟弟有 {b} 枝鉛筆，哥哥比弟弟多幾枝鉛筆？", @"枝", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_diff_age",  1, @"−", @"姐姐 {a} 歲，妹妹 {b} 歲，姐姐比妹妹大幾歲？", @"歲", 5, 15, 1, 8, YES, NO)];
    [arr addObject:T(@"g1_sub_cookie",    1, @"−", @"罐子裡有 {a} 塊餅乾，小華吃掉 {b} 塊，罐子裡還剩幾塊餅乾？", @"塊", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_balloon",   1, @"−", @"小明有 {a} 個氣球，飛走了 {b} 個，小明還剩幾個氣球？", @"個", 3, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_need",      1, @"−", @"媽媽要做 {a} 個飯糰，已經做好 {b} 個，還要做幾個？", @"個", 5, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_book",      1, @"−", @"小華要讀完 {a} 本書，已經讀完 {b} 本，還剩幾本沒讀？", @"本", 5, 18, 1, 9, YES, NO)];
    [arr addObject:T(@"g1_sub_seat",      1, @"−", @"教室裡有 {a} 個座位，坐了 {b} 個小朋友，還有幾個空位？", @"個", 5, 18, 1, 9, YES, NO)];

    return [arr copy];
}

#pragma mark - Grade 2（100 以內加減進退位 + 九九乘法）

+ (NSArray<WordProblemTemplate *> *)grade2Templates {
    NSMutableArray *arr = [NSMutableArray array];

    // — 加法（含進位）—
    [arr addObject:T(@"g2_add_class",     2, @"+", @"一年一班有 {a} 個學生，二班有 {b} 個學生，兩班共有幾個學生？", @"個", 15, 35, 15, 35, NO, NO)];
    [arr addObject:T(@"g2_add_ball",      2, @"+", @"體育館有 {a} 顆紅球，{b} 顆藍球，紅球和藍球共有幾顆？", @"顆", 12, 60, 12, 60, NO, NO)];
    [arr addObject:T(@"g2_add_gender",    2, @"+", @"班上有男生 {a} 人，女生 {b} 人，全班共有幾人？", @"人", 8, 30, 8, 30, NO, NO)];
    [arr addObject:T(@"g2_add_books",     2, @"+", @"學校買了 {a} 本數學書、{b} 本國語書，共買了幾本書？", @"本", 18, 65, 18, 65, NO, NO)];
    [arr addObject:T(@"g2_add_money",     2, @"+", @"原子筆 {a} 元、橡皮擦 {b} 元，買兩樣共要付幾元？", @"元", 12, 60, 10, 40, NO, NO)];
    [arr addObject:T(@"g2_add_meals",     2, @"+", @"早上煮了 {a} 個包子、下午又煮了 {b} 個，今天共煮了幾個包子？", @"個", 12, 60, 12, 60, NO, NO)];
    [arr addObject:T(@"g2_add_visitors",  2, @"+", @"上午來了 {a} 位客人，下午又來了 {b} 位，今天共來了幾位客人？", @"位", 18, 55, 15, 50, NO, NO)];
    [arr addObject:T(@"g2_add_save",      2, @"+", @"哥哥存了 {a} 元，弟弟存了 {b} 元，他們一共存了幾元？", @"元", 25, 75, 18, 60, NO, NO)];
    [arr addObject:T(@"g2_add_pages",     2, @"+", @"小明昨天讀了 {a} 頁書，今天又讀了 {b} 頁，這兩天共讀了幾頁？", @"頁", 12, 55, 12, 55, NO, NO)];
    [arr addObject:T(@"g2_add_stamp",     2, @"+", @"姐姐收集了 {a} 張郵票，妹妹收集了 {b} 張郵票，兩人共收集了幾張郵票？", @"張", 18, 60, 15, 50, NO, NO)];

    // — 減法（含退位）—
    [arr addObject:T(@"g2_sub_change",    2, @"−", @"媽媽帶 {a} 元去買菜，花了 {b} 元，還剩幾元？", @"元", 50, 99, 18, 60, YES, NO)];
    [arr addObject:T(@"g2_sub_distance",  2, @"−", @"從小華家到學校共 {a} 公尺，小華已經走了 {b} 公尺，還要再走幾公尺？", @"公尺", 50, 99, 18, 60, YES, NO)];
    [arr addObject:T(@"g2_sub_pages",     2, @"−", @"一本書共有 {a} 頁，小明已經讀了 {b} 頁，還剩幾頁沒讀？", @"頁", 50, 99, 18, 65, YES, NO)];
    [arr addObject:T(@"g2_sub_cards",     2, @"−", @"哥哥蒐集 {a} 張卡片，送給朋友 {b} 張後，哥哥還剩幾張卡片？", @"張", 40, 90, 18, 50, YES, NO)];
    [arr addObject:T(@"g2_sub_diff_kids", 2, @"−", @"A 班有 {a} 個學生，B 班有 {b} 個學生，A 班比 B 班多幾個學生？", @"個", 28, 60, 15, 45, YES, NO)];
    [arr addObject:T(@"g2_sub_sold",      2, @"−", @"麵包店做了 {a} 個麵包，賣掉 {b} 個，還剩幾個麵包？", @"個", 50, 99, 18, 60, YES, NO)];
    [arr addObject:T(@"g2_sub_save_left", 2, @"−", @"小華原本有 {a} 元，買玩具花了 {b} 元，還剩幾元？", @"元", 50, 99, 18, 60, YES, NO)];
    [arr addObject:T(@"g2_sub_need_more", 2, @"−", @"工人要做 {a} 個椅子，已經做好 {b} 個，還要做幾個？", @"個", 50, 99, 15, 45, YES, NO)];
    [arr addObject:T(@"g2_sub_seats",     2, @"−", @"禮堂有 {a} 個座位，坐了 {b} 個人，還有幾個空位？", @"個", 50, 99, 25, 65, YES, NO)];

    // — 乘法（同數連加 / 倍數，九九乘法範圍）—
    [arr addObject:T(@"g2_mul_dumpling",  2, @"×", @"每盤水餃有 {a} 個，{b} 盤共有幾個水餃？", @"個", 2, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_row",       2, @"×", @"教室裡每排有 {a} 個學生，共有 {b} 排，教室裡共有幾個學生？", @"個", 2, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_day_page",  2, @"×", @"小明每天讀 {a} 頁書，{b} 天共讀了幾頁書？", @"頁", 2, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_legs_dog",  2, @"×", @"每隻狗有 4 條腿，{b} 隻狗共有幾條腿？", @"條", 4, 4, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_flower",    2, @"×", @"一束花有 {a} 朵，{b} 束花共有幾朵？", @"朵", 3, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_candy",     2, @"×", @"一盒糖果有 {a} 顆，{b} 盒共有幾顆糖果？", @"顆", 4, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_basket",    2, @"×", @"每籃裝 {a} 顆蘋果，{b} 籃共有幾顆蘋果？", @"顆", 4, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_wheel",     2, @"×", @"每台車有 {a} 個輪子，{b} 台車共有幾個輪子？", @"個", 3, 4, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_finger",    2, @"×", @"每隻手有 {a} 根手指，{b} 隻手共有幾根手指？", @"根", 5, 5, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_age",       2, @"×", @"弟弟 {b} 歲，哥哥的年紀是弟弟的 {a} 倍，哥哥幾歲？", @"歲", 2, 5, 3, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_packet",    2, @"×", @"一包餅乾有 {a} 塊，買 {b} 包共有幾塊餅乾？", @"塊", 3, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_egg_box",   2, @"×", @"一盒雞蛋裝 {a} 顆，{b} 盒共有幾顆雞蛋？", @"顆", 6, 9, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_chair",     2, @"×", @"每張桌子配 {a} 把椅子，{b} 張桌子共配幾把椅子？", @"把", 2, 6, 2, 9, NO, NO)];
    [arr addObject:T(@"g2_mul_jiaozi",    2, @"×", @"每碗麵放 {a} 顆貢丸，{b} 碗共需要幾顆貢丸？", @"顆", 2, 5, 2, 9, NO, NO)];

    return [arr copy];
}

#pragma mark - Grade 3（除法 + 一位數×兩位數乘法 + 大數加減）

+ (NSArray<WordProblemTemplate *> *)grade3Templates {
    NSMutableArray *arr = [NSMutableArray array];

    // — 加法（三位數）—
    [arr addObject:T(@"g3_add_school",    3, @"+", @"學校原本有 {a} 位學生，今年又轉入 {b} 位，學校現在共有幾位學生？", @"位", 120, 480, 25, 120, NO, NO)];
    [arr addObject:T(@"g3_add_library",   3, @"+", @"圖書館上午借出 {a} 本書，下午借出 {b} 本，今天共借出幾本書？", @"本", 80, 380, 60, 280, NO, NO)];
    [arr addObject:T(@"g3_add_money",     3, @"+", @"媽媽買菜花了 {a} 元，買水果花了 {b} 元，共花了幾元？", @"元", 95, 480, 60, 280, NO, NO)];
    [arr addObject:T(@"g3_add_zoo",       3, @"+", @"動物園有 {a} 隻鸚鵡和 {b} 隻孔雀，鸚鵡和孔雀共有幾隻？", @"隻", 85, 320, 45, 180, NO, NO)];
    [arr addObject:T(@"g3_add_factory",   3, @"+", @"工廠上週生產 {a} 個產品，這週生產 {b} 個，兩週共生產幾個產品？", @"個", 120, 460, 80, 380, NO, NO)];

    // — 減法（三位數）—
    [arr addObject:T(@"g3_sub_orchard",   3, @"−", @"果園有 {a} 顆蘋果，賣出 {b} 顆，還剩幾顆蘋果？", @"顆", 280, 850, 80, 380, YES, NO)];
    [arr addObject:T(@"g3_sub_distance",  3, @"−", @"從家裡到公園 {a} 公尺，小華已經走了 {b} 公尺，還要再走幾公尺？", @"公尺", 280, 850, 80, 380, YES, NO)];
    [arr addObject:T(@"g3_sub_savings",   3, @"−", @"哥哥存了 {a} 元，弟弟存了 {b} 元，哥哥比弟弟多存幾元？", @"元", 280, 850, 80, 380, YES, NO)];
    [arr addObject:T(@"g3_sub_inventory", 3, @"−", @"倉庫原本有 {a} 箱貨物，運出 {b} 箱後，倉庫還剩幾箱貨物？", @"箱", 280, 850, 80, 380, YES, NO)];
    [arr addObject:T(@"g3_sub_visitor",   3, @"−", @"今天博物館有 {a} 位訪客，上午來了 {b} 位，下午來了幾位訪客？", @"位", 280, 850, 80, 380, YES, NO)];

    // — 乘法（一位數 × 兩位數）—
    [arr addObject:T(@"g3_mul_class_size", 3, @"×", @"每班有 {a} 個學生，學校有 {b} 班，全校共有幾個學生？", @"個", 20, 35, 3, 9, NO, NO)];
    [arr addObject:T(@"g3_mul_box",       3, @"×", @"一盒巧克力有 {a} 顆，買 {b} 盒共有幾顆巧克力？", @"顆", 12, 30, 3, 9, NO, NO)];
    [arr addObject:T(@"g3_mul_week_day",  3, @"×", @"一週有 7 天，{a} 週共有幾天？", @"天", 3, 25, 7, 7, NO, NO)];
    [arr addObject:T(@"g3_mul_multiple",  3, @"×", @"小華有 {a} 元，小明的錢是小華的 {b} 倍，小明有幾元？", @"元", 15, 45, 3, 9, NO, NO)];
    [arr addObject:T(@"g3_mul_bag",       3, @"×", @"一袋米 {a} 公斤，{b} 袋共有幾公斤？", @"公斤", 12, 25, 3, 9, NO, NO)];
    [arr addObject:T(@"g3_mul_seat",      3, @"×", @"電影院每排有 {a} 個座位，共 {b} 排，電影院共有幾個座位？", @"個", 15, 30, 4, 9, NO, NO)];
    [arr addObject:T(@"g3_mul_hour",      3, @"×", @"一小時有 60 分鐘，{a} 小時共有幾分鐘？", @"分鐘", 2, 9, 60, 60, NO, NO)];
    [arr addObject:T(@"g3_mul_dozen",     3, @"×", @"一打鉛筆有 12 枝，{a} 打共有幾枝鉛筆？", @"枝", 2, 9, 12, 12, NO, NO)];

    // — 除法（平分 / 包含除）—
    [arr addObject:T(@"g3_div_share_candy",  3, @"÷", @"媽媽買了 {a} 顆糖果，平分給 {b} 個小朋友，每個小朋友可分到幾顆糖果？", @"顆", 6, 81, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_pack",         3, @"÷", @"有 {a} 顆糖果，每 {b} 顆裝成一包，可以裝成幾包？", @"包", 6, 81, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_group",        3, @"÷", @"{a} 個學生分成 {b} 組，每組有幾個學生？", @"個", 6, 81, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_plate",        3, @"÷", @"有 {a} 顆水餃，每盤放 {b} 顆，可以裝成幾盤？", @"盤", 6, 81, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_row",          3, @"÷", @"教室有 {a} 個座位排成 {b} 排，每排有幾個座位？", @"個", 6, 81, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_multiple",     3, @"÷", @"小明有 {a} 元，是小華的 {b} 倍，小華有幾元？", @"元", 6, 81, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_money_day",    3, @"÷", @"媽媽把 {a} 元平均分給 {b} 天當零用錢，每天可花幾元？", @"元", 6, 72, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_fair_share",   3, @"÷", @"果汁共 {a} 杯，平均分給 {b} 個小朋友，每人可分幾杯？", @"杯", 6, 72, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_pack2",        3, @"÷", @"有 {a} 個包子，每 {b} 個裝一盒，共可裝幾盒？", @"盒", 6, 72, 2, 9, NO, YES)];
    [arr addObject:T(@"g3_div_team",         3, @"÷", @"{a} 個球員分成 {b} 隊，每隊有幾個球員？", @"個", 6, 72, 2, 9, NO, YES)];

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
