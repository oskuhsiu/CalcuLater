#import "SettingsViewController.h"

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
    self.view.backgroundColor = [UIColor systemBackgroundColor];
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
    [self.view addSubview:self.tableView];
}

- (void)setupSettingsSections {
    self.sectionTitles = @[@"題目設定", @"運算類型", @"提示設定"];
    
    self.settingsSections = @[
        @[@"第一個數字位數", @"第二個數字位數", @"允許負數結果"],
        @[@"加法", @"減法", @"乘法", @"除法"],
        @[@"顯示答案", @"標準提示", @"分層提示", @"動畫提示"]
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
    
    NSString *settingTitle = self.settingsSections[indexPath.section][indexPath.row];
    cell.textLabel.text = settingTitle;
    
    // Configure cell based on section and row
    if (indexPath.section == 0) { // Problem settings
        [self configureProblemSettingCell:cell atIndexPath:indexPath];
    } else if (indexPath.section == 1) { // Operation settings
        [self configureOperationSettingCell:cell atIndexPath:indexPath];
    } else if (indexPath.section == 2) { // Hint settings
        [self configureHintSettingCell:cell atIndexPath:indexPath];
    }
    
    return cell;
}

- (void)configureProblemSettingCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) { // First number digits
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)self.settingsManager.digits1];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.row == 1) { // Second number digits
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)self.settingsManager.digits2];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.row == 2) { // Allow negative results
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = self.settingsManager.allowNegativeResults;
        [toggle addTarget:self action:@selector(allowNegativeToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    }
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
    
    if (indexPath.section == 0 && (indexPath.row == 0 || indexPath.row == 1)) {
        [self showDigitPicker:indexPath.row == 0];
    }
}

- (void)showDigitPicker:(BOOL)isFirstNumber {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:isFirstNumber ? @"第一個數字位數" : @"第二個數字位數"
                                                                   message:@"選擇位數"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSInteger i = 1; i <= 5; i++) {
        NSString *title = [NSString stringWithFormat:@"%ld 位數", (long)i];
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            if (isFirstNumber) {
                self.settingsManager.digits1 = i;
            } else {
                self.settingsManager.digits2 = i;
            }
            [self.tableView reloadData];
        }];
        [alert addAction:action];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    // For iPad support
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Toggle Actions

- (void)allowNegativeToggled:(UISwitch *)sender {
    self.settingsManager.allowNegativeResults = sender.isOn;
}

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