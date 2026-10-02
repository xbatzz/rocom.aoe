import Foundation
import RocoContent
import SwiftData

@Model public final class ShinyRecord {
    public var dataVersion: Int = 1
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
    public static let currentVersion = 1

    public static func validateVersion(_ version: Int) throws {
        guard version == currentVersion else { throw UserDataError.unsupportedVersion(version) }
    }
    @MainActor public static func open(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([ShinyRecord.self, GrassRecord.self, HeroRecord.self, UserDataMetadata.self, TeamRecord.self, LegacyArchiveRecord.self])
        let config: ModelConfiguration
        if let url {
            config = ModelConfiguration("RocoUserData", schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration("RocoUserData", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, configurations: [config])
        container.mainContext.autosaveEnabled = false
        let context = container.mainContext
        let metadata = try context.fetch(FetchDescriptor<UserDataMetadata>())
        if let row = metadata.first { try validateVersion(row.dataVersion) }
        else { context.insert(UserDataMetadata()); try save(context) }
        for row in try context.fetch(FetchDescriptor<ShinyRecord>()) { try validateVersion(row.dataVersion) }
        for row in try context.fetch(FetchDescriptor<GrassRecord>()) { try validateVersion(row.dataVersion) }
        for row in try context.fetch(FetchDescriptor<HeroRecord>()) { try validateVersion(row.dataVersion) }
        return container
    }

    /// Shared transaction boundary: failed writes never remain as apparently saved UI state.
    @MainActor private static func save(_ context: ModelContext) throws {
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    @MainActor public static func toggleShiny(_ slot: String, context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<ShinyRecord>(predicate: #Predicate { $0.slotID == slot })).first
        if let existing { existing.collected.toggle(); existing.updatedAt = .now }
        else { context.insert(ShinyRecord(slotID: slot, collected: true)) }
        try save(context)
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
    public var dataVersion: Int = 1
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
        try save(context)
    }
}

@Model public final class HeroRecord {
    public var dataVersion: Int = 1
    @Attribute(.unique) public var familyID: String
    public var obtained: Bool
    public var updatedAt: Date
    public init(familyID: String, obtained: Bool) {
        self.familyID = familyID; self.obtained = obtained; updatedAt = .now
    }
}

extension UserDatabase {
    @MainActor public static func toggleHero(_ family: String, context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<HeroRecord>(predicate: #Predicate { $0.familyID == family })).first
        if let existing { existing.obtained.toggle(); existing.updatedAt = .now }
        else { context.insert(HeroRecord(familyID: family, obtained: true)) }
        try save(context)
    }
}

public enum UserDataError: Error {
    case unsupportedVersion(Int)
}

/// Data-format boundary for future backup/import. Unknown versions fail; no destructive reset.
@Model public final class UserDataMetadata {
    @Attribute(.unique) public var identity: String = "roco-user-data"
    public var dataVersion: Int = 1
    public init() {}
}
