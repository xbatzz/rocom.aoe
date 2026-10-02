import SwiftUI
import UIKit

enum Experiment: String, CaseIterable {
    case aImage = "A-image"
    case aEqual = "A-equal"
    case aClear = "A-clear-source"
    case bParity = "B-parity"
    case bClear = "B-clear-hero"
    case bTransparent = "B-explicit-transparent"
    case bHeroMarker = "B-hero-magenta"
    case bPageMarker = "B-page-green"
    case bNoAlignment = "B-no-alignment"
    case cContainer = "C-black-container"
    case cBlackConfig = "C-black-source-config"

    var swiftUI: Bool { self == .aImage || self == .aEqual || self == .aClear || self == .cBlackConfig }
    var heroColor: UIColor {
        switch self {
        case .bClear, .bTransparent, .bPageMarker: .clear
        case .bHeroMarker: .magenta
        default: .black
        }
    }
    var pageColor: UIColor { self == .bPageMarker ? .green : .black }
    var heroSide: CGFloat { self == .aEqual ? 160 : 320 }
    static var selected: Self {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--variant"), args.indices.contains(index + 1) else { return .bParity }
        return Self(rawValue: args[index + 1]) ?? .bParity
    }
}

enum Fixture {
    static let image: UIImage = {
        guard let url = Bundle.main.url(forResource: "JL_miaomiao", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { preconditionFailure("Missing shared PNG") }
        return image
    }()
    static let cell = Color(white: 0.18)
}

@main
struct HarnessApp: App {
    @State private var experiment = Experiment.selected
    var body: some Scene {
        WindowGroup {
            Group {
                if experiment.swiftUI {
                    SwiftUIExperiment(experiment: experiment)
                } else {
                    UIKitExperiment(experiment: experiment).ignoresSafeArea()
                }
            }
            .id(experiment)
            .preferredColorScheme(.dark)
            .overlay(alignment: .bottomTrailing) {
                Menu("Variant") {
                    ForEach(Experiment.allCases, id: \.self) { variant in
                        Button(variant.rawValue) { experiment = variant }
                    }
                }
                .padding(16)
            }
        }
    }
}

struct SwiftUIExperiment: View {
    let experiment: Experiment
    @Namespace private var namespace
    @State private var path: [Int] = []
    private var bitmap: some View {
        Image(uiImage: Fixture.image).resizable().scaledToFit().frame(width: 134.4, height: 134.4)
    }
    @ViewBuilder private var source: some View {
        if experiment == .aClear {
            bitmap.matchedTransitionSource(id: 1, in: namespace) { $0.background(.clear) }
        } else if experiment == .cBlackConfig {
            // Deliberately include a black background in the transition source
            // configuration while the resting cell remains grey.
            bitmap.matchedTransitionSource(id: 1, in: namespace) { $0.background(.black) }
        } else {
            bitmap.matchedTransitionSource(id: 1, in: namespace)
        }
    }
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 24) {
                Text(experiment.rawValue).accessibilityIdentifier("variant-label")
                HStack(spacing: 20) {
                    Button { Trace.shared.event("open"); path.append(1) } label: {
                        // The registered source has no cell background or padding.
                        source
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                                Trace.shared.event("source-layout", ["rect": Trace.rect($0)])
                            }
                            .frame(width: 160, height: 160)
                            .background(Fixture.cell, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("open-pet")
                    Fixture.cell.frame(width: 160, height: 160).clipShape(.rect(cornerRadius: 18))
                }
                Spacer()
                Button("Export probes") { Trace.shared.flush() }.accessibilityIdentifier("export")
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .background(WindowProbe(experiment: experiment))
            .navigationTitle("Grid")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Int.self) { _ in
                VStack(spacing: 24) {
                    Image(uiImage: Fixture.image).resizable().scaledToFit()
                        .frame(width: experiment.heroSide * 0.84, height: experiment.heroSide * 0.84)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                            Trace.shared.event("hero-layout", ["rect": Trace.rect($0)])
                        }
                        .frame(width: experiment.heroSide, height: experiment.heroSide)
                    Text("Transparent PNG · black detail")
                    Spacer()
                }
                .padding(.top, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .accessibilityIdentifier("detail")
                .navigationTitle("Hero").navigationBarTitleDisplayMode(.inline)
                .navigationTransition(.zoom(sourceID: 1, in: namespace))
                .onAppear { Trace.shared.event("detail-appear") }
                .onDisappear { Trace.shared.event("detail-disappear"); Trace.shared.flush() }
            }
            .onAppear { Trace.shared.event("grid-appear") }
        }
    }
}

// Copy of the production surface's layout, independently owned by the lab.
// B-parity keeps production defaults. B-clear changes ONLY Hero background.
final class LabSurface: UIView {
    let bitmap = UIImageView(image: Fixture.image)
    init(thumbnail: Bool, experiment: Experiment) {
        super.init(frame: .zero)
        bitmap.contentMode = .scaleAspectFit
        bitmap.accessibilityIdentifier = thumbnail ? "source-image" : "hero-image"
        addSubview(bitmap)
        backgroundColor = thumbnail ? UIColor(white: 0.18, alpha: 1) : experiment.heroColor
        layer.cornerRadius = thumbnail ? 18 : 0
        clipsToBounds = true
        if experiment == .bTransparent {
            isOpaque = false
            bitmap.backgroundColor = .clear
            bitmap.isOpaque = false
            bitmap.layer.isOpaque = false
            layer.isOpaque = false
        }
        accessibilityIdentifier = thumbnail ? "source-container" : "hero-container"
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        bitmap.frame = bounds.insetBy(dx: bounds.width * 0.08, dy: bounds.height * 0.08)
    }
}

