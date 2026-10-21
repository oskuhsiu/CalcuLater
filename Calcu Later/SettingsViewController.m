#import "SettingsViewController.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"
#import "ProblemGenerator.h"

typedef NS_ENUM(NSInteger, SettingsSection) {
    SettingsSectionAnswerMode = 0,
    SettingsSectionDifficulty,
    SettingsSectionOperations,
    SettingsSectionHelp,
    SettingsSectionOther,
    SettingsSectionCount,
};

// Configure the label before UITableView measures the header/footer. Styling a
// stock footer only in willDisplay can clip large Dynamic Type text.
@interface SettingsSectionView : UITableViewHeaderFooterView
@property (nonatomic, strong) UILabel *label;
@end

@implementation SettingsSectionView
- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = UIColor.clearColor;
        _label = [[UILabel alloc] init];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_label];
        [NSLayoutConstraint activateConstraints:@[
            [_label.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_label.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_label.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_label.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        ]];
    }
    return self;
}
@end

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SettingsManager *settingsManager;
@property (nonatomic, copy) NSString *operationNotice;
@property (nonatomic, assign) NSInteger operationNoticeRow;
@end

@implementation SettingsViewController

- (instancetype)initWithSettingsManager:(SettingsManager *)settingsManager {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _settingsManager = settingsManager;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"設定";
    self.settingsManager = self.settingsManager ?: SettingsManager.sharedInstance;
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeSettings];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"完成"
        style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonTapped)];
    self.navigationItem.rightBarButtonItem.accessibilityIdentifier = @"settings.done";
    self.navigationItem.rightBarButtonItem.accessibilityHint = @"返回主畫面，變更已自動儲存";
    self.navigationController.navigationBar.tintColor = ChildUI.brownText;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100;
    self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedSectionHeaderHeight = 40;
    self.tableView.sectionFooterHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedSectionFooterHeight = 60;
    self.tableView.accessibilityIdentifier = @"settings.list";
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)doneButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Content and accessibility

- (UIFont *)scaledFontOfSize:(CGFloat)size weight:(UIFontWeight)weight style:(UIFontTextStyle)style {
    return [[UIFontMetrics metricsForTextStyle:style]
        scaledFontForFont:[ChildUI roundedFontOfSize:size weight:weight]
        compatibleWithTraitCollection:self.traitCollection];
}

- (NSArray<NSString *> *)operationNames {
    return @[@"加法", @"減法", @"乘法", @"除法"];
}

- (NSString *)operationDetailAtRow:(NSInteger)row {
    if (self.operationNotice && self.operationNoticeRow == row) return self.operationNotice;
    return @[@"練習把數量合起來", @"練習拿走或比較數量",
             @"練習相同數量的幾組", @"練習平均分，每題都能整除"][row];
}

- (NSString *)operationAccessibilityHintAtRow:(NSInteger)row {
    return self.operationNotice && self.operationNoticeRow == row
        ? self.operationNotice : @"至少保留一種運算；開關變更會立即儲存";
}

- (void)styleSectionLabel:(UILabel *)label header:(BOOL)header {
    label.textColor = ChildUI.brownText;
    label.font = [self scaledFontOfSize:header ? 19 : 17
                                weight:header ? UIFontWeightBold : UIFontWeightRegular
                                 style:header ? UIFontTextStyleHeadline : UIFontTextStyleFootnote];
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionAnswerMode: return 2;
        case SettingsSectionDifficulty: return 4;
        case SettingsSectionOperations: return 4;
        case SettingsSectionHelp: return 1;
        case SettingsSectionOther: return 2;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"答題方式", @"練一練：題目範圍", @"練一練：運算類型", @"練習小幫手", @"陪伴與音效"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionAnswerMode:
            return @"變更會自動儲存，下次進入練習時套用。「練一練」和「想一想」使用這裡的答題方式；「學一學」固定使用選擇題。";
        case SettingsSectionDifficulty:
            return @"題目範圍與運算類型只影響「練一練」。「想一想」依你選擇的年級出題。";
        case SettingsSectionOperations:
            return @"至少保留一種運算。想換一種練習？先開啟新的運算，再關閉原本的就好。";
        case SettingsSectionOther:
            return @"變更會自動儲存，不必按「完成」也不會遺失。";
        default: return nil;
    }
}

