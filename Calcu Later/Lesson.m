#import "Lesson.h"
#import "ArithmeticProblem.h"

@interface Lesson ()
@property (nonatomic, copy, readwrite) NSString *lessonID;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *iconName;
@property (nonatomic, assign, readwrite) LessonKind kind;
@property (nonatomic, assign, readwrite) NSInteger questionCount;
@property (nonatomic, assign, readwrite) NSInteger multiplicationFactor;
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

- (ArithmeticProblem *)generateProblem {
    NSInteger a = 0, b = 0;
    NSString *op = @"+";
    switch (self.kind) {
        case LessonKindAddSimple: {
            // 透過 lessonID 區分 L1 (5以內) vs L2 (10以內)
            NSInteger upper = [self.lessonID isEqualToString:@"L1"] ? 5 : 10;
            a = arc4random_uniform((uint32_t)upper) + 1;
            b = arc4random_uniform((uint32_t)(upper - a + 1));
            op = @"+";
            return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:op answer:a + b];
        }
        case LessonKindSubSimple: {
            a = arc4random_uniform(9) + 1;  // 1..9
            b = arc4random_uniform((uint32_t)a + 1);  // 0..a，保證不退位、不小於 0
            return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"-" answer:a - b];
        }
        case LessonKindMakeTen: {
            // 個位數加法但會進位：a+b > 10、a,b in [1,9]
            do {
                a = arc4random_uniform(9) + 1;
                b = arc4random_uniform(9) + 1;
            } while (a + b <= 10 || a + b > 18);
            return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"+" answer:a + b];
        }
        case LessonKindBreakTen: {
            // 11..18 - 個位數，會退位（a 個位 < b）
            do {
                a = 10 + arc4random_uniform(9) + 1;  // 11..19
                b = arc4random_uniform(9) + 1;       // 1..9
            } while ((a % 10) >= b);
            return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"-" answer:a - b];
        }
        case LessonKindMultiplication: {
            NSInteger m = self.multiplicationFactor;
            NSInteger n = arc4random_uniform(9) + 1;
            return [[ArithmeticProblem alloc] initWithNumber1:m number2:n operator:@"×" answer:m * n];
        }
    }
    return [[ArithmeticProblem alloc] initWithNumber1:0 number2:0 operator:@"+" answer:0];
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
