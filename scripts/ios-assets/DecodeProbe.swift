import Foundation
import UIKit
import ImageIO
import CryptoKit

struct Input: Decodable {
    let assetId: String
    let path: String
    let sourceSha256: String
}
struct Pixels: Codable, Equatable {
    let width: Int
    let height: Int
    let rgbaSha256: String
    let transparentPixels: Int
    let partialAlphaPixels: Int
    let opaquePixels: Int
}
struct Result: Codable {
    let assetId: String
    let sourceSha256: String
    let imageIO: Pixels
    let uiImage: Pixels
    let uiImageFile: Pixels
}
struct Report: Codable {
    let platform: String
    let operatingSystem: String
    let webPTypeSupported: Bool
    let results: [Result]
}
enum ProbeError: Error { case invalid(String) }

func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
func pixels(_ image: CGImage) throws -> Pixels {
    let width = image.width, height = image.height
    guard width > 0, height > 0, width <= 16384, height <= 16384 else {
        throw ProbeError.invalid("Invalid dimensions")
    }
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    try rgba.withUnsafeMutableBytes { storage in
        guard let context = CGContext(data: storage.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw ProbeError.invalid("Cannot create RGBA context")
        }
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    var transparent = 0, partial = 0, opaque = 0
    for offset in stride(from: 3, to: rgba.count, by: 4) {
        switch rgba[offset] {
        case 0: transparent += 1
        case 255: opaque += 1
        default: partial += 1
        }
    }
    return Pixels(width: width, height: height, rgbaSha256: digest(Data(rgba)),
        transparentPixels: transparent, partialAlphaPixels: partial, opaquePixels: opaque)
}

@main struct DecodeProbe {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3 else { throw ProbeError.invalid("input.json output.json required") }
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let supportedTypes = CGImageSourceCopyTypeIdentifiers() as! [String]
        guard supportedTypes.contains("org.webmproject.webp") else { throw ProbeError.invalid("ImageIO does not advertise WebP") }
        var results: [Result] = []
        for input in inputs {
            let result = try autoreleasepool {
                let data = try Data(contentsOf: URL(fileURLWithPath: input.path))
                guard digest(data) == input.sourceSha256 else { throw ProbeError.invalid("Source hash mismatch: \(input.assetId)") }
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                    CGImageSourceGetCount(source) == 1,
                    CGImageSourceGetType(source) as String? == "org.webmproject.webp",
                    let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
                    CGImageSourceGetStatus(source) == .statusComplete,
                    let uiImage = UIImage(data: data)?.cgImage,
                    let fileImage = UIImage(contentsOfFile: input.path)?.cgImage else {
                    throw ProbeError.invalid("ImageIO/UIImage decode failed: \(input.assetId)")
                }
                let io = try pixels(image), ui = try pixels(uiImage), uiFile = try pixels(fileImage)
                guard io == ui, io == uiFile else { throw ProbeError.invalid("Decoder pixel disagreement: \(input.assetId)") }
                return Result(assetId: input.assetId, sourceSha256: input.sourceSha256, imageIO: io, uiImage: ui, uiImageFile: uiFile)
            }
            results.append(result)
        }
        let report = Report(platform: "iOS Simulator", operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            webPTypeSupported: true, results: results)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(report).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
    }
}
