import Foundation
import CryptoKit
import RocoContent

public struct UserBackup: Codable, Sendable {
    public var format = "rocom-native-user-data"
    public var schemaVersion = 1
    public var exportedAt: Date
    public var shiny: [Shiny]
    public var grass: [Grass]
    public var heroes: [Hero]
    public var teams: [Team]
    public var legacyArchives: [Archive]
    public init(exportedAt: Date = .now, shiny: [Shiny] = [], grass: [Grass] = [], heroes: [Hero] = [], teams: [Team] = [], legacyArchives: [Archive] = []) {
        self.exportedAt = exportedAt; self.shiny = shiny; self.grass = grass; self.heroes = heroes
        self.teams = teams; self.legacyArchives = legacyArchives
    }
    public struct Shiny: Codable, Sendable { public var slotID: String; public var collected: Bool; public var updatedAt: Date }
    public struct Grass: Codable, Sendable {
        public var footprintID: String; public var locationID: String; public var status: BadgeState; public var updatedAt: Date
        public var key: String { GrassRecord.key(footprintID, locationID) }
    }
    public struct Hero: Codable, Sendable { public var familyID: String; public var obtained: Bool; public var updatedAt: Date }
    public struct Team: Codable, Sendable { public var build: TeamBuild; public var updatedAt: Date }
    /// Exact original Web document, including fields this app cannot yet activate.
    public struct Archive: Codable, Sendable { public var digest: String; public var originalJSON: String; public var receivedAt: Date }

    public func validate() throws {
        guard format == "rocom-native-user-data", schemaVersion == 1 else { throw BackupError.invalid("不支持的备份格式/版本") }
        try Self.date(exportedAt)
        try Self.unique(shiny.map(\.slotID)); try Self.unique(grass.map(\.key))
        try Self.unique(heroes.map(\.familyID)); try Self.unique(teams.map { $0.build.id.uuidString }); try Self.unique(legacyArchives.map(\.digest))
        for row in shiny { try Self.id(row.slotID); try Self.date(row.updatedAt) }
        for row in grass { try Self.id(row.footprintID); try Self.id(row.locationID); try Self.date(row.updatedAt) }
        for row in heroes { try Self.id(row.familyID); try Self.date(row.updatedAt) }
        for row in teams { try row.build.validate(); try Self.date(row.updatedAt) }
        for row in legacyArchives {
            try Self.date(row.receivedAt)
            guard BackupCodec.digest(Data(row.originalJSON.utf8)) == row.digest else { throw BackupError.invalid("Web 归档校验不匹配") }
            _ = try JSONSerialization.jsonObject(with: Data(row.originalJSON.utf8))
        }
    }
    private static func id(_ id: String) throws { guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !id.contains("|") else { throw BackupError.invalid("稳定 ID 不得为空或含记录键分隔符") } }
    private static func date(_ date: Date) throws { guard date.timeIntervalSince1970.isFinite else { throw BackupError.invalid("日期无效") } }
    private static func unique(_ ids: [String]) throws {
        guard Set(ids).count == ids.count else { throw BackupError.invalid("备份含重复记录 ID") }
    }
}

public enum BackupError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let text): text } }
}
public enum BackupImportMode: String, CaseIterable, Sendable { case merge, replace }
public struct PreparedBackup: Sendable {
    public let backup: UserBackup
    public let warnings: [String]
}

public enum BackupCodec {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer(); try c.encode(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .omitted)))
        }
        return encoder
    }
    public static func parseDate(_ string: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: string) else { throw BackupError.invalid("无法解析 ISO 日期：\(string)") }
        return date
    }
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { try parseDate($0.singleValueContainer().decode(String.self)) }
        return decoder
    }
    public static func encode(_ backup: UserBackup) throws -> Data { try backup.validate(); return try encoder().encode(backup) }
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func prepare(_ data: Data, content: ContentStore) throws -> PreparedBackup {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let format = object["format"] as? String else { throw BackupError.invalid("备份须为有 format 的 JSON 对象") }
        if format == "rocom-user-data" { return try LegacyBackupImporter.prepare(data, content: content) }
        guard format == "rocom-native-user-data" else { throw BackupError.invalid("不支持此备份格式") }
        try validateKeys(object)
        let backup = try decoder().decode(UserBackup.self, from: data)
        try backup.validate()
        return PreparedBackup(backup: backup, warnings: [])
    }
    /// Do not silently discard future native fields under a known schema version.
    private static func validateKeys(_ root: [String: Any]) throws {
        func keys(_ object: [String: Any], _ allowed: Set<String>) throws {
            guard Set(object.keys).isSubset(of: allowed) else { throw BackupError.invalid("备份含未支持字段：\(Set(object.keys).subtracting(allowed).sorted().joined(separator: ", "))") }
        }
        try keys(root, ["format","schemaVersion","exportedAt","shiny","grass","heroes","teams","legacyArchives"])
        for (name, allowed) in [("shiny", Set(["slotID","collected","updatedAt"])), ("grass", Set(["footprintID","locationID","status","updatedAt"])), ("heroes", Set(["familyID","obtained","updatedAt"])), ("legacyArchives", Set(["digest","originalJSON","receivedAt"]))] {
            guard let rows = root[name] as? [[String: Any]] else { throw BackupError.invalid("\(name) 必须是记录数组") }
            for row in rows { try keys(row, allowed) }
        }
        guard let teams = root["teams"] as? [[String: Any]] else { throw BackupError.invalid("teams 必须是数组") }
        for team in teams {
            try keys(team, ["build","updatedAt"])
            guard let build = team["build"] as? [String: Any], let slots = build["slots"] as? [[String: Any]] else { throw BackupError.invalid("队伍结构无效") }
            try keys(build, ["version","id","name","magicItemID","slots"])
            for slot in slots { try keys(slot, ["petID","personalityID","legacyTypeID","individualValues","skillIDs"]) }
        }
    }
}
