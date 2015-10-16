//
//  CustomEQ.m
//  zFM
//
//  Created by zykhbl on 15-9-29.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "CustomEQ.h"

@implementation CustomEQ

@synthesize dict;
@synthesize eqFrequencies;
@synthesize eqValues;

+ (id)sharedCustomEQ {
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
        self.dict = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"customEQ.plist" ofType:nil]];
        self.eqFrequencies = (NSArray*)[self.dict objectForKey:@"eqFrequencies"];
        self.eqValues = [NSMutableArray arrayWithArray:(NSArray*)[self.dict objectForKey:@"eqValues"]];
    }
    return self;
}

- (void)setEQValue:(CGFloat)value inIndex:(int)index {
    [self.eqValues setObject:[NSNumber numberWithFloat:value] atIndexedSubscript:index];
    [self.dict writeToFile:[[NSBundle mainBundle] pathForResource:@"customEQ.plist" ofType:nil] atomically:YES];
}

- (CGFloat)getEQValueInIndex:(int)index {
    return [[self.eqValues objectAtIndex:index] floatValue];
}

- (int)getEQFrequencieInIndex:(int)index {
    return (int)[[self.eqFrequencies objectAtIndex:index] integerValue];
}

@end
