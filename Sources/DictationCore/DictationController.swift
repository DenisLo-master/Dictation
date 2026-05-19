import AppKit
import AVFoundation

@MainActor
final class DictationController {
    var onStatusChange: ((String) -> Void)?

    private let settings: AppSettings
    private let recorder = AudioRecorder()
    private let transcriber = OpenAITranscriber()
    private let pasteInjector = PasteInjector()
    private let queue = RecordingQueue()
    private let chunker = AudioChunker()
    private let overlay: EqualizerOverlayController
    private let logger: AppLogger

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var levelTimer: Timer?
    private var retryTimer: Timer?
    private var isHotkeyDown = false
    private var isBusy = false
    private var isProcessingQueue = false

    init(settings: AppSettings, overlay: EqualizerOverlayController, logger: AppLogger) {
        self.settings = settings
        self.overlay = overlay
        self.logger = logger
    }

    func startHotkeyMonitoring() {
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handleHotkeyEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleHotkeyEvent(event)
            return event
        }

        retryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingRecordings()
            }
        }
    }

    func requestPermissions() {
        AudioRecorder.requestPermission { [weak self] granted in
            Task { @MainActor in
                let accessibility = self?.pasteInjector.requestAccessibilityPermission() ?? false
                if granted && accessibility {
                    self?.onStatusChange?("Разрешения выданы.")
                    self?.logger.log(.info, "permissions_ok")
                } else if granted {
                    self?.onStatusChange?("Микрофон разрешен. Подтвердите Accessibility.")
                    self?.logger.log(.warning, "accessibility_permission_missing")
                } else {
                    self?.onStatusChange?("Нужен доступ к микрофону и Accessibility.")
                    self?.logger.log(.warning, "microphone_permission_missing")
                }
            }
        }
    }

    func processPendingRecordings() {
        guard !isProcessingQueue, !isBusy else { return }
        guard settings.apiKey?.isEmpty == false else { return }

        let jobs = queue.loadPending()
        guard !jobs.isEmpty else { return }

        isProcessingQueue = true
        overlay.show()
        overlay.setTranscribing()
        onStatusChange?("Есть сохраненные записи. Отправляю...")

        Task {
            defer {
                isProcessingQueue = false
                overlay.hide()
            }

            for job in jobs {
                guard !isBusy else { break }
                await process(job)
            }
        }
    }

    private func handleHotkeyEvent(_ event: NSEvent) {
        let hotkey = settings.hotkey

        if hotkey.isPressed(by: event), !isHotkeyDown {
            isHotkeyDown = true
            beginRecording()
        } else if hotkey.isReleased(by: event), isHotkeyDown {
            isHotkeyDown = false
            finishRecording()
        }
    }

    private func beginRecording() {
        guard !isBusy, !isProcessingQueue else { return }

        guard settings.apiKey?.isEmpty == false else {
            onStatusChange?("Сначала сохраните OpenAI API key.")
            logger.log(.warning, "recording_blocked_no_token")
            return
        }

        do {
            try recorder.start()
            isBusy = true
            overlay.show()
            onStatusChange?("Запись...")
            logger.log(.info, "recording_started", metadata: ["hotkey": settings.hotkey.displayName])
            startLevelTimer()
        } catch {
            isBusy = false
            overlay.hide()
            onStatusChange?("Не удалось начать запись: \(error.localizedDescription)")
            logger.log(.error, "recording_start_failed", metadata: ["message": error.localizedDescription])
        }
    }

    private func finishRecording() {
        guard isBusy, recorder.isRecording else { return }
        stopLevelTimer()

        do {
            let result = try recorder.stop()
            let job = try queue.enqueue(tempFileURL: result.fileURL, duration: result.duration)
            overlay.setTranscribing()
            onStatusChange?("Запись сохранена. Распознаю...")
            logger.log(.info, "audio_enqueued", metadata: [
                "audio_id": job.id,
                "duration": String(format: "%.1fs", job.duration),
                "size": "\(job.byteSize)"
            ])

            Task {
                await process(job)
                isBusy = false
            }
        } catch {
            isBusy = false
            overlay.hide()
            onStatusChange?("Не удалось сохранить запись: \(error.localizedDescription)")
            logger.log(.error, "recording_finish_failed", metadata: ["message": error.localizedDescription])
        }
    }

    private func process(_ initialJob: RecordingJob) async {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            overlay.hide()
            onStatusChange?("OpenAI API key не найден.")
            logger.log(.warning, "transcription_blocked_no_token", metadata: ["audio_id": initialJob.id])
            return
        }

        var job = initialJob
        var chunksToCleanup: [AudioChunk] = []

        do {
            job = try queue.markAttempt(job)
            let chunks = try await chunker.chunks(for: job)
            chunksToCleanup = chunks
            logger.log(.info, "transcription_upload_started", metadata: [
                "audio_id": job.id,
                "attempt": "\(job.attempts)",
                "chunks": "\(chunks.count)",
                "sha256": job.sha256
            ])

            var transcriptParts: [String] = []
            for chunk in chunks {
                let text = try await transcriber.transcribe(
                    fileURL: chunk.fileURL,
                    apiKey: apiKey,
                    model: settings.model
                )
                transcriptParts.append(text)
                logger.log(.info, "chunk_transcribed", metadata: [
                    "audio_id": job.id,
                    "chunk": "\(chunk.index)",
                    "start": String(format: "%.1f", chunk.start),
                    "end": String(format: "%.1f", chunk.end)
                ])
            }

            chunker.cleanup(chunks, preserving: job.fileURL)
            let text = TranscriptCombiner.combine(transcriptParts)

            guard !text.isEmpty else {
                overlay.hide()
                onStatusChange?("Пустая транскрибация.")
                logger.log(.warning, "empty_transcription", metadata: ["audio_id": job.id])
                return
            }

            pasteInjector.insert(text)
            queue.complete(job)
            overlay.flashSuccessAndHide()
            onStatusChange?("Вставлено.")
            logger.log(.info, "transcription_inserted", metadata: [
                "audio_id": job.id,
                "chars": "\(text.count)"
            ])
        } catch {
            chunker.cleanup(chunksToCleanup, preserving: job.fileURL)
            overlay.flashFailureAndHide()
            onStatusChange?("Ошибка. Аудио сохранено и будет повторено.")
            logger.log(.error, "transcription_failed_audio_preserved", metadata: [
                "audio_id": job.id,
                "attempt": "\(job.attempts)",
                "path": job.filePath,
                "message": error.localizedDescription
            ])
        }
    }

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.overlay.update(level: self.recorder.currentLevel())
            }
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}
