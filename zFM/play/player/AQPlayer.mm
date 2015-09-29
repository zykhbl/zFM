//
//  AQPlayer.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQPlayer.h"
#import <AVFoundation/AVFoundation.h>

@implementation AQPlayer

@synthesize delegate;
@synthesize downloader;
@synthesize converter;
@synthesize audioDataOffset;
@synthesize bitRate;

+ (void)playForeground {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
}

+ (id)sharedAQPlayer {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc]init];
    });
    return _sharedObject;
}

- (void)cancel {
    self.downloader = nil;
    [self.converter setStopRunloop:YES];
    [self.converter signal];
    self.converter = nil;
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

- (void)changeEQ:(int)index value:(CGFloat)v {
    if (self.converter != nil) {
        [self.converter changeEQ:index value:v];
    }
}

//===========protocol AQDownloaderDelegate===========
- (void)AQDownloader:(AQDownloader*)downloader convert:(NSString*)filePath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.converter == nil) {
            self.converter = [[AQConverter alloc] init];
            self.converter.delegate = self;
        }
        [self.converter doConvertFile:filePath];
    });
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
