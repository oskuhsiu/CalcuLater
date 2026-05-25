#import "SettingsViewController.h"
#import "DecorativeBackgroundView.h"

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SettingsManager *settingsManager;
@property (nonatomic, strong) NSArray<NSArray *> *settingsSections;
@property (nonatomic, strong) NSArray<NSString *> *sectionTitles;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"設定";
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeSettings];
    self.settingsManager = [SettingsManager sharedInstance];
    
    [self setupNavigationBar];
    [self setupTableView];
    [self setupSettingsSections];
}

- (void)setupNavigationBar {
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"完成" 
                                                                   style:UIBarButtonItemStyleDone 
                                                                  target:self 
                                                                  action:@selector(doneButtonTapped)];
    self.navigationItem.rightBarButtonItem = doneButton;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];  // 讓背景透出
    [self.view addSubview:self.tableView];
}

- (void)setupSettingsSections {
    self.sectionTitles = @[@"答題模式", @"刷題難度", @"運算類型", @"提示設定", @"其它"];

    self.settingsSections = @[
        @[@"作答方式"],
        @[@"題目範圍"],
        @[@"加法", @"減法", @"乘法", @"除法"],
        @[@"顯示答案", @"標準提示", @"分層提示", @"動畫提示"],
        @[@"音效", @"梅西老師"]
    ];
}

- (void)doneButtonTapped {
    [self.settingsManager saveSettings];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.settingsSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.settingsSections[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }

    // 讓 cell 半透明融入薰衣草背景，避免 dark mode 對比刺眼、light mode 「白塊雜燴」感。
    cell.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    cell.contentView.backgroundColor = [UIColor clearColor];

    NSString *settingTitle = self.settingsSections[indexPath.section][indexPath.row];
    cell.textLabel.text = settingTitle;
    
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.text = nil;

    if (indexPath.section == 0) {
        // 答題模式
        NSString *txt = (self.settingsManager.answerMode == AnswerModeMultipleChoice) ? @"選擇題" : @"手寫";
        cell.detailTextLabel.text = txt;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
        // Drill Tier
        NSArray *names = @[@"", @"D1（20 以內）", @"D2（100 以內）", @"D3（三位數+）", @"D4（混合）"];
        NSInteger t = self.settingsManager.drillTier;
        if (t < 1 || t > 4) t = 2;
        cell.detailTextLabel.text = names[t];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 2) {
        [self configureOperationSettingCell:cell atIndexPath:indexPath];
    } else if (indexPath.section == 3) {
        [self configureHintSettingCell:cell atIndexPath:indexPath];
    } else if (indexPath.section == 4) {
        UISwitch *t = [[UISwitch alloc] init];
        if (indexPath.row == 0) {
            t.on = self.settingsManager.soundEffectsEnabled;
            t.tag = 300;
        } else {
            t.on = self.settingsManager.mascotEnabled;
            t.tag = 301;
        }
        [t addTarget:self action:@selector(otherToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = t;
    }

    return cell;
}

- (void)otherToggled:(UISwitch *)s {
    if (s.tag == 300) self.settingsManager.soundEffectsEnabled = s.isOn;
    else if (s.tag == 301) self.settingsManager.mascotEnabled = s.isOn;
}

- (void)configureOperationSettingCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    UISwitch *toggle = [[UISwitch alloc] init];
    [toggle addTarget:self action:@selector(operationToggled:) forControlEvents:UIControlEventValueChanged];
    
    switch (indexPath.row) {
        case 0: // Addition
            toggle.on = self.settingsManager.operationAddition;
            toggle.tag = 100;
            break;
        case 1: // Subtraction
            toggle.on = self.settingsManager.operationSubtraction;
            toggle.tag = 101;
            break;
        case 2: // Multiplication
            toggle.on = self.settingsManager.operationMultiplication;
            toggle.tag = 102;
            break;
        case 3: // Division
            toggle.on = self.settingsManager.operationDivision;
            toggle.tag = 103;
            break;
    }
    
    cell.accessoryView = toggle;
}

- (void)configureHintSettingCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    UISwitch *toggle = [[UISwitch alloc] init];
    [toggle addTarget:self action:@selector(hintToggled:) forControlEvents:UIControlEventValueChanged];
    
    switch (indexPath.row) {
        case 0: // Show answer
            toggle.on = self.settingsManager.hintShowAnswer;
            toggle.tag = 200;
            break;
        case 1: // Standard hint
            toggle.on = self.settingsManager.hintStandard;
            toggle.tag = 201;
            break;
        case 2: // Multi-layer hint
            toggle.on = self.settingsManager.hintMultiLayer;
            toggle.tag = 202;
            break;
        case 3: // Animated hint
            toggle.on = self.settingsManager.hintAnimated;
            toggle.tag = 203;
            break;
    }
    
    cell.accessoryView = toggle;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        [self showAnswerModePicker];
    } else if (indexPath.section == 1) {
        [self showTierPicker];
    }
}

- (void)showAnswerModePicker {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"作答方式" message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"選擇題" style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *_) {
        self.settingsManager.answerMode = AnswerModeMultipleChoice;
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"手寫" style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *_) {
        self.settingsManager.answerMode = AnswerModeWriting;
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self _present:a];
}

- (void)showTierPicker {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"題目範圍" message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"D1（20 以內）", @"D2（100 以內）", @"D3（三位數+）", @"D4（混合）"];
    for (NSInteger i = 1; i <= 4; i++) {
        NSInteger captured = i;
        [a addAction:[UIAlertAction actionWithTitle:names[i - 1] style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *_) {
            self.settingsManager.drillTier = captured;
            [self.tableView reloadData];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self _present:a];
}

- (void)_present:(UIAlertController *)a {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Toggle Actions

- (void)operationToggled:(UISwitch *)sender {
    switch (sender.tag) {
        case 100:
            self.settingsManager.operationAddition = sender.isOn;
            break;
        case 101:
            self.settingsManager.operationSubtraction = sender.isOn;
            break;
        case 102:
            self.settingsManager.operationMultiplication = sender.isOn;
            break;
        case 103:
            self.settingsManager.operationDivision = sender.isOn;
            break;
    }
}

- (void)hintToggled:(UISwitch *)sender {
    switch (sender.tag) {
        case 200:
            self.settingsManager.hintShowAnswer = sender.isOn;
            break;
        case 201:
            self.settingsManager.hintStandard = sender.isOn;
            break;
        case 202:
            self.settingsManager.hintMultiLayer = sender.isOn;
            break;
        case 203:
            self.settingsManager.hintAnimated = sender.isOn;
            break;
    }
}

@end