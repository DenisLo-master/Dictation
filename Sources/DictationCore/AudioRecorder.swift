import AVFoundation
import Foundation

struct RecordingResult {
    let fileURL: URL
    let duration: TimeInterval
}

final class AudioRecorder {
    enum RecorderError: LocalizedError {
        case microphoneDenied
        case recorderUnavailable

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                "Microphone access is not allowed."
            case .recorderUnavailable:
                "Audio recorder is unavailable."
            }
        }
    }

    private var recorder: AVAudioRecorder?
    private var outputURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    static func requestPermission(_ completion: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    func start() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) != .denied else {
            throw RecorderError.microphoneDenied
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()

        self.recorder = recorder
        outputURL = url
    }

    func stop() throws -> RecordingResult {
        guard let recorder, let outputURL else {
            throw RecorderError.recorderUnavailable
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        self.outputURL = nil

        return RecordingResult(fileURL: outputURL, duration: duration)
    }

    func currentLevel() -> CGFloat {
        guard let recorder else { return 0 }

        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        guard averagePower.isFinite, peakPower.isFinite else { return 0 }

        let averageLinear = pow(10, averagePower / 20)
        let peakLinear = pow(10, peakPower / 20)
        let dbLift = max(0, min(1, (averagePower + 56) / 38))
        let boosted = max(averageLinear * 8.0, peakLinear * 4.5, dbLift)
        return CGFloat(max(0.03, min(1.0, boosted)))
    }
}
