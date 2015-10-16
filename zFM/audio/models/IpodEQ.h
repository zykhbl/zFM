//
//  IpodEQ.h
//  zFM
//
//  Created by zykhbl on 15-9-29.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IpodEQ : NSObject

@property (nonatomic, strong) NSMutableDictionary *dict;
@property (nonatomic, assign) int selected;
@property (nonatomic, strong) NSArray *ipodEQS;

+ (id)sharedIpodEQ;

- (void)selected:(int)value;

@end
