//
//  MyUnit.h
//  WBHui
//
//  Created by kenny on 12-3-19.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"

@interface MyUnit : NSObject

//NSFileMangage
+ (NSString*)makeUserFilePath:(NSString*)filename;
+ (NSString*)makeTmpFilePath:(NSString*)filename;
+ (NSString*)makeAppFilePath:(NSString*)filename;

+ (void)makeDir:(NSString*)dir;
+ (void)makeDirWithFilePath:(NSString*)filepath;
+ (BOOL)checkFilepathExists:(NSString*)filepath;
+ (void)makeFile:(NSString*)filepath;
+ (void)removeFile:(NSString*)filepath;

@end
