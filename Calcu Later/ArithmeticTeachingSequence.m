#import "ArithmeticTeachingSequence.h"

static const NSInteger ATMaximumValue = 99999;

static ArithmeticProblem *ATCopyProblem(ArithmeticProblem *problem) {
    ArithmeticProblem *copy = [[ArithmeticProblem alloc]
        initWithNumber1:problem ? problem.number1 : 0
               number2:problem ? problem.number2 : 0
              operator:problem.operatorSymbol ? [problem.operatorSymbol copy] : @""
                answer:problem ? problem.answer : 0];
    copy.isMultiStep = problem.isMultiStep;
    copy.auxiliaryDistractor = problem.auxiliaryDistractor;
    return copy;
}

static NSInteger ATDigitCount(NSInteger value) {
    NSInteger count = 1;
    while (value >= 10) {
        value /= 10;
        count++;
    }
    return count;
}

static NSArray<NSNumber *> *ATDigits(NSInteger value, NSInteger width) {
    NSMutableArray<NSNumber *> *digits = [NSMutableArray arrayWithCapacity:width];
    for (NSInteger i = 0; i < width; i++) {
        [digits insertObject:@(value % 10) atIndex:0];
        value /= 10;
    }
    return [digits copy];
}

static NSString *ATPlaceName(NSInteger column, NSInteger width) {
    return @[@"個位", @"十位", @"百位", @"千位", @"萬位"][width - column - 1];
}

static NSString *ATUnitName(NSInteger column, NSInteger width) {
    return @[@"一", @"十", @"百", @"千", @"萬"][width - column - 1];
}

@interface ArithmeticTeachingStep ()
@property (nonatomic, assign, readwrite) ArithmeticTeachingStepKind kind;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *explanation;
@property (nonatomic, copy, readwrite) NSString *prompt;
@property (nonatomic, copy, readwrite, nullable) NSNumber *expectedAnswer;
@property (nonatomic, assign, readwrite) NSInteger activeColumn;
@property (nonatomic, assign, readwrite) NSInteger sourceColumn;
@property (nonatomic, assign, readwrite) NSInteger destinationColumn;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *firstDigits;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *secondDigits;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *workingDigits;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *workingDigitsBefore;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *carryDigits;
@property (nonatomic, copy, readwrite) NSArray *visibleAnswerDigits;
@property (nonatomic, copy, readwrite, nullable) NSNumber *columnValue;
- (instancetype)initPrivate;
@end

@implementation ArithmeticTeachingStep
- (instancetype)initPrivate {
    return [super init];
}
@end

@interface ArithmeticTeachingSequence ()
@property (nonatomic, strong) ArithmeticProblem *storedProblem;
@property (nonatomic, assign, readwrite, getter=isValid) BOOL valid;
@property (nonatomic, assign, readwrite) NSInteger columnCount;
@property (nonatomic, copy, readwrite) NSArray<ArithmeticTeachingStep *> *steps;
@property (nonatomic, assign, readwrite) NSInteger firstOperandStartColumn;
@property (nonatomic, assign, readwrite) NSInteger secondOperandStartColumn;
@property (nonatomic, assign, readwrite) NSInteger answerStartColumn;
- (instancetype)initPrivate;
- (void)buildSteps;
@end

/// Private construction state. Each emitted step copies every mutable array.
@interface ATTeachingBuilder : NSObject
@property (nonatomic, strong) ArithmeticTeachingSequence *sequence;
@property (nonatomic, copy) NSArray<NSNumber *> *first;
@property (nonatomic, copy) NSArray<NSNumber *> *second;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *working;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *carry;
@property (nonatomic, strong) NSMutableArray *visible;
@property (nonatomic, strong) NSMutableArray<ArithmeticTeachingStep *> *steps;
- (void)appendKind:(ArithmeticTeachingStepKind)kind
            title:(NSString *)title
      explanation:(NSString *)explanation
           prompt:(NSString *)prompt
         expected:(nullable NSNumber *)expected
           column:(NSInteger)column
           source:(NSInteger)source
      destination:(NSInteger)destination
           before:(NSArray<NSNumber *> *)before
            value:(nullable NSNumber *)value;
