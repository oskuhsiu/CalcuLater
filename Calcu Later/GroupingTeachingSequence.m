#import "GroupingTeachingSequence.h"
#import "GroupingTeachingAction.h"
#import "WordProblem.h"

static ArithmeticProblem *GTCopyArithmetic(ArithmeticProblem *problem) {
    ArithmeticProblem *copy = [[ArithmeticProblem alloc] initWithNumber1:problem.number1
        number2:problem.number2 operator:[problem.operatorSymbol copy] ?: @"" answer:problem.answer];
    copy.isMultiStep = problem.isMultiStep;
    copy.auxiliaryDistractor = problem.auxiliaryDistractor;
    return copy;
}

static WordProblem *GTCopyStory(WordProblem *problem) {
    if (!problem) return nil;
    return [[WordProblem alloc] initWithStory:[problem.storyText copy]
        templateID:[problem.templateID copy] grade:problem.grade
        number1:problem.number1 number2:problem.number2 operator:[problem.operatorSymbol copy]
        answer:problem.answer unit:[problem.unit copy]
        missingAddend:problem.missingAddend missingSubtrahend:problem.missingSubtrahend
        missingMinuend:problem.missingMinuend remainder:problem.remainder
        number3:problem.number3 operator2:[problem.operator2 copy] intermediate:problem.intermediate
        isFractionAnswer:problem.isFractionAnswer answerNumerator:problem.answerNumerator
        answerDenominator:problem.answerDenominator groupingContext:[problem.groupingContext copy]
        strategyText:[problem.strategyText copy]];
}

static BOOL GTKnownMeaning(GroupingStoryMeaning meaning) {
    return meaning == GroupingStoryMeaningBuildEqualGroups ||
           meaning == GroupingStoryMeaningShareEqually ||
           meaning == GroupingStoryMeaningMakeGroupsOf;
}

static BOOL GTLabelIsPresent(NSString *label) {
    return [label stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
}

static NSInteger GTSum(NSArray<NSNumber *> *counts) {
    NSInteger total = 0;
    for (NSNumber *count in counts) total += count.integerValue;
    return total;
}

@interface GroupingTeachingStep ()
@property (nonatomic, assign, readwrite) GroupingTeachingStepKind kind;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *explanation;
@property (nonatomic, copy, readwrite) NSString *spokenExplanation;
@property (nonatomic, copy, readwrite) NSString *actionTitle;
@property (nonatomic, copy, readwrite) NSString *prompt;
@property (nonatomic, assign, readwrite) GroupingTeachingPredictionKind predictionKind;
@property (nonatomic, copy, readwrite, nullable) NSNumber *expectedAnswer;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *groupCountsBefore;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *groupCountsAfter;
@property (nonatomic, copy, readwrite, nullable) NSNumber *poolCountBefore;
@property (nonatomic, copy, readwrite, nullable) NSNumber *poolCountAfter;
@property (nonatomic, copy, readwrite, nullable) NSNumber *unopenedGroupCount;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeGroupIndices;
@property (nonatomic, assign, readwrite) NSInteger transferCount;
@property (nonatomic, copy, readwrite, nullable) NSNumber *visibleAnswer;
@property (nonatomic, copy, readwrite, nullable) NSNumber *visibleRemainder;
- (instancetype)initPrivate;
@end

@implementation GroupingTeachingStep
- (instancetype)initPrivate { return [super init]; }
@end

@interface GroupingTeachingSequence ()
@property (nonatomic, assign, readwrite) GroupingTeachingStatus status;
@property (nonatomic, strong) ArithmeticProblem *storedProblem;
@property (nonatomic, strong, nullable) WordProblem *storedWordProblem;
@property (nonatomic, copy, readwrite, nullable) GroupingStoryContext *context;
@property (nonatomic, assign, readwrite) NSInteger remainder;
@property (nonatomic, copy, readwrite) NSArray<GroupingTeachingStep *> *steps;
@property (nonatomic, assign) NSInteger groupCount;
@property (nonatomic, assign) NSInteger groupSize;
@property (nonatomic, assign) NSInteger total;
- (instancetype)initPrivate;
- (void)validateAndBuildIncludingPredictions:(BOOL)includePredictions;
@end

/// Private construction state. Only bounded, validated quantities reach this builder.
@interface GTSequenceBuilder : NSObject
@property (nonatomic, strong) GroupingTeachingSequence *sequence;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *groups;
@property (nonatomic, strong) NSMutableArray<GroupingTeachingStep *> *steps;
@property (nonatomic, copy, nullable) NSNumber *pool;
@property (nonatomic, copy, nullable) NSNumber *visibleAnswer;
@property (nonatomic, copy, nullable) NSNumber *visibleRemainder;
@property (nonatomic, assign) BOOL includePredictions;
- (NSArray<GroupingTeachingStep *> *)build;
- (void)inspectRemainder;
- (void)finish;
@end

@implementation GroupingTeachingSequence

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _status = GroupingTeachingStatusInvalidProblem;
        _steps = @[];
    }
    return self;
}

