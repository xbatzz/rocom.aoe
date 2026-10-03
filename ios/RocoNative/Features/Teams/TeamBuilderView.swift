import SwiftUI
import SwiftData
import RocoContent
import RocoDomain
import RocoUserData

struct TeamBuilderView: View {
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    @Query(sort: \TeamRecord.updatedAt, order: .reverse) private var teams: [TeamRecord]
    @Environment(\.modelContext) private var context
    @State private var deleting: TeamRecord?
    @State private var editing: TeamBuild?
    @State private var error: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                CompanionMetrics {
                    CompanionMetric(value: String(teams.count), label: "已保存队伍")
                    if !teams.isEmpty {
                    Button("新建队伍", systemImage: "plus") { editing = TeamBuild() }
                        .companionPrimaryAction()
                        .disabled(teams.count >= 10)
                    }
                }
                if teams.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("从六个伙伴开始").font(.title2.bold())
                        Text("搭配精灵的属性、血脉与技能，保存你的对战构筑。").font(.subheadline).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 16) {
                            ForEach(1...6, id: \.self) { i in
                                VStack(spacing: 8) {
                                    Text(String(format: "%02d", i)).font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                                        .frame(width: 56, height: 56)
                                        .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                                    Text("空槽位").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.accessibilityLabel("六个待配置的队伍槽位")
                        Button("组建第一支队伍") { editing = TeamBuild() }
                            .companionPrimaryAction()
                    }.padding(20).companionSurface()
                }
                ForEach(teams) { record in
                    Button {
                        do { editing = try record.decode() }
                        catch { self.error = String(describing: error) }
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(record.name).font(.title3.bold())
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            switch Result(catching: { try record.decode() }) {
                            case .success(let build):
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 88), alignment: .top)], spacing: 16) {
                                    ForEach(build.slots.indices, id: \.self) { i in
                                        let slot = build.slots[i]
                                        let pet = slot.petID.flatMap { content.pets[PetID(rawValue: $0)] }
                                        VStack(spacing: 6) {
                                            if let pet {
                                                CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 64)
                                            } else {
                                                Text(String(format: "%02d", i + 1)).font(.title3.monospacedDigit()).foregroundStyle(.secondary)
                                                    .frame(width: 64, height: 64).background(Color(uiColor: .tertiarySystemFill), in: Circle())
                                            }
                                            Text(pet?.nameZh ?? (slot.petID == nil ? "空槽位" : "无法解析"))
                                                .font(.caption.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                            if let pet {
                                                PetTypes(pet: pet, content: content)
                                                Text("\(slot.skillIDs.count) / 4 技能").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                Text("\(build.slots.filter { $0.petID != nil }.count) / 6 精灵 · \(build.slots.reduce(0) { $0 + $1.skillIDs.count }) 个技能")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            case .failure: Text("队伍读取失败 · 原数据已保留").font(.subheadline).foregroundStyle(.red)
                            }
                        }.padding(20).companionSurface()
                    }.buttonStyle(.plain)
                    .contextMenu {
                        Button("编辑 / 重命名") {
                            do { editing = try record.decode() }
                            catch { self.error = String(describing: error) }
                        }
                        Button("复制") {
                            do { try UserDatabase.duplicateTeam(record, context: context) }
                            catch { self.error = String(describing: error) }
                        }.disabled(teams.count >= 10)
                        Button("删除", role: .destructive) { deleting = record }.disabled(teams.count <= 1)
                    }
                }
                Text("最多保存 10 支队伍，每队 6 个槽位。长按已保存队伍可复制、重命名或删除。").font(.footnote).foregroundStyle(.secondary)
                if teams.count > 10 { Text("已有 \(teams.count) 队，完整保留。新建与复制暂不可用。").foregroundStyle(.secondary) }
            }.padding(20)
        }.reviewScrollPosition().companionBackground().navigationTitle("配队")
            .confirmationDialog("删除此队伍？此操作不会改变其他队伍或收藏。", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("删除队伍", role: .destructive) {
                    guard let record = deleting else { return }
                    do { try UserDatabase.deleteTeam(record, context: context); deleting = nil }
                    catch { self.error = String(describing: error) }
                }
                Button("取消", role: .cancel) { deleting = nil }
            }
            .sheet(item: $editing) { build in TeamDraftView(initial: build, content: content, portraits: portraits, skillIndex: skillIndex) }
            .alert("队伍读取失败 · 原数据已保留", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}

