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

#define kDefaultSize 1024 * 5

enum {
    kMyAudioConverterErr_CannotResumeFromInterruptionError = 'CANT',
    eofErr = -39
};

typedef struct {
	AudioFileID                  srcFileID;
	SInt64                       srcFilePos;
	char *                       srcBuffer;
	UInt32                       srcBufferSize;
	CAStreamBasicDescription     srcFormat;
	UInt32                       srcSizePerPacket;
	UInt32                       numPacketsPerRead;
	AudioStreamPacketDescription *packetDescriptions;
} AudioFileIO, *AudioFileIOPtr;

static OSStatus encoderDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
	AudioFileIOPtr afio = (AudioFileIOPtr)inUserData;
	
	UInt32 maxPackets = afio->srcBufferSize / afio->srcSizePerPacket;
	if (*ioNumberDataPackets > maxPackets) {
        *ioNumberDataPackets = maxPackets;
    }
    
	UInt32 outNumBytes;
	OSStatus error = AudioFileReadPackets(afio->srcFileID, false, &outNumBytes, afio->packetDescriptions, afio->srcFilePos, ioNumberDataPackets, afio->srcBuffer);
	if (eofErr == error) {//todo
        error = noErr;
    }
	if (error) { printf ("Input Proc Read error: %ld (%4.4s)\n", error, (char*)&error); return error; }
	
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
            if (error) { printf("Could not Set kAudioConverterDecompressionMagicCookie on the Audio Converter!\n"); }
        } else {
            printf("Could not Get kAudioFilePropertyMagicCookieData from source file!\n");
        }
		
		delete [] cookie;
	}
}

@interface AQConverter ()

@property (nonatomic, retain) AQGraph *graph;

@end

@implementation AQConverter

@synthesize graph;

