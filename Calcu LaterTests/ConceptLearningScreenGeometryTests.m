#import <XCTest/XCTest.h>
#import "ConceptLearningPath.h"
#import "ConceptLearningPathViewController.h"
#import "ChildUIKit.h"

@interface ConceptLearningPathViewController (ScreenGeometryTests)
- (ConceptLearningExample *)currentExample;
- (void)next;
- (void)changeNumbers;
@end

@interface ConceptLearningScreenGeometryTests : XCTestCase
@property (nonatomic, strong) UIWindow *hostWindow;
@property (nonatomic, strong) UIViewController *host;
@property (nonatomic, strong) ConceptLearningPathViewController *controller;
@end

@implementation ConceptLearningScreenGeometryTests

- (void)removeHost {
    [self.controller willMoveToParentViewController:nil];
    [self.controller.view removeFromSuperview];
    [self.controller removeFromParentViewController];
    self.controller = nil;
    self.hostWindow.hidden = YES;
    self.hostWindow.rootViewController = nil;
    self.hostWindow = nil;
    self.host = nil;
}

- (void)tearDown {
    [self removeHost];
    [super tearDown];
}

- (UITraitCollection *)traitsForSize:(CGSize)size category:(UIContentSizeCategory)category {
    return [UITraitCollection traitCollectionWithTraitsFromCollections:@[
        [UITraitCollection traitCollectionWithPreferredContentSizeCategory:category],
        [UITraitCollection traitCollectionWithHorizontalSizeClass:size.width < 600 ? UIUserInterfaceSizeClassCompact : UIUserInterfaceSizeClassRegular],
        [UITraitCollection traitCollectionWithVerticalSizeClass:size.height < 400 ? UIUserInterfaceSizeClassCompact : UIUserInterfaceSizeClassRegular]
    ]];
}

- (void)settleLayout {
    // Wrapping labels invalidate their fitting width after layout; navigation
    // also changes axis there. Allow those real constraints to settle, without
    // changing production label fonts, intrinsic sizes, or contentSize.
    for (NSUInteger pass = 0; pass < 4; pass++) {
        [self.host.view setNeedsLayout];
        [self.host.view layoutIfNeeded];
        [self.controller.view setNeedsLayout];
        [self.controller.view layoutIfNeeded];
    }
}

- (void)resizeTo:(CGSize)size category:(UIContentSizeCategory)category {
    self.hostWindow.frame = (CGRect){CGPointZero, size};
    self.host.view.frame = self.hostWindow.bounds;
    self.controller.view.frame = self.host.view.bounds;
    [self.host setOverrideTraitCollection:[self traitsForSize:size category:category]
                  forChildViewController:self.controller];
    [self settleLayout];
    XCTAssertEqualWithAccuracy(self.controller.view.bounds.size.width, size.width, 0.5);
    XCTAssertEqualWithAccuracy(self.controller.view.bounds.size.height, size.height, 0.5);
    XCTAssertEqualObjects(self.controller.traitCollection.preferredContentSizeCategory, category);
}

- (void)showPath:(ConceptLearningPath *)path size:(CGSize)size category:(UIContentSizeCategory)category {
    [self removeHost];
    self.hostWindow = [[UIWindow alloc] initWithFrame:(CGRect){CGPointZero, size}];
    self.host = [[UIViewController alloc] init];
    self.hostWindow.rootViewController = self.host;
    self.hostWindow.hidden = NO;
    self.host.view.frame = (CGRect){CGPointZero, size};
    self.controller = [[ConceptLearningPathViewController alloc] initWithPath:path];
    [self.host addChildViewController:self.controller];
    [self.host setOverrideTraitCollection:[self traitsForSize:size category:category]
                  forChildViewController:self.controller];
    // The trait override is genuinely inherited by the controller and its views.
    // Make it current for this synchronous view load as UIKit does for its layout
    // callbacks, so UIFontMetrics does not read the simulator's global setting.
    [self.controller.traitCollection performAsCurrentTraitCollection:^{
        [self.host.view addSubview:self.controller.view];
    }];
    self.controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.controller didMoveToParentViewController:self.host];
    [self resizeTo:size category:category];
}

