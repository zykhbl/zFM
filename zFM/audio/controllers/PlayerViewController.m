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
@synthesize prevBtn;
@synthesize nextBtn;
@synthesize timeSlider;
@synthesize timeLabel;
@synthesize tapView;
@synthesize duration;
@synthesize currentTime;
@synthesize playOtherSong;
@synthesize playState;
@synthesize timerStop;
@synthesize longPressTaped;
@synthesize beginTouchPoint;

- (void)chagePlayBtnState {
    if (self.playState == STOP) {
        [self.playBtn setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
    } else {
        [self.playBtn setImage:[UIImage imageNamed:@"pause.png"] forState:UIControlStateNormal];
    }
}

- (IBAction)play {
    if (self.player == nil || self.playOtherSong) {
        self.playState = PAUSE;
        self.playOtherSong = NO;
        self.player = [AQPlayer sharedAQPlayer];
        self.player.delegate = self;
        NSString *urlString = [self.songs objectAtIndex:self.songIndex];
        [self.player play:urlString];
    } else {
        if (self.playState == STOP) {
            self.playState = PAUSE;
            [player play];
        } else {
            self.playState = STOP;
            [player stop];
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
    if (self.player.converter != nil) {
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
            if (value == 1.0) {
                [self playNext];
            } else {
                self.currentTime = self.duration * value;
                [self.player seek:self.currentTime];
            }
        }
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

    self.prevBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.prevBtn.frame = CGRectMake((320.0 - 40.0) * 0.5 - 80.0, 50.0, 40.0, 40.0);
    [self.prevBtn setImage:[UIImage imageNamed:@"prev.png"] forState:UIControlStateNormal];
    [self.prevBtn addTarget:self action:@selector(playPrev) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:prevBtn];
    
    self.playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playBtn.frame = CGRectMake((320.0 - 40.0) * 0.5, 50.0, 40.0, 40.0);
    [self.playBtn setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
    [self.playBtn addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBtn];
    
    self.nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.nextBtn.frame = CGRectMake((320.0 - 40.0) * 0.5 + 80.0, 50.0, 40.0, 40.0);
    [self.nextBtn setImage:[UIImage imageNamed:@"next.png"] forState:UIControlStateNormal];
    [self.nextBtn addTarget:self action:@selector(playNext) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:nextBtn];
    
    self.playOtherSong = YES;
    self.playState = STOP;
    self.timerStop = YES;
    self.longPressTaped = NO;
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerFire) userInfo:nil repeats:YES];
}

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

- (void)playNewOnce:(BOOL)flag {
    __weak typeof(self) weak_self = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weak_self.currentTime = weak_self.duration = 0.0;
        weak_self.playOtherSong = YES;
        if (flag) {
            weak_self.songIndex = (weak_self.songIndex + 1) % [weak_self.songs count];
        } else {
            weak_self.songIndex = ((weak_self.songIndex - 1) + [weak_self.songs count]) % [weak_self.songs count];
        }
        weak_self.playState = STOP;
        weak_self.timerStop = YES;
        weak_self.longPressTaped = NO;
        [weak_self.player clear];
        
        [weak_self modifyStates];
        [weak_self chagePlayBtnState];
        
        [NSObject cancelPreviousPerformRequestsWithTarget:weak_self selector:@selector(play) object:nil];
        [weak_self performSelector:@selector(play) withObject:nil afterDelay:1.0];
    });
}

- (void)playPrev {
    [self playNewOnce:NO];
}

- (void)playNext {
    [self playNewOnce:YES];
}

- (void)timerFire {
    if (self.playState == PLAYING) {
        if (self.currentTime > self.duration) {
            [self playNext];
        } else {
            if (self.timerStop) {
                return;
            }
            
            self.currentTime += 1.0;
            
            if (self.currentTime < self.duration) {
                [self performSelectorOnMainThread:@selector(modifyStates) withObject:nil waitUntilDone:NO];
            }
        }
    }
}

//============AQPlayerDelegate============
- (void)AQPlayer:(AQPlayer*)player duration:(NSTimeInterval)d zeroCurrentTime:(BOOL)flag {
    self.duration = d;
    if (flag) {
        self.currentTime = 0.0;
    }
    
    self.playState = PLAYING;
    self.timerStop = NO;
}

- (void)AQPlayer:(AQPlayer*)player timerStop:(BOOL)flag {
    self.timerStop = flag;
    self.playState = PLAYING;
}

- (void)AQPlayer:(AQPlayer*)player playNext:(BOOL)flag {
    [self playNext];
}

@end
