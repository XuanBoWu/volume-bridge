#include "../Sources/MediaVolume.hpp"
#include <cassert>
#include <iostream>

int main() {
    auto value=dv::applyVolumeKey(50,false,0,false);
    assert(value.handled && value.percent==56.25f && !value.muted);
    for(unsigned i=0;i<7;i++) value=dv::applyVolumeKey(value.percent,value.muted,0,false);
    assert(value.percent==100);
    value=dv::applyVolumeKey(value.percent,value.muted,1,false);
    assert(value.percent==93.75f);
    for(unsigned i=0;i<32;i++) value=dv::applyVolumeKey(value.percent,value.muted,1,false);
    assert(value.percent==0);
    value=dv::applyVolumeKey(value.percent,true,0,true);
    assert(value.percent==1.5625f && !value.muted);
    value=dv::applyVolumeKey(value.percent,value.muted,7,false);
    assert(value.muted && value.percent==1.5625f);
    value=dv::applyVolumeKey(value.percent,value.muted,7,false);
    assert(!value.muted && value.percent==1.5625f);
    assert(!dv::applyVolumeKey(50,false,16,false).handled);
    assert(!dv::applyVolumeKey(NAN,false,0,false).handled);
    std::cout<<"PASS media volume: burst accumulation, limits, fine step, mute preservation and unmute\n";
}