struct TeamDraftView: View {
    let initial: TeamBuild
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    @State private var draft: TeamBuild
    @State private var first = 0
    @State private var second = 1
    @State private var error: String?
    @State private var discard = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    init(initial: TeamBuild, content: ContentStore, portraits: PortraitStore, skillIndex: SkillSearchIndex) {
        self.initial = initial; self.content = content; self.portraits = portraits; self.skillIndex = skillIndex; _draft = State(initialValue: initial)
    }
    private var dirty: Bool { draft != initial }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("队伍名称", text: $draft.name).font(.title2.bold()).accessibilityLabel("队伍名称")
                        CompanionMetrics { Text("魔法道具").font(.subheadline); magicPicker.labelsHidden().tint(.primary) }
                        Text("\(draft.slots.filter { $0.petID != nil }.count) / 6 精灵 · 保存后写入本机")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }.padding(20).companionSurface()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 150), spacing: 12)], spacing: 12) {
                        ForEach(draft.slots.indices, id: \.self) { i in
                            NavigationLink {
                                TeamSlotView(slot: $draft.slots[i], content: content, portraits: portraits, skillIndex: skillIndex)
                            } label: { TeamPetTile(slot: draft.slots[i], content: content, label: "槽位 \(i + 1)", compact: true) }
                                .buttonStyle(.plain)
                        }
                    }
                    DisclosureGroup("交换两个槽位") {
                        VStack(spacing: 12) {
                            Picker("来源", selection: $first) { ForEach(0..<6, id: \.self) { Text("槽位 \($0 + 1)").tag($0) } }
                            Picker("目标", selection: $second) { ForEach(0..<6, id: \.self) { Text("槽位 \($0 + 1)").tag($0) } }
                            Button("交换") {
                                do { try draft.swapSlots(first, second) }
                                catch { self.error = String(describing: error) }
                            }.buttonStyle(.bordered).disabled(first == second)
                        }.padding(.top, 12)
                    }.tint(.primary).padding(20).companionSurface()
                }.padding(20)
            }.reviewScrollPosition().companionBackground().navigationTitle("队伍编辑")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { if dirty { discard = true } else { dismiss() } }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            do { try UserDatabase.saveTeam(draft, context: context); dismiss() }
                            catch { self.error = String(describing: error) }
                        }
                    }
                }
        }.interactiveDismissDisabled(dirty)
            .confirmationDialog("放弃未保存的队伍草稿？", isPresented: $discard, titleVisibility: .visible) {
                Button("放弃草稿", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .alert("未能保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
    private var magicPicker: some View {
        Picker("魔法道具", selection: $draft.magicItemID) {
            Text("无").tag(nil as Int?)
            if let id = draft.magicItemID, content.magicItems[MagicItemID(rawValue: id)] == nil {
                Text("无法解析 #\(id) · 保留").tag(Optional(id))
            }
            ForEach(content.magicItems.values.sorted { $0.magicItemId.rawValue < $1.magicItemId.rawValue }, id: \.magicItemId) {
                Text($0.nameZh).tag(Optional($0.magicItemId.rawValue))
            }
        }
    }
    private func slotName(_ slot: TeamSlot) -> String {
        guard let id = slot.petID else { return "空槽" }
        return content.pets[PetID(rawValue: id)]?.nameZh ?? "无法解析精灵 #\(id) · 保留"
    }
}

struct TeamSlotView: View {
    @Binding var slot: TeamSlot
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    @State private var error: String?
    private var pet: Pet? { slot.petID.flatMap { content.pets[PetID(rawValue: $0)] } }
    var body: some View {
        Form {
            Section {
                NavigationLink("选择精灵") { TeamPetPicker(slot: $slot, content: content) }
                if let pet {
                    HStack(spacing: 16) {
                        CanonicalThumbnail(assetID: pet.portraitAssetId, content: content, size: 80)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pet.nameZh).font(.title3.bold())
                            PetTypes(pet: pet, content: content)
                        }
                    }.padding(.vertical, 8)
                }
                else if let id = slot.petID { Text("无法解析精灵 #\(id)，当前字段保持原样。") }
                Button("清空此槽", role: .destructive) { slot = TeamSlot() }
            }
            if let pet {
                Section("资料") {
                    NavigationLink("精灵详情") { ExistingPetDestination(pet: pet, content: content, portraits: portraits) }
                    ForEach(slot.skillIDs, id: \.self) { id in
                        if let skill = content.skills[SkillID(rawValue: id)] {
                            NavigationLink(skill.nameZh) { SkillDetailView(skill: skill, content: content, portraits: portraits, index: skillIndex) }
                        }
                    }
                }
                Section("性格与血脉") {
                    personalityPicker
                    legacyPicker(pet)
                }
                individualSection
                statsSection(pet)
                movesSection
            }
        }.navigationTitle("槽位草稿")
            .alert("无法应用更改", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
    private var personalityPicker: some View {
        Picker("性格", selection: $slot.personalityID) {
            Text("无修正").tag(nil as Int?)
            if let id = slot.personalityID, content.personalities[PersonalityID(rawValue: id)] == nil {
                Text("无法解析 #\(id) · 保留").tag(Optional(id))
            }
            ForEach(content.personalities.values.sorted { $0.personalityId.rawValue < $1.personalityId.rawValue }, id: \.personalityId) {
                Text($0.nameZh).tag(Optional($0.personalityId.rawValue))
            }
        }
    }
    private func legacyPicker(_ pet: Pet) -> some View {
        let ids = TeamRules.legacyOptions(pet, content: content)
        return Picker("血脉", selection: Binding<Int?>(get: { slot.legacyTypeID }, set: { value in
            guard let value, value != slot.legacyTypeID else { return }
            do { slot = try TeamRules.changeLegacy(slot, to: value, content: content) }
            catch { self.error = String(describing: error) }
        })) {
            if let current = slot.legacyTypeID, !ids.contains(TypeID(rawValue: current)) {
                Text("无法解析 #\(current) · 保留").tag(Optional(current))
            }
            ForEach(ids, id: \.self) { id in
                if let type = content.types[id] { Text(type.nameZh).tag(Optional(id.rawValue)) }
            }
        }
    }
    private var individualSection: some View {
        Section("个体值 · 最多 3 项大于 0") {
            ForEach(BattleStat.allCases, id: \.self) { stat in
                Stepper("\(stat.label)：\(slot.individualValues[stat.rawValue])", value: Binding(get: {
                    slot.individualValues[stat.rawValue]
                }, set: { value in
                    var values = slot.individualValues; values[stat.rawValue] = value
                    do { try TeamRules.validateIndividuals(values); slot.individualValues = values }
                    catch { self.error = String(describing: error) }
                }), in: 0...10)
            }
        }
    }
    @ViewBuilder private func statsSection(_ pet: Pet) -> some View {
        Section("六维") {
            switch calculatedStats(pet) {
            case .success(let values):
                ForEach(BattleStat.allCases, id: \.self) { LabeledContent($0.label, value: String(values[$0.rawValue])) }
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
    private func calculatedStats(_ pet: Pet) -> Result<[Int], Error> {
        Result {
            let personality = slot.personalityID.flatMap { content.personalities[PersonalityID(rawValue: $0)] }
            if slot.personalityID != nil && personality == nil { throw ContentError.invalid("性格 ID 无法解析，不能计算六维") }
            return try BattleStatsCalculator.calculate(pet: pet, individuals: slot.individualValues, personality: personality)
        }
    }
    @ViewBuilder private var movesSection: some View {
        Section("技能 · \(slot.skillIDs.count) / 4") {
            ForEach(slot.skillIDs, id: \.self) { id in
                Button("移除：\(content.skills[SkillID(rawValue: id)]?.nameZh ?? "无法解析 #\(id) · 保留")", role: .destructive) {
                    slot.skillIDs.removeAll { $0 == id }
                }
            }
            Button("使用推荐技能（替换当前选择）") {
                do { slot.skillIDs = try TeamRules.recommended(slot, content: content) }
                catch { self.error = String(describing: error) }
            }
            switch Result(catching: { try TeamRules.options(slot, content: content) }) {
            case .success(let options):
                ForEach(options, id: \.skill.skillId) { option in
                    Button {
                        do { slot = try TeamRules.toggleSkill(option.skill.skillId.rawValue, slot: slot, content: content) }
                        catch { self.error = String(describing: error) }
                    } label: {
                        VStack(alignment: .leading) {
                            Label(option.skill.nameZh, systemImage: slot.skillIDs.contains(option.skill.skillId.rawValue) ? "checkmark.circle.fill" : "circle")
                            Text("\(option.source.rawValue) · 推荐分 \(option.score.formatted())").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            case .failure(let error): Text(String(describing: error)).foregroundStyle(.red)
            }
        }
    }
}

private struct TeamPetPicker: View {
    @Binding var slot: TeamSlot
    let content: ContentStore
    @State private var query = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    private var candidates: [Pet] {
        content.orderedPets.filter {
            $0.implemented && $0.publicVisible && !$0.isLeader &&
                (query.isEmpty || "\($0.nameZh) \($0.petId.rawValue) \($0.searchAliases.joined(separator: " "))".localizedStandardContains(query))
        }
    }
    var body: some View {
        List(candidates, id: \.petId) { pet in
            Button(pet.nameZh) {
                do { slot = try TeamRules.assign(pet, content: content); dismiss() }
                catch { self.error = String(describing: error) }
            }
        }.navigationTitle("选择精灵").searchable(text: $query)
            .alert("无法选取", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}