- (UIView *)viewWithIdentifier:(NSString *)identifier inView:(UIView *)view {
    if ([view.accessibilityIdentifier isEqualToString:identifier]) return view;
    for (UIView *child in view.subviews) {
        UIView *match = [self viewWithIdentifier:identifier inView:child];
        if (match) return match;
    }
    return nil;
}

- (UIView *)viewWithIdentifier:(NSString *)identifier {
    UIView *view = [self viewWithIdentifier:identifier inView:self.controller.view];
    XCTAssertNotNil(view, @"Missing %@", identifier);
    return view;
}

- (void)assertLabelFits:(UILabel *)label inScroll:(UIScrollView *)scroll {
    XCTAssertTrue([label isKindOfClass:ChildWrappingLabel.class]);
    XCTAssertEqual(label.numberOfLines, 0);
    XCTAssertTrue(label.adjustsFontForContentSizeCategory);
    XCTAssertEqualObjects(label.traitCollection.preferredContentSizeCategory,
                          self.controller.traitCollection.preferredContentSizeCategory);
    NSDictionary<NSString *, NSNumber *> *baseSizes = @{@"concept.title": @26, @"concept.unscored": @17,
        @"concept.stage": @21, @"concept.invitation": @19, @"concept.question": @22,
        @"concept.equation": @30, @"concept.focus": @19, @"concept.variation": @17};
    CGFloat baseSize = baseSizes[label.accessibilityIdentifier].doubleValue;
    XCTAssertGreaterThan(baseSize, 0);
    UIFont *expected = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:baseSize weight:UIFontWeightRegular]
        compatibleWithTraitCollection:self.controller.traitCollection];
    XCTAssertEqualWithAccuracy(label.font.pointSize, expected.pointSize, 0.01,
                               @"%@ must use the active category's uncapped UIFontMetrics scale", label.accessibilityIdentifier);
    CGRect frame = [label convertRect:label.bounds toView:scroll];
    XCTAssertGreaterThan(frame.size.width, 0, @"%@", label.accessibilityIdentifier);
    XCTAssertGreaterThan(frame.size.height, 0, @"%@", label.accessibilityIdentifier);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(frame), 15.5);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(frame), scroll.bounds.size.width - 15.5);
    CGSize required = [label sizeThatFits:CGSizeMake(frame.size.width, CGFLOAT_MAX)];
    XCTAssertGreaterThanOrEqual(frame.size.height + 1, required.height,
                               @"%@ must fit all of its text, not merely a clipped frame", label.accessibilityIdentifier);
    CGRect contentBounds = (CGRect){CGPointZero, scroll.contentSize};
    XCTAssertTrue(CGRectContainsRect(CGRectInset(contentBounds, -0.5, -0.5), frame));
    XCTAssertFalse(label.hasAmbiguousLayout, @"%@", label.accessibilityIdentifier);
}

- (void)assertButtonFits:(UIButton *)button {
    XCTAssertGreaterThanOrEqual(button.bounds.size.width, 44);
    XCTAssertGreaterThanOrEqual(button.bounds.size.height, 44);
    XCTAssertFalse(button.hasAmbiguousLayout, @"%@", button.accessibilityIdentifier);
    XCTAssertFalse(button.titleLabel.adjustsFontSizeToFitWidth);
    XCTAssertEqual(button.titleLabel.numberOfLines, 0);
    XCTAssertTrue(button.titleLabel.adjustsFontForContentSizeCategory);
    UIFont *expected = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[ChildUI roundedFontOfSize:20 weight:UIFontWeightBold]
        compatibleWithTraitCollection:self.controller.traitCollection];
    XCTAssertEqualWithAccuracy(button.titleLabel.font.pointSize, expected.pointSize, 0.01);
    CGFloat availableWidth = button.bounds.size.width - button.contentEdgeInsets.left - button.contentEdgeInsets.right;
    CGFloat availableHeight = button.bounds.size.height - button.contentEdgeInsets.top - button.contentEdgeInsets.bottom;
    // The design deliberately replaces the old 28pt/single-line cap with a
    // full-size wrapped title. Measure every line at its real available width.
    CGSize fullTitle = [button.titleLabel sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)];
    XCTAssertEqualObjects(button.titleLabel.text, button.currentTitle);
    XCTAssertGreaterThan(availableWidth, 0);
    XCTAssertLessThanOrEqual(fullTitle.width, availableWidth + 1, @"%@ title must not truncate", button.accessibilityIdentifier);
    XCTAssertLessThanOrEqual(fullTitle.height, availableHeight + 1, @"%@ title must not clip vertically", button.accessibilityIdentifier);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(button.bounds, -1, -1), button.titleLabel.frame));
    XCTAssertTrue(CGRectContainsRect(CGRectInset(UIEdgeInsetsInsetRect(button.bounds, button.contentEdgeInsets), -1, -1), button.titleLabel.frame));
    CGSize requiredInLabel = [button.titleLabel sizeThatFits:CGSizeMake(button.titleLabel.bounds.size.width, CGFLOAT_MAX)];
    XCTAssertLessThanOrEqual(requiredInLabel.height, button.titleLabel.bounds.size.height + 1,
                            @"%@ must show every line inside the actual title label, not only a large button", button.accessibilityIdentifier);
}

