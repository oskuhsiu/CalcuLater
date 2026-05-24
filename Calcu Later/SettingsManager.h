#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingsManager : NSObject

@property (class, nonatomic, readonly) SettingsManager *sharedInstance;

// Problem generation settings
@property (nonatomic, assign) NSInteger digits1;
@property (nonatomic, assign) NSInteger digits2;
@property (nonatomic, assign) BOOL allowNegativeResults;

// Operation settings
@property (nonatomic, assign) BOOL operationAddition;
@property (nonatomic, assign) BOOL operationSubtraction;
@property (nonatomic, assign) BOOL operationMultiplication;
@property (nonatomic, assign) BOOL operationDivision;

// Hint settings
@property (nonatomic, assign) BOOL hintShowAnswer;
@property (nonatomic, assign) BOOL hintStandard;
@property (nonatomic, assign) BOOL hintMultiLayer;
@property (nonatomic, assign) BOOL hintAnimated;

- (void)saveSettings;
- (void)loadSettings;

@end

NS_ASSUME_NONNULL_END