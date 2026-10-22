#import "MultiplicativeTeachingAction.h"
#import "MultiplicativeTeachingActionCore.h"
#include <stdlib.h>

@interface MultiplicativeTeachingUnit ()
@property (nonatomic, assign, readwrite) NSUInteger identifier;
@property (nonatomic, assign, readwrite) NSInteger column;
@property (nonatomic, assign, readwrite) NSInteger value; // 100, 10 or 1, never 0.
@property (nonatomic, assign, readwrite) MultiplicativeTeachingUnitOrigin origin;
@property (nonatomic, assign, readwrite) NSInteger sourceStepIndex; // NSNotFound for original input.
@property (nonatomic, assign, readwrite) NSInteger groupIndex; // Zero-based generated group, otherwise NSNotFound.
- (instancetype)initPrivate;
@end

@implementation MultiplicativeTeachingUnit
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeTeachingQuantity ()
@property (nonatomic, copy, readwrite) NSArray<NSArray<MultiplicativeTeachingUnit *> *> *columns;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *counts;
@property (nonatomic, assign, readwrite) NSInteger weightedValue;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeTeachingQuantity
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeTeachingActionSnapshot ()
@property (nonatomic, assign, readwrite) MultiplicativeTeachingOperation operation;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingQuantity *accumulator;
@property (nonatomic, copy, readwrite) NSArray<NSArray<MultiplicativeTeachingUnit *> *> *carryUnits;
@property (nonatomic, copy, readwrite) NSIndexSet *processedInputColumns;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingQuantity *unprocessedInput;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingQuantity *pool;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeTeachingQuantity *> *recipients;
@property (nonatomic, copy, readwrite) NSArray *visibleAnswerDigits;
@property (nonatomic, copy, readwrite) NSIndexSet *completedColumns;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeDivisionWorkRow *> *visibleDivisionRows;
@property (nonatomic, copy, readwrite, nullable) NSNumber *visibleRemainder;
@property (nonatomic, copy, readwrite) NSString *spokenDescription;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeTeachingActionSnapshot
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeTeachingAction ()
@property (nonatomic, assign, readwrite) MultiplicativeTeachingActionKind kind;
@property (nonatomic, strong, readwrite) MultiplicativeTeachingStep *sourceStep;
@property (nonatomic, assign, readwrite) NSInteger sourceStepIndex;
@property (nonatomic, assign, readwrite) NSInteger indexWithinStep;
@property (nonatomic, assign, readwrite) NSInteger countWithinStep;
@property (nonatomic, assign, readwrite, getter=isSourceStepComplete) BOOL sourceStepComplete;
@property (nonatomic, assign, readwrite) NSInteger activeColumn;
@property (nonatomic, assign, readwrite) NSInteger sourceColumn;
@property (nonatomic, assign, readwrite) NSInteger destinationColumn;
@property (nonatomic, assign, readwrite) NSInteger recipientIndex; // NSNotFound outside one-recipient distribution.
@property (nonatomic, assign, readwrite) NSInteger groupIndex; // NSNotFound outside generated groups.
@property (nonatomic, assign, readwrite) NSInteger groupCount; // Original known multiplier/divisor.
@property (nonatomic, strong, readwrite) MultiplicativeTeachingActionSnapshot *before;
@property (nonatomic, strong, readwrite) MultiplicativeTeachingActionSnapshot *after;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeTeachingUnit *> *inputUnits;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeTeachingUnit *> *outputUnits;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeTeachingUnit *> *ownedIncomingCarryUnits;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *instruction;
@property (nonatomic, copy, readwrite) NSString *resultExplanation;
@property (nonatomic, copy, readwrite) NSString *spokenBefore;
@property (nonatomic, copy, readwrite) NSString *spokenAfter;
@property (nonatomic, copy, readwrite, nullable) NSNumber *writtenDigit;
@property (nonatomic, assign, readwrite) MultiplicativeTeachingWriteDisposition writeDisposition;
- (instancetype)initPrivate;
@end

@implementation MultiplicativeTeachingAction
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeTeachingActionPlan ()
@property (nonatomic, assign, readwrite) MultiplicativeTeachingActionStatus status;
@property (nonatomic, assign, readwrite, getter=isSupported) BOOL supported;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingSequence *sourceSequence;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingActionSnapshot *initialSnapshot;
@property (nonatomic, copy, readwrite) NSArray<MultiplicativeTeachingAction *> *actions;
@property (nonatomic, copy) NSArray<NSArray<MultiplicativeTeachingAction *> *> *sourceActions;
- (instancetype)initPrivate;
@end

