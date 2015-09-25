//
//  PlayerViewController.m
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "PlayerViewController.h"

@implementation PlayerViewController

@synthesize player;

- (void)viewDidLoad {
    [super viewDidLoad];
	
    [AQPlayer playForeground];
    
    NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=12626585&songtype=fc&bitrate=128";
//    NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=12946453&songtype=fc&bitrate=128";
//    NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=2444839&songtype=yc&bitrate=128";
    
    self.player = [AQPlayer sharedAQPlayer];
    [self.player play:urlString];
}

@end
