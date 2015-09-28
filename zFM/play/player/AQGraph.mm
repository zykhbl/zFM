//
//  AQGraph.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQGraph.h"
#import "CAXException.h"

static void SilenceData(AudioBufferList *inData) {
	for (UInt32 i = 0; i < inData->mNumberBuffers; ++i)
		memset(inData->mBuffers[i].mData, 0, inData->mBuffers[i].mDataByteSize);
}

static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    SourceAudioBufferDataPtr userData = (SourceAudioBufferDataPtr)inRefCon;
    
    AudioSampleType *out = (AudioSampleType *)ioData->mBuffers[0].mData;
    
    if (![userData->soundBuffer[inBusNumber].data isEmpty]) {
        SilenceData(ioData);
        
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
        SilenceData(ioData);
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

@implementation AQGraph

@synthesize mIsPlaying, mEQPresetsArray;

- (void)dealloc {
    printf("AUGraphController dealloc\n");
    
    DisposeAUGraph(mGraph);
    
    if (mUserData.soundBuffer[0].data != nil) {
        [mUserData.soundBuffer[0].data release];
        mUserData.soundBuffer[0].data = nil;
    }
    
    if (mUserData.soundBuffer[1].data != nil) {
        [mUserData.soundBuffer[1].data release];
        mUserData.soundBuffer[1].data = nil;
    }
    
    CFRelease(mEQPresetsArray);

	[super dealloc];
}

- (void)awakeFromNib {
	mIsPlaying = false;
	memset(&mUserData.soundBuffer, 0, sizeof(mUserData.soundBuffer));
}

- (void)initializeAUGraph {
    printf("initializeAUGraph\n");
	
    OSStatus error = noErr;
    try {
        XThrowIfError(NewAUGraph(&mGraph), "NewAUGraph failed!");
        
        CAComponentDescription mixer_desc(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(mGraph, &mixer_desc, &mixerNode), "AUGraphAddNode failed!");
        CAComponentDescription eq_desc(kAudioUnitType_Effect, kAudioUnitSubType_NBandEQ, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(mGraph, &eq_desc, &eqNode), "AUGraphAddNode failed!");
        CAComponentDescription ipod_eq_desc(kAudioUnitType_Effect, kAudioUnitSubType_AUiPodEQ, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(mGraph, &ipod_eq_desc, &ipodEQNode), "AUGraphAddNode failed!");
        CAComponentDescription output_desc(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple);
        XThrowIfError(AUGraphAddNode(mGraph, &output_desc, &outputNode), "AUGraphAddNode failed!");
        
        XThrowIfError(AUGraphConnectNodeInput(mGraph, mixerNode, 0, eqNode, 0), "AUGraphConnectNodeInput failed!");
        XThrowIfError(AUGraphConnectNodeInput(mGraph, eqNode, 0, ipodEQNode, 0), "AUGraphConnectNodeInput failed!");
        XThrowIfError(AUGraphConnectNodeInput(mGraph, ipodEQNode, 0, outputNode, 0), "AUGraphConnectNodeInput failed!");
        
        XThrowIfError(AUGraphOpen(mGraph), "AUGraphOpen failed!");
        
        XThrowIfError(AUGraphNodeInfo(mGraph, mixerNode, NULL, &mMixer), "AUGraphNodeInfo failed!");
        XThrowIfError(AUGraphNodeInfo(mGraph, eqNode, NULL, &mEQ), "AUGraphNodeInfo failed!");
        XThrowIfError(AUGraphNodeInfo(mGraph, ipodEQNode, NULL, &iPodEQ), "AUGraphNodeInfo failed!");
        
        UInt32 numbuses = 2;
        XThrowIfError(AudioUnitSetProperty(mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses)), "AudioUnitSetProperty failed!");
        for (UInt32 i = 0; i < numbuses; ++i) {
            AURenderCallbackStruct rcbs;
            rcbs.inputProc = &renderInput;
            rcbs.inputProcRefCon = &mUserData;
            
            XThrowIfError(AUGraphSetNodeInputCallback(mGraph, mixerNode, i, &rcbs), "AUGraphSetNodeInputCallback failed!");
            XThrowIfError(AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &mClientFormat, sizeof(mClientFormat)), "AudioUnitSetProperty failed!");
        }
        
        UInt32 asbdSize = sizeof (mOutputFormat);
        memset (&mOutputFormat, 0, sizeof (mOutputFormat));
        XThrowIfError(AudioUnitGetProperty(mEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mOutputFormat, &asbdSize), "AudioUnitGetProperty failed!");
        XThrowIfError(AudioUnitSetProperty(mEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mOutputFormat, sizeof(mOutputFormat)), "AudioUnitSetProperty failed!");
        Float64 graphSampleRate = mOutputFormat.mSampleRate;
        XThrowIfError(AudioUnitSetProperty (mEQ, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &graphSampleRate, sizeof (graphSampleRate)), "AudioUnitSetProperty failed!");
        NSArray *frequency = @[@32.0f , @64.0f, @125.0f, @250.0f, @500.0f, @1000.0f, @2000.0f, @4000.0f, @8000.0f, @16000.0f];
        NSMutableArray *eqFrequencies = [[NSMutableArray alloc] initWithArray:frequency];
        noBands = [eqFrequencies count];
        
        XThrowIfError(AudioUnitSetProperty(mEQ, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &noBands, sizeof(noBands)), "AudioUnitSetProperty failed!");
        for (NSUInteger i = 0; i < noBands; i++) {
            XThrowIfError(AudioUnitSetParameter(mEQ, kAUNBandEQParam_Frequency+i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)[[eqFrequencies objectAtIndex:i] floatValue], 0), "AudioUnitSetParameter failed!");
        }
        for (NSUInteger i = 0; i < noBands; i++) {
            XThrowIfError(AudioUnitSetParameter(mEQ, kAUNBandEQParam_BypassBand + i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)0, 0), "AudioUnitSetParameter failed!");
        }
        
        XThrowIfError(AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(mOutputFormat)), "AudioUnitSetProperty failed!");
        
        UInt32 size = sizeof(mEQPresetsArray);
        XThrowIfError(AudioUnitGetProperty(iPodEQ, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size), "AudioUnitGetProperty failed!");
        XThrowIfError(AudioUnitSetProperty(iPodEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(mOutputFormat)), "AudioUnitSetProperty failed!");
        
        XThrowIfError(AUGraphAddRenderNotify(mGraph, renderNotification, &mUserData), "AUGraphAddRenderNotify failed!");
        XThrowIfError(AUGraphInitialize(mGraph), "AUGraphInitialize failed!");
        CAShow(mGraph);
    } catch (CAXException e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
        error = e.mError;
	}
}

