import SwiftUI
import UIKit

/// Read-only display-link telemetry; no animation timing, visibility or alpha writes.
final class Trace: NSObject {
    static let shared = Trace()
    weak var root: UIView?
    private var link: CADisplayLink?
    private var records: [[String: Any]] = []
    private var experiment = Experiment.selected
    private var savedProbes = false
    private var wasTransitioning = false
    var directory: URL {
        URL.documentsDirectory.appending(path: experiment.rawValue, directoryHint: .isDirectory)
    }
    func configure(_ value: Experiment) {
        if experiment != value { records = []; savedProbes = false; wasTransitioning = false }
        experiment = value
    }
    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        event("start", ["imageSize": [Fixture.image.size.width, Fixture.image.size.height], "alphaInfo": Fixture.image.cgImage?.alphaInfo.rawValue ?? 0, "uptime": ProcessInfo.processInfo.systemUptime])
    }
    func event(_ name: String, _ info: [String: Any] = [:]) {
        records.append(["kind": name, "time": CACurrentMediaTime(), "epoch": Date().timeIntervalSince1970, "variant": experiment.rawValue, "info": info])
    }
    @objc private func tick(_ link: CADisplayLink) {
        guard let root, let window = (root as? UIWindow) ?? root.window else { return }
        let controllers = window.rootViewController.map { allControllers($0) } ?? []
        let transition = controllers.compactMap(\.transitionCoordinator).first
        let active = transition != nil
        // Keep transition frames plus the first actual post-transition display frame.
        if active || wasTransitioning || experiment.swiftUI {
            records.append(["kind": "frame", "time": link.timestamp, "targetTime": link.targetTimestamp,
                            "active": active, "interactive": transition?.isInteractive ?? false,
                            "percent": transition?.percentComplete ?? 0, "views": tree(window, depth: 0)])
        }
        if wasTransitioning && !active { event("transition-ended"); flush() }
        wasTransitioning = active
    }
    private func allControllers(_ controller: UIViewController) -> [UIViewController] {
        [controller] + controller.children.flatMap(allControllers)
    }
    private func tree(_ view: UIView, depth: Int) -> [[String: Any]] {
        guard depth < 18 else { return [] }
        return [Self.describe(view).merging(["depth": depth]) { _, new in new }] + view.subviews.flatMap { tree($0, depth: depth + 1) }
    }
    static func rect(_ rect: CGRect) -> [CGFloat] { [rect.minX, rect.minY, rect.width, rect.height] }
    static func color(_ color: UIColor?) -> [CGFloat] {
        guard let color else { return [] }
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return [] }
        return [r, g, b, a]
    }
    static func describe(_ view: UIView) -> [String: Any] {
        let layer = view.layer.presentation() ?? view.layer
        var info: [String: Any] = ["class": String(describing: type(of: view)), "id": view.accessibilityIdentifier ?? "", "address": String(describing: Unmanaged.passUnretained(view).toOpaque()), "bounds": rect(view.bounds), "windowRect": rect(view.convert(view.bounds, to: view.window)), "presentationFrame": rect(layer.frame), "hidden": view.isHidden, "alpha": view.alpha, "opacity": layer.opacity, "opaque": view.isOpaque, "layerOpaque": view.layer.isOpaque, "background": color(view.backgroundColor), "layerBackground": color(layer.backgroundColor.map(UIColor.init(cgColor:))) ]
        if let bitmap = view as? UIImageView {
            info["sameImage"] = bitmap.image === Fixture.image
            info["imageAlpha"] = bitmap.image?.cgImage?.alphaInfo.rawValue ?? -1
        }
        return info
    }
    func flush() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys]).write(to: directory.appending(path: "trace.json"), options: .atomic)
        } catch { assertionFailure("Evidence export failed: \(error)") }
    }
    /// Probes run only after didShow; they never feed a bitmap into the transition.
    func probes(hero: LabSurface, controller: UIViewController) {
        guard !savedProbes else { return }
        savedProbes = true
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Fixture.image.pngData()?.write(to: directory.appending(path: "decoded.png"))
            for (name, view) in [("image-only", hero.bitmap as UIView), ("hero-container", hero), ("detail-root", controller.view!)] {
                let format = UIGraphicsImageRendererFormat()
                format.opaque = false
                format.scale = 1
                let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
                let image = renderer.image { _ in view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) }
                try image.pngData()?.write(to: directory.appending(path: name + ".png"))
                event("snapshot-probe", ["name": name, "view": Self.describe(view), "alphaInfo": image.cgImage?.alphaInfo.rawValue ?? 0])
            }
        } catch { assertionFailure("Probe failed: \(error)") }
    }
}

struct WindowProbe: UIViewRepresentable {
    let experiment: Experiment
    func makeUIView(context: Context) -> ProbeView {
        Trace.shared.configure(experiment)
        return ProbeView()
    }
    func updateUIView(_ view: ProbeView, context: Context) {}
    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            Trace.shared.root = window
            Trace.shared.start()
        }
    }
}
