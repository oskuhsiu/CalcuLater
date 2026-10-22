#import "MultiplicativeTeachingSequence.h"

@interface MultiplicativeMultiplicationState ()
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *accumulatorCounts;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *carryCounts;
@property (nonatomic, copy, readwrite) NSIndexSet *processedInputColumns;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeMultiplicationState
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeMultiplicationPayload ()
@property (nonatomic, strong, readwrite) MultiplicativeMultiplicationState *before;
@property (nonatomic, strong, readwrite) MultiplicativeMultiplicationState *after;
@property (nonatomic, assign, readwrite) NSInteger generatedUnitCount;
@property (nonatomic, assign, readwrite) NSInteger incomingCarryUnitCount;
@property (nonatomic, assign, readwrite) NSInteger exchangeBundleCount;
@property (nonatomic, assign, readwrite) BOOL writesFinalCarry;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeMultiplicationPayload
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeDivisionState ()
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *unprocessedInputCounts;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *poolCounts;
@property (nonatomic, copy, readwrite) NSArray<NSArray<NSNumber *> *> *recipientCounts;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeDivisionState
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeDivisionPayload ()
@property (nonatomic, strong, readwrite) MultiplicativeDivisionState *before;
@property (nonatomic, strong, readwrite) MultiplicativeDivisionState *after;
@property (nonatomic, assign, readwrite) NSInteger broughtDownUnitCount;
@property (nonatomic, assign, readwrite) NSInteger unitsPerRecipient;
@property (nonatomic, assign, readwrite) NSInteger totalTransferredUnitCount;
@property (nonatomic, assign, readwrite) NSInteger exchangeLargerUnitCount;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeDivisionPayload
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeDivisionWorkRow ()
@property (nonatomic, assign, readwrite) NSInteger column;
@property (nonatomic, assign, readwrite) NSInteger partialCount;
@property (nonatomic, assign, readwrite) NSInteger distributedCount;
@property (nonatomic, assign, readwrite) NSInteger remainderCount;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeDivisionWorkRow
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeTeachingStep ()
@property (nonatomic, assign, readwrite) MultiplicativeTeachingStepKind kind;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *explanation;
@property (nonatomic, copy, readwrite) NSString *spokenExplanation;
@property (nonatomic, copy, readwrite) NSString *prompt;
@property (nonatomic, copy, readwrite, nullable) NSNumber *expectedAnswer;
@property (nonatomic, assign, readwrite) NSInteger activeColumn;
@property (nonatomic, assign, readwrite) NSInteger sourceColumn;
@property (nonatomic, assign, readwrite) NSInteger destinationColumn;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeMultiplicationPayload *multiplication;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeDivisionPayload *division;
@property (nonatomic, copy, readwrite) NSArray *visibleAnswerDigits;
@property (nonatomic, copy, readwrite) NSIndexSet *completedColumns;
@property (nonatomic, copy, readwrite, nullable) NSNumber *writtenDigit;
@property (nonatomic, assign, readwrite) MultiplicativeTeachingWriteDisposition writeDisposition;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeDivisionWorkRow *> *visibleDivisionRows;
@property (nonatomic, copy, readwrite, nullable) NSNumber *visibleRemainder;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeTeachingStep
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeTeachingSequence ()
@property (nonatomic, assign, readwrite) MultiplicativeTeachingStatus status;
@property (nonatomic, assign, readwrite) MultiplicativeTeachingOperation operation;
@property (nonatomic, assign, readwrite) NSInteger columnCount;
@property (nonatomic, assign, readwrite) NSInteger operandStartColumn;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *operandDigits;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeTeachingStep *> *steps;
@property (nonatomic, strong) ArithmeticProblem *storedProblem;
- (instancetype)initPrivate;
@end

static NSArray<NSNumber *> *MTDigits(NSInteger value) {
    return @[@(value / 100), @((value / 10) % 10), @(value % 10)];
}

static NSInteger MTWeighted(NSArray<NSNumber *> *counts) {
    return counts[0].integerValue * 100 + counts[1].integerValue * 10 + counts[2].integerValue;
}

static NSString *MTPlace(NSInteger column) { return @[@"百位", @"十位", @"個位"][column]; }
static NSString *MTUnit(NSInteger column) { return @[@"百", @"十", @"一"][column]; }

