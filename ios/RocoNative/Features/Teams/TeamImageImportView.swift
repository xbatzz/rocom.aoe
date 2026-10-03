import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import Vision
import ImageIO
import RocoContent
import RocoDomain
import RocoUserData

/// Fixed game configuration layout, matching the Web import crop coordinates.
struct TeamImageImportView: View {
    let content: ContentStore
    let portraits: PortraitStore
    let skillIndex: SkillSearchIndex
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var filePicker = false
    @State private var busy = false
    @State private var image: UIImage?
    @State private var draft: TeamBuild?
    @State private var warnings: [String] = []
    @State private var raw: [String] = []
    @State private var confirmed = Set<Int>()
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section("游戏队伍配置截图") {
                    Text("使用完整的两列三行配置图片（约 1625 × 747）。图片仅在本机处理；识别结果可以逐项修正。").font(.subheadline)
                    PhotosPicker("从照片选择", selection: $photo, matching: .images).disabled(busy)
                    Button("从文件选择图片") { filePicker = true }.disabled(busy)
                    if busy { ProgressView("正在识别六个槽位…") }
                    if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("导入的原始队伍图片") }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                if let current = draft {
                    Section("确认新队伍") {
                        TextField("名称", text: Binding(get: { draft?.name ?? "" }, set: { draft?.name = $0 }))
                        ForEach(0..<6, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 8) {
                                NavigationLink {
                                    TeamSlotView(slot: Binding(get: { draft?.slots[i] ?? TeamSlot() }, set: { draft?.slots[i] = $0; confirmed.remove(i) }), content: content, portraits: portraits, skillIndex: skillIndex, usedSlots: current.slots)
                                } label: {
                                    Text("槽位 \(i + 1) · " + (current.slots[i].petID.flatMap { content.pets[PetID(rawValue: $0)]?.nameZh } ?? "未确认精灵"))
                                }
                                if raw.indices.contains(i) { Text(raw[i]).font(.caption).foregroundStyle(.secondary) }
                                Toggle("已核对槽位 \(i + 1)（包括空槽）", isOn: Binding(get: { confirmed.contains(i) }, set: { if $0 { confirmed.insert(i) } else { confirmed.remove(i) } }))
                            }
                        }
                        Button("确认并创建新队伍") {
                            do { try UserDatabase.saveTeam(current, context: context); dismiss() } catch { self.error = String(describing: error) }
                        }.disabled(confirmed.count != 6 || busy)
                    }
                    Section("识别提示") { ForEach(Array(warnings.enumerated()), id: \.offset) { Text($0.element).font(.subheadline) } }
                }
            }.navigationTitle("图片识别导入")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(busy) } }
                .fileImporter(isPresented: $filePicker, allowedContentTypes: [.image]) { result in
                    Task {
                        do {
                            let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20 * 1024 * 1024 else { throw ContentError.invalid("图片须小于 20 MB") }
                            await recognize(try Data(contentsOf: url))
                        } catch { self.error = String(describing: error) }
                    }
                }
                .onChange(of: photo) { _, item in
                    Task { do { if let data = try await item?.loadTransferable(type: Data.self) { await recognize(data) } } catch { self.error = String(describing: error) } }
                }
        }.interactiveDismissDisabled(busy)
    }
    private func recognize(_ data: Data) async {
        busy = true; error = nil; draft = nil; confirmed.removeAll()
        defer { busy = false }
        do {
            guard data.count <= 20 * 1024 * 1024 else { throw ContentError.invalid("图片超过 20 MB") }
            let cg = try await TeamImageOCR.decode(data)
            image = UIImage(cgImage: cg)
            let templates = TypeMatchup(types: content.types).selectable.compactMap { type in
                GameIconCatalog.type(type.typeId)?.cgImage.map { (type.typeId.rawValue, $0) }
            }
            let result = try await TeamImageOCR.read(cg, templates: templates)
            raw = result.slots.map { $0.text.joined(separator: " · ") }
            var team = TeamBuild(); team.name = result.name.isEmpty ? "图片导入队伍" : String(result.name.prefix(32))
            warnings = []
            let labels = ["生命", "物攻", "魔攻", "物防", "魔防", "速度"]
            for (i, detected) in result.slots.enumerated() {
                let name = detected.text[0]
                let candidates = content.orderedPets.filter { $0.implemented && $0.publicVisible && !$0.isLeader && Self.normalize($0.nameZh) == Self.normalize(name) }
                var slot = TeamSlot()
                if candidates.count == 1, let pet = candidates.first {
                    slot.petID = pet.petId.rawValue
                    let allowed = TeamRules.legacyOptions(pet, content: content)
                    if let legacy = detected.typeID, allowed.contains(TypeID(rawValue: legacy)) { slot.legacyTypeID = legacy }
                    else { warnings.append("槽位 \(i + 1)：血脉图标无法可靠匹配，请手动选择。") }
                    let natureText = detected.text[1]
                    let nature = content.personalities.values.first { Self.normalize(natureText).contains(Self.normalize($0.nameZh)) }
                    if let nature { slot.personalityID = nature.personalityId.rawValue }
                    else {
                        let ordered = labels.enumerated().compactMap { index, label in natureText.range(of: label).map { (index, $0.lowerBound) } }.sorted { $0.1 < $1.1 }
                        if ordered.count == 2 {
                            slot.personalityID = content.personalities.values.sorted { $0.personalityId.rawValue < $1.personalityId.rawValue }.first { p in
                                let values = [p.modifiers.hp.rawValue, p.modifiers.physicalAttack.rawValue, p.modifiers.magicalAttack.rawValue, p.modifiers.physicalDefense.rawValue, p.modifiers.magicalDefense.rawValue, p.modifiers.speed.rawValue]
                                return values[ordered[0].0] > 0 && values[ordered[1].0] < 0
                            }?.personalityId.rawValue
                        }
                    }
                    let ivText = detected.text[2]
                    let stats = labels.enumerated().filter { ivText.contains($0.element) }
                    if stats.count <= 3 { for stat in stats { slot.individualValues[stat.offset] = 10 } }
                    let options = (try? TeamRules.options(slot, content: content)) ?? []
                    for text in detected.text.dropFirst(3) {
                        let moves = options.filter { Self.normalize($0.skill.nameZh) == Self.normalize(text) }
                        if moves.count == 1, let id = moves.first?.skill.skillId.rawValue, !slot.skillIDs.contains(id) { slot.skillIDs.append(id) }
                        else if !text.isEmpty { warnings.append("槽位 \(i + 1)：技能「\(text)」需核对，未自动填入。") }
                    }
                } else { warnings.append("槽位 \(i + 1)：精灵「\(name)」存在歧义或未匹配，请手动选取。") }
                if slot.personalityID == nil { warnings.append("槽位 \(i + 1)：性格未确认。") }
                warnings.append("槽位 \(i + 1)：请核对个体值及四个技能；OCR 不保证识别完整。")
                team.slots[i] = slot
            }
            draft = team
        } catch { self.error = String(describing: error) }
    }
    private static func normalize(_ text: String) -> String { text.filter { !$0.isWhitespace && !$0.isPunctuation } }
}

