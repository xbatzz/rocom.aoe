import SwiftUI

/// Native section controls stay above scrolling content. Large text uses a menu
/// so section names remain readable without compressing the segmented control.
struct CompanionTabBar<Selection: Hashable & RawRepresentable>: View where Selection.RawValue == String {
    let title: String
    @Binding var selection: Selection
    let options: [Selection]
    let identifier: String
    var label: (Selection) -> String = { $0.rawValue }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    picker.pickerStyle(.menu).tint(.primary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            } else {
                picker.pickerStyle(.segmented)
            }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier(identifier)
    }

    private var picker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
    }
}
