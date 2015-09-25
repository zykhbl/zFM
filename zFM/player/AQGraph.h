#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "AQRing.h"

#import "CAStreamBasicDescription.h"
#import "CAComponentDescription.h"

#define MAXBUFS  2
#define NUMFILES 2

typedef struct {
    AudioStreamBasicDescription asbd;
    AQRing *data;
} SoundBuffer, *SoundBufferPtr;

typedef struct {
    SoundBuffer soundBuffer[MAXBUFS];
} SourceAudioBufferData, *SourceAudioBufferDataPtr;

@interface AQGraph : NSObject {
	AUGraph   mGraph;
    
    AUNode mixerNode;
    AUNode eqNode;
    AUNode ipodEQNode;
    AUNode hightPassFiliterNode;
    AUNode lowPassFiliterNode;
    AUNode outputNode;
    
    AudioUnit mMixer;
    AudioUnit mEQ;
    AudioUnit iPodEQ;
    AudioUnit hightPassFiliter;
    AudioUnit lowPassFiliter;
    
    CAStreamBasicDescription mClientFormat;
    CAStreamBasicDescription mOutputFormat;
    
    CFArrayRef mEQPresetsArray;
    
    SourceAudioBufferData mUserData;

	Boolean mIsPlaying;
    
    UInt32 noBands;
    BOOL isCustom;
    BOOL isIPodDefined;
}

@property (readonly, nonatomic, getter=isPlaying) Boolean mIsPlaying;
@property (readonly, nonatomic, getter=iPodEQPresetsArray) CFArrayRef mEQPresetsArray;

- (void)awakeFromNib;
- (void)setasbd:(AudioStreamBasicDescription)asbd;
- (void)addBuf:(const void*)inInputData numberBytes:(UInt32)inNumberBytes;

- (void)initializeAUGraph;

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue;
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value;
- (void)setOutputVolume:(AudioUnitParameterValue)value;
- (void)selectEQPreset:(NSInteger)value;
- (void)changeTag:(int)tag value:(CGFloat)v;
- (void)hightPassValue:(CGFloat)v;
- (void)lowPassValue:(CGFloat)v;
- (void)changeBaseFrequency:(CGFloat)v;

- (void)startAUGraph;
- (void)stopAUGraph;

@end
