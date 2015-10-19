//
//  AQConverter.m
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import "AQConverter.h"
#import <AudioToolbox/AudioToolbox.h>
#import "CAXException.h"
#import "CAStreamBasicDescription.h"
#import "AQGraph.h"
#import "IpodEQ.h"
#import "CustomEQ.h"

#define kDefaultSize 1024 * 10

static pthread_mutex_t mutex;
static pthread_cond_t cond;

static id<AQConverterDelegate> afioDelegate;
static off_t contentLength;
static off_t bytesCanRead;
static off_t bytesOffset;
static BOOL stopRunloop;

typedef struct {
	AudioFileID                  srcFileID;
	SInt64                       srcFilePos;
	char                         *srcBuffer;
	UInt32                       srcBufferSize;
	CAStreamBasicDescription     srcFormat;
	UInt32                       srcSizePerPacket;
	AudioStreamPacketDescription *packetDescriptions;
    
    UInt64                       audioDataOffset;
    UInt32                       bitRate;
    NSTimeInterval               duration;
} AudioFileIO, *AudioFileIOPtr;

static void timerStop(BOOL flag) {
    if (afioDelegate && [afioDelegate respondsToSelector:@selector(AQConverter:timerStop:)]) {
        [afioDelegate AQConverter:nil timerStop:flag];
    }
}

static OSStatus encoderDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
	AudioFileIOPtr afio = (AudioFileIOPtr)inUserData;
	
	UInt32 maxPackets = afio->srcBufferSize / afio->srcSizePerPacket;
	if (*ioNumberDataPackets > maxPackets) {
        *ioNumberDataPackets = maxPackets;
    }
    
    pthread_mutex_lock(&mutex);
    while ((bytesOffset + afio->srcBufferSize) > bytesCanRead && !stopRunloop) {
        if (bytesCanRead < contentLength) {
            timerStop(YES);
            pthread_cond_wait(&cond, &mutex);
        } else {
            break;
        }
    }
    pthread_mutex_unlock(&mutex);
    
	UInt32 outNumBytes;
    OSStatus error = AudioFileReadPackets(afio->srcFileID, false, &outNumBytes, afio->packetDescriptions, afio->srcFilePos, ioNumberDataPackets, afio->srcBuffer);
	if (error) { NSLog(@"Input Proc Read error: %d (%4.4s)\n", (int)error, (char*)&error); return error; }
	
    bytesOffset += outNumBytes;
	afio->srcFilePos += *ioNumberDataPackets;
    
	ioData->mBuffers[0].mData = afio->srcBuffer;
	ioData->mBuffers[0].mDataByteSize = outNumBytes;
	ioData->mBuffers[0].mNumberChannels = afio->srcFormat.mChannelsPerFrame;
    
	if (outDataPacketDescription) {
		if (afio->packetDescriptions) {
			*outDataPacketDescription = afio->packetDescriptions;
		} else {
			*outDataPacketDescription = NULL;
        }
	}
    
    return error;
}