nonisolated enum TeamImageOCR {
    struct Slot: Sendable { let text: [String]; let typeID: Int? }
    struct Result: Sendable { let name: String; let slots: [Slot] }
    @concurrent static func decode(_ data: Data) async throws -> CGImage {
        // ImageIO downsamples and applies EXIF orientation off the UI actor; avoid full-size photo bitmaps.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1625,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary) else { throw ContentError.invalid("图片解码失败") }
        try Task.checkCancellation()
        return image
    }
    @concurrent static func read(_ image: CGImage, templates: [(Int, CGImage)]) async throws -> Result {
        let ratio = Double(image.width) / Double(image.height)
        guard image.width >= 800, image.height >= 350, abs(ratio - 1625.0 / 747) < 0.18 else { throw ContentError.invalid("请使用完整两列三行的队伍配置截图，避免裁边或拼接。") }
        func crop(_ x: Double, _ y: Double, _ width: Double, _ height: Double) throws -> CGImage {
            let sx = Double(image.width) / 1625, sy = Double(image.height) / 747
            guard let cropped = image.cropping(to: CGRect(x: x * sx, y: y * sy, width: width * sx, height: height * sy)) else { throw ContentError.invalid("截图区域读取失败") }; return cropped
        }
        func text(_ x: Double, _ y: Double, _ width: Double, _ height: Double) throws -> String {
            try Task.checkCancellation()
            let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.recognitionLanguages = ["zh-Hans", "en-US"]; request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: crop(x, y, width, height)).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined()
        }
        func pixels(_ cg: CGImage) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 24 * 24 * 4)
            bytes.withUnsafeMutableBytes { storage in
                if let context = CGContext(data: storage.baseAddress, width: 24, height: 24, bitsPerComponent: 8, bytesPerRow: 96, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    context.draw(cg, in: CGRect(x: 0, y: 0, width: 24, height: 24))
                }
            }; return bytes
        }
        let icons = templates.map { ($0.0, pixels($0.1)) }
        var slots: [Slot] = []
        for top in [22.0, 270, 518] {
            for (x, iconX) in [(334.0, 623.0), (970.0, 1259.0)] {
                var fields = try [text(x, top, 190, 43), text(x + 178, top + 50, 152, 39), text(x + 178, top + 89, 152, 39)]
                for offset in [0.0, 85, 169, 254] { fields.append(try text(x + offset, top + 177, 78, 30)) }
                let target = pixels(try crop(iconX, top + 3, 37, 37))
                let ranked = icons.map { id, bytes in
                    var difference = 0.0
                    for i in stride(from: 0, to: bytes.count, by: 4) {
                        for channel in 0..<3 { difference += abs(Double(bytes[i + channel]) - Double(target[i + channel])) }
                    }
                    let error = difference / Double(24 * 24 * 3 * 255)
                    return (id, error)
                }.sorted { $0.1 < $1.1 }
                let best = ranked.first
                let reliable = best.map { $0.1 < 0.3 && (ranked.count < 2 || ranked[1].1 - $0.1 > 0.025) } ?? false
                slots.append(Slot(text: fields, typeID: reliable ? best?.0 : nil))
            }
        }
        return Result(name: try text(1380, 518, 220, 55), slots: slots)
    }
}
