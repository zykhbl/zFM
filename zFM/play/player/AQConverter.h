//
//  AQConverter.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <pthread.h>

@protocol AQConverterDelegate;

@interface AQConverter : NSObject

@property (nonatomic, assign) id<AQConverterDelegate> delegate;

- (void)doConvertFile:(NSString*)url;
- (void)signal;

- (void)play;
- (void)pause;
- (void)setBytesCanRead:(off_t)bytes;
- (void)seek:(off_t)offset;

- (void)selectIpodEQPreset:(NSInteger)index;

@end

@protocol AQConverterDelegate <NSObject>

- (void)AQConverter:(AQConverter*)converter audioDataOffset:(UInt64)dataOffset bitRate:(UInt32)bRate;
- (void)AQConverter:(AQConverter*)converter timerStop:(BOOL)flag;

@end