static NSString *MTAPlace(NSInteger column) { return @[@"百位", @"十位", @"個位"][column]; }
static NSString *MTAUnitName(NSInteger column) { return @[@"百", @"十", @"一"][column]; }
static NSInteger MTAIndex(int value) { return value < 0 ? NSNotFound : value; }
static int MTACoreColumn(NSInteger column) { return column == NSNotFound ? -1 : (column >= 0 && column < 3 ? (int)column : -2); }

static BOOL MTACopyCounts(NSArray *counts, int result[3]) {
    if (counts.count != 3) return NO;
    for (NSInteger column = 0; column < 3; column++) {
        id count = counts[column];
        if (![count isKindOfClass:NSNumber.class] || [count integerValue] < 0 || [count integerValue] > 89) return NO;
        result[column] = (int)[count integerValue];
    }
    return YES;
}

static BOOL MTAMultiplyInventory(MultiplicativeMultiplicationState *state, MTCAInventory *result) {
    if (!state || !MTACopyCounts(state.accumulatorCounts, result->accumulator)
        || !MTACopyCounts(state.carryCounts, result->carry)) return NO;
    if (state.processedInputColumns.lastIndex != NSNotFound && state.processedInputColumns.lastIndex > 2) return NO;
    for (NSUInteger column = 0; column < 3; column++)
        if ([state.processedInputColumns containsIndex:column]) result->processedInputMask |= 1u << column;
    return YES;
}

static BOOL MTADivideInventory(MultiplicativeDivisionState *state, NSInteger groupCount, MTCAInventory *result) {
    if (!state || !MTACopyCounts(state.unprocessedInputCounts, result->input)
        || !MTACopyCounts(state.poolCounts, result->pool) || state.recipientCounts.count != (NSUInteger)groupCount) return NO;
    for (NSInteger recipient = 0; recipient < groupCount; recipient++)
        if (!MTACopyCounts(state.recipientCounts[recipient], result->recipients[recipient])) return NO;
    return YES;
}

static BOOL MTABridgeStep(MultiplicativeTeachingStep *step, MultiplicativeTeachingOperation operation,
                          NSInteger groupCount, MTCASourceStep *result) {
    switch (step.kind) {
        case MultiplicativeTeachingStepKindObserve: result->kind = MTCASourceObserve; break;
        case MultiplicativeTeachingStepKindPredict: result->kind = MTCASourcePredict; break;
        case MultiplicativeTeachingStepKindMultiplyPlace: result->kind = MTCASourceMultiplyPlace; break;
        case MultiplicativeTeachingStepKindRegroupUp: result->kind = MTCASourceRegroupUp; break;
        case MultiplicativeTeachingStepKindBringDown: result->kind = MTCASourceBringDown; break;
        case MultiplicativeTeachingStepKindDistribute: result->kind = MTCASourceDistribute; break;
        case MultiplicativeTeachingStepKindWriteDigit: result->kind = MTCASourceWriteDigit; break;
        case MultiplicativeTeachingStepKindRegroupDown: result->kind = MTCASourceRegroupDown; break;
        case MultiplicativeTeachingStepKindInspectRemainder: result->kind = MTCASourceInspectRemainder; break;
        case MultiplicativeTeachingStepKindVerify: result->kind = MTCASourceVerify; break;
        case MultiplicativeTeachingStepKindCompletion: result->kind = MTCASourceCompletion; break;
        default: return NO;
    }
    result->column = MTACoreColumn(step.activeColumn);
    result->sourceColumn = MTACoreColumn(step.sourceColumn);
    result->destinationColumn = MTACoreColumn(step.destinationColumn);
    if (result->column == -2 || result->sourceColumn == -2 || result->destinationColumn == -2) return NO;
    if (operation == MultiplicativeTeachingOperationMultiplication) {
        MultiplicativeMultiplicationPayload *payload = step.multiplication;
        if (!payload || step.division || !MTAMultiplyInventory(payload.before, &result->before)
            || !MTAMultiplyInventory(payload.after, &result->after)
            || payload.generatedUnitCount < 0 || payload.generatedUnitCount > 81
            || payload.incomingCarryUnitCount < 0 || payload.incomingCarryUnitCount > 8
            || payload.exchangeBundleCount < 0 || payload.exchangeBundleCount > 8) return NO;
        result->generatedUnits = (int)payload.generatedUnitCount;
        result->incomingCarryUnits = (int)payload.incomingCarryUnitCount;
        result->exchangeCount = (int)payload.exchangeBundleCount;
        result->writesFinalCarry = payload.writesFinalCarry ? 1 : 0;
    } else {
        MultiplicativeDivisionPayload *payload = step.division;
        if (!payload || step.multiplication || !MTADivideInventory(payload.before, groupCount, &result->before)
            || !MTADivideInventory(payload.after, groupCount, &result->after)
            || payload.broughtDownUnitCount < 0 || payload.broughtDownUnitCount > 9
            || payload.unitsPerRecipient < 0 || payload.unitsPerRecipient > 9
            || payload.totalTransferredUnitCount < 0 || payload.totalTransferredUnitCount > 81
            || payload.exchangeLargerUnitCount < 0 || payload.exchangeLargerUnitCount > 8) return NO;
        result->broughtDownUnits = (int)payload.broughtDownUnitCount;
        result->unitsPerRecipient = (int)payload.unitsPerRecipient;
        result->totalTransferredUnits = (int)payload.totalTransferredUnitCount;
        result->exchangeCount = (int)payload.exchangeLargerUnitCount;
    }
    return YES;
}