static void readCookie(AudioFileID sourceFileID, AudioConverterRef converter) {
	UInt32 cookieSize = 0;
	OSStatus error = AudioFileGetPropertyInfo(sourceFileID, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    
	if (noErr == error && 0 != cookieSize) {
		char *cookie = new char [cookieSize];
		
		error = AudioFileGetProperty(sourceFileID, kAudioFilePropertyMagicCookieData, &cookieSize, cookie);
        if (noErr == error) {
            error = AudioConverterSetProperty(converter, kAudioConverterDecompressionMagicCookie, cookieSize, cookie);
            if (error) { NSLog(@"Could not Set kAudioConverterDecompressionMagicCookie on the Audio Converter!\n"); }
        } else {
            NSLog(@"Could not Get kAudioFilePropertyMagicCookieData from source file!\n");
        }
		
		delete [] cookie;
	}
}

@interface AQConverter ()

@property (nonatomic, assign) CFURLRef sourceURL;
@property (nonatomic, assign) AudioConverterRef converter;
@property (nonatomic, assign) AudioFileID sourceFileID;
@property (nonatomic, assign) AudioFileIOPtr afio;
@property (nonatomic, assign) char *outputBuffer;
@property (nonatomic, assign) AudioStreamPacketDescription *outputPacketDescriptions;
@property (nonatomic, strong) AQGraph *graph;
@property (nonatomic, assign) BOOL again;

@end

@implementation AQConverter

@synthesize delegate;

@synthesize sourceURL;
@synthesize converter;
@synthesize sourceFileID;
@synthesize afio;
@synthesize outputBuffer;
@synthesize graph;
@synthesize again;

- (void)clear {
    if (self.sourceURL) {
        CFRelease(self.sourceURL);
        self.sourceURL = NULL;
    }
    
    if (self.converter) {
        AudioConverterDispose(self.converter);
    }
    
	if (self.sourceFileID) {
        AudioFileClose(self.sourceFileID);
    }
    
    if (self.afio != NULL) {
        if (self.afio->srcBuffer) {
            delete [] self.afio->srcBuffer;
        }
        
        if (self.afio->packetDescriptions) {
            delete [] self.afio->packetDescriptions;
        }
        
        free(self.afio);
    }
    
    if (self.outputBuffer) {
        delete [] self.outputBuffer;
    }
    
    if (self.outputPacketDescriptions) {
        delete [] self.outputPacketDescriptions;
    }
}

- (void)dealloc {
    [self clear];
    
    pthread_mutex_destroy(&mutex);
    pthread_cond_destroy(&cond);
}

- (id)init {
    self = [super init];
    
    if (self) {
        pthread_mutex_init(&mutex, NULL);
        pthread_cond_init(&cond, NULL);
        
        afioDelegate = nil;
        contentLength = bytesCanRead = bytesOffset = 0;
        stopRunloop = NO;
        
        self.sourceURL = NULL;
        self.sourceFileID = 0;
        self.converter = 0;
        self.outputBuffer = NULL;
        self.outputPacketDescriptions = NULL;
        self.again = NO;
    }
    
    return self;
}

- (void)createGraph:(CAStreamBasicDescription)dstFormat {
    if (self.graph == nil) {
        self.graph = [[AQGraph alloc] init];
        
        [self.graph awakeFromNib];
        [self.graph setasbd:dstFormat];
        [self.graph initializeAUGraph];
        
        [self.graph enableInput:0 isOn:1.0];
        [self.graph enableInput:1 isOn:0.0];
        [self.graph setInputVolume:0 value:1.0];
        [self.graph setInputVolume:1 value:0.0];
        [self.graph setOutputVolume:1.0];
        
        [self.graph startAUGraph];
        
        [self.graph selectIpodEQPreset:[[IpodEQ sharedIpodEQ] selected]];
        for (int i = 0; i < [[[CustomEQ sharedCustomEQ] eqFrequencies] count]; ++i) {
            CGFloat eqValue = [[CustomEQ sharedCustomEQ] getEQValueInIndex:i];
            [self.graph changeEQ:i value:eqValue];
        }
    }
}

- (void)doConvertFile:(NSString*)url srcFilePos:(SInt64)pos {
    CAStreamBasicDescription srcFormat, dstFormat;
    
    self.afio = (AudioFileIOPtr)malloc(sizeof(AudioFileIO));
    bzero(self.afio, sizeof(AudioFileIO));
    afioDelegate = self.delegate;
    
    try {
        if (self.sourceURL == NULL) {
            self.sourceURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)url, kCFURLPOSIXPathStyle, false);
        }
        
        pthread_mutex_lock(&mutex);
        OSStatus error = AudioFileOpenURL(sourceURL, kAudioFileReadPermission, 0, &sourceFileID);
        while (error && !stopRunloop) {
            if (bytesCanRead > contentLength * 0.01) {
                pthread_mutex_unlock(&mutex);
                if (self.delegate && [self.delegate respondsToSelector:@selector(AQConverter:playNext:)]) {
                    [self.delegate AQConverter:self playNext:YES];
                }
                return;
            }
            
            timerStop(YES);
            pthread_cond_wait(&cond, &mutex);
            error = AudioFileOpenURL(sourceURL, kAudioFileReadPermission, 0, &sourceFileID);
        }
        pthread_mutex_unlock(&mutex);
        
        UInt32 size = sizeof(srcFormat);
        XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyDataFormat, &size, &srcFormat), "couldn't get source data format");

        size = sizeof(self.afio->audioDataOffset);
        XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyDataOffset, &size, &self.afio->audioDataOffset), "couldn't get kAudioFilePropertyDataOffset");
        if (bytesOffset == 0) {
            bytesOffset = self.afio->audioDataOffset;
        }
        
        size = sizeof(self.afio->bitRate);
        XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyBitRate, &size, &self.afio->bitRate), "couldn't get kAudioFilePropertyBitRate");
        if (self.delegate && [self.delegate respondsToSelector:@selector(AQConverter:duration:zeroCurrentTime:)]) {
            self.afio->duration = (contentLength - self.afio->audioDataOffset) * 8 / self.afio->bitRate;
            [self.delegate AQConverter:self duration:self.afio->duration zeroCurrentTime:(pos == 0 ? YES : NO)];
        }
        
        dstFormat.mSampleRate = srcFormat.mSampleRate;
        dstFormat.mFormatID = kAudioFormatLinearPCM;
        dstFormat.mChannelsPerFrame = srcFormat.NumberChannels();
        dstFormat.mBitsPerChannel = 16;
        dstFormat.mBytesPerPacket = dstFormat.mBytesPerFrame = 2 * dstFormat.mChannelsPerFrame;
        dstFormat.mFramesPerPacket = 1;
        dstFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger;
        
        XThrowIfError(AudioConverterNew(&srcFormat, &dstFormat, &converter), "AudioConverterNew failed!");
        
        readCookie(self.sourceFileID, self.converter);
        
        size = sizeof(srcFormat);
        XThrowIfError(AudioConverterGetProperty(self.converter, kAudioConverterCurrentInputStreamDescription, &size, &srcFormat), "AudioConverterGetProperty kAudioConverterCurrentInputStreamDescription failed!");
        
        size = sizeof(dstFormat);
        XThrowIfError(AudioConverterGetProperty(self.converter, kAudioConverterCurrentOutputStreamDescription, &size, &dstFormat), "AudioConverterGetProperty kAudioConverterCurrentOutputStreamDescription failed!");
        
        [self createGraph:dstFormat];
        
        self.afio->srcFileID = self.sourceFileID;
        self.afio->srcBufferSize = kDefaultSize;
        self.afio->srcBuffer = new char [self.afio->srcBufferSize];
        self.afio->srcFilePos = pos;
        self.afio->srcFormat = srcFormat;
		
        if (srcFormat.mBytesPerPacket == 0) {
            size = sizeof(self.afio->srcSizePerPacket);
            XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyMaximumPacketSize, &size, &self.afio->srcSizePerPacket), "AudioFileGetProperty kAudioFilePropertyMaximumPacketSize failed!");
            self.afio->packetDescriptions = new AudioStreamPacketDescription[self.afio->srcBufferSize / self.afio->srcSizePerPacket];
        } else {
            self.afio->srcSizePerPacket = srcFormat.mBytesPerPacket;
            self.afio->packetDescriptions = NULL;
        }
        
        UInt32 outputSizePerPacket = dstFormat.mBytesPerPacket;
        UInt32 theOutputBufSize = kDefaultSize;
        self.outputBuffer = new char[theOutputBufSize];
        
        if (outputSizePerPacket == 0) {
            size = sizeof(outputSizePerPacket);
            XThrowIfError(AudioConverterGetProperty(self.converter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &outputSizePerPacket), "AudioConverterGetProperty kAudioConverterPropertyMaximumOutputPacketSize failed!");
            self.outputPacketDescriptions = new AudioStreamPacketDescription [theOutputBufSize / outputSizePerPacket];
        }
        
        UInt32 numOutputPackets = theOutputBufSize / outputSizePerPacket;
        while (!stopRunloop) {
            AudioBufferList fillBufList;
            fillBufList.mNumberBuffers = 1;
            fillBufList.mBuffers[0].mNumberChannels = dstFormat.mChannelsPerFrame;
            fillBufList.mBuffers[0].mDataByteSize = theOutputBufSize;
            fillBufList.mBuffers[0].mData = self.outputBuffer;

            UInt32 ioOutputDataPackets = numOutputPackets;
            error = AudioConverterFillComplexBuffer(self.converter, encoderDataProc, self.afio, &ioOutputDataPackets, &fillBufList, self.outputPacketDescriptions);
            if (error) {
                if (kAudioConverterErr_HardwareInUse == error) {
                    NSLog(@"Audio Converter returned kAudioConverterErr_HardwareInUse!\n");
                } else {
                    XThrowIfError(error, "AudioConverterFillComplexBuffer error!");
                }
            } else {
                if (ioOutputDataPackets == 0) {
                    self.again = YES;
                    break;
                }
            }
            
            if (noErr == error) {
                timerStop(NO);
                
                [self.graph addBuf:fillBufList.mBuffers[0].mData numberBytes:fillBufList.mBuffers[0].mDataByteSize];
            }
        }
    } catch (CAXException e) {
		char buf[256];
		NSLog(@"Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
	}
    
    if (self.again) {
        self.again = NO;
        SInt64 pos = self.afio->srcFilePos;
        [self clear];
        [self doConvertFile:url srcFilePos:pos];
    }
}

