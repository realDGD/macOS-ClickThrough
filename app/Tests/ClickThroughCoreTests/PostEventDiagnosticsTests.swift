import Foundation
import Testing
@testable import ClickThroughCore

private func signaled(_ semaphore: DispatchSemaphore) -> Bool {
    semaphore.wait(timeout: .now()) == .success
}

@MainActor
private func recordedRows(_ diagnostics: Diagnostics) throws -> [[String: Any]] {
    diagnostics.flush()
    guard FileManager.default.fileExists(atPath: diagnostics.directory.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(at: diagnostics.directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "jsonl" }.flatMap { file in
            try String(contentsOf: file, encoding: .utf8).split(separator: "\n").map {
                try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
            }
        }
}

@MainActor
private func waitFor(_ condition: () throws -> Bool) async throws {
    for _ in 0..<200 {
        if try condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for the background observer")
}

@MainActor @Test func postEventSnapshotsAreDeferredBoundedAndCorrelated() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let diagnostics = Diagnostics(directory: directory)
    diagnostics.enabled = true
    diagnostics.detailedEnabled = true
    let observer = PostEventDiagnostics(diagnostics: diagnostics)
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    observer.noteMouseDown("first")
    observer.submit(fields: ["click_id": "first"]) {
        started.signal()
        release.wait()
        return ["hit_role": "AXWindow", "focused_window_ax_error": "-25205"]
    }
    // The reader must not run synchronously, while the event callback is on the stack.
    #expect(!signaled(started))
    try await waitFor { signaled(started) }
    observer.noteMouseDown("second")
    observer.submit(fields: ["click_id": "second"]) {
        Issue.record("A second observation must not queue behind a blocked AX reader")
        return [:]
    }
    release.signal()
    try await waitFor { try recordedRows(diagnostics).count == 2 }
    let rows = try recordedRows(diagnostics)
    let skipped = try #require(rows.first { $0["kind"] as? String == "post_event_snapshot_skipped" })
    #expect((skipped["fields"] as? [String: String])?["reason"] == "observer_busy")
    let snapshot = try #require(rows.first { $0["kind"] as? String == "post_event_snapshot" })
    let fields = try #require(snapshot["fields"] as? [String: String])
    #expect(fields["click_id"] == "first")
    #expect(fields["latest_click_id"] == "second")
    #expect(fields["intervening_click"] == "true")
    #expect(fields["hit_role"] == "AXWindow")
    #expect(fields["focused_window_ax_error"] == "-25205")
    #expect(try #require(UInt64(fields["snapshot_delay_ns"] ?? "")) >= 150_000_000)
}

@MainActor @Test func disablingOrInvalidatingAnObserverSuppressesStaleSnapshots() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let diagnostics = Diagnostics(directory: directory)
    diagnostics.enabled = true
    diagnostics.detailedEnabled = true
    let observer = PostEventDiagnostics(diagnostics: diagnostics)
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    observer.submit(fields: ["click_id": "old"]) {
        started.signal()
        release.wait()
        finished.signal()
        return ["stale": "true"]
    }
    try await waitFor { signaled(started) }
    diagnostics.detailedEnabled = false
    observer.invalidate()
    diagnostics.detailedEnabled = true
    release.signal()
    try await waitFor { signaled(finished) }
    // Wait for the completion hop, then ensure a new generation can use the slot.
    try await waitFor { !observer.pending }
    observer.noteMouseDown("new")
    observer.submit(fields: ["click_id": "new"]) { ["fresh": "true"] }
    try await waitFor { try recordedRows(diagnostics).count == 1 }
    let fields = try #require(try recordedRows(diagnostics).first?["fields"] as? [String: String])
    #expect(fields["click_id"] == "new")
    #expect(fields["stale"] == nil)
}

@MainActor @Test func basicOrDisabledLoggingNeverRunsAnAXObserver() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let diagnostics = Diagnostics(directory: directory)
    let observer = PostEventDiagnostics(diagnostics: diagnostics)
    diagnostics.detailedEnabled = true
    observer.submit(fields: [:]) { Issue.record("Master switch is off"); return [:] }
    diagnostics.enabled = true
    diagnostics.detailedEnabled = false
    observer.submit(fields: [:]) { Issue.record("Detailed switch is off"); return [:] }
    diagnostics.detailedEnabled = true
    observer.submit(fields: [:]) { Issue.record("Canceled before callback return"); return [:] }
    observer.invalidate()
    try await waitFor { !observer.pending }
    #expect(try recordedRows(diagnostics).isEmpty)
}
