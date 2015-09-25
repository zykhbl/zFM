//
//  MyTool.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "MyTool.h"

@implementation MyTool

+ (NSString*)makeUserFilePath:(NSString*)filename {
    NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:filename];
    
    return filePath;
}

+ (NSString*)makeTmpFilePath:(NSString*)filename {	
	NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"tmp"];
	NSString *filePath = [documentsDirectory stringByAppendingPathComponent:filename];
	
	return filePath;
}

+ (NSString*)makeAppFilePath:(NSString*)filename {
	NSString *appDirectory = [[NSBundle mainBundle] resourcePath];
	NSString *filePath = [appDirectory stringByAppendingPathComponent:filename];
	
	return filePath;
}

+ (void)makeDir:(NSString*)dir {
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([fm fileExistsAtPath:dir]) {
		return ;
	} else {
		NSError* error;
		[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error];
	}
}

+ (void)makeDirWithFilePath:(NSString*)filepath {
	if (!filepath) {
		return ;
	}
	NSString *filename = [filepath lastPathComponent];
	NSString *dirpath = [filepath substringToIndex:([filepath length]-[filename length])];
	
	return [[self class] makeDir:dirpath];	
}

+ (BOOL)checkFilepathExists:(NSString*)filepath {
	NSFileManager *fm = [NSFileManager defaultManager];
	return [fm fileExistsAtPath:filepath];
}

+ (void)makeFile:(NSString*)filepath {
	if (![self checkFilepathExists:filepath]) {
        [self makeDirWithFilePath:filepath];
        
        NSFileManager *fm = [NSFileManager defaultManager];
		[fm createFileAtPath:filepath contents:nil attributes:nil];
    }
}

+ (void)removeFile:(NSString*)filepath {
    if ([self checkFilepathExists:filepath]) {        
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSError* error;
		[fm removeItemAtPath:filepath error:&error];
    }
}

@end