- (void)buildAddition;
- (void)buildSubtraction;
- (void)writeColumn:(NSInteger)column value:(NSInteger)value;
@end

@implementation ArithmeticTeachingSequence

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _steps = @[];
        _firstOperandStartColumn = NSNotFound;
        _secondOperandStartColumn = NSNotFound;
        _answerStartColumn = NSNotFound;
    }
    return self;
}

- (ArithmeticProblem *)problem {
    return ATCopyProblem(self.storedProblem);
}

+ (instancetype)sequenceForProblem:(ArithmeticProblem *)problem {
    ArithmeticTeachingSequence *sequence = [[self alloc] initPrivate];
    sequence.storedProblem = ATCopyProblem(problem);
    ArithmeticProblem *snapshot = sequence.storedProblem;
    if ([snapshot.operatorSymbol isEqualToString:@"−"]) snapshot.operatorSymbol = @"-";

    // Validate bounds BEFORE arithmetic. This also makes every intermediate count
    // small and prevents unexpectedly large teaching boards or overflow.
    if (!problem || snapshot.isMultiStep ||
        snapshot.number1 < 0 || snapshot.number1 > ATMaximumValue ||
        snapshot.number2 < 0 || snapshot.number2 > ATMaximumValue ||
        snapshot.answer < 0 || snapshot.answer > ATMaximumValue) return sequence;

    BOOL addition = [snapshot.operatorSymbol isEqualToString:@"+"];
    BOOL subtraction = [snapshot.operatorSymbol isEqualToString:@"-"];
    if (!addition && !subtraction) return sequence;
    if (subtraction && snapshot.number1 < snapshot.number2) return sequence;
    NSInteger calculated = addition ? snapshot.number1 + snapshot.number2
                                    : snapshot.number1 - snapshot.number2;
    if (calculated != snapshot.answer) return sequence;

    sequence.columnCount = MAX(ATDigitCount(snapshot.number1),
        MAX(ATDigitCount(snapshot.number2), ATDigitCount(snapshot.answer)));
    sequence.firstOperandStartColumn = sequence.columnCount - ATDigitCount(snapshot.number1);
    sequence.secondOperandStartColumn = sequence.columnCount - ATDigitCount(snapshot.number2);
    sequence.answerStartColumn = sequence.columnCount - ATDigitCount(snapshot.answer);
    sequence.valid = YES;
    [sequence buildSteps];
    return sequence;
}

- (void)buildSteps {
    ArithmeticProblem *problem = self.storedProblem;
    ATTeachingBuilder *builder = [[ATTeachingBuilder alloc] init];
    builder.sequence = self;
    builder.first = ATDigits(problem.number1, self.columnCount);
    builder.second = ATDigits(problem.number2, self.columnCount);
    builder.working = [builder.first mutableCopy];
    builder.carry = [NSMutableArray arrayWithCapacity:self.columnCount];
    builder.visible = [NSMutableArray arrayWithCapacity:self.columnCount];
    builder.steps = [NSMutableArray array];
    for (NSInteger i = 0; i < self.columnCount; i++) {
        [builder.carry addObject:@0];
        [builder.visible addObject:[NSNull null]];
    }
    [builder appendKind:ArithmeticTeachingStepKindAlignment
                   title:@"先把位值對齊"
             explanation:@"個位對個位、十位對十位，從最右邊的個位開始。空白的位置當作 0。"
                  prompt:@"" expected:nil column:NSNotFound source:NSNotFound destination:NSNotFound
                  before:builder.working value:nil];
    if ([problem.operatorSymbol isEqualToString:@"+"]) [builder buildAddition];
    else [builder buildSubtraction];
    NSString *symbol = [problem.operatorSymbol isEqualToString:@"-"] ? @"−" : @"+";
    [builder appendKind:ArithmeticTeachingStepKindCompletion
                   title:@"把每一位連起來"
             explanation:[NSString stringWithFormat:@"%ld %@ %ld = %ld。從個位開始，逐位算完，再把每一位連起來。可以回到題目，也可以重看。",
                          (long)problem.number1, symbol, (long)problem.number2, (long)problem.answer]
                  prompt:@"" expected:nil column:NSNotFound source:NSNotFound destination:NSNotFound
                  before:builder.working value:nil];
    self.steps = builder.steps;
}