- (BOOL)isSupported { return self.status == GroupingTeachingStatusSupported; }
- (ArithmeticProblem *)problem { return GTCopyArithmetic(self.storedProblem); }
- (WordProblem *)wordProblem { return GTCopyStory(self.storedWordProblem); }

+ (instancetype)sequenceForWordProblem:(WordProblem *)problem {
    return [self sequenceForWordProblem:problem includePredictions:YES];
}

+ (instancetype)sequenceForWordProblem:(WordProblem *)problem includePredictions:(BOOL)includePredictions {
    GroupingTeachingSequence *sequence = [[self alloc] initPrivate];
    // Copy the full story BEFORE validation; the arithmetic bridge deliberately loses context.
    sequence.storedWordProblem = GTCopyStory(problem);
    WordProblem *story = sequence.storedWordProblem;
    sequence.storedProblem = [[ArithmeticProblem alloc] initWithNumber1:story.number1
        number2:story.number2 operator:[story.operatorSymbol copy] ?: @"" answer:story.answer];
    sequence.context = story.groupingContext;
    sequence.remainder = story.remainder;
    if (!story || story.missingAddend || story.missingSubtrahend || story.missingMinuend ||
        story.operator2 != nil || story.number3 != 0 || story.intermediate != 0 ||
        story.isFractionAnswer || story.answerNumerator != 0 || story.answerDenominator != 0) return sequence;
    [sequence validateAndBuildIncludingPredictions:includePredictions];
    return sequence;
}

+ (instancetype)sequenceForArithmeticProblem:(ArithmeticProblem *)problem meaning:(GroupingStoryMeaning)meaning {
    return [self sequenceForArithmeticProblem:problem meaning:meaning includePredictions:YES];
}

+ (instancetype)sequenceForArithmeticProblem:(ArithmeticProblem *)problem
                                   meaning:(GroupingStoryMeaning)meaning
                        includePredictions:(BOOL)includePredictions {
    GroupingTeachingSequence *sequence = [[self alloc] initPrivate];
    sequence.storedProblem = GTCopyArithmetic(problem);
    ArithmeticProblem *snapshot = sequence.storedProblem;
    if ([snapshot.operatorSymbol isEqualToString:@"*"]) snapshot.operatorSymbol = @"×";
    if ([snapshot.operatorSymbol isEqualToString:@"/"]) snapshot.operatorSymbol = @"÷";
    if (!problem || snapshot.isMultiStep) return sequence;
    if (GTKnownMeaning(meaning)) {
        sequence.context = [[GroupingStoryContext alloc] initWithMeaning:meaning itemName:@"物件"
            itemUnit:@"個" groupName:@"組"
            answerUnit:meaning == GroupingStoryMeaningMakeGroupsOf ? @"組" : @"個"];
    }
    // Only bare arithmetic lacks a remainder field. Do not use auxiliaryDistractor as one.
    if ([snapshot.operatorSymbol isEqualToString:@"÷"] && snapshot.number1 >= 0 && snapshot.number2 > 0) {
        sequence.remainder = snapshot.number1 % snapshot.number2;
    }
    [sequence validateAndBuildIncludingPredictions:includePredictions];
    return sequence;
}