static ArithmeticProblem *MTCopyProblem(ArithmeticProblem *problem) {
    ArithmeticProblem *copy = [[ArithmeticProblem alloc] initWithNumber1:problem.number1
        number2:problem.number2 operator:[problem.operatorSymbol copy] ?: @"" answer:problem.answer];
    copy.isMultiStep = problem.isMultiStep;
    copy.auxiliaryDistractor = problem.auxiliaryDistractor;
    return copy;
}

/// Only bounded validated input reaches this private builder. It owns all mutable
/// construction arrays; published states copy every level of the collections.
@interface MTSequenceBuilder : NSObject
@property (nonatomic, strong) MultiplicativeTeachingSequence *sequence;
@property (nonatomic, strong) NSMutableArray<MultiplicativeTeachingStep *> *steps;
@property (nonatomic, strong) NSMutableArray *visible;
@property (nonatomic, strong) NSMutableIndexSet *completed;
@property (nonatomic, strong) NSMutableArray<MultiplicativeDivisionWorkRow *> *rows;
@property (nonatomic, copy, nullable) NSNumber *visibleRemainder;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *accumulator;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *carry;
@property (nonatomic, strong) NSMutableIndexSet *processed;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *unprocessed;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *pool;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<NSNumber *> *> *recipients;
- (NSArray<MultiplicativeTeachingStep *> *)build;
@end

@implementation MultiplicativeTeachingSequence

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _status = MultiplicativeTeachingStatusInvalidProblem;
        _operation = MultiplicativeTeachingOperationUnknown;
        _operandStartColumn = NSNotFound;
        _operandDigits = @[];
        _steps = @[];
    }
    return self;
}

- (BOOL)isSupported { return self.status == MultiplicativeTeachingStatusSupported; }
- (ArithmeticProblem *)problem { return MTCopyProblem(self.storedProblem); }

+ (instancetype)sequenceForArithmeticProblem:(ArithmeticProblem *)problem {
    MultiplicativeTeachingSequence *sequence = [[self alloc] initPrivate];
    sequence.storedProblem = MTCopyProblem(problem);
    ArithmeticProblem *snapshot = sequence.storedProblem;
    if ([snapshot.operatorSymbol isEqualToString:@"*"]) snapshot.operatorSymbol = @"×";
    if ([snapshot.operatorSymbol isEqualToString:@"/"]) snapshot.operatorSymbol = @"÷";
    if (!problem || snapshot.isMultiStep) return sequence;
    BOOL multiply = [snapshot.operatorSymbol isEqualToString:@"×"];
    BOOL divide = [snapshot.operatorSymbol isEqualToString:@"÷"];
    if (!multiply && !divide) {
        sequence.status = MultiplicativeTeachingStatusUnsupportedOperation;
        return sequence;
    }
    sequence.operation = multiply ? MultiplicativeTeachingOperationMultiplication : MultiplicativeTeachingOperationDivision;
    NSInteger a = snapshot.number1, b = snapshot.number2, answer = snapshot.answer;
    if (a < 0 || b < 0 || answer < 0 || (divide && b == 0)) return sequence;
    // Check every input bound before multiplication, division, modulo, digit
    // extraction, loops or recipient allocation. No potentially overflowing math.
    if (a > 999 || b > 9 || answer > 999) {
        sequence.status = MultiplicativeTeachingStatusOutsideBounds;
        return sequence;
    }
    if (multiply && b == 0) {
        if (answer != 0) return sequence;
        sequence.status = MultiplicativeTeachingStatusUnsupportedZeroMultiplier;
        return sequence;
    }
    NSInteger calculated = multiply ? a * b : a / b;
    if (multiply && calculated > 999) {
        sequence.status = MultiplicativeTeachingStatusOutsideBounds;
        return sequence;
    }
    if (answer != calculated) return sequence;

    sequence.columnCount = 3;
    sequence.operandStartColumn = a >= 100 ? 0 : (a >= 10 ? 1 : 2);
    sequence.operandDigits = MTDigits(a);
    MTSequenceBuilder *builder = [[MTSequenceBuilder alloc] init];
    builder.sequence = sequence;
    sequence.steps = [builder build];
    sequence.status = MultiplicativeTeachingStatusSupported;
    return sequence;
}
@end

@implementation MTSequenceBuilder