- (void)assertScreenAtStage:(NSUInteger)stage navigationAxis:(UILayoutConstraintAxis)axis {
    [self settleLayout];
    UIScrollView *scroll = (UIScrollView *)[self viewWithIdentifier:@"concept.content"];
    UIButton *close = (UIButton *)[self viewWithIdentifier:@"concept.close"];
    UIButton *previous = (UIButton *)[self viewWithIdentifier:@"concept.previous"];
    UIButton *next = (UIButton *)[self viewWithIdentifier:@"concept.next"];
    UIStackView *navigation = (UIStackView *)previous.superview;
    UIStackView *numberNavigation = (UIStackView *)[self viewWithIdentifier:@"concept.change"].superview;
    UILabel *question = (UILabel *)[self viewWithIdentifier:@"concept.question"];
    UIStackView *content = (UIStackView *)question.superview;
    XCTAssertTrue([scroll isKindOfClass:UIScrollView.class]);
    XCTAssertTrue([navigation isKindOfClass:UIStackView.class]);
    XCTAssertTrue([content isKindOfClass:UIStackView.class]);
    if (!scroll || !close || !previous || !next || !question) return;

    CGRect safe = self.controller.view.safeAreaLayoutGuide.layoutFrame;
    XCTAssertGreaterThan(scroll.bounds.size.height, 44);
    XCTAssertEqualWithAccuracy(scroll.bounds.size.width, MIN(768, safe.size.width), 1);
    XCTAssertEqualWithAccuracy(scroll.contentSize.width, scroll.bounds.size.width, 1);
    XCTAssertTrue(CGRectContainsRect(CGRectInset(safe, -0.5, -0.5), scroll.frame));
    XCTAssertFalse(scroll.hasAmbiguousLayout);
    XCTAssertFalse(content.hasAmbiguousLayout);
    XCTAssertFalse(navigation.hasAmbiguousLayout);
    XCTAssertFalse(numberNavigation.hasAmbiguousLayout);
    XCTAssertEqual(numberNavigation.axis, axis);
    XCTAssertEqual(numberNavigation.hidden, stage != 2);
    XCTAssertEqualWithAccuracy(content.bounds.size.width, scroll.bounds.size.width - 32, 1);

    XCTAssertEqual(close.superview, self.controller.view, @"Close must remain outside the scrolling content");
    XCTAssertFalse([close isDescendantOfView:scroll]);
    XCTAssertFalse(close.hidden);
    XCTAssertTrue(close.enabled);
    [self assertButtonFits:close];
    CGRect closeFrame = [close convertRect:close.bounds toView:self.controller.view];
    XCTAssertTrue(CGRectContainsRect(CGRectInset(safe, -0.5, -0.5), closeFrame));
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(scroll.frame), CGRectGetMaxY(closeFrame) + 7.5);

    for (NSString *identifier in @[@"concept.title", @"concept.unscored", @"concept.stage", @"concept.invitation",
                                   @"concept.question", @"concept.equation", @"concept.focus", @"concept.variation"]) {
        UILabel *label = (UILabel *)[self viewWithIdentifier:identifier];
        BOOL shouldHide = [identifier isEqualToString:@"concept.variation"] && stage != 2;
        XCTAssertEqual(label.hidden, shouldHide, @"%@", identifier);
        if (!label.hidden) [self assertLabelFits:label inScroll:scroll];
    }
    CGFloat previousBottom = -CGFLOAT_MAX;
    for (UIView *arranged in content.arrangedSubviews) {
        if (arranged.hidden) continue;
        XCTAssertGreaterThanOrEqual(CGRectGetMinY(arranged.frame) + 0.5, previousBottom,
                                   @"Visible content rows must not overlap");
        previousBottom = CGRectGetMaxY(arranged.frame);
    }
    XCTAssertEqual(previous.enabled, stage != 0);
    XCTAssertEqual(navigation.axis, axis);
    if (axis == UILayoutConstraintAxisVertical) {
        XCTAssertLessThanOrEqual(CGRectGetMaxY(previous.frame), CGRectGetMinY(next.frame) + 0.5);
        XCTAssertEqualWithAccuracy(previous.frame.origin.x, next.frame.origin.x, 0.5);
    } else {
        XCTAssertLessThanOrEqual(CGRectGetMaxX(previous.frame), CGRectGetMinX(next.frame) + 0.5);
        XCTAssertEqualWithAccuracy(previous.frame.origin.y, next.frame.origin.y, 0.5);
    }

    // Each action must be reachable individually. The tall lesson is deliberately
    // scrollable; requiring the whole page in one viewport would be incorrect.
    for (NSString *identifier in @[@"concept.read", @"concept.teach", @"concept.previousNumbers", @"concept.change", @"concept.previous", @"concept.next"]) {
        UIButton *button = (UIButton *)[self viewWithIdentifier:identifier];
        BOOL numberAction = [identifier isEqualToString:@"concept.change"] || [identifier isEqualToString:@"concept.previousNumbers"];
        XCTAssertEqual(button.hidden, numberAction && stage != 2);
        if (button.hidden) continue;
        [self assertButtonFits:button];
        XCTAssertTrue([button isDescendantOfView:scroll]);
        CGRect frame = [button convertRect:button.bounds toView:scroll];
        CGRect contentBounds = (CGRect){CGPointZero, scroll.contentSize};
        XCTAssertTrue(CGRectContainsRect(CGRectInset(contentBounds, -0.5, -0.5), frame), @"%@", identifier);
        XCTAssertGreaterThanOrEqual(CGRectGetMinX(frame), 15.5);
        XCTAssertLessThanOrEqual(CGRectGetMaxX(frame), scroll.bounds.size.width - 15.5);
        [scroll scrollRectToVisible:frame animated:NO];
        [self settleLayout];
        CGRect viewport = UIEdgeInsetsInsetRect(scroll.bounds, scroll.adjustedContentInset);
        XCTAssertTrue(CGRectContainsRect(CGRectInset(viewport, -1, -1), [button convertRect:button.bounds toView:scroll]),
                      @"%@ must be fully reachable by scrolling", identifier);
        XCTAssertEqualWithAccuracy(scroll.contentOffset.x, 0, 0.5);
        XCTAssertTrue(CGRectEqualToRect(closeFrame, [close convertRect:close.bounds toView:self.controller.view]),
                      @"Scrolling must not move the persistent Close action");
    }
}

