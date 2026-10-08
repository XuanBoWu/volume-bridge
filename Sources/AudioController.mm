#import "AudioController.h"
#import <AppKit/AppKit.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/CATapDescription.h>
#import <CoreAudio/AudioHardwareTapping.h>
#include "Policy.hpp"
#include "MediaVolume.hpp"
#include <atomic>
#include <memory>
#include <vector>
#include <cstdio>
#include <cstring>
#include <unistd.h>

namespace {
auto address(AudioObjectPropertySelector s,AudioObjectPropertyScope scope=kAudioObjectPropertyScopeGlobal,UInt32 e=0) {
    return AudioObjectPropertyAddress{s,scope,e};
}
template<class T> OSStatus get(AudioObjectID id,AudioObjectPropertySelector sel,T &v,AudioObjectPropertyScope scope=kAudioObjectPropertyScopeGlobal) {
    auto a=address(sel,scope); UInt32 n=sizeof(v); return AudioObjectGetPropertyData(id,&a,0,nullptr,&n,&v);
}
std::string text(AudioObjectID id,AudioObjectPropertySelector sel) {
    CFStringRef s=nullptr; if(get(id,sel,s)!=noErr || !s) return "";
    NSString *value=CFBridgingRelease(s); return value.UTF8String ?: "";
}
std::vector<AudioObjectID> streams(AudioObjectID id,AudioObjectPropertyScope scope) {
    auto a=address(kAudioDevicePropertyStreams,scope); UInt32 n=0;
    if(AudioObjectGetPropertyDataSize(id,&a,0,nullptr,&n)!=noErr) return {};
    std::vector<AudioObjectID> v(n/sizeof(AudioObjectID));
    if(n && AudioObjectGetPropertyData(id,&a,0,nullptr,&n,v.data())!=noErr) return {};
    return v;
}
dv::Device device(AudioObjectID id) {
    dv::Device d; d.id=id; if(!id) return d;
    d.uid=text(id,kAudioDevicePropertyDeviceUID); d.name=text(id,kAudioObjectPropertyName);
    UInt32 alive=0,transport=0; get(id,kAudioDevicePropertyDeviceIsAlive,alive); d.alive=alive && !d.uid.empty();
    get(id,kAudioDevicePropertyTransportType,transport);
    d.display=transport==kAudioDeviceTransportTypeHDMI || transport==kAudioDeviceTransportTypeDisplayPort;
    get(id,kAudioDevicePropertyNominalSampleRate,d.rate); get(id,kAudioDevicePropertyBufferFrameSize,d.frames);
    auto list=streams(id,kAudioDevicePropertyScopeOutput);
    if(list.size()==1 && streams(id,kAudioDevicePropertyScopeInput).empty()) {
        d.stream=list[0]; AudioStreamBasicDescription f{};
        if(get(d.stream,kAudioStreamPropertyVirtualFormat,f)==noErr) {
            d.channels=f.mChannelsPerFrame; d.flags=f.mFormatFlags; d.bits=f.mBitsPerChannel;
            d.pcm=f.mFormatID==kAudioFormatLinearPCM && (f.mFormatFlags&kAudioFormatFlagIsFloat)
                && !(f.mFormatFlags&kAudioFormatFlagIsNonInterleaved) && f.mBytesPerFrame==8;
        }
    }
    for(UInt32 element=0;element<=std::max(2u,d.channels);element++) {
        auto a=address(kAudioDevicePropertyVolumeScalar,kAudioDevicePropertyScopeOutput,element); Boolean writable=false;
        if(AudioObjectHasProperty(id,&a) && AudioObjectIsPropertySettable(id,&a,&writable)==noErr && writable) d.native=true;
    }
    return d;
}
AudioObjectID currentOutput() { AudioObjectID id=0; get(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice,id); return id; }
void require(OSStatus s,const char *op) { if(s!=noErr) { fprintf(stderr,"API %s error=%d\n",op,int(s)); throw s; } }
void cleanupResult(OSStatus s,const char *op) {
    if(s!=noErr && s!=kAudioHardwareBadObjectError && s!=kAudioHardwareBadDeviceError) fprintf(stderr,"CLEANUP %s error=%d\n",op,int(s));
}
struct Engine {
    dv::Device configuration;
    AudioObjectID tap=0,aggregate=0;
    AudioDeviceIOProcID proc=nullptr;
    CATapDescription *__strong description=nil;
    bool started=false,protectedSilence=false;
    std::atomic<float> target{0}; double gain=0,alpha=0;
    std::atomic<uint64_t> calls{0},mismatches{0},sampleCount{0};
    std::atomic<double> inputEnergy{0},outputEnergy{0};
    static OSStatus render(AudioObjectID,const AudioTimeStamp*,const AudioBufferList *in,const AudioTimeStamp*,AudioBufferList *out,const AudioTimeStamp*,void *context) {
        auto &e=*static_cast<Engine*>(context);
        for(UInt32 b=0;b<out->mNumberBuffers;b++) if(out->mBuffers[b].mData) memset(out->mBuffers[b].mData,0,out->mBuffers[b].mDataByteSize);
        e.calls.fetch_add(1,std::memory_order_relaxed);
        if(in->mNumberBuffers!=1 || out->mNumberBuffers!=1) { e.mismatches.fetch_add(1,std::memory_order_relaxed); return noErr; }
        const auto &ib=in->mBuffers[0]; auto &ob=out->mBuffers[0];
        if(!ib.mData || !ob.mData) return noErr;
        if(ib.mNumberChannels!=2 || ob.mNumberChannels!=2 || ib.mDataByteSize!=ob.mDataByteSize || ib.mDataByteSize%8) {
            e.mismatches.fetch_add(1,std::memory_order_relaxed); return noErr;
        }
        auto *src=static_cast<const float*>(ib.mData); auto *dst=static_cast<float*>(ob.mData);
        UInt32 frames=ib.mDataByteSize/8; double goal=e.target.load(std::memory_order_relaxed),ie=0,oe=0;
        for(UInt32 f=0;f<frames;f++) {
            e.gain+=(goal-e.gain)*e.alpha;
            if(std::abs(goal-e.gain)<1e-7) e.gain=goal;
            float g=float(e.gain);
            for(unsigned c=0;c<2;c++) {
                float x=src[2*f+c],y=x*g; dst[2*f+c]=y; ie+=double(x)*x; oe+=double(y)*y;
            }
        }
        e.sampleCount.fetch_add(frames*2,std::memory_order_relaxed);
        e.inputEnergy.fetch_add(ie,std::memory_order_relaxed); e.outputEnergy.fetch_add(oe,std::memory_order_relaxed);
        return noErr;
    }
    void start(const dv::Device &d,float initial) {
        configuration=d; target.store(initial); gain=initial; alpha=1-std::exp(-1/(d.rate*0.004));
        pid_t pid=getpid(); AudioObjectID own=0; UInt32 size=sizeof(own);
        auto a=address(kAudioHardwarePropertyTranslatePIDToProcessObject);
        require(AudioObjectGetPropertyData(kAudioObjectSystemObject,&a,sizeof(pid),&pid,&size,&own),"own-process");
        if(!own) throw OSStatus(-70001);
        NSString *uid=[NSString stringWithUTF8String:d.uid.c_str()];
        description=[[CATapDescription alloc] initExcludingProcesses:@[@(own)] andDeviceUID:uid withStream:0];
        description.name=@"音桥"; [description setPrivate:YES]; description.muteBehavior=CATapMutedWhenTapped;
        require(AudioHardwareCreateProcessTap(description,&tap),"create-tap");
        AudioStreamBasicDescription format{}; require(get(tap,kAudioTapPropertyFormat,format),"tap-format");
        if(format.mFormatID!=kAudioFormatLinearPCM || !(format.mFormatFlags&kAudioFormatFlagIsFloat)
           || (format.mFormatFlags&kAudioFormatFlagIsNonInterleaved) || format.mBitsPerChannel!=32
           || format.mChannelsPerFrame!=2 || format.mBytesPerFrame!=8 || format.mSampleRate!=d.rate) throw OSStatus(-70002);
        NSDictionary *composition=@{
            @kAudioAggregateDeviceNameKey:@"VolumeBridge (private)",@kAudioAggregateDeviceUIDKey:NSUUID.UUID.UUIDString,
            @kAudioAggregateDeviceMainSubDeviceKey:uid,@kAudioAggregateDeviceIsPrivateKey:@YES,
            @kAudioAggregateDeviceTapAutoStartKey:@NO,
            @kAudioAggregateDeviceSubDeviceListKey:@[@{@kAudioSubDeviceUIDKey:uid}],
            @kAudioAggregateDeviceTapListKey:@[@{@kAudioSubTapUIDKey:description.UUID.UUIDString,@kAudioSubTapDriftCompensationKey:@YES}]
        };
        require(AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)composition,&aggregate),"create-aggregate");
        UInt32 alive=0;
        for(unsigned n=0;n<30;n++) { get(aggregate,kAudioDevicePropertyDeviceIsAlive,alive); if(alive) break; usleep(100000); }
        if(!alive) throw OSStatus(-70003);
        if(!device(currentOutput()).sameConfiguration(d)) throw OSStatus(-70004);
        require(AudioDeviceCreateIOProcID(aggregate,render,this,&proc),"create-ioproc");
        require(AudioDeviceStart(aggregate,proc),"start-ioproc"); started=true;
    }
    void stopPlayback() noexcept {
        if(started && aggregate && proc) cleanupResult(AudioDeviceStop(aggregate,proc),"stop-ioproc");
        started=false;
        if(proc && aggregate) cleanupResult(AudioDeviceDestroyIOProcID(aggregate,proc),"destroy-ioproc"); proc=nullptr;
        if(aggregate) cleanupResult(AudioHardwareDestroyAggregateDevice(aggregate),"destroy-aggregate"); aggregate=0;
    }
    void holdForRebuild() {
        description.muteBehavior=CATapMuted;
        auto a=address(kAudioTapPropertyDescription); CFTypeRef value=(__bridge CFTypeRef)description;
        require(AudioObjectSetPropertyData(tap,&a,0,nullptr,sizeof(value),&value),"protect-rebuild");
        protectedSilence=true; stopPlayback();
    }
    ~Engine() {
        stopPlayback();
        if(tap) cleanupResult(AudioHardwareDestroyProcessTap(tap),"destroy-tap");
    }
};
static_assert(std::atomic<float>::is_always_lock_free && std::atomic<double>::is_always_lock_free);
struct Listener {
    AudioObjectID id; AudioObjectPropertyAddress a; AudioObjectPropertyListenerBlock __strong block;
};
}

