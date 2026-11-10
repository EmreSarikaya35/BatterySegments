import AppKit

enum QuitService {
    /// Polite terminate() only (never forceTerminate); true once the app is gone within 3 s.
    @MainActor
    static func quit(pid: pid_t) async -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return true }
        guard app.terminate() else { return false }
        for _ in 0 ..< 30 where !app.isTerminated {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return app.isTerminated
    }
}
