//
//  AQPlayer.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AQDownloader.h"
#import "AQConverter.h"

@protocol AQPlayerDelegate;

@interface AQPlayer : NSObject <AQDownloaderDelegate, AQConverterDelegate>

@property (nonatomic, assign) id<AQPlayerDelegate> delegate;
@property (nonatomic, strong) AQDownloader *downloader;
@property (nonatomic, strong) AQConverter *converter;

+ (void)playForeground;
+ (id)sharedAQPlayer;

- (void)clear;
- (void)play:(NSString*)url;

- (void)play;
- (void)stop;
- (void)seek:(NSTimeInterval)seekToTime;

- (void)selectIpodEQPreset:(NSInteger)index;
- (void)changeEQ:(int)index value:(CGFloat)v;

@end

@protocol AQPlayerDelegate <NSObject>

- (void)AQPlayer:(AQPlayer*)player duration:(NSTimeInterval)d zeroCurrentTime:(BOOL)flag;
- (void)AQPlayer:(AQPlayer*)player timerStop:(BOOL)flag;
- (void)AQPlayer:(AQPlayer*)player playNext:(BOOL)flag;

@end