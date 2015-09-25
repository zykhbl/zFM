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
@synthesize player;
@synthesize bgTask;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [AQPlayer playForeground];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
//    NSString *urlString = @"http://qzone.haoduoge.com/music/DDB51PJIPJ7F6B2BF40E5FBEADCFAD2795E24.mp3";
    NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=12626585&songtype=fc&bitrate=128";
//    NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=12946453&songtype=fc&bitrate=128";
//    NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=2444839&songtype=yc&bitrate=128";
//    NSString *urlString = @"http://mp3.9ku.com/file2/416/415802.mp3";
    
    self.player = [[AQPlayer alloc] init];
    [self.player play:urlString];
    
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
    bgTask = [application beginBackgroundTaskWithExpirationHandler:NULL];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

    });
}

@end
