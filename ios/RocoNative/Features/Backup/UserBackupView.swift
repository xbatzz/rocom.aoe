import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import RocoContent
import RocoUserData

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw BackupError.invalid("无法读取 JSON 文件") }
        self.bytes = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}

struct UserBackupView: View {
    let content: ContentStore
    @Query private var shiny: [ShinyRecord]
    @Query private var grass: [GrassRecord]
    @Query private var heroes: [HeroRecord]
    @Query private var teams: [TeamRecord]
    @Environment(\.modelContext) private var context
    @State private var document: BackupDocument?
    @State private var shareURL: URL?
    @State private var exporting = false
    @State private var importing = false
    @State private var prepared: PreparedBackup?
    @State private var mode = BackupImportMode.merge
    @State private var error: String?
    @State private var status: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("带上你的收藏与队伍").font(.title2.bold())
                    Text("将本机进度保存到文件，在需要时恢复。").font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 20)], alignment: .leading, spacing: 20) {
                        CompanionMetric(value: String(shiny.count), label: "异色记录", tint: .purple)
                        CompanionMetric(value: String(grass.count), label: "地点足迹记录", tint: .green)
                        CompanionMetric(value: String(heroes.count), label: "命定勇者记录", tint: .orange)
                        CompanionMetric(value: String(teams.count), label: "保存队伍")
                    }
                }.padding(20).companionSurface()
            CompanionSection("备份到 JSON 文件") {
                Button("生成当前备份", systemImage: "square.and.arrow.up") { generate() }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(.primary)
                if document != nil { Button("保存到文件") { exporting = true } }
                if let shareURL { ShareLink("分享备份", item: shareURL) }
                Text("包括异色、各地点草系足迹、命定勇者、全部队伍和保留的 Web 原始归档。备份包含导出时间、格式版本与稳定 ID。").font(.footnote).foregroundStyle(.secondary)
            }
            CompanionSection("从文件恢复") {
                Button("选择 JSON 文件", systemImage: "folder") { importing = true }
                    .buttonStyle(.bordered).controlSize(.large).tint(.primary)
                if let prepared {
                    preview(prepared)
                    Picker("导入方式", selection: $mode) {
                        Text("合并").tag(BackupImportMode.merge)
                        Text("全量替换").tag(BackupImportMode.replace)
                    }.pickerStyle(.segmented)
                    Text(mode == .replace ? "将以文件中的全部记录替换当前用户数据，包括保留的 Web 归档。" : "保留双方记录；同 ID 较新时间胜出。时间相同：异色/命定取消优先，草系未记录优先，其次未点亮；队伍保留本机版本。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(mode == .replace ? "确认全量替换" : "确认合并", role: mode == .replace ? .destructive : nil) {
                        do {
                            try BackupPersistence.restore(prepared.backup, mode: mode, context: context)
                            status = "导入成功；所有写入已提交。"
                            self.prepared = nil; document = nil
                            removeShareFile()
                        } catch { self.error = String(describing: error) }
                    }
                    Button("取消导入", role: .cancel) { self.prepared = nil }
                }
            }
            if let status { Label(status, systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(.green) }
            }.padding(20)
        }.reviewScrollPosition().companionBackground().navigationTitle("备份与恢复")
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "rocom-native-user-data") {
                switch $0 { case .success: status = "备份文件已保存。"; case .failure(let error): self.error = String(describing: error) }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                do {
                    let urls = try result.get()
                    guard let url = urls.first else { throw BackupError.invalid("未选择文件") }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    self.prepared = try BackupCodec.prepare(data, content: content)
                    mode = .merge; status = nil
                } catch { prepared = nil; self.error = String(describing: error) }
            }
            .alert("操作失败 · 原数据保留", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
            .onDisappear { removeShareFile() }
    }
    private func preview(_ prepared: PreparedBackup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文件已完整解析，尚未修改本机数据。").font(.headline)
            Text("异色 \(prepared.backup.shiny.count) · 足迹 \(prepared.backup.grass.count) · 命定 \(prepared.backup.heroes.count) · 队伍 \(prepared.backup.teams.count)")
            ForEach(prepared.warnings.indices, id: \.self) { Text(prepared.warnings[$0]).foregroundStyle(.secondary) }
        }
    }
    private func generate() {
        do {
            let bytes = try BackupCodec.encode(BackupPersistence.export(context: context))
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rocom-backup-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("rocom-native-user-data.json")
            try bytes.write(to: url, options: .atomic)
            removeShareFile()
            document = BackupDocument(bytes: bytes); shareURL = url; status = "备份快照已生成，可保存或分享。"
        } catch { self.error = String(describing: error) }
    }
    private func removeShareFile() {
        guard let url = shareURL else { return }
        do { try FileManager.default.removeItem(at: url.deletingLastPathComponent()); shareURL = nil }
        catch { self.error = "临时分享文件未能清理：\(error)" }
    }
}
