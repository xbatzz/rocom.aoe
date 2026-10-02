import SwiftUI
import RocoContent
import RocoDomain

struct TypeMatchupView: View {
    let engine: TypeMatchup
    @State private var first: TypeID
    @State private var second: TypeID?
    @State private var mode = 0

    init(content: ContentStore) {
        let engine = TypeMatchup(types: content.types)
        self.engine = engine
        // Content validation guarantees ordinary types; fail visibly if that contract changes.
        precondition(!engine.selectable.isEmpty, "Canonical types has no ordinary battle types")
        _first = State(initialValue: engine.selectable[0].typeId)
    }

    var body: some View {
        List {
            Section {
                Picker("模式", selection: $mode) {
                    Text("单属性").tag(0)
                    Text("双防御").tag(1)
                    Text("进攻覆盖").tag(2)
                }.pickerStyle(.segmented)
                Picker("第一属性", selection: $first) {
                    ForEach(engine.selectable, id: \.typeId) { Text($0.nameZh).tag($0.typeId) }
                }
                if mode != 0 {
                    Picker("第二属性", selection: $second) {
                        Text("无").tag(nil as TypeID?)
                        ForEach(engine.selectable, id: \.typeId) { Text($0.nameZh).tag(Optional($0.typeId)) }
                    }
                }
            }
            result
        }
        .navigationTitle("属性克制")
    }

    @ViewBuilder private var result: some View {
        switch makeResult() {
        case .success(let rows):
            Section(mode == 2 ? "克制覆盖（并集）" : "受到各属性攻击") {
                ForEach(rows, id: \.id) { row in LabeledContent(row.name, value: row.value) }
            }
            if mode == 0 {
                Section("进攻克制") {
                    ForEach(engine.selectable.filter { $0.weakToTypeIds.contains(first) }, id: \.typeId) {
                        Text($0.nameZh)
                    }
                }
            }
            if mode == 1 { Text("双属性相乘；4 倍按项目规则计为 3 倍。重复属性只计算一次。").font(.footnote).foregroundStyle(.secondary) }
        case .failure(let error):
            Text(String(describing: error)).foregroundStyle(.red)
        }
    }

    private struct Row {
        let id: TypeID
        let name: String
        let value: String
    }
    private func makeResult() -> Result<[Row], Error> {
        Result {
            let selected = mode == 0 ? [first] : [first] + (second.map { [$0] } ?? [])
            if mode == 2 {
                return try engine.coverage(attackers: selected).map { Row(id: $0.typeId, name: $0.nameZh, value: "克制") }
            }
            return try engine.selectable.map {
                Row(id: $0.typeId, name: $0.nameZh,
                    value: "\(try engine.defense(attack: $0.typeId, defenders: selected).formatted())×")
            }
        }
    }
}

struct NativeFeatureEntry: View {
    let content: ContentStore
    let portraits: PortraitStore
    let skills: SkillSearchIndex
    @State private var encyclopedia = false
    var body: some View {
        NavigationStack {
            List {
                Button("图鉴") { encyclopedia = true }
                NavigationLink("属性克制") { TypeMatchupView(content: content) }
                NavigationLink("技能查询") { SkillsView(content: content, portraits: portraits, index: skills) }
            }.navigationTitle("洛克工具")
        }
        .fullScreenCover(isPresented: $encyclopedia) {
            ZStack(alignment: .bottomTrailing) {
                AlignedNavigation(content: content, portraits: portraits).ignoresSafeArea()
                Button("功能首页", systemImage: "house") { encyclopedia = false }
                    .buttonStyle(.borderedProminent).padding()
            }
        }
    }
}
