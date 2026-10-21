#import <XCTest/XCTest.h>
#import "SettingsManager.h"
#import "SettingsViewController.h"
#import "ProblemGenerator.h"

@interface SettingsTests : XCTestCase
@property (nonatomic, copy) NSString *suiteName;
@property (nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation SettingsTests

- (void)setUp {
    [super setUp];
    self.suiteName = [@"SettingsTests." stringByAppendingString:NSUUID.UUID.UUIDString];
    self.defaults = [[NSUserDefaults alloc] initWithSuiteName:self.suiteName];
}

- (void)tearDown {
    [self.defaults removePersistentDomainForName:self.suiteName];
    self.defaults = nil;
    [super tearDown];
}

- (SettingsManager *)freshManager {
    return [[SettingsManager alloc] initWithUserDefaults:self.defaults];
}

- (void)testAbsentPreferencesUseSafeDefaultsWithoutWritingLegacyFlags {
    SettingsManager *settings = [self freshManager];
    XCTAssertEqual(settings.drillTier, DrillTierD2);
    XCTAssertEqual(settings.answerMode, AnswerModeMultipleChoice);
    XCTAssertTrue(settings.operationAddition);
    XCTAssertTrue(settings.operationSubtraction);
    XCTAssertFalse(settings.operationMultiplication);
    XCTAssertFalse(settings.operationDivision);
    XCTAssertNil([self.defaults objectForKey:@"hintShowAnswer"]);
}

- (void)testInvalidPersistedChoicesAreRepairedAndRepairSurvivesReload {
    for (id value in @[@(-1), @0, @5, @2.5, @"not a tier", @[], @{}]) {
        [self.defaults setObject:value forKey:@"drillTier"];
        SettingsManager *settings = [self freshManager];
        XCTAssertEqual(settings.drillTier, DrillTierD2);
        XCTAssertEqual([self.defaults integerForKey:@"drillTier"], DrillTierD2);
        [settings loadSettings];
        XCTAssertEqual(settings.drillTier, DrillTierD2);
    }
    for (id value in @[@(-1), @2, @0.5, @"not a mode", @[], @{}]) {
        [self.defaults setObject:value forKey:@"answerMode"];
        XCTAssertEqual([self freshManager].answerMode, AnswerModeMultipleChoice);
        XCTAssertEqual([self.defaults integerForKey:@"answerMode"], AnswerModeMultipleChoice);
    }
}

- (void)testValidChoicesAndNumericLaunchArgumentsArePreserved {
    for (DrillTier tier = DrillTierD1; tier <= DrillTierMixed; tier++) {
        [self.defaults setInteger:tier forKey:@"drillTier"];
        [self.defaults setInteger:AnswerModeWriting forKey:@"answerMode"];
        XCTAssertEqual([self freshManager].drillTier, tier);
        XCTAssertEqual([self freshManager].answerMode, AnswerModeWriting);
    }
    [self.defaults setObject:@"3" forKey:@"drillTier"];
    [self.defaults setObject:@"1" forKey:@"answerMode"];
    XCTAssertEqual([self freshManager].drillTier, DrillTierD3);
    XCTAssertEqual([self freshManager].answerMode, AnswerModeWriting);
}

- (void)testAllOffRepairOnlyRestoresAdditionAndPreservesOtherPreferences {
    for (NSString *key in @[@"operationAddition", @"operationSubtraction", @"operationMultiplication", @"operationDivision"]) {
        [self.defaults setBool:NO forKey:key];
    }
    NSDictionary<NSString *, NSNumber *> *preserved = @{
        @"hintShowAnswer": @NO, @"hintStandard": @YES,
        @"hintMultiLayer": @NO, @"hintAnimated": @YES,
        @"soundEffectsEnabled": @NO, @"mascotEnabled": @NO,
        @"drillTier": @(DrillTierD3), @"answerMode": @(AnswerModeWriting),
    };
    [preserved enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL *stop) {
        [self.defaults setObject:value forKey:key];
    }];
    SettingsManager *settings = [self freshManager];
    XCTAssertTrue(settings.operationAddition);
    XCTAssertFalse(settings.operationSubtraction);
    XCTAssertFalse(settings.operationMultiplication);
    XCTAssertFalse(settings.operationDivision);
    XCTAssertTrue([self.defaults boolForKey:@"operationAddition"]);
    [settings saveSettings];
    [preserved enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL *stop) {
        XCTAssertEqualObjects([self.defaults objectForKey:key], value);
    }];
}

