//
//  AQPlayer.h
//  BLFM
//
//  Created by zykhbl on 14-1-25.
//  Copyright (c) 2014年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AQConverter.h"

@interface AQPlayer : NSObject

@property (strong, nonatomic) NSString *downloadFilePath;
@property (strong, nonatomic) AQConverter *converter;

+ (void)playForeground;
- (void)play:(NSString*)url;

@end
