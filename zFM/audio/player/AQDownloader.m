//
//  AQDownloader.m
//  zFM
//
//  Created by zykhbl on 15-9-27.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQDownloader.h"
#import "MyTool.h"

@interface AQDownloader ()

@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *downloadDir;
@property (nonatomic, strong) NSString *downloadFilePath;
@property (nonatomic, strong) NSSet *runLoopModes;
@property (nonatomic, assign) BOOL converted;
@property (nonatomic, strong) NSFileHandle *file;

@end

@implementation AQDownloader

@synthesize delegate;
@synthesize url;
@synthesize conn;
@synthesize bytesReceived;
@synthesize contentLength;

@synthesize fileName;
@synthesize downloadDir;
@synthesize downloadFilePath;
@synthesize runLoopModes;
@synthesize converted;
@synthesize file;

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"AQDownloaderNetworking"];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

+ (NSThread *)networkRequestThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_networkRequestThread start];
    });
    
    return _networkRequestThread;
}

- (void)closeFile {
    if (self.file != nil) {
        [self.file closeFile];
        self.file = nil;
    }
}

- (void)dealloc {
    [self closeFile];
}

- (id)init {
    self = [super init];
    
    if (self) {
        self.downloadDir = [MyTool makeTmpFilePath:@"audio"];
        [MyTool makeDir:self.downloadDir];
        
        self.runLoopModes = [NSSet setWithObject:NSRunLoopCommonModes];
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

- (void)start {
    [self performSelector:@selector(operationDidStart) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
}

- (void)operationDidStart {
    NSURL *URL = [NSURL URLWithString:self.url];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    self.conn = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    for (NSString *runLoopMode in self.runLoopModes) {
        [self.conn scheduleInRunLoop:runLoop forMode:runLoopMode];
    }
    
    [self.conn start];
}

- (void)playNext {
    if (self.delegate && [self.delegate respondsToSelector:@selector(AQDownloader:playNext:)]) {
        [self.delegate AQDownloader:self playNext:YES];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.contentLength = [response expectedContentLength];
    self.bytesReceived = 0;
    
    self.fileName = [response suggestedFilename];
    self.downloadFilePath = [NSString stringWithFormat:@"%@/%@", self.downloadDir, self.fileName];
    
    BOOL sucess  = [[NSFileManager defaultManager] createFileAtPath:self.downloadFilePath contents:nil attributes:nil];
    if (!sucess) {
        [self playNext];
        return;
    }
    self.file = [NSFileHandle fileHandleForWritingAtPath:self.downloadFilePath];
    
    [self.file seekToFileOffset:self.contentLength];
    [self.file writeData:[@"1" dataUsingEncoding:NSUTF8StringEncoding]];
    [self.file seekToFileOffset:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.file writeData:data];

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
    NSLog(@"+++++++++++++connectionDidFinishLoading: %@+++++++++++++\n", self.fileName);
    
    if (self.converted) {
        [self signal:YES];
        [self closeFile];
    } else {
        [self playNext];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"+++++++++++++didFailWithError: %@+++++++++++++\n", self.fileName);
    
    if (self.converted) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(AQDownloader:fail:)]) {
            [self.delegate AQDownloader:self fail:YES];
        }
        [self closeFile];
    }
    
    [self playNext];
}

@end
