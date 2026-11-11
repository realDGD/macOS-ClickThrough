import ApplicationServices

struct AXStepResult {
    var success: Bool
    var fields: [String: String]

    static func failure(_ stage: String, _ error: AXError? = nil) -> Self {
        var fields = ["result": stage]
        if let error { fields["ax_error"] = String(error.rawValue) }
        return Self(success: false, fields: fields)
    }
}

@MainActor
enum A4Activation {
    static func window(at point: CGPoint, expectedPID: pid_t,
                       capture: ((AXHitEvidence) -> Void)? = nil) -> AXStepResult {
        var hitElement: AXUIElement?
        var resolvedWindow: AXUIElement?
        var evidence: [String: String] = [:]
        defer {
            capture?(AXHitEvidence(element: hitElement, window: resolvedWindow, fields: evidence))
        }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.025)
        var element: AXUIElement?
        let hit = AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element)
        if capture != nil {
            hitElement = element
            evidence["hit_ax_error"] = String(hit.rawValue)
        }
        guard hit == .success, let element else { return .failure("hit_failed", hit) }
        var pid: pid_t = 0
        let pidError = AXUIElementGetPid(element, &pid)
        if capture != nil {
            evidence["hit_pid"] = String(pid)
            evidence["hit_pid_error"] = String(pidError.rawValue)
        }
        guard pid == expectedPID else { return .failure("pid_mismatch") }
        var value: CFTypeRef?
        let read = AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value)
        if capture != nil {
            evidence["window_resolution"] = "AXWindow_attribute"
            evidence["window_attribute_error"] = String(read.rawValue)
            evidence["window_attribute_type"] = value.map { String(CFGetTypeID($0)) } ?? "missing"
        }
        guard read == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return .failure("window_attribute_failed", read)
        }
        let window = unsafeDowncast(value, to: AXUIElement.self)
        if capture != nil { resolvedWindow = window }
        AXUIElementSetMessagingTimeout(window, 0.025)
        var settable = DarwinBoolean(false)
        let query = AXUIElementIsAttributeSettable(window, kAXMainAttribute as CFString, &settable)
        guard query == .success else { return .failure("main_query_failed", query) }
        guard settable.boolValue else { return .failure("main_not_writable") }
        let set = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        return AXStepResult(success: set == .success,
                            fields: ["result": "main_set", "ax_error": String(set.rawValue)])
    }

    static func application(pid: pid_t) -> AXStepResult {
        let app = AXUIElementCreateApplication(pid)
        let timeout = AXUIElementSetMessagingTimeout(app, 0.025)
        guard timeout == .success else { return .failure("timeout_setup_failed", timeout) }
        var settable = DarwinBoolean(false)
        let query = AXUIElementIsAttributeSettable(app, kAXFrontmostAttribute as CFString, &settable)
        guard query == .success else { return .failure("frontmost_query_failed", query) }
        guard settable.boolValue else { return .failure("frontmost_not_writable") }
        let set = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        guard set == .success else { return .failure("frontmost_set_failed", set) }
        // Preserve A4's one immediate readback. This is diagnostic, not a completion barrier.
        var value: CFTypeRef?
        let read = AXUIElementCopyAttributeValue(app, kAXFrontmostAttribute as CFString, &value)
        var fields = ["result": "frontmost_set", "ax_error": String(set.rawValue),
                      "read_error": String(read.rawValue)]
        if read == .success, let value, CFGetTypeID(value) == CFBooleanGetTypeID() {
            fields["frontmost_after"] = String(CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self)))
        }
        return AXStepResult(success: true, fields: fields)
    }
}
