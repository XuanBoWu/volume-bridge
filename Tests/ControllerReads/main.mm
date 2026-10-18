#import "../../Sources/AudioController.h"
#import <CoreAudio/CoreAudio.h>
#include <cassert>
#include <cstdio>

// Interpose HAL reads: UI/event-tap accessors must remain cache-only even when
// the audio service is slow or a display has just disappeared.
static unsigned halReads=0;
extern "C" OSStatus AudioObjectGetPropertyData(AudioObjectID, const AudioObjectPropertyAddress *, UInt32,
    const void *, UInt32 *, void *) { ++halReads; return kAudioHardwareBadObjectError; }
extern "C" OSStatus AudioObjectGetPropertyDataSize(AudioObjectID, const AudioObjectPropertyAddress *, UInt32,
    const void *, UInt32 *) { ++halReads; return kAudioHardwareBadObjectError; }

@interface SnapshotController : DVAudioController
@property(nonatomic,copy) NSDictionary *testSnapshot;
@end
@implementation SnapshotController
- (NSDictionary *)snapshot { return self.testSnapshot ?: @{}; }
@end

int main() { @autoreleasepool {
    SnapshotController *controller=[SnapshotController new];
    controller.testSnapshot=@{@"state":@"active", @"deviceID":@123, @"canHandleMediaKeys":@YES};
    halReads=0;
    for(unsigned n=0;n<1000;n++) {
        assert([controller canHandleMediaKeys]);
        assert([controller availableOutputDevices].count==0);
    }
    assert(halReads==0);
    for(NSString *state in @[@"waiting", @"paused", @"bypass", @"recovering", @"sleeping", @"error"]) {
        controller.testSnapshot=@{@"state":state, @"canHandleMediaKeys":@NO};
        assert(![controller canHandleMediaKeys]);
    }
    assert(halReads==0);
    puts("PASS controller reads: UI device list and media-key eligibility never query HAL synchronously");
} }
