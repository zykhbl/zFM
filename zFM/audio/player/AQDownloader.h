//
//  AQDownloader.h
//  zFM
//
//  Created by zykhbl on 15-9-27.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AQDownloaderDelegate;

@interface AQDownloader : NSOperation

@property (nonatomic, weak) id<AQDownloaderDelegate> delegate;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSURLConnection *conn;
@property (nonatomic, assign) off_t contentLength;
@property (nonatomic, assign) int bytesReceived;

@end

@protocol AQDownloaderDelegate <NSObject>

- (void)AQDownloader:(AQDownloader*)downloader convert:(NSString*)filePath;
- (void)AQDownloader:(AQDownloader*)downloader signal:(BOOL)flag;
- (void)AQDownloader:(AQDownloader*)downloader fail:(BOOL)flag;
- (void)AQDownloader:(AQDownloader*)downloader playNext:(BOOL)flag;

@end