static NSArray<MultiplicativeTeachingUnit *> *MTAUnits(const uint16_t *identities, int count, NSArray *units) {
    NSMutableArray<MultiplicativeTeachingUnit *> *result = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (int index = 0; index < count; index++) [result addObject:units[identities[index]]];
    return [result copy];
}

static NSArray<NSArray<MultiplicativeTeachingUnit *> *> *MTAColumns(const MTCAPlan *plan, const MTCAState *state,
                                                                    int location, BOOL carryOnly, NSArray *units) {
    NSMutableArray<NSMutableArray<MultiplicativeTeachingUnit *> *> *columns = [NSMutableArray array];
    for (int column = 0; column < 3; column++) [columns addObject:[NSMutableArray array]];
    for (int identity = 1; identity <= plan->unitCount; identity++) {
        if (state->locations[identity] != location || (carryOnly && !state->carry[identity])) continue;
        [columns[plan->units[identity].column] addObject:units[identity]];
    }
    return @[[columns[0] copy], [columns[1] copy], [columns[2] copy]];
}

static MultiplicativeTeachingQuantity *MTAQuantity(const MTCAPlan *plan, const MTCAState *state,
                                                   int location, NSArray *units) {
    MultiplicativeTeachingQuantity *quantity = [[MultiplicativeTeachingQuantity alloc] initPrivate];
    quantity.columns = MTAColumns(plan, state, location, NO, units);
    quantity.counts = @[@(quantity.columns[0].count), @(quantity.columns[1].count), @(quantity.columns[2].count)];
    quantity.weightedValue = (NSInteger)quantity.columns[0].count * 100 + (NSInteger)quantity.columns[1].count * 10
        + (NSInteger)quantity.columns[2].count;
    return quantity;
}

static NSString *MTAQuantityText(MultiplicativeTeachingQuantity *quantity) {
    return [NSString stringWithFormat:@"%@ 個百、%@ 個十、%@ 個一", quantity.counts[0], quantity.counts[1], quantity.counts[2]];
}

