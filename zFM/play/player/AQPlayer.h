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
@property (nonatomic, assign) UInt64 audioDataOffset;
@property (nonatomic, assign) UInt32 bitRate;

+ (void)playForeground;
+ (id)sharedAQPlayer;

- (void)cancel;
- (void)play:(NSString*)url;

- (void)play;
- (void)pause;
- (void)seek:(CGFloat)value;

- (void)selectIpodEQPreset:(NSInteger)index;

@end

@protocol AQPlayerDelegate <NSObject>

- (void)AQPlayer:(AQPlayer*)player duration:(NSTimeInterval)d;
- (void)AQPlayer:(AQPlayer*)player timerStop:(BOOL)flag;

@end