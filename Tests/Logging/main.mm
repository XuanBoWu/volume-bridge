#import "../../Sources/Logging.h"

int main() {
    @autoreleasepool {
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"VolumeBridge-logging-%@", NSUUID.UUID.UUIDString]];
        NSString *path = [directory stringByAppendingPathComponent:@"runtime.log"];
        [DVLogger startWithOverridePath:path];
        NSString *payload = [@"diagnostic-payload-" stringByPaddingToLength:1800
            withString:@"x" startingAtIndex:0];
        for (NSUInteger index = 0; index < 1800; index++) {
            [DVLogger logWithLevel:DVLogLevelInfo event:@"test.rotation"
                            fields:@{ @"index": @(index), @"payload": payload }];
        }
        [DVLogger flush];
        NSArray<NSString *> *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
        BOOL hasRotation = NO;
        unsigned long long total = 0;
        for (NSString *name in names) {
            if ([name hasPrefix:@"runtime.log."]) hasRotation = YES;
            NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:[directory stringByAppendingPathComponent:name] error:nil];
            total += [attributes[NSFileSize] unsignedLongLongValue];
        }
        NSData *firstLineData = [NSData dataWithContentsOfFile:path];
        NSString *firstLine = [[NSString alloc] initWithData:firstLineData encoding:NSUTF8StringEncoding];
        NSString *line = [[firstLine componentsSeparatedByString:@"\n"] firstObject];
        NSData *json = [line dataUsingEncoding:NSUTF8StringEncoding];
        BOOL validJSON = json && [NSJSONSerialization JSONObjectWithData:json options:0 error:nil] != nil;
        [DVLogger stop];
        [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
        if (!hasRotation || !validJSON || total > 12 * 1024 * 1024) {
            fprintf(stderr, "logging rotation test failed\n");
            return 1;
        }
        printf("PASS logging: JSONL output, size rotation and bounded retention\n");
    }
    return 0;
}
