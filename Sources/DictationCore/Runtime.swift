import AppKit

@MainActor
private var retainedAppDelegate: AppDelegate?

@MainActor
public func runDictationApp() {
    guard !activateExistingInstanceIfNeeded() else {
        return
    }

    let delegate = AppDelegate()
    retainedAppDelegate = delegate

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
}

@MainActor
private func activateExistingInstanceIfNeeded() -> Bool {
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let running = NSRunningApplication
        .runningApplications(withBundleIdentifier: AppPaths.bundleIdentifier)
        .map {
            RunningApplicationInfo(
                processIdentifier: $0.processIdentifier,
                bundleIdentifier: $0.bundleIdentifier,
                isTerminated: $0.isTerminated
            )
        }

    guard
        let duplicate = SingleInstancePolicy.existingInstance(
            currentProcessIdentifier: currentPID,
            bundleIdentifier: AppPaths.bundleIdentifier,
            runningApplications: running
        ),
        let app = NSRunningApplication(processIdentifier: duplicate.processIdentifier)
    else {
        return false
    }

    app.activate(options: [.activateAllWindows])
    return true
}
