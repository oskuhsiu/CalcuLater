//
//  Calcu_LaterUITestsLaunchTests.m
//  Calcu LaterUITests
//
//  Created by darkness on 2025/8/7.
//

#import <XCTest/XCTest.h>

@interface Calcu_LaterUITestsLaunchTests : XCTestCase

@end

@implementation Calcu_LaterUITestsLaunchTests

+ (BOOL)runsForEachTargetApplicationUIConfiguration {
    return NO;
}

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)testLaunch {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    // Insert steps here to perform after app launch but before taking a screenshot,
    // such as logging into a test account or navigating somewhere in the app

    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    attachment.name = @"Launch Screen";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

@end
