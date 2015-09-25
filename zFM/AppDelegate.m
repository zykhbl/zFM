//
//  AppDelegate.m
//  BLFM
//
//  Created by zykhbl on 13-4-8.
//  Copyright (c) 2013年 zykhbl. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window;
@synthesize mainVC;
@synthesize bgTask;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    self.mainVC = [[AudioPlayViewController alloc] init];
    self.mainVC.view.frame = self.window.bounds;
    [self.window addSubview:self.mainVC.view];
    
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
    bgTask = [application beginBackgroundTaskWithExpirationHandler:NULL];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

    });
}

@end
