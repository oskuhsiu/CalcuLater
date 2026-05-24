#import "ArithmeticSolution.h"

#pragma mark - BorrowInfo

@interface BorrowInfo ()
@property (nonatomic, assign, readwrite) NSInteger original;
@property (nonatomic, copy, readwrite, nullable) NSNumber *afterLending;
@property (nonatomic, copy, readwrite, nullable) NSString *afterBorrowing;
@property (nonatomic, copy, readwrite, nullable) NSNumber *lendingColorIndex;
@property (nonatomic, copy, readwrite, nullable) NSNumber *borrowingColorIndex;
@end

@implementation BorrowInfo

- (instancetype)initWithOriginal:(NSInteger)original {
    self = [super init];
    if (self) {
        _original = original;
    }
    return self;
}

@end


#pragma mark - ArithmeticSolution

@interface ArithmeticSolution ()
@property (nonatomic, strong, readwrite) ArithmeticProblem *problem;
@property (nonatomic, assign, readwrite) NSInteger maxLength;
@property (nonatomic, copy, readwrite) NSString *carries;
@property (nonatomic, copy, readwrite) NSArray<BorrowInfo *> *borrows;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *digits1;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *digits2;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *answerDigits;
@end

@implementation ArithmeticSolution

#pragma mark - Public

+ (instancetype)solutionForProblem:(ArithmeticProblem *)problem {
    ArithmeticSolution *s = [[ArithmeticSolution alloc] init];
    s.problem = problem;

    NSString *n1Str = [@(problem.number1) stringValue];
    NSString *n2Str = [@(problem.number2) stringValue];
    NSString *ansStr = [@(problem.answer) stringValue];

    NSInteger maxLen = MAX(n1Str.length, MAX(n2Str.length, ansStr.length));
    s.maxLength = maxLen;

    s.digits1 = [self digitsFromString:n1Str paddedTo:maxLen];
    s.digits2 = [self digitsFromString:n2Str paddedTo:maxLen];
    s.answerDigits = [self digitsFromString:ansStr paddedTo:maxLen];

    s.carries = [self calculateCarriesForProblem:problem maxLength:maxLen];
    s.borrows = [self calculateBorrowsForProblem:problem maxLength:maxLen];

    return s;
}

#pragma mark - Digit decomposition

/// 把整數字串拆成 NSNumber 陣列，前面以 0 補齊到 paddedLen。
/// index 0 為最高位，與字串表示一致。
+ (NSArray<NSNumber *> *)digitsFromString:(NSString *)str paddedTo:(NSInteger)paddedLen {
    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:paddedLen];
    NSInteger padCount = paddedLen - (NSInteger)str.length;
    for (NSInteger i = 0; i < padCount; i++) {
        [result addObject:@(0)];
    }
    for (NSUInteger i = 0; i < str.length; i++) {
        unichar c = [str characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [result addObject:@(c - '0')];
        } else {
            // 防呆：非數字字元（例如負號）暫以 0 視之。
            [result addObject:@(0)];
        }
    }
    return [result copy];
}

#pragma mark - Carry algorithm (port of Android calculateCarries)