- (void)validateAndBuildIncludingPredictions:(BOOL)includePredictions {
    ArithmeticProblem *problem = self.storedProblem;
    NSInteger a = problem.number1, b = problem.number2, answer = problem.answer, r = self.remainder;
    if (a < 0 || b < 0 || answer < 0 || r < 0 || problem.isMultiStep) return;
    BOOL multiply = [problem.operatorSymbol isEqualToString:@"×"];
    BOOL divide = [problem.operatorSymbol isEqualToString:@"÷"];
    if (!multiply && !divide) {
        self.status = GroupingTeachingStatusMissingOrUnsupportedMeaning;
        return;
    }
    // Validate arithmetic without overflow and BEFORE allocating groups or taking any numeric loop.
    if (multiply) {
        if (r != 0 || (a != 0 && b > NSIntegerMax / a)) return;
        if (answer != a * b) return;
    } else {
        if (b == 0 || r >= b || a / b != answer || a % b != r) return;
    }
    GroupingStoryContext *context = self.context;
    if (!context || !GTKnownMeaning(context.meaning)) {
        self.status = GroupingTeachingStatusMissingOrUnsupportedMeaning;
        return;
    }
    if (!GTLabelIsPresent(context.itemName) || !GTLabelIsPresent(context.itemUnit) ||
        !GTLabelIsPresent(context.groupName) || !GTLabelIsPresent(context.answerUnit)) return;
    BOOL build = context.meaning == GroupingStoryMeaningBuildEqualGroups;
    BOOL share = context.meaning == GroupingStoryMeaningShareEqually;
    if (build != multiply) return;
    NSString *expectedUnit = share || build ? context.itemUnit : context.groupName;
    if (![context.answerUnit isEqualToString:expectedUnit] ||
        (self.storedWordProblem && ![self.storedWordProblem.unit isEqualToString:context.answerUnit])) return;

    NSInteger g = build || share ? b : answer;
    NSInteger s = build ? a : (share ? answer : b);
    NSInteger total = build ? answer : a;
    // Including the leftover tray, never more than nine rows. In particular, never
    // construct quotient-sized empty packing boxes and then discover an oversized board.
    if (g > 9 || s > 10 || total > 90 || (r > 0 && g >= 9)) {
        self.status = GroupingTeachingStatusOutsideConcreteBounds;
        return;
    }
    self.groupCount = g;
    self.groupSize = s;
    self.total = total;
    GTSequenceBuilder *builder = [[GTSequenceBuilder alloc] init];
    builder.sequence = self;
    builder.includePredictions = includePredictions;
    self.steps = [builder build];
    self.status = GroupingTeachingStatusSupported;
}

@end

@implementation GTSequenceBuilder

- (NSString *)stateSummary {
    GroupingStoryContext *context = self.sequence.context;
    NSString *unit = context.itemUnit, *group = context.groupName;
    if (context.meaning == GroupingStoryMeaningBuildEqualGroups) {
        return [NSString stringWithFormat:@"現在有 %ld %@，每%@的%@有 %ld %@；還有 %ld %@尚未建立。",
            (long)self.groups.count, group, group, context.itemName, (long)self.sequence.groupSize, unit,
            (long)(self.sequence.groupCount - (NSInteger)self.groups.count), group];
    }
    if (context.meaning == GroupingStoryMeaningShareEqually) {
        NSInteger each = self.groups.firstObject.integerValue;
        return [NSString stringWithFormat:@"%ld %@，每%@的%@現在有 %ld %@；共同待分的%@還有 %ld %@。",
            (long)self.groups.count, group, group, context.itemName, (long)each, unit,
            context.itemName, (long)self.pool.integerValue, unit];
    }
    return [NSString stringWithFormat:@"已完成 %ld %@，每%@的%@有 %ld %@；待分組的%@還有 %ld %@。",
        (long)self.groups.count, group, group, context.itemName, (long)self.sequence.groupSize, unit,
        context.itemName, (long)self.pool.integerValue, unit];
}

