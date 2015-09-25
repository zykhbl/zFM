//
//  AQPlayer.m
//  BLFM
//
//  Created by zykhbl on 14-1-25.
//  Copyright (c) 2014年 zykhbl. All rights reserved.
//

#import "AQPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "AFNetworking.h"
#import "MyUnit.h"

@implementation AQPlayer

@synthesize downloadFilePath;
@synthesize converter;

+ (void)playForeground {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
}

- (void)convert {
    if (self.converter == nil) {
        self.converter = [[AQConverter alloc] init];
    }
    [self.converter doConvertFile:self.downloadFilePath];
}

- (void)play:(NSString*)url {
//    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
//    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
//    
//    NSURL *URL = [NSURL URLWithString:url];
//    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
//    
//    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
//        self.downloadFilePath = [MyUnit makeTmpFilePath:[response suggestedFilename]];
//        return [[NSURL alloc] initFileURLWithPath:self.downloadFilePath];
//    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
//        NSLog(@"File downloaded to: %@", filePath);
//        [self performSelectorOnMainThread:@selector(convert) withObject:nil waitUntilDone:NO];
//    }];
//    [downloadTask resume];
    self.downloadFilePath = [MyUnit makeTmpFilePath:@"T1MHxLBCYT1R47IVrK.mp3"];
    [self performSelectorOnMainThread:@selector(convert) withObject:nil waitUntilDone:NO];
}

@end
