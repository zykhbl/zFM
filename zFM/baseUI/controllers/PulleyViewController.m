//
//  PulleyViewController.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "PulleyViewController.h"

#define tabWeights 3
#define scaleWeights 0.25
#define originTabColor [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1.0]
#define selectedTabColor [UIColor colorWithRed:73.0/255.0 green:175.0/255.0 blue:76.0/255.0 alpha:1.0]

@implementation PulleyViewController

@synthesize tabBtnArray;
@synthesize tabScrollView;
@synthesize mainViewControllerArray;
@synthesize mainScrollView;
@synthesize curSelectedIndex;
@synthesize nextSelectedIndex;
@synthesize animationing;
@synthesize scrollingNow;

- (id)init {
    if (self = [super init]) {
        self.curSelectedIndex = self.nextSelectedIndex = -1;
    }
    
    return self;
}

- (void)moveAnimationFinished {
    self.animationing = NO;
}

- (void)selectATab:(id)sender {
    UIButton *curSelectedBtn = (UIButton*)sender;
    int index = (int)curSelectedBtn.tag - 100;
    if (self.curSelectedIndex == index) {
        return;
    }
    
    if (self.curSelectedIndex != -1) {
        UIButton *perSelectedBtn = [self.tabBtnArray objectAtIndex:self.curSelectedIndex];
        [perSelectedBtn.layer setTransform:CATransform3DMakeScale(1.0, 1.0, 1.0)];
        [perSelectedBtn setTitleColor:originTabColor forState:UIControlStateNormal];
    }

    self.curSelectedIndex = index;
    
    CGPoint p = self.mainScrollView.contentOffset;
    p.x = self.curSelectedIndex * self.mainScrollView.bounds.size.width;
    self.mainScrollView.contentOffset = p;
    
    [curSelectedBtn.layer setTransform:CATransform3DMakeScale(1.0 + scaleWeights, 1.0 + scaleWeights, 1.0)];
    [curSelectedBtn setTitleColor:selectedTabColor forState:UIControlStateNormal];
}

- (IBAction)selectTab:(id)sender {
    if (!self.animationing && !self.scrollingNow) {
        self.animationing = YES;
        [UIView beginAnimations:@"moveMainView" context:nil];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(moveAnimationFinished)];
        [self selectATab:sender];
        [UIView commitAnimations];
    }
}

- (void)addTabScrollView:(NSArray*)tabNameArray {
    CGRect rect = CGRectMake(20.0, 20.0, self.view.bounds.size.width - 40.0, 40.0);
    self.tabScrollView = [[UIScrollView alloc] initWithFrame:rect];
    self.tabScrollView.backgroundColor = [UIColor clearColor];
    self.tabScrollView.bounces = NO;
    self.tabScrollView.scrollsToTop = NO;
    self.tabScrollView.showsHorizontalScrollIndicator = NO;
    self.tabScrollView.showsVerticalScrollIndicator = NO;
    self.tabScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.tabScrollView];
    
    CGRect btnRect = self.tabScrollView.bounds;
    btnRect.size.width = btnRect.size.width / tabWeights;
    CGFloat x = 0.0;
    CGSize size = self.tabScrollView.bounds.size;
    if (tabNameArray.count < tabWeights) {
        x = (self.tabScrollView.bounds.size.width - btnRect.size.width * tabNameArray.count) * 0.5;
    } else {
        size.width = btnRect.size.width * tabNameArray.count;
    }
    self.tabScrollView.contentSize = size;
    
    if (self.tabBtnArray == nil) {
        self.tabBtnArray = [[NSMutableArray alloc] init];
    }
    
    int index = 0;
    for (NSString *tabName in tabNameArray) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.tabBtnArray addObject:btn];
        btn.tag = 100 + index;
        [btn setTitleColor:originTabColor forState:UIControlStateNormal];
        [btn setTitle:tabName forState:UIControlStateNormal];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:15.0]];
        [btn.titleLabel setTextAlignment:NSTextAlignmentCenter];
        [btn addTarget:self action:@selector(selectTab:) forControlEvents:UIControlEventTouchUpInside];
        
        btnRect.origin.x = x;
        btn.frame = btnRect;
        [self.tabScrollView addSubview:btn];
        
        x += btnRect.size.width;
        ++index;
    }
    
    [self selectATab:[self.tabBtnArray objectAtIndex:0]];
}

