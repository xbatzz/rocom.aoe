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
}
