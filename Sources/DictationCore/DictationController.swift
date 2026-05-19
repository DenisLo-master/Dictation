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
    private var isHotkeyCaptureActive = false
    private var pendingStartTask: Task<Void, Never>?
    private var insertionTargetApplication: NSRunningApplication?
    private var hasLoggedPendingAccessibilityBlock = false

    private let hotkeyHoldDebounceNanoseconds: UInt64 = 180_000_000
    private let minimumRecordingDuration: TimeInterval = 0.35

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
                let accessibility = self?.pasteInjector.requestAccessibilityPermission(openSettings: true) ?? false
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

    func setHotkeyCaptureActive(_ active: Bool) {
        isHotkeyCaptureActive = active
        if active {
            isHotkeyDown = false
            cancelPendingStart()
        }
    }

    func processPendingRecordings() {
        guard !isProcessingQueue, !isBusy else { return }
        guard settings.apiKey?.isEmpty == false else { return }

        let jobs = queue.loadPending()
        guard !jobs.isEmpty else { return }

        guard pasteInjector.hasAccessibilityPermission() else {
            onStatusChange?("Есть сохраненные записи. Разрешите Accessibility для вставки.")
            if !hasLoggedPendingAccessibilityBlock {
                logger.log(.warning, "pending_blocked_accessibility_permission_missing", metadata: [
                    "count": "\(jobs.count)"
                ])
                hasLoggedPendingAccessibilityBlock = true
            }
            return
        }
        hasLoggedPendingAccessibilityBlock = false

        isProcessingQueue = true
        onStatusChange?("Есть сохраненные записи. Отправляю...")

        Task {
            defer {
                isProcessingQueue = false
            }

            for job in jobs {
                guard !isBusy else { break }
                await process(job, visualFeedback: false, insertionTarget: nil)
            }
        }
    }

    private func handleHotkeyEvent(_ event: NSEvent) {
        guard !isHotkeyCaptureActive else { return }

        let hotkey = settings.hotkey

        if hotkey.isPressed(by: event), !isHotkeyDown {
            isHotkeyDown = true
            insertionTargetApplication = currentInsertionTarget()
            scheduleRecordingStart()
        } else if hotkey.isReleased(by: event), isHotkeyDown {
            isHotkeyDown = false
            if recorder.isRecording {
                finishRecording()
            } else {
                cancelPendingStart()
            }
        }
    }

    private func scheduleRecordingStart() {
        guard pendingStartTask == nil else { return }

        pendingStartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.hotkeyHoldDebounceNanoseconds ?? 180_000_000)
            await MainActor.run {
                guard let self, self.isHotkeyDown, !Task.isCancelled else { return }
                self.pendingStartTask = nil
                self.beginRecording()
            }
        }
    }

    private func cancelPendingStart() {
        pendingStartTask?.cancel()
        pendingStartTask = nil
    }

    private func currentInsertionTarget() -> NSRunningApplication? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != AppPaths.bundleIdentifier
        else {
            return nil
        }
        return app
    }

    private func beginRecording() {
        guard !isBusy, !isProcessingQueue else { return }

        guard settings.apiKey?.isEmpty == false else {
            onStatusChange?("Сначала сохраните OpenAI API key.")
            logger.log(.warning, "recording_blocked_no_token")
            return
        }

        guard ensureAccessibilityPermission(prompt: true, audioID: nil) else {
            overlay.flashFailureAndHide()
            insertionTargetApplication = nil
            return
        }

        do {
            overlay.showPreparing()
            try recorder.start()
            isBusy = true
            overlay.showRecording()
            onStatusChange?("Запись...")
            logger.log(.info, "recording_started", metadata: [
                "hotkey": settings.hotkey.displayName,
                "target": insertionTargetApplication?.localizedName ?? "frontmost"
            ])
            startLevelTimer()
        } catch {
            isBusy = false
            insertionTargetApplication = nil
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
            guard result.duration >= minimumRecordingDuration else {
                try? FileManager.default.removeItem(at: result.fileURL)
                isBusy = false
                insertionTargetApplication = nil
                overlay.hide()
                onStatusChange?("Слишком короткая запись удалена.")
                logger.log(.warning, "recording_discarded_too_short", metadata: [
                    "duration": String(format: "%.3fs", result.duration)
                ])
                return
            }

            let job = try queue.enqueue(tempFileURL: result.fileURL, duration: result.duration)
            overlay.setTranscribing()
            onStatusChange?("Запись сохранена. Распознаю...")
            logger.log(.info, "audio_enqueued", metadata: [
                "audio_id": job.id,
                "duration": String(format: "%.1fs", job.duration),
                "size": "\(job.byteSize)"
            ])

            Task {
                await process(job, visualFeedback: true, insertionTarget: insertionTargetApplication)
                isBusy = false
                insertionTargetApplication = nil
            }
        } catch {
            isBusy = false
            insertionTargetApplication = nil
            overlay.hide()
            onStatusChange?("Не удалось сохранить запись: \(error.localizedDescription)")
            logger.log(.error, "recording_finish_failed", metadata: ["message": error.localizedDescription])
        }
    }

    private func process(
        _ initialJob: RecordingJob,
        visualFeedback: Bool,
        insertionTarget: NSRunningApplication?
    ) async {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            if visualFeedback {
                overlay.hide()
            }
            onStatusChange?("OpenAI API key не найден.")
            logger.log(.warning, "transcription_blocked_no_token", metadata: ["audio_id": initialJob.id])
            return
        }

        var job = initialJob
        var chunksToCleanup: [AudioChunk] = []

        do {
            guard job.duration >= minimumRecordingDuration else {
                queue.complete(job)
                if visualFeedback {
                    overlay.flashFailureAndHide()
                }
                onStatusChange?("Слишком короткая запись удалена.")
                logger.log(.warning, "pending_discarded_too_short", metadata: [
                    "audio_id": job.id,
                    "duration": String(format: "%.3fs", job.duration),
                    "path": job.filePath
                ])
                return
            }

            guard ensureAccessibilityPermission(prompt: visualFeedback, audioID: initialJob.id) else {
                if visualFeedback {
                    overlay.flashFailureAndHide()
                }
                return
            }

            let text: String
            if let savedTranscript = job.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
               !savedTranscript.isEmpty {
                text = savedTranscript
                logger.log(.info, "transcript_loaded_from_queue", metadata: [
                    "audio_id": job.id,
                    "chars": "\(savedTranscript.count)"
                ])
            } else {
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
                chunksToCleanup = []
                text = TranscriptCombiner.combine(transcriptParts)
            }

            guard !text.isEmpty else {
                if visualFeedback {
                    overlay.hide()
                }
                onStatusChange?("Пустая транскрибация.")
                logger.log(.warning, "empty_transcription", metadata: ["audio_id": job.id])
                return
            }

            job = try queue.saveTranscript(text, for: job)

            do {
                let pasteTarget = try await pasteInjector.insert(text, into: insertionTarget)
                queue.complete(job)
                if visualFeedback {
                    overlay.flashSuccessAndHide()
                }
                onStatusChange?("Вставлено.")
                logger.log(.info, "transcription_inserted", metadata: [
                    "audio_id": job.id,
                    "chars": "\(text.count)",
                    "target": pasteTarget?.localizedName ?? "frontmost"
                ])
            } catch PasteInjector.PasteError.accessibilityPermissionMissing {
                _ = pasteInjector.requestAccessibilityPermission(openSettings: visualFeedback)
                if visualFeedback {
                    overlay.flashFailureAndHide()
                }
                onStatusChange?("Текст распознан и сохранен. Разрешите Accessibility для вставки.")
                logger.log(.error, "paste_blocked_accessibility_transcript_saved", metadata: [
                    "audio_id": job.id,
                    "attempt": "\(job.attempts)",
                    "path": job.filePath,
                    "chars": "\(text.count)"
                ])
                return
            } catch PasteInjector.PasteError.focusedTextInputMissing {
                queue.complete(job)
                if visualFeedback {
                    overlay.flashFailureAndHide()
                }
                onStatusChange?("Поле ввода не активно. Транскрипт удален.")
                logger.log(.warning, "transcription_discarded_no_focused_input", metadata: [
                    "audio_id": job.id,
                    "attempt": "\(job.attempts)",
                    "chars": "\(text.count)",
                    "target": insertionTarget?.localizedName ?? "frontmost"
                ])
                return
            }
        } catch {
            chunker.cleanup(chunksToCleanup, preserving: job.fileURL)
            if isTerminalAudioFileError(error) {
                queue.complete(job)
                if visualFeedback {
                    overlay.flashFailureAndHide()
                }
                onStatusChange?("Поврежденная запись удалена. Запишите заново.")
                logger.log(.error, "transcription_terminal_audio_discarded", metadata: [
                    "audio_id": job.id,
                    "attempt": "\(job.attempts)",
                    "path": job.filePath,
                    "message": error.localizedDescription
                ])
                return
            }

            if visualFeedback {
                overlay.flashFailureAndHide()
            }
            onStatusChange?("Ошибка. Аудио сохранено и будет повторено.")
            logger.log(.error, "transcription_failed_audio_preserved", metadata: [
                "audio_id": job.id,
                "attempt": "\(job.attempts)",
                "path": job.filePath,
                "message": error.localizedDescription
            ])
        }
    }

    private func isTerminalAudioFileError(_ error: Error) -> Bool {
        guard case OpenAITranscriber.TranscriberError.serverError(400, let body) = error else {
            return false
        }

        return body.contains("\"param\": \"file\"")
            || body.contains("\"param\":\"file\"")
            || body.localizedCaseInsensitiveContains("Audio file might be corrupted")
            || body.localizedCaseInsensitiveContains("unsupported")
    }

    private func ensureAccessibilityPermission(prompt: Bool, audioID: String?) -> Bool {
        guard pasteInjector.hasAccessibilityPermission() else {
            if prompt {
                _ = pasteInjector.requestAccessibilityPermission(openSettings: true)
            }

            var metadata = [
                "message": "Accessibility permission is required before transcription upload."
            ]
            if let audioID {
                metadata["audio_id"] = audioID
            }
            logger.log(.warning, "accessibility_permission_required", metadata: metadata)
            onStatusChange?("Разрешите Accessibility: Privacy & Security -> Accessibility -> Dictation.")
            return false
        }

        return true
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
