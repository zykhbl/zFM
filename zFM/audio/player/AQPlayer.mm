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

- (void)clear {
    [self.downloader.conn cancel];
    [self.downloader cancel];
    self.downloader = nil;
    [self.converter setStopRunloop:YES];
    [self.converter signal];
    self.converter = nil;
}

- (void)play:(NSString*)url {
    if (self.downloader == nil) {
        self.downloader = [[AQDownloader alloc] init];
        self.downloader.delegate = self;
        self.downloader.url = url;
        [self.downloader start];
    }
}

- (void)play {
    [self.converter play];
    [self.converter signal];
}

- (void)stop {
    [self.converter stop];
}

- (void)seek:(NSTimeInterval)seekToTime {
    [self.converter setBytesCanRead:self.downloader.bytesReceived];
    [self.converter seek:seekToTime];
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

//===========AQDownloaderDelegate===========
- (void)AQDownloader:(AQDownloader*)downloader convert:(NSString*)filePath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.converter == nil) {
            self.converter = [[AQConverter alloc] init];
            self.converter.delegate = self;
            [self.converter setContentLength:self.downloader.contentLength];
            [self.converter setBytesCanRead:self.downloader.bytesReceived];
        }
        [self.converter doConvertFile:filePath];
    });
}

- (void)AQDownloader:(AQDownloader*)downloader signal:(BOOL)flag {
    if (self.converter != nil) {
        [self.converter setBytesCanRead:self.downloader.bytesReceived];
        [self.converter signal];
    }
}

- (void)timerStop:(BOOL)flag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQPlayer:timerStop:)]) {
        [self.delegate AQPlayer:self timerStop:flag];
    }
}

- (void)AQDownloader:(AQDownloader*)downloader fail:(BOOL)flag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQPlayer:duration:zeroCurrentTime:)]) {
        [self.delegate AQPlayer:self duration:0.0 zeroCurrentTime:flag];
    }
    [self timerStop:flag];
}

- (void)AQDownloader:(AQDownloader*)downloader playNext:(BOOL)flag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQPlayer:playNext:)]) {
        [self.delegate AQPlayer:self playNext:flag];
    }
}

//===========AQConverterDelegate===========
- (void)AQConverter:(AQConverter*)converter duration:(NSTimeInterval)duration zeroCurrentTime:(BOOL)flag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQPlayer:duration:zeroCurrentTime:)]) {
        [self.delegate AQPlayer:self duration:duration zeroCurrentTime:flag];
    }
}

- (void)AQConverter:(AQConverter*)converter timerStop:(BOOL)flag {
    [self timerStop:flag];
}

- (void)AQConverter:(AQConverter*)converter playNext:(BOOL)flag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQPlayer:playNext:)]) {
        [self.delegate AQPlayer:self playNext:flag];
    }
}

@end
