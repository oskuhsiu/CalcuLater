#import "WordProblemHomeViewController.h"
#import "WordProblemViewController.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"

@interface WordProblemHomeViewController ()
@end

@implementation WordProblemHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeLessons];
    self.title = @"想一想";
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSFontAttributeName: [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: ChildUI.brownText
    };
    [self setupUI];
}

- (void)setupUI {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    UILabel *intro = [[UILabel alloc] init];
    intro.text = @"選一個年級，就會有好多應用題等你！";
    intro.font = [ChildUI roundedFontOfSize:20.0 weight:UIFontWeightMedium];
    intro.textColor = [ChildUI.brownText colorWithAlphaComponent:0.8];
    intro.textAlignment = NSTextAlignmentCenter;
    intro.numberOfLines = 0;
    intro.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:intro];

    // 三張年級卡（直向）
    UIView *card1 = [self cardForGrade:1
                                 title:@"1 年級"
                              subtitle:@"20 以內 加 / 減 故事題"
                                 color:ChildUI.mintGreen];
    UIView *card2 = [self cardForGrade:2
                                 title:@"2 年級"
                              subtitle:@"100 以內 加減 + 九九乘法"
                                 color:ChildUI.pumpkinOrange];
    UIView *card3 = [self cardForGrade:3
                                 title:@"3 年級"
                              subtitle:@"大數加減 + 乘 / 除"
                                 color:ChildUI.lavender];

    [self.view addSubview:card1];
    [self.view addSubview:card2];
    [self.view addSubview:card3];

    [NSLayoutConstraint activateConstraints:@[
        [intro.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [intro.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [intro.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],

        [card1.topAnchor constraintEqualToAnchor:intro.bottomAnchor constant:24],
        [card1.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [card1.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [card1.heightAnchor constraintEqualToConstant:120],

        [card2.topAnchor constraintEqualToAnchor:card1.bottomAnchor constant:20],
        [card2.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [card2.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [card2.heightAnchor constraintEqualToConstant:120],

        [card3.topAnchor constraintEqualToAnchor:card2.bottomAnchor constant:20],
        [card3.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [card3.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [card3.heightAnchor constraintEqualToConstant:120],
    ]];
}

- (UIView *)cardForGrade:(NSInteger)grade
                   title:(NSString *)title
                subtitle:(NSString *)subtitle
                   color:(UIColor *)color {
    UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
    card.backgroundColor = color;
    card.layer.cornerRadius = 24.0;
    card.tag = grade;
    card.accessibilityIdentifier = [NSString stringWithFormat:@"stories.grade.%ld", (long)grade];
    card.accessibilityLabel = title;
    card.accessibilityHint = subtitle;
    [ChildUI applySoftShadowOnLayer:card.layer];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [card addTarget:self action:@selector(gradeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [card addTarget:self action:@selector(pressDown:) forControlEvents:UIControlEventTouchDown];
    [card addTarget:self action:@selector(pressUp:)
   forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [ChildUI roundedFontOfSize:30.0 weight:UIFontWeightBold];
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
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:24],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-24],
        [subLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-24],
        [subLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
    ]];
    return card;
}

- (void)pressDown:(UIButton *)b {
    [UIView animateWithDuration:0.10 animations:^{ b.transform = CGAffineTransformMakeScale(0.96, 0.96); }];
}

- (void)pressUp:(UIButton *)b {
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.5
                        options:0 animations:^{ b.transform = CGAffineTransformIdentity; } completion:nil];
}

- (void)gradeTapped:(UIButton *)sender {
    WordProblemViewController *vc = [[WordProblemViewController alloc] initWithGrade:sender.tag];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
}

@end
