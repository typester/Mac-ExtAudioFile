#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#undef Move

#define PERL_NO_GET_CONTEXT /* we want efficiency */
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#define NEED_newSVpvn_flags
#include "ppport.h"

typedef struct Mac__ExtAudioFile_s Mac__ExtAudioFile_t;
typedef Mac__ExtAudioFile_t* Mac__ExtAudioFile;

struct Mac__ExtAudioFile_s {
    ExtAudioFileRef eaf;
    AudioStreamBasicDescription asbd; /* client data format */
};

static void set_client_data_format(Mac__ExtAudioFile self, double sample_rate, U32 channels, U32 bits, bool is_float, bool is_signed_integer) {
    OSStatus status;
    AudioStreamBasicDescription asbd;

    asbd.mSampleRate       = sample_rate;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFormatFlags      = kAudioFormatFlagIsPacked;
    if (is_float) {
        asbd.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat;
    }
    else if (is_signed_integer) {
        asbd.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    }
    asbd.mChannelsPerFrame = channels;
    asbd.mBitsPerChannel   = bits;

    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame   = asbd.mBitsPerChannel/8 * asbd.mChannelsPerFrame;
    asbd.mBytesPerPacket  = asbd.mBytesPerFrame * asbd.mFramesPerPacket;

    status = ExtAudioFileSetProperty(
        self->eaf,
        kExtAudioFileProperty_ClientDataFormat,
        sizeof(asbd),
        &asbd
    );
    if (status) {
        croak("failed to set client data format: %d", status);
    }

    memcpy(&self->asbd, &asbd, sizeof(AudioStreamBasicDescription));
}

MODULE = Mac::ExtAudioFile  PACKAGE = Mac::ExtAudioFile

PROTOTYPES: DISABLE

Mac::ExtAudioFile
open(SV* class, char* path)
CODE:
{
    OSStatus status;
    NSURL* url;
    ExtAudioFileRef eaf;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    PERL_UNUSED_VAR(class);

    url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];

    status = ExtAudioFileOpenURL((CFURLRef)url, &eaf);
    if (status) {
        [pool drain];
        croak("failed to open file: %d", status);
    }

    Newx(RETVAL, 1, Mac__ExtAudioFile_t);
    RETVAL->eaf = eaf;
    memset(&RETVAL->asbd, 0, sizeof(AudioStreamBasicDescription));

    [pool drain];
}
OUTPUT:
    RETVAL

void
DESTROY(Mac::ExtAudioFile self)
CODE:
{
    ExtAudioFileDispose(self->eaf);
    Safefree(self);
}

void
_set_client_data_format(Mac::ExtAudioFile self, double sample_rate, U32 channels, U32 bits, bool is_float, bool is_signed_integer)
CODE:
{
    set_client_data_format(self, sample_rate, channels, bits, is_float, is_signed_integer);
}

I32
read(Mac::ExtAudioFile self, SV* sv_frames, SV* sv_data)
CODE:
{
    OSStatus status;
    U32 frames;
    AudioBufferList list;
    char* buf;

    if (!SvOK(sv_frames) || !SvIOK(sv_frames)) {
        croak("ioNumberFrames should be unsigned integer");
    }
    frames = SvIV(sv_frames);

    Newx(buf, frames * self->asbd.mBytesPerFrame, char);
    list.mNumberBuffers = 1;
    list.mBuffers[0].mNumberChannels = self->asbd.mChannelsPerFrame;
    list.mBuffers[0].mDataByteSize = frames * self->asbd.mBytesPerFrame;
    list.mBuffers[0].mData = (void*)buf;

    status = ExtAudioFileRead(self->eaf, &frames, &list);
    if (status) {
        Safefree(buf);
        croak("failed to read file: %d", status);
    }

    sv_setiv(sv_frames, frames);
    sv_setpvn(sv_data, buf, frames * self->asbd.mBytesPerFrame);
    RETVAL = status;
}
OUTPUT:
    RETVAL
