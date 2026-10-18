#import "../../Sources/AudioController.h"
#import <CoreAudio/CoreAudio.h>
#include "../../Sources/Policy.hpp"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

struct Fixture {
    AudioObjectID id;
    NSString *uid, *name;
    std::vector<AudioObjectID> outputs, inputs;
    bool alive=true, native=false;
};
static std::vector<Fixture> fixtures;
static AudioObjectID defaultOutput=11;
static unsigned writes=0;

static const Fixture *findDevice(AudioObjectID id) {
    for(const auto &d:fixtures) if(d.id==id) return &d;
    return nullptr;
}
template<class T> static OSStatus reply(UInt32 *size,void *data,const T &value) {
    if(*size<sizeof(T)) return kAudioHardwareBadPropertySizeError;
    memcpy(data,&value,sizeof(T)); *size=sizeof(T); return noErr;
}
static std::vector<AudioObjectID> objects(AudioObjectID id,const AudioObjectPropertyAddress *a) {
    if(id==kAudioObjectSystemObject && a->mSelector==kAudioHardwarePropertyDevices) {
        std::vector<AudioObjectID> result;
        for(const auto &d:fixtures) result.push_back(d.id);
        return result;
    }
    auto d=findDevice(id);
    if(d && a->mSelector==kAudioDevicePropertyStreams)
        return a->mScope==kAudioDevicePropertyScopeOutput ? d->outputs : d->inputs;
    return {};
}

// All HAL access is replaced. These tests cannot read or change real devices.
extern "C" OSStatus AudioObjectGetPropertyDataSize(AudioObjectID id,const AudioObjectPropertyAddress *a,
    UInt32,const void *,UInt32 *size) {
    *size=UInt32(objects(id,a).size()*sizeof(AudioObjectID)); return noErr;
}
extern "C" OSStatus AudioObjectGetPropertyData(AudioObjectID id,const AudioObjectPropertyAddress *a,
    UInt32,const void *,UInt32 *size,void *data) {
    if(a->mSelector==kAudioHardwarePropertyDefaultOutputDevice)
        return reply(size,data,defaultOutput);
    if(a->mSelector==kAudioHardwarePropertyDevices || a->mSelector==kAudioDevicePropertyStreams) {
        auto list=objects(id,a); UInt32 bytes=UInt32(list.size()*sizeof(AudioObjectID));
        if(*size<bytes) return kAudioHardwareBadPropertySizeError;
        if(bytes) memcpy(data,list.data(),bytes);
        *size=bytes; return noErr;
    }
    if(a->mSelector==kAudioStreamPropertyVirtualFormat) {
        AudioStreamBasicDescription f{};
        f.mSampleRate=48000; f.mFormatID=kAudioFormatLinearPCM;
        f.mFormatFlags=kAudioFormatFlagIsFloat; f.mBitsPerChannel=32;
        f.mChannelsPerFrame=2; f.mBytesPerFrame=8;
        return reply(size,data,f);
    }
    auto d=findDevice(id);
    if(!d) return kAudioHardwareBadObjectError;
    switch(a->mSelector) {
        case kAudioDevicePropertyDeviceUID:
        case kAudioObjectPropertyName: {
            CFStringRef value=(__bridge CFStringRef)(a->mSelector==kAudioDevicePropertyDeviceUID ? d->uid : d->name);
            CFRetain(value); return reply(size,data,value);
        }
        case kAudioDevicePropertyDeviceIsAlive: return reply(size,data,UInt32(d->alive));
        case kAudioDevicePropertyTransportType: return reply(size,data,UInt32(kAudioDeviceTransportTypeDisplayPort));
        case kAudioDevicePropertyNominalSampleRate: return reply(size,data,double(48000));
        case kAudioDevicePropertyBufferFrameSize: return reply(size,data,UInt32(512));
        default: return kAudioHardwareUnknownPropertyError;
    }
}
extern "C" Boolean AudioObjectHasProperty(AudioObjectID id,const AudioObjectPropertyAddress *a) {
    auto d=findDevice(id);
    return d && d->native && a->mSelector==kAudioDevicePropertyVolumeScalar;
}
extern "C" OSStatus AudioObjectIsPropertySettable(AudioObjectID id,const AudioObjectPropertyAddress *a,Boolean *writable) {
    *writable=AudioObjectHasProperty(id,a); return noErr;
}
extern "C" OSStatus AudioObjectSetPropertyData(AudioObjectID,const AudioObjectPropertyAddress *,UInt32,
    const void *,UInt32,const void *) { ++writes; return kAudioHardwareIllegalOperationError; }

@interface DVAudioController (TestAccess)
- (void)reconcile;
- (NSArray<NSDictionary *> *)readOutputDevices;
@end
@interface SelectionController : DVAudioController
@end
@implementation SelectionController
// Run the actual reconciliation synchronously, without timers, listeners or
// background enumeration. KVC seeds private state only in this test process;
// public preference-writing setters and start are intentionally not called.
- (void)refreshOutputDevicesIfNeeded {}
- (void)watch:(const dv::Device &)device { (void)device; }
@end

