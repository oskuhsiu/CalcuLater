#import "MultiplicationTableViewController.h"
#import "ChildUIKit.h"
#import "Lesson.h"
#import "LessonViewController.h"
#import "LessonProgressStore.h"
#import "DecorativeBackgroundView.h"
#import "SpeechManager.h"

@interface MultiplicationTableViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@end

@implementation MultiplicationTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeMultiplication];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    close.tintColor = ChildUI.brownText;
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"九九乘法表";
    title.font = [ChildUI roundedFontOfSize:24.0 weight:UIFontWeightBold];
    title.textColor = ChildUI.brownText;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scroll];

    [NSLayoutConstraint activateConstraints:@[
        [close.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [close.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [close.widthAnchor constraintEqualToConstant:36],
        [close.heightAnchor constraintEqualToConstant:36],

        [title.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14],
        [title.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

        [self.scroll.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:16],
        [self.scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];

    [self buildTable];
}

- (void)buildTable {
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:self.scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:self.scroll.widthAnchor],
    ]];

    NSArray<Lesson *> *factors = [LessonCatalog multiplicationLessons];
    UIView *prev = nil;
    for (Lesson *l in factors) {
        UIView *section = [self sectionForLesson:l];
        section.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:section];

        [NSLayoutConstraint activateConstraints:@[
            [section.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
            [section.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        ]];
        if (prev) {
            [section.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:14].active = YES;
        } else {
            [section.topAnchor constraintEqualToAnchor:content.topAnchor constant:8].active = YES;
        }
        prev = section;
    }
    if (prev) {
        [prev.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24].active = YES;
    }
}

- (UIView *)sectionForLesson:(Lesson *)lesson {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = ChildUI.creamBackground;
    card.layer.cornerRadius = 20.0;
    [ChildUI applySoftShadowOnLayer:card.layer];

    UILabel *header = [[UILabel alloc] init];
    header.text = lesson.title;
    header.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightBold];
    header.textColor = ChildUI.brownText;
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:header];

    NSInteger stars = [[LessonProgressStore sharedInstance] starsForLessonID:lesson.lessonID];
    NSMutableString *str = [NSMutableString string];
    for (NSInteger i = 0; i < 3; i++) [str appendString:i < stars ? @"★" : @"☆"];
    UILabel *starLabel = [[UILabel alloc] init];
    starLabel.text = str;
    starLabel.font = [ChildUI roundedFontOfSize:18.0 weight:UIFontWeightMedium];
    starLabel.textColor = ChildUI.eggYolk;
    starLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:starLabel];

    // 1..9 的乘式列表（可點：點按播放口訣）
    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 4;
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:rows];
    for (NSInteger n = 1; n <= 9; n++) {
        NSInteger a = lesson.multiplicationFactor;
        NSInteger b = n;
        NSInteger ans = a * b;

        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        NSString *txt = [NSString stringWithFormat:@"%ld × %ld = %ld  🔊",
                         (long)a, (long)b, (long)ans];
        [row setTitle:txt forState:UIControlStateNormal];
        row.titleLabel.font = [ChildUI roundedMonoFontOfSize:22.0 weight:UIFontWeightMedium];
        [row setTitleColor:ChildUI.brownText forState:UIControlStateNormal];
        row.tag = a * 100 + b;
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        row.accessibilityLabel = [NSString stringWithFormat:@"%ld 乘 %ld 等於 %ld，點按朗讀",
                                  (long)a, (long)b, (long)ans];
        [rows addArrangedSubview:row];
    }

    ChildButton *practice = [ChildButton buttonWithTitle:@"練習這一段"
                                          backgroundColor:ChildUI.pinkAccent];
    practice.translatesAutoresizingMaskIntoConstraints = NO;
    practice.tag = lesson.multiplicationFactor;
    [practice addTarget:self action:@selector(practiceTapped:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:practice];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [starLabel.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [starLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [rows.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:10],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [practice.topAnchor constraintEqualToAnchor:rows.bottomAnchor constant:12],
        [practice.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [practice.widthAnchor constraintEqualToConstant:200],
        [practice.heightAnchor constraintEqualToConstant:52],
        [practice.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
    ]];

    return card;
}

- (void)rowTapped:(UIButton *)btn {
    NSInteger a = btn.tag / 100;
    NSInteger b = btn.tag % 100;
    if (a < 1 || a > 9 || b < 1 || b > 9) return;
    NSString *chant = [self chantForA:a b:b];
    [[SpeechManager sharedInstance] speak:chant];

    // 點按視覺回饋
    UIView *snap = btn;
    [UIView animateWithDuration:0.10 animations:^{ snap.transform = CGAffineTransformMakeScale(0.96, 0.96); }];
    [UIView animateWithDuration:0.25 delay:0.10 usingSpringWithDamping:0.5 initialSpringVelocity:0.4
                        options:0 animations:^{ snap.transform = CGAffineTransformIdentity; } completion:nil];
}

// 九九乘法口訣（Taiwan 國小慣用）：
//  • ans < 10  → 「a b 得 ans」  例：二三得六
//  • ans = 10  → 「a b 一十」    例：二五一十
//  • ans > 10  → 「a b ans」     例：三五十五、七八五十六
- (NSString *)chantForA:(NSInteger)a b:(NSInteger)b {
    NSInteger ans = a * b;
    NSString *aC = [self chineseNumber:a];
    NSString *bC = [self chineseNumber:b];
    NSString *ansC = [self chineseNumber:ans];
    if (ans < 10) {
        return [NSString stringWithFormat:@"%@ %@ 得 %@", aC, bC, ansC];
    }
    return [NSString stringWithFormat:@"%@ %@ %@", aC, bC, ansC];
}

- (NSString *)chineseNumber:(NSInteger)n {
    NSArray *d = @[@"零", @"一", @"二", @"三", @"四", @"五", @"六", @"七", @"八", @"九"];
    if (n >= 0 && n <= 9) return d[n];
    if (n == 10) return @"一十";  // 口訣慣例（二五一十）
    if (n < 20) return [NSString stringWithFormat:@"十%@", d[n - 10]];
    NSString *tens = d[n / 10];
    NSInteger ones = n % 10;
    if (ones == 0) return [NSString stringWithFormat:@"%@十", tens];
    return [NSString stringWithFormat:@"%@十%@", tens, d[ones]];
}

- (void)practiceTapped:(UIButton *)btn {
    NSInteger factor = btn.tag;
    if (factor < 1 || factor > 9) return;
    NSArray *all = [LessonCatalog multiplicationLessons];
    LessonViewController *vc = [[LessonViewController alloc] initWithLesson:all[factor - 1]];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)closeTapped {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
