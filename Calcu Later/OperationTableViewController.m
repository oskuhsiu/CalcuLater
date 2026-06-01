#import "OperationTableViewController.h"
#import "ChildUIKit.h"
#import "SpeechManager.h"
#import "DecorativeBackgroundView.h"

@interface OperationTableViewController ()
@property (nonatomic, assign) OperationTableKind kind;
@property (nonatomic, strong) UIScrollView *scroll;
@end

@implementation OperationTableViewController

- (instancetype)initWithKind:(OperationTableKind)kind {
    self = [super initWithNibName:nil bundle:nil];
    if (self) { _kind = kind; }
    return self;
}

- (BOOL)isAddition { return self.kind == OperationTableKindAddition; }

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeLessons];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    close.tintColor = ChildUI.brownText;
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *title = [[UILabel alloc] init];
    title.text = self.isAddition ? @"加法表" : @"減法表";
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

    UIView *prev = nil;
    for (NSInteger a = 1; a <= 9; a++) {
        UIView *section = [self sectionForBase:a];
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

/// base = 加法的被加數 / 減法的減數（1..9）。
- (UIView *)sectionForBase:(NSInteger)base {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = ChildUI.creamBackground;
    card.layer.cornerRadius = 20.0;
    [ChildUI applySoftShadowOnLayer:card.layer];

    UILabel *header = [[UILabel alloc] init];
    header.text = self.isAddition
        ? [NSString stringWithFormat:@"%ld 的加法", (long)base]
        : [NSString stringWithFormat:@"減 %ld", (long)base];
    header.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightBold];
    header.textColor = ChildUI.brownText;
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:header];

    // 「唸整段」：一次把整段（一串）讀完。
    ChildButton *chantAll = [ChildButton buttonWithTitle:@"🔊 唸整段"
                                         backgroundColor:ChildUI.skyBlue];
    chantAll.titleLabel.font = [ChildUI roundedFontOfSize:16.0 weight:UIFontWeightSemibold];
    chantAll.translatesAutoresizingMaskIntoConstraints = NO;
    chantAll.tag = base;
    chantAll.accessibilityLabel = [NSString stringWithFormat:@"%@，整段朗讀", header.text];
    [chantAll addTarget:self action:@selector(chantSectionTapped:) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:chantAll];

    // 各列算式（可單獨點按朗讀）
    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 4;
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:rows];
    for (NSInteger n = 1; n <= 9; n++) {
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        NSString *txt = [NSString stringWithFormat:@"%@  🔊", [self displayForBase:base index:n]];
        [row setTitle:txt forState:UIControlStateNormal];
        row.titleLabel.font = [ChildUI roundedMonoFontOfSize:22.0 weight:UIFontWeightMedium];
        [row setTitleColor:ChildUI.brownText forState:UIControlStateNormal];
        row.tag = base * 100 + n;
        row.accessibilityLabel = [NSString stringWithFormat:@"%@，點按朗讀",
                                  [self spokenForBase:base index:n]];
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [rows addArrangedSubview:row];
    }

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],

        [chantAll.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [chantAll.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [chantAll.leadingAnchor constraintGreaterThanOrEqualToAnchor:header.trailingAnchor constant:10],
        [chantAll.heightAnchor constraintEqualToConstant:40],
        [chantAll.widthAnchor constraintEqualToConstant:120],

        [rows.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:10],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [rows.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
    ]];

    return card;
}

#pragma mark - Formatting

/// 顯示用算式（橫式），減法用 U+2212 較粗的減號。
- (NSString *)displayForBase:(NSInteger)base index:(NSInteger)n {
    if (self.isAddition) {
        return [NSString stringWithFormat:@"%ld + %ld = %ld", (long)base, (long)n, (long)(base + n)];
    }
    NSInteger minuend = base + n;  // 被減數
    return [NSString stringWithFormat:@"%ld − %ld = %ld", (long)minuend, (long)base, (long)n];
}

/// 朗讀用字串（中文唸法）。zh 嗓音可正確把阿拉伯數字讀成國語。
- (NSString *)spokenForBase:(NSInteger)base index:(NSInteger)n {
    if (self.isAddition) {
        return [NSString stringWithFormat:@"%ld 加 %ld 等於 %ld", (long)base, (long)n, (long)(base + n)];
    }
    NSInteger minuend = base + n;
    return [NSString stringWithFormat:@"%ld 減 %ld 等於 %ld", (long)minuend, (long)base, (long)n];
}

#pragma mark - Speech

- (void)rowTapped:(UIButton *)btn {
    NSInteger base = btn.tag / 100;
    NSInteger n = btn.tag % 100;
    if (base < 1 || base > 9 || n < 1 || n > 9) return;
    [[SpeechManager sharedInstance] speak:[self spokenForBase:base index:n]];
    [self bounce:btn];
}

/// 一次唸整段：把該段 9 列接成「一串」，用「，」分隔讓嗓音自然停頓。
- (void)chantSectionTapped:(UIButton *)btn {
    NSInteger base = btn.tag;
    if (base < 1 || base > 9) return;
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSInteger n = 1; n <= 9; n++) {
        [parts addObject:[self spokenForBase:base index:n]];
    }
    [[SpeechManager sharedInstance] speak:[parts componentsJoinedByString:@"，"]];
    [self bounce:btn];
}

- (void)bounce:(UIView *)v {
    [UIView animateWithDuration:0.10 animations:^{ v.transform = CGAffineTransformMakeScale(0.96, 0.96); }];
    [UIView animateWithDuration:0.25 delay:0.10 usingSpringWithDamping:0.5 initialSpringVelocity:0.4
                        options:0 animations:^{ v.transform = CGAffineTransformIdentity; } completion:nil];
}

#pragma mark - Nav

- (void)closeTapped {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[SpeechManager sharedInstance] stop];  // 離開畫面就停止朗讀
}

@end