static void expect(SelectionController *c,NSString *uid,float percent,NSString *state) {
    NSDictionary *s=c.snapshot;
    if(![s[@"uid"] isEqual:uid] || [s[@"volume"] floatValue]!=percent || ![s[@"state"] isEqual:state])
        fprintf(stderr,"Expected uid=%s volume=%.0f state=%s; got uid=%s volume=%s state=%s\n",
            uid.UTF8String,percent,state.UTF8String,[s[@"uid"] UTF8String],
            [s[@"volume"] description].UTF8String,[s[@"state"] UTF8String]);
    assert([s[@"uid"] isEqual:uid]);
    assert([s[@"volume"] floatValue]==percent);
    assert([s[@"state"] isEqual:state]);
}
int main() { @autoreleasepool {
    NSString *logDirectory=[NSTemporaryDirectory() stringByAppendingPathComponent:
        [@"VolumeBridge-device-selection-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    [DVLogger startWithOverridePath:[logDirectory stringByAppendingPathComponent:@"test.log"]];
    fixtures={
        {11,@"A",@"Display A",{101},{}}, {12,@"B",@"Display B",{102},{}},
        {13,@"new",@"New display",{103},{}},
        {21,@"headset",@"USB headset",{201},{301},true,true},
        {22,@"multi",@"Multiple output streams",{202,203},{}},
        {23,@"input",@"Input only",{},{302}},
        {24,@"offline",@"Disconnected",{204},{},false},
        {25,@"private",@"VolumeBridge (private)",{205},{}},
        {26,@"duplex",@"Duplex display",{206},{303}}
    };
    SelectionController *c=[SelectionController new];
    [c setValue:[@{@"A":@80,@"B":@10} mutableCopy] forKey:@"_saved"];
    [c setValue:@YES forKey:@"_running"];
    [c setValue:@YES forKey:@"_paused"]; // Prevent capture even for eligible fixtures.
    [c setValue:@"" forKey:@"_targetUID"];
    [c reconcile]; expect(c,@"A",80,@"paused");
    [c setValue:@YES forKey:@"_muted"];
    [c setValue:@"B" forKey:@"_targetUID"];
    [c reconcile]; expect(c,@"B",10,@"waiting");
    assert(![c.snapshot[@"muted"] boolValue]);
    defaultOutput=12;
    [c reconcile]; expect(c,@"B",10,@"paused");
    [c setValue:@YES forKey:@"_muted"];
    [c reconcile]; assert([c.snapshot[@"muted"] boolValue]);
    // A changed numeric device ID for the same UID must preserve mute/volume.
    fixtures[1].id=112; defaultOutput=112;
    [c reconcile]; expect(c,@"B",10,@"paused");
    assert([c.snapshot[@"muted"] boolValue]);
    // Unknown targets use the default, never the previous device's volume.
    [c setValue:@"new" forKey:@"_targetUID"];
    [c reconcile]; expect(c,@"new",50,@"waiting");
    // A disconnected fixed target restores its own saved volume on return.
    Fixture b=fixtures[1]; fixtures.erase(fixtures.begin()+1);
    defaultOutput=11;
    [c setValue:@"B" forKey:@"_targetUID"];
    [c reconcile]; expect(c,@"",50,@"waiting");
    fixtures.push_back(b); defaultOutput=11;
    [c reconcile]; expect(c,@"B",10,@"waiting");
    defaultOutput=112;
    [c reconcile]; expect(c,@"B",10,@"paused");
    [c setValue:@"" forKey:@"_targetUID"]; defaultOutput=11;
    [c reconcile]; expect(c,@"A",80,@"paused");

    NSArray<NSDictionary *> *outputs=[c readOutputDevices];
    assert(outputs.count==6);
    assert([outputs.firstObject[@"uid"] isEqual:@"A"]);
    for(NSString *uid in @[@"headset",@"multi",@"duplex"]) {
        NSArray *matches=[outputs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"uid == %@",uid]];
        assert(matches.count==1);
        assert(![matches[0][@"eligible"] boolValue]);
        assert([matches[0][@"native"] boolValue]==[uid isEqual:@"headset"]);
        assert([matches[0][@"channels"] unsignedIntValue]==([uid isEqual:@"multi"] ? 4u : 2u));
    }
    for(NSDictionary *d in outputs)
        if([@[@"A",@"B",@"new"] containsObject:d[@"uid"]]) assert([d[@"eligible"] boolValue]);
    assert(writes==0);
    [DVLogger stop];
    [NSFileManager.defaultManager removeItemAtPath:logDirectory error:nil];
    puts("PASS device selection: fixed-target volume restore, reconnect, same-UID mute, duplex/multi-stream visibility; no real HAL access");
} }
