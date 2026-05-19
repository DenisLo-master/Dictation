import Foundation

public enum FocusedTextInputPolicy {
    private static let writableRoles: Set<String> = [
        "AXTextArea",
        "AXTextField",
        "AXComboBox",
        "AXSearchField"
    ]

    private static let writableSubroles: Set<String> = [
        "AXSecureTextField",
        "AXSearchField"
    ]

    public static func isWritable(role: String?, subrole: String?) -> Bool {
        if let role, writableRoles.contains(role) {
            return true
        }

        if let subrole, writableSubroles.contains(subrole) {
            return true
        }

        return false
    }
}
