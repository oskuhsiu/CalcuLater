#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Explicit story roles, supplied by a reviewed producer rather than inferred from prose or IDs.
typedef NS_ENUM(NSInteger, GroupingStoryMeaning) {
    GroupingStoryMeaningBuildEqualGroups, // size = number1; count = number2
    GroupingStoryMeaningShareEqually,     // total = number1; recipient count = number2
    GroupingStoryMeaningMakeGroupsOf,     // total = number1; fixed size = number2
};

@interface GroupingStoryContext : NSObject <NSCopying>
@property (nonatomic, assign, readonly) GroupingStoryMeaning meaning;
/// What one counter represents, e.g. 糖果, 腿, 書 (with 頁 as its unit).
@property (nonatomic, copy, readonly) NSString *itemName;
@property (nonatomic, copy, readonly) NSString *itemUnit;
/// A countable group/recipient label, e.g. 包, 隻狗, 個小朋友. Not the answer unit.
@property (nonatomic, copy, readonly) NSString *groupName;
@property (nonatomic, copy, readonly) NSString *answerUnit;
/// Leftovers always count items, never complete groups or leftovers per recipient.
@property (nonatomic, copy, readonly) NSString *leftoverUnit;

/// Returns nil for unknown meanings or empty labels. Copies all supplied strings.
- (nullable instancetype)initWithMeaning:(GroupingStoryMeaning)meaning
                                itemName:(NSString *)itemName
                                itemUnit:(NSString *)itemUnit
                               groupName:(NSString *)groupName
                              answerUnit:(NSString *)answerUnit NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
