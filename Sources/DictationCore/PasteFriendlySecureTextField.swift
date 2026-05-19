import AppKit
import Carbon

final class PasteFriendlySecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        switch Int(event.keyCode) {
        case kVK_ANSI_A:
            return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
        case kVK_ANSI_C:
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case kVK_ANSI_V:
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        case kVK_ANSI_X:
            return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