static NSString *MTASnapshotText(MultiplicativeTeachingActionSnapshot *snapshot) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (snapshot.accumulator) {
        [parts addObject:[NSString stringWithFormat:@"目前已有 %@。", MTAQuantityText(snapshot.accumulator)]];
        for (NSInteger column = 0; column < 3; column++) {
            if (snapshot.carryUnits[column].count) [parts addObject:[NSString stringWithFormat:@"其中 %lu 個%@是先前換來的，已包括在目前數量內，不能再加一次。",
                (unsigned long)snapshot.carryUnits[column].count, MTAUnitName(column)]];
        }
    } else {
        [parts addObject:[NSString stringWithFormat:@"原來還沒帶下來的數量：%@。共同待分區：%@。",
            MTAQuantityText(snapshot.unprocessedInput), MTAQuantityText(snapshot.pool)]];
        for (NSUInteger recipient = 0; recipient < snapshot.recipients.count; recipient++) {
            [parts addObject:[NSString stringWithFormat:@"第 %lu 份目前有 %@。", (unsigned long)(recipient + 1),
                MTAQuantityText(snapshot.recipients[recipient])]];
        }
    }
    BOOL hasWritten = NO;
    for (NSInteger column = 0; column < 3; column++) {
        id digit = snapshot.visibleAnswerDigits[column];
        if ([digit isKindOfClass:NSNumber.class]) {
            [parts addObject:[NSString stringWithFormat:@"答案的%@已寫 %@。", MTAPlace(column), digit]];
            hasWritten = YES;
        } else if ([snapshot.completedColumns containsIndex:(NSUInteger)column]) {
            [parts addObject:[NSString stringWithFormat:@"%@已看過，最前面的 0 不寫，位置仍保留。", MTAPlace(column)]];
        }
    }
    if (!hasWritten) [parts addObject:@"答案還沒寫。"];
    for (MultiplicativeDivisionWorkRow *row in snapshot.visibleDivisionRows) {
        [parts addObject:[NSString stringWithFormat:@"直式已寫下的%@這一列：%ld 個%@減 %ld 個%@，剩下 %ld 個%@。",
            MTAPlace(row.column), (long)row.partialCount, MTAUnitName(row.column),
            (long)row.distributedCount, MTAUnitName(row.column), (long)row.remainderCount, MTAUnitName(row.column)]];
    }
    if (snapshot.visibleRemainder) [parts addObject:[NSString stringWithFormat:@"共同的餘數是 %@，不是每份各剩這麼多。", snapshot.visibleRemainder]];
    return [parts componentsJoinedByString:@" "];
}

static MultiplicativeTeachingActionSnapshot *MTASnapshot(const MTCAPlan *plan, const MTCAState *state,
                                                         NSArray *units, MultiplicativeTeachingStep *writtenSource) {
    MultiplicativeTeachingActionSnapshot *snapshot = [[MultiplicativeTeachingActionSnapshot alloc] initPrivate];
    snapshot.operation = plan->operation == MTCAOperationMultiply ? MultiplicativeTeachingOperationMultiplication
                                                                 : MultiplicativeTeachingOperationDivision;
    snapshot.carryUnits = MTAColumns(plan, state, MTCALocationAccumulator, YES, units);
    NSMutableIndexSet *processed = [NSMutableIndexSet indexSet];
    for (NSUInteger column = 0; column < 3; column++) if (state->processedInputMask & (1u << column)) [processed addIndex:column];
    snapshot.processedInputColumns = processed;
    if (plan->operation == MTCAOperationMultiply) {
        snapshot.accumulator = MTAQuantity(plan, state, MTCALocationAccumulator, units);
        snapshot.recipients = @[];
    } else {
        snapshot.unprocessedInput = MTAQuantity(plan, state, MTCALocationInput, units);
        snapshot.pool = MTAQuantity(plan, state, MTCALocationPool, units);
        NSMutableArray<MultiplicativeTeachingQuantity *> *recipients = [NSMutableArray arrayWithCapacity:(NSUInteger)plan->groupCount];
        for (int recipient = 0; recipient < plan->groupCount; recipient++)
            [recipients addObject:MTAQuantity(plan, state, MTCALocationFirstRecipient + recipient, units)];
        snapshot.recipients = recipients;
    }
    snapshot.visibleAnswerDigits = writtenSource ? writtenSource.visibleAnswerDigits : @[[NSNull null], [NSNull null], [NSNull null]];
    snapshot.completedColumns = writtenSource ? writtenSource.completedColumns : [NSIndexSet indexSet];
    snapshot.visibleDivisionRows = writtenSource ? writtenSource.visibleDivisionRows : @[];
    snapshot.visibleRemainder = writtenSource.visibleRemainder;
    snapshot.spokenDescription = MTASnapshotText(snapshot);
    return snapshot;
}

