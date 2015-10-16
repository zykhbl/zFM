//
//  CustomEQViewController.m
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "CustomEQViewController.h"
#import "AQPlayer.h"
#import "CustomEQ.h"

#define segmentedControlY 10.0
#define segmentedControlH 24.0
#define eqFrequencieCount 5
#define minEQ -12.0
#define maxEQ 12.0

@implementation CustomEQViewController

@synthesize segmentedControl;
@synthesize sliderArray;
@synthesize labelArray;

- (void)select:(id)sender {
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        [self addEQFrequencies:0];
    } else if (self.segmentedControl.selectedSegmentIndex == 1) {
        [self addEQFrequencies:eqFrequencieCount];
    }
}

- (void)addSegmentedControl {
    CGFloat x = 12.0;
    CGRect rect = self.view.bounds;
    rect = CGRectMake(x, segmentedControlY, rect.size.width - x * 2.0, segmentedControlH);
    
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"低频", @"高频"]];
    self.segmentedControl.frame = rect;
    self.segmentedControl.backgroundColor = [UIColor clearColor];
    self.segmentedControl.tintColor = [UIColor colorWithRed:73.0/255.0 green:175.0/255.0 blue:76.0/255.0 alpha:1.0];
    [self.segmentedControl addTarget:self action:@selector(select:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmentedControl];
    
    [self.segmentedControl setSelectedSegmentIndex:0];
    [self select:nil];
}

- (UILabel*)addLabel:(CGRect)rect text:(NSString*)text {
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont systemFontOfSize:14.0];
    [label setTextColor:[UIColor blackColor]];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = text;
    [self.view addSubview:label];
    
    return label;
}

- (IBAction)changeEQ:(id)sender {
    UISlider *slider = (UISlider*)sender;
    int index = (int)slider.tag - 100;
    if (self.segmentedControl.selectedSegmentIndex == 1) {
        index += eqFrequencieCount;
    }
    CGFloat value = minEQ + (maxEQ - minEQ) * slider.value;
    [[CustomEQ sharedCustomEQ] setEQValue:value inIndex:index];
    
    AQPlayer *player = [AQPlayer sharedAQPlayer];
    [player changeEQ:index value:value];
}

- (void)addEQFrequencies:(int)offset {
    CGFloat x = -50.0;
    CGFloat y = segmentedControlY + segmentedControlH + 10.0;
    CGFloat w = 30.0;
    CGFloat h = 300.0;
    CGFloat spaceW = (self.view.frame.size.width - w * eqFrequencieCount + 20.0) / (eqFrequencieCount - 1);
    
    for (int i = 0; i < eqFrequencieCount; ++i) {
        UISlider *slider = nil;
        if ([self.sliderArray count] == i) {
            slider = [[UISlider alloc] initWithFrame:CGRectMake(x, y, h, w)];
            slider.tag = 100 + i + offset;
            [slider addTarget:self action:@selector(changeEQ:) forControlEvents:UIControlEventValueChanged];
            [self.sliderArray addObject:slider];
            
            slider.layer.anchorPoint = CGPointMake(0.0, 0.0);
            slider.transform = CGAffineTransformMakeRotation(M_PI_2);
            [self.view addSubview:slider];
        } else {
            slider = [self.sliderArray objectAtIndex:i];
        }

        CGFloat value = [[CustomEQ sharedCustomEQ] getEQValueInIndex:i + offset];
        CGFloat per = (value - minEQ) / (maxEQ - minEQ);
        [slider setValue:per animated:NO];
        
        x += spaceW;
        
        UILabel *label = nil;
        if ([self.labelArray count] == i) {
            label = [self addLabel:CGRectMake(x + 60.0, segmentedControlY + segmentedControlH + 320.0, 60.0, 30.0) text:@""];
            [self.labelArray addObject:label];
        } else {
            label = [self.labelArray objectAtIndex:i];
        }
        
        NSString *text = [NSString stringWithFormat:@"%d", [[CustomEQ sharedCustomEQ] getEQFrequencieInIndex:i + offset]];
        label.text = text;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addLabel:CGRectMake(10.0, segmentedControlY + segmentedControlH + 20.0, 60.0, 30.0) text:[NSString stringWithFormat:@"%0.1fmb", maxEQ]];
    [self addLabel:CGRectMake(10.0, segmentedControlY + segmentedControlH + 160.0, 60.0, 30.0) text:@"0.0mb"];
    [self addLabel:CGRectMake(10.0, segmentedControlY + segmentedControlH + 300.0, 60.0, 30.0) text:[NSString stringWithFormat:@"%0.1fmb", minEQ]];
    
    self.sliderArray = [[NSMutableArray alloc] initWithCapacity:eqFrequencieCount];
    self.labelArray = [[NSMutableArray alloc] initWithCapacity:eqFrequencieCount];
    [self addEQFrequencies:0];
    
    [self addSegmentedControl];
}

@end
