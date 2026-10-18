#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DVLogLevel) {
    DVLogLevelDebug = 0,
    DVLogLevelInfo = 1,
    DVLogLevelNotice = 2,
    DVLogLevelWarning = 3,
    DVLogLevelError = 4,
    DVLogLevelCritical = 5,
};

@interface DVLogger : NSObject
+ (void)startWithOverridePath:(nullable NSString *)path;
+ (void)logWithLevel:(DVLogLevel)level event:(NSString *)event fields:(nullable NSDictionary<NSString *, id> *)fields;
+ (void)logWithLevel:(DVLogLevel)level event:(NSString *)event message:(NSString *)message;
+ (void)flush;
+ (void)stop;
@end

NS_ASSUME_NONNULL_END
