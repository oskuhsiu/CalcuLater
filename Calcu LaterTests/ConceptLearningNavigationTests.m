#import <XCTest/XCTest.h>
#import "ConceptLearningPath.h"
#import "ConceptLearningPathViewController.h"
#import "VerticalTeachingViewController.h"
#import "GroupingTeachingViewController.h"
#import "LessonsHomeViewController.h"
#import "LessonViewController.h"
#import "OperationTableViewController.h"
#import "MultiplicationTableViewController.h"
#import "Lesson.h"
#import "LessonProgressStore.h"
#import "ArithmeticProblem.h"
#import "ArithmeticTeachingSequence.h"
#import "GroupingTeachingSequence.h"
#import "WordProblem.h"

@interface ConceptLearningPathViewController (NavigationTests)
- (ConceptLearningExample *)currentExample;
- (void)previous;
- (void)next;
- (void)changeNumbers;
- (void)openTeaching;
@end

@interface ConceptPresentationSpy : ConceptLearningPathViewController
@property (nonatomic, strong) UIViewController *capturedTeaching;
@property (nonatomic) BOOL requestedDismissal;
@end
@implementation ConceptPresentationSpy
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion {
    self.capturedTeaching = controller;
    if (completion) completion();
}
- (UIViewController *)presentedViewController { return self.capturedTeaching; }
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    self.requestedDismissal = YES;
    if (completion) completion();
}
@end

@interface ConceptDiscoveryPresentationSpy : LessonsHomeViewController
@property (nonatomic, strong) UIViewController *capturedDestination;
@end
@implementation ConceptDiscoveryPresentationSpy
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion {
    self.capturedDestination = controller;
    if (completion) completion();
}
- (UIViewController *)presentedViewController { return self.capturedDestination; }
@end