static MultiplicativeTeachingActionKind MTAActionKind(MTCAActionKind kind) {
    switch (kind) {
        case MTCAActionGenerateGroup: return MultiplicativeTeachingActionKindGenerateGroup;
        case MTCAActionZeroGroups: return MultiplicativeTeachingActionKindZeroGroups;
        case MTCAActionExchangeUp: return MultiplicativeTeachingActionKindExchangeUp;
        case MTCAActionBringDown: return MultiplicativeTeachingActionKindBringDown;
        case MTCAActionDistributeRecipient: return MultiplicativeTeachingActionKindDistributeRecipient;
        case MTCAActionZeroDistribution: return MultiplicativeTeachingActionKindZeroDistribution;
        case MTCAActionExchangeDown: return MultiplicativeTeachingActionKindExchangeDown;
        case MTCAActionInspect: return MultiplicativeTeachingActionKindInspect;
    }
    return MultiplicativeTeachingActionKindInspect;
}

static void MTADescribeAction(MultiplicativeTeachingAction *action) {
    NSInteger column = action.activeColumn;
    switch (action.kind) {
        case MultiplicativeTeachingActionKindGenerateGroup:
            action.title = [NSString stringWithFormat:@"第 %ld / %ld 份：每份 %lu 個%@", (long)(action.groupIndex + 1),
                (long)action.groupCount, (unsigned long)action.outputUnits.count, MTAUnitName(column)];
            action.instruction = [NSString stringWithFormat:@"建立這一份 %lu 個%@；這是乘法新建立的一份，不是從別處搬來。",
                (unsigned long)action.outputUnits.count, MTAUnitName(column)];
            action.resultExplanation = [NSString stringWithFormat:@"這一份新增 %lu 個%@。%@", (unsigned long)action.outputUnits.count,
                MTAUnitName(column), action.ownedIncomingCarryUnits.count ? @"先前換來的單位一直都在，只合入一次，不乘上份數。" : @""];
            break;
        case MultiplicativeTeachingActionKindZeroGroups:
            action.title = @"每份是 0，不需要建立空的一份又一份";
            action.instruction = [NSString stringWithFormat:@"每份 0 個%@，取 %ld 份，也不會新增單位。", MTAUnitName(column), (long)action.groupCount];
            action.resultExplanation = action.ownedIncomingCarryUnits.count
                ? @"沒有新增單位；先前換來的數量仍然保留，只合入一次。" : @"沒有新增單位，這一位仍是 0。";
            break;
        case MultiplicativeTeachingActionKindExchangeUp:
            action.title = [NSString stringWithFormat:@"一次把 10 個%@換成 1 個%@", MTAUnitName(action.sourceColumn), MTAUnitName(action.destinationColumn)];
            action.instruction = @"只看這十個單位合成一個較大的單位；其他單位先不動。";
            action.resultExplanation = [NSString stringWithFormat:@"10 個%@ = 1 個%@。這次只換一組，數量沒有變。",
                MTAUnitName(action.sourceColumn), MTAUnitName(action.destinationColumn)];
            break;
        case MultiplicativeTeachingActionKindExchangeDown:
            action.title = [NSString stringWithFormat:@"一次把 1 個%@換成 10 個%@", MTAUnitName(action.sourceColumn), MTAUnitName(action.destinationColumn)];
            action.instruction = @"只看這一個單位拆成十個較小的單位，仍在同一個共同待分區。";
            action.resultExplanation = [NSString stringWithFormat:@"1 個%@ = 10 個%@。這次只換一個；原來下一位的數量還沒帶下來。",
                MTAUnitName(action.sourceColumn), MTAUnitName(action.destinationColumn)];
            break;
        case MultiplicativeTeachingActionKindBringDown:
            action.title = @"把原來這一位的數量放進共同待分區";
            action.instruction = [NSString stringWithFormat:@"把原來的 %lu 個%@帶下來；不是把一個較大的單位拆小。",
                (unsigned long)action.inputUnits.count, MTAUnitName(column)];
            action.resultExplanation = action.inputUnits.count
                ? [NSString stringWithFormat:@"同樣的 %lu 個%@到了共同待分區，身分和單位都沒變。", (unsigned long)action.inputUnits.count, MTAUnitName(column)]
                : @"原來這一位是 0，沒有移動的單位；共同待分區已有的單位仍保留。";
            break;
        case MultiplicativeTeachingActionKindDistributeRecipient:
            action.title = [NSString stringWithFormat:@"這一位，先分給第 %ld / %ld 份", (long)(action.recipientIndex + 1), (long)action.groupCount];
            action.instruction = [NSString stringWithFormat:@"從同一個共同待分區，給第 %ld 份 %lu 個%@；其他份這次不動。",
                (long)(action.recipientIndex + 1), (unsigned long)action.inputUnits.count, MTAUnitName(column)];
            action.resultExplanation = action.isSourceStepComplete
                ? @"這一位每一份都已分到一樣多；沒有把共同剩下的數量複製給每一份。"
                : @"現在還在逐份分配中，這個暫時狀態不代表最後每一份會不同。";
            break;
        case MultiplicativeTeachingActionKindZeroDistribution:
            action.title = @"這一位還不夠讓每份各拿一個";
            action.instruction = @"先保留共同待分區的數量，沒有單位移動，也不預先寫商。";
            action.resultExplanation = @"每份這一位都沒有新增單位；接下來再記下這一位的決定。";
            break;
        case MultiplicativeTeachingActionKindInspect:
            action.title = action.sourceStep.title;
            if (action.sourceStep.kind == MultiplicativeTeachingStepKindWriteDigit) {
                action.instruction = @"把這一位的決定記下來，其他還沒算的位仍留空。";
            } else if (action.sourceStep.kind == MultiplicativeTeachingStepKindInspectRemainder) {
                action.instruction = @"看看共同待分區，確認為什麼不能讓每份再各拿一個。";
            } else {
                action.instruction = action.sourceStep.prompt.length
                    ? [NSString stringWithFormat:@"%@ %@", action.sourceStep.explanation, action.sourceStep.prompt]
                    : action.sourceStep.explanation;
            }
            action.resultExplanation = action.sourceStep.explanation;
            break;
    }
    action.spokenBefore = [NSString stringWithFormat:@"%@ %@", action.instruction, action.before.spokenDescription];
    action.spokenAfter = [NSString stringWithFormat:@"%@ %@", action.resultExplanation, action.after.spokenDescription];
}