+ (NSString *)calculateCarriesForProblem:(ArithmeticProblem *)problem maxLength:(NSInteger)maxLen {
    if (![problem.operatorSymbol isEqualToString:@"+"]) return @"";

    NSString *n1 = [self leftPadString:[@(problem.number1) stringValue] toLength:maxLen with:'0'];
    NSString *n2 = [self leftPadString:[@(problem.number2) stringValue] toLength:maxLen with:'0'];

    NSMutableString *result = [NSMutableString stringWithCapacity:maxLen];
    for (NSInteger i = 0; i < maxLen; i++) [result appendString:@" "];

    NSInteger carry = 0;
    // 從最右邊往左掃到 index 1。i 位產生的進位寫到 i-1。
    for (NSInteger i = maxLen - 1; i >= 1; i--) {
        NSInteger d1 = [n1 characterAtIndex:i] - '0';
        NSInteger d2 = [n2 characterAtIndex:i] - '0';
        NSInteger sum = d1 + d2 + carry;
        carry = sum / 10;
        if (carry > 0) {
            [result replaceCharactersInRange:NSMakeRange(i - 1, 1) withString:@"1"];
        }
    }

    // 處理最高位本身的進位 — 會多生出一個前導字元。
    NSInteger d1 = [n1 characterAtIndex:0] - '0';
    NSInteger d2 = [n2 characterAtIndex:0] - '0';
    NSInteger sum = d1 + d2 + carry;
    NSString *finalCarry = (sum / 10 > 0) ? @"1" : @"";

    NSString *combined = [finalCarry stringByAppendingString:result];

    // 若整段都是空白 → 回傳 @""。
    if ([[combined stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
        return @"";
    }
    return combined;
}

#pragma mark - Borrow algorithm (port of Android calculateBorrowInfo)

+ (NSArray<BorrowInfo *> *)calculateBorrowsForProblem:(ArithmeticProblem *)problem maxLength:(NSInteger)maxLen {
    if (![problem.operatorSymbol isEqualToString:@"-"]) return @[];

    NSString *n1 = [self leftPadString:[@(problem.number1) stringValue] toLength:maxLen with:'0'];
    NSString *n2 = [self leftPadString:[@(problem.number2) stringValue] toLength:maxLen with:'0'];

    NSMutableArray<BorrowInfo *> *info = [NSMutableArray arrayWithCapacity:maxLen];
    NSMutableArray<NSNumber *> *effective = [NSMutableArray arrayWithCapacity:maxLen];
    for (NSInteger i = 0; i < maxLen; i++) {
        NSInteger d = [n1 characterAtIndex:i] - '0';
        [info addObject:[[BorrowInfo alloc] initWithOriginal:d]];
        [effective addObject:@(d)];
    }

    NSInteger borrowEventCount = 0;

    for (NSInteger i = maxLen - 1; i >= 0; i--) {
        NSInteger n2d = [n2 characterAtIndex:i] - '0';
        if (effective[i].integerValue < n2d) {
            NSInteger colorIndex = borrowEventCount % 5; // 與 Android 一致：5 色循環

            // 位置 i 借入：原值 + 10。
            info[i].afterBorrowing = [NSString stringWithFormat:@"%ld", (long)(effective[i].integerValue + 10)];
            info[i].borrowingColorIndex = @(colorIndex);
            effective[i] = @(effective[i].integerValue + 10);

            // 往左找借出者。
            NSInteger j = i - 1;
            while (j >= 0) {
                NSInteger lenderEffective = effective[j].integerValue;
                effective[j] = @(lenderEffective - 1);

                // 與 Android 相同：如果這位之前已被設定 lendingColorIndex，保留先前的顏色
                // （多次借出時呈現「上一位借了又借」的延續色），否則用本次的 colorIndex。
                info[j].afterLending = @(lenderEffective - 1);
                if (info[j].lendingColorIndex == nil) {
                    info[j].lendingColorIndex = @(colorIndex);
                }

                if (lenderEffective > 0) {
                    break;
                }
                // 借出者是 0 → 視覺上變成 9 (借 10 進來、借 1 出去)。
                // 同時把 effective[j] 修正為 9，避免外層迴圈重訪這位時又誤判要再借一次。
                // （Android 版這裡留下 -1 是已知 bug；我們在 iOS 修掉。）
                info[j].afterLending = @(9);
                if (info[j].lendingColorIndex == nil) {
                    info[j].lendingColorIndex = @(colorIndex);
                }
                effective[j] = @(9);
                j--;
            }

            borrowEventCount++;
        }
    }

    return [info copy];
}

#pragma mark - Helpers

+ (NSString *)leftPadString:(NSString *)str toLength:(NSInteger)len with:(unichar)ch {
    if ((NSInteger)str.length >= len) return str;
    NSMutableString *padded = [NSMutableString stringWithCapacity:len];
    for (NSInteger i = 0; i < len - (NSInteger)str.length; i++) {
        [padded appendFormat:@"%C", ch];
    }
    [padded appendString:str];
    return [padded copy];
}

@end
