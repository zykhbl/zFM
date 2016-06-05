//
//  PlayerViewController.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AQPlayer.h"

typedef enum {
	STOP,
	PAUSE,
	PLAYING
} PlayState;

@interface PlayerViewController : UIViewController <AQPlayerDelegate>

@property (nonatomic, assign) int songIndex;
@property (nonatomic, strong) NSArray *songs;
@property (nonatomic, strong) AQPlayer *player;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIButton *prevBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, strong) UISlider *timeSlider;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIView *tapView;

@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) BOOL playOtherSong;
@property (nonatomic, assign) PlayState playState;
@property (nonatomic, assign) BOOL timerStop;
@property (nonatomic, assign) BOOL longPressTaped;
@property (nonatomic, assign) CGPoint beginTouchPoint;
@property (nonatomic, assign) BOOL touchEnable;

@end