- (void)testEachOperationCanBeTheOnlyEnabledChoiceButCannotBeTurnedOff {
    SettingsManager *settings = [self freshManager];
    for (SettingsOperation selected = SettingsOperationAddition; selected <= SettingsOperationDivision; selected++) {
        XCTAssertTrue([settings setOperation:selected enabled:YES]);
        for (SettingsOperation other = SettingsOperationAddition; other <= SettingsOperationDivision; other++) {
            if (other != selected) XCTAssertTrue([settings setOperation:other enabled:NO]);
        }
        XCTAssertFalse([settings setOperation:selected enabled:NO]);
        SettingsManager *reloaded = [self freshManager];
        for (SettingsOperation operation = SettingsOperationAddition; operation <= SettingsOperationDivision; operation++) {
            XCTAssertEqual([reloaded isOperationEnabled:operation], operation == selected);
        }
    }
    XCTAssertFalse([settings setOperation:(SettingsOperation)99 enabled:YES]);
}

- (void)testSaveNormalizesInvalidProgrammaticValuesWithoutTouchingStandardDefaults {
    NSUserDefaults *standard = NSUserDefaults.standardUserDefaults;
    NSArray<NSString *> *keys = @[@"drillTier", @"answerMode", @"operationAddition", @"soundEffectsEnabled"];
    NSMutableDictionary *before = [NSMutableDictionary dictionary];
    for (NSString *key in keys) before[key] = [standard objectForKey:key] ?: NSNull.null;
    SettingsManager *settings = [self freshManager];
    settings.drillTier = 99;
    settings.answerMode = (AnswerMode)-1;
    settings.operationAddition = NO;
    settings.operationSubtraction = NO;
    settings.operationMultiplication = NO;
    settings.operationDivision = NO;
    settings.soundEffectsEnabled = NO;
    [settings saveSettings];
    SettingsManager *reloaded = [self freshManager];
    XCTAssertEqual(reloaded.drillTier, DrillTierD2);
    XCTAssertEqual(reloaded.answerMode, AnswerModeMultipleChoice);
    XCTAssertTrue(reloaded.operationAddition);
    XCTAssertFalse(reloaded.soundEffectsEnabled);
    for (NSString *key in keys) XCTAssertEqualObjects([standard objectForKey:key] ?: NSNull.null, before[key]);
}

- (void)testTwoInjectedSuitesReadAndSaveIndependently {
    NSString *otherSuite = [self.suiteName stringByAppendingString:@".other"];
    NSUserDefaults *otherDefaults = [[NSUserDefaults alloc] initWithSuiteName:otherSuite];
    @try {
        [self.defaults setInteger:DrillTierD3 forKey:@"drillTier"];
        [self.defaults setInteger:AnswerModeWriting forKey:@"answerMode"];
        [otherDefaults setInteger:DrillTierD1 forKey:@"drillTier"];
        [otherDefaults setInteger:AnswerModeMultipleChoice forKey:@"answerMode"];
        SettingsManager *first = [self freshManager];
        SettingsManager *second = [[SettingsManager alloc] initWithUserDefaults:otherDefaults];
        XCTAssertEqual(first.drillTier, DrillTierD3);
        XCTAssertEqual(first.answerMode, AnswerModeWriting);
        XCTAssertEqual(second.drillTier, DrillTierD1);
        XCTAssertEqual(second.answerMode, AnswerModeMultipleChoice);
        first.drillTier = DrillTierMixed;
        [first saveSettings];
        [second loadSettings];
        XCTAssertEqual(second.drillTier, DrillTierD1);
        XCTAssertEqual(second.answerMode, AnswerModeMultipleChoice);
        second.drillTier = DrillTierD2;
        [second saveSettings];
        [first loadSettings];
        XCTAssertEqual(first.drillTier, DrillTierMixed);
        XCTAssertEqual(first.answerMode, AnswerModeWriting);
    } @finally {
        [otherDefaults removePersistentDomainForName:otherSuite];
    }
}

