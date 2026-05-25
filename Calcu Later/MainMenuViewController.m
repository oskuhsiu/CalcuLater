#import "MainMenuViewController.h"
#import "ChildUIKit.h"
#import "LessonsHomeViewController.h"
#import "ViewController.h"
#import "MascotView.h"
#import "DecorativeBackgroundView.h"
#import "SettingsViewController.h"
#import "WordProblemHomeViewController.h"

@interface MainMenuViewController ()
@property (nonatomic, strong) MascotView *mascotView;
@property (nonatomic, strong) UIButton *settingsButton;
@end

@implementation MainMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeMainMenu];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    // settings 按鈕固定在 self.view 右上（不進 scrollView，避免 scroll 時跑掉）
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.settingsButton setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
    self.settingsButton.tintColor = ChildUI.brownText;
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton addTarget:self action:@selector(settingsTapped) forControlEvents:UIControlEventTouchUpInside];
    self.settingsButton.accessibilityLabel = @"設定";
    [self.view addSubview:self.settingsButton];

    // 用 UIScrollView 包主要內容，iPhone SE 等小螢幕能滾，大螢幕仍以 contentView 撐起。
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Calcu Later";
    title.font = [ChildUI roundedFontOfSize:42.0 weight:UIFontWeightBold];
    title.textColor = ChildUI.brownText;
    title.textAlignment = NSTextAlignmentCenter;
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.7;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"我是梅西老師，今天想做什麼？";
    subtitle.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightMedium];
    subtitle.textColor = [ChildUI.brownText colorWithAlphaComponent:0.7];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.adjustsFontSizeToFitWidth = YES;
    subtitle.minimumScaleFactor = 0.7;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:subtitle];

    self.mascotView = [[MascotView alloc] initWithVariant:MascotVariantDesk];
    self.mascotView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.mascotView];

    UIView *lessonCard = [self largeCardWithTitle:@"📘 學一學"
                                          subtitle:@"加減 / 九九乘法"
                                       background:ChildUI.mintGreen
                                            action:@selector(lessonsTapped)];
    UIView *drillCard = [self largeCardWithTitle:@"✏️ 練一練"
                                         subtitle:@"進位 / 退位 / 直式"
                                      background:ChildUI.pumpkinOrange
                                           action:@selector(drillsTapped)];
    UIView *wordCard = [self largeCardWithTitle:@"📝 想一想"
                                        subtitle:@"應用題（1~3 年級）"
                                     background:ChildUI.lavender
                                          action:@selector(wordProblemsTapped)];
    lessonCard.translatesAutoresizingMaskIntoConstraints = NO;
    drillCard.translatesAutoresizingMaskIntoConstraints = NO;
    wordCard.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:lessonCard];
    [contentView addSubview:drillCard];
    [contentView addSubview:wordCard];

    UILayoutGuide *contentGuide = scrollView.contentLayoutGuide;
    UILayoutGuide *frameGuide = scrollView.frameLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.settingsButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.settingsButton.widthAnchor constraintEqualToConstant:40],
        [self.settingsButton.heightAnchor constraintEqualToConstant:40],

        [scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        // 寬度跟著 scrollView 的可視寬度走，不能讓 contentView 橫向滾。
        [contentView.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor],

        [title.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:24],
        [title.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        // 避免 title 撞到 settingsButton：取 trailing-(settingsButton 寬度 + gap) 為上限。
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:64],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:-64],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [subtitle.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [subtitle.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:24],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:-24],

        [self.mascotView.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:12],
        [self.mascotView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.mascotView.widthAnchor constraintEqualToConstant:130],
        [self.mascotView.heightAnchor constraintEqualToConstant:130],

        [lessonCard.topAnchor constraintEqualToAnchor:self.mascotView.bottomAnchor constant:16],
        [lessonCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24],
        [lessonCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24],
        [lessonCard.heightAnchor constraintEqualToConstant:112],

        [drillCard.topAnchor constraintEqualToAnchor:lessonCard.bottomAnchor constant:14],
        [drillCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24],
        [drillCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24],
        [drillCard.heightAnchor constraintEqualToConstant:112],

        [wordCard.topAnchor constraintEqualToAnchor:drillCard.bottomAnchor constant:14],
        [wordCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24],
        [wordCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24],
        [wordCard.heightAnchor constraintEqualToConstant:112],

        // contentView 的 bottom 由最後一張卡 + 一點 padding 決定。
        [wordCard.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24],
    ]];

    // idle 浮動由 MascotView 自帶
}

- (UIView *)largeCardWithTitle:(NSString *)title subtitle:(NSString *)subtitle
                     background:(UIColor *)bg action:(SEL)action {
    UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
    card.backgroundColor = bg;
    card.layer.cornerRadius = 28.0;
    [ChildUI applySoftShadowOnLayer:card.layer];
    [card addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [card addTarget:self action:@selector(_press:) forControlEvents:UIControlEventTouchDown];
    [card addTarget:self action:@selector(_release:)
   forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [ChildUI roundedFontOfSize:28.0 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.text = subtitle;
    subLabel.font = [ChildUI roundedFontOfSize:17.0 weight:UIFontWeightMedium];
    subLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:subLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:22],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-16],
        [subLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        [subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-16],
    ]];
    return card;
}

- (void)_press:(UIButton *)b {
    [UIView animateWithDuration:0.10 animations:^{ b.transform = CGAffineTransformMakeScale(0.96, 0.96); }];
}
- (void)_release:(UIButton *)b {
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5
                        options:0 animations:^{ b.transform = CGAffineTransformIdentity; } completion:nil];
}

- (void)lessonsTapped {
    LessonsHomeViewController *vc = [[LessonsHomeViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark.circle.fill"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(dismissPresented)];
    vc.navigationItem.leftBarButtonItem = close;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissPresented {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)drillsTapped {
    ViewController *vc = [[ViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)wordProblemsTapped {
    WordProblemHomeViewController *vc = [[WordProblemHomeViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark.circle.fill"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(dismissPresented)];
    vc.navigationItem.leftBarButtonItem = close;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)settingsTapped {
    SettingsViewController *vc = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

@end
