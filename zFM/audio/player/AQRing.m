//
//  AQRing.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQRing.h"
#import <AudioUnit/AudioUnit.h>

#define kRingDefaultSize 1024 * 40

@implementation AQRing

@synthesize capacity;
@synthesize readOffset;
@synthesize writeOffset;
@synthesize container;
@synthesize mutex;
@synthesize cond;

- (void)dealloc {
    if (self.container != NULL) {
        free(self.container);
        self.container = NULL;
    }
    
    pthread_mutex_destroy(&mutex);
    pthread_cond_destroy(&cond);
}

- (id)init {
    self = [super init];
    
    if (self) {
        self.capacity = kRingDefaultSize;
        self.writeOffset = self.readOffset = 0;
        
        self.container = malloc(capacity * sizeof(AudioSampleType));
        
        pthread_mutex_init(&mutex, NULL);
        pthread_cond_init(&cond, NULL);
    }
    
    return self;
}

- (BOOL)isEmpty {
    return writeOffset == self.readOffset;
}

- (int)size {
    if (self.writeOffset > self.readOffset) {
        return self.writeOffset - self.readOffset;
    } else if (self.writeOffset < self.readOffset) {
        return self.capacity - (self.readOffset - self.writeOffset);
    } else {
        return 0;
    }
}

- (int)availableSpace {
    return self.capacity - [self size];
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
        int right = self.capacity - self.writeOffset;
        
        if (right >= inNumberBytes) {
            memcpy(self.container + self.writeOffset, inInputData, inNumberBytes);
            self.writeOffset += inNumberBytes;
            self.writeOffset %= self.capacity;
        } else {
            memcpy(self.container + self.writeOffset, inInputData, right);
            memcpy(self.container, inInputData + right, inNumberBytes - right);
            self.writeOffset = inNumberBytes - right;
            self.writeOffset %= self.capacity;
        }
    }
}

- (void)getData:(void*)outputData numberBytes:(int)outNumberBytes {
    pthread_mutex_lock(&mutex);
    
    if (self.writeOffset > self.readOffset) {
        memcpy(outputData, self.container + self.readOffset, outNumberBytes);
        self.readOffset += outNumberBytes;
        self.readOffset %= self.capacity;
    } else if (self.writeOffset < self.readOffset) {
        int right = self.capacity - self.readOffset;
        if (right >= outNumberBytes) {
            memcpy(outputData, self.container + self.readOffset, outNumberBytes);
            self.readOffset += outNumberBytes;
            self.readOffset %= self.capacity;
        } else {
            memcpy(outputData, self.container + self.readOffset, right);
            memcpy(outputData + right, self.container, outNumberBytes - right);
            self.readOffset = outNumberBytes - right;
            self.readOffset %= self.capacity;
        }
    }

    pthread_cond_signal(&cond);
    pthread_mutex_unlock(&mutex);
}

@end
