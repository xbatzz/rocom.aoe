import SwiftUI
import RocoDomain
import RocoContent

extension Pet {
    var numberLabel: String {
        if let handbookId { return String(format: "No. %03d", handbookId.rawValue) }
        return "配置 \(petId.rawValue)"
    }
}

/// Catalog queries operate only on canonical values; images remain owned by lazy cells.

struct AlignedPetGrid: View {
    /// Passed from ContentStore.orderedPets; never Dictionary iteration order.
    let pets: [Pet]
    let content: ContentStore
    let portraits: PortraitStore
    let anchors: PortraitAnchors
    let open: (Pet, PortraitOrigin) -> Void
    @State private var query = PetCatalogQuery()
    @State private var ascending = true
    @State private var chromeVisible = true
    @State private var results: [Pet] = []
    @State private var prefetchByPet: [PetID: [AssetID]] = [:]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize


    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("图鉴")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("catalog-title")
                    Text("\(results.count) 只精灵")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("catalog-count")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .background(Color(uiColor: .systemBackground))

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        if results.isEmpty {
                            ContentUnavailableView {
                                Label("没有符合条件的精灵", systemImage: "magnifyingglass")
                            } description: {
                                Text("试试其他关键词，或清除筛选条件。")
                            } actions: {
                                Button("重置搜索与筛选") { query = PetCatalogQuery() }
                            }
                        }
                        Color.clear.frame(height: 0).id("catalog-results-top")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 150), spacing: 20)], spacing: 28) {
                            ForEach(displayedResults, id: \.petId) { pet in
                                PetGridCell(pet: pet, content: content, portraits: portraits, anchors: anchors, prefetch: prefetchByPet[pet.petId] ?? []) { pet, origin in
                                    open(pet, origin)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .task(id: query) {
                let updated = await query.results(content: content)
                guard !Task.isCancelled else { return }
                var ahead: [PetID: [AssetID]] = [:]
                for offset in stride(from: 0, to: updated.count, by: 4) {
                    ahead[updated[offset].petId] = updated.dropFirst(offset + 1).prefix(4).compactMap(\.portraitAssetId)
                }
                prefetchByPet = ahead
                results = updated
            }
            .onChange(of: query) {
                proxy.scrollTo("catalog-results-top", anchor: .top)
            }
            .onScrollPhaseChange { _, phase, _ in
                // SwiftUI owns the scroll gesture in this embedded hierarchy, so
                // drive UIKit's standard bar visibility only at phase boundaries.
                chromeVisible = phase == .idle
            }
            .reviewScrollPosition()
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemBackground))
            .background {
                CatalogFilterToolbar(
                    content: content,
                    query: $query,
                    ascending: $ascending,
                    chromeVisible: chromeVisible
                )
                    .frame(width: 0, height: 0)
            }
        }
    }

    // Direction is presentation state; canonical query matching and sorting stay intact.
    private var displayedResults: [Pet] {
        let naturallyAscending = query.sort == .handbook || query.sort == .name
        return ascending == naturallyAscending ? results : Array(results.reversed())
    }

}

/// The mounted UIImageView owns the bitmap; cell state retains only load status.
/// Scrolling away dismantles the view without retaining one UIImage per visited pet.
private struct PetGridCell: View {
    let pet: Pet
    let content: ContentStore
    let portraits: PortraitStore
    let anchors: PortraitAnchors
    let prefetch: [AssetID]
    let open: (Pet, PortraitOrigin) -> Void
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        let origin = PortraitOrigin(petID: pet.petId, instance: "encyclopedia-grid")
        Button { open(pet, origin) } label: {
            VStack(alignment: .center, spacing: 6) {
                GeometryReader { geometry in
                    LoadingPortrait(pet: pet, portraits: portraits, origin: origin, anchors: anchors) { failure in
                        error = failure
                        loaded = failure == nil
                    }
                    .frame(width: geometry.size.width * 0.94, height: geometry.size.height * 0.94)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .aspectRatio(1, contentMode: .fit)
                .allowsHitTesting(false)
                Text(pet.nameZh).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pet.numberLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(pet.typeIds, id: \.self) { id in
                        if let type = content.type(id) {
                            HStack(spacing: 3) {
                                if let image = GameIconCatalog.type(id) {
                                    Image(uiImage: image).resizable().scaledToFit()
                                        .frame(width: 16, height: 16).accessibilityHidden(true)
                                }
                                Text(type.nameZh)
                            }
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if let error { Text(error).font(.caption2).foregroundStyle(.red) }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(.interaction, Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!loaded)
        .accessibilityIdentifier("pet-\(pet.petId.rawValue)")
        .accessibilityLabel("\(pet.nameZh)，\(pet.numberLabel)，\(pet.typeIds.compactMap { content.type($0)?.nameZh }.joined(separator: "、"))")
        .accessibilityHint(error != nil ? "图片加载失败" : loaded ? "查看精灵详情" : "正在加载图片")
        .task(id: pet.petId) {
            guard !prefetch.isEmpty else { return }
            await portraits.thumbnails.prefetch(prefetch, maxPixelSize: 512)
        }
    }
}
