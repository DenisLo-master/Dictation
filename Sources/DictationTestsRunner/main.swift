import AppKit
import Carbon
import CryptoKit
import DictationCore
import Foundation

typealias AsyncTest = () async throws -> Void

struct TestCase {
    let name: String
    let run: AsyncTest
}

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
enum DictationTestsRunner {
    static func main() async {
        let tests: [TestCase] = [
            TestCase(name: "hotkey captures Fn/Globe and detects down/up", run: testFnHotkey),
            TestCase(name: "hotkey captures hold modifiers and F13-F20", run: testHoldHotkeys),
            TestCase(name: "OpenAI model list filters and prioritizes transcription models", run: testModelFiltering),
            TestCase(name: "transcript combiner removes overlap without dropping words", run: testTranscriptCombiner),
            TestCase(name: "transcript formatter adds leading insertion space", run: testTranscriptInsertionFormatter),
            TestCase(name: "audio chunk planner preserves overlap boundaries", run: testChunkPlanner),
            TestCase(name: "audio level meter maps voice volume without fake movement", run: testAudioLevelMeter),
            TestCase(name: "recording queue persists, retries, and completes audio jobs", run: testRecordingQueue),
            TestCase(name: "rolling logger keeps last ten entries and quotes metadata", run: testRollingLogger),
            TestCase(name: "single-instance policy ignores current and terminated apps", run: testSingleInstancePolicy),
            TestCase(name: "app metadata footer contains version and developer", run: testAppMetadataFooter)
        ]

        var failures: [(String, Error)] = []

        for test in tests {
            do {
                try await test.run()
                print("PASS \(test.name)")
            } catch {
                failures.append((test.name, error))
                print("FAIL \(test.name): \(error)")
            }
        }

        if failures.isEmpty {
            print("All \(tests.count) tests passed.")
            exit(0)
        } else {
            print("\(failures.count) of \(tests.count) tests failed.")
            exit(1)
        }
    }
}

func testFnHotkey() async throws {
    let fnDown = try makeEvent(type: .flagsChanged, keyCode: UInt16(kVK_Function), flags: [.function])
    let fnDownWithoutFunctionKeyCode = try makeEvent(type: .flagsChanged, keyCode: 0, flags: [.function])
    let fnUp = try makeEvent(type: .flagsChanged, keyCode: UInt16(kVK_Function), flags: [])

    let captured = try require(DictationHotkey.capture(from: fnDown), "Expected Fn hotkey capture")
    let capturedWithoutFunctionKeyCode = try require(
        DictationHotkey.capture(from: fnDownWithoutFunctionKeyCode),
        "Expected Fn hotkey capture even when macOS does not report kVK_Function"
    )
    try expect(captured == .defaultHotkey, "Fn capture should equal default hotkey")
    try expect(capturedWithoutFunctionKeyCode == .defaultHotkey, "Fn capture should be based on .function flag")
    try expect(captured.isPressed(by: fnDown), "Fn down event should be pressed")
    try expect(captured.isPressed(by: fnDownWithoutFunctionKeyCode), "Fn should trigger even with a non-Fn keyCode")
    try expect(captured.isReleased(by: fnUp), "Fn up event should be released")
}

func testHoldHotkeys() async throws {
    let leftCommandDown = try makeEvent(type: .flagsChanged, keyCode: UInt16(kVK_Command), flags: [.command])
    let leftCommandUp = try makeEvent(type: .flagsChanged, keyCode: UInt16(kVK_Command), flags: [])
    let rightOptionDown = try makeEvent(type: .flagsChanged, keyCode: UInt16(kVK_RightOption), flags: [.option])
    let leftControlDown = try makeEvent(type: .flagsChanged, keyCode: UInt16(kVK_Control), flags: [.control])
    let f19Down = try makeEvent(type: .keyDown, keyCode: UInt16(kVK_F19), flags: [])
    let f19Repeat = try makeEvent(type: .keyDown, keyCode: UInt16(kVK_F19), flags: [], isARepeat: true)
    let f19Up = try makeEvent(type: .keyUp, keyCode: UInt16(kVK_F19), flags: [])
    let aDown = try makeEvent(type: .keyDown, keyCode: 0, flags: [])

    let leftCommand = try require(DictationHotkey.capture(from: leftCommandDown), "Expected left command hotkey capture")
    let rightOption = try require(DictationHotkey.capture(from: rightOptionDown), "Expected right option hotkey capture")
    let leftControl = try require(DictationHotkey.capture(from: leftControlDown), "Expected left control hotkey capture")
    let captured = try require(DictationHotkey.capture(from: f19Down), "Expected F19 hotkey capture")

    try expect(leftCommand.displayName == "Left Command", "Left command should be captured distinctly")
    try expect(leftCommand.isPressed(by: leftCommandDown), "Left command down should press")
    try expect(leftCommand.isReleased(by: leftCommandUp), "Left command up should release")
    try expect(rightOption.displayName == "Right Option", "Right option should still be supported")
    try expect(leftControl.displayName == "Left Control", "Left control should be supported")
    try expect(captured.displayName == "F19", "Expected display name F19")
    try expect(captured.isPressed(by: f19Down), "F19 keyDown should press")
    try expect(!captured.isPressed(by: f19Repeat), "F19 repeat should not retrigger")
    try expect(captured.isReleased(by: f19Up), "F19 keyUp should release")
    try expect(DictationHotkey.capture(from: aDown) == nil, "Ordinary letter keys should be rejected")
}

