import Foundation

public enum AppMetadata {
    public static let developerEmail = "denis.lkg@gmail.com"

    public static func version(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    public static func footerText(version: String = version(), language: AppLanguage = .defaultLanguage) -> String {
        AppText.footer(version: version, developerEmail: developerEmail, language: language)
    }
}
