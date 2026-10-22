#import "ConceptLearningPath.h"
#import "ArithmeticProblem.h"
#import "WordProblem.h"
#import "GroupingStoryContext.h"

@interface ConceptLearningExample ()
@property (nonatomic, strong) ArithmeticProblem *snapshot;
@property (nonatomic, copy, readwrite) NSString *questionText;
@property (nonatomic, copy, readwrite) NSString *focusText;
@property (nonatomic, copy, readwrite) NSString *equationText;
@property (nonatomic, strong, readwrite, nullable) WordProblem *wordProblem;
- (instancetype)initWithFirst:(NSInteger)a second:(NSInteger)b operation:(NSString *)operation focus:(NSString *)focus story:(nullable WordProblem *)story;
@end
@implementation ConceptLearningExample
- (instancetype)initWithFirst:(NSInteger)a second:(NSInteger)b operation:(NSString *)operation focus:(NSString *)focus story:(WordProblem *)story {
    self = [super init];
    if (self) {
        NSInteger answer = [operation isEqualToString:@"+"] ? a + b : a - b;
        _snapshot = story ? [story toArithmeticProblem] : [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:operation answer:answer];
        _wordProblem = story;
        _focusText = [focus copy];
        NSString *symbol = [operation isEqualToString:@"-"] ? @"−" : operation;
        _equationText = [NSString stringWithFormat:@"%ld %@ %ld = ?", (long)a, symbol, (long)b];
        _questionText = story.storyText ?: @"這一題可以怎麼算？先想一想，再看每一小步。";
    }
    return self;
}
- (ArithmeticProblem *)problem {
    ArithmeticProblem *copy = [[ArithmeticProblem alloc] initWithNumber1:self.snapshot.number1 number2:self.snapshot.number2 operator:[self.snapshot.operatorSymbol copy] answer:self.snapshot.answer];
    copy.auxiliaryDistractor = self.snapshot.auxiliaryDistractor;
    copy.isMultiStep = self.snapshot.isMultiStep;
    return copy;
}
@end

