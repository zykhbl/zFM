//
//  IpodEQ.m
//  zFM
//
//  Created by zykhbl on 15-9-29.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "IpodEQ.h"

@implementation IpodEQ

@synthesize dict;
@synthesize selected;
@synthesize ipodEQS;

+ (id)sharedIpodEQ {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc]init];
    });
    return _sharedObject;
}

- (id)init {
    self = [super init];
    if (self) {
        self.dict = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ipodEQ.plist" ofType:nil]];
        self.selected = [[self.dict objectForKey:@"selected"] integerValue];
        self.ipodEQS = (NSArray*)[self.dict objectForKey:@"ipodEQS"];
    }
    return self;
}

- (void)selected:(int)value {
    self.selected = value;
    
    [self.dict setObject:[NSNumber numberWithInt:self.selected] forKey:@"selected"];
    [self.dict writeToFile:[[NSBundle mainBundle] pathForResource:@"ipodEQ.plist" ofType:nil] atomically:YES];
}

@end