- (MultiplicativeMultiplicationState *)multiplicationState {
    MultiplicativeMultiplicationState *state = [[MultiplicativeMultiplicationState alloc] initPrivate];
    state.accumulatorCounts = self.accumulator;
    state.carryCounts = self.carry;
    state.processedInputColumns = self.processed;
    return state;
}

- (MultiplicativeDivisionState *)divisionState {
    MultiplicativeDivisionState *state = [[MultiplicativeDivisionState alloc] initPrivate];
    state.unprocessedInputCounts = self.unprocessed;
    state.poolCounts = self.pool;
    NSMutableArray<NSArray<NSNumber *> *> *rows = [NSMutableArray arrayWithCapacity:self.recipients.count];
    for (NSArray<NSNumber *> *recipient in self.recipients) [rows addObject:[recipient copy]];
    state.recipientCounts = rows;
    return state;
}

- (MultiplicativeTeachingStep *)begin:(MultiplicativeTeachingStepKind)kind
                               column:(NSInteger)column title:(NSString *)title explanation:(NSString *)explanation {
    MultiplicativeTeachingStep *step = [[MultiplicativeTeachingStep alloc] initPrivate];
    step.kind = kind;
    step.title = title;
    step.explanation = explanation;
    step.prompt = @"";
    step.activeColumn = column;
    step.sourceColumn = NSNotFound;
    step.destinationColumn = NSNotFound;
    if (self.sequence.operation == MultiplicativeTeachingOperationMultiplication) {
        step.multiplication = [[MultiplicativeMultiplicationPayload alloc] initPrivate];
        step.multiplication.before = [self multiplicationState];
    } else {
        step.division = [[MultiplicativeDivisionPayload alloc] initPrivate];
        step.division.before = [self divisionState];
    }
    return step;
}

- (void)finish:(MultiplicativeTeachingStep *)step {
    if (step.multiplication) step.multiplication.after = [self multiplicationState];
    else step.division.after = [self divisionState];
    step.visibleAnswerDigits = self.visible;
    step.completedColumns = self.completed;
    step.visibleDivisionRows = self.rows;
    step.visibleRemainder = self.visibleRemainder;
    NSMutableArray<NSString *> *spoken = [NSMutableArray arrayWithObject:step.explanation];
    if (step.prompt.length) [spoken addObject:step.prompt];
    NSMutableArray<NSString *> *written = [NSMutableArray array];
    for (NSInteger column = 0; column < 3; column++) {
        id digit = self.visible[column];
        if ([digit isKindOfClass:NSNumber.class]) {
            [written addObject:[NSString stringWithFormat:@"%@寫 %@", MTPlace(column), digit]];
        }
    }
    [spoken addObject:written.count ? [written componentsJoinedByString:@"，"] : @"答案還沒寫。"];
    if (self.visibleRemainder) [spoken addObject:[NSString stringWithFormat:@"共同的餘數是 %@。", self.visibleRemainder]];
    step.spokenExplanation = [spoken componentsJoinedByString:@" "];
    [self.steps addObject:step];
}

- (void)predictAtColumn:(NSInteger)column prompt:(NSString *)prompt expected:(NSInteger)expected {
    MultiplicativeTeachingStep *step = [self begin:MultiplicativeTeachingStepKindPredict
        column:column title:@"先想一想" explanation:@"可以先想想，也可以直接看示範；這裡不計分。"];
    step.prompt = prompt;
    step.expectedAnswer = @(expected);
    [self finish:step];
}

- (void)writeMultiplicationColumn:(NSInteger)column finalCarry:(BOOL)finalCarry {
    NSInteger digit = self.accumulator[column].integerValue;
    NSString *explanation = finalCarry
        ? [NSString stringWithFormat:@"原來的每一位都乘完了。換來的 %ld 個%@直接寫在%@，不用再乘一次。",
            (long)digit, MTUnit(column), MTPlace(column)]
        : [NSString stringWithFormat:@"%@留下 %ld 個%@，在答案的%@寫 %ld；還沒算的位先留空。",
            MTPlace(column), (long)digit, MTUnit(column), MTPlace(column), (long)digit];
    MultiplicativeTeachingStep *step = [self begin:MultiplicativeTeachingStepKindWriteDigit
        column:column title:finalCarry ? @"把最後換來的數量寫下來" : @"寫下這一位" explanation:explanation];
    step.multiplication.writesFinalCarry = finalCarry;
    if (finalCarry) self.carry[column] = @0;
    self.visible[column] = @(digit);
    [self.completed addIndex:column];
    step.writtenDigit = @(digit);
    step.writeDisposition = MultiplicativeTeachingWriteDispositionWritten;
    [self finish:step];
}

