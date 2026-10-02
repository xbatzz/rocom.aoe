import SwiftUI
import Observation
import RocoContent

/// One application-owned snapshot, shared by all windows/features. No feature opens JSON.
@MainActor @Observable
final class AppContent {
    enum State {
        case loading
        case ready(ContentStore, PortraitStore)
        case failed(String)
    }
    private(set) var state: State = .loading
    private var started = false

    func load() async {
        guard !started else { return }
        started = true
        do {
            guard let url = Bundle.main.url(forResource: "ContentResources", withExtension: "bundle") else {
                throw ContentError.invalid("App Bundle 缺少 ContentResources.bundle")
            }
            let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1
            let store = try await ContentStore.loadInBackground(bundleURL: url, appBuild: build)
            state = .ready(store, PortraitStore(resolver: store.assetResolver))
        } catch {
            state = .failed(String(describing: error))
        }
    }
}

@main
struct RocoApp: App {
    @State private var content = AppContent()

    var body: some Scene {
        WindowGroup {
            Group {
                switch content.state {
                case .loading:
                    ProgressView("正在加载图鉴…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let store, let portraits):
                    AlignedNavigation(content: store, portraits: portraits).ignoresSafeArea()
                case .failed(let message):
                    ContentUnavailableView("图鉴未能加载", systemImage: "exclamationmark.triangle",
                        description: Text(message))
                }
            }
            .background(Color(uiColor: .systemBackground))
            .task { await content.load() }
        }
    }
}
