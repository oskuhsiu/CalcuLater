#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "ArithmeticProblem.h"
#import "SubtractionHintView.h"

@interface SubtractionHintViewTests : XCTestCase
@end

@implementation SubtractionHintViewTests

- (ArithmeticProblem *)minus:(NSInteger)a sub:(NSInteger)b {
    return [[ArithmeticProblem alloc] initWithNumber1:a number2:b operator:@"-" answer:a - b];
}

- (void)testConfigureWithSubtractionReturnsYes {
    SubtractionHintView *v = [[SubtractionHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    BOOL ok = [v configureWithProblem:[self minus:102 sub:38]];
    XCTAssertTrue(ok);
    [v layoutIfNeeded];
    XCTAssertGreaterThan(v.subviews.count, 0);
}

- (void)testRejectsAddition {
    SubtractionHintView *v = [[SubtractionHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    ArithmeticProblem *p = [[ArithmeticProblem alloc] initWithNumber1:1 number2:2 operator:@"+" answer:3];
    XCTAssertFalse([v configureWithProblem:p]);
}

- (void)testBorrowThroughZero {
    SubtractionHintView *v = [[SubtractionHintView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
    XCTAssertTrue([v configureWithProblem:[self minus:1000 sub:1]]);
    [v layoutIfNeeded];
}

- (void)testTypicalChainedBorrow {
    SubtractionHintView *v = [[SubtractionHintView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
    XCTAssertTrue([v configureWithProblem:[self minus:50 sub:27]]);
    [v layoutIfNeeded];
}

- (void)testRejectsNegativeResult {
    SubtractionHintView *v = [[SubtractionHintView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
    ArithmeticProblem *p = [[ArithmeticProblem alloc] initWithNumber1:5 number2:10 operator:@"-" answer:-5];
    XCTAssertFalse([v configureWithProblem:p]);
}

@end
