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
            let line = RollingLogStore.formatLine(
                date: Date(),
                level: level.rawValue,
                event: event,
                metadata: metadata,
                formatter: formatter
            )

            var lines = existingLines()
            lines = RollingLogStore.append(line, to: lines, maxLines: maxLines)
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

public enum RollingLogStore {
    public static func append(_ line: String, to existingLines: [String], maxLines: Int) -> [String] {
        Array((existingLines + [line]).suffix(max(0, maxLines)))
    }

    public static func formatLine(
        date: Date,
        level: String,
        event: String,
        metadata: [String: String],
        formatter: DateFormatter
    ) -> String {
        var line = "\(formatter.string(from: date)) [\(level)] \(event)"
        if !metadata.isEmpty {
            let suffix = metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.quotedForLog)" }
                .joined(separator: " ")
            line += " \(suffix)"
        }
        return line
    }
}

extension String {
    var quotedForLog: String {
        if rangeOfCharacter(from: .whitespacesAndNewlines) == nil {
            return self
        }

        let escaped = replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
