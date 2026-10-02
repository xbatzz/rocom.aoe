import Foundation

struct BundleReader {
    let root: URL

    init(bundle: Bundle, directory: String) throws {
        guard let resources = bundle.resourceURL else { throw ContentError.invalid("Bundle has no resourceURL") }
        root = try Self.containedURL(root: resources, path: directory)
    }
    static func containedURL(root: URL, path: String) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        try require(!path.isEmpty && !path.hasPrefix("/") && !parts.contains("..") && !parts.contains(".") && !parts.contains(""), "Unsafe Bundle path: \(path)")
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let url = base.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        try require(url.path.hasPrefix(base.path + "/"), "Bundle path escapes root: \(path)")
        return url
    }
    func data(_ path: String) throws -> Data {
        let url = try Self.containedURL(root: root, path: path)
        do { return try Data(contentsOf: url) }
        catch { throw ContentError.invalid("Cannot read \(url.path): \(error)") }
    }
    func decode<T: Decodable>(_ type: T.Type, path: String, file: ContentFile? = nil) throws -> T {
        let bytes = try data(path)
        if let file {
            try require(bytes.count == file.bytes && sha256(bytes) == file.sha256, "Content bytes/hash mismatch: \(path)")
        }
        return try decodeData(type, bytes: bytes, context: path)
    }
}

func decodeData<T: Decodable>(_ type: T.Type, bytes: Data, context: String) throws -> T {
    do { return try JSONDecoder().decode(type, from: bytes) }
    catch { throw ContentError.invalid("Decode \(context): \(error)") }
}

func uniqueIndex<T, ID: Hashable>(_ rows: [T], id: (T) -> ID, context: String) throws -> [ID: T] {
    var result: [ID: T] = [:]
    result.reserveCapacity(rows.count)
    for row in rows {
        let key = id(row)
        try require(result.updateValue(row, forKey: key) == nil, "Duplicate \(context) ID: \(key)")
    }
    return result
}