- (UIView *)sectionViewWithText:(NSString *)text header:(BOOL)header {
    if (!text.length) return nil;
    NSString *identifier = header ? @"SettingsHeader" : @"SettingsFooter";
    SettingsSectionView *view = (SettingsSectionView *)[self.tableView dequeueReusableHeaderFooterViewWithIdentifier:identifier];
    if (!view) view = [[SettingsSectionView alloc] initWithReuseIdentifier:identifier];
    view.label.text = text;
    [self styleSectionLabel:view.label header:header];
    view.label.accessibilityTraits = header ? UIAccessibilityTraitHeader : UIAccessibilityTraitStaticText;
    return view;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [self sectionViewWithText:[self tableView:tableView titleForHeaderInSection:section] header:YES];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [self sectionViewWithText:[self tableView:tableView titleForFooterInSection:section] header:NO];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SettingsCell"];
        NSLayoutConstraint *minimumHeight = [cell.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:64];
        minimumHeight.priority = UILayoutPriorityRequired - 1;
        minimumHeight.active = YES;
    }
    cell.backgroundColor = UIColor.whiteColor;
    cell.tintColor = ChildUI.brownText;
    cell.textLabel.textColor = ChildUI.brownText;
    cell.detailTextLabel.textColor = ChildUI.brownText;
    cell.textLabel.font = [self scaledFontOfSize:20 weight:UIFontWeightSemibold style:UIFontTextStyleBody];
    cell.detailTextLabel.font = [self scaledFontOfSize:17 weight:UIFontWeightRegular style:UIFontTextStyleSubheadline];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.isAccessibilityElement = NO;
    cell.detailTextLabel.isAccessibilityElement = NO;
    cell.isAccessibilityElement = YES;
    cell.accessibilityTraits = UIAccessibilityTraitButton;
    cell.accessibilityIdentifier = nil;
    cell.accessibilityLabel = nil;
    cell.accessibilityValue = nil;
    cell.accessibilityHint = nil;

    BOOL selected = NO;
    if (indexPath.section == SettingsSectionAnswerMode) {
        BOOL writing = indexPath.row == AnswerModeWriting;
        cell.textLabel.text = writing ? @"手寫草稿" : @"選擇題";
        cell.detailTextLabel.text = writing ? @"寫下計算過程，再顯示答案自行核對。不會辨識手寫，也不會自動判分。"
                                           : @"從選項中點選答案，遊戲會判斷對錯。";
        selected = self.settingsManager.answerMode == indexPath.row;
        cell.accessibilityIdentifier = [NSString stringWithFormat:@"settings.answerMode.%ld", (long)indexPath.row];
        cell.accessibilityHint = @"點兩下選擇，立即儲存";
    } else if (indexPath.section == SettingsSectionDifficulty) {
        DrillTier tier = (DrillTier)(indexPath.row + 1);
        cell.textLabel.text = [ProblemGenerator titleForTier:tier];
        cell.detailTextLabel.text = [ProblemGenerator detailForTier:tier];
        selected = self.settingsManager.drillTier == tier;
        cell.accessibilityIdentifier = [NSString stringWithFormat:@"settings.tier.%ld", (long)tier];
        cell.accessibilityHint = @"點兩下選擇，立即儲存";
    } else if (indexPath.section == SettingsSectionOperations) {
        cell.textLabel.text = [self operationNames][indexPath.row];
        cell.detailTextLabel.text = [self operationDetailAtRow:indexPath.row];
        UISwitch *toggle = [self toggleForCell:cell identifier:
            [NSString stringWithFormat:@"settings.operation.%ld", (long)indexPath.row]];
        toggle.on = [self.settingsManager isOperationEnabled:(SettingsOperation)indexPath.row];
        toggle.tag = indexPath.row;
        toggle.accessibilityLabel = [@"練一練，" stringByAppendingString:cell.textLabel.text];
        toggle.accessibilityHint = [self operationAccessibilityHintAtRow:indexPath.row];
        [toggle addTarget:self action:@selector(operationToggled:) forControlEvents:UIControlEventValueChanged];
    } else if (indexPath.section == SettingsSectionHelp) {
        cell.textLabel.text = @"需要幫忙，隨時看怎麼算";
        cell.detailTextLabel.text = @"練習時都可以按「看怎麼算」，查看這一題的做法。選擇題和手寫草稿都能使用，不需要另外開啟。";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessibilityTraits = UIAccessibilityTraitStaticText;
        cell.accessibilityIdentifier = @"settings.help";
    } else {
        BOOL sound = indexPath.row == 0;
        cell.textLabel.text = sound ? @"音效" : @"梅西老師";
        cell.detailTextLabel.text = sound ? @"答題與操作的提示音" : @"在練習畫面陪你一起學習";
        UISwitch *toggle = [self toggleForCell:cell identifier:sound ? @"settings.sound" : @"settings.mascot"];
        toggle.on = sound ? self.settingsManager.soundEffectsEnabled : self.settingsManager.mascotEnabled;
        toggle.tag = indexPath.row;
        toggle.accessibilityHint = @"變更會立即儲存";
        [toggle addTarget:self action:@selector(otherToggled:) forControlEvents:UIControlEventValueChanged];
    }
    if (selected) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.accessibilityTraits |= UIAccessibilityTraitSelected;
        cell.accessibilityValue = @"目前使用";
    }
    if (cell.isAccessibilityElement) {
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@。%@", cell.textLabel.text, cell.detailTextLabel.text];
    }
    return cell;
}

