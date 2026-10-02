import Foundation
import Testing
import SwiftData
import RocoContent
@testable import RocoUserData

@MainActor struct BackupTests {
    private func content() throws -> ContentStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try ContentStore.load(bundle: #require(Bundle(url: root.appendingPathComponent("build/ios-content/store/ContentResources.bundle"))))
    }
    @Test func nativeRoundTripReplaceMergeAndNoTeamLimit() throws {
        let source = try UserDatabase.open(inMemory: true), target = try UserDatabase.open(inMemory: true)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var unknown = TeamBuild(); unknown.slots[0].petID = 999999; unknown.slots[0].skillIDs = [999998]
        var backup = UserBackup(exportedAt: date,
            shiny: [.init(slotID: "s99-f999-e999", collected: true, updatedAt: date)],
            grass: [.init(footprintID: "pet:999999", locationID: "somia", status: .lit, updatedAt: date)],
            heroes: [.init(familyID: "species:999999", obtained: true, updatedAt: date)],
            teams: [.init(build: unknown, updatedAt: date)])
        for _ in 0..<11 { backup.teams.append(.init(build: TeamBuild(), updatedAt: date)) }
        try BackupPersistence.restore(backup, mode: .replace, context: source.mainContext)
        #expect(try source.mainContext.fetchCount(FetchDescriptor<TeamRecord>()) == 12)
        let bytes = try BackupCodec.encode(BackupPersistence.export(context: source.mainContext))
        let parsed = try BackupCodec.prepare(bytes, content: content())
        try BackupPersistence.restore(parsed.backup, mode: .replace, context: target.mainContext)
        #expect(try target.mainContext.fetchCount(FetchDescriptor<TeamRecord>()) == 12)
        let row = try #require(target.mainContext.fetch(FetchDescriptor<TeamRecord>()).first { $0.teamID == unknown.id })
        #expect(try row.decode().slots[0].skillIDs == [999998])
        var merge = UserBackup(exportedAt: date)
        merge.shiny = [.init(slotID: "s99-f999-e999", collected: false, updatedAt: date)]
        merge.grass = [.init(footprintID: "pet:999999", locationID: "somia", status: .unrecorded, updatedAt: date)]
        merge.heroes = [.init(familyID: "species:999999", obtained: false, updatedAt: date)]
        var conflict = unknown; conflict.name = "Incoming tie"
        merge.teams = [.init(build: conflict, updatedAt: date)]
        try BackupPersistence.restore(merge, mode: .merge, context: target.mainContext)
        #expect(try target.mainContext.fetch(FetchDescriptor<ShinyRecord>()).first?.collected == false)
        #expect(try target.mainContext.fetch(FetchDescriptor<GrassRecord>()).first?.status == .unrecorded)
        #expect(try target.mainContext.fetch(FetchDescriptor<HeroRecord>()).first?.obtained == false)
        #expect(try row.decode().name == unknown.name)
        try BackupPersistence.restore(UserBackup(), mode: .replace, context: target.mainContext)
        #expect(try target.mainContext.fetchCount(FetchDescriptor<TeamRecord>()) == 0)
    }
    @Test func fullValidationAndMidWriteRollback() throws {
        let container = try UserDatabase.open(inMemory: true)
        let context = container.mainContext
        var existing = TeamBuild(); existing.name = "Keep"
        try UserDatabase.saveTeam(existing, context: context)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let row = UserBackup.Shiny(slotID: "s0-f1-e1", collected: true, updatedAt: date)
        var invalid = UserBackup(shiny: [row,row])
        #expect(throws: BackupError.self) { try BackupPersistence.restore(invalid, mode: .replace, context: context) }
        #expect(try context.fetchCount(FetchDescriptor<TeamRecord>()) == 1)
        invalid.shiny = [row]
        enum Injected: Error { case failure }
        #expect(throws: Injected.self) {
            try BackupPersistence.apply(invalid, mode: .replace, context: context) { throw Injected.failure }
        }
        #expect(try context.fetchCount(FetchDescriptor<ShinyRecord>()) == 0)
        #expect(try context.fetch(FetchDescriptor<TeamRecord>()).first?.decode().name == "Keep")
        #expect(!context.hasChanges)
        var object = try #require(JSONSerialization.jsonObject(with: BackupCodec.encode(UserBackup())) as? [String: Any])
        object["futureField"] = "never silently drop"
        let bytes = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: BackupError.self) { try BackupCodec.prepare(bytes, content: content()) }
        #expect(throws: (any Error).self) { try BackupCodec.prepare(Data("{bad".utf8), content: content()) }
    }
    @Test func legacyUnknownFieldsStableIDsAndExactArchive() throws {
        let bytes = Data("""
        {"format":"rocom-user-data","version":4,"exportedAt":"2026-10-03T00:00:00.000Z","data":{
          "teams":{"version":2,"activeTeamId":"old-id","teams":[{"id":"old-id","name":"Web team","createdAt":"2026-10-03T00:00:00.000Z","updatedAt":"2026-10-03T00:00:00.000Z","magicItemId":99999,"slots":[{"friendId":99999,"moveIds":[99998],"roles":["keep this"]}]}]},
          "handbookProgress":{"anything":"preserve"},"theme":"dark",
          "shinyCollection":{"version":2,"entries":{"s99:s99-f999-e999":{"collected":false,"updatedAt":"2026-10-03T00:00:00.000Z"}}},
          "badgeTrials":{"version":1,"updatedAt":"2026-10-03T00:00:00.000Z","trials":{
            "grass":{"familyMedals":{"species:1":"2026-10-03T00:00:00.000Z"},"footprints":{"somia":{"pet:99999":"2026-10-03T00:00:00.000Z"}},"unlitFootprints":{}},
            "destined-hero":{"familyMedals":{"species:99999":"2026-10-03T00:00:00.000Z"},"footprints":{},"unlitFootprints":{}}
          }},"extra":{"never":"drop"}}}
        """.utf8)
        let c = try content(), one = try BackupCodec.prepare(bytes, content: c), two = try BackupCodec.prepare(bytes, content: c)
        #expect(one.backup.teams[0].build.id == two.backup.teams[0].build.id)
        #expect(one.backup.teams[0].build.slots[0].petID == 99999)
        #expect(one.backup.shiny[0].collected == false)
        #expect(!one.warnings.isEmpty)
        #expect(one.backup.legacyArchives[0].originalJSON == String(data: bytes, encoding: .utf8))
        let container = try UserDatabase.open(inMemory: true)
        try BackupPersistence.restore(one.backup, mode: .merge, context: container.mainContext)
        try BackupPersistence.restore(two.backup, mode: .merge, context: container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TeamRecord>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<LegacyArchiveRecord>()) == 1)
        let roundTrip = try BackupCodec.prepare(BackupCodec.encode(BackupPersistence.export(context: container.mainContext)), content: c)
        #expect(roundTrip.backup.legacyArchives[0].originalJSON == one.backup.legacyArchives[0].originalJSON)
    }
}
