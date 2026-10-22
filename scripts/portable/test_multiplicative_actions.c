/* Independent arithmetic fixtures exercise the actual production action kernel.
 * No copy of its splitting/minting algorithm is used to produce expectations.
 * This does NOT compile the Foundation bridge or execute UIKit/XCTest. */
#include "MultiplicativeTeachingActionCore.h"
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int currentA, currentB, currentOperation;
static int maxActions, maxUnits, maxOwned, maxSourceActions;
static long checkedActions, checkedSnapshots;

#define REQUIRE(condition, message) do { if (!(condition)) { \
    fprintf(stderr, "FAIL operation=%d a=%d b=%d line=%d: %s\n", \
        currentOperation, currentA, currentB, __LINE__, message); exit(1); } } while (0)

typedef struct {
    MTCASourceStep steps[MTCAMaxSourceSteps];
    int count;
    MTCAInventory current;
} Fixture;

static int digit(int value, int column) {
    const int places[3] = {100, 10, 1};
    return value / places[column] % 10;
}
static int valueOf(const MTCAPlan *plan, int identity) {
    const int places[3] = {100, 10, 1};
    return places[plan->units[identity].column];
}
static int weighted(const int counts[3]) { return counts[0] * 100 + counts[1] * 10 + counts[2]; }
static int stateValue(const MTCAPlan *plan, const MTCAState *state) {
    int total = 0;
    for (int identity = 1; identity <= plan->unitCount; identity++)
        if (state->locations[identity] != MTCALocationAbsent) total += valueOf(plan, identity);
    return total;
}
static int contains(const uint16_t *ids, int count, int identity) {
    for (int index = 0; index < count; index++) if (ids[index] == identity) return 1;
    return 0;
}
static int equalState(const MTCAState *a, const MTCAState *b) {
    return a->processedInputMask == b->processedInputMask
        && memcmp(a->locations, b->locations, sizeof(a->locations)) == 0
        && memcmp(a->carry, b->carry, sizeof(a->carry)) == 0;
}
static int equalInventory(const MTCAInventory *a, const MTCAInventory *b) {
    if (a->processedInputMask != b->processedInputMask) return 0;
    for (int column = 0; column < 3; column++) {
        if (a->accumulator[column] != b->accumulator[column] || a->carry[column] != b->carry[column]
            || a->input[column] != b->input[column] || a->pool[column] != b->pool[column]) return 0;
        for (int recipient = 0; recipient < 9; recipient++)
            if (a->recipients[recipient][column] != b->recipients[recipient][column]) return 0;
    }
    return 1;
}
static MTCASourceStep *begin(Fixture *fixture, MTCASourceKind kind, int column) {
    REQUIRE(fixture->count < MTCAMaxSourceSteps, "fixture source capacity");
    MTCASourceStep *step = &fixture->steps[fixture->count++];
    step->kind = kind;
    step->column = column;
    step->sourceColumn = step->destinationColumn = -1;
    step->before = fixture->current;
    step->after = fixture->current;
    return step;
}
static void finish(Fixture *fixture, MTCASourceStep *step) { step->after = fixture->current; }
static void makeFixture(Fixture *fixture, MTCAOperation operation, int a, int b) {
    memset(fixture, 0, sizeof(*fixture));
    int start = a >= 100 ? 0 : (a >= 10 ? 1 : 2);
    if (operation == MTCAOperationDivide)
        for (int column = 0; column < 3; column++) fixture->current.input[column] = digit(a, column);
    begin(fixture, MTCASourceObserve, -1);
    if (operation == MTCAOperationMultiply) {
        for (int column = 2; column >= start; column--) {
            begin(fixture, MTCASourcePredict, column);
            MTCASourceStep *step = begin(fixture, MTCASourceMultiplyPlace, column);
            step->generatedUnits = digit(a, column) * b;
            step->incomingCarryUnits = fixture->current.accumulator[column];
            fixture->current.accumulator[column] += step->generatedUnits;
            fixture->current.carry[column] = 0;
            fixture->current.processedInputMask |= 1u << column;
            finish(fixture, step);
            int bundles = fixture->current.accumulator[column] / 10;
            if (bundles) {
                step = begin(fixture, MTCASourceRegroupUp, column);
                step->sourceColumn = column;
                step->destinationColumn = column - 1;
                step->exchangeCount = bundles;
                fixture->current.accumulator[column] %= 10;
                fixture->current.accumulator[column - 1] += bundles;
                fixture->current.carry[column - 1] = bundles;
                finish(fixture, step);
            }
            begin(fixture, MTCASourceWriteDigit, column);
        }
        if (start && fixture->current.accumulator[start - 1]) {
            MTCASourceStep *step = begin(fixture, MTCASourceWriteDigit, start - 1);
            step->writesFinalCarry = 1;
            fixture->current.carry[start - 1] = 0;
            finish(fixture, step);
        }
    } else {
        for (int column = start; column < 3; column++) {
            MTCASourceStep *step = begin(fixture, MTCASourceBringDown, column);
            step->broughtDownUnits = fixture->current.input[column];
            fixture->current.pool[column] += fixture->current.input[column];
            fixture->current.input[column] = 0;
            finish(fixture, step);
            begin(fixture, MTCASourcePredict, column);
            step = begin(fixture, MTCASourceDistribute, column);
            step->unitsPerRecipient = fixture->current.pool[column] / b;
            step->totalTransferredUnits = step->unitsPerRecipient * b;
            for (int recipient = 0; recipient < b; recipient++)
                fixture->current.recipients[recipient][column] += step->unitsPerRecipient;
            fixture->current.pool[column] %= b;
            finish(fixture, step);
            begin(fixture, MTCASourceWriteDigit, column);
            if (fixture->current.pool[column] && column < 2) {
                step = begin(fixture, MTCASourceRegroupDown, column);
                step->sourceColumn = column;
                step->destinationColumn = column + 1;
                step->exchangeCount = fixture->current.pool[column];
                fixture->current.pool[column + 1] += fixture->current.pool[column] * 10;
                fixture->current.pool[column] = 0;
                finish(fixture, step);
            }
        }
        begin(fixture, MTCASourceInspectRemainder, -1);
    }
    begin(fixture, MTCASourceVerify, -1);
    begin(fixture, MTCASourceCompletion, -1);
}

