/// Metadata and canonical relations are always checked. Image bytes can wait until use.
public enum AssetValidationMode: Sendable {
    /// Package validation and probes check every image before returning a snapshot.
    case eager
    /// The installed app checks only requested images, before returning their URLs.
    case onDemand
}
