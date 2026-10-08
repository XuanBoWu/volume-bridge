#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#include <vector>
#include <cstdlib>
#include <cstdio>

template<class T> OSStatus get(AudioObjectID id,AudioObjectPropertySelector sel,T &v) {
    AudioObjectPropertyAddress a{sel,kAudioObjectPropertyScopeGlobal,0}; UInt32 n=sizeof(v);
    return AudioObjectGetPropertyData(id,&a,0,nullptr,&n,&v);
}
NSString *text(AudioObjectID id,AudioObjectPropertySelector sel) {
    CFStringRef v=nullptr; if(get(id,sel,v)!=noErr || !v) return @""; return CFBridgingRelease(v);
}
int main(int argc,char **argv) { @autoreleasepool {
    if(argc<2) return 2;
    NSString *command=[NSString stringWithUTF8String:argv[1]];
    if([command isEqual:@"list"]) {
        auto a=AudioObjectPropertyAddress{kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal,0}; UInt32 n=0;
        if(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&a,0,nullptr,&n)!=noErr) return 1;
        std::vector<AudioObjectID> ids(n/sizeof(AudioObjectID));
        if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&a,0,nullptr,&n,ids.data())!=noErr) return 1;
        AudioObjectID current=0,system=0;
        get(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice,current);
        get(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultSystemOutputDevice,system);
        NSMutableArray *devices=[NSMutableArray array];
        for(auto id:ids) {
            double rate=0; UInt32 transport=0; get(id,kAudioDevicePropertyNominalSampleRate,rate); get(id,kAudioDevicePropertyTransportType,transport);
            auto ratesAddress=AudioObjectPropertyAddress{kAudioDevicePropertyAvailableNominalSampleRates,kAudioObjectPropertyScopeGlobal,0};
            UInt32 bytes=0; NSMutableArray *rates=[NSMutableArray array];
            if(AudioObjectGetPropertyDataSize(id,&ratesAddress,0,nullptr,&bytes)==noErr) {
                std::vector<AudioValueRange> ranges(bytes/sizeof(AudioValueRange));
                if(AudioObjectGetPropertyData(id,&ratesAddress,0,nullptr,&bytes,ranges.data())==noErr)
                    for(auto r:ranges) [rates addObject:@[@(r.mMinimum),@(r.mMaximum)]];
            }
            NSMutableDictionary *volumes=[NSMutableDictionary dictionary];
            for(UInt32 element=0;element<=2;element++) {
                auto va=AudioObjectPropertyAddress{kAudioDevicePropertyVolumeScalar,kAudioDevicePropertyScopeOutput,element};
                Float32 value=0; UInt32 size=sizeof(value);
                if(AudioObjectGetPropertyData(id,&va,0,nullptr,&size,&value)==noErr) volumes[@(element).stringValue]=@(value);
            }
            [devices addObject:@{@"id":@(id),@"name":text(id,kAudioObjectPropertyName),@"uid":text(id,kAudioDevicePropertyDeviceUID),@"rate":@(rate),@"transport":@(transport),@"rates":rates,@"volumes":volumes}];
        }
        NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"default":@(current),@"systemDefault":@(system),@"devices":devices} options:NSJSONWritingPrettyPrinted error:nil];
        fwrite(data.bytes,1,data.length,stdout); return 0;
    }
    if(argc<3) return 2;
    AudioObjectID id=unsigned(strtoul(argv[2],nullptr,10)); OSStatus result=-1;
    if([command isEqual:@"output"] || [command isEqual:@"system-output"]) {
        auto selector=[command isEqual:@"output"] ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultSystemOutputDevice;
        auto a=AudioObjectPropertyAddress{selector,kAudioObjectPropertyScopeGlobal,0};
        result=AudioObjectSetPropertyData(kAudioObjectSystemObject,&a,0,nullptr,sizeof(id),&id);
    } else if([command isEqual:@"rate"] && argc==4) {
        double rate=strtod(argv[3],nullptr); auto a=AudioObjectPropertyAddress{kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal,0};
        result=AudioObjectSetPropertyData(id,&a,0,nullptr,sizeof(rate),&rate);
    } else if([command isEqual:@"volume"] && argc==5) {
        UInt32 channel=unsigned(strtoul(argv[3],nullptr,10)); Float32 value=strtof(argv[4],nullptr);
        if(value<0 || value>1) return 2;
        auto a=AudioObjectPropertyAddress{kAudioDevicePropertyVolumeScalar,kAudioDevicePropertyScopeOutput,channel};
        result=AudioObjectSetPropertyData(id,&a,0,nullptr,sizeof(value),&value);
    }
    printf("status=%d\n",int(result)); return result==noErr ? 0 : 1;
}}
