//
//  AQDownloader.h
//  zFM
//
//  Created by zykhbl on 15-9-27.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AQDownloaderDelegate;

@interface AQDownloader : NSObject

@property (nonatomic, assign) id<AQDownloaderDelegate> delegate;
@property (nonatomic, strong) NSString *downloadDir;
@property (nonatomic, strong) NSString *downloadFilePath;
@property (nonatomic, assign) BOOL converted;
@property (nonatomic, assign) int contentLength;
@property (nonatomic, assign) int bytesReceived;
@property (nonatomic, assign) int wfd;

+ (AQDownloader*)sharedAQDownloader;

- (void)download:(NSString*)url;

@end

@protocol AQDownloaderDelegate <NSObject>

- (void)AQDownloader:(AQDownloader*)downloader convert:(NSString*)filePath;
- (void)AQDownloader:(AQDownloader*)downloader signal:(BOOL)flag;

@end