#import "Lesson.h"
#import "ArithmeticProblem.h"

@interface Lesson ()
@property (nonatomic, copy, readwrite) NSString *lessonID;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *iconName;
@property (nonatomic, assign, readwrite) LessonKind kind;
@property (nonatomic, assign, readwrite) NSInteger questionCount;
@property (nonatomic, assign, readwrite) NSInteger multiplicationFactor;
@property (nonatomic, strong) NSMutableArray<ArithmeticProblem *> *pendingProblems;
@property (nonatomic, copy) NSString *lastProblemKey;
@end

@implementation Lesson

- (instancetype)initWithID:(NSString *)lessonID
                     title:(NSString *)title
                  iconName:(NSString *)iconName
                      kind:(LessonKind)kind
             questionCount:(NSInteger)count
      multiplicationFactor:(NSInteger)factor {
    self = [super init];
    if (self) {
        _lessonID = [lessonID copy];
        _title = [title copy];
        _iconName = [iconName copy];
        _kind = kind;
        _questionCount = count;
        _multiplicationFactor = factor;
    }
    return self;
}

- (uint32_t)randomBelow:(uint32_t)upperBound {
    return arc4random_uniform(upperBound);
}

- (void)shuffle:(NSMutableArray *)items {
    for (NSUInteger i = items.count; i > 1; i--) {
        [items exchangeObjectAtIndex:i - 1 withObjectAtIndex:[self randomBelow:(uint32_t)i]];
    }
}

- (NSString *)keyForProblem:(ArithmeticProblem *)problem {
    return [NSString stringWithFormat:@"%ld%@%ld", (long)problem.number1,
            problem.operatorSymbol, (long)problem.number2];
}

/// 先列出合法題目，再從題組抽取；不以重抽次數碰運氣，亦不偏袒 +0。
- (NSArray<ArithmeticProblem *> *)candidateProblems {
    NSMutableArray<ArithmeticProblem *> *problems = [NSMutableArray array];
    switch (self.kind) {
        case LessonKindAddSimple: {
            NSInteger upper = [self.lessonID isEqualToString:@"L1"] ? 5 : 10;
            for (NSInteger a = 1; a <= upper; a++) {
                for (NSInteger b = 0; b <= upper - a; b++) {
                    [problems addObject:[[ArithmeticProblem alloc] initWithNumber1:a number2:b
                                                                            operator:@"+" answer:a + b]];
                }
            }
            break;
        }
        case LessonKindSubSimple: {
            // 「10 以內」包括從 10 減去個位數；也保留減 0 與減掉全部的概念。
            for (NSInteger a = 1; a <= 10; a++) {
                for (NSInteger b = 0; b <= a; b++) {
                    [problems addObject:[[ArithmeticProblem alloc] initWithNumber1:a number2:b
                                                                            operator:@"-" answer:a - b]];
                }
            }
            break;
        }
        case LessonKindMakeTen: {
            for (NSInteger a = 2; a <= 9; a++) {
                for (NSInteger b = 11 - a; b <= 9; b++) {
                    [problems addObject:[[ArithmeticProblem alloc] initWithNumber1:a number2:b
                                                                            operator:@"+" answer:a + b]];
                }
            }
            break;
        }
        case LessonKindBreakTen: {
            for (NSInteger a = 11; a <= 18; a++) {
                for (NSInteger b = a % 10 + 1; b <= 9; b++) {
                    [problems addObject:[[ArithmeticProblem alloc] initWithNumber1:a number2:b
                                                                            operator:@"-" answer:a - b]];
                }
            }
            break;
        }
        case LessonKindMultiplication: {
            NSInteger m = self.multiplicationFactor;
            for (NSInteger n = 1; n <= 9; n++) {
                [problems addObject:[[ArithmeticProblem alloc] initWithNumber1:m number2:n
                                                                        operator:@"×" answer:m * n]];
            }
            break;
        }
    }
    return problems;
}

