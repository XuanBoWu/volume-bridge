#include "../Sources/Policy.hpp"
#include <cassert>
#include <iostream>

int main() {
    using namespace dv;
    Device monitor{131,0,2,9,32,512,48000,true,false,true,true,"monitor","Mi Monitor"};
    Device speaker=monitor; speaker.id=12; speaker.uid="speaker"; speaker.native=true; speaker.display=false;
    assert(choose(true,false,false,monitor,nullptr,false)==Plan::start);
    assert(choose(true,false,false,monitor,&monitor,false)==Plan::keep);
    assert(choose(true,false,false,monitor,&monitor,true)==Plan::rebuild);
    auto reconnect=monitor; reconnect.id=456;
    assert(choose(true,false,false,reconnect,&monitor,false)==Plan::rebuild);
    auto changedRate=monitor; changedRate.rate=44100;
    assert(choose(true,false,false,changedRate,&monitor,false)==Plan::rebuild);
    auto unplugged=monitor; unplugged.alive=false;
    assert(choose(true,false,false,unplugged,&monitor,false)==Plan::noDevice);
    assert(choose(true,false,false,speaker,&monitor,false)==Plan::native);
    assert(choose(true,true,false,monitor,&monitor,false)==Plan::suspended);
    assert(choose(true,false,true,monitor,&monitor,false)==Plan::paused);
    assert(choose(false,false,false,monitor,&monitor,false)==Plan::off);
    auto surround=monitor; surround.channels=6;
    assert(choose(true,false,false,surround,nullptr,false)==Plan::unsupported);
    auto virtualDevice=monitor; virtualDevice.display=false;
    assert(choose(true,false,false,virtualDevice,nullptr,false)==Plan::unsupported);
    assert(gain(50,false)==0.25f && gain(100,false)==1 && gain(90,true)==0);
    for(double rate:{44100.,48000.,96000.}) {
        for(double target:{0.,0.25,1.}) {
            double value=0.5;
            for(unsigned i=0;i<rate/5;i++) value=nextGain(value,target,rate);
            assert(value==target);
        }
    }
    std::cout<<"PASS: switching, reconnect, format change, bypass, sleep, pause, eligibility, gain convergence\n";
}
