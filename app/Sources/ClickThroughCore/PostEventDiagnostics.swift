import Foundation

/// A bounded, read-only observation after the event-tap callback has returned.
@MainActor
public final class PostEventDiagnostics {
    private let diagnostics: Diagnostics
    private let queue = DispatchQueue(label: "local.clickthrough.ax-observation", qos: .utility)
    private(set) var pending = false
    private var generation = UUID()
    private var latestClickID = ""

    public init(diagnostics: Diagnostics) { self.diagnostics = diagnostics }

    public func noteMouseDown(_ id: String) { latestClickID = id }

    public func invalidate() {
        generation = UUID()
        // An in-flight AX read cannot be interrupted. Keep its slot until it finishes.
    }

    public func submit(fields: [String: String], read: @escaping @Sendable () -> [String: String]) {
        guard diagnostics.recordsDetailed else { return }
        guard !pending else {
            diagnostics.record("post_event_snapshot_skipped", fields: fields.merging(["reason": "observer_busy"]) { _, new in new }, detailed: true)
            return
        }
        let generation = generation
        pending = true
        let scheduled = DispatchTime.now().uptimeNanoseconds
        // This main-queue hop is the boundary: no new AX query runs inside the tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) { [weak self] in
            guard let self else { return }
            guard self.generation == generation, self.diagnostics.recordsDetailed else {
                self.pending = false
                return
            }
            self.queue.async { [weak self] in
                let started = DispatchTime.now().uptimeNanoseconds
                var result = fields.merging(read()) { _, new in new }
                result["snapshot_started_ns"] = String(started)
                result["snapshot_delay_ns"] = String(started - scheduled)
                result["snapshot_finished_ns"] = String(DispatchTime.now().uptimeNanoseconds)
                let completed = result
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.pending = false
                    guard self.generation == generation, self.diagnostics.recordsDetailed else { return }
                    var result = completed
                    result["latest_click_id"] = self.latestClickID
                    result["intervening_click"] = String(self.latestClickID != fields["click_id"])
                    self.diagnostics.record("post_event_snapshot", fields: result, detailed: true)
                }
            }
        }
    }
}
