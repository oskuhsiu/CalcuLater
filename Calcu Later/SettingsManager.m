#import "SettingsManager.h"
#import "ProblemGenerator.h"

@interface SettingsManager ()
@property (nonatomic, strong) NSUserDefaults *userDefaults;
- (BOOL)hasEnabledOperation;
@end

@implementation SettingsManager

+ (SettingsManager *)sharedInstance {
    static SettingsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SettingsManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    return [self initWithUserDefaults:NSUserDefaults.standardUserDefaults];
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    self = [super init];
    if (self) {
        _userDefaults = userDefaults;
        [self loadSettings];
    }
    return self;
}

- (id)_objOrDefault:(NSString *)key {
    return [self.userDefaults objectForKey:key];
}

// Only accept whole numbers. Older launches may have supplied numeric strings
// through defaults arguments; those remain valid, but malformed data cannot
// silently become the otherwise valid multiple-choice value 0.
- (NSInteger)integerForKey:(NSString *)key fallback:(NSInteger)fallback
                   minimum:(NSInteger)minimum maximum:(NSInteger)maximum {
    id value = [self.userDefaults objectForKey:key];
    NSInteger number = fallback;
    BOOL valid = NO;
    if ([value isKindOfClass:NSNumber.class]) {
        double numericValue = [value doubleValue];
        if (numericValue >= minimum && numericValue <= maximum) {
            number = [value integerValue];
            valid = numericValue == number;
        }
    } else if ([value isKindOfClass:NSString.class]) {
        NSScanner *scanner = [NSScanner scannerWithString:value];
        valid = [scanner scanInteger:&number] && scanner.isAtEnd &&
                number >= minimum && number <= maximum;
    }
    if (value && !valid) [self.userDefaults setInteger:fallback forKey:key];
    return valid ? number : fallback;
}

- (void)loadSettings {
    NSUserDefaults *d = self.userDefaults;

    self.digits1 = [self _objOrDefault:@"digits1"] ? [d integerForKey:@"digits1"] : 2;
    self.digits2 = [self _objOrDefault:@"digits2"] ? [d integerForKey:@"digits2"] : 2;
    self.allowNegativeResults = [self _objOrDefault:@"allowNegativeResults"] ? [d boolForKey:@"allowNegativeResults"] : NO;

    self.drillTier = [self integerForKey:@"drillTier" fallback:DrillTierD2
                               minimum:DrillTierD1 maximum:DrillTierMixed];

    self.operationAddition = [self _objOrDefault:@"operationAddition"] ? [d boolForKey:@"operationAddition"] : YES;
    self.operationSubtraction = [self _objOrDefault:@"operationSubtraction"] ? [d boolForKey:@"operationSubtraction"] : YES;
    self.operationMultiplication = [self _objOrDefault:@"operationMultiplication"] ? [d boolForKey:@"operationMultiplication"] : NO;
    self.operationDivision = [self _objOrDefault:@"operationDivision"] ? [d boolForKey:@"operationDivision"] : NO;
    if (![self hasEnabledOperation]) {
        // Match the generator's existing safe fallback without enabling every
        // operation or throwing away the family's other preferences.
        self.operationAddition = YES;
        [d setBool:YES forKey:@"operationAddition"];
    }

    self.hintShowAnswer = [self _objOrDefault:@"hintShowAnswer"] ? [d boolForKey:@"hintShowAnswer"] : YES;
    self.hintStandard = [self _objOrDefault:@"hintStandard"] ? [d boolForKey:@"hintStandard"] : YES;
    self.hintMultiLayer = [self _objOrDefault:@"hintMultiLayer"] ? [d boolForKey:@"hintMultiLayer"] : YES;
    self.hintAnimated = [self _objOrDefault:@"hintAnimated"] ? [d boolForKey:@"hintAnimated"] : YES;

    self.answerMode = (AnswerMode)[self integerForKey:@"answerMode" fallback:AnswerModeMultipleChoice
                                            minimum:AnswerModeMultipleChoice maximum:AnswerModeWriting];
    self.soundEffectsEnabled = [self _objOrDefault:@"soundEffectsEnabled"] ? [d boolForKey:@"soundEffectsEnabled"] : YES;
    self.mascotEnabled = [self _objOrDefault:@"mascotEnabled"] ? [d boolForKey:@"mascotEnabled"] : YES;
}

- (void)saveSettings {
    NSUserDefaults *d = self.userDefaults;
    if (self.drillTier < DrillTierD1 || self.drillTier > DrillTierMixed) self.drillTier = DrillTierD2;
    if (self.answerMode != AnswerModeMultipleChoice && self.answerMode != AnswerModeWriting) {
        self.answerMode = AnswerModeMultipleChoice;
    }
    if (![self hasEnabledOperation]) self.operationAddition = YES;

    [d setInteger:self.digits1 forKey:@"digits1"];
    [d setInteger:self.digits2 forKey:@"digits2"];
    [d setBool:self.allowNegativeResults forKey:@"allowNegativeResults"];

    [d setInteger:self.drillTier forKey:@"drillTier"];

    [d setBool:self.operationAddition forKey:@"operationAddition"];
    [d setBool:self.operationSubtraction forKey:@"operationSubtraction"];
    [d setBool:self.operationMultiplication forKey:@"operationMultiplication"];
    [d setBool:self.operationDivision forKey:@"operationDivision"];

    [d setBool:self.hintShowAnswer forKey:@"hintShowAnswer"];
    [d setBool:self.hintStandard forKey:@"hintStandard"];
    [d setBool:self.hintMultiLayer forKey:@"hintMultiLayer"];
    [d setBool:self.hintAnimated forKey:@"hintAnimated"];

    [d setInteger:(NSInteger)self.answerMode forKey:@"answerMode"];
    [d setBool:self.soundEffectsEnabled forKey:@"soundEffectsEnabled"];
    [d setBool:self.mascotEnabled forKey:@"mascotEnabled"];

    // NSUserDefaults persists changes automatically. Each settings interaction
    // calls this method, so dismissing the sheet never depends on tapping Done.
}

- (BOOL)hasEnabledOperation {
    return self.operationAddition || self.operationSubtraction ||
           self.operationMultiplication || self.operationDivision;
}

- (BOOL)isOperationEnabled:(SettingsOperation)operation {
    switch (operation) {
        case SettingsOperationAddition: return self.operationAddition;
        case SettingsOperationSubtraction: return self.operationSubtraction;
        case SettingsOperationMultiplication: return self.operationMultiplication;
        case SettingsOperationDivision: return self.operationDivision;
    }
    return NO;
}

- (BOOL)setOperation:(SettingsOperation)operation enabled:(BOOL)enabled {
    if (operation < SettingsOperationAddition || operation > SettingsOperationDivision) return NO;
    if (!enabled) {
        BOOL anotherEnabled = NO;
        for (SettingsOperation other = SettingsOperationAddition; other <= SettingsOperationDivision; other++) {
            if (other != operation && [self isOperationEnabled:other]) anotherEnabled = YES;
        }
        if (!anotherEnabled) return NO;
    }
    switch (operation) {
        case SettingsOperationAddition: self.operationAddition = enabled; break;
        case SettingsOperationSubtraction: self.operationSubtraction = enabled; break;
        case SettingsOperationMultiplication: self.operationMultiplication = enabled; break;
        case SettingsOperationDivision: self.operationDivision = enabled; break;
    }
    [self saveSettings];
    return YES;
}

@end