static void checkSnapshot(const MTCAPlan *plan, const MTCAState *state) {
    checkedSnapshots++;
    int owned = 0;
    for (int identity = 1; identity <= plan->unitCount; identity++) {
        int location = state->locations[identity];
        REQUIRE(plan->units[identity].column >= 0 && plan->units[identity].column < 3, "immutable place bound");
        REQUIRE(location >= MTCALocationAbsent && location < MTCALocationFirstRecipient + plan->groupCount, "location bound");
        if (location) owned++;
        if (state->carry[identity]) REQUIRE(location == MTCALocationAccumulator, "carry is owned annotation subset");
        if (plan->operation == MTCAOperationMultiply)
            REQUIRE(location == MTCALocationAbsent || location == MTCALocationAccumulator, "multiplication never has a fake input pool");
        else REQUIRE(location != MTCALocationAccumulator && !state->carry[identity], "division ownership categories");
    }
    if (owned > maxOwned) maxOwned = owned;
    if (plan->operation == MTCAOperationDivide) REQUIRE(stateValue(plan, state) == plan->operand, "division value conservation at every endpoint");
}

static void checkPlan(const Fixture *fixture, const MTCAPlan *plan) {
    REQUIRE(plan->actionCount >= fixture->count && plan->actionCount <= MTCAMaxActions, "bounded nonempty actions");
    REQUIRE(plan->unitCount >= 0 && plan->unitCount <= MTCAMaxUnits, "bounded minted units");
    if (plan->actionCount > maxActions) maxActions = plan->actionCount;
    if (plan->unitCount > maxUnits) maxUnits = plan->unitCount;
    unsigned char appeared[MTCAMaxUnits + 1] = {0};
    for (int identity = 1; identity <= plan->unitCount; identity++) {
        appeared[identity] = plan->initial.locations[identity] != MTCALocationAbsent;
        if (appeared[identity]) {
            REQUIRE(plan->units[identity].origin == MTCAOriginOriginalInput, "only original IDs at initial endpoint");
            REQUIRE(plan->units[identity].sourceStepIndex == -1 && plan->units[identity].groupIndex == -1, "original provenance");
        }
    }
    const MTCAState *previous = &plan->initial;
    int nextSource = 0, nextIndex = 0;
    for (int index = 0; index < plan->actionCount; index++) {
        const MTCAAction *action = &plan->actions[index];
        checkedActions++;
        REQUIRE(equalState(previous, &action->before), "adjacent endpoint identity and annotation continuity");
        REQUIRE(action->sourceStepIndex == nextSource && action->indexWithinStep == nextIndex, "precise contiguous source mapping");
        REQUIRE(action->countWithinStep >= 1 && action->countWithinStep <= 9, "bounded meaningful split");
        if (action->countWithinStep > maxSourceActions) maxSourceActions = action->countWithinStep;
        const MTCASourceStep *source = &fixture->steps[nextSource];
        MTCAInventory inventory;
        if (!nextIndex) {
            MTCAReadInventory(plan, &action->before, &inventory);
            REQUIRE(equalInventory(&inventory, &source->before), "exact original source before endpoint");
        }
        if (nextIndex == action->countWithinStep - 1) {
            MTCAReadInventory(plan, &action->after, &inventory);
            REQUIRE(equalInventory(&inventory, &source->after), "exact original source after endpoint");
            nextSource++;
            nextIndex = 0;
        } else nextIndex++;
        checkSnapshot(plan, &action->before);
        checkSnapshot(plan, &action->after);
        REQUIRE(action->inputCount >= 0 && action->inputCount <= 10 && action->outputCount >= 0 && action->outputCount <= 10, "small causal unit lists");
        int inputValue = 0, outputValue = 0;
        for (int unit = 0; unit < action->inputCount; unit++) {
            int identity = action->inputIDs[unit];
            REQUIRE(identity > 0 && identity <= plan->unitCount && action->before.locations[identity], "input already owned");
            REQUIRE(!contains(action->inputIDs, unit, identity), "unique input IDs");
            inputValue += valueOf(plan, identity);
        }
        for (int unit = 0; unit < action->outputCount; unit++) {
            int identity = action->outputIDs[unit];
            REQUIRE(identity > 0 && identity <= plan->unitCount && action->after.locations[identity], "output owned afterwards");
            REQUIRE(!contains(action->outputIDs, unit, identity), "unique output IDs");
            outputValue += valueOf(plan, identity);
        }
        int generation = action->kind == MTCAActionGenerateGroup;
        REQUIRE(stateValue(plan, &action->after) - stateValue(plan, &action->before) == (generation ? outputValue : 0), "generation is explicit; everything else conserves value");
        for (int identity = 1; identity <= plan->unitCount; identity++) {
            int before = action->before.locations[identity], after = action->after.locations[identity];
            if (before == after) continue;
            REQUIRE((before && contains(action->inputIDs, action->inputCount, identity))
                || (after && contains(action->outputIDs, action->outputCount, identity)), "every ownership delta is declared");
            if (!before && after) {
                REQUIRE(!appeared[identity], "no retired identity resurrects");
                appeared[identity] = 1;
                REQUIRE(plan->units[identity].sourceStepIndex == action->sourceStepIndex, "birth maps to exact source");
            }
        }
        for (int unit = 0; unit < action->ownedCarryCount; unit++) {
            int identity = action->ownedCarryIDs[unit];
            REQUIRE(action->before.carry[identity] && action->before.locations[identity] == MTCALocationAccumulator
                && action->after.locations[identity] == MTCALocationAccumulator, "incoming carry already owned throughout creation");
            REQUIRE(!contains(action->outputIDs, action->outputCount, identity), "incoming carry never generated again");
            REQUIRE(plan->units[identity].column == action->column, "incoming carry keeps its place");
        }
        switch (action->kind) {
            case MTCAActionGenerateGroup:
                REQUIRE(action->inputCount == 0 && action->outputCount == digit(plan->operand, action->column), "one equally-sized new group");
                REQUIRE(action->countWithinStep == plan->groupCount && action->groupIndex == action->indexWithinStep, "generated group mapping");
                REQUIRE(action->ownedCarryCount == source->incomingCarryUnits, "one separately identified incoming carry throughout groups");
                for (int unit = 0; unit < action->outputCount; unit++) {
                    const MTCAUnit *created = &plan->units[action->outputIDs[unit]];
                    REQUIRE(created->origin == MTCAOriginGeneratedGroup && created->groupIndex == action->groupIndex, "generation provenance");
                    REQUIRE(created->column == action->column, "generation stays at original input place");
                }
                break;
            case MTCAActionExchangeUp:
                REQUIRE(action->inputCount == 10 && action->outputCount == 1 && inputValue == outputValue, "one exact ten-to-one exchange");
                REQUIRE(action->destinationColumn == action->sourceColumn - 1, "up exchange is adjacent");
                break;
            case MTCAActionExchangeDown:
                REQUIRE(action->inputCount == 1 && action->outputCount == 10 && inputValue == outputValue, "one exact one-to-ten exchange");
                REQUIRE(action->destinationColumn == action->sourceColumn + 1, "down exchange is adjacent");
                break;
            case MTCAActionBringDown:
            case MTCAActionDistributeRecipient:
                REQUIRE(action->inputCount == action->outputCount && action->inputCount <= 9, "bounded transfer cardinality");
                for (int unit = 0; unit < action->inputCount; unit++) {
                    int identity = action->inputIDs[unit];
                    REQUIRE(identity == action->outputIDs[unit] && plan->units[identity].column == action->column, "transfer preserves exact identity and place");
                    REQUIRE(action->before.locations[identity] == (action->kind == MTCAActionBringDown ? MTCALocationInput : MTCALocationPool), "transfer has one truthful source");
                    REQUIRE(action->after.locations[identity] == (action->kind == MTCAActionBringDown ? MTCALocationPool : MTCALocationFirstRecipient + action->recipientIndex), "transfer has one truthful destination");
                }
                if (action->kind == MTCAActionDistributeRecipient) {
                    REQUIRE(action->recipientIndex == action->indexWithinStep && action->countWithinStep == plan->groupCount, "exactly one recipient per action");
                    REQUIRE(action->inputCount == source->unitsPerRecipient, "recipient receives intended same-place count");
                }
                break;
            case MTCAActionZeroGroups:
            case MTCAActionZeroDistribution:
                REQUIRE(action->countWithinStep == 1 && action->groupIndex == -1 && action->recipientIndex == -1, "zero does not create busywork or pretend targets");
                /* fall through */
            case MTCAActionInspect:
                REQUIRE(action->inputCount == 0 && action->outputCount == 0, "stationary action has no invented moving pieces");
                break;
        }
        if (action->kind == MTCAActionExchangeUp || action->kind == MTCAActionExchangeDown) {
            for (int unit = 0; unit < action->inputCount; unit++) REQUIRE(!action->after.locations[action->inputIDs[unit]], "exchanged input retired");
            for (int unit = 0; unit < action->outputCount; unit++) {
                int identity = action->outputIDs[unit];
                REQUIRE(!action->before.locations[identity] && plan->units[identity].origin == MTCAOriginExchange, "exchange output is new lineage, not a moved glyph");
                REQUIRE(plan->units[identity].column == action->destinationColumn && plan->units[identity].groupIndex == -1, "exchange result typed correctly");
            }
        }
        previous = &action->after;
    }
    REQUIRE(nextSource == fixture->count && nextIndex == 0, "all source steps covered once");
    MTCAInventory final;
    MTCAReadInventory(plan, previous, &final);
    if (plan->operation == MTCAOperationMultiply) {
        REQUIRE(weighted(final.accumulator) == plan->operand * plan->groupCount && weighted(final.carry) == 0, "final product and consumed carry annotations");
        for (int column = 0; column < 3; column++) REQUIRE(final.accumulator[column] == digit(plan->operand * plan->groupCount, column), "settled product place counts");
    } else {
        REQUIRE(weighted(final.input) == 0 && weighted(final.pool) == plan->operand % plan->groupCount, "single final remainder");
        for (int recipient = 0; recipient < plan->groupCount; recipient++) REQUIRE(weighted(final.recipients[recipient]) == plan->operand / plan->groupCount, "equal final recipient values");
    }
}

