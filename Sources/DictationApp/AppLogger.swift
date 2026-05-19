import AppKit
import Foundation

@MainActor
final class AppLogger {
    enum Level: String {
        case info
        case warning
        case error
    }

    private let fileURL = AppPaths.logFile
    private let maxLines = 10
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    func log(_ level: Level, _ event: String, metadata: [String: String] = [:]) {
        do {
            try AppPaths.prepare()
            var line = "\(formatter.string(from: Date())) [\(level.rawValue)] \(event)"
            if !metadata.isEmpty {
                let suffix = metadata
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value.quotedForLog)" }
                    .joined(separator: " ")
                line += " \(suffix)"
            }

            var lines = existingLines()
            lines.append(line)
            lines = Array(lines.suffix(maxLines))
            try lines.joined(separator: "\n").appending("\n").write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            NSLog("Dictation logger failed: \(error.localizedDescription)")
        }
    }

    func openLogFile() {
        do {
            try AppPaths.prepare()
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try "Лог пока пуст.\n".write(to: fileURL, atomically: true, encoding: .utf8)
            }
            NSWorkspace.shared.open(fileURL)
        } catch {
            NSLog("Dictation log open failed: \(error.localizedDescription)")
        }
    }

    private func existingLines() -> [String] {
        guard
            let content = try? String(contentsOf: fileURL, encoding: .utf8),
            !content.isEmpty
        else {
            return []
        }

        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}

private extension String {
    var quotedForLog: String {
        if rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            return self
        }

        let escaped = replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
