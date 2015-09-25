//
//  IpodEQViewCell.m
//  zFM
//
//  Created by zykhbl on 15-9-26.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "IpodEQViewCell.h"

@implementation IpodEQViewCell

@synthesize choosedImageView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        self.selectedBackgroundView.backgroundColor = [UIColor clearColor];
    }
    
    return self;
}

- (void)addChoosedImageView {
    if (self.choosedImageView == nil) {
        CGRect rect = self.bounds;
        rect = CGRectMake(rect.size.width - 30.0, (rect.size.height - 13.0) * 0.5, 18.0, 13.0);
        self.choosedImageView = [[UIImageView alloc]initWithFrame:rect];
        self.choosedImageView.image = [UIImage imageNamed:@"choosed.png"];
        self.choosedImageView.hidden = YES;
        [self addSubview:self.choosedImageView];
    }
}

@end