- (void)testEveryPathAndAllThreeStagesFit320PointsAtMaximumAccessibilityText {
    NSArray<ConceptLearningPath *> *paths = [ConceptLearningPath allPaths];
    XCTAssertGreaterThan(paths.count, 0u);
    BOOL checkedLongSharingStory = NO;
    for (ConceptLearningPath *path in paths) {
        [self showPath:path size:CGSizeMake(320, 568) category:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
        UILabel *question = (UILabel *)[self viewWithIdentifier:@"concept.question"];
        UIButton *teach = (UIButton *)[self viewWithIdentifier:@"concept.teach"];
        // Check the fixture truly exercises scaled fonts, not just a trait string.
        XCTAssertGreaterThan(question.font.pointSize, 22);
        XCTAssertGreaterThan(question.font.pointSize, 22 * 1.6 + 0.5, @"The former label cap must no longer constrain AX5 text.");
        XCTAssertGreaterThan(teach.titleLabel.font.pointSize, 20);
        XCTAssertGreaterThan(teach.titleLabel.font.pointSize, 28.5, @"The former action cap must no longer constrain AX5 text.");
        for (NSUInteger stage = 0; stage < 3; stage++) {
            [self assertScreenAtStage:stage navigationAxis:UILayoutConstraintAxisVertical];
            XCTAssertEqualObjects(question.text, self.controller.currentExample.questionText);
            UIScrollView *scroll = (UIScrollView *)[self viewWithIdentifier:@"concept.content"];
            XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.size.height,
                                 @"Maximum text at 320 pt should use vertical scrolling");
            if ([path.pathID isEqualToString:@"sharing"]) {
                checkedLongSharingStory = YES;
                XCTAssertTrue([question.text containsString:@"每人分到一樣多的整顆糖果"]);
                XCTAssertGreaterThan(question.bounds.size.height, question.font.lineHeight * 2);
            }
            if (stage < 2) [self.controller next];
        }
        // The later exploration stories must retain the same fitting contract.
        for (NSUInteger variation = 1; variation < path.explorationExamples.count; variation++) {
            [self.controller changeNumbers];
            [self assertScreenAtStage:2 navigationAxis:UILayoutConstraintAxisVertical];
            XCTAssertEqual(self.controller.currentExample, path.explorationExamples[variation]);
        }
    }
    XCTAssertTrue(checkedLongSharingStory);
}

