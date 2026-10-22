#include "MultiplicativeTeachingActionCore.h"
#include <string.h>

static int MTCAColumnIsValid(int column) { return column >= 0 && column < 3; }
static int MTCADigit(int operand, int column) {
    static const int places[3] = {100, 10, 1};
    return (operand / places[column]) % 10;
}

void MTCAReadInventory(const MTCAPlan *plan, const MTCAState *state, MTCAInventory *result) {
    memset(result, 0, sizeof(*result));
    result->processedInputMask = state->processedInputMask;
    for (int identity = 1; identity <= plan->unitCount; identity++) {
        int column = plan->units[identity].column;
        int location = state->locations[identity];
        if (location == MTCALocationAccumulator) result->accumulator[column]++;
        else if (location == MTCALocationInput) result->input[column]++;
        else if (location == MTCALocationPool) result->pool[column]++;
        else if (location >= MTCALocationFirstRecipient && location < MTCALocationFirstRecipient + plan->groupCount)
            result->recipients[location - MTCALocationFirstRecipient][column]++;
        if (state->carry[identity] && location == MTCALocationAccumulator) result->carry[column]++;
    }
}

static int MTCAInventoryEquals(const MTCAInventory *a, const MTCAInventory *b) {
    if (a->processedInputMask != b->processedInputMask) return 0;
    for (int column = 0; column < 3; column++) {
        if (a->accumulator[column] != b->accumulator[column] || a->carry[column] != b->carry[column]
            || a->input[column] != b->input[column] || a->pool[column] != b->pool[column]) return 0;
        for (int recipient = 0; recipient < MTCAMaxRecipients; recipient++)
            if (a->recipients[recipient][column] != b->recipients[recipient][column]) return 0;
    }
    return 1;
}

static int MTCAMint(MTCAPlan *plan, MTCAState *state, int column, int location,
                    MTCAUnitOrigin origin, int source, int group, int carry) {
    if (plan->unitCount >= MTCAMaxUnits) return 0;
    int identity = ++plan->unitCount;
    MTCAUnit unit = {column, origin, source, group};
    plan->units[identity] = unit;
    state->locations[identity] = (uint8_t)location;
    state->carry[identity] = (uint8_t)carry;
    return identity;
}

static int MTCACollect(const MTCAPlan *plan, const MTCAState *state, int location,
                       int column, uint16_t *identities, int count) {
    int found = 0;
    for (int identity = 1; identity <= plan->unitCount && found < count; identity++)
        if (state->locations[identity] == location && plan->units[identity].column == column)
            identities[found++] = (uint16_t)identity;
    return found == count;
}

static void MTCAClearCarry(const MTCAPlan *plan, MTCAState *state, int column) {
    for (int identity = 1; identity <= plan->unitCount; identity++)
        if (plan->units[identity].column == column) state->carry[identity] = 0;
}

static MTCAAction *MTCABegin(MTCAPlan *plan, const MTCAState *state,
                           const MTCASourceStep *source, int sourceIndex,
                           MTCAActionKind kind, int index, int count) {
    if (plan->actionCount >= MTCAMaxActions) return NULL;
    MTCAAction *action = &plan->actions[plan->actionCount++];
    action->kind = kind;
    action->sourceStepIndex = sourceIndex;
    action->indexWithinStep = index;
    action->countWithinStep = count;
    action->column = source->column;
    action->sourceColumn = source->sourceColumn;
    action->destinationColumn = source->destinationColumn;
    action->recipientIndex = -1;
    action->groupIndex = -1;
    action->groupCount = plan->groupCount;
    action->before = *state;
    return action;
}

static int MTCAKeepOwnedCarry(const MTCAPlan *plan, const MTCAState *state,
                              MTCAAction *action, int column) {
    for (int identity = 1; identity <= plan->unitCount; identity++) {
        if (state->carry[identity] && plan->units[identity].column == column) {
            if (state->locations[identity] != MTCALocationAccumulator || action->ownedCarryCount >= MTCAMaxRecipients) return 0;
            action->ownedCarryIDs[action->ownedCarryCount++] = (uint16_t)identity;
        }
    }
    return 1;
}

static int MTCADescriptorIsValid(const MTCASourceStep *source) {
    if (source->kind < MTCASourceObserve || source->kind > MTCASourceCompletion) return 0;
    int global = source->kind == MTCASourceObserve || source->kind == MTCASourceInspectRemainder
        || source->kind == MTCASourceVerify || source->kind == MTCASourceCompletion;
    if (global ? source->column != -1 : !MTCAColumnIsValid(source->column)) return 0;
    int exchange = source->kind == MTCASourceRegroupUp || source->kind == MTCASourceRegroupDown;
    if (!exchange && (source->sourceColumn != -1 || source->destinationColumn != -1 || source->exchangeCount != 0)) return 0;
    if (source->kind != MTCASourceMultiplyPlace && (source->generatedUnits != 0 || source->incomingCarryUnits != 0)) return 0;
    if (source->kind != MTCASourceBringDown && source->broughtDownUnits != 0) return 0;
    if (source->kind != MTCASourceDistribute && (source->unitsPerRecipient != 0 || source->totalTransferredUnits != 0)) return 0;
    if (source->kind != MTCASourceWriteDigit && source->writesFinalCarry != 0) return 0;
    return source->writesFinalCarry == 0 || source->writesFinalCarry == 1;
}

