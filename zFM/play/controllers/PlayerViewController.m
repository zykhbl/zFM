//
//  PlayerViewController.m
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "PlayerViewController.h"

@implementation PlayerViewController

@synthesize songIndex;
@synthesize songs;
@synthesize player;
@synthesize timer;
@synthesize playBtn;
@synthesize timeSlider;
@synthesize timeLabel;
@synthesize tapView;
@synthesize duration;
@synthesize currentTime;
@synthesize playOtherSong;
@synthesize played;
@synthesize timerStop;
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
    
    if (self.player == nil || self.playOtherSong) {
        self.playOtherSong = NO;
        self.timerStop = NO;
        self.player = [AQPlayer sharedAQPlayer];
        self.player.delegate = self;
        NSString *urlString = [self.songs objectAtIndex:self.songIndex];
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

- (void)handleMove:(UILongPressGestureRecognizer*)gestureRecognizer {
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

- (void)move:(UILongPressGestureRecognizer*)gestureRecognizer {
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        self.longPressTaped = YES;
        self.beginTouchPoint = [gestureRecognizer locationInView:self.tapView];
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateChanged) {
        [self handleMove:gestureRecognizer];
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateCancelled) {
        self.longPressTaped = NO;
    } else if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        self.longPressTaped = NO;
        [self handleMove:gestureRecognizer];
        
        CGFloat value = self.timeSlider.value;
        self.currentTime = self.duration * value;
        [self.player seek:value];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.songIndex = 0;
    self.songs = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"songs.plist" ofType:nil]];
    
    self.timeSlider = [[UISlider alloc] initWithFrame:CGRectMake(10.0, 10.0, 260.0, 30.0)];
    [self.view addSubview:self.timeSlider];
    
    self.tapView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 10.0, 30.0, 30.0)];
    self.tapView.backgroundColor = [UIColor clearColor];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    longPress.minimumPressDuration = 0.1;
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
    
    self.playOtherSong = YES;
    self.played = NO;
    self.timerStop = NO;
    self.longPressTaped = NO;
}

//============AQPlayerDelegate============
- (void)modifyStates {
    double last = self.duration - self.currentTime;
    int m = last / 60.0;
    int s = last - m * 60.0;
    
    NSString *mStr = m < 10 ? [NSString stringWithFormat:@"0%d", m] : [NSString stringWithFormat:@"%d", m];
    NSString *sStr = s < 10 ? [NSString stringWithFormat:@"0%d", s] : [NSString stringWithFormat:@"%d", s];
    self.timeLabel.text = [NSString stringWithFormat:@"%@:%@", mStr, sStr];
    
    if (!self.longPressTaped) {
        double per = 0.0;
        if (self.duration != 0.0) {
            per = self.currentTime / self.duration;
        }
        [self.timeSlider setValue:per animated:YES];
        
        CGRect sliderRect = self.timeSlider.frame;
        CGRect rect = self.tapView.frame;
        rect.origin.x = sliderRect.origin.x + (sliderRect.size.width - 30.0) * per;
        self.tapView.frame = rect;
    }
}

- (void)timerFire {
    if (self.played) {
        if (self.timerStop) {
            return;
        }
        
        if (self.timer == nil) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerFire) userInfo:nil repeats:YES];
        } else {
            self.currentTime += 1.0;
        }
        
        if (self.currentTime < self.duration) {
            [self performSelectorOnMainThread:@selector(modifyStates) withObject:nil waitUntilDone:NO];
        }
    }
}

- (void)AQPlayer:(AQPlayer*)player duration:(NSTimeInterval)d zeroCurrentTime:(BOOL)flag {
    self.duration = d;
    if (flag) {
        self.currentTime = 0.0;
    }
    
    [self performSelectorOnMainThread:@selector(timerFire) withObject:nil waitUntilDone:NO];
}

- (void)AQPlayer:(AQPlayer*)player timerStop:(BOOL)flag {
    self.timerStop = flag;
    
    if (self.currentTime + 2.0 >=  self.duration) {
        self.currentTime = self.duration = 0.0;
        self.playOtherSong = YES;
        self.songIndex = (self.songIndex + 1) % [self.songs count];
        self.played = NO;
        self.timerStop = NO;
        self.longPressTaped = NO;
        [self.player clear];
        
        [self performSelectorOnMainThread:@selector(modifyStates) withObject:nil waitUntilDone:NO];
        [self performSelectorOnMainThread:@selector(chagePlayBtnState) withObject:nil waitUntilDone:NO];
    }
}

@end
