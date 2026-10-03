import SwiftUI

/// The existing UIKit navigation host needs an explicit first-responder request.
/// This text field stays mounted through every glass shape and scroll progress.
struct CatalogSearchField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "名称、编号或配置 ID"
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.clearButtonMode = .never
        field.accessibilityLabel = "搜索精灵"
        field.accessibilityIdentifier = "catalog-search-field"
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        if focused && !field.isFirstResponder {
            field.becomeFirstResponder()
        } else if !focused && field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CatalogSearchField

        init(_ parent: CatalogSearchField) { self.parent = parent }

        @objc func textChanged(_ field: UITextField) {
            let text = field.text ?? ""
            if parent.text != text { parent.text = text }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.focused { parent.focused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.focused { parent.focused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.focused = false
            textField.resignFirstResponder()
            return true
        }
    }
}
