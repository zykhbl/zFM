//
//  AQRing.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <pthread.h>

@interface AQRing : NSObject

@property (nonatomic, assign) int capacity;
@property (nonatomic, assign) int readOffset;
@property (nonatomic, assign) int writeOffset;
@property (nonatomic, assign) void *container;
@property (nonatomic, assign) pthread_mutex_t mutex;
@property (nonatomic, assign) pthread_cond_t cond;

- (BOOL)isEmpty;
- (int)size;
- (void)putData:(const void*)inInputData numberBytes:(UInt32)inNumberBytes;
- (void)getData:(void*)outputData numberBytes:(int)outNumberBytes;

@end
