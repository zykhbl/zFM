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
@synthesize timer;
@synthesize playBtn;
@synthesize timeSlider;
@synthesize timeLabel;
@synthesize tapView;
@synthesize duration;
@synthesize currentTime;
@synthesize played;
@synthesize longPressTaped;
@synthesize beginTouchPoint;

- (void)chagePlayBtnState {
    if (self.played) {
        [self.playBtn setImage:[UIImage imageNamed:@"pause.png"] forState:UIControlStateNormal];
    } else {
        [self.playBtn setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
    }
}

- (IBAction)play:(id)sender {
    self.played = !self.played;
    
    if (self.player == nil) {
//        NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=12626585&songtype=fc&bitrate=128";
        NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=12946453&songtype=fc&bitrate=128";
//    NSString *urlString = @"http://mobileapi.5sing.kugou.com/song/transcoding?songid=2444839&songtype=yc&bitrate=128";
        self.player = [AQPlayer sharedAQPlayer];
        self.player.delegate = self;
        [self.player play:urlString];
    } else {
        if (self.played) {
            [player play];
        } else {
            [player pause];
        }
    }
    
    [self chagePlayBtnState];
}

- (void)handlePressTapMove:(UILongPressGestureRecognizer*)gestureRecognizer {
    CGPoint p = [gestureRecognizer locationInView:self.view];
    CGFloat dx = p.x - beginTouchPoint.x;
    
    CGRect sliderRect = self.timeSlider.frame;
    CGRect rect = self.tapView.frame;
    if (dx < sliderRect.origin.x) {
        dx = sliderRect.origin.x;
    } else if (dx > (sliderRect.origin.x + sliderRect.size.width - 30.0)) {
        dx = sliderRect.origin.x + sliderRect.size.width - 30.0;
    }
    rect.origin.x = dx;
    self.tapView.frame = rect;
    
    double per = (rect.origin.x - sliderRect.origin.x) / (sliderRect.size.width - 30.0);
    [self.timeSlider setValue:per];
}

- (void)longPressTapMove:(UILongPressGestureRecognizer*)gestureRecognizer {
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        self.longPressTaped = YES;
        self.beginTouchPoint = [gestureRecognizer locationInView:self.tapView];
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateChanged) {
        [self handlePressTapMove:gestureRecognizer];
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateCancelled) {
        self.longPressTaped = NO;
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        [self handlePressTapMove:gestureRecognizer];
        
        CGFloat value = self.timeSlider.value;
        self.currentTime = self.duration * value;
        off_t offset = (self.player.downloader.contentLength - self.player.audioDataOffset) * value;
        
        [self.player seek:offset];
        
        self.longPressTaped = NO;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.timeSlider = [[UISlider alloc] initWithFrame:CGRectMake(10.0, 10.0, 260.0, 30.0)];
    [self.view addSubview:self.timeSlider];
    
    self.tapView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 10.0, 30.0, 30.0)];
    self.tapView.backgroundColor = [UIColor clearColor];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressTapMove:)];
    [self.tapView addGestureRecognizer:longPress];
    [self.view addSubview:self.tapView];
    
    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(280.0, 10.0, 30.0, 30)];
    self.timeLabel.backgroundColor = [UIColor clearColor];
    self.timeLabel.font = [UIFont systemFontOfSize:10.0];
    [self.timeLabel setTextColor:[UIColor blackColor]];
    self.timeLabel.text = @"00:00";
    [self.view addSubview:self.timeLabel];

    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake((320.0 - 50.0) * 0.5, 45.0, 50.0, 50.0);
    [self.playBtn setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
    [self.playBtn addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBtn];
    
    self.played = NO;
    self.longPressTaped = NO;
}

//============AQPlayerDelegate============
- (void)modifyText {
    double last = self.duration - self.currentTime;
    int m = last / 60.0;
    int s = last - m * 60.0;
    
    NSString *mStr = m < 10 ? [NSString stringWithFormat:@"0%d", m] : [NSString stringWithFormat:@"%d", m];
    NSString *sStr = s < 10 ? [NSString stringWithFormat:@"0%d", s] : [NSString stringWithFormat:@"%d", s];
    self.timeLabel.text = [NSString stringWithFormat:@"%@:%@", mStr, sStr];
    
    if (!self.longPressTaped) {
        double per = self.currentTime / self.duration;
        [self.timeSlider setValue:per animated:YES];
        
        CGRect sliderRect = self.timeSlider.frame;
        CGRect rect = self.tapView.frame;
        rect.origin.x = sliderRect.origin.x + (sliderRect.size.width - 30.0) * per;
        self.tapView.frame = rect;
    }
}

- (void)modifyTime {
    if (self.played) {
        if (self.timer == nil) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(modifyTime) userInfo:nil repeats:YES];
        } else {
            self.currentTime += 1.0;
        }
        
        if (self.currentTime >  self.duration) {
            self.played = NO;
        } else {
            [self performSelectorOnMainThread:@selector(modifyText) withObject:nil waitUntilDone:NO];
        }
    }
}

- (void)AQPlayer:(AQPlayer*)player duration:(NSTimeInterval)d {
    self.duration = d;
    self.currentTime = 0.0;
    
    [self performSelectorOnMainThread:@selector(modifyTime) withObject:nil waitUntilDone:NO];
}

- (void)AQPlayer:(AQPlayer*)player playing:(BOOL)flag {
    BOOL lastState = self.played;
    self.played = flag;
    
    if (lastState != self.played) {
        [self performSelectorOnMainThread:@selector(chagePlayBtnState) withObject:nil waitUntilDone:NO];
    }
}

@end
