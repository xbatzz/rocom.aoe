import Foundation
import CryptoKit
import Testing
import RocoDomain
@testable import RocoContent

private let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
private let bundleURL = repository.appendingPathComponent("build/ios-content/store/ContentResources.bundle")

private func resourceBundle() throws -> Bundle {
    try #require(Bundle(url: bundleURL), "Run python3 scripts/ios-store/prepare-bundle.py first")
}
private func editedBundle(_ edit: (URL) throws -> Void, body: (Bundle) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let target = directory.appendingPathComponent("ContentResources.bundle")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.copyItem(at: bundleURL, to: target)
    try edit(target.appendingPathComponent("Content"))
    try body(#require(Bundle(url: target)))
}
private func json(_ url: URL) throws -> Any { try JSONSerialization.jsonObject(with: Data(contentsOf: url)) }
private func writeJSON(_ value: Any, _ url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: url)
}
private func editEntity(_ root: URL, _ filename: String, edit: (inout [[String: Any]]) throws -> Void) throws {
    let file = root.appendingPathComponent("canonical/" + filename)
    var rows = try #require(json(file) as? [[String: Any]])
    try edit(&rows)
    try writeJSON(rows, file)
    var manifest = try #require(json(root.appendingPathComponent("canonical/manifest.json")) as? [String: Any])
    var files = try #require(manifest["files"] as? [[String: Any]])
    let i = try #require(files.firstIndex { $0["path"] as? String == filename })
    let bytes = try Data(contentsOf: file)
    files[i]["bytes"] = bytes.count
    files[i]["sha256"] = sha256(bytes)
    manifest["files"] = files
    try writeJSON(manifest, root.appendingPathComponent("canonical/manifest.json"))
    try relinkAssets(root)
}
private func relinkAssets(_ root: URL) throws {
    let file = root.appendingPathComponent("assets/asset-manifest.json")
    var manifest = try #require(json(file) as? [String: Any])
    manifest["canonicalManifestSha256"] = sha256(try Data(contentsOf: root.appendingPathComponent("canonical/manifest.json")))
    try writeJSON(manifest, file)
}
private func expectFailure(_ bundle: Bundle, containing message: String) throws {
    do {
        _ = try ContentStore.load(bundle: bundle)
        Issue.record("Expected failure: \(message)")
    } catch { #expect(String(describing: error).contains(message)) }
}

@Suite(.serialized) struct ContentStoreTests {
    @Test func realCatalogAndForeignKeys() throws {
        let store = try ContentStore.load(bundle: resourceBundle())
        #expect(store.pets.count == 721)
        #expect(store.skills.count == 1079)
        let counts: [String: Int] = ["pets": store.pets.count, "petDetails": store.petDetails.count,
            "types": store.types.count, "skills": store.skills.count, "skillGroups": store.skillGroups.count,
            "petSkills": store.petSkillsByPet.values.reduce(0) { $0 + $1.count }, "traits": store.traits.count,
            "evolutions": store.evolutions.count, "families": store.families.count, "shinySlots": store.shinySlots.count,
            "badgeFootprints": store.badgeFootprints.count, "badgeLocations": store.badgeLocations.count,
            "personalities": store.personalities.count, "magicItems": store.magicItems.count,
            "seasons": store.seasons.count, "battleEffects": store.battleEffects.count, "assets": store.assets.count]
        #expect(counts == store.manifest.counts)
        let id = PetID(rawValue: 3001)
        let pet = try #require(store.pet(id))
        #expect(pet.nameZh == "喵喵")
        #expect(pet.speciesId.rawValue == 2)
        #expect(store.type(TypeID(rawValue: 2)) != nil)
        let detail = try #require(store.petDetails[id])
        #expect(detail.traitId?.rawValue == 200076)
        #expect(store.trait(TraitID(rawValue: 200076)) != nil)
        #expect(store.skill(SkillID(rawValue: 1))?.nameZh == "聚能")
        #expect(store.evolutions(from: id).map(\.targetPetId) == [PetID(rawValue: 3025)])
        #expect(store.incomingEvolutionsByPet[PetID(rawValue: 3025)]?.first?.sourcePetId == id)
        #expect(store.families(for: id, kind: .badgeRoot).contains { $0.memberPetIds.contains(id) })
        #expect(store.families(for: id, kind: .skillTerminal).contains { $0.memberPetIds.contains(id) })
        for row in store.petSkills(for: id) {
            #expect(store.skill(row.skillId) != nil)
            if let legacy = row.legacyTypeId { #expect(store.type(legacy) != nil) }
        }
        #expect(store.families(for: PetID(rawValue: 3550), kind: .skillTerminal).count == 4)
        #expect(store.seasons[SeasonID(rawValue: 0)] != nil)
        #expect(store.shinySlotsBySeason[SeasonID(rawValue: 4)]?.count == 19)
        #expect(store.badgeFootprintsByPet[id]?.footprintKey.rawValue == "pet:3001")
        #expect(store.battleEffectsBySkill[SkillID(rawValue: 1)]?.first?.kind == .unsupported)
        #expect(detail.catchInfo?.thresholdRaw == 1000)
        #expect(detail.catchInfo?.guaranteeRateBasisPoints == nil)
    }

    @Test func allAssetStatesAndUnknownID() throws {
        let store = try ContentStore.load(bundle: resourceBundle())
        var missing = Set<Int>(), available = 0
        for id in store.assets.keys {
            switch try store.assetResolver.resolve(id) {
            case .available(let url):
                #expect(url.pathExtension == "webp")
                available += 1
            case .missing(let state):
                #expect(state.reason == "source-file-missing")
                missing.formUnion(state.petIds.map(\.rawValue))
            }
        }
        #expect(available == 1465)
        #expect(missing == [3784, 3785])
        #expect(throws: ContentError.self) { try store.assetResolver.resolve(AssetID(rawValue: "unknown")) }
    }

    @Test func requiredNullableAndStrictDecoding() throws {
        let data = Data("{\"petId\":3001,\"traitId\":null,\"worldProfile\":null,\"catchInfo\":null}".utf8)
        let detail = try JSONDecoder().decode(PetDetail.self, from: data)
        #expect(detail.catchInfo == nil)
        #expect(try JSONDecoder().decode(PetDetail.self, from: JSONEncoder().encode(detail)) == detail)
        for text in [
            "{\"petId\":3001,\"traitId\":null,\"worldProfile\":null}",
            "{\"petId\":3001,\"traitId\":null,\"worldProfile\":null,\"catchInfo\":{},\"extra\":1}",
            "{\"petId\":0,\"traitId\":null,\"worldProfile\":null,\"catchInfo\":null}",
            "{\"petId\":3001,\"traitId\":null,\"worldProfile\":null,\"catchInfo\":{\"thresholdRaw\":-1,\"guaranteeRateBasisPoints\":null,\"ballLevelRaw\":1}}"
        ] { #expect(throws: (any Error).self) { try JSONDecoder().decode(PetDetail.self, from: Data(text.utf8)) } }
    }

    @Test func schemaVersionAndCountsFail() throws {
        for (key, value, expected) in [("schemaVersion", 3, "schemaVersion"), ("minimumAppBuild", 100, "App build")] {
            try editedBundle({ root in
                let file = root.appendingPathComponent("canonical/manifest.json")
                var m = try #require(json(file) as? [String: Any]); m[key] = value
                try writeJSON(m, file)
            }, body: { try expectFailure($0, containing: expected) })
        }
        try editedBundle({ root in
            let file = root.appendingPathComponent("canonical/manifest.json")
            var m = try #require(json(file) as? [String: Any])
            var counts = try #require(m["counts"] as? [String: Int]); counts["pets"] = 722; m["counts"] = counts
            try writeJSON(m, file)
        }, body: { try expectFailure($0, containing: "Count mismatch: pets") })
    }

    @Test func duplicateAndBrokenFKFailAfterRehash() throws {
        try editedBundle({ root in
            try editEntity(root, "pets.json") { $0[1] = $0[0] }
        }, body: { try expectFailure($0, containing: "Duplicate pets ID") })
        try editedBundle({ root in
            try editEntity(root, "pet-skills.json") { $0[0]["skillId"] = 999999999 }
        }, body: { try expectFailure($0, containing: "Unresolved FK petSkills.skillId") })
        try editedBundle({ root in
            try editEntity(root, "pets.json") { $0[0]["parentPetId"] = $0[0]["petId"] }
        }, body: { try expectFailure($0, containing: "Parent cycle") })
    }

    @Test func corruptedOrMissingJSONFails() throws {
        try editedBundle({ root in
            try FileManager.default.removeItem(at: root.appendingPathComponent("canonical/skills.json"))
        }, body: { try expectFailure($0, containing: "Cannot read") })
        try editedBundle({ root in
            try Data("[]".utf8).write(to: root.appendingPathComponent("canonical/skills.json"))
        }, body: { try expectFailure($0, containing: "bytes/hash mismatch") })
    }

    @Test func assetMismatchUnknownMissingAndTraversalFail() throws {
        try editedBundle({ root in
            let file = root.appendingPathComponent("assets/asset-manifest.json")
            var m = try #require(json(file) as? [String: Any]); m["canonicalManifestSha256"] = String(repeating: "0", count: 64)
            try writeJSON(m, file)
        }, body: { try expectFailure($0, containing: "different canonical package") })
        for (key, value, message) in [("missing", true as Any, "Unknown missing asset"), ("relativeOutputPath", "images/portraitGrid/../../escape.webp" as Any, "Unsafe Bundle path")] {
            try editedBundle({ root in
                let file = root.appendingPathComponent("assets/asset-manifest.json")
                var m = try #require(json(file) as? [String: Any])
                var records = try #require(m["assets"] as? [[String: Any]])
                let oldPath = try #require(records[0]["relativeOutputPath"] as? String)
                records[0][key] = value; m["assets"] = records
                if key == "relativeOutputPath" {
                    var files = try #require(m["files"] as? [[String: Any]])
                    let i = try #require(files.firstIndex { $0["relativePath"] as? String == oldPath })
                    files[i]["relativePath"] = value; m["files"] = files
                }
                try writeJSON(m, file)
            }, body: { try expectFailure($0, containing: message) })
        }
    }

    @Test func unknownMissingWebPAndCorruptionFail() throws {
        for corrupt in [false, true] {
            try editedBundle({ root in
                let m = try #require(json(root.appendingPathComponent("assets/asset-manifest.json")) as? [String: Any])
                let rows = try #require(m["assets"] as? [[String: Any]])
                let path = try #require(rows[0]["relativeOutputPath"] as? String)
                let file = root.appendingPathComponent("assets/" + path)
                if corrupt { try Data("bad".utf8).write(to: file) }
                else { try FileManager.default.removeItem(at: file) }
            }, body: { try expectFailure($0, containing: corrupt ? "Missing/corrupt Bundle WebP" : "Cannot read") })
        }
    }

    @Test func onDemandAssetsMatchEagerSnapshot() throws {
        let bundle = try resourceBundle()
        let eager = try ContentStore.load(bundle: bundle)
        let deferred = try ContentStore.load(bundle: bundle, assetValidation: .onDemand)
        #expect(deferred.manifest == eager.manifest)
        #expect(deferred.pets == eager.pets)
        #expect(deferred.assetResolver.materializedCount == eager.assetResolver.materializedCount)
        #expect(deferred.assetResolver.missingCount == eager.assetResolver.missingCount)
        for id in eager.assets.keys {
            #expect(try deferred.assetResolver.resolve(id) == eager.assetResolver.resolve(id))
        }
        #expect(throws: ContentError.self) { try deferred.assetResolver.resolve(AssetID(rawValue: "unknown")) }
    }

    @Test func onDemandRejectsMissingCorruptAndEscapingImagesWhenRequested() throws {
        for mutation in ["missing", "corrupt", "symlink"] {
            var affectedID: AssetID?
            try editedBundle({ root in
                let manifest = try #require(json(root.appendingPathComponent("assets/asset-manifest.json")) as? [String: Any])
                let rows = try #require(manifest["assets"] as? [[String: Any]])
                let row = try #require(rows.first { $0["relativeOutputPath"] is String })
                affectedID = AssetID(rawValue: try #require(row["assetKey"] as? String))
                let path = try #require(row["relativeOutputPath"] as? String)
                let file = root.appendingPathComponent("assets/" + path)
                switch mutation {
                case "missing": try FileManager.default.removeItem(at: file)
                case "corrupt": try Data("bad".utf8).write(to: file)
                default:
                    let outside = root.appendingPathComponent("outside.webp")
                    try FileManager.default.moveItem(at: file, to: outside)
                    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
                }
            }, body: { bundle in
                let store = try ContentStore.load(bundle: bundle, assetValidation: .onDemand)
                let id = try #require(affectedID)
                let other = try #require(store.assets.keys.first { $0 != id && store.assets[$0]?.availability == .available })
                _ = try store.assetResolver.resolve(other)
                do {
                    _ = try store.assetResolver.resolve(id)
                    Issue.record("Expected rejection of \(mutation) image")
                } catch {
                    let expected = mutation == "missing" ? "Cannot read" : mutation == "corrupt" ? "Missing/corrupt Bundle WebP" : "Bundle path escapes root"
                    #expect(String(describing: error).contains(expected))
                }
            })
        }
    }

    @Test func onDemandStillRejectsCorruptCanonicalData() throws {
        try editedBundle({ root in
            try Data("[]".utf8).write(to: root.appendingPathComponent("canonical/skills.json"))
        }, body: { bundle in
            do {
                _ = try ContentStore.load(bundle: bundle, assetValidation: .onDemand)
                Issue.record("Expected canonical integrity failure")
            } catch { #expect(String(describing: error).contains("bytes/hash mismatch")) }
        })
    }


    @Test func realDTOsRoundTripWithRequiredNulls() throws {
        let store = try ContentStore.load(bundle: resourceBundle())
        func roundTrip<T: Codable & Equatable>(_ value: T) throws {
            #expect(try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value)) == value)
        }
        try roundTrip(store.manifest)
        try roundTrip(Array(store.pets.values))
        try roundTrip(Array(store.petDetails.values))
        try roundTrip(Array(store.types.values))
        try roundTrip(Array(store.skills.values))
        try roundTrip(Array(store.skillGroups.values))
        try roundTrip(store.petSkillsByPet.values.flatMap { $0 })
        try roundTrip(Array(store.traits.values))
        try roundTrip(Array(store.evolutions.values))
        try roundTrip(Array(store.families.values))
        try roundTrip(Array(store.shinySlots.values))
        try roundTrip(Array(store.badgeFootprints.values))
        try roundTrip(Array(store.badgeLocations.values))
        try roundTrip(Array(store.personalities.values))
        try roundTrip(Array(store.magicItems.values))
        try roundTrip(Array(store.seasons.values))
        try roundTrip(Array(store.battleEffects.values))
        try roundTrip(Array(store.assets.values))
    }

    @Test func assetReferencesAndEnumsFail() throws {
        try editedBundle({ root in
            let file = root.appendingPathComponent("assets/asset-manifest.json")
            var m = try #require(json(file) as? [String: Any])
            var assets = try #require(m["assets"] as? [[String: Any]])
            var references = try #require(assets[0]["references"] as? [[String: Any]])
            references[0]["id"] = 999999999
            assets[0]["references"] = references; m["assets"] = assets
            try writeJSON(m, file)
        }, body: { try expectFailure($0, containing: "Asset reference mismatch") })
        try editedBundle({ root in
            try editEntity(root, "skills.json") { $0[0]["category"] = "invented" }
        }, body: { try expectFailure($0, containing: "Decode skills.json") })
    }

    @Test func snapshotCanCrossIsolation() async throws {
        let store = try await ContentStore.loadInBackground(bundleURL: bundleURL)
        let count = await withTaskGroup(of: Int.self, returning: Int.self) { group in
            for _ in 0..<4 { group.addTask { store.petSkills(for: PetID(rawValue: 3001)).count } }
            var total = 0
            for await value in group { total += value }
            return total
        }
        #expect(count == 4 * store.petSkills(for: PetID(rawValue: 3001)).count)
    }
}
