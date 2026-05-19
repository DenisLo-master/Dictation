import AppKit
import Carbon
import Foundation

struct DictationHotkey: Codable, Equatable {
    enum Kind: String, Codable {
        case modifier
        case functionKey
    }

    var keyCode: UInt16
    var modifierFlagRawValue: UInt
    var displayName: String
    var kind: Kind

    static let defaultHotkey = DictationHotkey(
        keyCode: UInt16(kVK_Function),
        modifierFlagRawValue: NSEvent.ModifierFlags.function.rawValue,
        displayName: "Fn / Globe",
        kind: .modifier
    )

    var modifierFlag: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagRawValue)
    }

    func isPressed(by event: NSEvent) -> Bool {
        switch kind {
        case .modifier:
            return event.type == .flagsChanged
                && event.keyCode == keyCode
                && event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifierFlag)
        case .functionKey:
            return event.type == .keyDown
                && event.keyCode == keyCode
                && !event.isARepeat
        }
    }

    func isReleased(by event: NSEvent) -> Bool {
        switch kind {
        case .modifier:
            return event.type == .flagsChanged
                && event.keyCode == keyCode
                && !event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifierFlag)
        case .functionKey:
            return event.type == .keyUp && event.keyCode == keyCode
        }
    }

    static func capture(from event: NSEvent) -> DictationHotkey? {
        if event.type == .flagsChanged {
            return modifierHotkey(from: event)
        }

        if event.type == .keyDown, isAllowedFunctionKey(event.keyCode) {
            return DictationHotkey(
                keyCode: event.keyCode,
                modifierFlagRawValue: 0,
                displayName: functionKeyName(event.keyCode),
                kind: .functionKey
            )
        }

        return nil
    }

    static func invalidReason(for event: NSEvent) -> String {
        if event.type == .keyDown {
            return "Выберите Fn, правый modifier или F13-F20."
        }
        return "Эта клавиша не подходит для удержания."
    }

    private static func modifierHotkey(from event: NSEvent) -> DictationHotkey? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch Int(event.keyCode) {
        case kVK_Function where flags.contains(.function):
            return .defaultHotkey
        case kVK_RightOption where flags.contains(.option):
            return DictationHotkey(
                keyCode: event.keyCode,
                modifierFlagRawValue: NSEvent.ModifierFlags.option.rawValue,
                displayName: "Right Option",
                kind: .modifier
            )
        case kVK_RightControl where flags.contains(.control):
            return DictationHotkey(
                keyCode: event.keyCode,
                modifierFlagRawValue: NSEvent.ModifierFlags.control.rawValue,
                displayName: "Right Control",
                kind: .modifier
            )
        case kVK_RightCommand where flags.contains(.command):
            return DictationHotkey(
                keyCode: event.keyCode,
                modifierFlagRawValue: NSEvent.ModifierFlags.command.rawValue,
                displayName: "Right Command",
                kind: .modifier
            )
        default:
            return nil
        }
    }

    private static func isAllowedFunctionKey(_ keyCode: UInt16) -> Bool {
        let code = Int(keyCode)
        return code == kVK_F13
            || code == kVK_F14
            || code == kVK_F15
            || code == kVK_F16
            || code == kVK_F17
            || code == kVK_F18
            || code == kVK_F19
            || code == kVK_F20
    }

    private static func functionKeyName(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_F13: "F13"
        case kVK_F14: "F14"
        case kVK_F15: "F15"
        case kVK_F16: "F16"
        case kVK_F17: "F17"
        case kVK_F18: "F18"
        case kVK_F19: "F19"
        case kVK_F20: "F20"
        default: "F\(keyCode)"
        }
    }
}
