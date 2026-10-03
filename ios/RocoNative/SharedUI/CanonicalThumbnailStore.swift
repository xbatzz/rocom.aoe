import UIKit
import ImageIO
import SwiftUI
import RocoContent

/// Application-owned, bounded bitmap cache. Validation and decoding run on this
/// actor, never in a SwiftUI task's main-actor turn. Requests are serialized so a
/// screenful of thumbnails cannot fan out into unbounded concurrent decodes.
actor CanonicalThumbnailStore {
    private let resolver: AssetResolver
    private let cache = NSCache<NSString, UIImage>()
    private var resolutions: [AssetID: AssetResolution] = [:]
    #if DEBUG
    private(set) var decodeCount = 0
    #endif

    init(resolver: AssetResolver) {
        self.resolver = resolver
        cache.totalCostLimit = 16 * 1024 * 1024
        cache.countLimit = 256
    }

    func image(for assetID: AssetID, maxPixelSize: Int) throws -> UIImage? {
        try Task.checkCancellation()
        let pixels = max(64, maxPixelSize)
        let key = "\(assetID.rawValue)|\(pixels)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let resolution: AssetResolution
        if let existing = resolutions[assetID] {
            resolution = existing
        } else {
            resolution = try resolver.resolve(assetID)
            // Bundled content is immutable for the lifetime of this store.
            // Only successful validation is retained; failed requests can retry.
            resolutions[assetID] = resolution
        }
        guard case .available(let url) = resolution else { return nil }
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary), CGImageSourceGetStatus(source) == .statusComplete else {
            throw ContentError.invalid("图片解码失败: \(assetID.rawValue)")
        }
        try Task.checkCancellation()
        let image = UIImage(cgImage: bitmap)
        cache.setObject(image, forKey: key, cost: bitmap.bytesPerRow * bitmap.height)
        #if DEBUG
        decodeCount += 1
        #endif
        return image
    }

    /// One small lookahead window; yield between decodes so visible requests can run.
    func prefetch(_ assetIDs: [AssetID], maxPixelSize: Int) async {
        for id in assetIDs.prefix(4) {
            guard !Task.isCancelled else { return }
            _ = try? image(for: id, maxPixelSize: maxPixelSize)
            await Task.yield()
        }
    }

}

extension EnvironmentValues {
    @Entry var canonicalThumbnails: CanonicalThumbnailStore? = nil
}
