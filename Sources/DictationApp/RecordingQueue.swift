import AVFoundation
import CryptoKit
import Foundation

struct RecordingJob: Codable, Equatable {
    var id: String
    var filePath: String
    var createdAt: Date
    var duration: TimeInterval
    var byteSize: Int64
    var sha256: String
    var attempts: Int

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var metadataURL: URL {
        AppPaths.pendingDirectory.appendingPathComponent("\(id).json")
    }
}

@MainActor
final class RecordingQueue {
    enum QueueError: LocalizedError {
        case missingAudioFile

        var errorDescription: String? {
            switch self {
            case .missingAudioFile:
                "Saved audio file is missing."
            }
        }
    }

    func enqueue(tempFileURL: URL, duration: TimeInterval) throws -> RecordingJob {
        try AppPaths.prepare()

        let id = UUID().uuidString
        let destination = AppPaths.pendingDirectory.appendingPathComponent("\(id).m4a")
        try FileManager.default.moveItem(at: tempFileURL, to: destination)

        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let byteSize = attributes[.size] as? Int64 ?? 0
        let sha256 = try sha256Hex(for: destination)

        let job = RecordingJob(
            id: id,
            filePath: destination.path,
            createdAt: Date(),
            duration: duration,
            byteSize: byteSize,
            sha256: sha256,
            attempts: 0
        )
        try save(job)
        return job
    }

    func loadPending() -> [RecordingJob] {
        do {
            try AppPaths.prepare()
            let urls = try FileManager.default.contentsOfDirectory(
                at: AppPaths.pendingDirectory,
                includingPropertiesForKeys: nil
            )
            return urls
                .filter { $0.pathExtension == "json" }
                .compactMap { try? Data(contentsOf: $0) }
                .compactMap { try? JSONDecoder().decode(RecordingJob.self, from: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.filePath) }
                .sorted { $0.createdAt < $1.createdAt }
        } catch {
            return []
        }
    }

    func markAttempt(_ job: RecordingJob) throws -> RecordingJob {
        var updated = job
        updated.attempts += 1
        try save(updated)
        return updated
    }

    func complete(_ job: RecordingJob) {
        try? FileManager.default.removeItem(at: job.fileURL)
        try? FileManager.default.removeItem(at: job.metadataURL)
    }

    private func save(_ job: RecordingJob) throws {
        let data = try JSONEncoder().encode(job)
        try data.write(to: job.metadataURL, options: .atomic)
    }

    private func sha256Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
