#import "MultiplicativeTeachingPresentation.h"

@interface MTPPreparationKey ()
@property (nonatomic, copy, readwrite) NSString *sessionID;
@property (nonatomic, assign, readwrite) NSInteger predictSourceIndex;
@property (nonatomic, assign, readwrite) NSInteger workSourceIndex;
@property (nonatomic, strong, readwrite) MultiplicativeTeachingActionSnapshot *anchor;
@property (nonatomic, copy, readwrite) NSString *attemptID;
- (instancetype)initPrivate;
@end
@implementation MTPPreparationKey
- (instancetype)initPrivate { return [super init]; }
@end

@interface MultiplicativeTeachingPresentation ()
@property (nonatomic, assign, readwrite) MTPPresentationPhase phase;
@property (nonatomic, copy, readwrite) NSString *sessionID;
@property (nonatomic, copy, readwrite) NSString *selectionID;
@property (nonatomic, assign, readwrite) NSInteger sourceStepIndex;
@property (nonatomic, assign, readwrite) NSInteger actionIndex;
@property (nonatomic, assign, readwrite) MTPPresentationEndpoint endpoint;
@property (nonatomic, strong, readwrite) MultiplicativeTeachingActionSnapshot *snapshot;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingAction *action;
@property (nonatomic, strong, readwrite, nullable) MTPPreparationKey *preparationKey;
@property (nonatomic, assign, readwrite) NSInteger activeColumn;
@property (nonatomic, assign, readwrite, getter=isReview) BOOL review;
@property (nonatomic, copy, readwrite) NSString *prompt;
@property (nonatomic, strong, readwrite, nullable) MultiplicativeTeachingPresentation *returnSelection;
- (instancetype)initPrivate;
@end

static BOOL MTPEqualObject(id a, id b) { return a == b || [a isEqual:b]; }
static BOOL MTPEqualQuantity(MultiplicativeTeachingQuantity *a, MultiplicativeTeachingQuantity *b) {
    return a == b || (a && b && [a.columns isEqual:b.columns] && [a.counts isEqual:b.counts]
                     && a.weightedValue == b.weightedValue);
}
static BOOL MTPEqualRows(NSArray<MultiplicativeDivisionWorkRow *> *a, NSArray<MultiplicativeDivisionWorkRow *> *b) {
    if (a.count != b.count) return NO;
    for (NSUInteger i = 0; i < a.count; i++) {
        if (a[i].column != b[i].column || a[i].partialCount != b[i].partialCount
            || a[i].distributedCount != b[i].distributedCount || a[i].remainderCount != b[i].remainderCount) return NO;
    }
    return YES;
}
static BOOL MTPEqualSnapshots(MultiplicativeTeachingActionSnapshot *a, MultiplicativeTeachingActionSnapshot *b) {
    if (!a || !b || a.operation != b.operation || !MTPEqualQuantity(a.accumulator, b.accumulator)
        || !MTPEqualQuantity(a.unprocessedInput, b.unprocessedInput) || !MTPEqualQuantity(a.pool, b.pool)
        || ![a.carryUnits isEqual:b.carryUnits] || ![a.processedInputColumns isEqual:b.processedInputColumns]
        || ![a.visibleAnswerDigits isEqual:b.visibleAnswerDigits] || ![a.completedColumns isEqual:b.completedColumns]
        || !MTPEqualRows(a.visibleDivisionRows, b.visibleDivisionRows)
        || !MTPEqualObject(a.visibleRemainder, b.visibleRemainder) || a.recipients.count != b.recipients.count) return NO;
    for (NSUInteger i = 0; i < a.recipients.count; i++) if (!MTPEqualQuantity(a.recipients[i], b.recipients[i])) return NO;
    return YES;
}