@interface DVAudioController ()
- (void)reconcile;
- (void)scheduleReconcile:(BOOL)force;
- (void)publish;
@end

@implementation DVAudioController {
    dispatch_queue_t _queue;
    dispatch_source_t _timer;
    NSDictionary *_snapshot;
    NSMutableDictionary *_saved;
    std::unique_ptr<Engine> _engine,_guard;
    std::vector<Listener> _systemListeners,_deviceListeners;
    dv::Device _desired;
    AudioObjectID _watchedDevice,_watchedStream;
    BOOL _running,_paused,_sleeping,_muted,_force;
    float _percent;
    uint64_t _token,_generation,_totalCalls,_totalMismatches,_overloads;
    unsigned _attempts;
    double _retryAt;
    NSString *_phase,*_detail;
}
- (instancetype)init {
    if((self=[super init])) {
        _queue=dispatch_queue_create("local.displayvolume.lifecycle",DISPATCH_QUEUE_SERIAL);
        _saved=[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"deviceVolumes"] mutableCopy] ?: [NSMutableDictionary dictionary];
        _phase=@"stopped"; _detail=@"尚未启动"; _percent=50; _snapshot=@{}; [self publish];
    }
    return self;
}
- (NSDictionary *)snapshot { @synchronized(self) { return _snapshot; } }
- (void)publish {
    uint64_t calls=_totalCalls+(_engine ? _engine->calls.load() : 0);
    uint64_t mismatches=_totalMismatches+(_engine ? _engine->mismatches.load() : 0);
    double inRMS=0,outRMS=0;
    if(_engine) {
        auto n=_engine->sampleCount.exchange(0); double ie=_engine->inputEnergy.exchange(0),oe=_engine->outputEnergy.exchange(0);
        if(n) { inRMS=sqrt(ie/n); outRMS=sqrt(oe/n); }
    }
    NSDictionary *status=@{
        @"state":_phase ?: @"stopped",@"detail":_detail ?: @"",@"name":[NSString stringWithUTF8String:_desired.name.c_str()],
        @"uid":[NSString stringWithUTF8String:_desired.uid.c_str()],@"deviceID":@(_desired.id),@"rate":@(_desired.rate),
        @"volume":@(_percent),@"muted":@(_muted),@"paused":@(_paused),@"generation":@(_generation),
        @"callbacks":@(calls),@"mismatches":@(mismatches),@"overloads":@(_overloads),@"protectedSilence":@(_guard && _guard->protectedSilence),
        @"inputRMS":@(inRMS),@"outputRMS":@(outRMS),@"retryAttempt":@(_attempts)
    };
    @synchronized(self) { _snapshot=status; }
}
- (void)phase:(NSString *)phase detail:(NSString *)detail {
    if(![_phase isEqual:phase] || ![_detail isEqual:detail]) fprintf(stderr,"STATE %s generation=%llu device=%u rate=%.0f %s\n",phase.UTF8String,_generation,_desired.id,_desired.rate,detail.UTF8String);
    _phase=phase; _detail=detail; [self publish];
}
- (void)clearListeners:(std::vector<Listener> &)list {
    for(auto &l:list) AudioObjectRemovePropertyListenerBlock(l.id,&l.a,_queue,l.block);
    list.clear();
}
- (void)addListener:(AudioObjectID)id selector:(AudioObjectPropertySelector)sel scope:(AudioObjectPropertyScope)scope list:(std::vector<Listener> &)list {
    auto a=address(sel,scope); if(!AudioObjectHasProperty(id,&a)) return;
    __weak DVAudioController *weak=self;
    AudioObjectPropertyListenerBlock block=^(UInt32,const AudioObjectPropertyAddress *) {
        DVAudioController *strong=weak; if(!strong || !strong->_running) return;
        if(sel==kAudioDeviceProcessorOverload) { strong->_overloads++; [strong publish]; return; }
        [strong scheduleReconcile:sel==kAudioHardwarePropertyServiceRestarted];
    };
    OSStatus s=AudioObjectAddPropertyListenerBlock(id,&a,_queue,block);
    if(s==noErr) list.push_back({id,a,block}); else fprintf(stderr,"LISTENER selector=%u error=%d\n",sel,int(s));
}
- (void)watch:(const dv::Device &)d {
    if(_watchedDevice==d.id && _watchedStream==d.stream) return;
    [self clearListeners:_deviceListeners]; _watchedDevice=d.id; _watchedStream=d.stream;
    if(!d.id) return;
    for(auto sel:std::initializer_list<AudioObjectPropertySelector>{kAudioDevicePropertyDeviceIsAlive,kAudioDevicePropertyNominalSampleRate,kAudioDevicePropertyBufferFrameSize,kAudioDeviceProcessorOverload})
        [self addListener:d.id selector:sel scope:kAudioObjectPropertyScopeGlobal list:_deviceListeners];
    for(auto sel:std::initializer_list<AudioObjectPropertySelector>{kAudioDevicePropertyStreams,kAudioDevicePropertyStreamConfiguration})
        [self addListener:d.id selector:sel scope:kAudioDevicePropertyScopeOutput list:_deviceListeners];
    if(d.stream) [self addListener:d.stream selector:kAudioStreamPropertyVirtualFormat scope:kAudioObjectPropertyScopeGlobal list:_deviceListeners];
}
- (void)scheduleReconcile:(BOOL)force {
    _force|=force; uint64_t token=++_token;
    __weak DVAudioController *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),_queue,^{
        DVAudioController *strong=weak; if(strong && strong->_running && strong->_token==token) [strong reconcile];
    });
}
- (void)discardEngine {
    if(_engine) { _totalCalls+=_engine->calls.load(); _totalMismatches+=_engine->mismatches.load(); _engine.reset(); }
    _guard.reset();
}
- (void)reconcile {
    if(!_running) return;
    auto next=device(currentOutput());
    if(next.uid!=_desired.uid) {
        _attempts=0; _retryAt=0;
        NSNumber *saved=_saved[[NSString stringWithUTF8String:next.uid.c_str()]];
        _percent=saved ? std::clamp(saved.floatValue,0.0f,100.0f) : 50; _muted=NO;
    }
    if(!next.sameConfiguration(_desired)) { _attempts=0; _retryAt=0; }
    _desired=next; [self watch:next];
    auto plan=dv::choose(_running,_sleeping,_paused,next,_engine ? &_engine->configuration : nullptr,_force);
    if(plan==dv::Plan::keep && _engine->mismatches.load()!=0) { plan=dv::Plan::rebuild; _force=YES; }
    if(plan!=dv::Plan::keep && plan!=dv::Plan::start && plan!=dv::Plan::rebuild) {
        [self discardEngine]; _attempts=0; _retryAt=0; _force=NO;
        switch(plan) {
            case dv::Plan::suspended: [self phase:@"sleeping" detail:@"睡眠期间已释放音频链路"]; break;
            case dv::Plan::paused: [self phase:@"paused" detail:@"已暂停，使用原始输出音量"]; break;
            case dv::Plan::native: [self phase:@"bypass" detail:@"此设备由 macOS 控制音量"]; break;
            case dv::Plan::noDevice: [self phase:@"waiting" detail:@"等待可用的音频输出"]; break;
            default: [self phase:@"unsupported" detail:@"此输出暂不支持软件音量，保留原始播放"]; break;
        }
        return;
    }
    if(plan==dv::Plan::keep) { [self publish]; return; }
    double now=NSProcessInfo.processInfo.systemUptime;
    if(now<_retryAt) { [self publish]; return; }
    if(_guard && _guard->configuration.uid!=next.uid) _guard.reset();
    [self phase:_generation ? @"recovering" : @"starting" detail:@"正在建立音频链路"]; _force=NO;
    try {
        if(_engine) {
            if(_engine->configuration.uid==next.uid && next.alive) {
                _engine->holdForRebuild(); _totalCalls+=_engine->calls.load(); _totalMismatches+=_engine->mismatches.load();
                _guard=std::move(_engine);
            } else [self discardEngine];
        }
        auto created=std::make_unique<Engine>(); created->start(next,dv::gain(_percent,_muted));
        _engine=std::move(created); _guard.reset(); _generation++; _attempts=0; _retryAt=0;
        [self phase:@"active" detail:@"软件音量正在处理当前显示器输出"];
    } catch(OSStatus error) {
        if(_engine) [self discardEngine];
        _attempts++; _retryAt=NSProcessInfo.processInfo.systemUptime+std::min(30.0,std::pow(2.0,std::min(_attempts-1,5u)));
        NSString *detail=[NSString stringWithFormat:@"音频错误 %d，稍后自动重试%@",int(error),_guard ? @"；恢复期间保持静音" : @""];
        [self phase:@"error" detail:detail];
    }
}
- (void)start {
    dispatch_async(_queue,^{
        if(self->_running) return; self->_running=YES;
        for(auto sel:std::initializer_list<AudioObjectPropertySelector>{kAudioHardwarePropertyDefaultOutputDevice,kAudioHardwarePropertyDevices,kAudioHardwarePropertyServiceRestarted})
            [self addListener:kAudioObjectSystemObject selector:sel scope:kAudioObjectPropertyScopeGlobal list:self->_systemListeners];
        self->_timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,self->_queue);
        dispatch_source_set_timer(self->_timer,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),2*NSEC_PER_SEC,200*NSEC_PER_MSEC);
        __weak DVAudioController *weak=self;
        dispatch_source_set_event_handler(self->_timer,^{ DVAudioController *s=weak; if(s) [s reconcile]; });
        dispatch_resume(self->_timer); [self reconcile];
    });
}
- (void)stopWithCompletion:(void (^)(void))completion {
    dispatch_async(_queue,^{
        self->_running=NO; self->_token++;
        if(self->_timer) { dispatch_source_cancel(self->_timer); self->_timer=nil; }
        [self clearListeners:self->_systemListeners]; [self clearListeners:self->_deviceListeners]; [self discardEngine];
        [self phase:@"stopped" detail:@"音频链路已释放"];
        // AppKit may wait for terminateLater in a nested modal run loop.
        // A completion on the serial main dispatch queue cannot re-enter a
        // terminate call that originated on that same queue.
        NSArray *modes=@[NSRunLoopCommonModes,NSDefaultRunLoopMode,NSModalPanelRunLoopMode];
        CFRunLoopPerformBlock(CFRunLoopGetMain(),(__bridge CFArrayRef)modes,completion);
        CFRunLoopWakeUp(CFRunLoopGetMain());
    });
}
- (void)setVolumePercent:(float)percent {
    dispatch_async(_queue,^{
        if(!std::isfinite(percent)) return;
        self->_percent=std::clamp(percent,0.0f,100.0f); self->_muted=NO;
        if(self->_engine) self->_engine->target.store(dv::gain(self->_percent,false));
        if(!self->_desired.uid.empty()) {
            self->_saved[[NSString stringWithUTF8String:self->_desired.uid.c_str()]]=@(self->_percent);
            [NSUserDefaults.standardUserDefaults setObject:self->_saved forKey:@"deviceVolumes"];
        }
        [self publish];
    });
}
- (void)setMuted:(BOOL)muted {
    dispatch_async(_queue,^{ self->_muted=muted; if(self->_engine) self->_engine->target.store(dv::gain(self->_percent,muted)); [self publish]; });
}
- (BOOL)canHandleMediaKeys {
    NSDictionary *s=[self snapshot];
    return [s[@"state"] isEqual:@"active"] && currentOutput()==[s[@"deviceID"] unsignedIntValue];
}
- (void)applyMediaKey:(NSInteger)key fine:(BOOL)fine deviceUID:(NSString *)uid completion:(void (^)(NSDictionary<NSString *,id> * _Nullable))completion {
    dispatch_async(_queue,^{
        NSDictionary *result=nil;
        // Recheck on the lifecycle queue: a device may switch after event capture.
        if(self->_running && !self->_paused && !self->_sleeping && self->_engine
           && [self->_phase isEqual:@"active"] && currentOutput()==self->_desired.id
           && [uid isEqual:[NSString stringWithUTF8String:self->_desired.uid.c_str()]]) {
            auto value=dv::applyVolumeKey(self->_percent,self->_muted,int(key),fine);
            if(value.handled) {
                self->_percent=value.percent; self->_muted=value.muted;
                self->_engine->target.store(dv::gain(value.percent,value.muted));
                self->_saved[uid]=@(value.percent);
                [NSUserDefaults.standardUserDefaults setObject:self->_saved forKey:@"deviceVolumes"];
                [self publish]; result=[self snapshot];
            }
        }
        NSArray *modes=@[NSRunLoopCommonModes,NSDefaultRunLoopMode,NSModalPanelRunLoopMode];
        CFRunLoopPerformBlock(CFRunLoopGetMain(),(__bridge CFArrayRef)modes,^{ completion(result); });
        CFRunLoopWakeUp(CFRunLoopGetMain());
    });
}
- (void)setPaused:(BOOL)paused { dispatch_async(_queue,^{ self->_paused=paused; self->_retryAt=0; [self reconcile]; }); }
- (void)setSleeping:(BOOL)sleeping {
    dispatch_async(_queue,^{ self->_sleeping=sleeping; self->_retryAt=0; self->_force=YES; [self reconcile]; });
}
- (void)retry { dispatch_async(_queue,^{ self->_force=YES; self->_retryAt=0; [self reconcile]; }); }
@end
