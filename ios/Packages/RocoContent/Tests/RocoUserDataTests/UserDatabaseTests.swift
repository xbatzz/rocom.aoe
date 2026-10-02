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

}