@implementation MultiplicativeTeachingActionPlan
- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _status = MultiplicativeTeachingActionStatusInvalidSource;
        _actions = @[];
        _sourceActions = @[];
    }
    return self;
}
- (BOOL)isSupported { return self.status == MultiplicativeTeachingActionStatusSupported; }

+ (instancetype)planForSequence:(MultiplicativeTeachingSequence *)sequence {
    MultiplicativeTeachingActionPlan *plan = [[self alloc] initPrivate];
    plan.sourceSequence = sequence;
    if (!sequence || !sequence.isSupported) {
        plan.status = MultiplicativeTeachingActionStatusUnsupportedSource;
        return plan;
    }
    ArithmeticProblem *problem = sequence.problem;
    BOOL multiply = sequence.operation == MultiplicativeTeachingOperationMultiplication;
    if ((!multiply && sequence.operation != MultiplicativeTeachingOperationDivision) || sequence.columnCount != 3
        || problem.number1 < 0 || problem.number1 > 999 || problem.number2 < 1 || problem.number2 > 9
        || sequence.steps.count < 2 || sequence.steps.count > MTCAMaxSourceSteps) return plan;
    MTCASourceStep sources[MTCAMaxSourceSteps] = {0};
    for (NSUInteger index = 0; index < sequence.steps.count; index++)
        if (!MTABridgeStep(sequence.steps[index], sequence.operation, problem.number2, &sources[index])) return plan;
    MTCAPlan *core = calloc(1, sizeof(*core));
    if (!core) return plan;
    MTCAStatus status = MTCABuildPlan(multiply ? MTCAOperationMultiply : MTCAOperationDivide,
        (int)problem.number1, (int)problem.number2, sources, sequence.steps.count, core);
    if (status != MTCAStatusOK) { free(core); return plan; }
    NSMutableArray *units = [NSMutableArray arrayWithObject:[NSNull null]];
    for (int identity = 1; identity <= core->unitCount; identity++) {
        MTCAUnit raw = core->units[identity];
        MultiplicativeTeachingUnit *unit = [[MultiplicativeTeachingUnit alloc] initPrivate];
        unit.identifier = (NSUInteger)identity;
        unit.column = raw.column;
        unit.value = raw.column == 0 ? 100 : (raw.column == 1 ? 10 : 1);
        unit.origin = raw.origin == MTCAOriginOriginalInput ? MultiplicativeTeachingUnitOriginOriginalInput
            : (raw.origin == MTCAOriginGeneratedGroup ? MultiplicativeTeachingUnitOriginGeneratedGroup : MultiplicativeTeachingUnitOriginExchange);
        unit.sourceStepIndex = MTAIndex(raw.sourceStepIndex);
        unit.groupIndex = MTAIndex(raw.groupIndex);
        [units addObject:unit];
    }
    NSMutableArray<MultiplicativeTeachingAction *> *actions = [NSMutableArray arrayWithCapacity:(NSUInteger)core->actionCount];
    NSMutableArray<NSMutableArray<MultiplicativeTeachingAction *> *> *bySource = [NSMutableArray arrayWithCapacity:sequence.steps.count];
    for (NSUInteger index = 0; index < sequence.steps.count; index++) [bySource addObject:[NSMutableArray array]];
    plan.initialSnapshot = MTASnapshot(core, &core->initial, units, nil);
    MultiplicativeTeachingActionSnapshot *previous = plan.initialSnapshot;
    for (int index = 0; index < core->actionCount; index++) {
        const MTCAAction *raw = &core->actions[index];
        MultiplicativeTeachingAction *action = [[MultiplicativeTeachingAction alloc] initPrivate];
        action.kind = MTAActionKind(raw->kind);
        action.sourceStepIndex = raw->sourceStepIndex;
        action.sourceStep = sequence.steps[(NSUInteger)raw->sourceStepIndex];
        action.indexWithinStep = raw->indexWithinStep;
        action.countWithinStep = raw->countWithinStep;
        action.sourceStepComplete = raw->indexWithinStep == raw->countWithinStep - 1;
        action.activeColumn = MTAIndex(raw->column);
        action.sourceColumn = MTAIndex(raw->sourceColumn);
        action.destinationColumn = MTAIndex(raw->destinationColumn);
        action.recipientIndex = MTAIndex(raw->recipientIndex);
        action.groupIndex = MTAIndex(raw->groupIndex);
        action.groupCount = raw->groupCount;
        action.before = previous;
        MultiplicativeTeachingStep *writtenSource = action.isSourceStepComplete ? action.sourceStep
            : (raw->sourceStepIndex > 0 ? sequence.steps[(NSUInteger)(raw->sourceStepIndex - 1)] : nil);
        action.after = MTASnapshot(core, &raw->after, units, writtenSource);
        action.inputUnits = MTAUnits(raw->inputIDs, raw->inputCount, units);
        action.outputUnits = MTAUnits(raw->outputIDs, raw->outputCount, units);
        action.ownedIncomingCarryUnits = MTAUnits(raw->ownedCarryIDs, raw->ownedCarryCount, units);
        if (action.sourceStep.kind == MultiplicativeTeachingStepKindWriteDigit) {
            action.writtenDigit = action.sourceStep.writtenDigit;
            action.writeDisposition = action.sourceStep.writeDisposition;
        }
        MTADescribeAction(action);
        [actions addObject:action];
        [bySource[(NSUInteger)raw->sourceStepIndex] addObject:action];
        previous = action.after;
    }
    free(core);
    NSMutableArray<NSArray<MultiplicativeTeachingAction *> *> *sourceActions = [NSMutableArray arrayWithCapacity:bySource.count];
    for (NSArray *source in bySource) [sourceActions addObject:[source copy]];
    plan.actions = actions;
    plan.sourceActions = sourceActions;
    plan.status = MultiplicativeTeachingActionStatusSupported;
    return plan;
}

- (NSArray<MultiplicativeTeachingAction *> *)actionsForSourceStepAtIndex:(NSInteger)index {
    return index >= 0 && (NSUInteger)index < self.sourceActions.count ? self.sourceActions[(NSUInteger)index] : @[];
}
- (MultiplicativeTeachingActionSnapshot *)beforeSnapshotForSourceStepAtIndex:(NSInteger)index {
    return [self actionsForSourceStepAtIndex:index].firstObject.before;
}
- (MultiplicativeTeachingActionSnapshot *)resultSnapshotForSourceStepAtIndex:(NSInteger)index {
    return [self actionsForSourceStepAtIndex:index].lastObject.after;
}
@end
