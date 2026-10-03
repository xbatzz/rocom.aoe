import SwiftUI
import RocoContent

/// Lazy visible-row decoding of the exact canonical asset, including shiny portraits.
struct CanonicalThumbnail: View {
    let assetID: AssetID?
    let content: ContentStore
    var size: CGFloat = 48
    @Environment(\.displayScale) private var displayScale
    @Environment(\.canonicalThumbnails) private var thumbnails
    @State private var image: UIImage?
    @State private var error: String?
    private struct Request: Equatable {
        let assetID: AssetID?
        let pixels: Int
    }
    var body: some View {
        let request = Request(assetID: assetID, pixels: max(64, Int((size * displayScale).rounded(.up))))
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true) }
            else if let error { Image(systemName: "exclamationmark.triangle").resizable().scaledToFit().padding(size * 0.2).accessibilityLabel(error) }
            else { Image(systemName: "photo").resizable().scaledToFit().padding(size * 0.2).foregroundStyle(.secondary).accessibilityLabel("暂无图片") }
        }.frame(width: size, height: size)
            .onDisappear {
                // Lazy containers can retain cell state after its surface disappears.
                // Only the bounded application cache should retain offscreen bitmaps.
                image = nil
                error = nil
            }
            .task(id: request) {
                image = nil; error = nil
                guard let assetID = request.assetID else { return }
                do {
                    guard let thumbnails else { throw ContentError.invalid("缺少缩略图缓存") }
                    let loaded = try await thumbnails.image(for: assetID, maxPixelSize: request.pixels)
                    try Task.checkCancellation()
                    image = loaded
                } catch is CancellationError {
                    // A recycled row must not publish an old image or an error.
                } catch {
                    guard !Task.isCancelled else { return }
                    self.error = String(describing: error)
                }
            }
    }
}
