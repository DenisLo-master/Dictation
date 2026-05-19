import AVFoundation
import CryptoKit
import Foundation

public struct RecordingJob: Codable, Equatable, Sendable {
    public var id: String
    public var filePath: String
    public var createdAt: Date
    public var duration: TimeInterval
    public var byteSize: Int64
    public var sha256: String
    public var attempts: Int

    public init(
        id: String,
        filePath: String,
        createdAt: Date,
        duration: TimeInterval,
        byteSize: Int64,
        sha256: String,
        attempts: Int
    ) {
        self.id = id
        self.filePath = filePath
        self.createdAt = createdAt
        self.duration = duration
        self.byteSize = byteSize
        self.sha256 = sha256
        self.attempts = attempts
    }

    public var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
}

@MainActor
public final class RecordingQueue {
    public enum QueueError: LocalizedError {
        case missingAudioFile

        public var errorDescription: String? {
            switch self {
            case .missingAudioFile:
                "Saved audio file is missing."
            }
        }
    }

    private let pendingDirectory: URL

    init() {
        self.pendingDirectory = AppPaths.pendingDirectory
    }

    public init(pendingDirectory: URL) {
        self.pendingDirectory = pendingDirectory
    }

    public func enqueue(tempFileURL: URL, duration: TimeInterval) throws -> RecordingJob {
        try preparePendingDirectory()

        let id = UUID().uuidString
        let destination = pendingDirectory.appendingPathComponent("\(id).m4a")
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

    public func loadPending() -> [RecordingJob] {
        do {
            try preparePendingDirectory()
            let urls = try FileManager.default.contentsOfDirectory(
                at: pendingDirectory,
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

    public func markAttempt(_ job: RecordingJob) throws -> RecordingJob {
        var updated = job
        updated.attempts += 1
        try save(updated)
        return updated
    }

    public func complete(_ job: RecordingJob) {
        try? FileManager.default.removeItem(at: job.fileURL)
        try? FileManager.default.removeItem(at: metadataURL(for: job))
    }

    private func save(_ job: RecordingJob) throws {
        let data = try JSONEncoder().encode(job)
        try data.write(to: metadataURL(for: job), options: .atomic)
    }

    private func sha256Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func metadataURL(for job: RecordingJob) -> URL {
        pendingDirectory.appendingPathComponent("\(job.id).json")
    }

    private func preparePendingDirectory() throws {
        try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
    }
}
