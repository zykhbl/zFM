//
//  AppDelegate.h
//  BLFM
//
//  Created by zykhbl on 13-4-8.
//  Copyright (c) 2013年 zykhbl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioPlayViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, NSURLConnectionDataDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) AudioPlayViewController *mainVC;
@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end