@interface ConceptLearningNavigationTests : XCTestCase
@end
@implementation ConceptLearningNavigationTests
- (UILabel *)label:(NSString *)identifier inView:(UIView *)view {
    if ([view.accessibilityIdentifier isEqualToString:identifier]) return (UILabel *)view;
    for (UIView *child in view.subviews) {
        UILabel *found = [self label:identifier inView:child];
        if (found) return found;
    }
    return nil;
}
- (NSDictionary *)savedProgress {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (Lesson *lesson in [LessonCatalog addSubLessons]) {
        for (NSString *suffix in @[@"stars", @"completed"]) {
            NSString *key = [NSString stringWithFormat:@"lesson.%@.%@", lesson.lessonID, suffix];
            result[key] = [NSUserDefaults.standardUserDefaults objectForKey:key] ?: NSNull.null;
        }
    }
    return result;
}
- (void)testStageNavigationCanSkipGuidanceAndKeepsExplorationNumbersAfterBack {
    NSDictionary *before = [self savedProgress];
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        ConceptPresentationSpy *controller = [[ConceptPresentationSpy alloc] initWithPath:path];
        [controller loadViewIfNeeded];
        XCTAssertEqualObjects(controller.currentExample.equationText, path.firstExample.equationText);
        [controller previous];
        XCTAssertEqual(controller.currentExample, path.firstExample);
        [controller next];
        XCTAssertEqual(controller.currentExample, path.relatedExample);
        XCTAssertTrue([[self label:@"concept.invitation" inView:controller.view].text containsString:@"先用手指或心裡想一想"]);
        [controller next];
        XCTAssertEqual(controller.currentExample, path.explorationExamples[0]);
        [controller changeNumbers];
        ConceptLearningExample *changed = controller.currentExample;
        XCTAssertEqual(changed, path.explorationExamples[1]);
        [controller previous];
        XCTAssertEqual(controller.currentExample, path.relatedExample);
        [controller next];
        XCTAssertEqual(controller.currentExample, changed);
        [controller changeNumbers];
        [controller changeNumbers];
        XCTAssertEqual(controller.currentExample, path.explorationExamples[0]);
        [controller next];
        XCTAssertTrue(controller.requestedDismissal);
        XCTAssertEqual(controller.currentExample, path.explorationExamples[0]);
    }
    XCTAssertEqualObjects([self savedProgress], before, @"Skipping or leaving exploration does not create stars or completion records.");
}
- (void)testGuidanceUsesCurrentSnapshotAndCannotAdvanceTheQuestion {
    NSDictionary *before = [self savedProgress];
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        ConceptPresentationSpy *controller = [[ConceptPresentationSpy alloc] initWithPath:path];
        [controller loadViewIfNeeded];
        for (NSUInteger stage = 1; stage <= 2; stage++) {
            [controller next];
            if (stage == 2) [controller changeNumbers];
            ConceptLearningExample *question = controller.currentExample;
            NSString *equation = [self label:@"concept.equation" inView:controller.view].text;
            [controller openTeaching];
            UIViewController *sheet = controller.capturedTeaching;
            XCTAssertNotNil(sheet);
            id sequence = [sheet valueForKey:@"sequence"];
            ArithmeticProblem *actual = [sequence valueForKey:@"problem"];
            XCTAssertEqual(actual.number1, question.problem.number1);
            XCTAssertEqual(actual.number2, question.problem.number2);
            XCTAssertEqual(actual.answer, question.problem.answer);
            XCTAssertEqualObjects(actual.operatorSymbol, question.problem.operatorSymbol);
            if (question.wordProblem) {
                XCTAssertTrue([sheet isKindOfClass:GroupingTeachingViewController.class]);
                XCTAssertNil(((GroupingTeachingViewController *)sheet).returnToQuestion);
                WordProblem *story = ((GroupingTeachingSequence *)sequence).wordProblem;
                XCTAssertEqualObjects(story.storyText, question.wordProblem.storyText);
                XCTAssertEqual(story.groupingContext.meaning, question.wordProblem.groupingContext.meaning);
                XCTAssertEqualObjects(story.unit, question.wordProblem.unit);
                XCTAssertEqualObjects(story.groupingContext.answerUnit, question.wordProblem.groupingContext.answerUnit);
                XCTAssertEqualObjects(story.groupingContext.leftoverUnit, question.wordProblem.groupingContext.leftoverUnit);
                XCTAssertEqual(story.remainder, question.wordProblem.remainder);
            } else {
                XCTAssertTrue([sheet isKindOfClass:VerticalTeachingViewController.class]);
                XCTAssertNil(((VerticalTeachingViewController *)sheet).returnToQuestion);
            }
            [controller next];
            [controller previous];
            [controller changeNumbers];
            [controller openTeaching];
            XCTAssertEqual(controller.capturedTeaching, sheet, @"Repeated taps must not present another sheet.");
            XCTAssertEqual(controller.currentExample, question);
            XCTAssertEqualObjects([self label:@"concept.equation" inView:controller.view].text, equation);
            controller.capturedTeaching = nil; // Actual UIKit dismissal has a separate native UI flow.
            XCTAssertEqual(controller.currentExample, question);
            XCTAssertFalse(controller.requestedDismissal);
            [controller openTeaching];
            XCTAssertNotEqual(controller.capturedTeaching, sheet);
            controller.capturedTeaching = nil;
        }
    }
    XCTAssertEqualObjects([self savedProgress], before);
}
- (void)testDiscoverySelectionPreservesLessonAndTableDestinationsAndPresentationGuard {
    NSDictionary *before = [self savedProgress];
    ConceptDiscoveryPresentationSpy *controller = [[ConceptDiscoveryPresentationSpy alloc] init];
    [controller loadViewIfNeeded];
    UICollectionView *collection = [controller valueForKey:@"collectionView"];
    id<UICollectionViewDelegate> delegate = (id)controller;
    NSArray<Lesson *> *lessons = [LessonCatalog addSubLessons];
    NSArray<ConceptLearningPath *> *paths = [ConceptLearningPath allPaths];
    NSArray<NSNumber *> *counts = @[@(lessons.count), @(paths.count), @3];
    for (NSInteger section = 0; section < (NSInteger)counts.count; section++) {
        for (NSInteger item = 0; item < counts[section].integerValue; item++) {
            NSIndexPath *index = [NSIndexPath indexPathForItem:item inSection:section];
            [delegate collectionView:collection didSelectItemAtIndexPath:index];
            UIViewController *destination = controller.capturedDestination;
            XCTAssertNotNil(destination);
            XCTAssertEqual(destination.modalPresentationStyle, UIModalPresentationFullScreen);
            if (section == 0) {
                XCTAssertTrue([destination isKindOfClass:LessonViewController.class]);
                Lesson *actual = [destination valueForKey:@"lesson"];
                XCTAssertEqualObjects(actual.lessonID, lessons[item].lessonID);
                XCTAssertEqualObjects(actual.title, lessons[item].title);
                XCTAssertEqual(actual.kind, lessons[item].kind);
                XCTAssertEqual(actual.questionCount, lessons[item].questionCount);
            } else if (section == 1) {
                XCTAssertTrue([destination isKindOfClass:ConceptLearningPathViewController.class]);
                ConceptLearningPath *actual = [destination valueForKey:@"path"];
                XCTAssertEqualObjects(actual.pathID, paths[item].pathID);
                XCTAssertEqualObjects(actual.firstExample.equationText, paths[item].firstExample.equationText);
            } else if (item < 2) {
                XCTAssertTrue([destination isKindOfClass:OperationTableViewController.class]);
                XCTAssertEqual([[destination valueForKey:@"kind"] integerValue], item == 0 ? OperationTableKindAddition : OperationTableKindSubtraction);
            } else {
                XCTAssertTrue([destination isKindOfClass:MultiplicationTableViewController.class]);
            }
            [delegate collectionView:collection didSelectItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:(section + 1) % 3]];
            XCTAssertEqual(controller.capturedDestination, destination, @"Repeated selection cannot present a second route over an existing destination.");
            controller.capturedDestination = nil;
        }
    }
    XCTAssertEqualObjects([self savedProgress], before);
}
- (void)assertLabel:(UILabel *)label fitsView:(UIView *)view {
    CGRect frame = [label convertRect:label.bounds toView:view];
    XCTAssertGreaterThan(frame.size.width, 0);
    XCTAssertGreaterThan(frame.size.height, 0);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(view.bounds, -0.5, -0.5), frame));
    CGSize required = [label sizeThatFits:CGSizeMake(frame.size.width, CGFLOAT_MAX)];
    XCTAssertGreaterThanOrEqual(frame.size.height + 1, required.height, @"Full label text must fit, not only its clipped frame.");
}
- (void)testLessonsKeepThreeSectionsAllRoutesAndMeasuredRows {
    CGFloat standardHeight = 0, accessibleHeight = 0;
    CGFloat standardTitleSize = 0, accessibleTitleSize = 0;
    for (NSString *category in @[UIContentSizeCategoryLarge, UIContentSizeCategoryExtraExtraExtraLarge,
                                UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        UIViewController *host = [[UIViewController alloc] init];
        LessonsHomeViewController *controller = [[LessonsHomeViewController alloc] init];
        [host addChildViewController:controller];
        [host setOverrideTraitCollection:[UITraitCollection traitCollectionWithPreferredContentSizeCategory:category]
                 forChildViewController:controller];
        // UIFontMetrics reads the current traits at synchronous view creation.
        // An inherited trait string alone does not prove scaled test fonts.
        [controller.traitCollection performAsCurrentTraitCollection:^{
            [host.view addSubview:controller.view];
        }];
        [controller didMoveToParentViewController:host];
        UICollectionView *collection = [controller valueForKey:@"collectionView"];
        id<UICollectionViewDelegateFlowLayout> delegate = (id)controller;
        XCTAssertEqual([collection.dataSource numberOfSectionsInCollectionView:collection], 3);
        NSArray *counts = @[@5, @5, @3];
        for (NSNumber *width in @[@320, @375, @768, @1024]) {
            controller.view.frame = CGRectMake(0, 0, width.doubleValue, 720);
            [controller.view layoutIfNeeded];
            for (NSInteger section = 0; section < 3; section++) {
                XCTAssertEqual([collection.dataSource collectionView:collection numberOfItemsInSection:section], [counts[section] integerValue]);
                CGSize headerSize = [delegate collectionView:collection layout:collection.collectionViewLayout referenceSizeForHeaderInSection:section];
                XCTAssertGreaterThan(headerSize.height, 44);
                UIView *header = [controller valueForKey:@"measuringHeader"];
                header.frame = CGRectMake(0, 0, headerSize.width, headerSize.height);
                [header setNeedsLayout];
                [header layoutIfNeeded];
                UILabel *heading = [header valueForKey:@"titleLabel"];
                UILabel *description = [header valueForKey:@"detailLabel"];
                [self assertLabel:heading fitsView:header];
                [self assertLabel:description fitsView:header];
                XCTAssertTrue(heading.accessibilityTraits & UIAccessibilityTraitHeader);
                UIButton *explore = [header valueForKey:@"exploreButton"];
                XCTAssertEqual(explore.hidden, section != 0);
                if (!explore.hidden) {
                    CGRect actionFrame = [explore convertRect:explore.bounds toView:header];
                    XCTAssertTrue(CGRectContainsRect(header.bounds, actionFrame));
                    XCTAssertGreaterThanOrEqual(actionFrame.size.height, 60);
                    XCTAssertLessThanOrEqual(explore.titleLabel.intrinsicContentSize.width,
                        actionFrame.size.width - explore.contentEdgeInsets.left - explore.contentEdgeInsets.right);
                }
                for (NSInteger item = 0; item < [counts[section] integerValue]; item++) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
                    CGSize size = [delegate collectionView:collection layout:collection.collectionViewLayout sizeForItemAtIndexPath:indexPath];
                    XCTAssertGreaterThanOrEqual(size.height, 88);
                    XCTAssertLessThanOrEqual(size.width, MIN(736, width.doubleValue - 32));
                    UICollectionViewCell *cell = [controller valueForKey:@"measuringCell"];
                    cell.frame = CGRectMake(0, 0, size.width, size.height);
                    [cell setNeedsLayout];
                    [cell layoutIfNeeded];
                    UILabel *title = [cell valueForKey:@"titleLabel"];
                    UILabel *detail = [cell valueForKey:@"detailLabel"];
                    UILabel *stars = [cell valueForKey:@"starsLabel"];
                    XCTAssertEqual(title.numberOfLines, 0);
                    XCTAssertTrue(title.adjustsFontForContentSizeCategory);
                    XCTAssertEqualObjects(title.traitCollection.preferredContentSizeCategory, category);
                    [self assertLabel:title fitsView:cell.contentView];
                    [self assertLabel:detail fitsView:cell.contentView];
                    XCTAssertLessThanOrEqual(CGRectGetMaxY(title.frame), CGRectGetMinY(detail.frame));
                    if (section == 0) {
                        Lesson *lesson = [LessonCatalog addSubLessons][item];
                        XCTAssertEqualObjects(title.text, lesson.title);
                        XCTAssertFalse(stars.hidden);
                        [self assertLabel:stars fitsView:cell.contentView];
                        XCTAssertLessThanOrEqual(CGRectGetMaxY(detail.frame), CGRectGetMinY(stars.frame));
                        if (item == 0 && width.integerValue == 320) {
                            if ([category isEqualToString:UIContentSizeCategoryLarge]) {
                                standardHeight = size.height; standardTitleSize = title.font.pointSize;
                            }
                            if ([category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
                                accessibleHeight = size.height; accessibleTitleSize = title.font.pointSize;
                            }
                        }
                    } else XCTAssertTrue(stars.hidden);
                }
            }
        }
    }
    XCTAssertGreaterThan(standardHeight, 0);
    XCTAssertGreaterThan(accessibleHeight, standardHeight, @"Large-text rows must actually grow.");
    XCTAssertGreaterThan(standardTitleSize, 0);
    XCTAssertGreaterThan(accessibleTitleSize, standardTitleSize, @"Large-text evidence must use genuinely larger fonts.");
}
@end
