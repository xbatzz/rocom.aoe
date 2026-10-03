import Foundation
import RocoContent
import RocoDomain
import Darwin

func residentBytes() throws -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { throw ContentError.invalid("task_info failed: \(result)") }
    return info.resident_size
}

struct ProbeReport: Codable {
    let assetValidation: String
    let operatingSystem: String
    let runs: Int
    let loadMilliseconds: [Double]
    let baselineResidentBytes: UInt64
    let firstLoadedResidentBytes: UInt64
    let firstResidentDeltaBytes: Int64
    let loadedResidentBytes: UInt64
    let residentDeltaBytes: Int64
    let counts: [String: Int]
    let materializedAssets: Int
    let missingPets: [Int]
}

@main struct ContentProbe {
    static func main() throws {
        guard (3...4).contains(CommandLine.arguments.count),
            CommandLine.arguments.count == 3 || CommandLine.arguments[3] == "--on-demand-assets",
            let bundle = Bundle(url: URL(fileURLWithPath: CommandLine.arguments[1])) else {
            throw ContentError.invalid("Usage: content-probe <ContentResources.bundle> <report.json> [--on-demand-assets]")
        }
        let validation: AssetValidationMode = CommandLine.arguments.count == 4 ? .onDemand : .eager
        let baseline = try residentBytes()
        var times: [Double] = []
        var firstLoaded: UInt64 = 0
        var retained: ContentStore?
        for _ in 0..<5 {
            retained = nil
            let start = ContinuousClock.now
            let store = try autoreleasepool { try ContentStore.load(bundle: bundle, assetValidation: validation) }
            let elapsed = start.duration(to: .now).components
            times.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
            retained = store
            if times.count == 1 { firstLoaded = try residentBytes() }
        }
        guard let store = retained else { throw ContentError.invalid("No loaded store") }
        guard store.pets.count == 721, store.skills.count == 1079,
            store.pet(PetID(rawValue: 3001))?.nameZh == "喵喵" else {
            throw ContentError.invalid("Representative/count verification failed")
        }
        var missing: [Int] = []
        for number in [3784, 3785] {
            guard let id = store.pet(PetID(rawValue: number))?.portraitAssetId,
                case .missing(let status) = try store.assetResolver.resolve(id),
                status.petIds == [PetID(rawValue: number)] else { throw ContentError.invalid("Missing verification failed") }
            missing.append(number)
        }
        let loaded = try residentBytes()
        let report = ProbeReport(assetValidation: validation == .onDemand ? "onDemand" : "eager",
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            runs: 5, loadMilliseconds: times, baselineResidentBytes: baseline, firstLoadedResidentBytes: firstLoaded,
            firstResidentDeltaBytes: Int64(firstLoaded) - Int64(baseline), loadedResidentBytes: loaded,
            residentDeltaBytes: Int64(loaded) - Int64(baseline), counts: store.manifest.counts,
            materializedAssets: store.assetResolver.materializedCount, missingPets: missing)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print(String(decoding: data, as: UTF8.self))
        withExtendedLifetime(store) {}
    }
}