@implementation MultiplicativeTeachingPresentation
- (instancetype)initPrivate {
    self = [super init];
    if (self) { _actionIndex = NSNotFound; _activeColumn = NSNotFound; _prompt = @""; }
    return self;
}
+ (instancetype)baseWithSession:(NSString *)sessionID {
    MultiplicativeTeachingPresentation *p = [[self alloc] initPrivate];
    p.sessionID = sessionID;
    p.selectionID = NSUUID.UUID.UUIDString;
    return p;
}
+ (instancetype)actionInPlan:(MultiplicativeTeachingActionPlan *)plan sessionID:(NSString *)sessionID
                       index:(NSInteger)index endpoint:(MTPPresentationEndpoint)endpoint {
    if (!plan.supported || !sessionID.length || index < 0 || index >= (NSInteger)plan.actions.count) return nil;
    MultiplicativeTeachingAction *action = plan.actions[(NSUInteger)index];
    // Predict belongs only to the isolated preparation phase.
    if (action.sourceStep.kind == MultiplicativeTeachingStepKindPredict) return nil;
    MultiplicativeTeachingPresentation *p = [self baseWithSession:sessionID];
    p.phase = MTPPresentationPhaseActionSelection;
    p.sourceStepIndex = action.sourceStepIndex;
    p.actionIndex = index;
    p.action = action;
    p.activeColumn = action.activeColumn;
    p.endpoint = endpoint;
    p.snapshot = endpoint == MTPPresentationEndpointBefore ? action.before : action.after;
    return p;
}
+ (instancetype)preparationInPlan:(MultiplicativeTeachingActionPlan *)plan sessionID:(NSString *)sessionID
              predictSourceIndex:(NSInteger)predictSourceIndex review:(BOOL)review
                 returnSelection:(MultiplicativeTeachingPresentation *)returnSelection {
    if (!plan.supported || !sessionID.length || predictSourceIndex < 0
        || predictSourceIndex + 1 >= (NSInteger)plan.sourceSequence.steps.count) return nil;
    MultiplicativeTeachingStep *predict = plan.sourceSequence.steps[(NSUInteger)predictSourceIndex];
    MultiplicativeTeachingStep *work = plan.sourceSequence.steps[(NSUInteger)predictSourceIndex + 1];
    BOOL multiplication = plan.sourceSequence.operation == MultiplicativeTeachingOperationMultiplication;
    if (predict.kind != MultiplicativeTeachingStepKindPredict || predict.activeColumn < 0 || predict.activeColumn > 2
        || work.activeColumn != predict.activeColumn || !predict.prompt.length
        || work.kind != (multiplication ? MultiplicativeTeachingStepKindMultiplyPlace : MultiplicativeTeachingStepKindDistribute)
        || (multiplication ? (!predict.multiplication || !work.multiplication || predict.division || work.division)
                           : (!predict.division || !work.division || predict.multiplication || work.multiplication))) return nil;
    NSArray<MultiplicativeTeachingAction *> *questions = [plan actionsForSourceStepAtIndex:predictSourceIndex];
    NSArray<MultiplicativeTeachingAction *> *actions = [plan actionsForSourceStepAtIndex:predictSourceIndex + 1];
    if (questions.count != 1 || !actions.count) return nil;
    MultiplicativeTeachingAction *question = questions.firstObject;
    MultiplicativeTeachingActionSnapshot *anchor = actions.firstObject.before;
    if (question.kind != MultiplicativeTeachingActionKindInspect || question.inputUnits.count || question.outputUnits.count
        || anchor.operation != plan.sourceSequence.operation || !MTPEqualSnapshots(question.before, question.after)
        || !MTPEqualSnapshots(question.after, anchor)) return nil;
    MTPPreparationKey *key = [[MTPPreparationKey alloc] initPrivate];
    key.sessionID = sessionID;
    key.predictSourceIndex = predictSourceIndex;
    key.workSourceIndex = predictSourceIndex + 1;
    key.anchor = anchor;
    key.attemptID = NSUUID.UUID.UUIDString;
    MultiplicativeTeachingPresentation *p = [self baseWithSession:sessionID];
    p.phase = MTPPresentationPhaseSourcePreparation;
    p.sourceStepIndex = key.workSourceIndex;
    p.endpoint = MTPPresentationEndpointBefore;
    p.snapshot = anchor;
    p.preparationKey = key;
    p.activeColumn = predict.activeColumn;
    p.review = review;
    p.prompt = predict.prompt;
    p.returnSelection = [returnSelection.sessionID isEqual:sessionID] ? returnSelection : nil;
    return p;
}
+ (instancetype)inspectionInPlan:(MultiplicativeTeachingActionPlan *)plan sessionID:(NSString *)sessionID
                 sourceStepIndex:(NSInteger)sourceStepIndex endpoint:(MTPPresentationEndpoint)endpoint
                 returnSelection:(MultiplicativeTeachingPresentation *)returnSelection {
    if (!plan.supported || !sessionID.length || sourceStepIndex < 0
        || sourceStepIndex >= (NSInteger)plan.sourceSequence.steps.count
        || plan.sourceSequence.steps[(NSUInteger)sourceStepIndex].kind == MultiplicativeTeachingStepKindPredict) return nil;
    MultiplicativeTeachingActionSnapshot *snapshot = endpoint == MTPPresentationEndpointBefore
        ? [plan beforeSnapshotForSourceStepAtIndex:sourceStepIndex] : [plan resultSnapshotForSourceStepAtIndex:sourceStepIndex];
    if (!snapshot) return nil;
    MultiplicativeTeachingPresentation *p = [self baseWithSession:sessionID];
    p.phase = MTPPresentationPhaseSourceInspection;
    p.sourceStepIndex = sourceStepIndex;
    p.endpoint = endpoint;
    p.snapshot = snapshot;
    p.activeColumn = plan.sourceSequence.steps[(NSUInteger)sourceStepIndex].activeColumn;
    p.returnSelection = [returnSelection.sessionID isEqual:sessionID] ? returnSelection : nil;
    return p;
}
- (instancetype)presentationByUpdatingEndpoint:(MTPPresentationEndpoint)endpoint {
    if (self.phase != MTPPresentationPhaseActionSelection || !self.action) return self;
    MultiplicativeTeachingPresentation *p = [[self.class alloc] initPrivate];
    p.phase = self.phase; p.sessionID = self.sessionID; p.selectionID = self.selectionID;
    p.sourceStepIndex = self.sourceStepIndex; p.actionIndex = self.actionIndex; p.action = self.action;
    p.activeColumn = self.activeColumn; p.endpoint = endpoint;
    p.snapshot = endpoint == MTPPresentationEndpointBefore ? self.action.before : self.action.after;
    return p;
}
- (BOOL)acceptsPreparationKey:(MTPPreparationKey *)key {
    MTPPreparationKey *current = self.preparationKey;
    return self.phase == MTPPresentationPhaseSourcePreparation && current && key
        && [current.sessionID isEqual:key.sessionID] && current.predictSourceIndex == key.predictSourceIndex
        && current.workSourceIndex == key.workSourceIndex && current.anchor == key.anchor
        && [current.attemptID isEqual:key.attemptID];
}
+ (NSNumber *)proposalFromText:(NSString *)text validationMessage:(NSString **)message {
    if (message) *message = nil;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length) {
        if (message) *message = @"可以先留白，也可以填一個 0 到 999 的整數。想先觀察，就按「看第一個動作」。";
        return nil;
    }
    NSInteger value = 0;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c < '0' || c > '9' || value > 99) {
            if (message) *message = @"請填 0 到 999 的整數，不用小數點或負號。也可以直接看動作或這一步的結果。";
            return nil;
        }
        value = value * 10 + (c - '0');
    }
    return @(value);
}
- (NSString *)feedbackForProposal:(NSInteger)proposal matchesExpected:(BOOL)matchesExpected
                    givenNumber1:(NSInteger)number1 givenNumber2:(NSInteger)number2 {
    if (self.phase != MTPPresentationPhaseSourcePreparation || proposal < 0 || proposal > 999
        || self.activeColumn < 0 || self.activeColumn > 2 || number2 < 1 || number2 > 9) return @"";
    NSString *unit = @[@"百", @"十", @"一"][(NSUInteger)self.activeColumn];
    if (self.snapshot.operation == MultiplicativeTeachingOperationDivision) {
        if (matchesExpected) return @"這個分法讓每份一樣多，而且不能再讓每份多拿一個。接著可以一份一份檢查；這裡不計分。";
        NSInteger pool = self.snapshot.pool.counts[(NSUInteger)self.activeColumn].integerValue;
        NSInteger needed = proposal * number2;
        if (needed > pool) return [NSString stringWithFormat:
            @"如果每份給 %ld 個%@，%ld 份需要 %ld 個%@；現在共同待分區只有 %ld 個%@，不夠。這只是猜想，還沒有分出去。",
            (long)proposal, unit, (long)number2, (long)needed, unit, (long)pool, unit];
        NSInteger hypotheticalLeft = pool - needed;
        if (hypotheticalLeft >= number2) return [NSString stringWithFormat:
            @"如果每份給 %ld 個%@，會用 %ld 個%@，還有 %ld 個%@可分。這樣還夠讓 %ld 份各多拿 1 個，所以可以再想想。這只是猜想，還沒有分出去。",
            (long)proposal, unit, (long)needed, unit, (long)hypotheticalLeft, unit, (long)number2];
        return @"再看看共同待分區：每份要一樣多，而且要把能完整分的一輪輪分完。現在的積木還沒改變。";
    }
    if (matchesExpected) return @"你有把每一組和原來已有的數量分清楚。接著一組一組檢查；這裡不計分。";
    NSInteger divisor = self.activeColumn == 0 ? 100 : self.activeColumn == 1 ? 10 : 1;
    NSInteger digit = (number1 / divisor) % 10;
    NSInteger owned = self.snapshot.accumulator.counts[(NSUInteger)self.activeColumn].integerValue;
    if (owned > 0 && proposal == digit * number2) return [NSString stringWithFormat:
        @"%ld 個%@只算了這次的 %ld 組。累積區原來已有 %ld 個%@，這些也要保留，沒有消失；它們已經在累積區，不是另外一份。",
        (long)proposal, unit, (long)number2, (long)owned, unit];
    if (owned > 0 && proposal == (digit + owned) * number2) return [NSString stringWithFormat:
        @"這樣把原來已有的 %ld 個%@也放進每一組，再乘了 %ld 次。它們原本只在累積區一次，不是每組都有；這次每組是題目給的 %ld 個%@。",
        (long)owned, unit, (long)number2, (long)digit, unit];
    if (!owned && proposal == digit + number2) return [NSString stringWithFormat:
        @"這樣把 %ld 和 %ld 相加了。題目要的是 %ld 組，每組都有 %ld 個%@，不是把組數當作積木加進去。",
        (long)digit, (long)number2, (long)number2, (long)digit, unit];
    if (!owned && number2 > 1 && proposal == digit * (number2 - 1)) return [NSString stringWithFormat:
        @"這樣只算了 %ld 組，還少看一組。題目有 %ld 組，每組都是 %ld 個%@。",
        (long)(number2 - 1), (long)number2, (long)digit, unit];
    return [NSString stringWithFormat:
        @"再想想：每組有 %ld 個%@，共有 %ld 組；累積區原來的 %ld 個%@要保留一次。可以先看第一組怎麼做，積木還沒有改變。",
        (long)digit, unit, (long)number2, (long)owned, unit];
}
@end