- (void)appendKind:(GroupingTeachingStepKind)kind title:(NSString *)title
      explanation:(NSString *)explanation action:(NSString *)action
           prompt:(NSString *)prompt prediction:(GroupingTeachingPredictionKind)prediction
         expected:(NSNumber *)expected before:(NSArray<NSNumber *> *)before
       poolBefore:(NSNumber *)poolBefore active:(NSArray<NSNumber *> *)active transfer:(NSInteger)transfer {
    GroupingTeachingStep *step = [[GroupingTeachingStep alloc] initPrivate];
    step.kind = kind;
    step.title = title;
    step.explanation = explanation;
    step.actionTitle = action;
    step.prompt = prompt;
    step.predictionKind = prediction;
    step.expectedAnswer = expected;
    step.groupCountsBefore = before;
    step.groupCountsAfter = self.groups;
    step.poolCountBefore = poolBefore;
    step.poolCountAfter = self.pool;
    if (self.sequence.context.meaning == GroupingStoryMeaningBuildEqualGroups) {
        step.unopenedGroupCount = @(self.sequence.groupCount - (NSInteger)self.groups.count);
    }
    step.activeGroupIndices = active;
    step.transferCount = transfer;
    step.visibleAnswer = self.visibleAnswer;
    step.visibleRemainder = self.visibleRemainder;
    step.spokenExplanation = [NSString stringWithFormat:@"%@ %@%@", explanation, [self stateSummary],
        prompt.length ? [@" " stringByAppendingString:prompt] : @""];
    [self.steps addObject:step];
}

- (void)appendSettledKind:(GroupingTeachingStepKind)kind title:(NSString *)title explanation:(NSString *)explanation {
    [self appendKind:kind title:title explanation:explanation action:@"" prompt:@""
        prediction:GroupingTeachingPredictionKindNone expected:nil before:self.groups
        poolBefore:self.pool active:@[] transfer:0];
}

- (void)predict:(NSString *)prompt kind:(GroupingTeachingPredictionKind)kind expected:(NSNumber *)expected {
    if (!self.includePredictions) return;
    [self appendKind:GroupingTeachingStepKindPredict title:@"先想一想"
        explanation:@"可以先猜一猜，也可以直接看這一步；不計分。" action:@"" prompt:prompt
        prediction:kind expected:expected before:self.groups poolBefore:self.pool active:@[] transfer:0];
}

- (NSArray<GroupingTeachingStep *> *)build {
    self.groups = [NSMutableArray array];
    self.steps = [NSMutableArray array];
    GroupingStoryContext *context = self.sequence.context;
    BOOL build = context.meaning == GroupingStoryMeaningBuildEqualGroups;
    BOOL share = context.meaning == GroupingStoryMeaningShareEqually;
    NSInteger g = self.sequence.groupCount, s = self.sequence.groupSize;
    NSString *item = context.itemName, *unit = context.itemUnit, *group = context.groupName;
    if (!build) self.pool = @(self.sequence.total);
    if (share) for (NSInteger recipient = 0; recipient < g; recipient++) [self.groups addObject:@0];

    NSString *observe;
    if (build) observe = [NSString stringWithFormat:@"每%@的%@有 %ld %@，要建立 %ld %@。一次建立一%@，看看合起來有多少。",
        group, item, (long)s, unit, (long)g, group, group];
    else if (share) observe = [NSString stringWithFormat:@"把%@ %ld %@平均分給 %ld %@。每一輪都讓每%@拿 1 %@。",
        item, (long)self.sequence.total, unit, (long)g, group, group, unit];
    else observe = [NSString stringWithFormat:@"%@共有 %ld %@，每%@要有 %ld %@。一次分出完整的一%@，看看能分成幾%@。",
        item, (long)self.sequence.total, unit, group, (long)s, unit, group, group];
    [self appendSettledKind:GroupingTeachingStepKindObserve title:@"先看題目的規則" explanation:observe];

    NSInteger actions = share ? s : g;
    for (NSInteger index = 0; index < actions; index++) {
        NSInteger nextCount = share ? index + 1 : (build ? GTSum(self.groups) + s : (NSInteger)self.groups.count + 1);
        NSString *prompt = share
            ? [NSString stringWithFormat:@"每%@再拿 1 %@後，每%@會有幾%@？", group, unit, group, unit]
            : (build ? [NSString stringWithFormat:@"再建立一%@後，現在的%@合起來有幾%@？", group, item, unit]
                     : [NSString stringWithFormat:@"再分出一%@後，完成的數量會是幾%@？", group, group]);
        [self predict:prompt kind:GroupingTeachingPredictionKindCount expected:@(nextCount)];
        NSArray<NSNumber *> *before = [self.groups copy];
        NSNumber *poolBefore = self.pool;
        NSMutableArray<NSNumber *> *active = [NSMutableArray array];
        NSString *explanation, *action;
        if (share) {
            for (NSInteger recipient = 0; recipient < g; recipient++) {
                self.groups[recipient] = @(self.groups[recipient].integerValue + 1);
                [active addObject:@(recipient)];
            }
            self.pool = @(self.pool.integerValue - g);
            action = [NSString stringWithFormat:@"每%@再分 1 %@", group, unit];
            explanation = [NSString stringWithFormat:@"每%@的%@都增加 1 %@，這一輪共分出 %ld %@，每%@的數量仍然一樣。",
                group, item, unit, (long)g, unit, group];
        } else {
            [active addObject:@(self.groups.count)];
            [self.groups addObject:@(s)];
            if (!build) self.pool = @(self.pool.integerValue - s);
            action = [NSString stringWithFormat:build ? @"建立一%@" : @"分出一%@", group];
            explanation = build
                ? [NSString stringWithFormat:@"新建一%@，放入%@ %ld %@；每%@的數量一樣。", group, item, (long)s, unit, group]
                : [NSString stringWithFormat:@"從待分組區拿出%@ %ld %@，分成完整的一%@。", item, (long)s, unit, group];
        }
        [self appendKind:share ? GroupingTeachingStepKindShareRound : (build ? GroupingTeachingStepKindBuildGroup : GroupingTeachingStepKindPackGroup)
            title:action explanation:explanation action:action prompt:@""
            prediction:GroupingTeachingPredictionKindNone expected:nil before:before poolBefore:poolBefore
            active:active transfer:share ? g : s];
    }

    if (!build) [self inspectRemainder];
    [self finish];
    return [self.steps copy];
}

