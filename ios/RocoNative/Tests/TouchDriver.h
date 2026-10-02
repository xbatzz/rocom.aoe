#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN
/// Test runner only. Each track is one continuous finger; offsets are gesture times.
/// Uses private XCTest event records, guarded for the pinned Xcode 26.2 SDK.
void P0SendTouchTracks(NSArray<NSArray<NSValue *> *> *tracks,
                      NSArray<NSArray<NSNumber *> *> *offsets,
                      NSArray<NSNumber *> *releaseOffsets,
                      void (^completion)(NSError * _Nullable));
NS_ASSUME_NONNULL_END
