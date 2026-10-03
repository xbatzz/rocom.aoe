import Foundation
import SwiftData
import Testing
import RocoContent
@testable import RocoUserData

@MainActor struct SelectedPersistenceTests {
    @Test func activeTeamMedalsThemeUndoAndTransactionalRoundTrip() throws {
        let source = try UserDatabase.open(inMemory: true), target = try UserDatabase.open(inMemory: true)
        let context = source.mainContext
        var first = TeamBuild(); first.name = "First"
        var second = TeamBuild(); second.name = "Second"
        try UserDatabase.saveTeam(first, context: context); try UserDatabase.saveTeam(second, context: context)
        #expect(try UserDatabase.preferences(context: context).activeTeamID == first.id)
        try UserDatabase.setActiveTeam(second.id, context: context)
        first.name = "Edit first"; try UserDatabase.saveTeam(first, context: context)
        #expect(try UserDatabase.preferences(context: context).activeTeamID == second.id)
        try UserDatabase.setAppearance(.dark, context: context)
        try UserDatabase.toggleGrassMedal("species:1", context: context)
        #expect(try context.fetchCount(FetchDescriptor<HeroRecord>()) == 0)
        try UserDatabase.setGrass(.unlit, footprint: "pet:1", location: "somia", context: context)
        try UserDatabase.setGrass(.lit, footprint: "pet:1", location: "plata", context: context)
        try UserDatabase.setGrass(.unrecorded, footprint: "pet:1", location: "somia", context: context)
        try UserDatabase.toggleShiny("s4-f1-e1", context: context)
        let before = try #require(context.fetch(FetchDescriptor<ShinyRecord>()).first?.updatedAt)
        try UserDatabase.setShiny(false, slot: "s4-f1-e1", context: context)
        #expect(try context.fetch(FetchDescriptor<ShinyRecord>()).first?.updatedAt ?? .distantPast > before)
        let backup = try BackupPersistence.export(context: context)
        #expect(backup.schemaVersion == 2)
        try BackupPersistence.restore(backup, mode: .replace, context: target.mainContext)
        let copied = try BackupPersistence.export(context: target.mainContext)
        #expect(copied.preferences?.activeTeamID == second.id && copied.preferences?.appearance == .dark)
        #expect(copied.grassMedals?.first?.obtained == true)
        #expect(copied.grass.contains { $0.locationID == "somia" && $0.status == .unrecorded })
        let record = try #require(context.fetch(FetchDescriptor<TeamRecord>()).first { $0.teamID == second.id })
        try UserDatabase.deleteTeam(record, context: context)
        #expect(try UserDatabase.preferences(context: context).activeTeamID == first.id)
        enum Injected: Error { case fail }
        var replace = backup; replace.preferences?.appearance = .light; replace.grassMedals?[0].obtained = false
        #expect(throws: Injected.self) { try BackupPersistence.apply(replace, mode: .replace, context: context) { throw Injected.fail } }
        #expect(try UserDatabase.preferences(context: context).appearance == .dark)
        #expect(try context.fetch(FetchDescriptor<GrassFamilyMedalRecord>()).first?.obtained == true)
        #expect(!context.hasChanges)
    }
    @Test func versionFiveActivatesNewStatesAndPreservesUnselectedWebFields() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let content = try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var backup = UserBackup(grassMedals: [.init(familyID: "species:1", obtained: true, updatedAt: date)])
        backup.preferences = .init(activeTeamID: nil, activeTeamUpdatedAt: date, appearance: .light, appearanceUpdatedAt: date)
        let native = try JSONSerialization.jsonObject(with: BackupCodec.encode(backup))
        let web: [String: Any] = ["format": "rocom-user-data", "version": 5, "exportedAt": "2026-10-03T00:00:00Z", "native": native, "data": ["handbookProgress": ["unknown": ["keep": true]], "extraUserField": [1,2,3]]]
        let prepared = try BackupCodec.prepare(JSONSerialization.data(withJSONObject: web), content: content)
        #expect(prepared.backup.grassMedals?.first?.obtained == true && prepared.backup.preferences?.appearance == .light)
        let archive = try #require(prepared.backup.legacyArchives.first)
        #expect(archive.originalJSON.contains("extraUserField") && archive.originalJSON.contains("handbookProgress"))
        var old = backup; old.schemaVersion = 1; old.preferences = nil; old.grassMedals = nil
        #expect(try BackupCodec.prepare(BackupCodec.encode(old), content: content).backup.schemaVersion == 1)
        var future = backup; future.schemaVersion = 3
        #expect(throws: BackupError.self) { try BackupCodec.encode(future) }
    }
    @Test func additiveSchemaKeepsExistingDatabase() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("user.store")
        func seedOldSchema() throws {
            let old = Schema([ShinyRecord.self, GrassRecord.self, HeroRecord.self, UserDataMetadata.self, TeamRecord.self, LegacyArchiveRecord.self])
            let config = ModelConfiguration("RocoUserData", schema: old, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: old, configurations: [config])
            container.mainContext.insert(ShinyRecord(slotID: "s4-f1-e1", collected: true))
            container.mainContext.insert(try TeamRecord(build: TeamBuild()))
            container.mainContext.insert(UserDataMetadata())
            try container.mainContext.save()
        }
        try seedOldSchema()
        let upgraded = try UserDatabase.open(url: url)
        #expect(try upgraded.mainContext.fetchCount(FetchDescriptor<TeamRecord>()) == 1)
        #expect(try upgraded.mainContext.fetch(FetchDescriptor<ShinyRecord>()).first?.collected == true)
        try UserDatabase.setAppearance(.dark, context: upgraded.mainContext)
        try UserDatabase.toggleGrassMedal("species:1", context: upgraded.mainContext)
        #expect(try BackupPersistence.export(context: upgraded.mainContext).grassMedals?.first?.obtained == true)
    }
    @Test func actualWebFixtureRestoresAndExportsForWeb() throws {
        guard let directory = ProcessInfo.processInfo.environment["ROCO_PARITY_DIRECTORY"] else { return }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let content = try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))))
        let directoryURL = URL(fileURLWithPath: directory)
        let prepared = try BackupCodec.prepare(Data(contentsOf: directoryURL.appendingPathComponent("web-v5.json")), content: content)
        let target = try UserDatabase.open(inMemory: true)
        try BackupPersistence.restore(prepared.backup, mode: .replace, context: target.mainContext)
        let exported = try BackupPersistence.export(context: target.mainContext)
        #expect(exported.teams.first?.build.id.uuidString.lowercased() == "ba33f531-c820-56e8-b12f-1e1919f52a94")
        #expect(exported.preferences?.appearance == .dark)
        #expect(exported.grassMedals?.first?.obtained == true)
        #expect(exported.legacyArchives.contains { $0.originalJSON.contains("extraUserField") })
        try BackupCodec.encode(exported).write(to: directoryURL.appendingPathComponent("native-roundtrip.json"))
    }

}
