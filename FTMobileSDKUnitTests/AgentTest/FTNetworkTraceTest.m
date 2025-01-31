//
//  NetworkTraceTest.m
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/27.
//  Copyright © 2020 hll. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTMobileAgent+Private.h>
#import <FTMobileAgent/FTMonitorManager.h>
#import <FTMobileAgent/FTConstants.h>
#import <NSString+FTAdd.h>
#import "OHHTTPStubs.h"
#import <NSURLRequest+FTMonitor.h>
#import <FTMobileAgent/FTMonitorUtils.h>
#import "FTTrackerEventDBTool+Test.h"
#import <FTRecordModel.h>
#import <FTBaseInfoHander.h>
#import <FTDateUtil.h>
#import "FTSessionConfiguration+Test.h"
#import <FTMobileAgent/FTConstants.h>
#import <FTJSONUtil.h>
#import "FTTrackDataManger+Test.h"
#import <FTRequest.h>
#import <FTNetworkManager.h>
@interface FTNetworkTraceTest : XCTestCase<NSURLSessionDelegate>
@end

@implementation FTNetworkTraceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [[FTTrackerEventDBTool sharedManger] deleteItemWithTm:[FTDateUtil currentTimeNanosecond]];
}

- (void)tearDown {
    [[FTMobileAgent sharedInstance] resetInstance];
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)setNetworkTraceType:(FTNetworkTraceType)type{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.networkTraceType = type;
    traceConfig.service = @"iOSTestService";
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
}

- (void)testFTNetworkTrackTypeZipkin{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeZipkin];
    [self networkUpload:@"Zipkin" handler:^(NSDictionary *header) {
        NSString *traceId = [header valueForKey:FT_NETWORK_ZIPKIN_TRACEID];
        NSString *spanID = [header valueForKey:FT_NETWORK_ZIPKIN_SPANID];
        NSString *sampled = [header valueForKey:FT_NETWORK_ZIPKIN_SAMPLED];
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_ZIPKIN_TRACEID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SPANID]&&[header.allKeys containsObject:FT_NETWORK_ZIPKIN_SAMPLED]);
        XCTAssertEqualObjects(sampled, @"1");
        XCTAssertTrue(traceId.length == 32 && spanID.length == 16);
        XCTAssertTrue([traceId.lowercaseString isEqualToString:traceId] && [spanID.lowercaseString isEqualToString:spanID]);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeJaeger{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeJaeger];
    [self networkUpload:@"Jaeger" handler:^(NSDictionary *header) {
        NSString *trace =header[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [trace componentsSeparatedByString:@":"];
        NSString *traceId = [traceAry firstObject];
        NSString *spanID =traceAry[1];
        NSString *sampled = [traceAry lastObject];
        XCTAssertTrue(traceId.length == 32 && spanID.length == 16);
        XCTAssertTrue([traceId.lowercaseString isEqualToString:traceId] && [spanID.lowercaseString isEqualToString:spanID]);
        XCTAssertEqualObjects(sampled, @"1");
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
- (void)testFTNetworkTrackTypeDDtrace{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    [self networkUpload:@"Jaeger" handler:^(NSDictionary *header) {
       
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]);
        XCTAssertTrue([header.allKeys containsObject:FT_NETWORK_DDTRACE_ORIGIN]&&[header[FT_NETWORK_DDTRACE_ORIGIN] isEqualToString:@"rum"]);

        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}

- (void)testSampleRate0{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.samplerate = 0;
    traceConfig.service = @"iOSTestService";
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_TRACING];

    [self networkUpload:@"" handler:^(NSDictionary *header) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    
    [NSThread sleepForTimeInterval:2];
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newArray.count == oldArray.count);

}
- (void)testSampleRate100{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url];
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.samplerate = 100;
    traceConfig.service = @"iOSTestService";
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startTraceWithConfigOptions:traceConfig];
    NSArray *oldArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_TRACING];

    [self networkUpload:@"" handler:^(NSDictionary *header) {
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    
    NSArray *newArray = [[FTTrackerEventDBTool sharedManger] getFirstRecords:100 withType:FT_DATA_TYPE_TRACING];
    XCTAssertTrue(newArray.count > oldArray.count);

}
- (void)networkUpload:(NSString *)str handler:(void (^)(NSDictionary *header))completionHandler{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    __block NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSDictionary *header = task.currentRequest.allHTTPHeaderFields;
        completionHandler?completionHandler(header):nil;
    }];
    
    [task resume];
}
-(void)setBadNetOHHTTPStubs{
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSURL *url = [NSURL URLWithString:urlStr];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:url.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        NSError* notConnectedError = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorTimedOut userInfo:@{NSLocalizedDescriptionKey:@"time out"}];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
    }];
}
- (void)testTimeOut{
    [self setNetworkTraceType:FTNetworkTraceTypeZipkin];
    [self setBadNetOHHTTPStubs];
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self networkUpload:@"SKYWALKING_V3" handler:^(NSDictionary *header) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSDictionary *tags = opdata[@"tags"];
    NSString *status = tags[@"status"];
    XCTAssertTrue([status isEqualToString:@"error"]);
    NSDictionary *content = [FTJSONUtil dictionaryWithJsonString:field[@"message"]];
    NSDictionary *responseContent = content[@"responseContent"];
    NSDictionary *error = responseContent[@"error"];
    NSNumber *errorCode = error[@"errorCode"];
    XCTAssertTrue([errorCode isEqualToNumber:@-1001]);
    [self uploadModel:model];
}
- (void)testRightRequest{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];

    [self setNetworkTraceType:FTNetworkTraceTypeJaeger];
    [self networkUpload:@"testRightRequest" handler:^(NSDictionary *header) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[@"tags"];
    BOOL isError = [tags[@"__isError"] boolValue];
    XCTAssertTrue(isError == NO);
    [self uploadModel:model];
}
- (void)testNewThread{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTraceTypeJaeger];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self networkUpload:@"testNewThread" handler:^(NSDictionary *header) {
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];
    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[@"tags"];
    NSString *status = tags[@"status"];
    XCTAssertTrue([status isEqualToString:@"ok"]);

    [self uploadModel:model];
}

