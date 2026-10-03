import Foundation
import SwiftData
import RocoContent

@Model public final class LegacyArchiveRecord {
    @Attribute(.unique) public var digest: String
    public var originalJSON: String
    public var receivedAt: Date
    public init(_ archive: UserBackup.Archive) {
        digest = archive.digest; originalJSON = archive.originalJSON; receivedAt = archive.receivedAt
    }
}

public enum BackupPersistence {
    @MainActor public static func export(context: ModelContext) throws -> UserBackup {
        guard !context.hasChanges else { throw BackupError.invalid("请先保存或回滚未提交的用户数据") }
        let shiny = try context.fetch(FetchDescriptor<ShinyRecord>()).map {
            try UserDatabase.validateVersion($0.dataVersion)
            return UserBackup.Shiny(slotID: $0.slotID, collected: $0.collected, updatedAt: $0.updatedAt)
        }.sorted { $0.slotID < $1.slotID }
        let grass = try context.fetch(FetchDescriptor<GrassRecord>()).map {
            try UserDatabase.validateVersion($0.dataVersion)
            guard $0.identity == GrassRecord.key($0.footprintID, $0.locationID) else { throw BackupError.invalid("草系记录 identity 与内容不一致，原数据保留") }
            return UserBackup.Grass(footprintID: $0.footprintID, locationID: $0.locationID, status: $0.status, updatedAt: $0.updatedAt)
        }.sorted { $0.key < $1.key }
        let heroes = try context.fetch(FetchDescriptor<HeroRecord>()).map {
            try UserDatabase.validateVersion($0.dataVersion)
            return UserBackup.Hero(familyID: $0.familyID, obtained: $0.obtained, updatedAt: $0.updatedAt)
        }.sorted { $0.familyID < $1.familyID }
        let teams = try context.fetch(FetchDescriptor<TeamRecord>()).map { UserBackup.Team(build: try $0.decode(), updatedAt: $0.updatedAt) }
            .sorted { $0.build.id.uuidString < $1.build.id.uuidString }
        let archives = try context.fetch(FetchDescriptor<LegacyArchiveRecord>()).map {
            UserBackup.Archive(digest: $0.digest, originalJSON: $0.originalJSON, receivedAt: $0.receivedAt)
        }.sorted { $0.digest < $1.digest }
        let medals = try context.fetch(FetchDescriptor<GrassFamilyMedalRecord>()).map {
            try UserDatabase.validateVersion($0.dataVersion)
            return UserBackup.Hero(familyID: $0.familyID, obtained: $0.obtained, updatedAt: $0.updatedAt)
        }.sorted { $0.familyID < $1.familyID }
        let p = try context.fetch(FetchDescriptor<UserPreferences>()).first
        let preferences = p.map { UserBackup.Preferences(activeTeamID: $0.activeTeamID, activeTeamUpdatedAt: $0.activeTeamUpdatedAt, appearance: $0.appearance, appearanceUpdatedAt: $0.appearanceUpdatedAt) }
        let backup = UserBackup(shiny: shiny, grass: grass, heroes: heroes, teams: teams, legacyArchives: archives, grassMedals: medals, preferences: preferences)
        try backup.validate()
        return backup
    }
    @MainActor public static func restore(_ backup: UserBackup, mode: BackupImportMode, context: ModelContext) throws {
        try apply(backup, mode: mode, context: context)
    }
    /// Internal pre-save hook enables a deterministic failure/rollback test.
    @MainActor static func apply(_ backup: UserBackup, mode: BackupImportMode, context: ModelContext, beforeSave: () throws -> Void = {}) throws {
        try backup.validate() // Entire snapshot validated before any mutation, including >10 teams.
        guard !context.hasChanges else { throw BackupError.invalid("用户数据库有未提交修改，不能导入") }
        do {
            try context.transaction {
                var shiny = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ShinyRecord>()).map { ($0.slotID, $0) })
                var grass = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<GrassRecord>()).map { ($0.identity, $0) })
                var heroes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<HeroRecord>()).map { ($0.familyID, $0) })
                var teams = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<TeamRecord>()).map { ($0.teamID, $0) })
                var archives = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<LegacyArchiveRecord>()).map { ($0.digest, $0) })
                var medals = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<GrassFamilyMedalRecord>()).map { ($0.familyID, $0) })
                for row in medals.values { try UserDatabase.validateVersion(row.dataVersion) }
                // Validate every existing row before replacement can remove any record.
                for row in shiny.values { try UserDatabase.validateVersion(row.dataVersion) }
                for row in grass.values {
                    try UserDatabase.validateVersion(row.dataVersion)
                    guard row.identity == GrassRecord.key(row.footprintID, row.locationID) else { throw BackupError.invalid("草系记录 identity 与内容不一致，原数据保留") }
                }
                for row in heroes.values { try UserDatabase.validateVersion(row.dataVersion) }
                for row in teams.values { try UserDatabase.validateVersion(row.dataVersion) }
                for row in try context.fetch(FetchDescriptor<UserDataMetadata>()) { try UserDatabase.validateVersion(row.dataVersion) }
                if mode == .replace {
                    let incomingShiny = Set(backup.shiny.map(\.slotID)), incomingGrass = Set(backup.grass.map(\.key))
                    let incomingHeroes = Set(backup.heroes.map(\.familyID)), incomingTeams = Set(backup.teams.map { $0.build.id })
                    let incomingArchives = Set(backup.legacyArchives.map(\.digest))
                    for (key, row) in shiny where !incomingShiny.contains(key) { context.delete(row); shiny.removeValue(forKey: key) }
                    for (key, row) in grass where !incomingGrass.contains(key) { context.delete(row); grass.removeValue(forKey: key) }
                    for (key, row) in heroes where !incomingHeroes.contains(key) { context.delete(row); heroes.removeValue(forKey: key) }
                    for (key, row) in teams where !incomingTeams.contains(key) { context.delete(row); teams.removeValue(forKey: key) }
                    for (key, row) in archives where !incomingArchives.contains(key) { context.delete(row); archives.removeValue(forKey: key) }
                    let incomingMedals = Set((backup.grassMedals ?? []).map(\.familyID))
                    for (key, row) in medals where !incomingMedals.contains(key) { context.delete(row); medals.removeValue(forKey: key) }
                }
                for value in backup.shiny {
                    if let row = shiny[value.slotID] {
                        try UserDatabase.validateVersion(row.dataVersion)
                        if mode == .replace || value.updatedAt > row.updatedAt || (value.updatedAt == row.updatedAt && !value.collected) {
                            row.collected = value.collected; row.updatedAt = value.updatedAt
                        }
                    } else {
                        let row = ShinyRecord(slotID: value.slotID, collected: value.collected); row.updatedAt = value.updatedAt; context.insert(row)
                    }
                }
                for value in backup.grass {
                    if let row = grass[value.key] {
                        try UserDatabase.validateVersion(row.dataVersion)
                        if mode == .replace || value.updatedAt > row.updatedAt || (value.updatedAt == row.updatedAt && priority(value.status) > priority(row.status)) {
                            row.status = value.status; row.updatedAt = value.updatedAt
                        }
                    } else {
                        let row = GrassRecord(footprintID: value.footprintID, locationID: value.locationID, status: value.status)
                        row.updatedAt = value.updatedAt; context.insert(row)
                    }
                }
                for value in backup.heroes {
                    if let row = heroes[value.familyID] {
                        try UserDatabase.validateVersion(row.dataVersion)
                        if mode == .replace || value.updatedAt > row.updatedAt || (value.updatedAt == row.updatedAt && !value.obtained) {
                            row.obtained = value.obtained; row.updatedAt = value.updatedAt
                        }
                    } else {
                        let row = HeroRecord(familyID: value.familyID, obtained: value.obtained); row.updatedAt = value.updatedAt; context.insert(row)
                    }
                }
                for value in backup.teams {
                    if let row = teams[value.build.id] {
                        try UserDatabase.validateVersion(row.dataVersion)
                        if mode == .replace || value.updatedAt > row.updatedAt {
                            row.payload = try JSONEncoder().encode(value.build); row.name = value.build.name; row.updatedAt = value.updatedAt
                        }
                    } else {
                        let row = try TeamRecord(build: value.build); row.updatedAt = value.updatedAt; context.insert(row)
                    }
                }
                for value in backup.legacyArchives where archives[value.digest] == nil { context.insert(LegacyArchiveRecord(value)) }
                for value in backup.grassMedals ?? [] {
                    if let row = medals[value.familyID] {
                        if mode == .replace || value.updatedAt > row.updatedAt || (value.updatedAt == row.updatedAt && !value.obtained) {
                            row.obtained = value.obtained; row.updatedAt = value.updatedAt
                        }
                    } else {
                        let row = GrassFamilyMedalRecord(familyID: value.familyID, obtained: value.obtained)
                        row.updatedAt = value.updatedAt; context.insert(row)
                    }
                }
                let preferences = try UserDatabase.preferences(context: context)
                if let incoming = backup.preferences {
                    if mode == .replace || incoming.activeTeamUpdatedAt > preferences.activeTeamUpdatedAt {
                        preferences.activeTeamID = incoming.activeTeamID; preferences.activeTeamUpdatedAt = incoming.activeTeamUpdatedAt
                    }
                    if mode == .replace || incoming.appearanceUpdatedAt > preferences.appearanceUpdatedAt {
                        preferences.appearanceRaw = incoming.appearance.rawValue; preferences.appearanceUpdatedAt = incoming.appearanceUpdatedAt
                    }
                } else if mode == .replace {
                    preferences.activeTeamID = nil; preferences.appearanceRaw = AppAppearance.system.rawValue
                    preferences.activeTeamUpdatedAt = Date(timeIntervalSince1970: 0); preferences.appearanceUpdatedAt = Date(timeIntervalSince1970: 0)
                }
                try beforeSave()
                try context.save()
            }
        } catch { context.rollback(); throw error }
    }
    private static func priority(_ state: BadgeState) -> Int { switch state { case .lit: 0; case .unlit: 1; case .unrecorded: 2 } }
}