- (void)inspectRemainder {
    GroupingStoryContext *context = self.sequence.context;
    BOOL share = context.meaning == GroupingStoryMeaningShareEqually;
    NSInteger remaining = self.pool.integerValue;
    NSInteger needed = share ? self.sequence.groupCount : self.sequence.groupSize;
    NSString *unit = context.itemUnit, *group = context.groupName, *item = context.itemName;
    if (remaining > 0) {
        NSString *prompt = share
            ? [NSString stringWithFormat:@"待分區剩下 %ld %@，還能讓每%@再拿 1 %@嗎？", (long)remaining, unit, group, unit]
            : [NSString stringWithFormat:@"待分組區剩下 %ld %@，還夠再分成完整的一%@嗎？一%@需要 %ld %@。", (long)remaining, unit, group, group, (long)needed, unit];
        [self predict:prompt kind:GroupingTeachingPredictionKindCanContinue expected:@NO];
    }
    self.visibleRemainder = @(remaining);
    NSString *explanation;
    if (remaining == 0) explanation = [NSString stringWithFormat:@"%@已經全部%@，共同的區域剩下 0 %@，沒有餘數。",
        item, share ? @"平均分完" : @"分組完成", unit];
    else if (share) explanation = [NSString stringWithFormat:@"剩下的%@有 %ld %@。再讓每%@拿 1 %@需要 %ld %@，現在不夠。這些共同留下的%@不是每%@各剩一份。",
        item, (long)remaining, unit, group, unit, (long)needed, unit, item, group];
    else explanation = [NSString stringWithFormat:@"剩下的%@有 %ld %@，不到一%@需要的 %ld %@，不能再分成完整的一%@。留下的是%@，不是完整的%@。",
        item, (long)remaining, unit, group, (long)needed, unit, group, item, group];
    [self appendSettledKind:GroupingTeachingStepKindInspectRemainder title:@"看看為什麼停下來" explanation:explanation];
}

