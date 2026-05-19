import Foundation

final class AppSettings {
    private enum Keys {
        static let model = "transcriptionModel"
        static let hotkey = "dictationHotkey"
        static let language = "appLanguage"
    }

    private let keychain = KeychainStore(service: "dev.denis.Dictation", account: "openai-api-key")

    var apiKey: String? {
        try? keychain.read()
    }

    var model: String {
        get {
            UserDefaults.standard.string(forKey: Keys.model) ?? "gpt-4o-mini-transcribe"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.model)
        }
    }

    var hotkey: DictationHotkey {
        get {
            guard
                let data = UserDefaults.standard.data(forKey: Keys.hotkey),
                let hotkey = try? JSONDecoder().decode(DictationHotkey.self, from: data)
            else {
                return .defaultHotkey
            }
            return hotkey
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Keys.hotkey)
            }
        }
    }

    var language: AppLanguage {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: Keys.language),
                let language = AppLanguage(rawValue: rawValue)
            else {
                return .defaultLanguage
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.language)
        }
    }

    func saveAPIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try keychain.delete()
        } else {
            try keychain.save(trimmed)
        }
    }
}
