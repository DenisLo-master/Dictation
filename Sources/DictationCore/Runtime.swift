import AppKit

@MainActor
private var retainedAppDelegate: AppDelegate?

@MainActor
public func runDictationApp() {
    let delegate = AppDelegate()
    retainedAppDelegate = delegate

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
}
