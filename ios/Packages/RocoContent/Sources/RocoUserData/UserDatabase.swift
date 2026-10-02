import Foundation
import SwiftData

@Model public final class ShinyRecord {
    @Attribute(.unique) public var slotID: String
    public var collected: Bool
    public var updatedAt: Date
    public init(slotID: String, collected: Bool) {
        self.slotID = slotID
        self.collected = collected
        updatedAt = .now
    }
}

public enum UserDatabase {
    @MainActor public static func open(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([ShinyRecord.self])
        let config = ModelConfiguration("RocoUserData", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        container.mainContext.autosaveEnabled = false
        return container
    }

    @MainActor public static func toggleShiny(_ slot: String, context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<ShinyRecord>(predicate: #Predicate { $0.slotID == slot })).first
        if let existing { existing.collected.toggle(); existing.updatedAt = .now }
        else { context.insert(ShinyRecord(slotID: slot, collected: true)) }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
