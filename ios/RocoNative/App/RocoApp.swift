import SwiftUI
import Observation
import RocoContent
import SwiftData
import RocoUserData
import os

/// One application-owned snapshot, shared by all windows/features. No feature opens JSON.
@MainActor @Observable
final class AppContent {
    enum State {
        case loading
        case ready(ContentStore, PortraitStore, SkillSearchIndex, TrackingCatalogIndex, ModelContainer)
        case failed(String)
    }
    private(set) var state: State = .loading
    private var started = false
    private let logger = Logger(subsystem: "com.batzz.rocom", category: "startup")

    private static var visualReviewActive: Bool {
        #if DEBUG
        VisualReview.route != nil
        #else
        false
        #endif
    }

    func load() async {
        guard !started else { return }
        started = true
        let start = ContinuousClock.now
        do {
            guard let url = Bundle.main.url(forResource: "ContentResources", withExtension: "bundle") else {
                throw ContentError.invalid("App Bundle 缺少 ContentResources.bundle")
            }
            let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1
            // Open the user database while the immutable content snapshot is built off the UI actor.
            async let snapshot = Self.loadSnapshot(bundleURL: url, appBuild: build)
            let database = try UserDatabase.open(inMemory: Self.visualReviewActive)
            let (store, skills, tracking) = try await snapshot
            #if DEBUG
            if Self.visualReviewActive { try VisualReview.seed(database.mainContext, content: store, tracking: tracking) }
            #endif
            state = .ready(store, PortraitStore(resolver: store.assetResolver), skills, tracking, database)
            logger.info("Home content ready after \(String(describing: start.duration(to: .now)), privacy: .public)")
        } catch {
            state = .failed(String(describing: error))
        }
    }

    @concurrent private static func loadSnapshot(bundleURL: URL, appBuild: Int) async throws
        -> (ContentStore, SkillSearchIndex, TrackingCatalogIndex) {
        guard let bundle = Bundle(url: bundleURL) else { throw ContentError.invalid("Cannot open content Bundle") }
        let store = try ContentStore.load(bundle: bundle, appBuild: appBuild, assetValidation: .onDemand)
        return (store, SkillSearchIndex(content: store), TrackingCatalogIndex(content: store))
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
                    ProgressView("正在加载内容…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let store, let portraits, let skills, let tracking, let database):
                    #if DEBUG
                    if let route = VisualReview.route {
                        AppearanceContainer { VisualReview.page(route, content: store, portraits: portraits, skills: skills, tracking: tracking) }.modelContainer(database)
                    } else {
                        AppearanceContainer { NativeFeatureEntry(content: store, portraits: portraits, skills: skills, tracking: tracking) }.modelContainer(database)
                    }
                    #else
                    AppearanceContainer { NativeFeatureEntry(content: store, portraits: portraits, skills: skills, tracking: tracking) }.modelContainer(database)
                    #endif
                case .failed(let message):
                    ContentUnavailableView("内容或用户数据库未能加载", systemImage: "exclamationmark.triangle",
                        description: Text(message))
                }
            }
            .background(Color(uiColor: .systemBackground))
            .task { await content.load() }
        }
    }
}

private struct AppearanceContainer<Content: View>: View {
    @Query private var preferences: [UserPreferences]
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().preferredColorScheme(preferences.first?.appearance == .light ? .light : preferences.first?.appearance == .dark ? .dark : nil)
    }
}
