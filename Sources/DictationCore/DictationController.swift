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
    private var isHotkeyDown = false
    private var isBusy = false
    private var isHotkeyCaptureActive = false
    private var pendingStartTask: Task<Void, Never>?
    private var insertionTargetApplication: NSRunningApplication?

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

    }

    func requestPermissions() {
        AudioRecorder.requestPermission { [weak self] granted in
            Task { @MainActor in
                let accessibility = self?.pasteInjector.requestAccessibilityPermission(openSettings: true) ?? false
                let language = self?.settings.language ?? .defaultLanguage
                if granted && accessibility {
                    self?.onStatusChange?(AppText.permissionsOk(language))
                    self?.logger.log(.info, "permissions_ok")
                } else if granted {
                    self?.onStatusChange?(AppText.microphoneOkAccessibilityNeeded(language))
                    self?.logger.log(.warning, "accessibility_permission_missing")
                } else {
                    self?.onStatusChange?(AppText.permissionsNeeded(language))
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

    func discardPendingRecordings() {
        let jobs = queue.loadPending()
        guard !jobs.isEmpty else { return }

        for job in jobs {
            queue.complete(job)
        }

        logger.log(.warning, "pending_recordings_discarded_on_launch", metadata: [
            "count": "\(jobs.count)"
        ])
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
        guard !isBusy else { return }

        guard settings.apiKey?.isEmpty == false else {
            onStatusChange?(AppText.saveTokenFirst(settings.language))
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
            onStatusChange?(AppText.recording(settings.language))
            logger.log(.info, "recording_started", metadata: [
                "hotkey": settings.hotkey.displayName,
                "target": insertionTargetApplication?.localizedName ?? "frontmost"
            ])
            startLevelTimer()
        } catch {
            isBusy = false
            insertionTargetApplication = nil
            overlay.hide()
            onStatusChange?(AppText.recordingStartFailed(error.localizedDescription, language: settings.language))
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
                onStatusChange?(AppText.recordingTooShort(settings.language))
                logger.log(.warning, "recording_discarded_too_short", metadata: [
                    "duration": String(format: "%.3fs", result.duration)
                ])
                return
            }

            let job = try queue.enqueue(tempFileURL: result.fileURL, duration: result.duration)
            overlay.setTranscribing()
            onStatusChange?(AppText.transcribing(settings.language))
            logger.log(.info, "audio_captured", metadata: [
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
            onStatusChange?(AppText.recordingFinishFailed(error.localizedDescription, language: settings.language))
            logger.log(.error, "recording_finish_failed", metadata: ["message": error.localizedDescription])
        }
    }

    private func process(
        _ initialJob: RecordingJob,
        visualFeedback: Bool,
        insertionTarget: NSRunningApplication?
    ) async {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            queue.complete(initialJob)
            if visualFeedback {
                overlay.hide()
            }
            onStatusChange?(AppText.apiKeyMissing(settings.language))
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
                onStatusChange?(AppText.recordingTooShort(settings.language))
                logger.log(.warning, "pending_discarded_too_short", metadata: [
                    "audio_id": job.id,
                    "duration": String(format: "%.3fs", job.duration),
                    "path": job.filePath
                ])
                return
            }

            guard ensureAccessibilityPermission(prompt: visualFeedback, audioID: initialJob.id) else {
                queue.complete(job)
                if visualFeedback {
                    overlay.flashFailureAndHide()
                }
                return
            }

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
                    model: settings.model,
                    language: settings.language
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
            let text = TranscriptCombiner.combine(transcriptParts)

            guard !text.isEmpty else {
                queue.complete(job)
                if visualFeedback {
                    overlay.hide()
                }
                onStatusChange?(AppText.emptyTranscription(settings.language))
                logger.log(.warning, "empty_transcription", metadata: ["audio_id": job.id])
                return
            }

            let insertedText = TranscriptInsertionFormatter.format(text)

            do {
                let pasteTarget = try await pasteInjector.insert(insertedText, into: insertionTarget)
                queue.complete(job)
                if visualFeedback {
                    overlay.flashSuccessAndHide()
                }
                onStatusChange?(AppText.inserted(settings.language))
                logger.log(.info, "transcription_inserted", metadata: [
                    "audio_id": job.id,
                    "chars": "\(insertedText.count)",
                    "target": pasteTarget?.localizedName ?? "frontmost"
                ])
            } catch PasteInjector.PasteError.accessibilityPermissionMissing {
                _ = pasteInjector.requestAccessibilityPermission(openSettings: visualFeedback)
                if visualFeedback {
                    overlay.flashFailureAndHide()
                }
                queue.complete(job)
                onStatusChange?(AppText.recognizedButNotInserted(settings.language))
                logger.log(.error, "paste_blocked_accessibility_transcript_deleted", metadata: [
                    "audio_id": job.id,
                    "attempt": "\(job.attempts)",
                    "chars": "\(insertedText.count)"
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
                onStatusChange?(AppText.corruptedRecordingDeleted(settings.language))
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
            queue.complete(job)
            onStatusChange?(AppText.genericErrorDeleted(settings.language))
            logger.log(.error, "transcription_failed_audio_deleted", metadata: [
                "audio_id": job.id,
                "attempt": "\(job.attempts)",
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
            onStatusChange?(AppText.accessibilitySettings(settings.language))
            return false
        }

        return true
    }

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
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
