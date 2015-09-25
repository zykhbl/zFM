//
//  MyTool.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"

@interface MyTool : NSObject

+ (NSString*)makeUserFilePath:(NSString*)filename;
+ (NSString*)makeTmpFilePath:(NSString*)filename;
+ (NSString*)makeAppFilePath:(NSString*)filename;

+ (void)makeDir:(NSString*)dir;
+ (void)makeDirWithFilePath:(NSString*)filepath;
+ (BOOL)checkFilepathExists:(NSString*)filepath;
+ (void)makeFile:(NSString*)filepath;
+ (void)removeFile:(NSString*)filepath;

@end
