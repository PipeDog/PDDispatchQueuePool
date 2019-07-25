//
//  PDDispatchQueuePool.m
//  PDDispatchQueuePool
//
//  Created by liang on 2019/7/25.
//  Copyright © 2019 liang. All rights reserved.
//

#import "PDDispatchQueuePool.h"
#import <UIKit/UIKit.h>
#import <stdatomic.h>

#define MAX_QUEUE_COUNT 16

static qos_class_t _NSQualityOfServiceToQOSClass(NSQualityOfService qos) {
    switch (qos) {
        case NSQualityOfServiceUserInteractive:
            return QOS_CLASS_USER_INTERACTIVE;
        case NSQualityOfServiceUserInitiated:
            return QOS_CLASS_USER_INITIATED;
        case NSQualityOfServiceUtility:
            return QOS_CLASS_UTILITY;
        case NSQualityOfServiceBackground:
            return QOS_CLASS_BACKGROUND;
        case NSQualityOfServiceDefault:
            return QOS_CLASS_DEFAULT;
        default:
            return QOS_CLASS_DEFAULT;
    }
}

static dispatch_queue_priority_t _NSQualityOfServiceToDispatchPriority(NSQualityOfService qos) {
    switch (qos) {
        case NSQualityOfServiceUserInteractive:
            return DISPATCH_QUEUE_PRIORITY_HIGH;
        case NSQualityOfServiceUserInitiated:
            return DISPATCH_QUEUE_PRIORITY_HIGH;
        case NSQualityOfServiceUtility:
            return DISPATCH_QUEUE_PRIORITY_LOW;
        case NSQualityOfServiceBackground:
            return DISPATCH_QUEUE_PRIORITY_BACKGROUND;
        case NSQualityOfServiceDefault:
            return DISPATCH_QUEUE_PRIORITY_DEFAULT;
        default:
            return DISPATCH_QUEUE_PRIORITY_DEFAULT;
    }
}

typedef struct {
    const char *name;
    void **queues;
    atomic_uint_least32_t queueCount;
    int32_t counter;
} _PDDispatchContext;

static _PDDispatchContext *_PDDispatchContextCreate(const char *name,
                                                    uint32_t queueCount,
                                                    NSQualityOfService qos) {
    _PDDispatchContext *context = calloc(1, sizeof(_PDDispatchContext));
    if (!context) { return NULL; }
    
    context->queues = calloc(queueCount, sizeof(void *));
    if (!context->queues) {
        free(context);
        return NULL;
    }
    
    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
        dispatch_qos_class_t qosClass = _NSQualityOfServiceToQOSClass(qos);
        
        for (NSUInteger i = 0; i < queueCount; i ++) {
            dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, qosClass, 0);
            dispatch_queue_t queue = dispatch_queue_create(name, attr);
            
            context->queues[i] = (__bridge_retained void *)queue;
        }
    } else {
        long identifier = _NSQualityOfServiceToDispatchPriority(qos);
        
        for (NSUInteger i = 0; i < queueCount; i ++) {
            dispatch_queue_t queue = dispatch_queue_create(name, DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(queue, dispatch_get_global_queue(identifier, 0));
            
            context->queues[i] = (__bridge_retained void *)queue;
        }
    }
    
    context->queueCount = queueCount;
    if (name) {
        context->name = strdup(name);
    }
    return context;
}

static void _PDDispatchContextRelease(_PDDispatchContext *context) {
    if (!context) { return; }
    
    if (context->queues) {
        for (NSUInteger i = 0; i < context->queueCount; i ++) {
            void *queuePtr = context->queues[i];
            dispatch_queue_t queue = (__bridge_transfer dispatch_queue_t)queuePtr;
            const char *name = dispatch_queue_get_label(queue);
            if (name) { strlen(name); }
            queue = nil;
        }
        free(context->queues);
        context->queues = NULL;
    }
    
    if (context->name) {
        free((void *)context->name);
    }
    
    free(context);
}

static dispatch_queue_t _PDDispatchContextGetQueue(_PDDispatchContext *context) {
    uint32_t counter = (uint32_t)atomic_fetch_add(&context->queueCount, 1);
    void *queue = context->queues[counter % context->queueCount];
    return (__bridge dispatch_queue_t)queue;
}

