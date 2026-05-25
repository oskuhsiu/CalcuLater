#import "SettingsManager.h"

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
    self = [super init];
    if (self) {
        [self loadSettings];
    }
    return self;
}

- (id)_objOrDefault:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)loadSettings {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

    self.digits1 = [self _objOrDefault:@"digits1"] ? [d integerForKey:@"digits1"] : 2;
    self.digits2 = [self _objOrDefault:@"digits2"] ? [d integerForKey:@"digits2"] : 2;
    self.allowNegativeResults = [self _objOrDefault:@"allowNegativeResults"] ? [d boolForKey:@"allowNegativeResults"] : NO;

    self.drillTier = [self _objOrDefault:@"drillTier"] ? [d integerForKey:@"drillTier"] : 2;

    self.operationAddition = [self _objOrDefault:@"operationAddition"] ? [d boolForKey:@"operationAddition"] : YES;
    self.operationSubtraction = [self _objOrDefault:@"operationSubtraction"] ? [d boolForKey:@"operationSubtraction"] : YES;
    self.operationMultiplication = [self _objOrDefault:@"operationMultiplication"] ? [d boolForKey:@"operationMultiplication"] : NO;
    self.operationDivision = [self _objOrDefault:@"operationDivision"] ? [d boolForKey:@"operationDivision"] : NO;

    self.hintShowAnswer = [self _objOrDefault:@"hintShowAnswer"] ? [d boolForKey:@"hintShowAnswer"] : YES;
    self.hintStandard = [self _objOrDefault:@"hintStandard"] ? [d boolForKey:@"hintStandard"] : YES;
    self.hintMultiLayer = [self _objOrDefault:@"hintMultiLayer"] ? [d boolForKey:@"hintMultiLayer"] : YES;
    self.hintAnimated = [self _objOrDefault:@"hintAnimated"] ? [d boolForKey:@"hintAnimated"] : YES;

    self.answerMode = [self _objOrDefault:@"answerMode"] ? (AnswerMode)[d integerForKey:@"answerMode"] : AnswerModeMultipleChoice;
    self.soundEffectsEnabled = [self _objOrDefault:@"soundEffectsEnabled"] ? [d boolForKey:@"soundEffectsEnabled"] : YES;
    self.mascotEnabled = [self _objOrDefault:@"mascotEnabled"] ? [d boolForKey:@"mascotEnabled"] : YES;
}

- (void)saveSettings {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

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

    [d synchronize];
}

@end