- (void)finish {
    GroupingStoryContext *context = self.sequence.context;
    BOOL build = context.meaning == GroupingStoryMeaningBuildEqualGroups;
    BOOL share = context.meaning == GroupingStoryMeaningShareEqually;
    NSInteger answer = self.sequence.storedProblem.answer, r = self.sequence.remainder;
    NSString *unit = context.itemUnit, *item = context.itemName, *group = context.groupName;
    self.visibleAnswer = @(answer);
    NSString *write = build
        ? [NSString stringWithFormat:@"把建立好的%@合起來，%@一共有 %ld %@。", group, item, (long)answer, context.answerUnit]
        : (share ? [NSString stringWithFormat:@"每%@分到的%@最多有 %ld %@。", group, item, (long)answer, context.answerUnit]
                 : [NSString stringWithFormat:@"可以分成 %ld %@。", (long)answer, context.answerUnit]);
    if (!build && r > 0) write = [write stringByAppendingFormat:@"另外共同剩下的%@有 %ld %@。", item, (long)r, unit];
    [self appendSettledKind:GroupingTeachingStepKindWriteAnswer title:@"把找到的數量寫下來" explanation:write];

    NSInteger grouped = GTSum(self.groups);
    NSString *verify = share
        ? [NSString stringWithFormat:@"%ld %@，每%@的%@有 %ld %@，共分了 %ld %@。",
            (long)self.sequence.groupCount, group, group, item, (long)self.sequence.groupSize, unit, (long)grouped, unit]
        : [NSString stringWithFormat:@"每%@的%@有 %ld %@，%ld %@合起來有 %ld %@。",
            group, item, (long)self.sequence.groupSize, unit, (long)self.sequence.groupCount, group, (long)grouped, unit];
    if (!build) verify = [verify stringByAppendingFormat:@"加上共同剩下的 %ld %@，正好是原來的%@ %ld %@。",
        (long)r, unit, item, (long)self.sequence.total, unit];
    [self appendSettledKind:GroupingTeachingStepKindVerify title:@"放回原來的題目檢查" explanation:verify];
    [self appendSettledKind:GroupingTeachingStepKindCompletion title:@"回頭想一想"
        explanation:@"可以回到題目，想想每一步為什麼這樣做；也可以重看剛才的步驟。"];
}

@end

