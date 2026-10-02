import SwiftUI
import ImageIO
import RocoContent

/// Lazy visible-row decoding of the exact canonical asset, including shiny portraits.
struct CanonicalThumbnail: View {
    let assetID: AssetID?
    let content: ContentStore
    var size: CGFloat = 48
    @State private var image: UIImage?
    @State private var error: String?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true) }
            else if let error { Image(systemName: "exclamationmark.triangle").accessibilityLabel(error) }
            else { Image(systemName: "photo").foregroundStyle(.secondary).accessibilityLabel("暂无图片") }
        }.frame(width: size, height: size)
            .task(id: assetID) {
                image = nil; error = nil
                guard let assetID else { return }
                do {
                    switch try content.assetResolver.resolve(assetID) {
                    case .missing: break
                    case .available(let url):
                        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                            let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceThumbnailMaxPixelSize: 128
                            ] as CFDictionary) else { throw ContentError.invalid("图片解码失败: \(assetID.rawValue)") }
                        image = UIImage(cgImage: bitmap)
                    }
                } catch { self.error = String(describing: error) }
            }
    }
}