- (void)buildMultiplication {
    NSInteger multiplier = self.sequence.storedProblem.number2;
    for (NSInteger column = 2; column >= self.sequence.operandStartColumn; column--) {
        NSInteger digit = self.sequence.operandDigits[column].integerValue;
        NSInteger incoming = self.accumulator[column].integerValue;
        NSInteger generated = digit * multiplier;
        NSInteger total = generated + incoming;
        NSString *prompt = incoming > 0
            ? [NSString stringWithFormat:@"%ld 個%@乘以 %ld，再加上換來的 %ld 個%@，一共有幾個%@？",
                (long)digit, MTUnit(column), (long)multiplier, (long)incoming, MTUnit(column), MTUnit(column)]
            : [NSString stringWithFormat:@"%ld 個%@乘以 %ld，一共有幾個%@？",
                (long)digit, MTUnit(column), (long)multiplier, MTUnit(column)];
        [self predictAtColumn:column prompt:prompt expected:total];
        NSString *explanation = [NSString stringWithFormat:@"%ld 個%@取 %ld 份，是 %ld 個%@。",
            (long)digit, MTUnit(column), (long)multiplier, (long)generated, MTUnit(column)];
        if (incoming > 0) explanation = [explanation stringByAppendingFormat:@"再合入換來的 %ld 個%@，共有 %ld 個%@；換來的數量只加一次，不再乘。",
            (long)incoming, MTUnit(column), (long)total, MTUnit(column)];
        MultiplicativeTeachingStep *calculate = [self begin:MultiplicativeTeachingStepKindMultiplyPlace
            column:column title:[NSString stringWithFormat:@"先看%@的數量", MTPlace(column)] explanation:explanation];
        calculate.multiplication.generatedUnitCount = generated;
        calculate.multiplication.incomingCarryUnitCount = incoming;
        self.accumulator[column] = @(total);
        self.carry[column] = @0;
        [self.processed addIndex:column];
        [self finish:calculate];

        NSInteger bundles = total / 10;
        if (bundles > 0) {
            NSInteger destination = column - 1;
            // A valid product <=999 guarantees destination is within three places.
            MultiplicativeTeachingStep *exchange = [self begin:MultiplicativeTeachingStepKindRegroupUp
                column:column title:@"每十個，換成一個較大的單位"
                explanation:[NSString stringWithFormat:@"把 %ld 個%@換成 %ld 個%@，移到%@。%@留下 %ld 個%@，數量沒有變。",
                    (long)(bundles * 10), MTUnit(column), (long)bundles, MTUnit(destination),
                    MTPlace(destination), MTPlace(column), (long)(total % 10), MTUnit(column)]];
            exchange.sourceColumn = column;
            exchange.destinationColumn = destination;
            exchange.multiplication.exchangeBundleCount = bundles;
            self.accumulator[column] = @(total % 10);
            self.accumulator[destination] = @(self.accumulator[destination].integerValue + bundles);
            self.carry[destination] = @(bundles);
            [self finish:exchange];
        }
        [self writeMultiplicationColumn:column finalCarry:NO];
    }
    NSInteger finalColumn = self.sequence.operandStartColumn - 1;
    if (finalColumn >= 0 && self.accumulator[finalColumn].integerValue > 0) {
        [self writeMultiplicationColumn:finalColumn finalCarry:YES];
    }
    NSInteger result = MTWeighted(self.accumulator);
    MultiplicativeTeachingStep *verify = [self begin:MultiplicativeTeachingStepKindVerify column:NSNotFound
        title:@"把各個位值合起來檢查"
        explanation:[NSString stringWithFormat:@"現在有 %@ 個百、%@ 個十、%@ 個一，合起來是 %ld。%ld × %ld = %ld。",
            self.accumulator[0], self.accumulator[1], self.accumulator[2], (long)result,
            (long)self.sequence.storedProblem.number1, (long)multiplier, (long)result]];
    [self finish:verify];
}

