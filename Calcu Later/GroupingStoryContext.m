#import "GroupingStoryContext.h"

@implementation GroupingStoryContext

- (nullable instancetype)initWithMeaning:(GroupingStoryMeaning)meaning
                                itemName:(NSString *)itemName
                                itemUnit:(NSString *)itemUnit
                               groupName:(NSString *)groupName
                              answerUnit:(NSString *)answerUnit {
    if (meaning != GroupingStoryMeaningBuildEqualGroups &&
        meaning != GroupingStoryMeaningShareEqually &&
        meaning != GroupingStoryMeaningMakeGroupsOf) return nil;
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    if ([itemName stringByTrimmingCharactersInSet:whitespace].length == 0 ||
        [itemUnit stringByTrimmingCharactersInSet:whitespace].length == 0 ||
        [groupName stringByTrimmingCharactersInSet:whitespace].length == 0 ||
        [answerUnit stringByTrimmingCharactersInSet:whitespace].length == 0) return nil;
    self = [super init];
    if (self) {
        _meaning = meaning;
        _itemName = [itemName copy];
        _itemUnit = [itemUnit copy];
        _groupName = [groupName copy];
        _answerUnit = [answerUnit copy];
    }
    return self;
}

- (NSString *)leftoverUnit {
    return self.itemUnit;
}

- (id)copyWithZone:(NSZone *)zone {
    // A fresh base-class snapshot also prevents a mutable subclass from escaping into a lesson.
    return [[GroupingStoryContext allocWithZone:zone] initWithMeaning:self.meaning
                                                            itemName:self.itemName
                                                            itemUnit:self.itemUnit
                                                           groupName:self.groupName
                                                          answerUnit:self.answerUnit];
}

@end
