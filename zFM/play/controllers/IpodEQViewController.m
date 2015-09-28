//
//  IpodEQViewController.m
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "IpodEQViewController.h"
#import "IpodEQViewCell.h"
#import "AQPlayer.h"

@implementation IpodEQViewController

@synthesize tableView;
@synthesize dict;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.dict == nil) {
        self.dict = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ipodEQ.plist" ofType:nil]];
    }
    
    if (self.tableView == nil) {
        CGRect rect = self.view.bounds;
        self.tableView = [[UITableView alloc] initWithFrame:rect style:UITableViewStylePlain];
        [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        [self.view addSubview:self.tableView];
    }
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *dataArray = (NSArray*)[self.dict objectForKey:@"ipodEQS"];
    return [dataArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *IpodEQViewCellIdentifier = @"IpodEQViewCell";
    IpodEQViewCell *cell = (IpodEQViewCell*)[self.tableView dequeueReusableCellWithIdentifier:IpodEQViewCellIdentifier];
    
    if (cell == nil) {
        cell = [[IpodEQViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:IpodEQViewCellIdentifier];
    }
    
    CGRect rect = self.view.bounds;
    rect.size.height = 40.0;
    cell.frame = rect;
    
    NSArray *dataArray = (NSArray*)[self.dict objectForKey:@"ipodEQS"];
    cell.textLabel.text = [dataArray objectAtIndex:indexPath.row];
    
    [cell addChoosedImageView];
    
    NSNumber *selected = [self.dict objectForKey:@"selected"];
    if (indexPath.row == selected.intValue) {
        cell.choosedImageView.hidden = NO;
    } else {
        cell.choosedImageView.hidden = YES;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 40.0;
}

- (void)tableView:(UITableView *)tView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AQPlayer *player = [AQPlayer getPlayer];
    if (player != nil) {
        [player selectIpodEQPreset:indexPath.row];
    }
    
    NSArray *dataArray = (NSArray*)[self.dict objectForKey:@"ipodEQS"];
    for (int i = 0; i < [dataArray count]; ++i) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:i inSection:0];
        IpodEQViewCell *cell = (IpodEQViewCell*)[self.tableView cellForRowAtIndexPath:path];
        if (i == indexPath.row) {
            [self.dict setObject:[NSNumber numberWithInt:i] forKey:@"selected"];
            
            cell.choosedImageView.hidden = NO;
        } else {
            cell.choosedImageView.hidden = YES;
        }
    }
}

@end
