#import "Logging.h"
#import <os/log.h>

namespace {
constexpr unsigned long long kMaxFileBytes = 1024 * 1024;
constexpr unsigned long long kMaxTotalBytes = 12 * 1024 * 1024;
constexpr NSUInteger kMaxFiles = 12;
constexpr NSTimeInterval kMaxAge = 14 * 24 * 60 * 60;
constexpr NSTimeInterval kCleanupInterval = 6 * 60 * 60;

dispatch_queue_t gQueue;
dispatch_source_t gCleanupTimer;
NSFileHandle *gHandle;
NSString *gPath;
NSString *gDirectory;
NSString *gBaseName;
os_log_t gOSLog;
NSISO8601DateFormatter *gDateFormatter;
BOOL gManagedPath = NO;
BOOL gStarted = NO;

NSString *levelName(DVLogLevel level) {
    switch (level) {
        case DVLogLevelDebug: return @"debug";
        case DVLogLevelInfo: return @"info";
        case DVLogLevelNotice: return @"notice";
        case DVLogLevelWarning: return @"warning";
        case DVLogLevelError: return @"error";
        case DVLogLevelCritical: return @"critical";
    }
    return @"unknown";
}

os_log_type_t osLogType(DVLogLevel level) {
    switch (level) {
        case DVLogLevelDebug: return OS_LOG_TYPE_DEBUG;
        case DVLogLevelInfo: return OS_LOG_TYPE_INFO;
        case DVLogLevelNotice: return OS_LOG_TYPE_DEFAULT;
        case DVLogLevelWarning: return OS_LOG_TYPE_ERROR;
        case DVLogLevelError: return OS_LOG_TYPE_ERROR;
        case DVLogLevelCritical: return OS_LOG_TYPE_FAULT;
    }
    return OS_LOG_TYPE_DEFAULT;
}

NSString *defaultPath() {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/VolumeBridge/volume-bridge.log"];
}

void writeDiagnostic(NSString *text, DVLogLevel level) {
    if (gOSLog) os_log_with_type(gOSLog, osLogType(level), "%{public}s", text.UTF8String ?: "");
}

void openLocked() {
    if (!gPath) return;
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:gDirectory]) {
        NSError *error = nil;
        [fm createDirectoryAtPath:gDirectory
       withIntermediateDirectories:YES
                        attributes:@{NSFilePosixPermissions: @0700}
                             error:&error];
        if (error) writeDiagnostic([NSString stringWithFormat:@"log.directoryCreateFailed error=%@", error], DVLogLevelError);
    }
    [fm setAttributes:@{NSFilePosixPermissions: @0700} ofItemAtPath:gDirectory error:nil];
    if (![fm fileExistsAtPath:gPath]) {
        [fm createFileAtPath:gPath contents:nil attributes:@{NSFilePosixPermissions: @0600}];
    }
    [fm setAttributes:@{NSFilePosixPermissions: @0600} ofItemAtPath:gPath error:nil];
    gHandle = [NSFileHandle fileHandleForWritingAtPath:gPath];
    [gHandle seekToEndOfFile];
}

NSArray<NSString *> *logFilesLocked() {
    if (!gDirectory || !gBaseName) return @[];
    NSArray<NSString *> *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:gDirectory error:nil];
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSString *name, NSDictionary *) {
        return [name isEqual:gBaseName] || [name hasPrefix:[gBaseName stringByAppendingString:@"."]];
    }];
    return [names filteredArrayUsingPredicate:predicate];
}

NSDate *modificationDate(NSString *name) {
    NSString *path = [gDirectory stringByAppendingPathComponent:name];
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return attributes[NSFileModificationDate] ?: [NSDate distantPast];
}

unsigned long long fileSize(NSString *name) {
    NSString *path = [gDirectory stringByAppendingPathComponent:name];
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return [attributes[NSFileSize] unsignedLongLongValue];
}

void removeLocked(NSString *name) {
    NSString *path = [gDirectory stringByAppendingPathComponent:name];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

void closeHandleLocked() {
    if (!gHandle) return;
    @try {
        [gHandle synchronizeFile];
        [gHandle closeFile];
    } @catch (NSException *exception) {
        writeDiagnostic([NSString stringWithFormat:@"log.closeFailed reason=%@", exception.reason ?: @"unknown"], DVLogLevelError);
    }
    gHandle = nil;
}

void cleanupLocked() {
    if (!gManagedPath) return;
    NSMutableArray<NSString *> *rotated = [NSMutableArray array];
    NSDate *now = NSDate.date;
    for (NSString *name in logFilesLocked()) {
        if ([name isEqual:gBaseName]) continue;
        NSDate *date = modificationDate(name);
        if ([now timeIntervalSinceDate:date] > kMaxAge) {
            removeLocked(name);
        } else {
            [rotated addObject:name];
        }
    }
    [rotated sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [modificationDate(a) compare:modificationDate(b)];
    }];
    while (rotated.count > kMaxFiles - 1) {
        removeLocked(rotated.firstObject);
        [rotated removeObjectAtIndex:0];
    }
    unsigned long long total = fileSize(gBaseName);
    for (NSString *name in rotated) total += fileSize(name);
    while (total > kMaxTotalBytes && rotated.count > 0) {
        NSString *name = rotated.firstObject;
        total -= fileSize(name);
        removeLocked(name);
        [rotated removeObjectAtIndex:0];
    }
}

