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

@property (nonatomic, weak) id<AQConverterDelegate> delegate;

- (void)doConvertFile:(NSString*)url;
- (void)signal;

- (void)play;
- (void)stop;
- (void)seek:(NSTimeInterval)seekToTime;

- (void)setContentLength:(off_t)len;
- (void)setBytesCanRead:(off_t)bytes;
- (void)setStopRunloop:(BOOL)stop;

- (void)selectIpodEQPreset:(NSInteger)index;
- (void)changeEQ:(int)index value:(CGFloat)v;

@end

@protocol AQConverterDelegate <NSObject>

- (void)AQConverter:(AQConverter*)converter duration:(NSTimeInterval)duration zeroCurrentTime:(BOOL)flag;
- (void)AQConverter:(AQConverter*)converter timerStop:(BOOL)flag;
- (void)AQConverter:(AQConverter*)converter playNext:(BOOL)flag;

@end