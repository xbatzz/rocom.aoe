import SwiftUI

/// A top-level title that scrolls with the page's content.
struct CompanionPageHeader: View {
    let title: String
    var subtitle: String? = nil
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifier)-title")
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("\(identifier)-count")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
