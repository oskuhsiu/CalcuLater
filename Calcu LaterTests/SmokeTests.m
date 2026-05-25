// Smoke tests：確保關鍵 view controller / view 至少能初始化、loadView 不 crash。
// 不驗 layout 精準，只是抓住「啟動就 crash」這類最常見的回歸。
#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "ArithmeticProblem.h"
#import "Lesson.h"
#import "MakeBreakTenHintView.h"
#import "LessonViewController.h"
#import "LessonsHomeViewController.h"
#import "MultiplicationTableViewController.h"
#import "MainMenuViewController.h"

@interface SmokeTests : XCTestCase
@end

@implementation SmokeTests

#pragma mark - MakeBreakTenHintView

- (void)testMakeTenHintConfiguresFor8Plus5 {
    MakeBreakTenHintView *v = [[MakeBreakTenHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)
                                                                      mode:MakeBreakTenModeMakeTen];
    ArithmeticProblem *p = [[ArithmeticProblem alloc] initWithNumber1:8 number2:5 operator:@"+" answer:13];
    XCTAssertTrue([v configureWithProblem:p]);
    [v layoutIfNeeded];
    XCTAssertGreaterThan(v.subviews.count, 0);
}

- (void)testBreakTenHintConfiguresFor12Minus5 {
    MakeBreakTenHintView *v = [[MakeBreakTenHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)
                                                                      mode:MakeBreakTenModeBreakTen];
    ArithmeticProblem *p = [[ArithmeticProblem alloc] initWithNumber1:12 number2:5 operator:@"-" answer:7];
    XCTAssertTrue([v configureWithProblem:p]);
    [v layoutIfNeeded];
    XCTAssertGreaterThan(v.subviews.count, 0);
}

- (void)testMakeTenRejectsSubtraction {
    MakeBreakTenHintView *v = [[MakeBreakTenHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)
                                                                      mode:MakeBreakTenModeMakeTen];
    ArithmeticProblem *p = [[ArithmeticProblem alloc] initWithNumber1:12 number2:5 operator:@"-" answer:7];
    XCTAssertFalse([v configureWithProblem:p]);
}

#pragma mark - View controller smoke

- (void)forceLoad:(UIViewController *)vc {
    vc.view.frame = CGRectMake(0, 0, 390, 844);  // iPhone 15 sized
    [vc viewWillAppear:NO];
    [vc.view layoutIfNeeded];
}

- (void)testMainMenuLoads {
    MainMenuViewController *vc = [[MainMenuViewController alloc] init];
    XCTAssertNoThrow([self forceLoad:vc]);
    XCTAssertGreaterThan(vc.view.subviews.count, 0);
}

- (void)testLessonsHomeLoads {
    LessonsHomeViewController *vc = [[LessonsHomeViewController alloc] init];
    XCTAssertNoThrow([self forceLoad:vc]);
}

- (void)testMultiplicationTableLoads {
    MultiplicationTableViewController *vc = [[MultiplicationTableViewController alloc] init];
    XCTAssertNoThrow([self forceLoad:vc]);
}

- (void)testLessonViewControllerLoadsAddSimple {
    NSArray<Lesson *> *all = [LessonCatalog addSubLessons];
    XCTAssertGreaterThan(all.count, 0);
    LessonViewController *vc = [[LessonViewController alloc] initWithLesson:all.firstObject];
    XCTAssertNoThrow([self forceLoad:vc]);
}

- (void)testLessonViewControllerLoadsMultiplication {
    NSArray<Lesson *> *all = [LessonCatalog multiplicationLessons];
    XCTAssertGreaterThan(all.count, 0);
    LessonViewController *vc = [[LessonViewController alloc] initWithLesson:all.firstObject];
    XCTAssertNoThrow([self forceLoad:vc]);
}

@end