- (void)testSelectedSharingQuestionSurvivesWideRelayoutAndLiveTextSizeChanges {
    ConceptLearningPath *sharing = nil;
    for (ConceptLearningPath *path in [ConceptLearningPath allPaths]) {
        if ([path.pathID isEqualToString:@"sharing"]) sharing = path;
    }
    XCTAssertNotNil(sharing);
    if (!sharing) return;
    [self showPath:sharing size:CGSizeMake(320, 568) category:UIContentSizeCategoryLarge];
    [self.controller next];
    [self.controller next];
    [self.controller changeNumbers];
    ConceptLearningExample *selected = self.controller.currentExample;
    UILabel *question = (UILabel *)[self viewWithIdentifier:@"concept.question"];
    UILabel *equation = (UILabel *)[self viewWithIdentifier:@"concept.equation"];
    UIButton *teach = (UIButton *)[self viewWithIdentifier:@"concept.teach"];
    CGFloat defaultQuestionSize = question.font.pointSize;
    CGFloat defaultActionSize = teach.titleLabel.font.pointSize;
    [self assertScreenAtStage:2 navigationAxis:UILayoutConstraintAxisVertical];

    NSArray<NSValue *> *sizes = @[[NSValue valueWithCGSize:CGSizeMake(1024, 768)],
                                 [NSValue valueWithCGSize:CGSizeMake(1024, 768)],
                                 [NSValue valueWithCGSize:CGSizeMake(320, 568)],
                                 [NSValue valueWithCGSize:CGSizeMake(1024, 768)]];
    NSArray<NSString *> *categories = @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge,
                                       UIContentSizeCategoryAccessibilityExtraExtraExtraLarge, UIContentSizeCategoryLarge];
    for (NSUInteger index = 0; index < sizes.count; index++) {
        CGSize size = sizes[index].CGSizeValue;
        UIContentSizeCategory category = categories[index];
        BOOL accessible = UIContentSizeCategoryIsAccessibilityCategory(category);
        [self resizeTo:size category:category];
        UILayoutConstraintAxis axis = accessible || size.width < 400 ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
        [self assertScreenAtStage:2 navigationAxis:axis];
        XCTAssertEqual(self.controller.currentExample, selected, @"Relayout must not regenerate or advance the question");
        XCTAssertEqualObjects(question.text, selected.questionText);
        XCTAssertEqualObjects(equation.text, selected.equationText);
        if (accessible) {
            XCTAssertGreaterThan(question.font.pointSize, defaultQuestionSize);
            XCTAssertGreaterThan(teach.titleLabel.font.pointSize, defaultActionSize);
        } else {
            XCTAssertEqualWithAccuracy(question.font.pointSize, defaultQuestionSize, 0.5);
            XCTAssertEqualWithAccuracy(teach.titleLabel.font.pointSize, defaultActionSize, 0.5);
        }
    }
}

@end