- (OSStatus)doConvertFile:(NSString*)url {
	AudioFileID         sourceFileID = 0;
    AudioConverterRef   converter = NULL;
    Boolean             canResumeFromInterruption = true;
    
    CAStreamBasicDescription srcFormat, dstFormat;
    AudioFileIO afio = {};
    
    char *outputBuffer = NULL;
    AudioStreamPacketDescription *outputPacketDescriptions = NULL;
    
    OSStatus error = noErr;
    try {
        CFURLRef sourceURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)url, kCFURLPOSIXPathStyle, false);
        XThrowIfError(AudioFileOpenURL(sourceURL, kAudioFileReadPermission, 0, &sourceFileID), "AudioFileOpenURL failed");
        CFRelease(sourceURL);
        
        UInt32 size = sizeof(srcFormat);
        XThrowIfError(AudioFileGetProperty(sourceFileID, kAudioFilePropertyDataFormat, &size, &srcFormat), "couldn't get source data format");
        
        dstFormat.mSampleRate = srcFormat.mSampleRate;
        dstFormat.mFormatID = kAudioFormatLinearPCM;
        dstFormat.mChannelsPerFrame = srcFormat.NumberChannels();
        dstFormat.mBitsPerChannel = 16;
        dstFormat.mBytesPerPacket = dstFormat.mBytesPerFrame = 2 * dstFormat.mChannelsPerFrame;
        dstFormat.mFramesPerPacket = 1;
        dstFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger;
        
        XThrowIfError(AudioConverterNew(&srcFormat, &dstFormat, &converter), "AudioConverterNew failed!");
        
        readCookie(sourceFileID, converter);
        
        size = sizeof(srcFormat);
        XThrowIfError(AudioConverterGetProperty(converter, kAudioConverterCurrentInputStreamDescription, &size, &srcFormat), "AudioConverterGetProperty kAudioConverterCurrentInputStreamDescription failed!");
        
        size = sizeof(dstFormat);
        XThrowIfError(AudioConverterGetProperty(converter, kAudioConverterCurrentOutputStreamDescription, &size, &dstFormat), "AudioConverterGetProperty kAudioConverterCurrentOutputStreamDescription failed!");
        
        UInt32 canResume = 0;
        size = sizeof(canResume);
        error = AudioConverterGetProperty(converter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume);
        if (noErr == error) {
            if (0 == canResume) {
                canResumeFromInterruption = false;
            }
            printf("Audio Converter %s continue after interruption!\n", (canResumeFromInterruption == 0 ? "CANNOT" : "CAN"));
        } else {
            if (kAudioConverterErr_PropertyNotSupported == error) {
                printf("kAudioConverterPropertyCanResumeFromInterruption property not supported - see comments in source for more info.\n");
            } else {
                printf("AudioConverterGetProperty kAudioConverterPropertyCanResumeFromInterruption result %ld, paramErr is OK if PCM\n", error);
            }
            
            error = noErr;
        }
        
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
        }
        
        afio.srcFileID = sourceFileID;
        afio.srcBufferSize = kDefaultSize;
        afio.srcBuffer = new char [afio.srcBufferSize];
        afio.srcFilePos = 0;
        afio.srcFormat = srcFormat;
		
        if (srcFormat.mBytesPerPacket == 0) {
            size = sizeof(afio.srcSizePerPacket);
            XThrowIfError(AudioFileGetProperty(sourceFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &afio.srcSizePerPacket), "AudioFileGetProperty kAudioFilePropertyPacketSizeUpperBound failed!");
            
            afio.numPacketsPerRead = afio.srcBufferSize / afio.srcSizePerPacket;
            
            afio.packetDescriptions = new AudioStreamPacketDescription [afio.numPacketsPerRead];
        } else {
            afio.srcSizePerPacket = srcFormat.mBytesPerPacket;
            afio.numPacketsPerRead = afio.srcBufferSize / afio.srcSizePerPacket;
            afio.packetDescriptions = NULL;
        }
        
        UInt32 outputSizePerPacket = dstFormat.mBytesPerPacket;
        UInt32 theOutputBufSize = kDefaultSize;
        outputBuffer = new char[theOutputBufSize];
        
        if (outputSizePerPacket == 0) {
            size = sizeof(outputSizePerPacket);
            XThrowIfError(AudioConverterGetProperty(converter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &outputSizePerPacket), "AudioConverterGetProperty kAudioConverterPropertyMaximumOutputPacketSize failed!");
            
            outputPacketDescriptions = new AudioStreamPacketDescription [theOutputBufSize / outputSizePerPacket];
        }
        
        UInt32 numOutputPackets = theOutputBufSize / outputSizePerPacket;
        
        while (1) {
            AudioBufferList fillBufList;
            fillBufList.mNumberBuffers = 1;
            fillBufList.mBuffers[0].mNumberChannels = dstFormat.mChannelsPerFrame;
            fillBufList.mBuffers[0].mDataByteSize = theOutputBufSize;
            fillBufList.mBuffers[0].mData = outputBuffer;
            
            if (error && (false == canResumeFromInterruption)) {
                error = kMyAudioConverterErr_CannotResumeFromInterruptionError;
                break;
            }

            UInt32 ioOutputDataPackets = numOutputPackets;
            error = AudioConverterFillComplexBuffer(converter, encoderDataProc, &afio, &ioOutputDataPackets, &fillBufList, outputPacketDescriptions);
            if (error) {
                if (kAudioConverterErr_HardwareInUse == error) {
                    printf("Audio Converter returned kAudioConverterErr_HardwareInUse!\n");
                } else {
                    XThrowIfError(error, "AudioConverterFillComplexBuffer error!");
                }
            } else {
                if (ioOutputDataPackets == 0) {
                    error = noErr;
                    break;
                }
            }
            
            if (noErr == error) {
                [self.graph addBuf:fillBufList.mBuffers[0].mData numberBytes:fillBufList.mBuffers[0].mDataByteSize];
            }
        }
    } catch (CAXException e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
        error = e.mError;
	}
    
    if (converter) AudioConverterDispose(converter);
	if (sourceFileID) AudioFileClose(sourceFileID);
    
    if (afio.srcBuffer) delete [] afio.srcBuffer;
    if (afio.packetDescriptions) delete [] afio.packetDescriptions;
    if (outputBuffer) delete [] outputBuffer;
    if (outputPacketDescriptions) delete [] outputPacketDescriptions;
    
    return error;
}

- (void)change:(int)v {
    if (self.graph != nil) {
        [self.graph selectEQPreset:v];
    }
}

- (void)changeTag:(int)tag value:(CGFloat)v {
    if (self.graph != nil) {
        [self.graph changeTag:tag value:v];
    }
}

- (void)changeBaseFrequency:(CGFloat)v {
    if (self.graph != nil) {
        [self.graph changeBaseFrequency:v];
    }
}

- (void)start {
    [self.graph startAUGraph];
}

- (void)pause {
    [self.graph stopAUGraph];
}

@end