- (UITableView *)tableForController:(SettingsViewController *)controller {
    [controller loadViewIfNeeded];
    controller.view.frame = CGRectMake(0, 0, 390, 844);
    [controller.view layoutIfNeeded];
    for (UIView *view in controller.view.subviews) {
        if ([view isKindOfClass:UITableView.class]) return (UITableView *)view;
    }
    XCTFail(@"Settings should present its choices in an accessible scrolling table.");
    return nil;
}

- (UITableViewCell *)cellInTable:(UITableView *)table section:(NSInteger)section row:(NSInteger)row {
    return [table.dataSource tableView:table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
}

- (UILabel *)label:(NSString *)identifier inView:(UIView *)view {
    if ([view isKindOfClass:UILabel.class] && [view.accessibilityIdentifier isEqualToString:identifier]) return (UILabel *)view;
    for (UIView *child in view.subviews) {
        UILabel *match = [self label:identifier inView:child];
        if (match) return match;
    }
    return nil;
}
- (UILabel *)titleInCell:(UITableViewCell *)cell { return [self label:@"settings.row.title" inView:cell.contentView]; }
- (UILabel *)detailInCell:(UITableViewCell *)cell { return [self label:@"settings.row.detail" inView:cell.contentView]; }

- (void)testAnswerModeAndDifficultyPersistBeforeSheetDismissal {
    SettingsViewController *controller = [[SettingsViewController alloc] initWithSettingsManager:[self freshManager]];
    UITableView *table = [self tableForController:controller];
    [table.delegate tableView:table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:AnswerModeWriting inSection:0]];
    XCTAssertEqual([self freshManager].answerMode, AnswerModeWriting);
    XCTAssertEqual([self cellInTable:table section:0 row:1].accessoryType, UITableViewCellAccessoryCheckmark);
    XCTAssertTrue([[self detailInCell:[self cellInTable:table section:0 row:1]].text containsString:@"不會辨識手寫"]);
    for (DrillTier tier = DrillTierD1; tier <= DrillTierMixed; tier++) {
        [table.delegate tableView:table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:tier - 1 inSection:1]];
        XCTAssertEqual([self freshManager].drillTier, tier);
        UITableViewCell *cell = [self cellInTable:table section:1 row:tier - 1];
        XCTAssertEqualObjects([self titleInCell:cell].text, [ProblemGenerator titleForTier:tier]);
        XCTAssertEqualObjects([self detailInCell:cell].text, [ProblemGenerator detailForTier:tier]);
        XCTAssertEqual(cell.accessoryType, UITableViewCellAccessoryCheckmark);
    }
    UITableViewCell *help = [self cellInTable:table section:3 row:0];
    XCTAssertNil(help.accessoryView);
    XCTAssertEqual(help.selectionStyle, UITableViewCellSelectionStyleNone);
    XCTAssertTrue([[self detailInCell:help].text containsString:@"不需要另外開啟"]);
}