static _PDDispatchContext *_PDDispatchContextGetForQOS(NSQualityOfService qos) {
    static _PDDispatchContext *context[5] = {0};
    switch (qos) {
        case NSQualityOfServiceUserInteractive: {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                int count = (int)[NSProcessInfo processInfo].activeProcessorCount;
                count = count < 1 ? 1 : count > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : count;
                context[0] = _PDDispatchContextCreate("com.pipedog.user-interactive", count, qos);
            });
            return context[0];
        } break;
        case NSQualityOfServiceUserInitiated: {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                int count = (int)[NSProcessInfo processInfo].activeProcessorCount;
                count = count < 1 ? 1 : count > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : count;
                context[1] = _PDDispatchContextCreate("com.pipedog.user-initiated", count, qos);
            });
            return context[1];
        } break;
        case NSQualityOfServiceUtility: {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                int count = (int)[NSProcessInfo processInfo].activeProcessorCount;
                count = count < 1 ? 1 : count > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : count;
                context[2] = _PDDispatchContextCreate("com.pipedog.utility", count, qos);
            });
            return context[2];
        } break;
        case NSQualityOfServiceBackground: {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                int count = (int)[NSProcessInfo processInfo].activeProcessorCount;
                count = count < 1 ? 1 : count > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : count;
                context[3] = _PDDispatchContextCreate("com.pipedog.background", count, qos);
            });
            return context[3];
        } break;
        case NSQualityOfServiceDefault:
        default: {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                int count = (int)[NSProcessInfo processInfo].activeProcessorCount;
                count = count < 1 ? 1 : count > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : count;
                context[4] = _PDDispatchContextCreate("com.pipedog.default", count, qos);
            });
            return context[4];
        } break;
    }
}

@implementation PDDispatchQueuePool {
    @public
    _PDDispatchContext *_context;
}

- (void)dealloc {
    if (!_context) {
        _PDDispatchContextRelease(_context);
        _context = NULL;
    }
}

- (instancetype)initWithContext:(_PDDispatchContext *)context {
    self = [super init];
    if (!context) { return nil; }
    
    self->_context = context;
    _name = context->name ? [NSString stringWithUTF8String:context->name] : nil;
    return self;
}

- (instancetype)initWithName:(NSString *)name queueCount:(NSUInteger)queueCount qos:(NSQualityOfService)qos {
    if (queueCount == 0 || queueCount > MAX_QUEUE_COUNT) { return nil; }
    
    self = [super init];
    _context = _PDDispatchContextCreate(name.UTF8String, (uint32_t)queueCount, qos);
    if (!_context) { return nil; }
    
    _name = name;
    return self;
}

- (dispatch_queue_t)queue {
    return _PDDispatchContextGetQueue(_context);
}

+ (instancetype)defaultPoolForQOS:(NSQualityOfService)qos {
    switch (qos) {
        case NSQualityOfServiceUserInteractive: {
            static PDDispatchQueuePool *pool;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                pool = [[PDDispatchQueuePool alloc] initWithContext:_PDDispatchContextGetForQOS(qos)];
            });
            return pool;
        } break;
        case NSQualityOfServiceUserInitiated: {
            static PDDispatchQueuePool *pool;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                pool = [[PDDispatchQueuePool alloc] initWithContext:_PDDispatchContextGetForQOS(qos)];
            });
            return pool;
        } break;
        case NSQualityOfServiceUtility: {
            static PDDispatchQueuePool *pool;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                pool = [[PDDispatchQueuePool alloc] initWithContext:_PDDispatchContextGetForQOS(qos)];
            });
            return pool;
        } break;
        case NSQualityOfServiceBackground: {
            static PDDispatchQueuePool *pool;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                pool = [[PDDispatchQueuePool alloc] initWithContext:_PDDispatchContextGetForQOS(qos)];
            });
            return pool;
        } break;
        case NSQualityOfServiceDefault:
        default: {
            static PDDispatchQueuePool *pool;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                pool = [[PDDispatchQueuePool alloc] initWithContext:_PDDispatchContextGetForQOS(qos)];
            });
            return pool;
        } break;
    }
}

@end

dispatch_queue_t PDDispatchQueueGetForQOS(NSQualityOfService qos) {
    return _PDDispatchContextGetQueue(_PDDispatchContextGetForQOS(qos));
}