func testModelFiltering() async throws {
    let models = OpenAIModelService.transcriptionModels(from: [
        "gpt-4o",
        "gpt-4o-transcribe",
        "whisper-1",
        "gpt-4o-mini-transcribe",
        "foo-transcription-preview",
        "gpt-4o-transcribe-diarize"
    ])

    try expect(
        models.map(\.id) == [
            "gpt-4o-mini-transcribe",
            "gpt-4o-transcribe",
            "gpt-4o-transcribe-diarize",
            "whisper-1",
            "foo-transcription-preview"
        ],
        "Transcription models should be filtered and preferred models prioritized"
    )
    try expect(models.first?.badge == "fast", "Mini model should be marked fast")
    try expect(models[2].badge == "speakers", "Diarize model should be marked as speaker-aware")
    try expect(AppText.modelBadge(models[2].badge, language: .russian) == "спикеры", "Model badges should localize for the UI")
}

func testTranscriptCombiner() async throws {
    try expect(
        TranscriptCombiner.combine(["hello brave new", "brave new world"]) == "hello brave new world",
        "Overlapping chunk text should not duplicate words"
    )
    try expect(
        TranscriptCombiner.combine([" first part ", "", "second part"]) == "first part second part",
        "Empty parts should be ignored and whitespace trimmed"
    )
    try expect(
        TranscriptCombiner.combine(["alpha beta", "gamma delta"]) == "alpha beta gamma delta",
        "Non-overlapping text should be joined with one space"
    )
}

func testTranscriptInsertionFormatter() async throws {
    try expect(
        TranscriptInsertionFormatter.format("привет") == " привет",
        "Inserted transcript should start with one leading space"
    )
}

func testChunkPlanner() async throws {
    let small = AudioChunker.plan(duration: 8, byteSize: 1024)
    try expect(small == [AudioChunkPlan(index: 0, start: 0, end: 8)], "Small audio should stay as one chunk")

    let large = AudioChunker.plan(
        duration: 120,
        byteSize: 50 * 1024 * 1024,
        maxChunkBytes: 24 * 1024 * 1024,
        overlapSeconds: 1
    )
    try expect(large.count == 3, "50 MB should split into three chunks with a 24 MB limit")
    try expect(large[0] == AudioChunkPlan(index: 0, start: 0, end: 41), "First chunk should include forward overlap")
    try expect(large[1] == AudioChunkPlan(index: 1, start: 39, end: 81), "Middle chunk should overlap both sides")
    try expect(large[2] == AudioChunkPlan(index: 2, start: 79, end: 120), "Last chunk should include backward overlap only")
}

func testAudioLevelMeter() async throws {
    let silence = AudioLevelMeter.normalizedLevel(averagePower: -80, peakPower: -80)
    let quiet = AudioLevelMeter.normalizedLevel(averagePower: -48, peakPower: -42)
    let normalSpeech = AudioLevelMeter.normalizedLevel(averagePower: -24, peakPower: -12)
    let loud = AudioLevelMeter.normalizedLevel(averagePower: -24, peakPower: -16)

    try expect(silence == 0, "Silence should be gated to zero")
    try expect(quiet > silence, "Quiet voice should register above silence")
    try expect(loud > quiet, "Louder voice should produce a higher level")
    try expect(normalSpeech < 0.75, "Normal speech should not pin the equalizer to the top")

    var history = VoiceLevelHistory(columnCount: 4)
    let initial = history.levels
    let afterSilence = history.push(0)
    let afterLoud = history.push(0.9)
    let activeColumns = afterLoud.filter { $0 > 0.3 }.count
    let afterDrop = history.push(0)

    try expect(afterSilence.last ?? 1 <= initial.last ?? 1, "Silence should not create decorative movement")
    try expect(activeColumns >= 3, "Voice should drive the whole equalizer, not only a delayed history column")
    try expect((afterDrop.max() ?? 1) < (afterLoud.max() ?? 0), "Equalizer should release quickly when voice drops")
}

