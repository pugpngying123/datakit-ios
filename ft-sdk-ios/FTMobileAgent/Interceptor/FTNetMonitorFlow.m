//
//  network.m
//  testdemo
//
//  Created by 胡蕾蕾 on 2020/1/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTNetMonitorFlow.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
@interface FTNetMonitorFlow ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign)long long int lastBytes;

@end
@implementation FTNetMonitorFlow

-(void)startMonitor{
    self.lastBytes = [self getInterfaceBytes];
    self.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(refreshFlow) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
}
-(void)stopMonitor{
    [self.timer invalidate];
}
- (void)refreshFlow{
    long long int rate = 0;
    long long int currentBytes = [self getInterfaceBytes];
    
    if(self.lastBytes) {
     //用上当前的下行总流量减去上一秒的下行流量达到下行速录
        rate = currentBytes -self.lastBytes;
    }
    self.lastBytes = currentBytes;
    NSString *flow = [self formatNetWork:rate];
    if (self.updateNetFlowBlock) {
        self.updateNetFlowBlock(flow);
    }
}
- (long long) getInterfaceBytes {
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1) {
        return 0;
    }
    uint32_t iBytes = 0;
    uint32_t oBytes = 0;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;
        if (ifa->ifa_data == 0)
            continue;
        /* Not a loopback device. */
        if (strncmp(ifa->ifa_name, "lo", 2)){
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            iBytes += if_data->ifi_ibytes;
            
            oBytes += if_data->ifi_obytes;
        }
    }
    freeifaddrs(ifa_list);
    NSLog(@"\n[getInterfaceBytes-Total]%d,%d",iBytes,oBytes);
    return iBytes + oBytes;
}

- (NSString *)formatNetWork:(long long int)rate {
    if (rate <1024) {
        return [NSString stringWithFormat:@"%lldB/秒", rate];
    } else if (rate >=1024&& rate <1024*1024) {
        return [NSString stringWithFormat:@"%.1fKB/秒", (double)rate /1024];
    } else if (rate >=1024*1024&& rate <1024*1024*1024) {
        return [NSString stringWithFormat:@"%.2fMB/秒", (double)rate / (1024*1024)];
    } else {
        return@"10Kb/秒";
    };
}
@end