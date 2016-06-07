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

#define kDefaultSize 1024 * 20

typedef struct {
	AudioFileID                  srcFileID;
	SInt64                       srcFilePos;
	char                         *srcBuffer;
	UInt32                       srcBufferSize;
	CAStreamBasicDescription     srcFormat;
	UInt32                       srcSizePerPacket;
    double                       packetDuration;
	AudioStreamPacketDescription *packetDescriptions;
    
    UInt64                       audioDataOffset;
    UInt64                       audioDataByteCount;
    UInt64                       audioDataPacketCount;
    UInt32                       bitRate;
    NSTimeInterval               duration;
} AudioFileIO, *AudioFileIOPtr;

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    
    id<AQConverterDelegate> afioDelegate;
    off_t contentLength;
    off_t bytesCanRead;
    off_t bytesOffset;
    BOOL stopRunloop;
    
    AudioFileIOPtr afio;
} AudioBase, *AudioBasePtr;

static void timerStop(AudioBasePtr ab, BOOL flag) {
    if (ab->afioDelegate && [ab->afioDelegate respondsToSelector:@selector(AQConverter:timerStop:)]) {
        [ab->afioDelegate AQConverter:nil timerStop:flag];
    }
}

static OSStatus encoderDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
	AudioBasePtr ab = (AudioBasePtr)inUserData;
	
	UInt32 maxPackets = ab->afio->srcBufferSize / ab->afio->srcSizePerPacket;
	if (*ioNumberDataPackets > maxPackets) {
        *ioNumberDataPackets = maxPackets;
    }
    
    pthread_mutex_lock(&ab->mutex);
    while ((ab->bytesOffset + ab->afio->srcBufferSize) > ab->bytesCanRead && !ab->stopRunloop) {
        if (ab->bytesCanRead < ab->contentLength) {
            timerStop(ab, YES);
            pthread_cond_wait(&ab->cond, &ab->mutex);
        } else {
            break;
        }
    }
    pthread_mutex_unlock(&ab->mutex);
    
	UInt32 outNumBytes;
    OSStatus error = AudioFileReadPackets(ab->afio->srcFileID, false, &outNumBytes, ab->afio->packetDescriptions, ab->afio->srcFilePos, ioNumberDataPackets, ab->afio->srcBuffer);
	if (error) {
        NSLog(@"Input Proc Read error: %d (%4.4s)\n", (int)error, (char*)&error);
        return error;
    }
	
    ab->bytesOffset += outNumBytes;
	ab->afio->srcFilePos += *ioNumberDataPackets;
    
	ioData->mBuffers[0].mData = ab->afio->srcBuffer;
	ioData->mBuffers[0].mDataByteSize = outNumBytes;
	ioData->mBuffers[0].mNumberChannels = ab->afio->srcFormat.mChannelsPerFrame;
    
	if (outDataPacketDescription) {
		if (ab->afio->packetDescriptions) {
			*outDataPacketDescription = ab->afio->packetDescriptions;
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
@property (nonatomic, assign) AudioBasePtr ab;
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
@synthesize ab;
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
    
    if (self.ab != NULL && self.ab->afio != NULL) {
        if (self.ab->afio->srcBuffer) {
            delete [] self.ab->afio->srcBuffer;
        }
        
        if (self.ab->afio->packetDescriptions) {
            delete [] self.ab->afio->packetDescriptions;
        }
        
        free(self.ab->afio);
    }
    
    if (self.outputBuffer) {
        delete [] self.outputBuffer;
    }
    
    if (self.outputPacketDescriptions) {
        delete [] self.outputPacketDescriptions;
    }
}

- (void)dealloc {
    NSLog(@"===================AQConverter dealloc===================\n");
    
    [self clear];
    
    if (self.ab != NULL) {
        pthread_mutex_destroy(&self.ab->mutex);
        pthread_cond_destroy(&self.ab->cond);
        
        free(self.ab);
    }
}

- (id)init {
    self = [super init];
    
    if (self) {
        self.ab = (AudioBasePtr)malloc(sizeof(AudioBase));
        bzero(self.ab, sizeof(AudioBase));
        
        pthread_mutex_init(&self.ab->mutex, NULL);
        pthread_cond_init(&self.ab->cond, NULL);
        
        self.ab->afioDelegate = nil;
        self.ab->contentLength = self.ab->bytesCanRead = self.ab->bytesOffset = 0;
        self.ab->stopRunloop = NO;
        
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
    
    self.ab->afio = (AudioFileIOPtr)malloc(sizeof(AudioFileIO));
    bzero(self.ab->afio, sizeof(AudioFileIO));
    self.ab->afioDelegate = self.delegate;
    
    try {
        if (self.sourceURL == NULL) {
            self.sourceURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)url, kCFURLPOSIXPathStyle, false);
        }
        
        pthread_mutex_lock(&self.ab->mutex);
        OSStatus error = AudioFileOpenURL(sourceURL, kAudioFileReadPermission, 0, &sourceFileID);
        while ((error || self.sourceFileID == NULL) && !self.ab->stopRunloop) {
            if (self.ab->bytesCanRead > self.ab->contentLength * 0.2) {
                pthread_mutex_unlock(&self.ab->mutex);
                if (self.delegate && [self.delegate respondsToSelector:@selector(AQConverter:playNext:)]) {
                    [self.delegate AQConverter:self playNext:YES];
                }
                return;
            }
            
            timerStop(self.ab, YES);
            pthread_cond_wait(&self.ab->cond, &self.ab->mutex);
            error = AudioFileOpenURL(sourceURL, kAudioFileReadPermission, 0, &sourceFileID);
        }
        pthread_mutex_unlock(&self.ab->mutex);
        
        UInt32 size = sizeof(srcFormat);
        XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyDataFormat, &size, &srcFormat), "couldn't get source data format");

        size = sizeof(self.ab->afio->audioDataOffset);
        XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyDataOffset, &size, &self.ab->afio->audioDataOffset), "couldn't get kAudioFilePropertyDataOffset");
        if (self.ab->bytesOffset == 0) {
            self.ab->bytesOffset = self.ab->afio->audioDataOffset;
        }
        
        size = sizeof(self.ab->afio->audioDataByteCount);
        XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyAudioDataByteCount, &size, &self.ab->afio->audioDataByteCount), "couldn't get kAudioFilePropertyAudioDataByteCount");
        if (self.ab->afio->audioDataByteCount < self.ab->contentLength - self.ab->afio->audioDataOffset) {
            self.ab->afio->audioDataByteCount = self.ab->contentLength - self.ab->afio->audioDataOffset;
        }
        
        size = sizeof(self.ab->afio->bitRate);
        XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyBitRate, &size, &self.ab->afio->bitRate), "couldn't get kAudioFilePropertyBitRate");
        if (self.delegate && [self.delegate respondsToSelector:@selector(AQConverter:duration:zeroCurrentTime:)]) {
            self.ab->afio->duration = self.ab->afio->audioDataByteCount * 8 / self.ab->afio->bitRate;
            [self.delegate AQConverter:self duration:self.ab->afio->duration zeroCurrentTime:(pos == 0 ? YES : NO)];
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
        
        self.ab->afio->srcFileID = self.sourceFileID;
        self.ab->afio->srcBufferSize = kDefaultSize;
        self.ab->afio->srcBuffer = new char [self.ab->afio->srcBufferSize];
        self.ab->afio->srcFilePos = pos;
        self.ab->afio->srcFormat = srcFormat;
        
        self.ab->afio->packetDuration = self.ab->afio->srcFormat.mFramesPerPacket / self.ab->afio->srcFormat.mSampleRate;
        self.ab->afio->audioDataPacketCount = self.ab->afio->duration / self.ab->afio->packetDuration;
		
        if (srcFormat.mBytesPerPacket == 0) {
            size = sizeof(self.ab->afio->srcSizePerPacket);
            XThrowIfError(AudioFileGetProperty(self.sourceFileID, kAudioFilePropertyMaximumPacketSize, &size, &self.ab->afio->srcSizePerPacket), "AudioFileGetProperty kAudioFilePropertyMaximumPacketSize failed!");
            if (self.ab->afio->srcSizePerPacket > 0) {
                self.ab->afio->packetDescriptions = new AudioStreamPacketDescription[self.ab->afio->srcBufferSize / self.ab->afio->srcSizePerPacket];
            } else {
                self.ab->afio->packetDescriptions = NULL;
            }
        } else {
            self.ab->afio->srcSizePerPacket = srcFormat.mBytesPerPacket;
            self.ab->afio->packetDescriptions = NULL;
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
        while (!self.ab->stopRunloop) {
            AudioBufferList fillBufList;
            fillBufList.mNumberBuffers = 1;
            fillBufList.mBuffers[0].mNumberChannels = dstFormat.mChannelsPerFrame;
            fillBufList.mBuffers[0].mDataByteSize = theOutputBufSize;
            fillBufList.mBuffers[0].mData = self.outputBuffer;

            UInt32 ioOutputDataPackets = numOutputPackets;
            error = AudioConverterFillComplexBuffer(self.converter, encoderDataProc, self.ab, &ioOutputDataPackets, &fillBufList, self.outputPacketDescriptions);
            if (error || ioOutputDataPackets == 0) {
                if (error) {
                    if (kAudioConverterErr_HardwareInUse == error) {
                        NSLog(@"Audio Converter returned kAudioConverterErr_HardwareInUse!\n");
                    } else {
                        NSLog(@"AudioConverterFillComplexBuffer error!\n");
                        
                        off_t old_bytesCanRead = self.ab->bytesCanRead;
                        pthread_mutex_lock(&self.ab->mutex);
                        while (self.ab->bytesCanRead < old_bytesCanRead + kDefaultSize * 5 && !self.ab->stopRunloop) {
                            if (self.ab->bytesCanRead < self.ab->contentLength) {
                                timerStop(self.ab, YES);
                                pthread_cond_wait(&self.ab->cond, &self.ab->mutex);
                            } else {
                                break;
                            }
                        }
                        pthread_mutex_unlock(&self.ab->mutex);
                    }
                } else {
                    NSLog(@"ioOutputDataPackets == 0 \n");
                }
                
                UInt64 maxAudioDataOffset = self.ab->afio->audioDataOffset + self.ab->afio->audioDataByteCount;
                if (self.ab->bytesOffset < maxAudioDataOffset && self.ab->afio->srcFilePos < self.ab->afio->audioDataPacketCount) {
                    self.again = YES;
                    break;
                }
            }
            
            if (error == noErr && ioOutputDataPackets > 0 && fillBufList.mBuffers[0].mDataByteSize > 0) {
                timerStop(self.ab, NO);
                [self.graph addBuf:fillBufList.mBuffers[0].mData numberBytes:fillBufList.mBuffers[0].mDataByteSize];
            }
        }
    } catch (CAXException e) {
		char buf[256];
		NSLog(@"Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
	}
    
    if (self.again) {
        self.again = NO;
        SInt64 pos = self.ab->afio->srcFilePos;
        [self clear];
        [self doConvertFile:url srcFilePos:pos];
    }
}

- (void)doConvertFile:(NSString*)url {
    [self doConvertFile:url srcFilePos:0];
}

- (void)signal {
    pthread_mutex_lock(&self.ab->mutex);
    pthread_cond_signal(&self.ab->cond);
    pthread_mutex_unlock(&self.ab->mutex);
}

- (void)play {
    [self.graph startAUGraph];
}

- (void)stop {
    [self.graph stopAUGraph];
}

- (void)seek:(NSTimeInterval)seekToTime {
    self.ab->bytesOffset = self.ab->afio->audioDataOffset + self.ab->afio->audioDataByteCount * (seekToTime / self.ab->afio->duration);
    
    self.ab->afio->srcFilePos = (UInt32)(seekToTime / self.ab->afio->packetDuration);
    [self signal];
}

- (void)setContentLength:(off_t)len {
    self.ab->contentLength = len;
}

- (void)setBytesCanRead:(off_t)bytes {
    self.ab->bytesCanRead = bytes;
}

- (void)setStopRunloop:(BOOL)stop {
    self.ab->stopRunloop = stop;
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
