//
//  PDDispatchQueuePool.h
//  PDDispatchQueuePool
//
//  Created by liang on 2019/7/25.
//  Copyright © 2019 liang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PDDispatchQueuePool : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)defaultPoolForQOS:(NSQualityOfService)qos;

- (instancetype)initWithName:(nullable NSString *)name queueCount:(NSUInteger)queueCount qos:(NSQualityOfService)qos;

@property (nonatomic, readonly) NSString *name;

- (dispatch_queue_t)queue;

@end

extern dispatch_queue_t PDDispatchQueueGetForQOS(NSQualityOfService qos);

NS_ASSUME_NONNULL_END
