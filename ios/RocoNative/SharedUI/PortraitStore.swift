import UIKit
import RocoDomain
import RocoContent

@MainActor
final class PortraitStore {
    let thumbnails: CanonicalThumbnailStore
    private var missingPlaceholder: UIImage?
#if DEBUG
    var decodeCount: Int { get async { await thumbnails.decodeCount } }
    private(set) var placeholderCreationCount = 0
#endif
    init(resolver: AssetResolver) {
        thumbnails = CanonicalThumbnailStore(resolver: resolver)
    }
    nonisolated deinit {}

    /// The same actor owns validation, decoding and cache entries for both catalogs.
    /// A 512px portrait also preserves the frozen source/hero bitmap identity.
    func image(for pet: Pet) async throws -> UIImage {
        guard let assetID = pet.portraitAssetId else {
            throw ContentError.invalid("Pet \(pet.petId.rawValue) has no canonical portraitAssetId")
        }
        let image = try await thumbnails.image(for: assetID, maxPixelSize: 512)
        try Task.checkCancellation()
        return image ?? placeholder()
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
