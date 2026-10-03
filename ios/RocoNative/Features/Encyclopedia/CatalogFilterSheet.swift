import SwiftUI
import RocoContent
import RocoDomain

/// Kept beside the primary menu, never pushed over it or presented full-screen.
struct CatalogFilterSheet: View {
    let content: ContentStore
    @Binding var query: PetCatalogQuery
    @Binding var ascending: Bool
    @State private var submenu: String?
    @State private var typeSlot = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    switch submenu {
                    case "属性":
                        Picker("属性位置", selection: $typeSlot) {
                            Text("属性一").tag(0)
                            Text("属性二").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)
                        option("全部", selected: selectedType == nil) { setType(nil) }
                        ForEach(content.catalogTypes, id: \.typeId) { type in
                            option(type.nameZh, selected: selectedType == type.typeId) { setType(type.typeId) }
                        }
                    case "形态":
                        option("全部", selected: query.leader == .all) { query.leader = .all }
                        option("普通", selected: query.leader == .ordinary) { query.leader = .ordinary }
                        option("首领", selected: query.leader == .leader) { query.leader = .leader }
                    case "阶段":
                        ForEach(PetCatalogQuery.Stage.allCases, id: \.self) { stage in
                            option(stage.rawValue, selected: query.stage == stage) { query.stage = stage }
                        }
                    case "排序":
                        ForEach(PetCatalogQuery.Sort.allCases, id: \.self) { sort in
                            option(sort.rawValue, selected: query.sort == sort) { query.sort = sort }
                        }
                    case "升/降序":
                        option("升序", selected: ascending) { ascending = true }
                        option("降序", selected: !ascending) { ascending = false }
                    default:
                        EmptyView()
                    }
                }
                .padding(.trailing, 12)
                .frame(width: 164, alignment: .leading)
            }
            .frame(width: submenu == nil ? 0 : 164, height: submenu == "属性" ? 320 : 224)
            .opacity(submenu == nil ? 0 : 1)
            .clipped()
            .allowsHitTesting(submenu != nil)
            .accessibilityHidden(submenu == nil)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(["属性", "形态", "阶段", "排序", "升/降序"], id: \.self) { title in
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
                            submenu = submenu == title ? nil : title
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.semibold))
                                .accessibilityHidden(true)
                            Text(title)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .background(submenu == title ? Color.primary.opacity(0.08) : .clear,
                            in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier("catalog-filter-\(title)")
                    .accessibilityValue(submenu == title ? "已展开" : "")
                }
                Divider().padding(.vertical, 4)
                Button("清除筛选") { query.clearFilters() }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 10)
                    .disabled(!query.hasFilters)
                    .accessibilityIdentifier("catalog-clear-filters")
            }
            .frame(width: 144)
        }
        .font(.body)
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .padding(12)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var selectedType: TypeID? { typeSlot == 0 ? query.firstType : query.secondType }

    private func setType(_ type: TypeID?) {
        if typeSlot == 0 { query.firstType = type } else { query.secondType = type }
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
