#import <Foundation/Foundation.h>
#import "Logging.h"

NS_ASSUME_NONNULL_BEGIN
@interface DVAudioController : NSObject
- (void)start;
- (void)stopWithCompletion:(void (^)(void))completion;
- (void)setVolumePercent:(float)percent;
- (void)setVolumePercent:(float)percent completion:(void (^ _Nullable)(NSDictionary<NSString *,id> *))completion;
- (void)setMuted:(BOOL)muted;
- (BOOL)canHandleMediaKeys;
- (void)applyMediaKey:(NSInteger)key fine:(BOOL)fine deviceUID:(NSString *)uid completion:(void (^)(NSDictionary<NSString *,id> * _Nullable))completion;
- (void)setPaused:(BOOL)paused;
- (void)setSleeping:(BOOL)sleeping;
- (void)retry;
- (NSArray<NSDictionary<NSString *, id> *> *)availableOutputDevices;
- (void)setTargetDeviceUID:(NSString *)uid;
- (void)setDefaultOutputDeviceUID:(NSString *)uid;
- (NSDictionary<NSString *,id> *)snapshot;
@end
NS_ASSUME_NONNULL_END
