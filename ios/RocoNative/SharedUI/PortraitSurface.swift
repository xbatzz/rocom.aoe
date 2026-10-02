import SwiftUI
import RocoDomain

/// The displayed image IS the registered zoom view. SwiftUI owns its layout;
/// no parent layoutSubviews rewrites a child frame while UIKit owns its transform.
final class PortraitSurface: UIImageView {
    var transitionImageView: UIImageView { self }
    init(portrait: UIImage) {
        super.init(frame: .zero)
        image = portrait
        contentMode = .scaleAspectFit
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
    }
    required init?(coder: NSCoder) { nil }
}

@MainActor
final class PortraitAnchors {
    private let sources = NSMapTable<NSString, PortraitSurface>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    weak var hero: PortraitSurface?
    // The registry owns only weak view values and needs no actor-bound cleanup.
    nonisolated deinit {}
    func register(_ view: PortraitSurface, origin: PortraitOrigin?) {
        if let origin { sources.setObject(view, forKey: key(origin)) }
        else { hero = view }
    }
    func source(for origin: PortraitOrigin) -> PortraitSurface? { sources.object(forKey: key(origin)) }
    private func key(_ origin: PortraitOrigin) -> NSString { "\(origin.instance):\(origin.petID.rawValue)" as NSString }
}

struct AnchoredPortrait: View {
    let image: UIImage
    let origin: PortraitOrigin?
    let anchors: PortraitAnchors
    var body: some View {
        GeometryReader { geometry in
            // Preserve the existing 8% inset on both ends, outside the zoom view.
            RegisteredPortrait(image: image, origin: origin, anchors: anchors)
                .frame(width: geometry.size.width * 0.84, height: geometry.size.height * 0.84)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

private struct RegisteredPortrait: UIViewRepresentable {
    let image: UIImage
    let origin: PortraitOrigin?
    let anchors: PortraitAnchors
    func makeUIView(context: Context) -> PortraitSurface {
        let view = PortraitSurface(portrait: image)
        anchors.register(view, origin: origin)
        return view
    }
    func updateUIView(_ uiView: PortraitSurface, context: Context) {
        anchors.register(uiView, origin: origin)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PortraitSurface, context: Context) -> CGSize? {
        // Unspecified isn't zero. SwiftUI probes ideal/min/max sizes; only accept
        // a concrete proposal here, otherwise let its normal sizing path decide.
        let size: CGSize?
        if let width = proposal.width, let height = proposal.height,
           width.isFinite, height.isFinite {
            size = CGSize(width: width, height: height)
        } else {
            size = nil
        }
        return size
    }
}
