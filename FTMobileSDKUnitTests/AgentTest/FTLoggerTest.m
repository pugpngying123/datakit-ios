//
//  FTLoggerTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2021/6/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTDateUtil.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTJSONUtil.h>
#import <FTRecordModel.h>
#import "UITestVC.h"
#import "FTTrackDataManger+Test.h"

@interface FTLoggerTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UITestVC *testVC;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *appid;
@end

@implementation FTLoggerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    self.testVC = [[UITestVC alloc] init];
    
    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:self.testVC];
    self.navigationController.tabBarItem.title = @"UITestVC";
    
    UITableViewController *firstViewController = [[UITableViewController alloc] init];
    UINavigationController *firstNavigationController = [[UINavigationController alloc] initWithRootViewController:firstViewController];
    
    self.tabBarController.viewControllers = @[firstNavigationController, self.navigationController];
    self.window.rootViewController = self.tabBarController;
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    self.url = [processInfo environment][@"ACCESS_SERVER_URL"];
    self.appid = [processInfo environment][@"APP_ID"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    [[FTMobileAgent sharedInstance] resetInstance];
}
- (void)testEnableCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:1];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount=count+1);
}
- (void)testDisbleCustomLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = NO
    ;
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:1];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)testEnableTraceConsoleLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableConsoleLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<21; i++) {
        NSLog(@"testEnableTraceConsoleLog");
    }
    [NSThread sleepForTimeInterval:3];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count+20);
}
- (void)testDisableTraceConsoleLog{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableConsoleLog = NO;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<21; i++) {
        NSLog(@"testEnableTraceConsoleLog");
    }
    [NSThread sleepForTimeInterval:1];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count);
}
- (void)testDiscardNew{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscard;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<5030; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManger sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertTrue([model.data isEqualToString:@"testData0"]);

    XCTAssertTrue(newCount == 5000);
}

- (void)testDiscardOldBulk{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscardOldest;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];

    for (int i = 0; i<5045; i++) {
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManger sharedInstance] addTrackData:model type:FTAddDataLogging];

    }
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [[[FTTrackerEventDBTool sharedManger] getFirstRecords:1 withType:FT_DATA_TYPE_LOGGING] firstObject];
    XCTAssertFalse([model.data isEqualToString:@"testData0"]);
    XCTAssertTrue(newCount == 5000);
}
- (void)testCache{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.discardType = FTDiscardOldest;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    for (int i = 0; i<101; i++) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FTRecordModel *model = [FTRecordModel new];
        model.op = FT_DATA_TYPE_LOGGING;
        model.data = [NSString stringWithFormat:@"testData%d",i];
        [[FTTrackDataManger sharedInstance] addTrackData:model type:FTAddDataLogging];
    });
    }
    [NSThread sleepForTimeInterval:4];
    //如果不调用 -insertCacheToDB 方法 则数据库应该为100条数据
    NSInteger oldCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(oldCount == 100);
    [[FTTrackerEventDBTool sharedManger] insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == 101);
}
- (void)testPrefix{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableConsoleLog = YES;
    loggerConfig.prefix = @"debug";
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSLog(@"debug testDisableTraceConsoleLog");
    for (int i = 0; i<20; i++) {
        NSLog(@"testDisableTraceConsoleLog");
    }
    [NSThread sleepForTimeInterval:3];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount == count);
    for (int i = 0; i<20; i++) {
        NSLog(@"debug testDisableTraceConsoleLog");
    }
    [NSThread sleepForTimeInterval:3];
    NSInteger newCount2 =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount2 == count+20);

}
- (void)testLogLevelFilter{
    [self setRightSDKConfig];
    NSInteger count =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.logLevelFilter = @[@(FTStatusInfo)];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethod" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:1];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger newCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount>count);
    [[FTMobileAgent sharedInstance] logging:@"testLoggingMethodError" status:FTStatusError];
    [NSThread sleepForTimeInterval:1];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSInteger newCount2 =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
    XCTAssertTrue(newCount2 == newCount);

}
- (void)setRightSDKConfig{
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    config.enableSDKDebugLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] logout];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}
-(void)testSetEmptyLoggerServiceName{
    [self setRightSDKConfig];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:self.url];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
//    [FTMobileAgent sharedInstance].upTool.isUploading = YES;
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:1];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[@"tags"];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue(serviceName.length>0);
}

-(void)testSetLoggerServiceName{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.service = @"testSetServiceName";
    loggerConfig.enableCustomLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] logging:@"testSetEmptyServiceName" status:FTStatusInfo];
    [NSThread sleepForTimeInterval:2];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [array lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *op = dict[@"opdata"];
    NSDictionary *tags = op[@"tags"];
    NSString *serviceName = [tags valueForKey:FT_KEY_SERVICE];
    XCTAssertTrue([serviceName isEqualToString:@"testSetServiceName"]);
}
- (void)testEnableLinkRumData{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = YES;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];

    [NSThread sleepForTimeInterval:2];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags =opdata[@"tags"];
    XCTAssertTrue([tags.allKeys containsObject:@"session_id"]);
    XCTAssertTrue([tags.allKeys containsObject:@"session_type"]);
}
- (void)testDisableLinkRumData{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableLinkRumData = NO;
    loggerConfig.enableCustomLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:self.appid];
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [self.testVC view];
    [self.testVC viewDidAppear:NO];
    [[FTMobileAgent sharedInstance] logging:@"testEnableLinkRumData" status:FTStatusInfo];

    [NSThread sleepForTimeInterval:1];
    NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    FTRecordModel *model = [datas lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags =opdata[@"tags"];
    XCTAssertFalse([tags.allKeys containsObject:@"session_id"]);
    XCTAssertFalse([tags.allKeys containsObject:@"session_type"]);

}
- (void)testSampleRate0{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.samplerate = 0;
    loggerConfig.enableCustomLog = YES;
    loggerConfig.enableConsoleLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    [[FTMobileAgent sharedInstance] logging:@"testSampleRate0" status:FTStatusInfo];
    NSLog(@"testSampleRate0");
    [NSThread sleepForTimeInterval:2];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];

    XCTAssertTrue(oldDatas.count == newDatas.count);
}
- (void)testSampleRate100{
    [self setRightSDKConfig];
    FTLoggerConfig *loggerConfig = [[FTLoggerConfig alloc]init];
    loggerConfig.enableCustomLog = YES;
    loggerConfig.enableConsoleLog = YES;
    [[FTMobileAgent sharedInstance] startLoggerWithConfigOptions:loggerConfig];
    NSArray *oldDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    [[FTMobileAgent sharedInstance] logging:@"testSampleRate0" status:FTStatusInfo];
    NSLog(@"testSampleRate100");
    [NSThread sleepForTimeInterval:2];
    [[FTTrackerEventDBTool sharedManger]insertCacheToDB];
    NSArray *newDatas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_LOGGING];
    XCTAssertTrue(oldDatas.count+2 == newDatas.count);

}
@end
