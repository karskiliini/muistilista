import Foundation

/// File-scope handler so it converts to a C function pointer (a signal
/// handler cannot capture context). Records the signal, then restores the
/// default handler and re-raises so the process still crashes as normal.
private func ostoslistaSignalHandler(_ sig: Int32) {
    CrashReporter.handleSignal(sig)
    signal(sig, SIG_DFL)
    raise(sig)
}

/// File-scope so it converts to a C function pointer for
/// NSSetUncaughtExceptionHandler (no captured context allowed).
private func ostoslistaExceptionHandler(_ exception: NSException) {
    CrashReporter.handleException(exception)
}

/// A captured crash, persisted to the App Group container so it survives
/// the crash and can be shown on the next launch.
struct CrashReport: Codable {
    let date: Date
    let version: String
    let kind: String        // "exception" | "signal" | "coredata"
    let name: String
    let reason: String
    let stack: [String]

    /// Short human-readable one-liner for the alert.
    var summary: String {
        let head = reason.isEmpty ? name : "\(name): \(reason)"
        return "v\(version) · \(kind)\n\(head)"
    }
}

/// Lightweight, dependency-free crash capture. Installs handlers for
/// uncaught Obj-C/Swift exceptions and fatal signals (SIGABRT/SIGSEGV/…)
/// and writes a report to disk. Also records Core Data store-load failures,
/// the most likely crash source here. On the next launch the app reads the
/// pending report and shows it, so the crash cause is no longer invisible.
enum CrashReporter {
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var defaultURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: CoreDataStack.appGroupID)?
            .appendingPathComponent("last-crash.json")
    }

    // MARK: Install

    static func install() {
        NSSetUncaughtExceptionHandler(ostoslistaExceptionHandler)
        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP] {
            signal(sig, ostoslistaSignalHandler)
        }
    }

    static func handleException(_ exception: NSException) {
        let report = CrashReport(
            date: Date(), version: appVersion, kind: "exception",
            name: exception.name.rawValue,
            reason: exception.reason ?? "",
            stack: exception.callStackSymbols)
        if let url = defaultURL { save(report, to: url) }
    }

    static func handleSignal(_ sig: Int32) {
        let names = [SIGABRT: "SIGABRT", SIGILL: "SIGILL", SIGSEGV: "SIGSEGV",
                     SIGFPE: "SIGFPE", SIGBUS: "SIGBUS", SIGTRAP: "SIGTRAP"]
        let report = CrashReport(
            date: Date(), version: appVersion, kind: "signal",
            name: names[sig] ?? "signal \(sig)",
            reason: "Sovellus sai signaalin (usein Swift-kaatuma tai muistivirhe).",
            stack: Thread.callStackSymbols)
        if let url = defaultURL { save(report, to: url) }
    }

    /// Record a Core Data store-load failure (recoverable path uses this).
    static func recordCoreData(_ error: Error) {
        let ns = error as NSError
        let report = CrashReport(
            date: Date(), version: appVersion, kind: "coredata",
            name: "\(ns.domain) \(ns.code)",
            reason: ns.localizedDescription,
            stack: Thread.callStackSymbols)
        if let url = defaultURL { save(report, to: url) }
    }

    // MARK: Persistence (also used by tests)

    static func save(_ report: CrashReport, to url: URL) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(from url: URL) -> CrashReport? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CrashReport.self, from: data)
    }

    static func clear(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// The pending crash from a previous run (nil if the last run was clean).
    static func pending() -> CrashReport? {
        guard let url = defaultURL else { return nil }
        return load(from: url)
    }

    static func clearPending() {
        guard let url = defaultURL else { return }
        clear(at: url)
    }
}