- (void)setasbd:(AudioStreamBasicDescription)asbd {
    mClientFormat = asbd;
    mOutputFormat = asbd;
    
    mUserData.soundBuffer[0].asbd = mClientFormat;
    mUserData.soundBuffer[0].data = [[AQRing alloc] init];
}

- (void)addBuf:(const void*)inInputData numberBytes:(UInt32)inNumberBytes {
    [mUserData.soundBuffer[0].data putData:inInputData numberBytes:inNumberBytes];
}

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue {
    printf("BUS %ld isON %f\n", inputNum, isONValue);
         
    OSStatus result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, inputNum, isONValue, 0);
    if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Enable result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value {
	OSStatus result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputNum, value, 0);
    if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)setOutputVolume:(AudioUnitParameterValue)value {
	OSStatus result = AudioUnitSetParameter(mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
    if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)selectIpodEQPreset:(NSInteger)index {
    if (isCustom) {
        isCustom = NO;
        for (NSUInteger i=0; i<noBands; i++) {
            OSStatus result = AudioUnitSetParameter(mEQ, kAUNBandEQParam_BypassBand+i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)0, 0);
            if (result) { printf("set NumberOfBands Property3 result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
        }
    }
    
    isIPodDefined = YES;
    AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, index);
    OSStatus result = AudioUnitSetProperty(iPodEQ, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset));
    if (result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
    
    printf("SET EQ PRESET %d ", index);
    CFShow(aPreset->presetName);
}

- (void)changeTag:(int)tag value:(CGFloat)v {
    if (isIPodDefined) {
        isIPodDefined = NO;
        AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, 0);
        OSStatus result = AudioUnitSetProperty(iPodEQ, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset));
        if (result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
    }
    
    isCustom = YES;
    AudioUnitParameterID parameterID = kAUNBandEQParam_Gain + tag;
    OSStatus result = AudioUnitSetParameter(mEQ, parameterID, kAudioUnitScope_Global, 0, v, 0);
    if (result) { printf("AudioUnitSetParameter result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
}

- (void)changeBaseFrequency:(CGFloat)v {
    NSMutableArray *frequency = [NSMutableArray array];
    for (int i = 0; i < 10; ++i) {
        [frequency addObject:[NSNumber numberWithFloat:(v + i * 20.0)]];
    }
    NSMutableArray *eqFrequencies = [[NSMutableArray alloc] initWithArray:frequency];
    noBands = [eqFrequencies count];
    
    OSStatus result = AudioUnitSetProperty(mEQ, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &noBands, sizeof(noBands));
    if (result) { printf("set NumberOfBands Property1 result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    for (NSUInteger i = 0; i < noBands; i++) {
        result = AudioUnitSetParameter(mEQ, kAUNBandEQParam_Frequency + i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)[[eqFrequencies objectAtIndex:i] floatValue], 0);
        if (result) { printf("set NumberOfBands Property2 result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    }
    
    for (NSUInteger i = 0; i < noBands; i++) {
        AudioUnitParameterID parameterID = kAUNBandEQParam_Gain + i;
        OSStatus result = AudioUnitSetParameter(mEQ, parameterID, kAudioUnitScope_Global, 0, -26.0, 0);
        if (result) { printf("AudioUnitSetParameter result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
    }
    
    Boolean outIsUpdated = YES;
    result = AUGraphUpdate(mGraph, &outIsUpdated);
    if (result) { printf("AUGraphUpdate result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)startAUGraph {
    printf("PLAY\n");
    
	OSStatus result = AUGraphStart(mGraph);
    if (result) { printf("AUGraphStart result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
	mIsPlaying = true;
}

- (void)stopAUGraph {
	printf("STOP\n");

    Boolean isRunning = false;
    
    OSStatus result = AUGraphIsRunning(mGraph, &isRunning);
    if (result) { printf("AUGraphIsRunning result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    if (isRunning) {
        result = AUGraphStop(mGraph);
        if (result) { printf("AUGraphStop result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
        mIsPlaying = false;
    }
}

@end