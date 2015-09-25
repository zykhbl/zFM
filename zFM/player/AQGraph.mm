#import "AQGraph.h"

static void SilenceData(AudioBufferList *inData) {
	for (UInt32 i=0; i < inData->mNumberBuffers; i++)
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

- (void)addEqNode {
    OSStatus result = AUGraphDisconnectNodeInput(mGraph, outputNode, 0);
    if (result) { printf("AUGraphDisconnectNodeInput result %lu %4.4s\n", result, (char*)&result); return; }
    
    CAComponentDescription eq_desc(kAudioUnitType_Effect, kAudioUnitSubType_NBandEQ, kAudioUnitManufacturer_Apple);
    result = AUGraphAddNode(mGraph, &eq_desc, &eqNode);
    if (result) { printf("AUGraphNewNode 2 result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphConnectNodeInput(mGraph, mixerNode, 0, eqNode, 0);
	if (result) { printf("AUGraphConnectNodeInput result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphConnectNodeInput(mGraph, eqNode, 0, outputNode, 0);
    if (result) { printf("AUGraphConnectNodeInput result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphNodeInfo(mGraph, eqNode, NULL, &mEQ);
    if (result) { printf("AUGraphNodeInfo result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    UInt32 asbdSize = sizeof (mOutputFormat);
	memset (&mOutputFormat, 0, sizeof (mOutputFormat));
	result = AudioUnitGetProperty(mEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,&mOutputFormat, &asbdSize);
    if (result) { printf("Couldn't get aueffectunit ASBD result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    result = AudioUnitSetProperty(mEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mOutputFormat, sizeof(mOutputFormat));
    if (result) { printf("Couldn't set ASBD on effect unit input result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    Float64 graphSampleRate = mOutputFormat.mSampleRate;
    result = AudioUnitSetProperty (mEQ, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &graphSampleRate, sizeof (graphSampleRate));
    if (result) { printf("AudioUnitSetProperty (set au effect unit output stream format) result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    NSArray *frequency = @[@32.0f , @64.0f, @125.0f, @250.0f, @500.0f, @1000.0f, @2000.0f, @4000.0f, @8000.0f, @16000.0f];
    NSMutableArray *eqFrequencies = [[NSMutableArray alloc] initWithArray:frequency];
    noBands = [eqFrequencies count];
    
    result = AudioUnitSetProperty(mEQ, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &noBands, sizeof(noBands));
    if (result) { printf("set NumberOfBands Property1 result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    for (NSUInteger i = 0; i < noBands; i++) {
        result = AudioUnitSetParameter(mEQ, kAUNBandEQParam_Frequency+i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)[[eqFrequencies objectAtIndex:i] floatValue], 0);
        if (result) { printf("set NumberOfBands Property2 result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    }
    
    for (NSUInteger i = 0; i < noBands; i++) {
        result = AudioUnitSetParameter(mEQ, kAUNBandEQParam_BypassBand+i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)0, 0);
        if (result) { printf("set NumberOfBands Property3 result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
        
        AudioUnitParameterID parameterID = kAUNBandEQParam_Gain + i;
        OSStatus result = AudioUnitSetParameter(mEQ, parameterID, kAudioUnitScope_Global, 0, -1110.0, 0);
        if (result) { printf("AudioUnitSetParameter result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
    }
}

- (void)addIpodEQNode {
    CAComponentDescription ipod_eq_desc(kAudioUnitType_Effect, kAudioUnitSubType_AUiPodEQ, kAudioUnitManufacturer_Apple);
    OSStatus result = AUGraphAddNode(mGraph, &ipod_eq_desc, &ipodEQNode);
    if (result) { printf("AUGraphNewNode 3 result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphConnectNodeInput(mGraph, eqNode, 0, ipodEQNode, 0);
	if (result) { printf("AUGraphConnectNodeInput result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphNodeInfo(mGraph, ipodEQNode, NULL, &iPodEQ);
    if (result) { printf("AUGraphNodeInfo result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    UInt32 size = sizeof(mEQPresetsArray);
    result = AudioUnitGetProperty(iPodEQ, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size);
    if (result) { printf("AudioUnitGetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    result = AudioUnitSetProperty(iPodEQ, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(mOutputFormat));
    if (result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)addHightPassFiliterNode {
    CAComponentDescription hightPass_filiter_desc(kAudioUnitType_Effect, kAudioUnitSubType_HighPassFilter, kAudioUnitManufacturer_Apple);
    OSStatus result = AUGraphAddNode(mGraph, &hightPass_filiter_desc, &hightPassFiliterNode);
    if (result) { printf("AUGraphNewNode 4 result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphConnectNodeInput(mGraph, ipodEQNode, 0, hightPassFiliterNode, 0);
	if (result) { printf("AUGraphConnectNodeInput result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphNodeInfo(mGraph, hightPassFiliterNode, NULL, &hightPassFiliter);
    if (result) { printf("AUGraphNodeInfo result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    Float32 highPassFilterCutoff = 500.0;
    result = AudioUnitSetParameter(hightPassFiliter, kHipassParam_CutoffFrequency, kAudioUnitScope_Global, 0, highPassFilterCutoff, 0);
    if (result) { printf("set hight pass filiter result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)addLowPassFiliterNode {
    CAComponentDescription lowPass_filiter_desc(kAudioUnitType_Effect, kAudioUnitSubType_LowPassFilter, kAudioUnitManufacturer_Apple);
    OSStatus result = AUGraphAddNode(mGraph, &lowPass_filiter_desc, &lowPassFiliterNode);
    if (result) { printf("AUGraphNewNode 5 result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphConnectNodeInput(mGraph, hightPassFiliterNode, 0, lowPassFiliterNode, 0);
	if (result) { printf("AUGraphConnectNodeInput result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphNodeInfo(mGraph, lowPassFiliterNode, NULL, &lowPassFiliter);
    if (result) { printf("AUGraphNodeInfo result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    Float32 lowPassFilterCutoff = 500.0;
    result = AudioUnitSetParameter(lowPassFiliter, kLowPassParam_CutoffFrequency, kAudioUnitScope_Global, 0, lowPassFilterCutoff, 0);
    if (result) { printf("set low pass filiter result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)initializeAUGraph {
    printf("initializeAUGraph\n");
	
	OSStatus result = result = NewAUGraph(&mGraph);
    if (result) { printf("NewAUGraph result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    result = AUGraphOpen(mGraph);
	if (result) { printf("AUGraphOpen result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    result = AUGraphAddRenderNotify(mGraph, renderNotification, &mUserData);
    if (result) { printf("AUGraphAddRenderNotify result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
	result = AUGraphInitialize(mGraph);
    if (result) { printf("AUGraphInitialize result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    CAShow(mGraph);
    
	CAComponentDescription mixer_desc(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer, kAudioUnitManufacturer_Apple);
    result = AUGraphAddNode(mGraph, &mixer_desc, &mixerNode);
	if (result) { printf("AUGraphNewNode 6 result %lu %4.4s\n", result, (char*)&result); return; }
    
    CAComponentDescription output_desc(kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple);
	result = AUGraphAddNode(mGraph, &output_desc, &outputNode);
	if (result) { printf("AUGraphNewNode 1 result %lu %4.4s\n", result, (char*)&result); return; }
    
    result = AUGraphConnectNodeInput(mGraph, mixerNode, 0, outputNode, 0);
    if (result) { printf("AUGraphConnectNodeInput result %lu %4.4s\n", result, (char*)&result); return; }
	
	result = AUGraphNodeInfo(mGraph, mixerNode, NULL, &mMixer);
    if (result) { printf("AUGraphNodeInfo result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
	UInt32 numbuses = 2;
    result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    if (result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }

	for (UInt32 i = 0; i < numbuses; ++i) {
		AURenderCallbackStruct rcbs;
		rcbs.inputProc = &renderInput;
		rcbs.inputProcRefCon = &mUserData;
        
        result = AUGraphSetNodeInputCallback(mGraph, mixerNode, i, &rcbs);
        if (result) { printf("AUGraphSetNodeInputCallback result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
		
		result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &mClientFormat, sizeof(mClientFormat));
        if (result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
	}
    
//	result = AudioUnitSetProperty(mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mOutputFormat, sizeof(mOutputFormat));
//    if (result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
    
    [self addEqNode];
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

- (void)selectEQPreset:(NSInteger)value {
    if (isCustom) {
        isCustom = NO;
        for (NSUInteger i=0; i<noBands; i++) {
            OSStatus result = AudioUnitSetParameter(mEQ, kAUNBandEQParam_BypassBand+i, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)0, 0);
            if (result) { printf("set NumberOfBands Property3 result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
        }
    }
    
    isIPodDefined = YES;
    AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, value);
    OSStatus result = AudioUnitSetProperty(iPodEQ, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, aPreset, sizeof(AUPreset));
    if (result) { printf("AudioUnitSetProperty result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; };
    
    printf("SET EQ PRESET %d ", value);
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

- (void)hightPassValue:(CGFloat)v {
    Float32 highPassFilterCutoff = v;
    OSStatus result = AudioUnitSetParameter(hightPassFiliter, kHipassParam_CutoffFrequency, kAudioUnitScope_Global, 0, highPassFilterCutoff, 0);
    if (result) { printf("set hight pass filiter result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
}

- (void)lowPassValue:(CGFloat)v {
    Float32 lowPassFilterCutoff = v;
    OSStatus result = AudioUnitSetParameter(lowPassFiliter, kLowPassParam_CutoffFrequency, kAudioUnitScope_Global, 0, lowPassFilterCutoff, 0);
    if (result) { printf("set low pass filiter result %ld %08X %4.4s\n", result, (unsigned int)result, (char*)&result); return; }
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