import AVFoundation
import Foundation

public struct AudioChunk: Sendable {
    public var index: Int
    public var start: TimeInterval
    public var end: TimeInterval
    public var fileURL: URL

    public init(index: Int, start: TimeInterval, end: TimeInterval, fileURL: URL) {
        self.index = index
        self.start = start
        self.end = end
        self.fileURL = fileURL
    }
}

public struct AudioChunkPlan: Equatable, Sendable {
    public var index: Int
    public var start: TimeInterval
    public var end: TimeInterval

    public init(index: Int, start: TimeInterval, end: TimeInterval) {
        self.index = index
        self.start = start
        self.end = end
    }
}

public struct AudioChunker: Sendable {
    private let maxChunkBytes: Int64 = 24 * 1024 * 1024
    private let overlapSeconds: TimeInterval = 1.0

    public init() {}

    public static func plan(
        duration: TimeInterval,
        byteSize: Int64,
        maxChunkBytes: Int64 = 24 * 1024 * 1024,
        overlapSeconds: TimeInterval = 1.0
    ) -> [AudioChunkPlan] {
        guard byteSize > maxChunkBytes else {
            return [AudioChunkPlan(index: 0, start: 0, end: duration)]
        }

        let chunkCount = max(2, Int(ceil(Double(byteSize) / Double(maxChunkBytes))))
        let baseDuration = max(10, duration / Double(chunkCount))

        return (0..<chunkCount).map { index in
            AudioChunkPlan(
                index: index,
                start: max(0, Double(index) * baseDuration - (index == 0 ? 0 : overlapSeconds)),
                end: min(duration, Double(index + 1) * baseDuration + overlapSeconds)
            )
        }
    }

    func chunks(for job: RecordingJob) async throws -> [AudioChunk] {
        guard job.byteSize > maxChunkBytes else {
            return [
                AudioChunk(index: 0, start: 0, end: job.duration, fileURL: job.fileURL)
            ]
        }

        try AppPaths.prepare()
        var chunks: [AudioChunk] = []

        for plan in Self.plan(duration: job.duration, byteSize: job.byteSize, maxChunkBytes: maxChunkBytes, overlapSeconds: overlapSeconds) {
            let outputURL = AppPaths.chunksDirectory
                .appendingPathComponent("\(job.id)-chunk-\(plan.index)")
                .appendingPathExtension("m4a")

            try? FileManager.default.removeItem(at: outputURL)
            try await exportChunk(inputURL: job.fileURL, outputURL: outputURL, start: plan.start, end: plan.end)
            chunks.append(AudioChunk(index: plan.index, start: plan.start, end: plan.end, fileURL: outputURL))
        }

        return chunks
    }

    func cleanup(_ chunks: [AudioChunk], preserving originalURL: URL) {
        for chunk in chunks where chunk.fileURL != originalURL {
            try? FileManager.default.removeItem(at: chunk.fileURL)
        }
    }

    private func exportChunk(inputURL: URL, outputURL: URL, start: TimeInterval, end: TimeInterval) async throws {
        let asset = AVURLAsset(url: inputURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "Dictation.AudioChunker", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create audio export session."
            ])
        }

        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )

        await withCheckedContinuation { continuation in
            session.exportAsynchronously {
                continuation.resume()
            }
        }

        if session.status != .completed {
            throw session.error ?? NSError(domain: "Dictation.AudioChunker", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Audio chunk export failed."
            ])
        }
    }
}

public enum TranscriptCombiner {
    public static func combine(_ parts: [String]) -> String {
        parts.reduce("") { combined, next in
            merge(combined, next)
        }
    }

    private static func merge(_ left: String, _ right: String) -> String {
        let cleanRight = right.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty else { return cleanRight }
        guard !cleanRight.isEmpty else { return left }

        let leftWords = left.split(separator: " ").map(String.init)
        let rightWords = cleanRight.split(separator: " ").map(String.init)
        let maxOverlap = min(12, leftWords.count, rightWords.count)

        for count in stride(from: maxOverlap, through: 1, by: -1) {
            let suffix = leftWords.suffix(count).map { $0.lowercased() }
            let prefix = rightWords.prefix(count).map { $0.lowercased() }
            if suffix == prefix {
                return (leftWords + rightWords.dropFirst(count)).joined(separator: " ")
            }
        }

        return "\(left) \(cleanRight)"
    }
}

public enum TranscriptInsertionFormatter {
    public static func format(_ transcript: String) -> String {
        " \(transcript)"
    }
}