func testRecordingQueue() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("DictationQueueTests-\(UUID().uuidString)", isDirectory: true)
    let pending = root.appendingPathComponent("Pending", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let tempAudio = root.appendingPathComponent("sample.m4a")
    let audioData = Data("audio payload".utf8)
    try audioData.write(to: tempAudio)

    let expectedSHA = SHA256.hash(data: audioData).map { String(format: "%02x", $0) }.joined()

    try await MainActor.run {
        let queue = RecordingQueue(pendingDirectory: pending)
        let job = try queue.enqueue(tempFileURL: tempAudio, duration: 3.5)

        try expect(FileManager.default.fileExists(atPath: job.filePath), "Enqueued audio should be moved into pending storage")
        try expect(!FileManager.default.fileExists(atPath: tempAudio.path), "Original temp audio should be moved, not copied")
        try expect(job.byteSize == Int64(audioData.count), "Job should record byte size")
        try expect(job.sha256 == expectedSHA, "Job should record SHA-256 for delivery verification")

        let pendingJobs = queue.loadPending()
        try expect(pendingJobs.count == 1, "Queue should reload persisted pending job")
        try expect(pendingJobs[0].id == job.id, "Reloaded job should match original id")

        let attempted = try queue.markAttempt(job)
        try expect(attempted.attempts == 1, "Mark attempt should increment retry count")
        try expect(queue.loadPending()[0].attempts == 1, "Retry count should persist to disk")

        queue.complete(attempted)
        try expect(queue.loadPending().isEmpty, "Completed job should be removed from queue")
        try expect(!FileManager.default.fileExists(atPath: attempted.filePath), "Completed audio file should be deleted")
    }
}

func testRollingLogger() async throws {
    let lines = (0..<12).reduce(into: [String]()) { result, index in
        result = RollingLogStore.append("line-\(index)", to: result, maxLines: 10)
    }

    try expect(lines.count == 10, "Logger should keep only last 10 lines")
    try expect(lines.first == "line-2", "Logger should drop oldest lines")
    try expect(lines.last == "line-11", "Logger should keep newest line")

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let line = RollingLogStore.formatLine(
        date: Date(timeIntervalSince1970: 0),
        level: "error",
        event: "transcription_failed",
        metadata: ["message": "Bad gateway", "audio_id": "A1"],
        formatter: formatter
    )

    try expect(
        line == "1970-01-01 00:00:00 [error] transcription_failed audio_id=A1 message=\"Bad gateway\"",
        "Logger should sort metadata keys and quote values with spaces"
    )
}

func testSingleInstancePolicy() async throws {
    let apps = [
        RunningApplicationInfo(processIdentifier: 100, bundleIdentifier: "dev.denis.Dictation", isTerminated: false),
        RunningApplicationInfo(processIdentifier: 101, bundleIdentifier: "dev.denis.Dictation", isTerminated: true),
        RunningApplicationInfo(processIdentifier: 102, bundleIdentifier: "com.example.Other", isTerminated: false)
    ]

    let duplicate = SingleInstancePolicy.existingInstance(
        currentProcessIdentifier: 99,
        bundleIdentifier: "dev.denis.Dictation",
        runningApplications: apps
    )
    try expect(duplicate?.processIdentifier == 100, "Should return an existing live app with the same bundle id")

    let none = SingleInstancePolicy.existingInstance(
        currentProcessIdentifier: 100,
        bundleIdentifier: "dev.denis.Dictation",
        runningApplications: apps
    )
    try expect(none == nil, "Should ignore the current process and terminated apps")
}

func testAppMetadataFooter() async throws {
    let footer = AppMetadata.footerText(version: "1.2.3", language: .russian)
    try expect(footer.contains("Версия: 1.2.3"), "Footer should include localized version")
    try expect(footer.contains("Разработчик: flo.production.studio@gmail.com"), "Footer should include developer email")
}

func makeEvent(
    type: NSEvent.EventType,
    keyCode: UInt16,
    flags: NSEvent.ModifierFlags,
    isARepeat: Bool = false
) throws -> NSEvent {
    try require(
        NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: isARepeat,
            keyCode: keyCode
        ),
        "Could not create NSEvent"
    )
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure.failed(message)
    }
}

func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else {
        throw TestFailure.failed(message)
    }
    return value
}
