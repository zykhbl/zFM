//
//  AQGraph.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define MAXBUFS  2
#define NUMFILES 2

@interface AQGraph : NSObject

@property (readonly, nonatomic, getter=iPodEQPresetsArray) CFArrayRef mEQPresetsArray;

- (void)awakeFromNib;
- (void)setasbd:(AudioStreamBasicDescription)asbd;
- (void)addBuf:(const void*)inInputData numberBytes:(UInt32)inNumberBytes;

- (void)initializeAUGraph;

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue;
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value;
- (void)setOutputVolume:(AudioUnitParameterValue)value;
- (void)selectIpodEQPreset:(NSInteger)index;
- (void)changeTag:(int)tag value:(CGFloat)v;
- (void)changeBaseFrequency:(CGFloat)v;

- (void)startAUGraph;
- (void)stopAUGraph;

@end
