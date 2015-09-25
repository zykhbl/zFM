//
//  PulleyViewController.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PulleyViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableArray *tabBtnArray;
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) NSMutableArray *mainViewControllerArray;
@property (nonatomic, strong) UIScrollView *mainScrollView;
@property (nonatomic, assign) int curSelectedIndex;
@property (nonatomic, assign) int nextSelectedIndex;
@property (nonatomic, assign) BOOL animationing;
@property (nonatomic, assign) BOOL scrollingNow;

- (void)addTabScrollView:(NSArray*)tabNameArray andMainScrollView:(NSArray*)subViewControllerArray;

@end