#pragma mark - Immutable views of a selected division action
@interface GroupingTeachingAction ()
@property (nonatomic, strong, readwrite) GroupingTeachingSequence *sequence;
@property (nonatomic, assign, readwrite) NSInteger stepIndex;
@property (nonatomic, assign, readwrite) NSInteger actionIndex;
@property (nonatomic, assign, readwrite) NSInteger actionCount;
@property (nonatomic, assign, readwrite, getter=isFullAction) BOOL fullAction;
@property (nonatomic, assign, readwrite, getter=isRoundComplete) BOOL roundComplete;
@property (nonatomic, strong, readwrite) GroupingTeachingStep *snapshot;
@property (nonatomic, copy, readwrite) NSString *progressText;
@property (nonatomic, copy, readwrite) NSArray<NSArray<NSNumber *> *> *groupIdentitiesBefore;
@property (nonatomic, copy, readwrite) NSArray<NSArray<NSNumber *> *> *groupIdentitiesAfter;
@end
static NSArray<NSArray<NSNumber *> *> *GTIdentityCopy(NSArray<NSArray<NSNumber *> *> *groups) {
    NSMutableArray *copy = [NSMutableArray arrayWithCapacity:groups.count];
    for (NSArray *group in groups) [copy addObject:[group copy]];
    return [copy copy];
}
static NSArray<NSNumber *> *GTIdentityCounts(NSArray<NSArray<NSNumber *> *> *groups) {
    NSMutableArray *counts = [NSMutableArray arrayWithCapacity:groups.count];
    for (NSArray *group in groups) [counts addObject:@(group.count)];
    return [counts copy];
}
@implementation GroupingTeachingAction
- (instancetype)initPrivate { return [super init]; }
+ (BOOL)hasDivisionAction:(GroupingTeachingSequence *)sequence index:(NSInteger)index {
    if (!sequence.isSupported || index < 0 || index >= (NSInteger)sequence.steps.count) return NO;
    GroupingTeachingStep *step = sequence.steps[index];
    return step.kind == GroupingTeachingStepKindShareRound || step.kind == GroupingTeachingStepKindPackGroup;
}
+ (NSArray<GroupingTeachingAction *> *)focusedActionsForSequence:(GroupingTeachingSequence *)sequence stepIndex:(NSInteger)index {
    if (![self hasDivisionAction:sequence index:index]) return @[];
    BOOL share = sequence.context.meaning == GroupingStoryMeaningShareEqually;
    NSInteger pool = sequence.problem.number1;
    NSMutableArray<NSMutableArray<NSNumber *> *> *groups = [NSMutableArray array];
    NSMutableArray<GroupingTeachingAction *> *actions = [NSMutableArray array];
    for (NSInteger stepIndex = 0; stepIndex <= index; stepIndex++) {
        GroupingTeachingStep *step = sequence.steps[stepIndex];
        while (groups.count < step.groupCountsAfter.count) [groups addObject:[NSMutableArray array]];
        // The packing before-state does not contain the newly prepared empty bag.
        NSArray *roundBeforeIDs = GTIdentityCopy([groups subarrayWithRange:NSMakeRange(0, step.groupCountsBefore.count)]);
        NSInteger roundPoolBefore = pool;
        for (NSNumber *active in step.activeGroupIndices) {
            NSInteger groupIndex = active.integerValue;
            NSArray *beforeIDs = GTIdentityCopy(groups);
            NSInteger poolBefore = pool;
            NSInteger targetCount = step.groupCountsAfter[groupIndex].integerValue;
            while ((NSInteger)groups[groupIndex].count < targetCount) {
                if (pool <= 0) return @[];
                [groups[groupIndex] addObject:@(--pool)];
            }
            if (stepIndex != index) continue;
            GroupingTeachingAction *action = [[self alloc] initPrivate];
            action.sequence = sequence; action.stepIndex = index;
            action.actionIndex = share ? actions.count : 0;
            action.actionCount = share ? step.activeGroupIndices.count : 1;
            action.fullAction = NO;
            action.roundComplete = action.actionIndex + 1 == action.actionCount;
            action.groupIdentitiesBefore = share ? beforeIDs : roundBeforeIDs;
            action.groupIdentitiesAfter = GTIdentityCopy(groups);
            GroupingTeachingStep *snapshot = [[GroupingTeachingStep alloc] initPrivate];
            snapshot.kind = step.kind; snapshot.title = step.title;
            snapshot.actionTitle = share ? [NSString stringWithFormat:@"第 %ld %@再拿 1 %@", (long)groupIndex + 1, sequence.context.groupName, sequence.context.itemUnit] : step.actionTitle;
            snapshot.prompt = @""; snapshot.predictionKind = GroupingTeachingPredictionKindNone;
            snapshot.groupCountsBefore = GTIdentityCounts(action.groupIdentitiesBefore);
            snapshot.groupCountsAfter = GTIdentityCounts(action.groupIdentitiesAfter);
            snapshot.poolCountBefore = @(share ? poolBefore : roundPoolBefore);
            snapshot.poolCountAfter = @(pool);
            snapshot.activeGroupIndices = @[active]; snapshot.transferCount = share ? 1 : step.transferCount;
            snapshot.visibleAnswer = step.visibleAnswer; snapshot.visibleRemainder = step.visibleRemainder;
            GroupingStoryContext *context = sequence.context;
            if (share) {
                NSInteger round = step.groupCountsAfter[groupIndex].integerValue;
                action.progressText = [NSString stringWithFormat:@"第 %ld 輪 · 第 %ld / %ld 位", (long)round, (long)action.actionIndex + 1, (long)action.actionCount];
                snapshot.explanation = [NSString stringWithFormat:@"這輪每%@只再拿 1 %@。現在給第 %ld %@；共同待分的%@從 %ld %@變成 %ld %@。%@", context.groupName, context.itemUnit, (long)groupIndex + 1, context.groupName, context.itemName, (long)poolBefore, context.itemUnit, (long)pool, context.itemUnit, action.roundComplete ? @"這輪分完了，大家的數量又一樣多。" : @"這輪還沒分完，其他人要等下一小步。"];
                if (action.roundComplete) snapshot.explanation = [snapshot.explanation stringByAppendingString:step.explanation];
            } else {
                action.progressText = [NSString stringWithFormat:@"第 %ld %@ · 每%@ %ld %@", (long)groupIndex + 1, context.groupName, context.groupName, (long)step.transferCount, context.itemUnit];
                snapshot.explanation = step.explanation;
            }
            snapshot.spokenExplanation = [NSString stringWithFormat:@"%@。%@", action.progressText, snapshot.explanation];
            action.snapshot = snapshot;
            [actions addObject:action];
        }
    }
    return [actions copy];
}
+ (instancetype)fullActionForSequence:(GroupingTeachingSequence *)sequence stepIndex:(NSInteger)index {
    NSArray<GroupingTeachingAction *> *focused = [self focusedActionsForSequence:sequence stepIndex:index];
    if (!focused.count) return nil;
    GroupingTeachingAction *first = focused.firstObject, *last = focused.lastObject;
    GroupingTeachingAction *action = [[self alloc] initPrivate];
    action.sequence = sequence; action.stepIndex = index; action.actionIndex = NSNotFound;
    action.actionCount = focused.count; action.fullAction = YES; action.roundComplete = YES;
    action.snapshot = sequence.steps[index];
    action.groupIdentitiesBefore = first.groupIdentitiesBefore; action.groupIdentitiesAfter = last.groupIdentitiesAfter;
    action.progressText = sequence.context.meaning == GroupingStoryMeaningShareEqually
        ? [NSString stringWithFormat:@"第 %@ 輪 · 每位再拿 1 %@", action.snapshot.groupCountsAfter.firstObject, sequence.context.itemUnit]
        : first.progressText;
    return action;
}
@end