- (void)testBadResponse{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTraceTypeDDtrace];
    NSString *uuid = [NSUUID UUID].UUIDString;

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
    NSString *urlStr = @"http://api.qingyunke.com/api.php1";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];

    request.HTTPMethod = @"POST";

    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];

    [task resume];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];

    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *field = opdata[@"field"];
    NSDictionary *tags = opdata[@"tags"];
    NSString *status = tags[@"status"];
    XCTAssertTrue([status isEqualToString:@"error"]);
    [self uploadModel:model];
}
- (void)testNSURLConnection{
    XCTestExpectation *expectation= [self expectationWithDescription:@"异步操作timeout"];
    [self setNetworkTraceType:FTNetworkTraceTypeZipkin];
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
    [NSThread sleepForTimeInterval:2];

    NSArray *data = [[FTTrackerEventDBTool sharedManger] getFirstRecords:10 withType:FT_DATA_TYPE_TRACING];
    FTRecordModel *model = [data lastObject];
    NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:model.data];
    NSDictionary *opdata = dict[@"opdata"];
    NSDictionary *tags = opdata[@"tags"];
    NSString *status = tags[@"status"];
    XCTAssertTrue([status isEqualToString:@"ok"]);

    [self uploadModel:model];
}
- (void)uploadModel:(FTRecordModel *)model{
    XCTestExpectation *expectation2= [self expectationWithDescription:@"异步操作timeout"];
    FTRequest *request = [[FTRequest alloc]initWithEvents:@[model] type:FT_DATA_TYPE_TRACING];
    [[FTNetworkManager sharedInstance] sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
       
        NSInteger statusCode = httpResponse.statusCode;
        BOOL success = (statusCode >=200 && statusCode < 500);
        XCTAssertTrue(success);
        [expectation2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        XCTAssertNil(error);
    }];
}
@end
