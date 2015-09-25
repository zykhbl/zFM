//
//  AppDelegate.h
//  BLFM
//
//  Created by zykhbl on 13-4-8.
//  Copyright (c) 2013年 zykhbl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AQPlayer.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, NSURLConnectionDataDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) AQPlayer *player;
@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end