@implementation GroupingPredictionFeedback
+ (NSString *)feedbackForSequence:(GroupingTeachingSequence *)sequence stepIndex:(NSInteger)index chosenValue:(NSInteger)value {
    if (!sequence.isSupported || index < 0 || index >= (NSInteger)sequence.steps.count) return @"";
    GroupingTeachingStep *step = sequence.steps[index];
    if (step.kind != GroupingTeachingStepKindPredict) return @"";
    GroupingStoryContext *context = sequence.context;
    BOOL share = context.meaning == GroupingStoryMeaningShareEqually;
    BOOL build = context.meaning == GroupingStoryMeaningBuildEqualGroups;
    NSString *unit = context.itemUnit, *group = context.groupName;
    BOOL correct = value == step.expectedAnswer.integerValue;
    if (step.predictionKind == GroupingTeachingPredictionKindCanContinue) {
        NSInteger available = step.poolCountAfter.integerValue;
        NSInteger needed = share ? step.groupCountsAfter.count : sequence.problem.number2;
        NSString *rule = share ? [NSString stringWithFormat:@"%ld %@各再拿 1 %@，要 %ld %@", (long)needed, group, unit, (long)needed, unit]
            : [NSString stringWithFormat:@"完整的一%@要 %ld %@", group, (long)needed, unit];
        return [NSString stringWithFormat:@"你選「%@」。共同待分只有 %ld %@；%@，還差 %ld %@。%@", value ? @"還可以" : @"不夠了", (long)available, unit, rule, (long)MAX(0, needed - available), unit, correct ? @"對，所以先停下來。這裡不計分。" : (share ? [NSString stringWithFormat:@"只給其中幾位，就沒有讓每位都再拿 1 %@。看圖數一數，再選也可以。", unit] : @"不完整的一組還不能算一組。看圖數一數，再選也可以。")];
    }
    if (share) {
        NSInteger before = step.groupCountsAfter.firstObject.integerValue;
        return [NSString stringWithFormat:@"你選 %ld %@。每%@現在有 %ld %@，下一輪每位只再拿 1 %@，是 %ld 加 1。共同待分還有 %ld %@。%@", (long)value, unit, group, (long)before, unit, unit, (long)before, (long)step.poolCountAfter.integerValue, unit, correct ? @"這樣想對了；準備好再看動作。" : @"先數原來的，再加這 1 個圓點；不用把整個待分區都算給一個人。"];
    }
    if (build) {
        NSInteger existing = GTSum(step.groupCountsAfter), size = sequence.problem.number1;
        return [NSString stringWithFormat:@"你選 %ld %@。已建立的%@共有 %ld %@，下一%@再放 %ld %@，是 %ld 加 %ld。%@", (long)value, unit, group, (long)existing, unit, group, (long)size, unit, (long)existing, (long)size, correct ? @"想清楚了，就看下一小步。" : @"把原來的和新的一組分開數，再合起來；這裡不計分。"];
    }
    NSInteger before = step.groupCountsAfter.count, size = sequence.problem.number2;
    return [NSString stringWithFormat:@"你選 %ld %@。現在有 %ld %@完整的，待分區有 %ld %@；再拿 %ld %@，只會多 1 %@，是 %ld 加 1。%@", (long)value, group, (long)before, group, (long)step.poolCountAfter.integerValue, unit, (long)size, unit, group, (long)before, correct ? @"對，數的是完整的組，不是物件。" : @"先數完整的組，再想一想；這裡不計分。"];
}
@end
