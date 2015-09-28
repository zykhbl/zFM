//
//  AQPlayer.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQPlayer.h"
#import <AVFoundation/AVFoundation.h>

static AQPlayer *player = nil;

@implementation AQPlayer

@synthesize delegate;
@synthesize downloader;
@synthesize bgConvertThread;
@synthesize converter;
@synthesize audioDataOffset;
@synthesize bitRate;

+ (void)playForeground {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
}

+ (AQPlayer*)getPlayer {
    return player;
}

- (void)dealloc {
    NSLog(@"++++++++++ AQPlayer dealloc! ++++++++++ \n");
    
    if (self.bgConvertThread) {
        [self.bgConvertThread cancel];
    }
    
    player = nil;
}

- (id)init {
    self = [super init];
    if (self) {
        player = self;
    }
    return self;
}

- (void)play:(NSString*)url {
    if (self.downloader == nil) {
        self.downloader = [[AQDownloader alloc] init];
        self.downloader.delegate = self;
    }
    
    [self.downloader download:url];
}

- (void)play {
    [self.converter play];
}

- (void)pause {
    [self.converter pause];
}

- (void)seek:(CGFloat)value {
    off_t offset = self.audioDataOffset + (self.downloader.contentLength - self.audioDataOffset) * value;
    [self.converter setBytesCanRead:self.downloader.bytesReceived];
    [self.converter seek:offset];
}

- (void)selectIpodEQPreset:(NSInteger)index {
    if (self.converter != nil) {
        [self.converter selectIpodEQPreset:index];
    }    
}

//===========protocol AQDownloaderDelegate===========
- (void)convertOnThread:(NSString*)filePath {
    if (self.converter == nil) {
        self.converter = [[AQConverter alloc] init];
        self.converter.delegate = self;
    }
    [self.converter doConvertFile:filePath];
}

- (void)AQDownloader:(AQDownloader*)downloader convert:(NSString*)filePath {
    self.bgConvertThread = [[NSThread alloc] initWithTarget:self selector:@selector(convertOnThread:) object:filePath];
    [self.bgConvertThread start];
}

- (void)AQDownloader:(AQDownloader*)downloader signal:(BOOL)flag {
    [self.converter setBytesCanRead:self.downloader.bytesReceived];
    [self.converter signal];
}

//===========AQConverterDelegate===========
- (void)AQConverter:(AQConverter*)converter audioDataOffset:(UInt64)dataOffset bitRate:(UInt32)bRate {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQPlayer:duration:)]) {
        self.audioDataOffset = dataOffset;
        self.bitRate = bRate;
        NSTimeInterval duration = (self.downloader.contentLength - self.audioDataOffset) * 8 / self.bitRate;
        [self.delegate AQPlayer:self duration:duration];
    }
}

- (void)AQConverter:(AQConverter*)converter timerStop:(BOOL)flag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQPlayer:timerStop:)]) {
        [self.delegate AQPlayer:self timerStop:flag];
    }
}

@end
