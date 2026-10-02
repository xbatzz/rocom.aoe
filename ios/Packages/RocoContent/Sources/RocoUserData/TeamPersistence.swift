import Foundation
import SwiftData
import RocoContent

/// Value snapshot preserves unresolved IDs; failed decode never overwrites its source bytes.
@Model public final class TeamRecord {
    @Attribute(.unique) public var teamID: UUID
    public var dataVersion: Int = 1
    public var name: String
    public var payload: Data
    public var updatedAt: Date
    public init(build: TeamBuild) throws {
        try build.validate()
        teamID = build.id; name = build.name
        payload = try JSONEncoder().encode(build); updatedAt = .now
    }
    public func decode() throws -> TeamBuild {
        try UserDatabase.validateVersion(dataVersion)
        let build = try JSONDecoder().decode(TeamBuild.self, from: payload)
        try build.validate()
        guard build.id == teamID else { throw ContentError.invalid("队伍 ID 与存储记录不一致") }
        return build
    }
}

extension UserDatabase {
    @MainActor public static func saveTeam(_ build: TeamBuild, context: ModelContext) throws {
        try build.validate()
        let id = build.id
        let existing = try context.fetch(FetchDescriptor<TeamRecord>(predicate: #Predicate { $0.teamID == id })).first
        let bytes = try JSONEncoder().encode(build)
        if let existing {
            try validateVersion(existing.dataVersion)
            existing.name = build.name; existing.payload = bytes; existing.updatedAt = .now
        } else {
            guard try context.fetchCount(FetchDescriptor<TeamRecord>()) < 10 else { throw ContentError.invalid("最多 10 支队伍") }
            context.insert(try TeamRecord(build: build))
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}

extension UserDatabase {
    @MainActor public static func duplicateTeam(_ record: TeamRecord, context: ModelContext) throws {
        var build = try record.decode()
        build.id = UUID()
        build.name = String((build.name + " 副本").prefix(32))
        try saveTeam(build, context: context)
    }

    @MainActor public static func deleteTeam(_ record: TeamRecord, context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<TeamRecord>()) > 1 else {
            throw ContentError.invalid("至少保留一支队伍")
        }
        context.delete(record)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
