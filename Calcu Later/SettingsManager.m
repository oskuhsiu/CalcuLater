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

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load problem generation settings with defaults
    self.digits1 = [defaults objectForKey:@"digits1"] ? [defaults integerForKey:@"digits1"] : 2;
    self.digits2 = [defaults objectForKey:@"digits2"] ? [defaults integerForKey:@"digits2"] : 2;
    self.allowNegativeResults = [defaults objectForKey:@"allowNegativeResults"] ? [defaults boolForKey:@"allowNegativeResults"] : NO;
    
    // Load operation settings with defaults
    self.operationAddition = [defaults objectForKey:@"operationAddition"] ? [defaults boolForKey:@"operationAddition"] : YES;
    self.operationSubtraction = [defaults objectForKey:@"operationSubtraction"] ? [defaults boolForKey:@"operationSubtraction"] : YES;
    self.operationMultiplication = [defaults objectForKey:@"operationMultiplication"] ? [defaults boolForKey:@"operationMultiplication"] : NO;
    self.operationDivision = [defaults objectForKey:@"operationDivision"] ? [defaults boolForKey:@"operationDivision"] : NO;
    
    // Load hint settings with defaults
    self.hintShowAnswer = [defaults objectForKey:@"hintShowAnswer"] ? [defaults boolForKey:@"hintShowAnswer"] : YES;
    self.hintStandard = [defaults objectForKey:@"hintStandard"] ? [defaults boolForKey:@"hintStandard"] : YES;
    self.hintMultiLayer = [defaults objectForKey:@"hintMultiLayer"] ? [defaults boolForKey:@"hintMultiLayer"] : YES;
    self.hintAnimated = [defaults objectForKey:@"hintAnimated"] ? [defaults boolForKey:@"hintAnimated"] : YES;
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Save problem generation settings
    [defaults setInteger:self.digits1 forKey:@"digits1"];
    [defaults setInteger:self.digits2 forKey:@"digits2"];
    [defaults setBool:self.allowNegativeResults forKey:@"allowNegativeResults"];
    
    // Save operation settings
    [defaults setBool:self.operationAddition forKey:@"operationAddition"];
    [defaults setBool:self.operationSubtraction forKey:@"operationSubtraction"];
    [defaults setBool:self.operationMultiplication forKey:@"operationMultiplication"];
    [defaults setBool:self.operationDivision forKey:@"operationDivision"];
    
    // Save hint settings
    [defaults setBool:self.hintShowAnswer forKey:@"hintShowAnswer"];
    [defaults setBool:self.hintStandard forKey:@"hintStandard"];
    [defaults setBool:self.hintMultiLayer forKey:@"hintMultiLayer"];
    [defaults setBool:self.hintAnimated forKey:@"hintAnimated"];
    
    [defaults synchronize];
}

@end