- (void)buildDivision {
    NSInteger divisor = self.sequence.storedProblem.number2;
    BOOL quotientStarted = NO;
    for (NSInteger column = self.sequence.operandStartColumn; column < 3; column++) {
        NSInteger originalCount = self.unprocessed[column].integerValue;
        NSInteger exchangedCount = self.pool[column].integerValue;
        MultiplicativeTeachingStep *bring = [self begin:MultiplicativeTeachingStepKindBringDown column:column
            title:column == self.sequence.operandStartColumn ? @"先看最高的位" : @"把原來下一位的數量帶下來"
            explanation:[NSString stringWithFormat:@"把原來的 %ld 個%@放進共同待分區，和這裡已有的 %ld 個%@合起來，共有 %ld 個%@。這一步沒有改變單位。",
                (long)originalCount, MTUnit(column), (long)exchangedCount, MTUnit(column),
                (long)(originalCount + exchangedCount), MTUnit(column)]];
        bring.division.broughtDownUnitCount = originalCount;
        self.unprocessed[column] = @0;
        self.pool[column] = @(exchangedCount + originalCount);
        [self finish:bring];

        NSInteger partial = self.pool[column].integerValue;
        NSInteger quotientDigit = partial / divisor;
        NSInteger distributed = quotientDigit * divisor;
        NSInteger remainder = partial % divisor;
        [self predictAtColumn:column
            prompt:[NSString stringWithFormat:@"把 %ld 個%@平均分成 %ld 份，每份最多分到幾個完整的%@？",
                (long)partial, MTUnit(column), (long)divisor, MTUnit(column)] expected:quotientDigit];
        MultiplicativeTeachingStep *share = [self begin:MultiplicativeTeachingStepKindDistribute column:column
            title:@"每一份都分到一樣多"
            explanation:[NSString stringWithFormat:@"每份分到 %ld 個%@，%ld 份共分出 %ld 個%@，共同待分區剩下 %ld 個%@。",
                (long)quotientDigit, MTUnit(column), (long)divisor, (long)distributed, MTUnit(column), (long)remainder, MTUnit(column)]];
        share.division.unitsPerRecipient = quotientDigit;
        share.division.totalTransferredUnitCount = distributed;
        for (NSMutableArray<NSNumber *> *recipient in self.recipients) {
            recipient[column] = @(recipient[column].integerValue + quotientDigit);
        }
        self.pool[column] = @(remainder);
        [self finish:share];

        BOOL suppress = quotientDigit == 0 && !quotientStarted && column < 2;
        NSString *explanation = suppress
            ? [NSString stringWithFormat:@"每份還分不到 1 個%@，商最前面的 0 先不寫；%@的位置仍然保留。",
                MTUnit(column), MTPlace(column)]
            : [NSString stringWithFormat:@"每份有 %ld 個%@，商的%@寫 %ld。%@",
                (long)quotientDigit, MTUnit(column), MTPlace(column), (long)quotientDigit,
                quotientDigit == 0 && quotientStarted ? @"商已經開始，中間的 0 一定要寫，不能把後面的位移過來。" : @"其他還沒算的位先留空。"];
        MultiplicativeTeachingStep *write = [self begin:MultiplicativeTeachingStepKindWriteDigit column:column
            title:@"記下這一位和分出去的數量" explanation:explanation];
        [self.completed addIndex:column];
        write.writtenDigit = @(quotientDigit);
        write.writeDisposition = suppress ? MultiplicativeTeachingWriteDispositionSuppressedLeadingZero
                                          : MultiplicativeTeachingWriteDispositionWritten;
        if (!suppress) {
            self.visible[column] = @(quotientDigit);
            quotientStarted = YES;
        }
        MultiplicativeDivisionWorkRow *row = [[MultiplicativeDivisionWorkRow alloc] initPrivate];
        row.column = column;
        row.partialCount = partial;
        row.distributedCount = distributed;
        row.remainderCount = remainder;
        [self.rows addObject:row];
        [self finish:write];

        if (remainder > 0 && column < 2) {
            NSInteger destination = column + 1;
            MultiplicativeTeachingStep *exchange = [self begin:MultiplicativeTeachingStepKindRegroupDown column:column
                title:@"還沒分完，換成下一位的單位"
                explanation:[NSString stringWithFormat:@"共同剩下的 %ld 個%@，換成 %ld 個%@。數量不變；原來%@的數量還沒帶下來。",
                    (long)remainder, MTUnit(column), (long)(remainder * 10), MTUnit(destination), MTPlace(destination)]];
            exchange.sourceColumn = column;
            exchange.destinationColumn = destination;
            exchange.division.exchangeLargerUnitCount = remainder;
            self.pool[column] = @0;
            self.pool[destination] = @(self.pool[destination].integerValue + remainder * 10);
            [self finish:exchange];
        }
    }

    NSInteger remainder = self.pool[2].integerValue;
    NSString *explanation = remainder > 0
        ? [NSString stringWithFormat:@"共同剩下 %ld 個一。要讓 %ld 份各再拿 1 個一，需要 %ld 個一，現在不夠；餘數是 %ld，不是每份各剩 %ld。",
            (long)remainder, (long)divisor, (long)divisor, (long)remainder, (long)remainder]
        : @"共同待分區剩下 0 個一，已經全部平均分完，沒有餘數。";
    MultiplicativeTeachingStep *inspect = [self begin:MultiplicativeTeachingStepKindInspectRemainder column:NSNotFound
        title:@"看看為什麼停下來" explanation:explanation];
    self.visibleRemainder = @(remainder);
    [self finish:inspect];
    NSInteger quotient = MTWeighted(self.recipients.firstObject);
    NSInteger distributedTotal = quotient * divisor;
    MultiplicativeTeachingStep *verify = [self begin:MultiplicativeTeachingStepKindVerify column:NSNotFound
        title:@"放回原來的數量檢查"
        explanation:[NSString stringWithFormat:@"每份有 %ld，%ld 份共 %ld，加上共同剩下的 %ld，正好是原來的 %ld。%ld × %ld + %ld = %ld。",
            (long)quotient, (long)divisor, (long)distributedTotal, (long)remainder,
            (long)self.sequence.storedProblem.number1, (long)quotient, (long)divisor,
            (long)remainder, (long)(distributedTotal + remainder)]];
    [self finish:verify];
}

