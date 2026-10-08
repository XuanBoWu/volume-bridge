#pragma once
#include <algorithm>
#include <cmath>

namespace dv {
struct KeyVolume { float percent; bool muted; bool handled; };
inline KeyVolume applyVolumeKey(float percent, bool muted, int key, bool fine) {
    if(!std::isfinite(percent)) return {percent,muted,false};
    if(key==7) return {percent,!muted,true};
    if(key!=0 && key!=1) return {percent,muted,false};
    float step=fine ? 1.5625f : 6.25f;
    return {std::clamp(percent+(key==0 ? step : -step),0.0f,100.0f),false,true};
}
}
