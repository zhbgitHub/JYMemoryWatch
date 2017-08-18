//
//  JYMemoryWatch.m
//  JYMemoryWatch
//
//  Created by 张波 on 17/08/11.
//  Copyright © 2017年 张波. All rights reserved.
//

#import "JYMemoryWatch.h"
#import <sys/sysctl.h>
#import <mach/mach.h>

@interface JYMemoryWatch ()

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UILabel *memoryLb;

@end

@implementation JYMemoryWatch
//1.单例模式
//2.对我提供一个api，开启方法，方法怎么实现的？通过GCD在全局并发队列
//3.关闭
#pragma mark -- life cycle
+ (id)sharedInstance
{
    __strong static JYMemoryWatch *_sharedObject = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark -- External service
- (void)jy_startWatchAndShowInStatusBar
{
    [self jy_startWatchTimer];
    [self jy_showMemoryViewInStatusBar];
}

- (void)jy_startWatchTimer
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerScheduled:) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
    });
}

- (void)jy_endWatch
{
    [self.timer invalidate];
    self.timer = nil;
}

- (void)jy_showMemoryViewInStatusBar
{
    UIWindow *kWindow = [UIApplication sharedApplication].keyWindow;
    [kWindow addSubview:self.memoryLb];
    [kWindow bringSubviewToFront:self.memoryLb];
}

#pragma mark -- private methods
- (void)timerScheduled:(NSTimer *)timer
{
    double availableMemory = [self availableMemory];
    double usedMemory = [self usedMemory];
    double memoryUsedPercentage = [self memoryUsedPercentage];
    self.memoryLb.text = [NSString stringWithFormat:@"可用:%.2f 已用:%.2f 率:%.2f%%",availableMemory, usedMemory, memoryUsedPercentage];
}

#pragma mark -- getters and setters

- (UILabel *)memoryLb
{
    if (_memoryLb == nil) {
        _memoryLb = [[UILabel alloc] init];
        CGFloat x = UIScreen.mainScreen.bounds.size.width * 0.55f;
        CGFloat w = UIScreen.mainScreen.bounds.size.width * 0.45f - 35.f;
        _memoryLb.frame = CGRectMake(x, 0, w, 20.f);
        _memoryLb.backgroundColor = [UIColor yellowColor];
        _memoryLb.textAlignment = NSTextAlignmentRight;
        _memoryLb.textColor = [UIColor redColor];
        _memoryLb.font = [UIFont systemFontOfSize:9.f];
    }
    return _memoryLb;
}

/**
 获取总内存大小（单位：MB）
 
 @return double MB
 */
- (double)totalMemory
{
    return ([NSProcessInfo processInfo].physicalMemory) / 1024.0 / 1024.0;
}

/**
 获取当前设备可用内存(单位：MB）
 
 @return double MB
 */
- (double)availableMemory
{
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(),
                                               HOST_VM_INFO,
                                               (host_info_t)&vmStats,
                                               &infoCount);
    
    if (kernReturn == KERN_SUCCESS) {
        return ((vm_page_size *vmStats.free_count + vm_page_size * vmStats.inactive_count) / 1024.0) / 1024.0;
        //        return ((vm_page_size *vmStats.free_count) / 1024.0) / 1024.0;
    }
    return 0.0f;
}

/**
 获取当前任务所占用的内存（单位：MB）
 
 @return double MB
 */
- (double)usedMemory
{
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(),
                                         TASK_BASIC_INFO,
                                         (task_info_t)&taskInfo,
                                         &infoCount);
    
    if (kernReturn == KERN_SUCCESS) {
        return taskInfo.resident_size / 1024.0 / 1024.0;
    }
    return 0.0f;
}

/**
 当前内存使用率
 
 @return double
 */
- (double)memoryUsedPercentage
{
    return [self usedMemory] / [self totalMemory];
}

@end