- (void)testSwitchesSaveImmediatelyAndLastOperationExplainsRejection {
    SettingsManager *settings = [self freshManager];
    XCTAssertTrue([settings setOperation:SettingsOperationSubtraction enabled:NO]);
    SettingsViewController *controller = [[SettingsViewController alloc] initWithSettingsManager:settings];
    UITableView *table = [self tableForController:controller];
    UISwitch *addition = (UISwitch *)[self cellInTable:table section:2 row:0].accessoryView;
    XCTAssertEqualObjects(addition.accessibilityLabel, @"練一練，加法");
    addition.on = NO;
    [addition sendActionsForControlEvents:UIControlEventValueChanged];
    XCTAssertTrue(addition.isOn);
    XCTAssertTrue([self freshManager].operationAddition);
    XCTAssertTrue([[self detailInCell:[self cellInTable:table section:2 row:0]].text containsString:@"至少需要一種運算"]);
    UISwitch *multiplication = (UISwitch *)[self cellInTable:table section:2 row:2].accessoryView;
    multiplication.on = YES;
    [multiplication sendActionsForControlEvents:UIControlEventValueChanged];
    XCTAssertTrue([self freshManager].operationMultiplication);
    XCTAssertFalse([[self detailInCell:[self cellInTable:table section:2 row:0]].text containsString:@"至少需要一種運算"]);
    for (NSInteger row = 0; row < 2; row++) {
        UISwitch *toggle = (UISwitch *)[self cellInTable:table section:4 row:row].accessoryView;
        toggle.on = NO;
        [toggle sendActionsForControlEvents:UIControlEventValueChanged];
    }
    XCTAssertFalse([self freshManager].soundEffectsEnabled);
    XCTAssertFalse([self freshManager].mascotEnabled);
}

- (NSUInteger)labelsContainingText:(NSString *)text inView:(UIView *)view {
    NSUInteger count = [view isKindOfClass:UILabel.class] && [((UILabel *)view).text isEqualToString:text] ? 1 : 0;
    for (UIView *child in view.subviews) count += [self labelsContainingText:text inView:child];
    return count;
}

- (void)testCustomSectionsUseOneTextSourceRatherThanPopulatingStockLabelsToo {
    SettingsViewController *controller = [[SettingsViewController alloc] initWithSettingsManager:[self freshManager]];
    UITableView *table = [self tableForController:controller];
    XCTAssertFalse([table.dataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)]);
    XCTAssertFalse([table.dataSource respondsToSelector:@selector(tableView:titleForFooterInSection:)]);
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)[table.delegate tableView:table viewForHeaderInSection:0];
    XCTAssertEqual([self labelsContainingText:@"答題方式" inView:header], 1u);
    UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)[table.delegate tableView:table viewForFooterInSection:4];
    XCTAssertEqual([self labelsContainingText:@"變更會自動儲存，不必按「完成」也不會遺失。" inView:footer], 1u);
    XCTAssertEqual(table.sectionHeaderHeight, UITableViewAutomaticDimension);
    XCTAssertEqual(table.sectionFooterHeight, UITableViewAutomaticDimension);
}

- (void)testLongSettingsRowsFitTheirWholeTextChainAtNarrowAndLargeTypeSizes {
    SettingsViewController *controller = [[SettingsViewController alloc] initWithSettingsManager:[self freshManager]];
    UITableView *table = [self tableForController:controller];
    // Component sizing check only. The UI matrix separately sets real system
    // Dynamic Type and inspects the table's actual on-screen rows.
    for (NSNumber *pointSize in @[@20, @64]) {
        UITableViewCell *cell = [self cellInTable:table section:1 row:2];
        UILabel *title = [self titleInCell:cell];
        UILabel *detail = [self detailInCell:cell];
        XCTAssertNotNil(title);
        XCTAssertNotNil(detail);
        title.font = [UIFont systemFontOfSize:pointSize.doubleValue];
        detail.font = [UIFont systemFontOfSize:pointSize.doubleValue * 0.85];
        for (NSNumber *width in @[@260, @353]) {
            cell.contentView.bounds = CGRectMake(0, 0, width.doubleValue, 1000);
            [cell.contentView setNeedsLayout];
            [cell.contentView layoutIfNeeded];
            CGSize fitted = [cell.contentView systemLayoutSizeFittingSize:CGSizeMake(width.doubleValue, 0)
                withHorizontalFittingPriority:UILayoutPriorityRequired
                verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
            CGFloat textWidth = width.doubleValue - 40;
            CGFloat fullTextHeight = [title sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)].height
                + [detail sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)].height;
            XCTAssertGreaterThan(fitted.height, 64.0);
            XCTAssertGreaterThanOrEqual(fitted.height + 1, fullTextHeight + 34);
            XCTAssertFalse(title.translatesAutoresizingMaskIntoConstraints);
            XCTAssertFalse(detail.translatesAutoresizingMaskIntoConstraints);
        }
    }
}

@end