@end

@implementation ATTeachingBuilder

- (void)appendKind:(ArithmeticTeachingStepKind)kind
            title:(NSString *)title
      explanation:(NSString *)explanation
           prompt:(NSString *)prompt
         expected:(NSNumber *)expected
           column:(NSInteger)column
           source:(NSInteger)source
      destination:(NSInteger)destination
           before:(NSArray<NSNumber *> *)before
            value:(NSNumber *)value {
    ArithmeticTeachingStep *step = [[ArithmeticTeachingStep alloc] initPrivate];
    step.kind = kind;
    step.title = title;
    step.explanation = explanation;
    step.prompt = prompt;
    step.expectedAnswer = expected;
    step.activeColumn = column;
    step.sourceColumn = source;
    step.destinationColumn = destination;
    step.firstDigits = self.first;
    step.secondDigits = self.second;
    step.workingDigitsBefore = before;
    step.workingDigits = self.working;
    step.carryDigits = self.carry;
    step.visibleAnswerDigits = self.visible;
    step.columnValue = value;
    [self.steps addObject:step];
}

- (void)buildAddition {
    NSInteger width = self.sequence.columnCount;
    for (NSInteger column = width - 1; column >= 0; column--) {
        NSString *place = ATPlaceName(column, width);
        NSString *unit = ATUnitName(column, width);
        NSInteger first = self.first[column].integerValue;
        NSInteger second = self.second[column].integerValue;
        NSInteger carry = self.carry[column].integerValue;
        NSInteger sum = self.working[column].integerValue + second;
        NSString *expression = carry > 0
            ? [NSString stringWithFormat:@"%ld + %ld + %ld", (long)first, (long)second, (long)carry]
            : [NSString stringWithFormat:@"%ld + %ld", (long)first, (long)second];
        NSString *explanation = carry > 0
            ? [NSString stringWithFormat:@"來看%@。把兩個數和剛才換來的 %ld 個%@合在一起。", place, (long)carry, unit]
            : [NSString stringWithFormat:@"來看%@。把這一欄的兩個數合在一起。", place];
        [self appendKind:ArithmeticTeachingStepKindPrediction title:@"先想一想"
             explanation:explanation
                  prompt:[NSString stringWithFormat:@"%@：%@，一共有幾個%@？", place, expression, unit]
                expected:@(sum) column:column source:NSNotFound destination:NSNotFound
                  before:self.working value:nil];

        NSArray<NSNumber *> *before = [self.working copy];
        self.working[column] = @(sum);
        self.carry[column] = @0;
        [self appendKind:ArithmeticTeachingStepKindColumnCalculation
                   title:[NSString stringWithFormat:@"合起來看%@", place]
             explanation:[NSString stringWithFormat:@"%@ = %ld，這裡共有 %ld 個%@。", expression, (long)sum, (long)sum, unit]
                  prompt:@"" expected:nil column:column source:NSNotFound destination:NSNotFound
                  before:before value:@(sum)];

        if (sum >= 10) {
            // The validated answer has room for the carry, so column is > 0.
            NSInteger destination = column - 1;
            NSString *nextUnit = ATUnitName(destination, width);
            before = [self.working copy];
            self.working[column] = @(sum - 10);
            self.working[destination] = @(self.working[destination].integerValue + 1);
            self.carry[destination] = @1;
            [self appendKind:ArithmeticTeachingStepKindRegroup title:@"滿十，交換一次"
                 explanation:[NSString stringWithFormat:@"把 10 個%@換成 1 個%@，移到%@；%@留下 %ld 個%@。數量沒有變。",
                              unit, nextUnit, ATPlaceName(destination, width), place, (long)(sum - 10), unit]
                      prompt:@"" expected:nil column:column source:column destination:destination
                      before:before value:nil];
        }
        [self writeColumn:column value:self.working[column].integerValue];
    }
}