static void checkRejection(MTCAPlan *plan) {
    Fixture fixture;
    makeFixture(&fixture, MTCAOperationMultiply, 99, 9);
    REQUIRE(MTCABuildPlan(MTCAOperationMultiply, 99, 9, fixture.steps, fixture.count, NULL) == MTCAStatusInvalidInput, "null result rejection");
    const int invalid[][2] = {{-1,1},{1000,1},{INT_MIN,1},{INT_MAX,1},{1,0},{1,-1},{1,10},{1,INT_MAX},{112,9}};
    for (size_t index = 0; index < sizeof(invalid) / sizeof(invalid[0]); index++) {
        REQUIRE(MTCABuildPlan(MTCAOperationMultiply, invalid[index][0], invalid[index][1], fixture.steps, fixture.count, plan) == MTCAStatusInvalidInput, "bounds before multiplication");
        REQUIRE(plan->unitCount == 0 && plan->actionCount == 0, "unsupported plan does not expose partial actions");
    }
    REQUIRE(MTCABuildPlan(MTCAOperationDivide, 1, 1, NULL, 2, plan) == MTCAStatusInvalidInput, "null source rejection");
    REQUIRE(MTCABuildPlan(MTCAOperationMultiply, 99, 9, fixture.steps, SIZE_MAX, plan) == MTCAStatusInvalidInput, "source count overflow rejection");
    for (int source = 0; source < fixture.count; source++) {
        Fixture malformed = fixture;
        malformed.steps[source].after.accumulator[2]++;
        REQUIRE(MTCABuildPlan(MTCAOperationMultiply, 99, 9, malformed.steps, malformed.count, plan) == MTCAStatusInvalidSource, "any wrong source endpoint rejected");
        REQUIRE(plan->actionCount == 0 && plan->unitCount == 0, "endpoint failure not published");
        malformed = fixture;
        malformed.steps[source].column = INT_MAX;
        REQUIRE(MTCABuildPlan(MTCAOperationMultiply, 99, 9, malformed.steps, malformed.count, plan) == MTCAStatusInvalidSource, "invalid column rejection");
    }
    fixture.steps[0].generatedUnits = 1;
    REQUIRE(MTCABuildPlan(MTCAOperationMultiply, 99, 9, fixture.steps, fixture.count, plan) == MTCAStatusInvalidSource, "unrelated payload cannot smuggle an effect");
}

