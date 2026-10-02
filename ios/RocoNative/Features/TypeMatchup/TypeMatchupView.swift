import SwiftUI
import RocoContent
import RocoDomain

struct TypeMatchupView: View {
    let engine: TypeMatchup
    @State private var first: TypeID
    @State private var second: TypeID?
    @State private var mode = 0
    @State private var neutralExpanded = true

    init(content: ContentStore) {
        let engine = TypeMatchup(types: content.types)
        self.engine = engine
        // Content validation guarantees ordinary types; fail visibly if that contract changes.
        precondition(!engine.selectable.isEmpty, "Canonical types has no ordinary battle types")
        _first = State(initialValue: engine.selectable[0].typeId)
        #if DEBUG
        if VisualReview.route == "types-dual" || VisualReview.route == "types-coverage", engine.selectable.count > 3 {
            _mode = State(initialValue: VisualReview.route == "types-dual" ? 1 : 2)
            _first = State(initialValue: engine.selectable[2].typeId)
            _second = State(initialValue: engine.selectable[3].typeId)
        }
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("模式", selection: $mode) {
                    Text("单属性").tag(0)
                    Text("双防御").tag(1)
                    Text("进攻覆盖").tag(2)
                }.pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 12) {
                    Text(mode == 2 ? "选择进攻属性" : "选择防御属性").font(.headline)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(engine.selectable, id: \.typeId) { type in
                                Button { first = type.typeId } label: {
                                    TypeBadge(type: type).padding(.vertical, 6).padding(.horizontal, 4)
                                        .background(first == type.typeId ? Color.primary.opacity(0.08) : .clear, in: Capsule())
                                        .overlay(Capsule().strokeBorder(first == type.typeId ? Color.primary.opacity(0.5) : .clear))
                                }.buttonStyle(.plain).accessibilityAddTraits(first == type.typeId ? .isSelected : [])
                            }
                        }
                    }.scrollIndicators(.hidden)
                    if mode != 0 {
                        Picker("第二属性", selection: $second) {
                            Text("无").tag(nil as TypeID?)
                            ForEach(engine.selectable, id: \.typeId) { Text($0.nameZh).tag(Optional($0.typeId)) }
                        }.pickerStyle(.menu).tint(.primary)
                    }
                }
                HStack(spacing: 12) {
                    if let type = engine.selectable.first(where: { $0.typeId == first }) {
                        if let image = GameIconCatalog.type(first) {
                            Image(uiImage: image).resizable().scaledToFit().frame(width: 32, height: 33).accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.nameZh + (mode == 0 ? "属性" : second.flatMap { id in engine.selectable.first { $0.typeId == id }?.nameZh }.map { " + " + $0 } ?? "属性"))
                                .font(.title2.bold())
                            Text(mode == 2 ? "克制覆盖按并集合并" : "下方倍率为受到攻击时的伤害倍率").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                result
            }.padding(20)
        }.reviewScrollPosition().companionBackground().navigationTitle("属性克制")
    }

    @ViewBuilder private var result: some View {
        switch makeResult() {
        case .success(let rows):
            if mode == 2 {
                CompanionSection("克制覆盖 · \(rows.count) 种属性") { typeGrid(rows) }
                if rows.isEmpty { Text("当前选择没有克制覆盖。").foregroundStyle(.secondary) }
            } else {
                ForEach(Array(Set(rows.map(\.multiplier))).filter { $0 != 1 }.sorted(by: >), id: \.self) { multiplier in
                    CompanionSection("\(multiplier.formatted())× · \(multiplier > 1 ? "弱点" : "抵抗")") {
                        typeGrid(rows.filter { $0.multiplier == multiplier })
                    }
                }
                DisclosureGroup("1× · 一般承伤", isExpanded: $neutralExpanded) { typeGrid(rows.filter { $0.multiplier == 1 }).padding(.top, 12) }
                    .font(.subheadline.weight(.medium)).tint(.primary)
            }
            if mode == 0 {
                CompanionSection("进攻克制") {
                    let targets = engine.selectable.filter { $0.weakToTypeIds.contains(first) }
                    if targets.isEmpty { Text("该属性没有额外的进攻克制。").font(.subheadline).foregroundStyle(.secondary) }
                    else { typeGrid(targets.map { Row(type: $0, multiplier: 2) }) }
                }
            }
            if mode == 1 { Text("双属性相乘；4 倍按项目规则计为 3 倍。重复属性只计算一次。").font(.footnote).foregroundStyle(.secondary) }
        case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
        }
    }
    private func typeGrid(_ rows: [Row]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(rows, id: \.id) { row in
                TypeBadge(type: row.type).padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    private struct Row {
        let type: BattleType
        let multiplier: Double
        var id: TypeID { type.typeId }
    }
    private func makeResult() -> Result<[Row], Error> {
        Result {
            let selected = mode == 0 ? [first] : [first] + (second.map { [$0] } ?? [])
            if mode == 2 {
                return try engine.coverage(attackers: selected).map { Row(type: $0, multiplier: 2) }
            }
            return try engine.selectable.map {
                Row(type: $0, multiplier: try engine.defense(attack: $0.typeId, defenders: selected))
            }
        }
    }
}
