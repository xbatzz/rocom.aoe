import SwiftUI
import RocoDomain
import RocoContent

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

/// Async loading keeps image bytes in the mounted surface, preserving the shared
/// zoom's exact UIImage while avoiding bitmap retention in lazy-cell @State.
struct LoadingPortrait: UIViewRepresentable {
    let pet: Pet
    let portraits: PortraitStore
    let origin: PortraitOrigin
    let anchors: PortraitAnchors
    let completed: (String?) -> Void

    final class Coordinator {
        var petID: PetID?
        var task: Task<Void, Never>?
        nonisolated deinit {}
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PortraitSurface {
        PortraitSurface(portrait: UIImage())
    }
    func updateUIView(_ view: PortraitSurface, context: Context) {
        guard context.coordinator.petID != pet.petId else { return }
        context.coordinator.task?.cancel()
        context.coordinator.petID = pet.petId
        view.image = nil
        context.coordinator.task = Task { [weak view] in
            do {
                let image = try await portraits.image(for: pet)
                try Task.checkCancellation()
                guard let view else { return }
                view.image = image
                anchors.register(view, origin: origin)
                completed(nil)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, view != nil else { return }
                completed(String(describing: error))
            }
        }
    }
    static func dismantleUIView(_ view: PortraitSurface, coordinator: Coordinator) {
        coordinator.task?.cancel()
        view.image = nil
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PortraitSurface, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height,
            width.isFinite, height.isFinite else { return nil }
        return CGSize(width: width, height: height)
    }
}
