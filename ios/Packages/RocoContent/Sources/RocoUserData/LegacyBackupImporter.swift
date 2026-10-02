import Foundation
import CryptoKit
import CoreFoundation
import RocoDomain
import RocoContent

/// Web userDataBackup.ts versions 1–4. Exact source JSON is always retained.
/// Unsupported user fields are reported and archived, never discarded or inferred.
public enum LegacyBackupImporter {
    public static func prepare(_ bytes: Data, content: ContentStore) throws -> PreparedBackup {
        let root = try object(JSONSerialization.jsonObject(with: bytes), "Web backup")
        guard root["format"] as? String == "rocom-user-data", let rawVersion = root["version"],
            let version = try? integer(rawVersion, field: "version", minimum: 1),
            (1...4).contains(version), let original = String(data: bytes, encoding: .utf8) else { throw BackupError.invalid("不支持的 Web 备份版本") }
        let exportedAt = try date(root["exportedAt"])
        let data = try object(root["data"], "data")
        var backup = UserBackup(exportedAt: exportedAt)
        var warnings = ["Web 原始 JSON 已完整归档，主题、图鉴课题/收藏、草系家族奖牌、队伍角色与当前队伍选择暂不激活；这些字段会随原生备份再次导出。"]
        let teamState = try object(data["teams"], "teams")
        guard try integer(teamState["version"] as Any, field: "teams.version", minimum: 1) == 2, let teams = teamState["teams"] as? [[String: Any]],
            let activeID = teamState["activeTeamId"] as? String,
            teams.contains(where: { $0["id"] as? String == activeID }) else { throw BackupError.invalid("Web teams 结构无效") }
        for team in teams {
            guard let id = team["id"] as? String, !id.isEmpty, let name = team["name"] as? String,
                let slots = team["slots"] as? [Any], slots.count <= 6 else { throw BackupError.invalid("Web 队伍 ID/名称/槽位无效；不会截断额外槽") }
            var build = TeamBuild(); build.id = stableTeamID(id); build.name = name
            build.magicItemID = try optionalID(team["magicItemId"])
            for (index, value) in slots.enumerated() {
                if value is NSNull { continue }
                let row = try object(value, "slots[\(index)]")
                var slot = TeamSlot()
                slot.petID = try optionalID(row["friendId"])
                slot.personalityID = try optionalID(row["personalityId"])
                slot.legacyTypeID = try optionalID(row["legacyTypeId"])
                if let raw = row["individualValues"] {
                    let iv = try object(raw, "individualValues")
                    slot.individualValues = try ["hp","phyAtk","magAtk","phyDef","magDef","speed"].map { key in
                        guard let value = iv[key] else { return 0 } // Web's documented legacy missing-value default.
                        return try integer(value, field: key, minimum: 0)
                    }
                }
                if let raw = row["moveIds"] ?? row["skillIds"] ?? row["selectedMoves"] ?? row["skills"] ?? row["moves"] {
                    guard let moves = raw as? [Any] else { throw BackupError.invalid("Web 技能必须是数组") }
                    slot.skillIDs = try moves.map { value in
                        if let row = value as? [String: Any] {
                            guard let value = row["id"] ?? row["moveId"] ?? row["move_id"] ?? row["skillId"] ?? row["skill_id"] else { throw BackupError.invalid("Web 技能缺 ID") }
                            return try integer(value, field: "skillID", minimum: 1)
                        }
                        return try integer(value, field: "skillID", minimum: 1)
                    }
                }
                build.slots[index] = slot
            }
            try build.validate() // Invalid/>4/duplicate skills are rejected, never truncated.
            backup.teams.append(.init(build: build, updatedAt: try date(team["updatedAt"])))
        }
        if version >= 3 {
            let shiny = try object(data["shinyCollection"], "shinyCollection")
            let entries = try object(shiny["entries"], "shiny.entries")
            guard let rawVersion = shiny["version"],
                let shinyVersion = try? integer(rawVersion, field: "shiny.version", minimum: 1), [1,2].contains(shinyVersion) else { throw BackupError.invalid("Web 异色版本无效") }
            for (key, value) in entries.sorted(by: { $0.key < $1.key }) {
                let entry = try object(value, "shiny entry")
                guard let flag = entry["collected"] as? NSNumber, CFGetTypeID(flag) == CFBooleanGetTypeID() else { throw BackupError.invalid("Web 异色状态须为布尔值") }
                let collected = flag.boolValue
                let timestamp = try date(entry["updatedAt"])
                let parts = key.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, parts[0].hasPrefix("s"), let season = Int(parts[0].dropFirst()), season >= 0 else { throw BackupError.invalid("Web 异色 key 无效") }
                if shinyVersion == 2 {
                    let slot = String(parts[1])
                    guard slot.hasPrefix("s\(season)-") else { throw BackupError.invalid("Web 异色赛季与槽 ID 不匹配") }
                    backup.shiny.append(.init(slotID: slot, collected: collected, updatedAt: timestamp))
                } else {
                    guard let id = Int(parts[1]), id > 0 else { throw BackupError.invalid("Web 旧异色精灵 ID 无效") }
                    let slots = (content.shinySlotsByPet[PetID(rawValue: id)] ?? []).filter { $0.seasonId.rawValue == season }
                    if slots.isEmpty { warnings.append("旧异色 \(key) 暂无 canonical slot；原始状态仅归档保留。") }
                    for slot in slots { backup.shiny.append(.init(slotID: slot.slotId.rawValue, collected: collected, updatedAt: timestamp)) }
                }
            }
            // Multiple legacy stages may refer to the same canonical slot: latest, then false wins.
            var merged: [String: UserBackup.Shiny] = [:]
            for row in backup.shiny {
                if let previous = merged[row.slotID], previous.updatedAt > row.updatedAt || (previous.updatedAt == row.updatedAt && !previous.collected) { continue }
                merged[row.slotID] = row
            }
            backup.shiny = merged.values.sorted { $0.slotID < $1.slotID }
        }
        if version >= 2 {
            let badges = try object(data["badgeTrials"], "badgeTrials")
            guard try integer(badges["version"] as Any, field: "badges.version", minimum: 1) == 1 else { throw BackupError.invalid("Web 徽章版本无效") }
            let trials = try object(badges["trials"], "badgeTrials.trials")
            if let raw = trials["destined-hero"] {
                let trial = try object(raw, "destined-hero")
                for (key, timestamp) in try object(trial["familyMedals"], "familyMedals") {
                    backup.heroes.append(.init(familyID: key, obtained: true, updatedAt: try date(timestamp)))
                }
            }
            if let raw = trials["grass"] {
                let trial = try object(raw, "grass")
                var records: [String: UserBackup.Grass] = [:]
                for (field, status) in [("footprints", BadgeState.lit), ("unlitFootprints", .unlit)] {
                    let locations = try object(trial[field] ?? [String: Any](), field)
                    for (location, raw) in locations {
                        for (footprint, timestamp) in try object(raw, "location records") {
                            let date = try date(timestamp)
                            guard footprint.hasPrefix("pet:") else {
                                warnings.append("旧足迹 \(location)/\(footprint) 不猜映射；原始记录仅归档保留。")
                                continue
                            }
                            let row = UserBackup.Grass(footprintID: footprint, locationID: location, status: status, updatedAt: date)
                            if let previous = records[row.key], previous.updatedAt > row.updatedAt { continue }
                            records[row.key] = row // Equal time unlit wins, as the second pass.
                        }
                    }
                }
                backup.grass = records.values.sorted { $0.key < $1.key }
            }
        }
        backup.heroes.sort { $0.familyID < $1.familyID }
        backup.legacyArchives = [.init(digest: BackupCodec.digest(bytes), originalJSON: original, receivedAt: exportedAt)]
        try backup.validate()
        return PreparedBackup(backup: backup, warnings: warnings)
    }
    private static func object(_ value: Any?, _ field: String) throws -> [String: Any] {
        guard let object = value as? [String: Any] else { throw BackupError.invalid("Web \(field) 必须是对象") }
        return object
    }
    private static func date(_ value: Any?) throws -> Date {
        guard let value = value as? String else { throw BackupError.invalid("Web 日期缺失") }
        return try BackupCodec.parseDate(value)
    }
    private static func optionalID(_ value: Any?) throws -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        return try integer(value, field: "ID", minimum: 1)
    }
    private static func integer(_ value: Any, field: String, minimum: Int) throws -> Int {
        // Numeric Web IDs must be JS-safe; reject rather than round a large JSON number.
        // Decimal strings can be read exactly without passing through Double.
        if let text = value as? String {
            guard let number = Int(text), number >= minimum else { throw BackupError.invalid("Web \(field) 必须是合法整数") }
            return number
        }
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else {
            throw BackupError.invalid("Web \(field) 必须是整数，不能是布尔值")
        }
        let number = value.doubleValue
        guard number.isFinite, number.rounded() == number, number >= Double(minimum),
            number <= 9_007_199_254_740_991 else { throw BackupError.invalid("Web \(field) 超出安全整数范围或不是整数") }
        return Int(number)
    }
    /// Arbitrary Web IDs map reproducibly; exact original IDs remain in the archived document.
    private static func stableTeamID(_ value: String) -> UUID {
        if let id = UUID(uuidString: value) { return id }
        var b = Array(SHA256.hash(data: Data(("rocom-web-team:" + value).utf8)).prefix(16))
        b[6] = (b[6] & 0x0f) | 0x50; b[8] = (b[8] & 0x3f) | 0x80
        return UUID(uuid: (b[0],b[1],b[2],b[3],b[4],b[5],b[6],b[7],b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15]))
    }
}