- (void)doConvertFile:(NSString*)url {
    [self doConvertFile:url srcFilePos:0];
}

- (void)signal {
    pthread_mutex_lock(&mutex);
    pthread_cond_signal(&cond);
    pthread_mutex_unlock(&mutex);
}

- (void)play {
    [self.graph startAUGraph];
}

- (void)stop {
    [self.graph stopAUGraph];
}

- (void)seek:(NSTimeInterval)seekToTime {
    bytesOffset = self.afio->audioDataOffset + (contentLength - self.afio->audioDataOffset) * (seekToTime / self.afio->duration);
    
    double packetDuration = self.afio->srcFormat.mFramesPerPacket / self.afio->srcFormat.mSampleRate;
    self.afio->srcFilePos = (UInt32)(seekToTime / packetDuration);
    [self signal];
}

- (void)setContentLength:(off_t)len {
    contentLength = len;
}

- (void)setBytesCanRead:(off_t)bytes {
    bytesCanRead = bytes;
}

- (void)setStopRunloop:(BOOL)stop {
    stopRunloop = stop;
}

- (void)selectIpodEQPreset:(NSInteger)index {
    if (self.graph != nil) {
        [self.graph selectIpodEQPreset:index];
    }
}

- (void)changeEQ:(int)index value:(CGFloat)v {
    if (self.graph != nil) {
        [self.graph changeEQ:index value:v];
    }
}

@end
