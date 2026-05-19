import Foundation

public struct RunningApplicationInfo: Equatable, Sendable {
    public var processIdentifier: pid_t
    public var bundleIdentifier: String?
    public var isTerminated: Bool

    public init(processIdentifier: pid_t, bundleIdentifier: String?, isTerminated: Bool) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.isTerminated = isTerminated
    }
}

public enum SingleInstancePolicy {
    public static func existingInstance(
        currentProcessIdentifier: pid_t,
        bundleIdentifier: String,
        runningApplications: [RunningApplicationInfo]
    ) -> RunningApplicationInfo? {
        runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier
                && $0.processIdentifier != currentProcessIdentifier
                && !$0.isTerminated
        }
    }
}