- (void)buildSubtraction {
    NSInteger width = self.sequence.columnCount;
    for (NSInteger column = width - 1; column >= 0; column--) {
        NSInteger second = self.second[column].integerValue;
        if (self.working[column].integerValue < second) {
            NSInteger donor = column - 1;
            while (donor >= 0 && self.working[donor].integerValue == 0) donor--;
            // Nonnegative consistent subtraction guarantees a donor exists.
            // Exchange left-to-right, one ADJACENT place at a time. A zero in
            // between genuinely becomes 10 first, then 9 on the next exchange.
            for (NSInteger source = donor; source < column; source++) {
                NSInteger destination = source + 1;
                NSString *sourceUnit = ATUnitName(source, width);
                NSString *destinationUnit = ATUnitName(destination, width);
                NSString *explanation = [NSString stringWithFormat:@"%@的數量不夠減，先從%@換到%@。",
                    ATPlaceName(column, width), ATPlaceName(source, width), ATPlaceName(destination, width)];
                [self appendKind:ArithmeticTeachingStepKindPrediction title:@"不夠減，先交換"
                     explanation:explanation
                          prompt:[NSString stringWithFormat:@"1 個%@可以換成幾個%@？", sourceUnit, destinationUnit]
                        expected:@10 column:destination source:NSNotFound destination:NSNotFound
                          before:self.working value:nil];

                NSArray<NSNumber *> *before = [self.working copy];
                self.working[source] = @(self.working[source].integerValue - 1);
                self.working[destination] = @(self.working[destination].integerValue + 10);
                [self appendKind:ArithmeticTeachingStepKindRegroup title:@"拆開一組，數量不變"
                     explanation:[NSString stringWithFormat:@"1 個%@換成 10 個%@。%@剩 %ld 個%@，%@現在有 %ld 個%@。",
                                  sourceUnit, destinationUnit, ATPlaceName(source, width),
                                  (long)self.working[source].integerValue, sourceUnit,
                                  ATPlaceName(destination, width), (long)self.working[destination].integerValue, destinationUnit]
                          prompt:@"" expected:nil column:destination source:source destination:destination
                          before:before value:nil];
            }
        }
        NSInteger first = self.working[column].integerValue;
        NSInteger difference = first - second;
        NSString *place = ATPlaceName(column, width);
        NSString *unit = ATUnitName(column, width);
        [self appendKind:ArithmeticTeachingStepKindPrediction title:@"現在試著減一減"
             explanation:[NSString stringWithFormat:@"%@現在有 %ld 個%@，拿走 %ld 個%@。", place, (long)first, unit, (long)second, unit]
                  prompt:[NSString stringWithFormat:@"%ld − %ld，還剩幾個%@？", (long)first, (long)second, unit]
                expected:@(difference) column:column source:NSNotFound destination:NSNotFound
                  before:self.working value:nil];
        [self appendKind:ArithmeticTeachingStepKindColumnCalculation
                   title:[NSString stringWithFormat:@"算出%@", place]
             explanation:[NSString stringWithFormat:@"%ld − %ld = %ld，還剩 %ld 個%@。", (long)first, (long)second, (long)difference, (long)difference, unit]
                  prompt:@"" expected:nil column:column source:NSNotFound destination:NSNotFound
                  before:self.working value:@(difference)];
        [self writeColumn:column value:difference];
    }
}

- (void)writeColumn:(NSInteger)column value:(NSInteger)value {
    BOOL leadingZero = column < self.sequence.answerStartColumn;
    if (!leadingZero) self.visible[column] = @(value);
    NSString *explanation = leadingZero
        ? @"這一欄是 0。答案最左邊多出來的 0 不用寫，其他數字的位置不變。"
        : [NSString stringWithFormat:@"在答案的%@寫 %ld；其他還沒算的位，先留空。",
           ATPlaceName(column, self.sequence.columnCount), (long)value];
    [self appendKind:ArithmeticTeachingStepKindWriteAnswer title:@"把這一位寫下來"
         explanation:explanation prompt:@"" expected:nil column:column source:NSNotFound destination:NSNotFound
              before:self.working value:@(value)];
}

@end
