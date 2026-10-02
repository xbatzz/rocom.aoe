import Foundation
import CryptoKit

public enum ContentError: Error, CustomStringConvertible, Sendable {
    case invalid(String)
    public var description: String {
        switch self { case .invalid(let message): return "ContentStore: \(message)" }
    }
}

struct ContentKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// Synthesized decodeIfPresent conflates a missing required key and explicit null.
/// This container checks the complete key set before any typed decoding.
struct StrictObject {
    let container: KeyedDecodingContainer<ContentKey>
    init(_ decoder: any Decoder, keys: [String]) throws {
        container = try decoder.container(keyedBy: ContentKey.self)
        let expected = Set(keys), actual = Set(container.allKeys.map(\.stringValue))
        guard expected == actual else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Missing keys: \(expected.subtracting(actual).sorted()); unexpected keys: \(actual.subtracting(expected).sorted())"))
        }
    }
    func value<T: Decodable>(_ key: String) throws -> T {
        try container.decode(T.self, forKey: ContentKey(key))
    }
}

func require(_ condition: Bool, _ context: String) throws {
    guard condition else { throw ContentError.invalid(context) }
}
func matches(_ value: String, _ pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
}
func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// Only battleEffects.parameters is open JSON in the frozen schema.
public indirect enum JSONValue: Codable, Equatable, Sendable {
    case null, boolean(Bool), number(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .boolean(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .boolean(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}
