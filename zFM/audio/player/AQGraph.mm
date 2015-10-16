//
//  AQGraph.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQGraph.h"
#import <AudioUnit/AudioUnit.h>
#import "CAStreamBasicDescription.h"
#import "CAComponentDescription.h"
#import "CAXException.h"
#import "AQRing.h"
#import "CustomEQ.h"

typedef struct {
    AudioStreamBasicDescription asbd;
    AQRing *data;
} SoundBuffer, *SoundBufferPtr;

typedef struct {
    SoundBuffer soundBuffer[MAXBUFS];
} SourceAudioBufferData, *SourceAudioBufferDataPtr;

static void silenceData(AudioBufferList *inData) {
	for (UInt32 i = 0; i < inData->mNumberBuffers; ++i)
		memset(inData->mBuffers[i].mData, 0, inData->mBuffers[i].mDataByteSize);
}

static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    SourceAudioBufferDataPtr userData = (SourceAudioBufferDataPtr)inRefCon;
    
    AudioSampleType *out = (AudioSampleType *)ioData->mBuffers[0].mData;
    
    if (![userData->soundBuffer[inBusNumber].data isEmpty]) {
        silenceData(ioData);
        
        int size = [userData->soundBuffer[inBusNumber].data size];
        if (size > 0) {
            if (size > ioData->mBuffers[0].mDataByteSize) {
                [userData->soundBuffer[inBusNumber].data getData:out numberBytes:ioData->mBuffers[0].mDataByteSize];
            } else {
                [userData->soundBuffer[inBusNumber].data getData:out numberBytes:size];
            }
        }
        
        return noErr;
    } else {
        silenceData(ioData);
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
        return noErr;
    }
	
    int size = [userData->soundBuffer[inBusNumber].data size];
    if (size > 0) {
        if (size > ioData->mBuffers[0].mDataByteSize) {
            [userData->soundBuffer[inBusNumber].data getData:out numberBytes:ioData->mBuffers[0].mDataByteSize];
        } else {
            [userData->soundBuffer[inBusNumber].data getData:out numberBytes:size];
        }
    }
    
    return noErr;
}

static OSStatus renderNotification(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    return noErr;
}

@interface AQGraph ()

@property (nonatomic, assign) AUGraph mGraph;

@property (nonatomic, assign) AUNode mixerNode;
@property (nonatomic, assign) AUNode eqNode;
@property (nonatomic, assign) AUNode ipodEQNode;
@property (nonatomic, assign) AUNode outputNode;

@property (nonatomic, assign) AudioUnit mMixer;
@property (nonatomic, assign) AudioUnit mEQ;
@property (nonatomic, assign) AudioUnit iPodEQ;

@property (nonatomic, assign) CAStreamBasicDescription mClientFormat;
@property (nonatomic, assign) CAStreamBasicDescription mOutputFormat;

@property (nonatomic, strong) AQRing *ring;
@property (nonatomic, assign) SourceAudioBufferDataPtr mUserData;

@property (nonatomic, assign) UInt32 bands;

@end

@implementation AQGraph

@synthesize mGraph;
@synthesize mixerNode;
@synthesize eqNode;
@synthesize ipodEQNode;
@synthesize outputNode;
@synthesize mMixer;
@synthesize mEQ;
@synthesize iPodEQ;
@synthesize mClientFormat;
@synthesize mOutputFormat;
@synthesize ring;
@synthesize mUserData;
@synthesize bands;

@synthesize mEQPresetsArray;

- (void)dealloc {
    if (self.mGraph) {
        AUGraphStop(self.mGraph);
        AUGraphRemoveRenderNotify(self.mGraph, renderNotification, self.mUserData);
        AUGraphClearConnections(self.mGraph);
        
        if (self.mixerNode) {
            AUGraphRemoveNode(self.mGraph, self.mixerNode);
        }
        if (self.eqNode) {
            AUGraphRemoveNode(self.mGraph, self.eqNode);
        }
        if (self.ipodEQNode) {
            AUGraphRemoveNode(self.mGraph, self.ipodEQNode);
        }
        if (self.outputNode) {
            AUGraphRemoveNode(self.mGraph, self.outputNode);
        }
        
        AUGraphClose(self.mGraph);
    }
    
    if (self.mUserData != NULL) {
        if (self.mUserData->soundBuffer[0].data != nil) {
            self.mUserData->soundBuffer[0].data = nil;
        }
        
        if (self.mUserData->soundBuffer[1].data != nil) {
            self.mUserData->soundBuffer[1].data = nil;
        }
        
        free(self.mUserData);
    }
    
    if (self.mEQPresetsArray != NULL) {
        CFRelease(self.mEQPresetsArray);
    }
}

