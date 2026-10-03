import XCTest
import RocoContent
import RocoDomain
@testable import RocoNative

final class CanonicalThumbnailStoreTests: XCTestCase {
    @MainActor
    func testSharedRequestsSizesMissingAndCancellation() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ContentResources", withExtension: "bundle"))
        let content = try await ContentStore.loadInBackground(bundleURL: url, assetValidation: .onDemand)
        let store = CanonicalThumbnailStore(resolver: content.assetResolver)
        let id = try XCTUnwrap(content.pet(PetID(rawValue: 3001))?.portraitAssetId)
        async let first = store.image(for: id, maxPixelSize: 156)
        async let second = store.image(for: id, maxPixelSize: 156)
        let (a, b) = try await (first, second)
        let image = try XCTUnwrap(a)
        XCTAssertTrue(image === b, "Simultaneous rows must share the bitmap")
        XCTAssertLessThanOrEqual(max(image.cgImage?.width ?? 0, image.cgImage?.height ?? 0), 156)
        let initialDecodes = await store.decodeCount
        XCTAssertEqual(initialDecodes, 1)

        let loadedLarger = try await store.image(for: id, maxPixelSize: 288)
        let larger = try XCTUnwrap(loadedLarger)
        XCTAssertFalse(larger === image, "Display scale/size changes request a fresh resolution")
        let repeated = try await store.image(for: id, maxPixelSize: 156)
        XCTAssertTrue(repeated === image, "Returning to a page reuses its thumbnail")
        let decodes = await store.decodeCount
        XCTAssertEqual(decodes, 2)
        let missing = try XCTUnwrap(content.pet(PetID(rawValue: 3784))?.portraitAssetId)
        let placeholder = try await store.image(for: missing, maxPixelSize: 156)
        XCTAssertNil(placeholder)
        do {
            _ = try await store.image(for: AssetID(rawValue: "unknown"), maxPixelSize: 156)
            XCTFail("Invalid assets must not become silent placeholders")
        } catch { XCTAssertTrue(error is ContentError) }

        let cancelled = Task { try await store.image(for: id, maxPixelSize: 512) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("Cancelled requests must not publish a stale result")
        } catch { XCTAssertTrue(error is CancellationError) }
        let finalDecodes = await store.decodeCount
        XCTAssertEqual(finalDecodes, 2)
    }
}
