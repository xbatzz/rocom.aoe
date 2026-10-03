import Foundation
import SwiftData

public enum AppAppearance: String, Codable, CaseIterable, Sendable {
    case system, light, dark
    public var label: String { switch self { case .system: "跟随系统"; case .light: "浅色"; case .dark: "深色" } }
}

@Model public final class UserPreferences {
    @Attribute(.unique) public var identity: String = "preferences"
    public var activeTeamID: UUID?
    public var activeTeamUpdatedAt: Date = Date(timeIntervalSince1970: 0)
    public var appearanceRaw: String = "system"
    public var appearanceUpdatedAt: Date = Date(timeIntervalSince1970: 0)
    public var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }
    public init() {}
}

extension UserDatabase {
    @MainActor public static func preferences(context: ModelContext) throws -> UserPreferences {
        if let row = try context.fetch(FetchDescriptor<UserPreferences>()).first { return row }
        let row = UserPreferences(); context.insert(row); return row
    }
    @MainActor public static func setActiveTeam(_ id: UUID, context: ModelContext) throws {
        guard try context.fetch(FetchDescriptor<TeamRecord>()).contains(where: { $0.teamID == id }) else { throw UserDataError.missingTeam }
        let row = try preferences(context: context)
        row.activeTeamID = id; row.activeTeamUpdatedAt = nextTimestamp(after: row.activeTeamUpdatedAt)
        do { try context.save() } catch { context.rollback(); throw error }
    }
    @MainActor public static func setAppearance(_ appearance: AppAppearance, context: ModelContext) throws {
        let row = try preferences(context: context)
        row.appearanceRaw = appearance.rawValue; row.appearanceUpdatedAt = nextTimestamp(after: row.appearanceUpdatedAt)
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