- (void)awakeFromNib {
    self.mUserData = (SourceAudioBufferDataPtr)malloc(sizeof(SourceAudioBufferData));
	memset(self.mUserData->soundBuffer, 0, sizeof(self.mUserData->soundBuffer));
}

- (void)setasbd:(AudioStreamBasicDescription)asbd {
    self.mClientFormat = asbd;
    self.mOutputFormat = asbd;
    
    self.mUserData->soundBuffer[0].asbd = mClientFormat;
    self.ring = [[AQRing alloc] init];
    self.mUserData->soundBuffer[0].data = self.ring;
}

- (void)initializeAUGraph {
    OSStatus error = noErr;
    try {
        XThrowIfError(NewAUGraph(&mGraph), "NewAUGraph failed!");
        
        CAComponentDescription mixer_desc(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(self.mGraph, &mixer_desc, &mixerNode), "AUGraphAddNode failed!");
        CAComponentDescription eq_desc(kAudioUnitType_Effect, kAudioUnitSubType_NBandEQ, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(self.mGraph, &eq_desc, &eqNode), "AUGraphAddNode failed!");
        CAComponentDescription ipod_eq_desc(kAudioUnitType_Effect, kAudioUnitSubType_AUiPodEQ, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(self.mGraph, &ipod_eq_desc, &ipodEQNode), "AUGraphAddNode failed!");
        CAComponentDescription output_desc(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(self.mGraph, &output_desc, &outputNode), "AUGraphAddNode failed!");
        
        XThrowIfError(AUGraphConnectNodeInput(self.mGraph, self.mixerNode, 0, self.eqNode, 0), "AUGraphConnectNodeInput failed!");
        XThrowIfError(AUGraphConnectNodeInput(self.mGraph, self.eqNode, 0, self.ipodEQNode, 0), "AUGraphConnectNodeInput failed!");
        XThrowIfError(AUGraphConnectNodeInput(self.mGraph, self.ipodEQNode, 0, self.outputNode, 0), "AUGraphConnectNodeInput failed!");
        
        XThrowIfError(AUGraphOpen(self.mGraph), "AUGraphOpen failed!");
        
        XThrowIfError(AUGraphNodeInfo(self.mGraph, self.mixerNode, NULL, &mMixer), "AUGraphNodeInfo failed!");
        XThrowIfError(AUGraphNodeInfo(self.mGraph, self.eqNode, NULL, &mEQ), "AUGraphNodeInfo failed!");
        XThrowIfError(AUGraphNodeInfo(self.mGraph, self.ipodEQNode, NULL, &iPodEQ), "AUGraphNodeInfo failed!");
        
        UInt32 numbuses = 2;
        XThrowIfError(AudioUnitSetProperty(self.mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses)), "AudioUnitSetProperty failed!");
        for (UInt32 i = 0; i < numbuses; ++i) {
            AURenderCallbackStruct rcbs;
            rcbs.inputProc = &renderInput;
            rcbs.inputProcRefCon = self.mUserData;
            
            XThrowIfError(AUGraphSetNodeInputCallback(self.mGraph, self.mixerNode, i, &rcbs), "AUGraphSetNodeInputCallback failed!");
            XThrowIfError(AudioUnitSetProperty(self.mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &mClientFormat, sizeof(self.mClientFormat)), "AudioUnitSetProperty failed!");
        }
        
        UInt32 asbdSize = sizeof (self.mOutputFormat);
        memset (&mOutputFormat, 0, sizeof (self.mOutputFormat));
        XThrowIfError(AudioUnitGetProperty(self.mEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mOutputFormat, &asbdSize), "AudioUnitGetProperty failed!");
        XThrowIfError(AudioUnitSetProperty(self.mEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mOutputFormat, sizeof(self.mOutputFormat)), "AudioUnitSetProperty failed!");
        Float64 graphSampleRate = self.mOutputFormat.mSampleRate;
        XThrowIfError(AudioUnitSetProperty (self.mEQ, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &graphSampleRate, sizeof (graphSampleRate)), "AudioUnitSetProperty failed!");
        NSArray *frequency = [[CustomEQ sharedCustomEQ] eqFrequencies];
        NSMutableArray *eqFrequencies = [[NSMutableArray alloc] initWithArray:frequency];
        self.bands = [eqFrequencies count];
        
        XThrowIfError(AudioUnitSetProperty(self.mEQ, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &bands, sizeof(self.bands)), "AudioUnitSetProperty failed!");
        for (NSUInteger i = 0; i < self.bands; i++) {
            XThrowIfError(AudioUnitSetParameter(mEQ, kAUNBandEQParam_Frequency + (int)i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)[[eqFrequencies objectAtIndex:i] floatValue], 0), "AudioUnitSetParameter failed!");
        }
        for (NSUInteger i = 0; i < self.bands; i++) {
            XThrowIfError(AudioUnitSetParameter(self.mEQ, kAUNBandEQParam_BypassBand + (int)i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)0, 0), "AudioUnitSetParameter failed!");
        }
        
        XThrowIfError(AudioUnitSetProperty(self.mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(mOutputFormat)), "AudioUnitSetProperty failed!");
        
        UInt32 size = sizeof(self.mEQPresetsArray);
        XThrowIfError(AudioUnitGetProperty(self.iPodEQ, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size), "AudioUnitGetProperty failed!");
        XThrowIfError(AudioUnitSetProperty(self.iPodEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(self.mOutputFormat)), "AudioUnitSetProperty failed!");
        
        XThrowIfError(AUGraphAddRenderNotify(self.mGraph, renderNotification, self.mUserData), "AUGraphAddRenderNotify failed!");
        XThrowIfError(AUGraphInitialize(self.mGraph), "AUGraphInitialize failed!");
        CAShow(self.mGraph);
    } catch (CAXException e) {
		char buf[256];
		NSLog(@"Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
        error = e.mError;
	}
}

