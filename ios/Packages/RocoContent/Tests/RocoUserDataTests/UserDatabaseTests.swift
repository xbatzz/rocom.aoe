import RocoContent
import Foundation
import Testing
import SwiftData
@testable import RocoUserData

@MainActor struct UserDatabaseTests {
    @Test func stableSlotsAndToggle() throws {
        let container = try UserDatabase.open(inMemory: true)
        let context = container.mainContext
        try UserDatabase.toggleShiny("s0-route-a", context: context)
        try UserDatabase.toggleShiny("s1-route-a", context: context)
        try UserDatabase.toggleShiny("s0-route-b", context: context)
        try UserDatabase.toggleShiny("s0-route-a", context: context)
        let rows = try context.fetch(FetchDescriptor<ShinyRecord>())
        #expect(rows.count == 3)
        #expect(rows.filter(\.collected).count == 2)
        #expect(rows.first { $0.slotID == "s0-route-a" }?.collected == false)
    }
    @Test func independentGrassLocationsAndThreeStates() throws {
        let container = try UserDatabase.open(inMemory: true)
        let context = container.mainContext
        try UserDatabase.cycleGrass(footprint: "pet:3001", location: "somia", context: context)
        try UserDatabase.cycleGrass(footprint: "pet:3001", location: "stonehenge", context: context)
        try UserDatabase.cycleGrass(footprint: "pet:3001", location: "somia", context: context)
        var rows = try context.fetch(FetchDescriptor<GrassRecord>())
        #expect(rows.first { $0.locationID == "somia" }?.status == .unlit)
        #expect(rows.first { $0.locationID == "stonehenge" }?.status == .lit)
        try UserDatabase.cycleGrass(footprint: "pet:3001", location: "somia", context: context)
        rows = try context.fetch(FetchDescriptor<GrassRecord>())
        #expect(rows.first { $0.locationID == "somia" }?.status == .unrecorded)
        #expect(try context.fetchCount(FetchDescriptor<ShinyRecord>()) == 0)
    }

    @Test func heroNeverDerivesGrassOrShiny() throws {
        let container = try UserDatabase.open(inMemory: true)
        let context = container.mainContext
        try UserDatabase.toggleHero("species:1", context: context)
        try UserDatabase.cycleGrass(footprint: "pet:3004", location: "somia", context: context)
        try UserDatabase.toggleHero("species:1", context: context)
        #expect(try context.fetch(FetchDescriptor<HeroRecord>()).first?.obtained == false)
        #expect(try context.fetch(FetchDescriptor<GrassRecord>()).first?.status == .lit)
        #expect(try context.fetchCount(FetchDescriptor<ShinyRecord>()) == 0)
    }

    @Test func diskReopenAndVersionBoundary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("tracking.store")
        func write() throws {
            let container = try UserDatabase.open(url: url)
            try UserDatabase.toggleShiny("s0-f1-e1", context: container.mainContext)
            try UserDatabase.cycleGrass(footprint: "pet:1", location: "somia", context: container.mainContext)
            try UserDatabase.toggleHero("species:1", context: container.mainContext)
        }
        try write()
        let reopened = try UserDatabase.open(url: url)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<ShinyRecord>()).first?.collected == true)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<GrassRecord>()).first?.status == .lit)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<HeroRecord>()).first?.obtained == true)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<UserDataMetadata>()).first?.dataVersion == 1)
        #expect(throws: UserDataError.self) { try UserDatabase.validateVersion(2) }
    }

    @Test func teamRoundTripUnresolvedAndDraftIsolation() throws {
        let container = try UserDatabase.open(inMemory: true)
        var build = TeamBuild()
        build.slots[0].petID = 999999
        build.slots[0].skillIDs = [999998]
        build.magicItemID = 999997
        try UserDatabase.saveTeam(build, context: container.mainContext)
        let row = try #require(container.mainContext.fetch(FetchDescriptor<TeamRecord>()).first)
        var draft = try row.decode()
        draft.name = "Unsaved draft"
        #expect(try row.decode() == build)
        try UserDatabase.saveTeam(draft, context: container.mainContext)
        #expect(try row.decode().slots[0].skillIDs == [999998])
        #expect(try row.decode().magicItemID == 999997)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<HeroRecord>()) == 0)
    }

}