@interface ConceptLearningPath ()
@property (nonatomic, copy, readwrite) NSString *pathID;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *summaryText;
@property (nonatomic, copy, readwrite) NSString *iconName;
@property (nonatomic, strong, readwrite) ConceptLearningExample *firstExample;
@property (nonatomic, strong, readwrite) ConceptLearningExample *relatedExample;
@property (nonatomic, copy, readwrite) NSArray<ConceptLearningExample *> *explorationExamples;
- (instancetype)initWithID:(NSString *)pathID title:(NSString *)title summary:(NSString *)summary icon:(NSString *)icon examples:(NSArray<ConceptLearningExample *> *)examples;
@end
@implementation ConceptLearningPath
- (instancetype)initWithID:(NSString *)pathID title:(NSString *)title summary:(NSString *)summary icon:(NSString *)icon examples:(NSArray<ConceptLearningExample *> *)examples {
    self = [super init];
    if (self) {
        _pathID = [pathID copy]; _title = [title copy]; _summaryText = [summary copy]; _iconName = [icon copy];
        _firstExample = examples[0]; _relatedExample = examples[1];
        _explorationExamples = [examples subarrayWithRange:NSMakeRange(2, examples.count - 2)];
    }
    return self;
}
+ (ConceptLearningExample *)vertical:(NSInteger)a second:(NSInteger)b operation:(NSString *)operation focus:(NSString *)focus {
    return [[ConceptLearningExample alloc] initWithFirst:a second:b operation:operation focus:focus story:nil];
}
+ (ConceptLearningExample *)grouping:(NSInteger)a second:(NSInteger)b meaning:(GroupingStoryMeaning)meaning {
    BOOL multiply = meaning == GroupingStoryMeaningBuildEqualGroups;
    BOOL share = meaning == GroupingStoryMeaningShareEqually;
    NSString *groupName = share ? @"個小朋友" : @"包";
    NSString *answerUnit = meaning == GroupingStoryMeaningMakeGroupsOf ? @"包" : @"顆";
    GroupingStoryContext *context = [[GroupingStoryContext alloc] initWithMeaning:meaning itemName:@"糖果" itemUnit:@"顆" groupName:groupName answerUnit:answerUnit];
    NSString *story; NSString *focus;
    if (multiply) {
        story = [NSString stringWithFormat:@"每包有 %ld 顆糖果，有 %ld 包一樣多的糖果。一共有幾顆糖果？", (long)a, (long)b];
        focus = @"前面的數是每包幾顆，後面的數是有幾包。一次放一包，看看總數怎麼增加。";
    } else if (share) {
        story = [NSString stringWithFormat:@"把 %ld 顆糖果平均分給 %ld 個小朋友，每人分到一樣多的整顆糖果。每人最多分到幾顆？還剩幾顆？", (long)a, (long)b];
        focus = @"小朋友的人數已經知道。每一輪，每人拿一顆；剩下的糖果放在一起。";
    } else {
        story = [NSString stringWithFormat:@"有 %ld 顆糖果，每 %ld 顆裝成一包。最多裝滿幾包？還剩幾顆？", (long)a, (long)b];
        focus = @"每包要幾顆已經知道。一次裝滿一包；答案數的是包，不是糖果顆數。";
    }
    NSString *operation = multiply ? @"×" : @"÷";
    // This reviewed producer supplies exact quantity roles. Never infer them from IDs or prose.
    WordProblem *word = [[WordProblem alloc] initWithStory:story templateID:[NSString stringWithFormat:@"concept.%ld.%ld.%ld", (long)meaning, (long)a, (long)b]
        grade:multiply ? 2 : 3 number1:a number2:b operator:operation answer:multiply ? a * b : a / b unit:answerUnit
        missingAddend:NO missingSubtrahend:NO missingMinuend:NO remainder:multiply ? 0 : a % b
        number3:0 operator2:nil intermediate:0 isFractionAnswer:NO answerNumerator:0 answerDenominator:0 groupingContext:context strategyText:focus];
    return [[ConceptLearningExample alloc] initWithFirst:a second:b operation:operation focus:focus story:word];
}
+ (NSArray<ConceptLearningPath *> *)allPaths {
    NSString *carry = @"從個位開始，想想：這一位湊滿十了嗎？十個一可以換成一個十。";
    NSString *borrow = @"個位不夠減時，先把一個十換成十個一，再繼續減。";
    NSString *zeroBorrow = @"十位是零時，到更高一位換一換。數量不變，只是換成較小的單位。";
    NSString *carryContrast = @"43 不變，另一個數只改個位：16、17、18。比較個位合起來是 9、10、11 時，哪一次要把十個一換成一個十？";
    NSString *ordinaryBorrowContrast = @"比較 112 − 38 和 102 − 38，只改被減數的十位。112 的十位有一個十，可以先換給個位；之後再看看十位夠不夠減。";
    NSString *zeroBorrowContrast = @"只把 112 的十位改成 0，就成了 102。十位是零時，先把一個百換成十個十，再換一個十給個位。";
    NSMutableArray<ConceptLearningPath *> *paths = [NSMutableArray array];
    [paths addObject:[[self alloc] initWithID:@"carry" title:@"加法進位：十個換一個" summary:@"看個位怎麼湊成十，再把一個十移到十位。" icon:@"plus.square.fill"
        examples:@[[self vertical:27 second:15 operation:@"+" focus:carry], [self vertical:36 second:18 operation:@"+" focus:carry],
                   [self vertical:43 second:16 operation:@"+" focus:carryContrast], [self vertical:43 second:17 operation:@"+" focus:carryContrast], [self vertical:43 second:18 operation:@"+" focus:carryContrast]]]];
    [paths addObject:[[self alloc] initWithID:@"borrow" title:@"減法借位：遇到零也會換" summary:@"先換一個十，再看看十位是零時怎麼辦。" icon:@"minus.square.fill"
        examples:@[[self vertical:42 second:16 operation:@"-" focus:borrow], [self vertical:102 second:38 operation:@"-" focus:zeroBorrow],
                   [self vertical:112 second:38 operation:@"-" focus:ordinaryBorrowContrast], [self vertical:102 second:38 operation:@"-" focus:zeroBorrowContrast], [self vertical:203 second:57 operation:@"-" focus:zeroBorrow]]]];
    NSArray<NSArray<NSNumber *> *> *multiplyPairs = @[@[@3, @2], @[@3, @3], @[@4, @3], @[@3, @4], @[@2, @5]];
    NSArray<NSArray<NSNumber *> *> *divisionPairs = @[@[@12, @3], @[@13, @3], @[@17, @4], @[@18, @4], @[@19, @4]];
    for (NSNumber *value in @[@(GroupingStoryMeaningBuildEqualGroups), @(GroupingStoryMeaningShareEqually), @(GroupingStoryMeaningMakeGroupsOf)]) {
        GroupingStoryMeaning meaning = value.integerValue;
        BOOL multiply = meaning == GroupingStoryMeaningBuildEqualGroups; BOOL share = meaning == GroupingStoryMeaningShareEqually;
        NSMutableArray *examples = [NSMutableArray array];
        for (NSArray<NSNumber *> *pair in multiply ? multiplyPairs : divisionPairs) {
            [examples addObject:[self grouping:pair[0].integerValue second:pair[1].integerValue meaning:meaning]];
        }
        [paths addObject:[[self alloc] initWithID:multiply ? @"equal-groups" : (share ? @"sharing" : @"packing")
            title:multiply ? @"乘法：一樣多的幾包" : (share ? @"除法：平均分給幾個人" : @"除法：每幾顆裝一包")
            summary:multiply ? @"每包一樣多，一包一包合起來。" : (share ? @"知道有幾個人，找出每人分到幾顆。" : @"知道每包有幾顆，找出能裝滿幾包。")
            icon:multiply ? @"square.grid.2x2.fill" : (share ? @"person.3.fill" : @"shippingbox.fill") examples:examples]];
    }
    return [paths copy];
}
@end
