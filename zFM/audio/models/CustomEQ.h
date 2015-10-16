//
//  CustomEQ.h
//  zFM
//
//  Created by zykhbl on 15-9-29.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CustomEQ : NSObject

@property (nonatomic, strong) NSMutableDictionary *dict;
@property (nonatomic, strong) NSArray *eqFrequencies;
@property (nonatomic, strong) NSMutableArray *eqValues;

+ (id)sharedCustomEQ;

- (void)setEQValue:(CGFloat)value inIndex:(int)index;
- (CGFloat)getEQValueInIndex:(int)index;
- (int)getEQFrequencieInIndex:(int)index;

@end