- (void)addBuf:(const void*)inInputData numberBytes:(UInt32)inNumberBytes {
    [self.mUserData->soundBuffer[0].data putData:inInputData numberBytes:inNumberBytes];
}

- (void)startAUGraph {
	OSStatus result = AUGraphStart(self.mGraph);
    if (result) { NSLog(@"AUGraphStart result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; }
}

- (void)stopAUGraph {
    Boolean isRunning = false;
    OSStatus result = AUGraphIsRunning(self.mGraph, &isRunning);
    if (result) { NSLog(@"AUGraphIsRunning result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; }
    
    if (isRunning) {
        result = AUGraphStop(self.mGraph);
        if (result) { NSLog(@"AUGraphStop result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; }
    }
}

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue {
    OSStatus result = AudioUnitSetParameter(self.mMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, inputNum, isONValue, 0);
    if (result) { NSLog(@"AudioUnitSetParameter kMultiChannelMixerParam_Enable result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; }
}

- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value {
	OSStatus result = AudioUnitSetParameter(self.mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputNum, value, 0);
    if (result) { NSLog(@"AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; }
}

- (void)setOutputVolume:(AudioUnitParameterValue)value {
	OSStatus result = AudioUnitSetParameter(self.mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
    if (result) { NSLog(@"AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; }
}

- (void)selectIpodEQPreset:(NSInteger)index {
    AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(self.mEQPresetsArray, index);
    OSStatus result = AudioUnitSetProperty(self.iPodEQ, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset));
    if (result) { NSLog(@"AudioUnitSetProperty result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; };
    
    CFShow(aPreset->presetName);
}

- (void)changeEQ:(int)index value:(CGFloat)v {
    AudioUnitParameterID parameterID = kAUNBandEQParam_Gain + index;
    OSStatus result = AudioUnitSetParameter(mEQ, parameterID, kAudioUnitScope_Global, 0, v, 0);
    if (result) { NSLog(@"AudioUnitSetParameter result %d %08X %4.4s\n", (int)result, (unsigned int)result, (char*)&result); return; };
}

@end