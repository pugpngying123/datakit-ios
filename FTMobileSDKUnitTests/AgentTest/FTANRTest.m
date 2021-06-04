//
//  FTANRTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/10/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestANRVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import "FTUploadTool+Test.h"
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
#import <FTMobileAgent/FTRecordModel.h>
#import <FTJSONUtil.h>
#import <FTMobileAgent/FTConstants.h>

@interface FTANRTest : XCTestCase
@property (nonatomic, strong) TestANRVC *testVC;

@end

@implementation FTANRTest

- (void)setUp {
    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[TestANRVC alloc] init];
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:self.testVC];
    navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    tabBarController.viewControllers = @[firstNavigationController, navigationController];
    window.rootViewController = tabBarController;
    
    [self.testVC view];
    [self.testVC viewWillAppear:NO];
    
}
- (void)initSDKWithEnableTrackAppANR:(BOOL)enable{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    config.appid =appid;
    if (enable) {
        config.enableTrackAppANR = YES;
        config.enableTrackAppFreeze = YES;
    }
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[[NSDate date] ft_dateTimestamp]];
}
- (void)testTraceAnrBlock{
    [self initSDKWithEnableTrackAppANR:YES];
    [self.testVC viewDidAppear:NO];
    [NSThread sleepForTimeInterval:2];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_RUM];
    [self.testVC testAnrBlock];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_RUM];
        XCTAssertTrue(newCount-lastCount>0);

        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_RUM];

        for (NSInteger i=0; i<datas.count; i++) {
           FTRecordModel *model = datas[i];
           NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
            NSDictionary *opdata = [dict valueForKey:@"opdata"];

            NSString *measurement = opdata[@"measurement"];
            if ([measurement isEqualToString:@"long_task"]) {
                NSDictionary *field = [opdata valueForKey:@"field"];
                XCTAssertTrue([field.allKeys containsObject:@"long_task_stack"]&&[field.allKeys containsObject:@"duration"]);
                //[field.allKeys containsObject:@"long_task_message"]
            }
        }
        [expect fulfill];
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
//    [[FTMobileAgent sharedInstance] resetInstance];
}

- (void)testNoTraceAnrBlock{
    [self initSDKWithEnableTrackAppANR:NO];
    [NSThread sleepForTimeInterval:2];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC testAnrBlock];
    XCTestExpectation *expect = [self expectationWithDescription:@"请求超时timeout!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
        XCTAssertTrue(newCount == lastCount);
        [expect fulfill];
        
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [[FTMobileAgent sharedInstance] resetInstance];
}
@end
