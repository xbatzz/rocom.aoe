import Foundation

/// Web encyclopedia presentation rules, independent of canonical storage order.
public enum PetCatalogPresentation {
    public static func handbookOrder(_ left: Pet, _ right: Pet) -> Bool {
        // Web getPetHandbookId uses species_id even when no real handbook entry exists.
        // Keep handbookId's stricter eligibility semantics for labels and search.
        if left.speciesId != right.speciesId {
            return left.speciesId.rawValue < right.speciesId.rawValue
        }
        return left.petId.rawValue < right.petId.rawValue
    }

    /// Call after filtering so a matching alternate leader can represent its group.
    public static func collapseDuplicateLeaderConfigurations(_ pets: [Pet]) -> [Pet] {
        var regularPets: [Pet] = []
        var leaders: [LeaderKey: Pet] = [:]
        var leaderKeys: [LeaderKey] = []
        for pet in pets {
            guard pet.isLeader else {
                regularPets.append(pet)
                continue
            }
            let key = LeaderKey(pet)
            if let current = leaders[key] {
                if shouldReplace(pet, current) { leaders[key] = pet }
            } else {
                leaderKeys.append(key)
                leaders[key] = pet
            }
        }
        return regularPets + leaderKeys.compactMap { leaders[$0] }
    }

    private static func shouldReplace(_ candidate: Pet, _ current: Pet) -> Bool {
        if candidate.implemented != current.implemented { return candidate.implemented }
        let candidateHasStats = total(candidate) > 0
        let currentHasStats = total(current) > 0
        if candidateHasStats != currentHasStats { return candidateHasStats }
        return candidate.petId.rawValue < current.petId.rawValue
    }

    private static func total(_ pet: Pet) -> Int {
        let stats = pet.baseStats
        return stats.hp + stats.physicalAttack + stats.magicalAttack
            + stats.physicalDefense + stats.magicalDefense + stats.speed
    }

    private struct LeaderKey: Hashable {
        let speciesID: Int
        let name: String
        let resource: String

        init(_ pet: Pet) {
            speciesID = pet.speciesId.rawValue
            name = pet.nameZh.trimmingCharacters(in: .whitespacesAndNewlines)
            resource = pet.resourceKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