final class LabAnchors {
    weak var source: LabSurface?
    weak var hero: LabSurface?
}

struct LabPortrait: UIViewRepresentable {
    let thumbnail: Bool
    let experiment: Experiment
    let anchors: LabAnchors
    func makeUIView(context: Context) -> LabSurface {
        let view = LabSurface(thumbnail: thumbnail, experiment: experiment)
        if thumbnail { anchors.source = view } else { anchors.hero = view }
        return view
    }
    func updateUIView(_ view: LabSurface, context: Context) {}
}

struct LabGrid: View {
    let experiment: Experiment
    let anchors: LabAnchors
    let open: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text(experiment.rawValue).accessibilityIdentifier("variant-label")
            HStack(spacing: 20) {
                Button(action: open) {
                    LabPortrait(thumbnail: true, experiment: experiment, anchors: anchors)
                        .frame(width: 160, height: 160)
                }.buttonStyle(.plain).accessibilityIdentifier("open-pet")
                Fixture.cell.frame(width: 160, height: 160).clipShape(.rect(cornerRadius: 18))
            }
            Spacer()
            Button("Export probes") { Trace.shared.flush() }.accessibilityIdentifier("export")
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

struct LabDetail: View {
    let experiment: Experiment
    let anchors: LabAnchors
    var body: some View {
        VStack(spacing: 24) {
            LabPortrait(thumbnail: false, experiment: experiment, anchors: anchors)
                .frame(width: experiment.heroSide, height: experiment.heroSide)
            Text("Transparent PNG · black detail").foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: experiment.pageColor))
        .accessibilityIdentifier("detail")
    }
}

struct UIKitExperiment: UIViewControllerRepresentable {
    let experiment: Experiment
    func makeCoordinator() -> Coordinator { Coordinator(experiment: experiment) }
    func makeUIViewController(context: Context) -> UINavigationController { context.coordinator.makeNavigation() }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate {
        let experiment: Experiment
        let anchors = LabAnchors()
        weak var navigation: UINavigationController?
        init(experiment: Experiment) { self.experiment = experiment }
        func makeNavigation() -> UINavigationController {
            let root = UIHostingController(rootView: LabGrid(experiment: experiment, anchors: anchors, open: open))
            root.title = "Grid"
            root.navigationItem.largeTitleDisplayMode = .always
            let nav = UINavigationController(rootViewController: root)
            nav.overrideUserInterfaceStyle = .dark
            nav.navigationBar.prefersLargeTitles = true
            nav.delegate = self
            navigation = nav
            Trace.shared.configure(experiment)
            Trace.shared.root = nav.view
            Trace.shared.start()
            return nav
        }
        func open() {
            guard let nav = navigation, nav.viewControllers.count == 1 else { return }
            Trace.shared.event("open")
            let detail = UIHostingController(rootView: LabDetail(experiment: experiment, anchors: anchors))
            detail.title = "Hero"
            detail.navigationItem.largeTitleDisplayMode = .never
            detail.view.backgroundColor = experiment.pageColor
            let options = UIViewController.Transition.ZoomOptions()
            if experiment != .bNoAlignment {
                options.alignmentRectProvider = { [weak anchors] context in
                    guard let hero = anchors?.hero, hero.isDescendant(of: context.zoomedViewController.view) else {
                        Trace.shared.event("alignment-nil"); return nil
                    }
                    let target: UIView = self.experiment == .cContainer ? hero : hero.bitmap
                    let rect = target.convert(target.bounds, to: context.zoomedViewController.view)
                    Trace.shared.event("alignment", ["rect": Trace.rect(rect), "target": target.accessibilityIdentifier ?? "", "source": String(describing: type(of: context.sourceView))])
                    return rect
                }
            }
            detail.preferredTransition = .zoom(options: options) { [weak anchors, experiment] _ in
                let view: UIView? = experiment == .cContainer ? anchors?.source : anchors?.source?.bitmap
                Trace.shared.event("resolve-source", ["view": view.map(Trace.describe) ?? [:]])
                return view
            }
            nav.pushViewController(detail, animated: true)
        }
        func navigationController(_ nav: UINavigationController, willShow controller: UIViewController, animated: Bool) {
            Trace.shared.event(nav.viewControllers.count == 2 ? "will-detail" : "will-grid")
        }
        func navigationController(_ nav: UINavigationController, didShow controller: UIViewController, animated: Bool) {
            Trace.shared.event(nav.viewControllers.count == 2 ? "did-detail" : "did-grid", ["source": anchors.source.map(Trace.describe) ?? [:], "hero": anchors.hero.map(Trace.describe) ?? [:]])
            if nav.viewControllers.count == 2, let hero = anchors.hero {
                Trace.shared.probes(hero: hero, controller: controller)
            }
            Trace.shared.flush()
        }
    }
}
