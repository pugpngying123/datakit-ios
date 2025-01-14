//
//  FTWKWebViewTraceTest.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/18.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestWKWebViewVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTBaseInfoHander.h>
#import <FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTConstants.h>
#import <FTBaseInfoHander.h>
#import <FTRecordModel.h>
#import <FTMonitorManager.h>
#import <FTDateUtil.h>
#import <FTJSONUtil.h>
#import "TestWKParentVC.h"
#import "FTTrackDataManger+Test.h"
@interface FTWKWebViewTraceTest : XCTestCase
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) TestWKWebViewVC *testVC;
@property (nonatomic, strong) TestWKParentVC *testParentVC;

@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) UITabBarController *tabBarController;
@end

@implementation FTWKWebViewTraceTest

- (void)setUp {
   
}
- (void)setWKWebview{
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = [UIColor whiteColor];

    self.tabBarController = [[UITabBarController alloc] init];
    
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
    self.window.rootViewController = self.navigationController;
}
- (void)setTraceConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [self setWKWebview];
}
- (void)setNoTraceConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMonitorManager sharedInstance] setMobileConfig:config];
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
    [self setWKWebview];
}

- (void)testNoTrace{
    self.testVC =  [[TestWKWebViewVC alloc] init];
    [self.navigationController pushViewController:self.testVC animated:YES];
    [self.testVC viewDidLoad];
    [self setNoTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    [self.testVC ft_load:@"https://auth.dataflux.cn/loginpsw"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
        XCTAssertTrue(newCount-lastCount == 0);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [self.testVC ft_stopLoading];

    self.testVC = nil;
}

/**
 * 使用 loadRequest 方法发起请求 之后页面跳转 nextLink
 * 验证：nextLink logging数据不增加
 * metrics 中也能采集到 nextLink 请求状态（成功/失败）、请求时间（loading/loadCompleted）
 *
*/
- (void)testWKWebViewNextLink{
    [self setTraceConfig];
    self.testVC =  [[TestWKWebViewVC alloc] init];
    [self.navigationController pushViewController:self.testVC animated:YES];
    [self.testVC viewDidLoad];
    [self.testVC setDelegateSelf];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    __block NSInteger lastLoggingCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://www.baidu.com"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger loggingcount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
        
        XCTAssertTrue(loggingcount>lastLoggingCount);
        lastLoggingCount = loggingcount;
        [self.testVC ft_testNextLink];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [expectation fulfill];
             });
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
    NSInteger newLoggingCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newLoggingCount == lastLoggingCount);
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
- (void)testWKWebViewParentLoad{
    self.testParentVC =  [[TestWKParentVC alloc] init];
    [self.navigationController pushViewController:self.testParentVC animated:YES];
    [self.testParentVC viewDidLoad];
    [self setTraceConfig];
    [self.testParentVC setDelegateProxy];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    __block NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testParentVC ft_load:@"https://auth.dataflux.cn/loginpsw"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
        XCTAssertTrue(newCount-lastCount == 1);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
    self.testParentVC = nil;
}
- (void)testWKWebViewProxytLoad{
    [self setTraceConfig];
    self.testParentVC =  [[TestWKParentVC alloc] init];
    [self.navigationController pushViewController:self.testParentVC animated:YES];
    [self.testParentVC viewDidLoad];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self.testParentVC setDelegateProxy];

    __block NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testParentVC ft_load:@"https://auth.dataflux.cn/loginpsw"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
        XCTAssertTrue(newCount-lastCount == 1);
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    self.testParentVC = nil;
  
}
/**
 * 使用 loadRequest 方法发起请求 之后页面跳转 nextLink 再进行reload
 * 验证：reload 时 发起的请求 能新增trace数据，header中都添加数据
 * reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url、spanid 都不一致
*/
- (void)testWKWebViewReloadNextLink{
    [self setTraceConfig];
    self.testVC =  [[TestWKWebViewVC alloc] init];
    [self.navigationController pushViewController:self.testVC animated:YES];
    [self.testVC viewDidLoad];
    [self.testVC setDelegateSelf];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://auth.dataflux.cn/loginpsw"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.testVC ft_testNextLink];
        [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:5];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newCount-lastCount == 2);
    NSArray *array = [[FTTrackerEventDBTool sharedManger]getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *reloadModel = [array lastObject];
    FTRecordModel *model = [array objectAtIndex:array.count-2];
    __block NSString *reloadUrl;
    __block NSString *reloadSpanID;
    [self getX_B3_SpanId:reloadModel completionHandler:^(NSString *spanID, NSString *urlStr) {
        reloadUrl = urlStr;
        reloadSpanID = spanID;
    }];
    [self getX_B3_SpanId:model completionHandler:^(NSString *spanID, NSString *urlStr) {
        XCTAssertFalse([reloadUrl isEqualToString:urlStr]);
        XCTAssertFalse([reloadSpanID isEqualToString:spanID]);
    }];
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
/**
 * loadRequest 方法发起请求
 * 验证： reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url一致 spanid 不一致
*/
- (void)testWKWebViewReloadTrace{
    [self setTraceConfig];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    self.testVC =  [[TestWKWebViewVC alloc] init];
    [self.navigationController pushViewController:self.testVC animated:YES];
    [self.testVC viewDidLoad];
    [self.testVC setDelegateSelf];
    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://baidu.com"];
   
    [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:8];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newCount-lastCount == 2);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *reloadModel = [array lastObject];
    FTRecordModel *model = [array objectAtIndex:array.count-2];
    __block NSString *reloadUrl;
    __block NSString *reloadSpanID;
    [self getX_B3_SpanId:reloadModel completionHandler:^(NSString *spanID, NSString *urlStr) {
        reloadUrl = urlStr;
        reloadSpanID = spanID;
    }];
    [self getX_B3_SpanId:model completionHandler:^(NSString *spanID, NSString *urlStr) {
        XCTAssertTrue([reloadUrl isEqualToString:urlStr]);
        XCTAssertFalse([reloadSpanID isEqualToString:spanID]);
    }];
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
/**
 * 使用 loadRequest 方法发起请求 之后页面跳转再回退到初始页面 再进行reload
 * 验证：reload 时 发起的请求 都能新增trace数据，header中都添加数据
 * reload 后 新的trace数据 的url 与ft_loadRequest产生的trace数据 url 一致 ，spanid 不一致
*/
- (void)testWKWebViewGobackReloadTrace{
    self.testVC =  [[TestWKWebViewVC alloc] init];
    [self.navigationController pushViewController:self.testVC animated:YES];
    [self.testVC viewDidLoad];
    [self setTraceConfig];
    [self.testVC setDelegateSelf];

    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    NSInteger lastCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    [self.testVC ft_load:@"https://dataflux.cn"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.testVC ft_testNextLink];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.testVC.webView goBack];
            [self performSelector:@selector(webviewReload:) withObject:expectation afterDelay:5];
        });
    });
    [self waitForExpectationsWithTimeout:45 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    NSInteger newCount = [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newCount-lastCount == 2);
    NSArray *array = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *reloadModel = [array lastObject];
    FTRecordModel *model = [array objectAtIndex:array.count-2];
    __block NSString *reloadUrl;
    __block NSString *reloadSpanID;
    [self getX_B3_SpanId:reloadModel completionHandler:^(NSString *spanID, NSString *urlStr) {
        reloadUrl = urlStr;
        reloadSpanID = spanID;
    }];
    [self getX_B3_SpanId:model completionHandler:^(NSString *spanID, NSString *urlStr) {
        XCTAssertTrue([reloadUrl isEqualToString:urlStr]);
        XCTAssertFalse([reloadSpanID isEqualToString:spanID]);
    }];
    [self.testVC ft_stopLoading];
    self.testVC = nil;
}
- (void)webviewReload:(XCTestExpectation *)expection{
    [self.testVC ft_reload];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [expection fulfill];
      });
}
- (void)getX_B3_SpanId:(FTRecordModel *)model completionHandler:(void (^)(NSString *spanID,NSString *urlStr))completionHandler{
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = [dict valueForKey:@"opdata"];
    NSDictionary *field = [opdata valueForKey:@"field"];
    NSDictionary *content = [FTJSONUtil dictionaryWithJsonString:[field valueForKey:@"message"]];
    NSDictionary *requestContent = [content valueForKey:@"requestContent"];
    NSDictionary *headers = [requestContent valueForKey:@"headers"];
    completionHandler?completionHandler([headers valueForKey:@"X-B3-SpanId"],[requestContent valueForKey:@"url"]):nil;
}
@end
