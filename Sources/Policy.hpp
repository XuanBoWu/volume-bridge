#pragma once
#include <algorithm>
#include <cmath>
#include <string>

namespace dv {
enum class Plan { off, suspended, paused, noDevice, native, unsupported, start, keep, rebuild };
struct Device {
    unsigned id=0, stream=0, channels=0, flags=0, bits=0, frames=0;
    double rate=0;
    bool alive=false, native=false, display=false, pcm=false;
    std::string uid,name;
    bool eligible() const { return alive && display && !native && pcm && channels==2 && bits==32 && rate>0; }
    bool sameConfiguration(const Device &other) const {
        return id==other.id && uid==other.uid && stream==other.stream && channels==other.channels
            && flags==other.flags && bits==other.bits && frames==other.frames && rate==other.rate;
    }
};
inline Plan choose(bool running,bool sleeping,bool paused,const Device &desired,const Device *active,bool forced) {
    if(!running) return Plan::off;
    if(sleeping) return Plan::suspended;
    if(paused) return Plan::paused;
    if(!desired.id || !desired.alive) return Plan::noDevice;
    if(desired.native) return Plan::native;
    if(!desired.eligible()) return Plan::unsupported;
    if(!active) return Plan::start;
    return !forced && desired.sameConfiguration(*active) ? Plan::keep : Plan::rebuild;
}
inline float gain(float percent,bool muted) {
    float p=std::clamp(percent,0.0f,100.0f)/100.0f;
    return muted ? 0 : p*p;
}
inline double nextGain(double current,double target,double rate) {
    double next=current+(target-current)*(1-std::exp(-1/(rate*0.004)));
    return std::abs(next-target)<1e-7 ? target : next;
}
}
