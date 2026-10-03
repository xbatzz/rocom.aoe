import UIKit
import ImageIO
import RocoDomain
import RocoContent
import os

@MainActor
final class PortraitStore {
    let thumbnails: CanonicalThumbnailStore
    private let resolver: AssetResolver
    private let cache = NSCache<NSString, UIImage>()
    private let logger = Logger(subsystem: "com.batzz.rocom", category: "portraits")
    private var missingPlaceholder: UIImage?
#if DEBUG
    private(set) var decodeCount = 0
    private(set) var placeholderCreationCount = 0
#endif
    init(resolver: AssetResolver) {
        self.resolver = resolver
        thumbnails = CanonicalThumbnailStore(resolver: resolver)
        cache.totalCostLimit = 16 * 1024 * 1024
    }
    nonisolated deinit {}

    /// Called by lazy visible/near-visible cells. Reuses the existing ImageIO thumbnail
    /// decoder and bounded cache; asset identity also shares bitmaps across pet forms.
    func image(for pet: Pet) throws -> UIImage {
        guard let assetId = pet.portraitAssetId else {
            throw ContentError.invalid("Pet \(pet.petId.rawValue) has no canonical portraitAssetId")
        }
        let key = assetId.rawValue as NSString
        if let image = cache.object(forKey: key) { return image }
        switch try resolver.resolve(assetId) {
        case .missing:
            return placeholder()
        case .available(let url):
            let start = ContinuousClock.now
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 512,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary), CGImageSourceGetStatus(source) == .statusComplete else {
                logger.error("portrait decode failed pet=\(pet.petId.rawValue) asset=\(assetId.rawValue, privacy: .public)")
                throw ContentError.invalid("WebP decode failed: pet \(pet.petId.rawValue), \(url.lastPathComponent)")
            }
            let image = UIImage(cgImage: bitmap)
            let cost = bitmap.bytesPerRow * bitmap.height
            cache.setObject(image, forKey: key, cost: cost)
#if DEBUG
            decodeCount += 1
            logger.notice("decode pet=\(pet.petId.rawValue) bytes=\(cost) elapsed=\(String(describing: start.duration(to: .now)), privacy: .public)")
#endif
            return image
        }
    }

    /// Only AssetResolver's validated known missing state reaches this native bitmap.
    /// A single transparent image is held for both missing pets and both transition ends.
    private func placeholder() -> UIImage {
        if let image = missingPlaceholder { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { _ in
            let symbol = UIImage(systemName: "photo")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            symbol?.draw(in: CGRect(x: 192, y: 192, width: 128, height: 128))
        }
        missingPlaceholder = image
#if DEBUG
        placeholderCreationCount += 1
#endif
        return image
    }
}
