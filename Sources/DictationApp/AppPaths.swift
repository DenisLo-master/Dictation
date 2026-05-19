import Foundation

enum AppPaths {
    static let bundleIdentifier = "dev.denis.Dictation"

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dictation", isDirectory: true)
    }

    static var pendingDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Pending", isDirectory: true)
    }

    static var chunksDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Chunks", isDirectory: true)
    }

    static var logsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Dictation", isDirectory: true)
    }

    static var logFile: URL {
        logsDirectory.appendingPathComponent("Dictation.log")
    }

    static func prepare() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: chunksDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
}