/// 輪流取各組一題，不讓候選組合較多的大數完全淹沒小數。
- (NSArray<ArithmeticProblem *> *)balancedSelectionFrom:(NSArray<ArithmeticProblem *> *)pool
                                                  count:(NSUInteger)count {
    NSMutableDictionary<NSNumber *, NSMutableArray<ArithmeticProblem *> *> *groups = [NSMutableDictionary dictionary];
    for (ArithmeticProblem *problem in pool) {
        NSInteger value = self.kind == LessonKindAddSimple ? problem.answer : problem.number1;
        if (self.kind == LessonKindMultiplication) value = problem.number2;
        NSNumber *key = @(value);
        if (!groups[key]) groups[key] = [NSMutableArray array];
        [groups[key] addObject:problem];
    }
    NSMutableArray<NSNumber *> *keys = [[groups.allKeys sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    [self shuffle:keys];
    // 每堂內建減法課都練到從 10 減，不只是把 10 放進可能抽中的大題庫。
    if (self.kind == LessonKindSubSimple && [keys containsObject:@10]) {
        [keys removeObject:@10];
        [keys insertObject:@10 atIndex:0];
    }
    NSMutableArray<ArithmeticProblem *> *selected = [NSMutableArray array];
    NSUInteger target = MIN(count, pool.count);
    while (selected.count < target) {
        for (NSNumber *key in keys) {
            NSMutableArray<ArithmeticProblem *> *group = groups[key];
            if (group.count == 0) continue;
            NSUInteger index = [self randomBelow:(uint32_t)group.count];
            [selected addObject:group[index]];
            [group removeObjectAtIndex:index];
            if (selected.count == target) break;
        }
    }
    return selected;
}

- (NSMutableArray<ArithmeticProblem *> *)balancedBatchWithCount:(NSUInteger)count {
    NSArray<ArithmeticProblem *> *candidates = [self candidateProblems];
    NSMutableArray<ArithmeticProblem *> *core = [NSMutableArray array];
    NSMutableArray<ArithmeticProblem *> *zero = [NSMutableArray array];
    NSMutableArray<ArithmeticProblem *> *takeAll = [NSMutableArray array];
    for (ArithmeticProblem *problem in candidates) {
        if (problem.number2 == 0) [zero addObject:problem];
        else if (self.kind == LessonKindSubSimple && problem.answer == 0) [takeAll addObject:problem];
        else [core addObject:problem];
    }

    NSMutableArray<ArithmeticProblem *> *batch = [NSMutableArray array];
    // 內建十題課：加 0／減 0 各至多一題，減掉全部亦只保留一題。
    if (count >= 5 && zero.count > 0) {
        [batch addObject:zero[[self randomBelow:(uint32_t)zero.count]]];
    }
    if (count >= 5 && takeAll.count > 0) {
        [batch addObject:takeAll[[self randomBelow:(uint32_t)takeAll.count]]];
    }
    [batch addObjectsFromArray:[self balancedSelectionFrom:core count:count - batch.count]];

    // 自訂題數超過核心題庫時，先用完其餘邊界題，再讓下一批開始重用。
    if (batch.count < count) {
        NSMutableArray<ArithmeticProblem *> *remaining = [candidates mutableCopy];
        [remaining removeObjectsInArray:batch];
        [self shuffle:remaining];
        NSUInteger needed = MIN(count - batch.count, remaining.count);
        [batch addObjectsFromArray:[remaining subarrayWithRange:NSMakeRange(0, needed)]];
    }
    [self shuffle:batch];
    return batch;
}

- (NSArray<ArithmeticProblem *> *)generateSessionProblems {
    [self.pendingProblems removeAllObjects];
    NSMutableArray<ArithmeticProblem *> *session = [NSMutableArray array];
    NSUInteger target = (NSUInteger)MAX(0, self.questionCount);
    NSString *previousKey = self.lastProblemKey;
    while (session.count < target) {
        NSMutableArray<ArithmeticProblem *> *batch = [self balancedBatchWithCount:target - session.count];
        if (batch.count == 0) break;
        if ([[self keyForProblem:batch.firstObject] isEqualToString:previousKey]) {
            if (batch.count > 1) {
                [batch exchangeObjectAtIndex:0 withObjectAtIndex:1];
            } else {
                // 自訂單題課程無法交換位置，改選另一題；內建課程不需走這個分支。
                for (ArithmeticProblem *alternative in [self candidateProblems]) {
                    if (![[self keyForProblem:alternative] isEqualToString:previousKey]) {
                        batch[0] = alternative;
                        break;
                    }
                }
            }
        }
        [session addObjectsFromArray:batch];
        previousKey = [self keyForProblem:batch.lastObject];
    }
    if (session.count > 0) self.lastProblemKey = previousKey;
    return [session copy];
}

- (ArithmeticProblem *)generateProblem {
    if (self.pendingProblems.count == 0) {
        self.pendingProblems = [[self generateSessionProblems] mutableCopy];
    }
    if (self.pendingProblems.count == 0) {
        // 即使自訂課程題數為 0，舊單題 API 仍維持回傳合法題目的契約。
        return [self balancedBatchWithCount:1].firstObject
            ?: [[ArithmeticProblem alloc] initWithNumber1:1 number2:1 operator:@"+" answer:2];
    }
    ArithmeticProblem *problem = self.pendingProblems.firstObject;
    [self.pendingProblems removeObjectAtIndex:0];
    self.lastProblemKey = [self keyForProblem:problem];
    return problem;
}

@end


@implementation LessonCatalog

+ (NSArray<Lesson *> *)addSubLessons {
    return @[
        [[Lesson alloc] initWithID:@"L1" title:@"5 以內加法" iconName:@"1.circle.fill"
                              kind:LessonKindAddSimple questionCount:10 multiplicationFactor:0],
        [[Lesson alloc] initWithID:@"L2" title:@"10 以內加法" iconName:@"2.circle.fill"
                              kind:LessonKindAddSimple questionCount:10 multiplicationFactor:0],
        [[Lesson alloc] initWithID:@"L3" title:@"10 以內減法" iconName:@"3.circle.fill"
                              kind:LessonKindSubSimple questionCount:10 multiplicationFactor:0],
        [[Lesson alloc] initWithID:@"L4" title:@"合十法（進位加）" iconName:@"4.circle.fill"
                              kind:LessonKindMakeTen questionCount:10 multiplicationFactor:0],
        [[Lesson alloc] initWithID:@"L5" title:@"破十法（退位減）" iconName:@"5.circle.fill"
                              kind:LessonKindBreakTen questionCount:10 multiplicationFactor:0],
    ];
}

+ (NSArray<Lesson *> *)multiplicationLessons {
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 1; i <= 9; i++) {
        NSString *lessonID = [NSString stringWithFormat:@"M%ld", (long)i];
        NSString *title = [NSString stringWithFormat:@"%ld 的乘法", (long)i];
        NSString *icon = [NSString stringWithFormat:@"%ld.square.fill", (long)i];
        [result addObject:[[Lesson alloc] initWithID:lessonID title:title iconName:icon
                                                 kind:LessonKindMultiplication
                                        questionCount:9
                                  multiplicationFactor:i]];
    }
    return [result copy];
}

@end
