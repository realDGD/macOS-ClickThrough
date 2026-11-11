import AppKit
import ApplicationServices

// Immutable retained references cross to one serial reader only after the callback returns.
struct AXHitEvidence: @unchecked Sendable {
    let element: AXUIElement?
    let window: AXUIElement?
    let fields: [String: String]

    nonisolated func snapshot(pid: pid_t) -> [String: String] {
        var result = fields
        let started = DispatchTime.now().uptimeNanoseconds
        let app = AXUIElementCreateApplication(pid)
        var focusedWindow: AXUIElement?

        func read(_ element: AXUIElement, _ attribute: String, _ key: String) -> CFTypeRef? {
            guard DispatchTime.now().uptimeNanoseconds - started < 100_000_000 else {
                result[key + "_status"] = "budget_exhausted"
                return nil
            }
            let timeout = AXUIElementSetMessagingTimeout(element, 0.025)
            guard timeout == .success else {
                result[key + "_timeout_error"] = String(timeout.rawValue)
                return nil
            }
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            result[key + "_ax_error"] = String(error.rawValue)
            guard error == .success, let value else { return nil }
            result[key + "_type"] = String(CFGetTypeID(value))
            return value
        }

        // Sample focus first so optional hit metadata cannot consume its time budget.
        let frontmost = NSWorkspace.shared.frontmostApplication
        result["frontmost_pid_at_snapshot_start"] = frontmost.map { String($0.processIdentifier) } ?? "unknown"
        result["frontmost_bundle_id_at_snapshot_start"] = frontmost?.bundleIdentifier ?? "unknown"
        if let value = read(app, kAXFocusedWindowAttribute, "focused_window"),
           CFGetTypeID(value) == AXUIElementGetTypeID() {
            focusedWindow = unsafeDowncast(value, to: AXUIElement.self)
        }
        result["focused_window_status"] = focusedWindow == nil ? "unavailable" : "present"
        if let focusedWindow {
            if let element { result["focused_matches_hit"] = String(CFEqual(focusedWindow, element)) }
            if let window { result["focused_matches_resolved_window"] = String(CFEqual(focusedWindow, window)) }
        }
        if let element {
            for (attribute, key) in [(kAXRoleAttribute, "hit_role"), (kAXSubroleAttribute, "hit_subrole")] {
                if let value = read(element, attribute, key), CFGetTypeID(value) == CFStringGetTypeID() {
                    result[key] = String((value as! String).prefix(128))
                }
            }
        }
        if let window {
            for (attribute, key) in [(kAXMainAttribute, "resolved_main"), (kAXFocusedAttribute, "resolved_focused")] {
                if let value = read(window, attribute, key), CFGetTypeID(value) == CFBooleanGetTypeID() {
                    result[key] = String(CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self)))
                }
            }
        }
        result["frontmost_pid_at_snapshot_end"] = NSWorkspace.shared.frontmostApplication.map { String($0.processIdentifier) } ?? "unknown"
        result["ax_observation_work_ns"] = String(DispatchTime.now().uptimeNanoseconds - started)
        return result
    }
}
