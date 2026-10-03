import Foundation

/// Quantized sampling avoids invalidating the grid on every scroll frame.
@MainActor
final class CatalogScrollSample {
    var isUserScrolling = false
    private var previous: (bucket: Int, time: ContinuousClock.Instant)?

    func isFast(at bucket: Int) -> Bool {
        let now = ContinuousClock.now
        defer { previous = (bucket, now) }
        guard isUserScrolling, let previous else { return false }
        let duration = previous.time.duration(to: now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        guard seconds > 0 else { return false }
        return Double(abs(bucket - previous.bucket) * 64) / seconds > 700
    }

    func reset() { previous = nil }
}
