#import "MultiplicativePlaceValueScene.h"
#import <math.h>

static const CGFloat MTPInset = 12, MTPGap = 10, MTPClearance = 8;
static const NSTimeInterval MTPLead = .45, MTPTail = .35, MTPBirth = .55, MTPJoin = 1.25, MTPDockHold = .70, MTPSplitHold = .35;

CGSize MTPPlaceValueBodySize(NSInteger column) {
    return column == 0 ? CGSizeMake(160, 160) : (column == 1 ? CGSizeMake(16, 160) : CGSizeMake(16, 16));
}
NSString *MTPPlaceValuePlaceName(NSInteger column) { return column == 0 ? @"百" : (column == 1 ? @"十" : @"一"); }
CGFloat MTPPlaceValueTextHeight(NSString *text, UIFont *font, CGFloat width) {
    CGRect rect = [text boundingRectWithSize:CGSizeMake(MAX(1, width), CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
        attributes:@{NSFontAttributeName:font} context:nil];
    return ceil(MAX(font.lineHeight, rect.size.height)) + 2;
}
static NSArray *MTPFlatten(MultiplicativeTeachingQuantity *quantity) {
    NSMutableArray *units = [NSMutableArray array];
    for (NSArray *column in quantity.columns) [units addObjectsFromArray:column];
    return units.copy;
}
NSArray<NSString *> *MTPPlaceValueOwnerOrder(MultiplicativeTeachingActionSnapshot *snapshot) {
    if (snapshot.accumulator) return @[@"accumulator"];
    NSMutableArray *owners = [NSMutableArray arrayWithObjects:@"input", @"pool", nil];
    for (NSUInteger i = 0; i < snapshot.recipients.count; i++) [owners addObject:[NSString stringWithFormat:@"recipient.%lu", (unsigned long)i]];
    return owners.copy;
}
NSDictionary<NSString *, NSArray<MultiplicativeTeachingUnit *> *> *MTPPlaceValueOwners(MultiplicativeTeachingActionSnapshot *snapshot) {
    NSMutableDictionary *owners = [NSMutableDictionary dictionary];
    if (snapshot.accumulator) owners[@"accumulator"] = MTPFlatten(snapshot.accumulator);
    if (snapshot.unprocessedInput) owners[@"input"] = MTPFlatten(snapshot.unprocessedInput);
    if (snapshot.pool) owners[@"pool"] = MTPFlatten(snapshot.pool);
    for (NSUInteger i = 0; i < snapshot.recipients.count; i++) owners[[NSString stringWithFormat:@"recipient.%lu", (unsigned long)i]] = MTPFlatten(snapshot.recipients[i]);
    return owners.copy;
}
NSString *MTPPlaceValueOwnerName(NSString *owner, MultiplicativeTeachingActionSnapshot *snapshot) {
    if ([owner isEqualToString:@"accumulator"]) return @"累積區";
    if ([owner isEqualToString:@"input"]) return @"原題尚未取下";
    if ([owner isEqualToString:@"pool"]) return snapshot.visibleRemainder ? @"共同餘數區" : @"共同待分區";
    return [NSString stringWithFormat:@"第 %ld 份", (long)[[owner componentsSeparatedByString:@"."].lastObject integerValue] + 1];
}
static NSSet *MTPCarry(MultiplicativeTeachingActionSnapshot *snapshot) {
    NSMutableSet *ids = [NSMutableSet set];
    for (NSArray *column in snapshot.carryUnits) for (MultiplicativeTeachingUnit *unit in column) [ids addObject:@(unit.identifier)];
    return ids.copy;
}
static void MTPInventory(MultiplicativeTeachingActionSnapshot *snapshot, NSMutableDictionary *units, NSMutableDictionary *owners) {
    NSDictionary *inventory = MTPPlaceValueOwners(snapshot);
    for (NSString *owner in inventory) for (MultiplicativeTeachingUnit *unit in inventory[owner]) {
        units[@(unit.identifier)] = unit; owners[@(unit.identifier)] = owner;
    }
}
static CGRect MTPLerp(CGRect a, CGRect b, CGFloat progress) {
    CGFloat p = MIN(1, MAX(0, progress)); p = p * p * (3 - 2 * p);
    return CGRectMake(a.origin.x + (b.origin.x - a.origin.x) * p, a.origin.y + (b.origin.y - a.origin.y) * p, a.size.width, a.size.height);
}
static BOOL MTPFiniteRect(CGRect rect) {
    return !CGRectIsNull(rect) && !CGRectIsInfinite(rect) && isfinite(rect.origin.x) && isfinite(rect.origin.y)
        && isfinite(rect.size.width) && isfinite(rect.size.height) && rect.size.width > 0 && rect.size.height > 0;
}

@interface MTPPlaceValueUnitPlacement ()
@property (nonatomic, strong, readwrite) MultiplicativeTeachingUnit *unit;
@property (nonatomic, copy, readwrite) NSString *owner;
@property (nonatomic, assign, readwrite) CGRect frame;
@property (nonatomic, assign, readwrite) BOOL inTransit;
@property (nonatomic, assign, readwrite) BOOL carryAnnotation;
@end
@implementation MTPPlaceValueUnitPlacement
- (instancetype)initWithUnit:(MultiplicativeTeachingUnit *)unit owner:(NSString *)owner frame:(CGRect)frame inTransit:(BOOL)inTransit carryAnnotation:(BOOL)carryAnnotation {
    self = [super init]; if (self) { _unit = unit; _owner = [owner copy]; _frame = frame; _inTransit = inTransit; _carryAnnotation = carryAnnotation; } return self;
}
@end
@interface MTPPlaceValueProjection ()
@property (nonatomic, copy, readwrite) NSArray<MTPPlaceValueUnitPlacement *> *placements;
@property (nonatomic, copy, readwrite) NSDictionary<NSNumber *, NSString *> *ownersByIdentifier;
@property (nonatomic, copy, readwrite) NSDictionary<NSNumber *, MultiplicativeTeachingUnit *> *ownedUnitsByIdentifier;
@property (nonatomic, copy, readwrite) NSSet<NSNumber *> *carryIdentifiers;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *labelTexts;
@property (nonatomic, strong, readwrite) MultiplicativeTeachingActionSnapshot *canonicalSnapshot;
@property (nonatomic, assign, readwrite) BOOL complete;
@end
@implementation MTPPlaceValueProjection @end
@interface MultiplicativePlaceValueScene ()
@property (nonatomic, strong, readwrite) MultiplicativeTeachingAction *action;
@property (nonatomic, strong, readwrite) UIFont *font;
@property (nonatomic, assign, readwrite) CGFloat width;
@property (nonatomic, assign, readwrite) CGRect requiredRect;
@property (nonatomic, assign, readwrite) CGRect cradleRect;
@property (nonatomic, assign, readwrite) BOOL geometryValid;
@property (nonatomic, copy, readwrite) NSString *geometryFailure;
@property (nonatomic, assign, readwrite) BOOL stationary;
@property (nonatomic, assign, readwrite) NSTimeInterval duration;
@property (nonatomic, copy, readwrite) NSDictionary<NSNumber *, NSValue *> *beforeFrames;
@property (nonatomic, copy, readwrite) NSDictionary<NSNumber *, NSValue *> *afterFrames;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSValue *> *labelFrames;
@property (nonatomic, copy, readwrite) NSSet<NSNumber *> *omittedIdentifiers;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *transferOrder;
@property (nonatomic, copy, readwrite) NSDictionary<NSNumber *, NSValue *> *sweptFrames;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSValue *> *joinedFrames;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *beforeOwners;
@property (nonatomic, copy) NSDictionary<NSNumber *, NSString *> *afterOwners;
@property (nonatomic, copy) NSDictionary<NSNumber *, MultiplicativeTeachingUnit *> *beforeUnits;
@property (nonatomic, copy) NSDictionary<NSNumber *, MultiplicativeTeachingUnit *> *afterUnits;
@property (nonatomic, copy) NSString *portText;
@property (nonatomic) NSTimeInterval travelDuration;
@end

@implementation MultiplicativePlaceValueScene
+ (instancetype)sceneWithAction:(MultiplicativeTeachingAction *)action width:(CGFloat)width font:(UIFont *)font {
    MultiplicativePlaceValueScene *scene = [[self alloc] init];
    scene.action = action; scene.width = MAX(1, width); scene.font = font;
    scene.beforeFrames = @{}; scene.afterFrames = @{}; scene.joinedFrames = @{}; scene.labelFrames = @{};
    scene.transferOrder = @[]; scene.sweptFrames = @{}; scene.cradleRect = CGRectNull; scene.geometryFailure = @""; scene.portText = @"";
    NSMutableDictionary *beforeUnits = [NSMutableDictionary dictionary], *beforeOwners = [NSMutableDictionary dictionary];
    NSMutableDictionary *afterUnits = [NSMutableDictionary dictionary], *afterOwners = [NSMutableDictionary dictionary];
    MTPInventory(action.before, beforeUnits, beforeOwners); MTPInventory(action.after, afterUnits, afterOwners);
    scene.beforeUnits = beforeUnits; scene.afterUnits = afterUnits; scene.beforeOwners = beforeOwners; scene.afterOwners = afterOwners;
    NSMutableSet *omitted = [NSMutableSet setWithArray:beforeUnits.allKeys]; [omitted addObjectsFromArray:afterUnits.allKeys];
    for (MultiplicativeTeachingUnit *unit in action.inputUnits) [omitted removeObject:@(unit.identifier)];
    for (MultiplicativeTeachingUnit *unit in action.outputUnits) [omitted removeObject:@(unit.identifier)];
    scene.omittedIdentifiers = omitted;
    scene.stationary = action.inputUnits.count == 0 && action.outputUnits.count == 0;
    [scene buildGeometry];
    return scene;
}
- (BOOL)isTransfer { return self.action.kind == MultiplicativeTeachingActionKindBringDown || self.action.kind == MultiplicativeTeachingActionKindDistributeRecipient; }
- (BOOL)isExchange { return self.action.kind == MultiplicativeTeachingActionKindExchangeUp || self.action.kind == MultiplicativeTeachingActionKindExchangeDown; }
- (NSString *)countText:(NSArray<NSNumber *> *)counts {
    return [NSString stringWithFormat:@"%@ 百、%@ 十、%@ 一", counts[0], counts[1], counts[2]];
}
- (NSArray<NSNumber *> *)countsForOwners:(NSSet *)selectedOwners units:(NSDictionary *)units owners:(NSDictionary *)owners onlyOmitted:(BOOL)onlyOmitted {
    NSInteger counts[3] = {0, 0, 0};
    for (NSNumber *identifier in units) if ([selectedOwners containsObject:owners[identifier]] && (!onlyOmitted || [self.omittedIdentifiers containsObject:identifier])) {
        MultiplicativeTeachingUnit *unit = units[identifier]; if (unit.column >= 0 && unit.column < 3) counts[unit.column]++;
    }
    return @[@(counts[0]), @(counts[1]), @(counts[2])];
}
- (NSString *)contextForUnits:(NSDictionary *)units owners:(NSDictionary *)owners carry:(NSSet *)carry snapshot:(MultiplicativeTeachingActionSnapshot *)snapshot {
    NSMutableArray *lines = [NSMutableArray array]; NSMutableArray *otherRecipients = [NSMutableArray array];
    for (NSString *owner in MTPPlaceValueOwnerOrder(snapshot)) {
        if ([owner hasPrefix:@"recipient."] && ![owner isEqualToString:[NSString stringWithFormat:@"recipient.%ld", (long)self.action.recipientIndex]]) {
            [otherRecipients addObject:owner]; continue;
        }
        NSSet *ownerSet = [NSSet setWithObject:owner];
        NSArray *counts = [self countsForOwners:ownerSet units:units owners:owners onlyOmitted:NO];
        NSArray *omitted = [self countsForOwners:ownerSet units:units owners:owners onlyOmitted:YES];
        [lines addObject:[NSString stringWithFormat:@"%@：%@。未畫出：%@。", MTPPlaceValueOwnerName(owner, snapshot), [self countText:counts], [self countText:omitted]]];
    }
    if (otherRecipients.count) {
        NSMutableArray *names = [NSMutableArray array]; for (NSString *owner in otherRecipients) [names addObject:MTPPlaceValueOwnerName(owner, snapshot)];
        NSSet *set = [NSSet setWithArray:otherRecipients];
        [lines addObject:[NSString stringWithFormat:@"%@合計：%@，都沒有移動。", [names componentsJoinedByString:@"、"], [self countText:[self countsForOwners:set units:units owners:owners onlyOmitted:YES]]]];
    }
    if (carry.count) {
        NSInteger counts[3] = {0,0,0}; for (NSNumber *identifier in carry) { MultiplicativeTeachingUnit *unit = units[identifier]; if (unit) counts[unit.column]++; }
        [lines addObject:[NSString stringWithFormat:@"先前換來的 %@ 已包含在累積區，不另外加一次。", [self countText:@[@(counts[0]),@(counts[1]),@(counts[2])]]]];
    }
    [lines addObject:@"這是動作特寫；未畫出的積木沒有移動，按「看全部」可逐個查看。"];
    return [lines componentsJoinedByString:@"\n"];
}
- (NSString *)phaseTextAtElapsed:(NSTimeInterval)elapsed complete:(BOOL)complete born:(NSUInteger)born arrived:(NSUInteger)arrived transit:(BOOL)transit {
    if (complete) return self.action.resultExplanation;
    if (elapsed < MTPLead || self.stationary) return self.action.instruction;
    NSString *place = MTPPlaceValuePlaceName(self.action.activeColumn);
    if (self.action.kind == MultiplicativeTeachingActionKindGenerateGroup)
        return [NSString stringWithFormat:@"這一組目前新增 %lu 個%@；一個一個看。", (unsigned long)born, place];
    if ([self isTransfer]) return [NSString stringWithFormat:@"這次已移到%@ %lu 個%@。%@", MTPPlaceValueOwnerName(self.afterOwners[@(self.action.outputUnits.firstObject.identifier)], self.action.before), (unsigned long)arrived, place, transit ? @"正在移動的 1 個仍包含在原來那一區，抵達才換到目的地。" : @"每次只移動 1 個，其他積木保持原位。"];
    BOOL up = self.action.kind == MultiplicativeTeachingActionKindExchangeUp;
    if (up && elapsed < MTPLead + MTPJoin + MTPDockHold) return [NSString stringWithFormat:@"10 個%@靠在一起；仍是原來這 10 個%@。", MTPPlaceValuePlaceName(self.action.sourceColumn), MTPPlaceValuePlaceName(self.action.sourceColumn)];
    return up ? [NSString stringWithFormat:@"同樣的數量，現在換成 1 個%@。", MTPPlaceValuePlaceName(self.action.destinationColumn)]
        : [NSString stringWithFormat:@"1 個%@拆成 10 個%@；仍在同一個共同待分區。", MTPPlaceValuePlaceName(self.action.sourceColumn), MTPPlaceValuePlaceName(self.action.destinationColumn)];
}
- (MTPPlaceValueProjection *)projectionAtElapsed:(NSTimeInterval)elapsed {
    BOOL complete = self.duration > 0 && elapsed >= self.duration;
    NSMutableDictionary *units = [self.beforeUnits mutableCopy], *owners = [self.beforeOwners mutableCopy];
    NSMutableDictionary<NSNumber *, NSValue *> *frames = [self.beforeFrames mutableCopy];
    NSMutableSet *carry = [MTPCarry(self.action.before) mutableCopy], *moving = [NSMutableSet set];
    NSUInteger born = 0, arrived = 0;
    if (self.action.kind == MultiplicativeTeachingActionKindGenerateGroup) {
        born = elapsed < MTPLead ? 0 : MIN(self.action.outputUnits.count, (NSUInteger)floor((elapsed - MTPLead) / MTPBirth) + 1);
        for (NSUInteger i = 0; i < born; i++) {
            MultiplicativeTeachingUnit *unit = self.action.outputUnits[i]; NSNumber *identifier = @(unit.identifier);
            units[identifier] = unit; owners[identifier] = self.afterOwners[identifier]; frames[identifier] = self.afterFrames[identifier];
        }
    } else if ([self isTransfer] && self.action.inputUnits.count) {
        NSTimeInterval leg = self.travelDuration + .25;
        for (NSUInteger index = 0; index < self.transferOrder.count; index++) {
            NSNumber *identifier = self.transferOrder[index]; NSTimeInterval local = elapsed - MTPLead - index * leg;
            CGFloat progress = local <= 0 ? 0 : MIN(1, local / self.travelDuration);
            frames[identifier] = [NSValue valueWithCGRect:MTPLerp(self.beforeFrames[identifier].CGRectValue, self.afterFrames[identifier].CGRectValue, progress)];
            if (local + 1e-9 >= self.travelDuration) { owners[identifier] = self.afterOwners[identifier]; arrived++; }
            else if (local > 0) [moving addObject:identifier];
        }
    } else if ([self isExchange]) {
        BOOL up = self.action.kind == MultiplicativeTeachingActionKindExchangeUp;
        BOOL replaced = up ? elapsed >= MTPLead + MTPJoin + MTPDockHold : elapsed >= MTPLead;
        if (replaced) {
            for (MultiplicativeTeachingUnit *unit in self.action.inputUnits) { NSNumber *identifier = @(unit.identifier); [units removeObjectForKey:identifier]; [owners removeObjectForKey:identifier]; [frames removeObjectForKey:identifier]; [carry removeObject:identifier]; }
            for (MultiplicativeTeachingUnit *unit in self.action.outputUnits) {
                NSNumber *identifier = @(unit.identifier); units[identifier] = unit; owners[identifier] = self.afterOwners[identifier];
                frames[identifier] = up ? self.afterFrames[identifier] : [NSValue valueWithCGRect:MTPLerp(self.joinedFrames[identifier].CGRectValue, self.afterFrames[identifier].CGRectValue, (elapsed - MTPLead - MTPSplitHold) / MTPJoin)];
                if ([MTPCarry(self.action.after) containsObject:identifier]) [carry addObject:identifier];
            }
        } else if (up) for (MultiplicativeTeachingUnit *unit in self.action.inputUnits) {
            NSNumber *identifier = @(unit.identifier); frames[identifier] = [NSValue valueWithCGRect:MTPLerp(self.beforeFrames[identifier].CGRectValue, self.joinedFrames[identifier].CGRectValue, (elapsed - MTPLead) / MTPJoin)];
        }
    }
    if (complete) { units = [self.afterUnits mutableCopy]; owners = [self.afterOwners mutableCopy]; frames = [self.afterFrames mutableCopy]; carry = [MTPCarry(self.action.after) mutableCopy]; [moving removeAllObjects]; }
    NSMutableArray *placements = [NSMutableArray array];
    NSArray *identifiers = [frames.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *identifier in identifiers) {
        MultiplicativeTeachingUnit *unit = units[identifier]; if (!unit) continue;
        MTPPlaceValueUnitPlacement *placement = [[MTPPlaceValueUnitPlacement alloc] init]; placement.unit = unit; placement.owner = owners[identifier];
        placement.frame = frames[identifier].CGRectValue; placement.inTransit = [moving containsObject:identifier]; placement.carryAnnotation = [carry containsObject:identifier]; [placements addObject:placement];
    }
    MultiplicativeTeachingActionSnapshot *snapshot = complete ? self.action.after : self.action.before;
    MTPPlaceValueProjection *projection = [[MTPPlaceValueProjection alloc] init]; projection.placements = placements; projection.ownersByIdentifier = owners;
    projection.ownedUnitsByIdentifier = units; projection.carryIdentifiers = carry; projection.canonicalSnapshot = snapshot; projection.complete = complete;
    projection.labelTexts = @{@"title":self.action.title, @"context":[self contextForUnits:units owners:owners carry:carry snapshot:snapshot], @"owner":self.portText,
        @"phase":[self phaseTextAtElapsed:elapsed complete:complete born:born arrived:arrived transit:moving.count > 0]};
    return projection;
}
- (MTPPlaceValueProjection *)projectionAfter:(BOOL)after {
    if (!self.stationary) return [self projectionAtElapsed:after ? self.duration : 0];
    MTPPlaceValueProjection *projection = [self projectionAtElapsed:0];
    if (after) {
        projection.canonicalSnapshot = self.action.after; projection.ownedUnitsByIdentifier = self.afterUnits; projection.ownersByIdentifier = self.afterOwners;
        projection.carryIdentifiers = MTPCarry(self.action.after); projection.complete = YES;
        projection.labelTexts = @{@"title":self.action.title, @"context":self.action.after.spokenDescription, @"owner":@"", @"phase":self.action.resultExplanation};
    }
    return projection;
}
- (NSArray<NSDictionary<NSString *, NSString *> *> *)labelVariants {
    NSMutableArray *variants = [NSMutableArray array];
    [variants addObject:[self projectionAtElapsed:0].labelTexts];
    if (self.duration > 0) {
        // Bounded by nine births/transfers. Include both sides of every discrete
        // ownership/carry event and motion/dwell language before allocating labels.
        NSMutableArray *times = [NSMutableArray arrayWithObjects:@(MTPLead), @(self.duration), @(MTPLead + MTPJoin), @(MTPLead + MTPJoin + MTPDockHold), @(MTPLead + MTPSplitHold), nil];
        for (NSUInteger i = 0; i <= 9; i++) {
            [times addObject:@(MTPLead + i * MTPBirth)];
            [times addObject:@(MTPLead + i * (self.travelDuration + .25))];
            [times addObject:@(MTPLead + i * (self.travelDuration + .25) + self.travelDuration)];
        }
        for (NSNumber *time in times) for (NSNumber *delta in @[@(-.001), @(.001)]) {
            NSTimeInterval t = MIN(self.duration, MAX(0, time.doubleValue + delta.doubleValue)); [variants addObject:[self projectionAtElapsed:t].labelTexts];
        }
    }
    return variants.copy;
}
- (CGFloat)heightForLabel:(NSString *)key variants:(NSArray<NSDictionary *> *)variants width:(CGFloat)width {
    CGFloat height = 0;
    for (NSDictionary *texts in variants) height = MAX(height, MTPPlaceValueTextHeight(texts[key] ?: @"", self.font, width));
    return height;
}
- (void)offsetFrames:(NSMutableDictionary *)frames x:(CGFloat)x y:(CGFloat)y {
    for (NSNumber *identifier in frames.allKeys.copy) frames[identifier] = [NSValue valueWithCGRect:CGRectOffset([frames[identifier] CGRectValue], x, y)];
}
- (void)buildGeometry {
    MultiplicativeTeachingAction *action = self.action; CGFloat available = MAX(1, self.width - 2 * MTPInset);
    NSMutableDictionary *before = [NSMutableDictionary dictionary], *after = [NSMutableDictionary dictionary], *joined = [NSMutableDictionary dictionary];
    NSMutableDictionary *swept = [NSMutableDictionary dictionary]; NSMutableArray *order = [NSMutableArray array];
    CGSize material = CGSizeZero; BOOL sideLabels = NO;
    if (self.stationary) { self.requiredRect = CGRectNull; self.geometryValid = YES; return; }
    if (action.kind == MultiplicativeTeachingActionKindGenerateGroup) {
        CGSize size = MTPPlaceValueBodySize(action.activeColumn); NSInteger n = action.outputUnits.count;
        NSInteger columns = MAX(1, MIN(n, (NSInteger)floor((available + MTPGap) / (size.width + MTPGap))));
        NSInteger rows = (n + columns - 1) / columns;
        material = CGSizeMake(columns * size.width + (columns - 1) * MTPGap, rows * size.height + (rows - 1) * MTPGap);
        for (NSInteger i = 0; i < n; i++) after[@(action.outputUnits[i].identifier)] = [NSValue valueWithCGRect:CGRectMake((i % columns) * (size.width + MTPGap), (i / columns) * (size.height + MTPGap), size.width, size.height)];
        self.portText = [NSString stringWithFormat:@"累積區 · 第 %ld / %ld 組，只新增這一組", (long)action.groupIndex + 1, (long)action.groupCount];
        self.duration = MTPLead + n * MTPBirth + MTPTail;
    } else if ([self isExchange]) {
        BOOL up = action.kind == MultiplicativeTeachingActionKindExchangeUp;
        NSArray<MultiplicativeTeachingUnit *> *small = up ? action.inputUnits : action.outputUnits;
        MultiplicativeTeachingUnit *large = up ? action.outputUnits.firstObject : action.inputUnits.firstObject;
        BOOL vertical = small.firstObject.column == 2;
        material = vertical ? CGSizeMake(20, 254) : CGSizeMake(254, 164);
        CGSize largeSize = MTPPlaceValueBodySize(large.column), smallSize = MTPPlaceValueBodySize(small.firstObject.column);
        CGRect largeFrame = CGRectMake((material.width - largeSize.width) / 2, (material.height - largeSize.height) / 2, largeSize.width, largeSize.height);
        for (NSUInteger i = 0; i < small.count; i++) {
            CGRect separated = vertical ? CGRectMake(2, 2 + i * 26, 16, 16) : CGRectMake(2 + i * 26, 2, 16, 160);
            CGRect docked = vertical ? CGRectMake(largeFrame.origin.x, largeFrame.origin.y + i * 16, smallSize.width, smallSize.height) : CGRectMake(largeFrame.origin.x + i * 16, largeFrame.origin.y, smallSize.width, smallSize.height);
            NSNumber *identifier = @(small[i].identifier); (up ? before : after)[identifier] = [NSValue valueWithCGRect:separated]; joined[identifier] = [NSValue valueWithCGRect:docked]; swept[identifier] = [NSValue valueWithCGRect:CGRectUnion(separated, docked)];
        }
        (up ? after : before)[@(large.identifier)] = [NSValue valueWithCGRect:largeFrame];
        NSString *owner = (up ? self.afterOwners : self.beforeOwners)[@(large.identifier)];
        self.portText = [NSString stringWithFormat:@"%@ · 同一區內換位值", MTPPlaceValueOwnerName(owner, action.before)];
        self.duration = MTPLead + MTPJoin + (up ? MTPDockHold : MTPSplitHold) + MTPTail;
        sideLabels = vertical && self.width >= 280;
    } else if ([self isTransfer]) {
        NSUInteger n = action.inputUnits.count; CGSize size = MTPPlaceValueBodySize(action.activeColumn);
        CGFloat bestHeight = CGFLOAT_MAX, bestWidth = CGFLOAT_MAX; NSInteger bestColumns = 1; BOOL horizontal = NO;
        for (NSUInteger c = 1; c <= n; c++) for (NSUInteger orientation = 0; orientation < 2; orientation++) {
            NSUInteger r = (n + c - 1) / c;
            CGFloat w = c * size.width + (c - 1) * MTPGap, h = r * size.height + (r - 1) * MTPGap;
            CGSize candidate = orientation == 0 ? CGSizeMake(w * 2 + 40, h) : CGSizeMake(w, h * 2 + 40);
            if (candidate.width <= available && (candidate.height < bestHeight || (candidate.height == bestHeight && candidate.width < bestWidth))) {
                bestHeight = candidate.height; bestWidth = candidate.width; bestColumns = c; horizontal = orientation == 0;
            }
        }
        // Even a non-fitting scene has lawful true-scale geometry. The board uses
        // static overview recovery; it never clips or scales this animation.
        if (bestHeight == CGFLOAT_MAX) { bestColumns = 1; horizontal = NO; bestWidth = size.width; bestHeight = n * (size.height + MTPGap) * 2 - 2 * MTPGap + 40; }
        material = CGSizeMake(bestWidth, bestHeight);
        NSInteger rows = ((NSInteger)n + bestColumns - 1) / bestColumns;
        CGFloat portWidth = bestColumns * size.width + (bestColumns - 1) * MTPGap, portHeight = rows * size.height + (rows - 1) * MTPGap;
        for (NSUInteger i = 0; i < n; i++) {
            CGRect source = CGRectMake((i % bestColumns) * (size.width + MTPGap), (i / bestColumns) * (size.height + MTPGap), size.width, size.height);
            CGRect destination = CGRectOffset(source, horizontal ? portWidth + 40 : 0, horizontal ? 0 : portHeight + 40);
            NSNumber *identifier = @(action.inputUnits[i].identifier); before[identifier] = [NSValue valueWithCGRect:source]; after[identifier] = [NSValue valueWithCGRect:destination]; swept[identifier] = [NSValue valueWithCGRect:CGRectUnion(source, destination)];
        }
        if (horizontal) {
            for (NSInteger row = 0; row < rows; row++) for (NSInteger col = bestColumns - 1; col >= 0; col--) { NSInteger i = row * bestColumns + col; if (i < (NSInteger)n) [order addObject:@(action.inputUnits[i].identifier)]; }
        } else {
            for (NSInteger col = 0; col < bestColumns; col++) for (NSInteger row = rows - 1; row >= 0; row--) { NSInteger i = row * bestColumns + col; if (i < (NSInteger)n) [order addObject:@(action.inputUnits[i].identifier)]; }
        }
        NSNumber *first = @(action.inputUnits.firstObject.identifier);
        self.portText = [NSString stringWithFormat:@"%@：%@　%@：%@", horizontal ? @"左" : @"上", MTPPlaceValueOwnerName(self.beforeOwners[first], action.before), horizontal ? @"右" : @"下", MTPPlaceValueOwnerName(self.afterOwners[first], action.after)];
        // Smoothstep reaches 1.5 times average speed. Preserve the 260 pt/s cap
        // for the actual trajectory, not just for its average distance / time.
        self.travelDuration = MAX(.70, (horizontal ? portWidth + 40 : portHeight + 40) * 1.5 / 260.0);
        self.duration = MTPLead + n * (self.travelDuration + .25) + MTPTail;
    } else { self.geometryFailure = @"沒有符合這個動作的位值圖。"; self.geometryValid = NO; return; }
    self.beforeFrames = before; self.afterFrames = after; self.joinedFrames = joined; self.transferOrder = order; self.sweptFrames = swept;
    NSArray *variants = [self labelVariants]; NSMutableDictionary *labels = [NSMutableDictionary dictionary];
    CGFloat materialX, materialY, height;
    if (sideLabels) {
        CGFloat textWidth = available - material.width - 16, y = MTPInset;
        for (NSString *key in @[@"title", @"context", @"owner", @"phase"]) {
            CGFloat h = [self heightForLabel:key variants:variants width:textWidth]; labels[key] = [NSValue valueWithCGRect:CGRectMake(MTPInset, y, textWidth, h)]; y += h + 8;
        }
        CGFloat contentHeight = MAX(material.height, y - MTPInset - 8); height = 2 * MTPInset + contentHeight;
        materialX = self.width - MTPInset - material.width; materialY = MTPInset + (contentHeight - material.height) / 2;
    } else {
        CGFloat y = MTPInset;
        for (NSString *key in @[@"title", @"context", @"owner"]) {
            CGFloat h = [self heightForLabel:key variants:variants width:available]; labels[key] = [NSValue valueWithCGRect:CGRectMake(MTPInset, y, available, h)]; y += h + 12;
        }
        materialX = MTPInset + MAX(0, (available - material.width) / 2); materialY = y; y += material.height + 12;
        CGFloat phaseHeight = [self heightForLabel:@"phase" variants:variants width:available]; labels[@"phase"] = [NSValue valueWithCGRect:CGRectMake(MTPInset, y, available, phaseHeight)]; height = y + phaseHeight + MTPInset;
    }
    [self offsetFrames:before x:materialX y:materialY]; [self offsetFrames:after x:materialX y:materialY]; [self offsetFrames:joined x:materialX y:materialY]; [self offsetFrames:swept x:materialX y:materialY];
    self.beforeFrames = before; self.afterFrames = after; self.joinedFrames = joined; self.sweptFrames = swept; self.labelFrames = labels;
    if ([self isExchange]) self.cradleRect = CGRectMake(materialX, materialY, material.width, material.height);
    self.requiredRect = CGRectMake(0, 0, MAX(self.width, materialX + material.width + MTPInset), ceil(height));
    [self certifyGeometry];
}
- (void)certifyGeometry {
    NSString *failure = nil;
    NSMutableDictionary *allFrames = [self.beforeFrames mutableCopy]; [allFrames addEntriesFromDictionary:self.afterFrames];
    for (NSNumber *identifier in allFrames) {
        MultiplicativeTeachingUnit *unit = self.beforeUnits[identifier] ?: self.afterUnits[identifier]; CGRect frame = [allFrames[identifier] CGRectValue];
        if (!MTPFiniteRect(frame) || !CGSizeEqualToSize(frame.size, MTPPlaceValueBodySize(unit.column)) || !CGRectContainsRect(self.requiredRect, frame)) { failure = @"積木必須完整保留原來的大小。"; break; }
    }
    if (!failure) for (NSValue *value in self.sweptFrames.allValues) for (NSValue *label in self.labelFrames.allValues) {
        if (CGRectIntersectsRect(value.CGRectValue, CGRectInset(label.CGRectValue, -MTPClearance, -MTPClearance))) failure = @"移動路線太靠近文字。";
    }
    if (!failure) for (NSValue *value in allFrames.allValues) for (NSValue *label in self.labelFrames.allValues) {
        if (CGRectIntersectsRect(value.CGRectValue, CGRectInset(label.CGRectValue, -MTPClearance, -MTPClearance))) failure = @"積木太靠近文字。";
    }
    if (!failure && [self isTransfer]) {
        NSMutableSet *arrived = [NSMutableSet set];
        for (NSNumber *identifier in self.transferOrder) {
            CGRect swept = self.sweptFrames[identifier].CGRectValue;
            for (NSNumber *other in self.beforeFrames) if (![other isEqual:identifier]) {
                CGRect stationary = ([arrived containsObject:other] ? self.afterFrames[other] : self.beforeFrames[other]).CGRectValue;
                if (CGRectIntersectsRect(swept, CGRectInset(stationary, -MTPClearance, -MTPClearance))) failure = @"移動路線會碰到其他積木。";
            }
            [arrived addObject:identifier];
        }
    }
    if (!failure) for (NSUInteger i = 0; i <= 32; i++) {
        MTPPlaceValueProjection *projection = [self projectionAtElapsed:self.duration * i / 32.0];
        for (NSUInteger a = 0; a < projection.placements.count; a++) {
            CGRect frame = projection.placements[a].frame;
            if (!CGRectContainsRect(self.requiredRect, frame)) failure = @"完整動作超出預留範圍。";
            for (NSUInteger b = a + 1; b < projection.placements.count; b++) {
                CGRect overlap = CGRectIntersection(frame, projection.placements[b].frame);
                if (!CGRectIsNull(overlap) && overlap.size.width > .001 && overlap.size.height > .001) failure = @"積木不能互相蓋住。";
            }
        }
    }
    self.geometryFailure = failure ?: @""; self.geometryValid = failure == nil;
}
@end
