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
        let schema = Schema([ShinyRecord.self, GrassRecord.self])
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

public enum BadgeState: String, Codable, CaseIterable, Sendable {
    case unrecorded, lit, unlit
    public var next: BadgeState {
        switch self { case .unrecorded: .lit; case .lit: .unlit; case .unlit: .unrecorded }
    }
    public var label: String {
        switch self { case .unrecorded: "未记录"; case .lit: "已点亮"; case .unlit: "未点亮" }
    }
}

@Model public final class GrassRecord {
    @Attribute(.unique) public var identity: String
    public var footprintID: String
    public var locationID: String
    public var status: BadgeState
    public var updatedAt: Date
    public init(footprintID: String, locationID: String, status: BadgeState) {
        identity = Self.key(footprintID, locationID)
        self.footprintID = footprintID; self.locationID = locationID; self.status = status
        updatedAt = .now
    }
    public static func key(_ footprint: String, _ location: String) -> String { "grass|\(location)|\(footprint)" }
}

extension UserDatabase {
    @MainActor public static func cycleGrass(footprint: String, location: String, context: ModelContext) throws {
        let key = GrassRecord.key(footprint, location)
        let existing = try context.fetch(FetchDescriptor<GrassRecord>(predicate: #Predicate { $0.identity == key })).first
        if let existing { existing.status = existing.status.next; existing.updatedAt = .now }
        else { context.insert(GrassRecord(footprintID: footprint, locationID: location, status: .lit)) }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