int main(void) {
    MTCAPlan *plan = calloc(1, sizeof(*plan));
    REQUIRE(plan != NULL, "allocation");
    long multiplicationCases = 0, divisionCases = 0;
    for (int operation = MTCAOperationMultiply; operation <= MTCAOperationDivide; operation++) {
        for (int a = 0; a <= 999; a++) {
            for (int b = 1; b <= 9; b++) {
                if (operation == MTCAOperationMultiply && a * b > 999) continue;
                currentA = a; currentB = b; currentOperation = operation;
                Fixture fixture;
                makeFixture(&fixture, (MTCAOperation)operation, a, b);
                REQUIRE(MTCABuildPlan((MTCAOperation)operation, a, b, fixture.steps, fixture.count, plan) == MTCAStatusOK, "bounded canonical fixture accepted");
                checkPlan(&fixture, plan);
                if (operation == MTCAOperationMultiply) multiplicationCases++; else divisionCases++;
            }
        }
    }
    checkRejection(plan);
    free(plan);
    printf("PASS production C kernel: %ld multiplication cases + %ld division cases; %ld actions, %ld endpoint checks.\n", multiplicationCases, divisionCases, checkedActions, checkedSnapshots);
    printf("Observed maxima: %d actions/lesson, %d actions/source step, %d minted identities, %d simultaneously owned units.\n", maxActions, maxSourceActions, maxUnits, maxOwned);
    puts("Scope: production split/identity/conservation kernel only. Foundation bridge, XCTest and UIKit are NOT run here.");
    return 0;
}