- (NSArray<MultiplicativeTeachingStep *> *)build {
    self.steps = [NSMutableArray array];
    self.visible = [NSMutableArray arrayWithObjects:[NSNull null], [NSNull null], [NSNull null], nil];
    self.completed = [NSMutableIndexSet indexSet];
    self.rows = [NSMutableArray array];
    BOOL multiply = self.sequence.operation == MultiplicativeTeachingOperationMultiplication;
    ArithmeticProblem *problem = self.sequence.storedProblem;
    if (multiply) {
        self.accumulator = [@[@0, @0, @0] mutableCopy];
        self.carry = [@[@0, @0, @0] mutableCopy];
        self.processed = [NSMutableIndexSet indexSet];
    } else {
        self.unprocessed = [self.sequence.operandDigits mutableCopy];
        self.pool = [@[@0, @0, @0] mutableCopy];
        self.recipients = [NSMutableArray arrayWithCapacity:problem.number2];
        for (NSInteger recipient = 0; recipient < problem.number2; recipient++) {
            [self.recipients addObject:[@[@0, @0, @0] mutableCopy]];
        }
    }
    NSString *explanation = multiply
        ? [NSString stringWithFormat:@"看 %ld × %ld。百位、十位、個位分開看，從個位開始。原來每一位的數量取 %ld 份；換來的單位另外合入。",
            (long)problem.number1, (long)problem.number2, (long)problem.number2]
        : [NSString stringWithFormat:@"用平均分的方式看 %ld ÷ %ld。把原來的數量平均分成 %ld 份，從最高的位開始；不夠分的單位可以換成下一位的單位。",
            (long)problem.number1, (long)problem.number2, (long)problem.number2];
    MultiplicativeTeachingStep *observe = [self begin:MultiplicativeTeachingStepKindObserve column:NSNotFound
        title:@"先看每一位代表什麼" explanation:explanation];
    [self finish:observe];
    if (multiply) [self buildMultiplication];
    else [self buildDivision];
    MultiplicativeTeachingStep *complete = [self begin:MultiplicativeTeachingStepKindCompletion column:NSNotFound
        title:@"換你試試看" explanation:@"可以回到原來的題目，自己選出答案；這個示範不會替你作答。"];
    [self finish:complete];
    return [self.steps copy];
}
@end
