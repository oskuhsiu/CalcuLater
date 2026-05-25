#import "LessonsHomeViewController.h"
#import "Lesson.h"
#import "LessonViewController.h"
#import "LessonProgressStore.h"
#import "MultiplicationTableViewController.h"
#import "ChildUIKit.h"
#import "DecorativeBackgroundView.h"

@interface LessonsHomeViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<Lesson *> *addSubLessons;
@end

@implementation LessonsHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [DecorativeBackgroundView installInViewController:self theme:BackgroundThemeLessons];
    self.addSubLessons = [LessonCatalog addSubLessons];
    [self setupNav];
    [self setupCollection];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.collectionView reloadData];
}

- (void)setupNav {
    self.title = @"學一學";
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSFontAttributeName: [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: ChildUI.brownText
    };
}

- (void)setupCollection {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 16;
    layout.minimumInteritemSpacing = 16;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);
    layout.sectionHeadersPinToVisibleBounds = NO;

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:UICollectionViewCell.class forCellWithReuseIdentifier:@"cell"];
    [self.collectionView registerClass:UICollectionReusableView.class
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"header"];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.collectionView];
}

#pragma mark - DataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)cv { return 2; }

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)self.addSubLessons.count : 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:ip];
    for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];
    cell.contentView.backgroundColor = ChildUI.creamBackground;
    cell.contentView.layer.cornerRadius = 24.0;
    cell.contentView.layer.masksToBounds = NO;
    [ChildUI applySoftShadowOnLayer:cell.contentView.layer];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.tintColor = ChildUI.pumpkinOrange;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.font = [ChildUI roundedFontOfSize:20.0 weight:UIFontWeightBold];
    title.textColor = ChildUI.brownText;
    title.numberOfLines = 2;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:title];

    UILabel *stars = [[UILabel alloc] init];
    stars.font = [ChildUI roundedFontOfSize:22.0 weight:UIFontWeightSemibold];
    stars.textColor = ChildUI.eggYolk;
    stars.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:stars];

    if (ip.section == 0) {
        Lesson *l = self.addSubLessons[ip.item];
        icon.image = [UIImage systemImageNamed:l.iconName];
        title.text = l.title;
        NSInteger s = [[LessonProgressStore sharedInstance] starsForLessonID:l.lessonID];
        NSMutableString *str = [NSMutableString string];
        for (NSInteger i = 0; i < 3; i++) [str appendString:i < s ? @"★" : @"☆"];
        stars.text = str;
    } else {
        icon.image = [UIImage systemImageNamed:@"square.grid.3x3.fill"];
        icon.tintColor = ChildUI.lavender;
        title.text = @"九九乘法表";
        stars.text = @"";
    }

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:18],
        [icon.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:54],
        [icon.heightAnchor constraintEqualToConstant:54],

        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:14],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:cell.contentView.trailingAnchor constant:-12],
        [title.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:18],

        [stars.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:14],
        [stars.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-14],
    ]];
    return cell;
}

#pragma mark - Layout sizing

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)ip {
    CGFloat w = cv.bounds.size.width - 32;
    return CGSizeMake(w, 100);
}

#pragma mark - Selection

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    [cv deselectItemAtIndexPath:ip animated:YES];
    UIViewController *vc = nil;
    if (ip.section == 0) {
        Lesson *l = self.addSubLessons[ip.item];
        vc = [[LessonViewController alloc] initWithLesson:l];
    } else {
        vc = [[MultiplicationTableViewController alloc] init];
    }
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
}

@end
