//
//  AudioPlayViewController.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AudioPlayViewController.h"
#import "PlayerViewController.h"
#import "IpodEQViewController.h"
#import "CustomEQViewController.h"

@implementation AudioPlayViewController

@synthesize playVC;
@synthesize ipodEQVC;
@synthesize customEQVC;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.playVC == nil) {
        self.playVC = [[PlayerViewController alloc] init];
    }
    
    if (self.ipodEQVC == nil) {
        self.ipodEQVC = [[IpodEQViewController alloc] init];
    }
    
    if (self.customEQVC == nil) {
        self.customEQVC = [[CustomEQViewController alloc] init];
    }
    
    [self addTabScrollView:@[@"播放器", @"ipod EQ", @"EQ"] andMainScrollView:@[self.playVC, self.ipodEQVC, self.customEQVC]];
}

@end
