import Foundation
import SwiftData

@Model public final class GrassFamilyMedalRecord {
    @Attribute(.unique) public var familyID: String
    public var dataVersion: Int = 1
    public var obtained: Bool
    public var updatedAt: Date
    public init(familyID: String, obtained: Bool) {
        self.familyID = familyID; self.obtained = obtained; updatedAt = .now
    }
}

extension UserDatabase {
    @MainActor public static func toggleGrassMedal(_ id: String, context: ModelContext) throws {
        if let row = try context.fetch(FetchDescriptor<GrassFamilyMedalRecord>()).first(where: { $0.familyID == id }) {
            row.obtained.toggle(); row.updatedAt = nextTimestamp(after: row.updatedAt)
        } else { context.insert(GrassFamilyMedalRecord(familyID: id, obtained: true)) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
    @MainActor public static func setGrass(_ status: BadgeState, footprint: String, location: String, context: ModelContext) throws {
        let id = GrassRecord.key(footprint, location)
        if let row = try context.fetch(FetchDescriptor<GrassRecord>()).first(where: { $0.identity == id }) {
            row.status = status; row.updatedAt = nextTimestamp(after: row.updatedAt)
        } else { context.insert(GrassRecord(footprintID: footprint, locationID: location, status: status)) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
    @MainActor public static func setShiny(_ collected: Bool, slot: String, context: ModelContext) throws {
        if let row = try context.fetch(FetchDescriptor<ShinyRecord>()).first(where: { $0.slotID == slot }) {
            row.collected = collected; row.updatedAt = nextTimestamp(after: row.updatedAt)
        } else { context.insert(ShinyRecord(slotID: slot, collected: collected)) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
