//
//  AQDownloader.m
//  zFM
//
//  Created by zykhbl on 15-9-27.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQDownloader.h"
#import "MyTool.h"

@implementation AQDownloader

@synthesize delegate;
@synthesize downloadDir;
@synthesize downloadFilePath;
@synthesize converted;
@synthesize bytesReceived;
@synthesize contentLength;
@synthesize wfd;

- (void)dealloc {
    NSLog(@"++++++++++ AQDownloader dealloc! ++++++++++ \n");
}

- (id)init {
    self = [super init];
    
    if (self) {
        self.downloadDir = [MyTool makeTmpFilePath:@"audio"];
        [MyTool makeDir:self.downloadDir];
        
        self.converted = NO;
    }
    
    return self;
}

- (void)convert {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQDownloader:convert:)]) {
        [self.delegate AQDownloader:self convert:self.downloadFilePath];
    }
}

- (void)signal:(BOOL)flag {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQDownloader:signal:)]) {
        [self.delegate AQDownloader:self signal:flag];
    }
}

- (void)downloadThread:(NSString*)url {
    NSURL *URL = [NSURL URLWithString:url];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [conn start];
}

- (void)download:(NSString*)url {
    [self downloadThread:url];
}

- (int)getWriteFileFD:(NSString*)filename {
    const char *filepath = [filename cStringUsingEncoding:NSUTF8StringEncoding];
    
    FILE *sound = fopen(filepath, "wb");
    int fd = fileno(sound);
    
    if (fd == -1) {
        printf("write temp mp3 file error: %d = %s \n", errno, strerror(errno));
        exit(1);
    }
    
    return fd;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.contentLength = [response expectedContentLength];
    self.bytesReceived = 0;
    
    NSString *fileName = [response suggestedFilename];
    self.downloadFilePath = [NSString stringWithFormat:@"%@/%@", self.downloadDir, fileName];
    self.wfd = [self getWriteFileFD:self.downloadFilePath];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    write(self.wfd, data.bytes, data.length);
    

    self.bytesReceived += data.length;
    if (self.bytesReceived > self.contentLength * 0.01) {
        if (!self.converted) {
            self.converted = YES;
            [self convert];
        } else {
            [self signal:NO];
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"=============connectionDidFinishLoading============= \n");
    
    [self signal:YES];
    close(wfd);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"=============didFailWithError============= \n");
    close(wfd);
}

@end