- (UISwitch *)toggleForCell:(UITableViewCell *)cell identifier:(NSString *)identifier {
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = ChildUI.calmGreen;
    toggle.accessibilityIdentifier = identifier;
    toggle.accessibilityLabel = cell.textLabel.text;
    // VoiceOver gets one named native switch, not duplicate label elements.
    // Sighted users can tap the whole 64+ point row, not only the switch thumb.
    cell.isAccessibilityElement = NO;
    cell.accessoryView = toggle;
    return toggle;
}

#pragma mark - Save each interaction

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:!UIAccessibilityIsReduceMotionEnabled()];
    if (indexPath.section == SettingsSectionAnswerMode) {
        self.settingsManager.answerMode = (AnswerMode)indexPath.row;
    } else if (indexPath.section == SettingsSectionDifficulty) {
        self.settingsManager.drillTier = indexPath.row + 1;
    } else if (indexPath.section == SettingsSectionOperations || indexPath.section == SettingsSectionOther) {
        UISwitch *toggle = (UISwitch *)[tableView cellForRowAtIndexPath:indexPath].accessoryView;
        if (![toggle isKindOfClass:UISwitch.class]) return;
        [toggle setOn:!toggle.isOn animated:!UIAccessibilityIsReduceMotionEnabled()];
        [toggle sendActionsForControlEvents:UIControlEventValueChanged];
        return;
    } else {
        return;
    }
    [self.settingsManager saveSettings];
    // Updating in place keeps VoiceOver on the option that was just activated.
    for (UITableViewCell *cell in tableView.visibleCells) {
        NSIndexPath *visiblePath = [tableView indexPathForCell:cell];
        if (!visiblePath || visiblePath.section != indexPath.section) continue;
        BOOL selected = visiblePath.row == indexPath.row;
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
        cell.accessibilityValue = selected ? @"目前使用" : nil;
    }
}

- (void)operationToggled:(UISwitch *)sender {
    SettingsOperation operation = (SettingsOperation)sender.tag;
    if (operation < SettingsOperationAddition || operation > SettingsOperationDivision) return;
    BOOL hadNotice = self.operationNotice != nil;
    BOOL accepted = [self.settingsManager setOperation:operation enabled:sender.isOn];
    if (!accepted) {
        [sender setOn:YES animated:!UIAccessibilityIsReduceMotionEnabled()];
        self.operationNotice = [NSString stringWithFormat:@"先保留「%@」陪你練習。至少需要一種運算；開啟另一種後，就可以關閉這一種。", [self operationNames][operation]];
        self.operationNoticeRow = operation;
    } else {
        self.operationNotice = nil;
    }
    // Keep the reason visible beside the choices, without a blocking alert or
    // replacing the native switch that currently has accessibility focus.
    if (hadNotice || self.operationNotice) {
        for (NSInteger row = 0; row < 4; row++) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:SettingsSectionOperations];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
            cell.detailTextLabel.text = [self operationDetailAtRow:row];
            cell.accessoryView.accessibilityHint = [self operationAccessibilityHintAtRow:row];
        }
        [UIView performWithoutAnimation:^{
            [self.tableView beginUpdates];
            [self.tableView endUpdates];
        }];
    }
    if (!accepted) UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.operationNotice);
}

- (void)otherToggled:(UISwitch *)sender {
    if (sender.tag == 0) self.settingsManager.soundEffectsEnabled = sender.isOn;
    else if (sender.tag == 1) self.settingsManager.mascotEnabled = sender.isOn;
    else return;
    [self.settingsManager saveSettings];
}

@end