MTCAStatus MTCABuildPlan(MTCAOperation operation, int operand, int groupCount,
                        const MTCASourceStep *steps, size_t stepCount, MTCAPlan *result) {
    if (!result) return MTCAStatusInvalidInput;
    memset(result, 0, sizeof(*result));
    MTCAStatus failure = MTCAStatusInvalidSource;
    if ((operation != MTCAOperationMultiply && operation != MTCAOperationDivide)
        || operand < 0 || operand > 999 || groupCount < 1 || groupCount > 9
        || !steps || stepCount < 2 || stepCount > MTCAMaxSourceSteps) return MTCAStatusInvalidInput;
    if (operation == MTCAOperationMultiply && operand * groupCount > 999) return MTCAStatusInvalidInput;
    if (steps[0].kind != MTCASourceObserve || steps[stepCount - 1].kind != MTCASourceCompletion) return MTCAStatusInvalidSource;
    result->operation = operation;
    result->operand = operand;
    result->groupCount = groupCount;
    MTCAState state = {0};
    if (operation == MTCAOperationDivide) {
        for (int column = 0; column < 3; column++) {
            for (int unit = 0; unit < MTCADigit(operand, column); unit++) {
                if (!MTCAMint(result, &state, column, MTCALocationInput,
                              MTCAOriginOriginalInput, -1, -1, 0)) goto capacity;
            }
        }
    }
    result->initial = state;
    for (size_t sourceIndex = 0; sourceIndex < stepCount; sourceIndex++) {
        const MTCASourceStep *source = &steps[sourceIndex];
        if (!MTCADescriptorIsValid(source)) goto fail;
        MTCAInventory inventory;
        MTCAReadInventory(result, &state, &inventory);
        if (!MTCAInventoryEquals(&inventory, &source->before)) goto fail;
        int column = source->column;
        switch (source->kind) {
            case MTCASourceMultiplyPlace: {
                if (operation != MTCAOperationMultiply || !MTCAColumnIsValid(column)
                    || (state.processedInputMask & (1u << column))) goto fail;
                int digit = MTCADigit(operand, column);
                if (source->generatedUnits != digit * groupCount || source->incomingCarryUnits != inventory.accumulator[column]
                    || inventory.carry[column] != source->incomingCarryUnits) goto fail;
                int count = digit ? groupCount : 1;
                for (int index = 0; index < count; index++) {
                    MTCAAction *action = MTCABegin(result, &state, source, (int)sourceIndex,
                        digit ? MTCAActionGenerateGroup : MTCAActionZeroGroups, index, count);
                    if (!action) goto capacity;
                    action->groupIndex = digit ? index : -1;
                    if (!MTCAKeepOwnedCarry(result, &state, action, column)) goto fail;
                    for (int unit = 0; unit < digit; unit++) {
                        int identity = MTCAMint(result, &state, column, MTCALocationAccumulator,
                            MTCAOriginGeneratedGroup, (int)sourceIndex, index, 0);
                        if (!identity) goto capacity;
                        action->outputIDs[action->outputCount++] = (uint16_t)identity;
                    }
                    if (index == count - 1) {
                        MTCAClearCarry(result, &state, column);
                        state.processedInputMask |= 1u << column;
                    }
                    action->after = state;
                }
                break;
            }
            case MTCASourceRegroupUp: {
                if (operation != MTCAOperationMultiply || !MTCAColumnIsValid(column)
                    || source->sourceColumn != column || source->destinationColumn != column - 1
                    || !MTCAColumnIsValid(source->destinationColumn) || source->exchangeCount < 1
                    || source->exchangeCount > 8 || source->exchangeCount != inventory.accumulator[column] / 10) goto fail;
                for (int index = 0; index < source->exchangeCount; index++) {
                    MTCAAction *action = MTCABegin(result, &state, source, (int)sourceIndex,
                        MTCAActionExchangeUp, index, source->exchangeCount);
                    if (!action) goto capacity;
                    action->inputCount = 10;
                    if (!MTCACollect(result, &state, MTCALocationAccumulator, column, action->inputIDs, 10)) goto fail;
                    for (int unit = 0; unit < 10; unit++) {
                        state.locations[action->inputIDs[unit]] = MTCALocationAbsent;
                        state.carry[action->inputIDs[unit]] = 0;
                    }
                    int identity = MTCAMint(result, &state, source->destinationColumn, MTCALocationAccumulator,
                        MTCAOriginExchange, (int)sourceIndex, -1, 1);
                    if (!identity) goto capacity;
                    action->outputCount = 1;
                    action->outputIDs[0] = (uint16_t)identity;
                    action->after = state;
                }
                break;
            }
            case MTCASourceBringDown: {
                if (operation != MTCAOperationDivide || !MTCAColumnIsValid(column)
                    || source->broughtDownUnits != inventory.input[column] || source->broughtDownUnits < 0
                    || source->broughtDownUnits > 9) goto fail;
                MTCAAction *action = MTCABegin(result, &state, source, (int)sourceIndex, MTCAActionBringDown, 0, 1);
                if (!action) goto capacity;
                action->inputCount = action->outputCount = source->broughtDownUnits;
                if (!MTCACollect(result, &state, MTCALocationInput, column, action->inputIDs, action->inputCount)) goto fail;
                for (int unit = 0; unit < action->inputCount; unit++) {
                    action->outputIDs[unit] = action->inputIDs[unit];
                    state.locations[action->inputIDs[unit]] = MTCALocationPool;
                }
                action->after = state;
                break;
            }
            case MTCASourceDistribute: {
                if (operation != MTCAOperationDivide || !MTCAColumnIsValid(column)
                    || source->unitsPerRecipient < 0 || source->unitsPerRecipient > 9
                    || source->unitsPerRecipient != inventory.pool[column] / groupCount
                    || source->totalTransferredUnits != source->unitsPerRecipient * groupCount) goto fail;
                int count = source->unitsPerRecipient ? groupCount : 1;
                for (int index = 0; index < count; index++) {
                    MTCAAction *action = MTCABegin(result, &state, source, (int)sourceIndex,
                        source->unitsPerRecipient ? MTCAActionDistributeRecipient : MTCAActionZeroDistribution, index, count);
                    if (!action) goto capacity;
                    action->recipientIndex = source->unitsPerRecipient ? index : -1;
                    action->inputCount = action->outputCount = source->unitsPerRecipient;
                    if (!MTCACollect(result, &state, MTCALocationPool, column, action->inputIDs, action->inputCount)) goto fail;
                    for (int unit = 0; unit < action->inputCount; unit++) {
                        action->outputIDs[unit] = action->inputIDs[unit];
                        state.locations[action->inputIDs[unit]] = (uint8_t)(MTCALocationFirstRecipient + index);
                    }
                    action->after = state;
                }
                break;
            }
            case MTCASourceRegroupDown: {
                if (operation != MTCAOperationDivide || !MTCAColumnIsValid(column)
                    || source->sourceColumn != column || source->destinationColumn != column + 1
                    || !MTCAColumnIsValid(source->destinationColumn) || source->exchangeCount < 1
                    || source->exchangeCount >= groupCount || source->exchangeCount != inventory.pool[column]) goto fail;
                for (int index = 0; index < source->exchangeCount; index++) {
                    MTCAAction *action = MTCABegin(result, &state, source, (int)sourceIndex,
                        MTCAActionExchangeDown, index, source->exchangeCount);
                    if (!action) goto capacity;
                    action->inputCount = 1;
                    if (!MTCACollect(result, &state, MTCALocationPool, column, action->inputIDs, 1)) goto fail;
                    state.locations[action->inputIDs[0]] = MTCALocationAbsent;
                    for (int unit = 0; unit < 10; unit++) {
                        int identity = MTCAMint(result, &state, source->destinationColumn, MTCALocationPool,
                            MTCAOriginExchange, (int)sourceIndex, -1, 0);
                        if (!identity) goto capacity;
                        action->outputIDs[action->outputCount++] = (uint16_t)identity;
                    }
                    action->after = state;
                }
                break;
            }
            case MTCASourceWriteDigit:
                if (!MTCAColumnIsValid(column)) goto fail;
                if (source->writesFinalCarry && operation != MTCAOperationMultiply) goto fail;
                /* Falls through: a write changes only the separately-owned
                 * written metadata, plus consuming the final carry annotation. */
                /* fall through */
            case MTCASourceObserve:
            case MTCASourcePredict:
            case MTCASourceInspectRemainder:
            case MTCASourceVerify:
            case MTCASourceCompletion: {
                MTCAAction *action = MTCABegin(result, &state, source, (int)sourceIndex, MTCAActionInspect, 0, 1);
                if (!action) goto capacity;
                if (source->kind == MTCASourceWriteDigit && source->writesFinalCarry) MTCAClearCarry(result, &state, column);
                action->after = state;
                break;
            }
            default: goto fail;
        }
        MTCAReadInventory(result, &state, &inventory);
        if (!MTCAInventoryEquals(&inventory, &source->after)) goto fail;
    }
    return MTCAStatusOK;
capacity:
    failure = MTCAStatusCapacityExceeded;
fail:
    result->unitCount = 0;
    result->actionCount = 0;
    return failure;
}
