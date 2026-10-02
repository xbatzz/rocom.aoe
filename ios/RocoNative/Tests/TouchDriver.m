#import "TouchDriver.h"
#import <XCTest/XCTest.h>

// Runtime-only declarations: no private framework linked into the application.
// API provenance: appium/WebDriverAgent FBW3CActionsSynthesizer/FBXCTestDaemonsProxy.
@interface NSObject (P0EventRecords)
- (instancetype)initForTouchAtPoint:(CGPoint)point offset:(NSTimeInterval)offset;
- (void)moveToPoint:(CGPoint)point atOffset:(NSTimeInterval)offset;
- (void)liftUpAtOffset:(NSTimeInterval)offset;
- (instancetype)initWithName:(NSString *)name interfaceOrientation:(NSInteger)orientation;
- (void)addPointerEventPath:(id)path;
- (id)eventSynthesizer;
- (void)synthesizeEvent:(id)record completion:(void (^)(BOOL, NSError *))completion;
@end

void P0SendTouchTracks(NSArray<NSArray<NSValue *> *> *tracks,
                      NSArray<NSArray<NSNumber *> *> *offsets,
                      NSArray<NSNumber *> *releaseOffsets,
                      void (^completion)(NSError *)) {
    Class pathClass = NSClassFromString(@"XCPointerEventPath");
    Class recordClass = NSClassFromString(@"XCSynthesizedEventRecord");
    id device = XCUIDevice.sharedDevice;
    if (!pathClass || !recordClass ||
        ![pathClass instancesRespondToSelector:@selector(initForTouchAtPoint:offset:)] ||
        ![pathClass instancesRespondToSelector:@selector(moveToPoint:atOffset:)] ||
        ![pathClass instancesRespondToSelector:@selector(liftUpAtOffset:)] ||
        ![recordClass instancesRespondToSelector:@selector(initWithName:interfaceOrientation:)] ||
        ![recordClass instancesRespondToSelector:@selector(addPointerEventPath:)] ||
        ![device respondsToSelector:@selector(eventSynthesizer)]) {
        completion([NSError errorWithDomain:@"P0TouchDriver" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Pinned XCTest touch-record API unavailable"}]);
        return;
    }
    @try {
        id synthesizer = [device eventSynthesizer];
        if (![synthesizer respondsToSelector:@selector(synthesizeEvent:completion:)]) {
            completion([NSError errorWithDomain:@"P0TouchDriver" code:1 userInfo:@{NSLocalizedDescriptionKey: @"XCTest synthesizer unavailable"}]);
            return;
        }
        NSCAssert(tracks.count == offsets.count && tracks.count == releaseOffsets.count, @"Invalid touch tracks");
        id record = [[recordClass alloc] initWithName:@"P0 continuous touch" interfaceOrientation:1];
        for (NSUInteger index = 0; index < tracks.count; index++) {
            NSArray<NSValue *> *points = tracks[index];
            NSArray<NSNumber *> *times = offsets[index];
            NSCAssert(points.count > 0 && points.count == times.count, @"Invalid touch times");
            id path = [[pathClass alloc] initForTouchAtPoint:points[0].CGPointValue offset:times[0].doubleValue];
            for (NSUInteger point = 1; point < points.count; point++) {
                [path moveToPoint:points[point].CGPointValue atOffset:times[point].doubleValue];
            }
            [path liftUpAtOffset:releaseOffsets[index].doubleValue];
            [record addPointerEventPath:path];
        }
        [synthesizer synthesizeEvent:record completion:^(BOOL succeeded, NSError *error) {
            NSError *result = error ?: (succeeded ? nil : [NSError errorWithDomain:@"P0TouchDriver" code:2 userInfo:@{NSLocalizedDescriptionKey: @"XCTest touch synthesis failed"}]);
            // XCTest replies on its XPC queue; Swift's caller and subsequent UI checks
            // are MainActor-isolated. This is an actor hop, not a navigation delay.
            dispatch_async(dispatch_get_main_queue(), ^{ completion(result); });
        }];
    } @catch (NSException *exception) {
        completion([NSError errorWithDomain:@"P0TouchDriver" code:2 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"XCTest event record exception"}]);
    }
}
