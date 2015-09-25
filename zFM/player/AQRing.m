//
//  AQRing.m
//  BLFM
//
//  Created by zykhbl on 14-2-2.
//  Copyright (c) 2014年 zykhbl. All rights reserved.
//

#import "AQRing.h"
#import <AudioUnit/AudioUnit.h>

#define kRingDefaultSize 1024 * 10

@implementation AQRing

- (void)dealloc {
    if (container != NULL) {
        free(container);
        container = NULL;
    }
    
    pthread_mutex_destroy(&mutex);
    pthread_cond_destroy(&cond);
}

- (id)init {
    if (self) {
        capacity = kRingDefaultSize;
        writeOffset = readOffset = 0;
        
        container = malloc(capacity * sizeof(AudioSampleType));
        
        pthread_mutex_init(&mutex, NULL);
        pthread_cond_init(&cond, NULL);
    }
    
    return self;
}

- (BOOL)isEmpty {
    return writeOffset == readOffset;
}

- (int)size {
    if (writeOffset > readOffset) {
        return writeOffset - readOffset;
    } else if (writeOffset < readOffset) {
        return capacity - (readOffset - writeOffset);
    } else {
        return 0;
    }
}

- (int)availableSpace {
    return capacity - [self size];
}

- (void)putData:(const void*)inInputData numberBytes:(UInt32)inNumberBytes {
    pthread_mutex_lock(&mutex);
    
    int space = [self availableSpace];
    while (space <= inNumberBytes) {
        pthread_cond_wait(&cond, &mutex);
        space = [self availableSpace];
    }
    
    pthread_mutex_unlock(&mutex);
    
    if (space > inNumberBytes) {
        int right = capacity - writeOffset;
        
        if (right >= inNumberBytes) {
            memcpy(container + writeOffset, inInputData, inNumberBytes);
            writeOffset += inNumberBytes;
            writeOffset %= capacity;
        } else {
            memcpy(container + writeOffset, inInputData, right);
            memcpy(container, inInputData + right, inNumberBytes - right);
            writeOffset = inNumberBytes - right;
            writeOffset %= capacity;
        }
    }
}

- (void)getData:(void*)outputData numberBytes:(int)outNumberBytes {
    pthread_mutex_lock(&mutex);
    
    if (writeOffset > readOffset) {
        memcpy(outputData, container + readOffset, outNumberBytes);
        readOffset += outNumberBytes;
        readOffset %= capacity;
    } else if (writeOffset < readOffset) {
        int right = capacity - readOffset;
        if (right >= outNumberBytes) {
            memcpy(outputData, container + readOffset, outNumberBytes);
            readOffset += outNumberBytes;
            readOffset %= capacity;
        } else {
            memcpy(outputData, container + readOffset, right);
            memcpy(outputData + right, container, outNumberBytes - right);
            readOffset = outNumberBytes - right;
            readOffset %= capacity;
        }
    }

    pthread_cond_signal(&cond);
    pthread_mutex_unlock(&mutex);
}

@end
