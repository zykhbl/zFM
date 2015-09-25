//
//  AQRing.h
//  BLFM
//
//  Created by zykhbl on 14-2-2.
//  Copyright (c) 2014年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <pthread.h>

@interface AQRing : NSObject {
    int capacity;
    
    int readOffset;
    int writeOffset;
    
    void *container;
    
    pthread_mutex_t mutex;
    pthread_cond_t cond;
}

- (BOOL)isEmpty;
- (int)size;
- (void)putData:(const void*)inInputData numberBytes:(UInt32)inNumberBytes;
- (void)getData:(void*)outputData numberBytes:(int)outNumberBytes;

@end
