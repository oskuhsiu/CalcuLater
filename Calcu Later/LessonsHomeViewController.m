#import "LessonsHomeViewController.h"
#import "Lesson.h"
#import "LessonViewController.h"
#import "LessonProgressStore.h"
#import "MultiplicationTableViewController.h"
#import "OperationTableViewController.h"
#import "ConceptLearningPath.h"
#import "ConceptLearningPathViewController.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"
#import <math.h>

static UILabel *DiscoveryLabel(CGFloat size, BOOL bold) {
    UILabel *label = [[UILabel alloc] init];
    label.font = [ChildUI scaledRoundedFontOfSize:size weight:bold ? UIFontWeightBold : UIFontWeightRegular textStyle:UIFontTextStyleBody maximumPointSize:size * 1.6];
    label.adjustsFontForContentSizeCategory = YES; label.textColor = ChildUI.brownText; label.numberOfLines = 0;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    return label;
}
/// One constrained cell measures and renders every row. Titles, details and
/// stars have separate lines, without a fixed height or two-line truncation.
@interface LessonsDiscoveryCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *starsLabel;
- (CGFloat)heightForWidth:(CGFloat)width;
@end
@implementation LessonsDiscoveryCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = ChildUI.creamBackground; self.contentView.layer.cornerRadius = 24;
        [ChildUI applySoftShadowOnLayer:self.contentView.layer]; self.shouldGroupAccessibilityChildren = YES;
        _icon = [[UIImageView alloc] init]; _icon.contentMode = UIViewContentModeScaleAspectFit;
        _icon.isAccessibilityElement = NO; _icon.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:_icon];
        _titleLabel = DiscoveryLabel(20, YES); _detailLabel = DiscoveryLabel(16, NO); _starsLabel = DiscoveryLabel(22, YES);
        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _detailLabel, _starsLabel]];
        text.axis = UILayoutConstraintAxisVertical; text.spacing = 8; text.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:text];
        [NSLayoutConstraint activateConstraints:@[
            [_icon.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16], [_icon.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:20],
            [_icon.widthAnchor constraintEqualToConstant:32], [_icon.heightAnchor constraintEqualToConstant:32],
            [text.leadingAnchor constraintEqualToAnchor:_icon.trailingAnchor constant:12], [text.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [text.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:18], [text.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-18]
        ]];
    }
    return self;
}
- (CGFloat)heightForWidth:(CGFloat)width {
    CGFloat textWidth = MAX(1, width - 76);
    for (UILabel *label in @[self.titleLabel, self.detailLabel, self.starsLabel]) label.preferredMaxLayoutWidth = textWidth;
    CGSize fitting = [self.contentView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return MAX(88, ceil(fitting.height));
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat textWidth = MAX(1, self.contentView.bounds.size.width - 76);
    for (UILabel *label in @[self.titleLabel, self.detailLabel, self.starsLabel]) label.preferredMaxLayoutWidth = textWidth;
}
@end

@interface LessonsDiscoveryHeader : UICollectionReusableView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) ChildButton *exploreButton;
@property (nonatomic, strong) NSLayoutConstraint *buttonHeight;
- (CGFloat)heightForWidth:(CGFloat)width;
@end
@implementation LessonsDiscoveryHeader
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _titleLabel = DiscoveryLabel(23, YES); _titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader; _detailLabel = DiscoveryLabel(17, NO);
        _exploreButton = [ChildButton buttonWithTitle:@"看動畫，不計分" backgroundColor:ChildUI.mintGreen];
        _exploreButton.titleLabel.font = [ChildUI scaledRoundedFontOfSize:19 weight:UIFontWeightBold textStyle:UIFontTextStyleBody maximumPointSize:28];
        _exploreButton.titleLabel.adjustsFontForContentSizeCategory = YES; _exploreButton.titleLabel.adjustsFontSizeToFitWidth = NO;
        _exploreButton.titleLabel.numberOfLines = 1; _exploreButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        _exploreButton.contentEdgeInsets = UIEdgeInsetsMake(14, 12, 14, 12);
        _exploreButton.accessibilityIdentifier = @"lessons.explore"; _exploreButton.accessibilityLabel = @"先看動畫，不計分";
        _exploreButton.accessibilityHint = @"跳到進位、借位、乘法和兩種除法的探索入口。";
        NSLayoutConstraint *height = [_exploreButton.heightAnchor constraintGreaterThanOrEqualToConstant:60]; height.priority = 999; height.active = YES; _buttonHeight = height;
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _detailLabel, _exploreButton]];
        stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = NO; [self addSubview:stack];
        NSLayoutConstraint *width = [stack.widthAnchor constraintEqualToAnchor:self.widthAnchor constant:-32]; width.priority = 999;
        [NSLayoutConstraint activateConstraints:@[
            [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], [stack.widthAnchor constraintLessThanOrEqualToConstant:736], width,
            [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:20], [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12]
        ]];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.buttonHeight.constant = MAX(60, ceil(self.exploreButton.titleLabel.font.lineHeight) + 28);
}
- (CGFloat)heightForWidth:(CGFloat)width {
    self.buttonHeight.constant = MAX(60, ceil(self.exploreButton.titleLabel.font.lineHeight) + 28);
    CGFloat textWidth = MAX(1, MIN(736, width - 32)); self.titleLabel.preferredMaxLayoutWidth = textWidth; self.detailLabel.preferredMaxLayoutWidth = textWidth;
    CGSize fitting = [self systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return ceil(fitting.height);
}
@end

@interface LessonsHomeViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<Lesson *> *addSubLessons;
@property (nonatomic, strong) NSArray<ConceptLearningPath *> *conceptPaths;
@property (nonatomic, strong) LessonsDiscoveryCell *measuringCell;
@property (nonatomic, strong) LessonsDiscoveryHeader *measuringHeader;
@property (nonatomic) CGFloat lastLayoutWidth;
@end
@implementation LessonsHomeViewController
- (void)viewDidLoad {
    [super viewDidLoad]; [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeLessons];
    self.addSubLessons = [LessonCatalog addSubLessons]; self.conceptPaths = [ConceptLearningPath allPaths]; self.title = @"學一學";
    self.navigationController.navigationBar.titleTextAttributes = @{NSFontAttributeName:[ChildUI roundedFontOfSize:22 weight:UIFontWeightBold], NSForegroundColorAttributeName:ChildUI.brownText};
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init]; layout.minimumLineSpacing = 16; layout.minimumInteritemSpacing = 16;
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.backgroundColor = UIColor.clearColor; self.collectionView.dataSource = self; self.collectionView.delegate = self;
    self.collectionView.accessibilityIdentifier = @"lessons.catalog"; self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.collectionView registerClass:LessonsDiscoveryCell.class forCellWithReuseIdentifier:@"cell"];
    [self.collectionView registerClass:LessonsDiscoveryHeader.class forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
    [self.view addSubview:self.collectionView]; UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:safe.topAnchor], [self.collectionView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor], [self.collectionView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor]
    ]];
    [self resetMeasuringViews];
}
- (void)resetMeasuringViews {
    [self.measuringCell removeFromSuperview];
    [self.measuringHeader removeFromSuperview];
    self.measuringCell = [[LessonsDiscoveryCell alloc] initWithFrame:CGRectZero];
    self.measuringHeader = [[LessonsDiscoveryHeader alloc] initWithFrame:CGRectZero];
    // Hidden siblings inherit the same traits as rendered rows, including
    // container-specific Dynamic Type overrides. They never enter accessibility.
    for (UIView *view in @[self.measuringCell, self.measuringHeader]) {
        view.hidden = YES;
        view.accessibilityElementsHidden = YES;
        [self.view addSubview:view];
    }
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.collectionView reloadData]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (fabs(self.lastLayoutWidth - self.collectionView.bounds.size.width) > 0.5) { self.lastLayoutWidth = self.collectionView.bounds.size.width; [self.collectionView.collectionViewLayout invalidateLayout]; }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        [self resetMeasuringViews];
        [self.collectionView reloadData]; [self.collectionView.collectionViewLayout invalidateLayout];
    }
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView { return 3; }
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section { return section == 0 ? self.addSubLessons.count : (section == 1 ? self.conceptPaths.count : 3); }
- (void)configureCell:(LessonsDiscoveryCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    cell.starsLabel.hidden = indexPath.section != 0; cell.starsLabel.text = nil; cell.starsLabel.accessibilityLabel = nil;
    cell.icon.tintColor = indexPath.section == 0 ? ChildUI.pumpkinOrange : [ChildUI candyColorAtIndex:indexPath.item];
    if (indexPath.section == 0) {
        Lesson *lesson = self.addSubLessons[indexPath.item];
        cell.titleLabel.text = lesson.title; // Preserve the exact existing visible and accessibility titles.
        cell.icon.image = [UIImage systemImageNamed:lesson.iconName]; cell.detailLabel.text = @"先看示範，再做原來的練習。";
        NSInteger stars = [[LessonProgressStore sharedInstance] starsForLessonID:lesson.lessonID]; NSMutableString *display = [NSMutableString string];
        for (NSInteger i = 0; i < 3; i++) [display appendString:i < stars ? @"★" : @"☆"];
        cell.starsLabel.text = display; cell.starsLabel.accessibilityLabel = [NSString stringWithFormat:@"練習星星，%ld 顆，共 3 顆", (long)stars];
        cell.accessibilityIdentifier = [@"lessons.lesson." stringByAppendingString:lesson.lessonID]; cell.titleLabel.accessibilityHint = @"打開這一課的示範和練習。";
    } else if (indexPath.section == 1) {
        ConceptLearningPath *path = self.conceptPaths[indexPath.item]; cell.titleLabel.text = path.title; cell.detailLabel.text = path.summaryText;
        cell.icon.image = [UIImage systemImageNamed:path.iconName]; cell.accessibilityIdentifier = [@"lessons.concept." stringByAppendingString:path.pathID];
        cell.titleLabel.accessibilityHint = @"打開不計分的探索題目，再選擇要不要看動畫。";
    } else {
        cell.titleLabel.text = @[@"加法表", @"減法表", @"九九乘法表"][indexPath.item];
        cell.detailLabel.text = @[@"找一找加起來的數。", @"找一找減掉後的數。", @"看看乘法表，也能選一個段來練習。"][indexPath.item];
        cell.icon.image = [UIImage systemImageNamed:@[@"plus.square.fill", @"minus.square.fill", @"square.grid.3x3.fill"][indexPath.item]];
        cell.accessibilityIdentifier = @[@"lessons.table.addition", @"lessons.table.subtraction", @"lessons.table.multiplication"][indexPath.item]; cell.titleLabel.accessibilityHint = @"打開查表。";
    }
    cell.titleLabel.accessibilityIdentifier = [cell.accessibilityIdentifier stringByAppendingString:@".title"];
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    LessonsDiscoveryCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath]; [self configureCell:cell atIndexPath:indexPath]; return cell;
}
- (void)configureHeader:(LessonsDiscoveryHeader *)header section:(NSInteger)section {
    header.titleLabel.text = @[@"加減練習 · L1–L5", @"動畫探索 · 不計分", @"查一查 · 運算表"][section];
    header.detailLabel.text = @[@"照自己的步調選一課。星星只記錄原來的練習。", @"先看例子，換一題想想，再換數字。沒有計時，也不會增加星星。", @"保留加法表、減法表和九九乘法表。"][section];
    header.titleLabel.accessibilityIdentifier = @[@"lessons.section.practice", @"lessons.section.concepts", @"lessons.section.tables"][section]; header.exploreButton.hidden = section != 0;
    [header.exploreButton removeTarget:self action:@selector(showConceptPaths) forControlEvents:UIControlEventTouchUpInside];
    [header.exploreButton addTarget:self action:@selector(showConceptPaths) forControlEvents:UIControlEventTouchUpInside];
}
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    LessonsDiscoveryHeader *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath]; [self configureHeader:header section:indexPath.section]; return header;
}
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = MAX(1, MIN(736, collectionView.bounds.size.width - 32)); [self configureCell:self.measuringCell atIndexPath:indexPath]; return CGSizeMake(width, [self.measuringCell heightForWidth:width]);
}
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout insetForSectionAtIndex:(NSInteger)section {
    CGFloat side = MAX(16, (collectionView.bounds.size.width - 736) / 2); return UIEdgeInsetsMake(8, side, 20, side);
}
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section {
    [self configureHeader:self.measuringHeader section:section]; return CGSizeMake(collectionView.bounds.size.width, [self.measuringHeader heightForWidth:collectionView.bounds.size.width]);
}
- (void)showConceptPaths {
    [self.collectionView layoutIfNeeded]; NSIndexPath *first = [NSIndexPath indexPathForItem:0 inSection:1];
    UICollectionViewLayoutAttributes *attributes = [self.collectionView.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:first];
    if (!attributes) return;
    CGFloat top = -self.collectionView.adjustedContentInset.top;
    CGFloat maximum = MAX(top, self.collectionView.contentSize.height - self.collectionView.bounds.size.height + self.collectionView.adjustedContentInset.bottom);
    CGFloat y = MAX(top, MIN(maximum, attributes.frame.origin.y - self.collectionView.adjustedContentInset.top));
    [self.collectionView setContentOffset:CGPointMake(0, y) animated:NO]; [self.collectionView layoutIfNeeded];
    LessonsDiscoveryHeader *header = (LessonsDiscoveryHeader *)[self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:first];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, header.titleLabel);
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES]; if (self.presentedViewController) return; UIViewController *controller;
    if (indexPath.section == 0) controller = [[LessonViewController alloc] initWithLesson:self.addSubLessons[indexPath.item]];
    else if (indexPath.section == 1) controller = [[ConceptLearningPathViewController alloc] initWithPath:self.conceptPaths[indexPath.item]];
    else if (indexPath.item == 0) controller = [[OperationTableViewController alloc] initWithKind:OperationTableKindAddition];
    else if (indexPath.item == 1) controller = [[OperationTableViewController alloc] initWithKind:OperationTableKindSubtraction];
    else controller = [[MultiplicationTableViewController alloc] init];
    controller.modalPresentationStyle = UIModalPresentationFullScreen; [self presentViewController:controller animated:YES completion:nil];
}
@end