- (void)addMainScrollView:(NSArray*)subViewControllerArray {
    CGRect rect = CGRectMake(0.0, 60.0, self.view.bounds.size.width, self.view.bounds.size.height - 60.0);
    self.mainScrollView = [[UIScrollView alloc] initWithFrame:rect];
    self.mainScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mainScrollView.pagingEnabled = YES;
    self.mainScrollView.bounces = NO;
    self.mainScrollView.scrollsToTop = NO;
    self.mainScrollView.showsHorizontalScrollIndicator = NO;
    self.mainScrollView.showsVerticalScrollIndicator = NO;
    self.mainScrollView.delegate = self;
    [self.view addSubview:self.mainScrollView];
    
    if (self.mainViewControllerArray == nil) {
        self.mainViewControllerArray = [[NSMutableArray alloc] init];
    }
    
    CGFloat x = 0.0;
    for (UIViewController *vc in subViewControllerArray) {
        [self.mainViewControllerArray addObject:vc];
        CGRect vcRect = self.mainScrollView.bounds;
        vcRect.origin.x = x;
        vc.view.frame = vcRect;
        vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.mainScrollView addSubview:vc.view];
        
        x += vcRect.size.width;
    }
    
    CGSize size = self.mainScrollView.bounds.size;
    size.width *= subViewControllerArray.count;
    size.height = 0;
    self.mainScrollView.contentSize = size;
}

- (void)addTabScrollView:(NSArray*)tabNameArray andMainScrollView:(NSArray*)subViewControllerArray {
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addMainScrollView:subViewControllerArray];
    [self addTabScrollView:tabNameArray];
}

- (void)replyOState:(CGFloat)offsetX {
    UIButton *perSelectedBtn = [self.tabBtnArray objectAtIndex:self.curSelectedIndex];
    self.curSelectedIndex = (int)(offsetX / self.mainScrollView.bounds.size.width);
    UIButton *curSelectedBtn = [self.tabBtnArray objectAtIndex:self.curSelectedIndex];
    
    [perSelectedBtn setTitleColor:originTabColor forState:UIControlStateNormal];
    [curSelectedBtn setTitleColor:selectedTabColor forState:UIControlStateNormal];
    
    [UIView beginAnimations:@"moveTab" context:nil];
    [UIView setAnimationDuration:0.2];
    CGRect rect = [[self.tabBtnArray objectAtIndex:0] bounds];
    CGPoint p = self.tabScrollView.contentOffset;
    p.x = ((int)(self.curSelectedIndex / tabWeights)) * rect.size.width;
    self.tabScrollView.contentOffset = p;
    [UIView commitAnimations];
    
    self.scrollingNow = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!self.animationing) {
        CGFloat offsetX = scrollView.contentOffset.x;
        CGFloat curSelectedOffsetX = self.curSelectedIndex * self.mainScrollView.bounds.size.width;
        
        static BOOL flag = YES;
        
        if (offsetX != curSelectedOffsetX) {
            self.scrollingNow = YES;
            CGFloat moveX = fabsf(curSelectedOffsetX - offsetX) / self.mainScrollView.bounds.size.width;
            CGFloat propertion = scaleWeights * moveX;
            
            self.nextSelectedIndex = self.curSelectedIndex + (offsetX > curSelectedOffsetX ? 1 : -1);
            
            UIButton *curSelectedBtn = [self.tabBtnArray objectAtIndex:self.curSelectedIndex];
            UIButton *nextSelectedBtn = [self.tabBtnArray objectAtIndex:self.nextSelectedIndex];
            
            [curSelectedBtn.layer setTransform:CATransform3DMakeScale(1.0 + scaleWeights - propertion, 1.0 + scaleWeights - propertion, 1.0)];
            [nextSelectedBtn.layer setTransform:CATransform3DMakeScale(1.0 + propertion, 1.0 + propertion, 1.0)];
            
            [curSelectedBtn setTitleColor:[UIColor colorWithRed:((1.0-moveX)*73.0)/255.0 green:((1.0-moveX)*175.0)/255.0 blue:((1.0-moveX)*76.0)/255.0 alpha:1.0] forState:UIControlStateNormal];
            [nextSelectedBtn setTitleColor:[UIColor colorWithRed:(moveX*73.0)/255.0 green:(moveX*175.0)/255.0 blue:(moveX*76.0)/255.0 alpha:1.0] forState:UIControlStateNormal];
            
            if (((offsetX > curSelectedOffsetX) && offsetX >= self.nextSelectedIndex * self.mainScrollView.bounds.size.width) || ((offsetX < curSelectedOffsetX) && offsetX <= self.nextSelectedIndex * self.mainScrollView.bounds.size.width)) {
                [self replyOState:offsetX];
            }
        } else {
            flag = YES;
            [self replyOState:offsetX];
        }
    }
}

@end