void rotateLockedIfNeeded() {
    if (!gHandle || [gHandle offsetInFile] < kMaxFileBytes) return;
    closeHandleLocked();
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSInteger index = NSInteger(kMaxFiles) - 2; index >= 1; index--) {
        NSString *from = [gDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%ld", gBaseName, (long)index]];
        NSString *to = [gDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%ld", gBaseName, (long)index + 1]];
        [fm removeItemAtPath:to error:nil];
        [fm moveItemAtPath:from toPath:to error:nil];
    }
    NSString *first = [gDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.1", gBaseName]];
    [fm removeItemAtPath:first error:nil];
    [fm moveItemAtPath:gPath toPath:first error:nil];
    openLocked();
    cleanupLocked();
}

void writeLocked(DVLogLevel level, NSString *event, NSDictionary<NSString *, id> *fields) {
    if (!gHandle) return;
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:@{
        @"timestamp": [gDateFormatter stringFromDate:NSDate.date],
        @"level": levelName(level),
        @"event": event ?: @"unknown",
    }];
    if (fields.count > 0) record[@"fields"] = fields;
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:0 error:&error];
    if (!data) {
        NSDictionary *fallback = @{
            @"timestamp": [gDateFormatter stringFromDate:NSDate.date],
            @"level": @"error",
            @"event": @"logger.serializationFailed",
            @"message": error.localizedDescription ?: @"unknown",
        };
        data = [NSJSONSerialization dataWithJSONObject:fallback options:0 error:nil];
    }
    NSMutableData *line = [data mutableCopy];
    [line appendBytes:"\n" length:1];
    rotateLockedIfNeeded();
    @try {
        [gHandle writeData:line];
    } @catch (NSException *exception) {
        writeDiagnostic([NSString stringWithFormat:@"log.writeFailed reason=%@", exception.reason ?: @"unknown"], DVLogLevelError);
        closeHandleLocked();
    }
    writeDiagnostic([[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding], level);
}
}

@implementation DVLogger

+ (void)startWithOverridePath:(NSString *)path {
    @synchronized(self) {
        if (gStarted) return;
        gStarted = YES;
        gQueue = dispatch_queue_create("local.volumeBridge.logging", DISPATCH_QUEUE_SERIAL);
        gOSLog = os_log_create("local.alexwu.VolumeBridge", "runtime");
        gDateFormatter = [NSISO8601DateFormatter new];
        NSString *selected = path.length ? path : defaultPath();
        gManagedPath = path.length == 0;
        gPath = [selected stringByStandardizingPath];
        gDirectory = [gPath stringByDeletingLastPathComponent];
        gBaseName = gPath.lastPathComponent;
        dispatch_sync(gQueue, ^{
            openLocked();
            cleanupLocked();
        });
        if (gManagedPath) {
            gCleanupTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, gQueue);
            dispatch_source_set_timer(gCleanupTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCleanupInterval * NSEC_PER_SEC)),
                                      (uint64_t)(kCleanupInterval * NSEC_PER_SEC), (uint64_t)(60 * NSEC_PER_SEC));
            dispatch_source_set_event_handler(gCleanupTimer, ^{ cleanupLocked(); });
            dispatch_resume(gCleanupTimer);
        }
    }
}

+ (void)logWithLevel:(DVLogLevel)level event:(NSString *)event fields:(NSDictionary<NSString *, id> *)fields {
    if (!gStarted) [self startWithOverridePath:nil];
    dispatch_block_t block = ^{
        writeLocked(level, event, fields ?: @{});
    };
    if (level >= DVLogLevelError) dispatch_sync(gQueue, block);
    else dispatch_async(gQueue, block);
}

+ (void)logWithLevel:(DVLogLevel)level event:(NSString *)event message:(NSString *)message {
    [self logWithLevel:level event:event fields:@{ @"message": message ?: @"" }];
}

+ (void)flush {
    if (!gQueue) return;
    dispatch_sync(gQueue, ^{
        if (!gHandle) return;
        @try { [gHandle synchronizeFile]; }
        @catch (NSException *exception) {
            writeDiagnostic([NSString stringWithFormat:@"log.flushFailed reason=%@", exception.reason ?: @"unknown"], DVLogLevelError);
        }
    });
}

+ (void)stop {
    @synchronized(self) {
        if (!gStarted) return;
        if (gCleanupTimer) {
            dispatch_source_cancel(gCleanupTimer);
            gCleanupTimer = nil;
        }
        dispatch_sync(gQueue, ^{
            closeHandleLocked();
        });
        gStarted = NO;
    }
}

@end
