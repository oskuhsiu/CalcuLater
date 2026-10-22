#ifndef MultiplicativeTeachingActionCore_h
#define MultiplicativeTeachingActionCore_h

#include <stddef.h>
#include <stdint.h>

/* Foundation-free production kernel. It consumes, but never rewrites, the
 * reviewed sequence's original before/after states. No screen or clock policy. */
enum { MTCAColumns = 3, MTCAMaxRecipients = 9, MTCAMaxSourceSteps = 23,
       MTCAMaxUnits = 256, MTCAMaxActions = MTCAMaxSourceSteps * 9,
       MTCAMaxAffectedUnits = 10 };

typedef enum { MTCAOperationMultiply = 1, MTCAOperationDivide = 2 } MTCAOperation;
typedef enum {
    MTCASourceObserve, MTCASourcePredict, MTCASourceMultiplyPlace,
    MTCASourceRegroupUp, MTCASourceBringDown, MTCASourceDistribute,
    MTCASourceWriteDigit, MTCASourceRegroupDown, MTCASourceInspectRemainder,
    MTCASourceVerify, MTCASourceCompletion
} MTCASourceKind;
typedef enum {
    MTCAActionInspect, MTCAActionGenerateGroup, MTCAActionZeroGroups,
    MTCAActionExchangeUp, MTCAActionBringDown, MTCAActionDistributeRecipient,
    MTCAActionZeroDistribution, MTCAActionExchangeDown
} MTCAActionKind;
typedef enum { MTCAOriginOriginalInput, MTCAOriginGeneratedGroup,
               MTCAOriginExchange } MTCAUnitOrigin;
typedef enum { MTCAStatusOK, MTCAStatusInvalidInput, MTCAStatusInvalidSource,
               MTCAStatusCapacityExceeded } MTCAStatus;
/* Location is not a place value. A unit's immutable column supplies its value.
 * Retired and not-yet-created IDs both have location 0 in a given snapshot. */
enum { MTCALocationAbsent = 0, MTCALocationAccumulator = 1,
       MTCALocationInput = 2, MTCALocationPool = 3,
       MTCALocationFirstRecipient = 4 };

typedef struct {
    int accumulator[3], carry[3], input[3], pool[3];
    int recipients[MTCAMaxRecipients][3];
    unsigned int processedInputMask;
} MTCAInventory;

typedef struct {
    MTCASourceKind kind;
    int column, sourceColumn, destinationColumn; /* -1 when not applicable */
    MTCAInventory before, after;
    int generatedUnits, incomingCarryUnits, exchangeCount;
    int broughtDownUnits, unitsPerRecipient, totalTransferredUnits;
    int writesFinalCarry;
} MTCASourceStep;

typedef struct {
    int column; /* 0 hundreds, 1 tens, 2 ones; never changes for this ID */
    MTCAUnitOrigin origin;
    int sourceStepIndex, groupIndex; /* -1 where not applicable */
} MTCAUnit;

typedef struct {
    uint8_t locations[MTCAMaxUnits + 1];
    /* Annotation subset of accumulator units, NOT a second inventory. */
    uint8_t carry[MTCAMaxUnits + 1];
    unsigned int processedInputMask;
} MTCAState;

typedef struct {
    MTCAActionKind kind;
    int sourceStepIndex, indexWithinStep, countWithinStep;
    int column, sourceColumn, destinationColumn;
    int recipientIndex, groupIndex, groupCount; /* index -1 if none */
    MTCAState before, after;
    /* Generate: empty inputs, new outputs. Move: equal ID lists. Exchange:
     * retired inputs and new outputs with equal weighted value (10 <-> 1).
     * Inspection/zero: both empty. No arbitrary many-to-many exchange. */
    uint16_t inputIDs[MTCAMaxAffectedUnits], outputIDs[MTCAMaxAffectedUnits];
    int inputCount, outputCount;
    /* Already-owned IDs, excluded from generation and never duplicated. */
    uint16_t ownedCarryIDs[MTCAMaxRecipients];
    int ownedCarryCount;
} MTCAAction;

typedef struct {
    MTCAOperation operation;
    int operand, groupCount;
    MTCAUnit units[MTCAMaxUnits + 1]; /* IDs are 1...unitCount; 0 unused */
    int unitCount, actionCount;
    MTCAState initial;
    MTCAAction actions[MTCAMaxActions];
} MTCAPlan;

/* Allocate MTCAPlan on the heap. On failure its counts are zero; do not publish
 * partial data. Supported inputs: a 0...999, b 1...9, multiplication a*b<=999.
 * Each original source endpoint must match exactly or the entire plan fails. */
MTCAStatus MTCABuildPlan(MTCAOperation operation, int operand, int groupCount,
                        const MTCASourceStep *steps, size_t stepCount,
                        MTCAPlan *result);
void MTCAReadInventory(const MTCAPlan *plan, const MTCAState *state,
                       MTCAInventory *result);

#endif
