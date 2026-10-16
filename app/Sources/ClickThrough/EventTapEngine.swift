import AppKit
import ApplicationServices
import ClickThroughCore

@MainActor
final class EventTapEngine {
    var settings = AppSettings()
    var onStateChange: ((RuntimeState) -> Void)?
    private(set) var state: RuntimeState = .stopped {
        didSet { onStateChange?(state) }
    }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let diagnostics: Diagnostics
    private let ownBundleID = Bundle.main.bundleIdentifier ?? "local.clickthrough.app"

    init(diagnostics: Diagnostics) { self.diagnostics = diagnostics }

    func start() {
        releaseTap()
        guard AXIsProcessTrusted() else {
            state = .permissionRequired
            diagnostics.record("start_blocked", fields: ["reason": "ax_not_trusted"])
            return
        }
        let mask = [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged,
                    .rightMouseDown, .rightMouseUp, .rightMouseDragged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, user in
            guard let user else { return Unmanaged.passUnretained(event) }
            MainActor.assumeIsolated {
                Unmanaged<EventTapEngine>.fromOpaque(user).takeUnretainedValue().process(type: type, event: event)
            }
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { return nil }
            return Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                               options: .defaultTap, eventsOfInterest: mask, callback: callback,
                               userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { state = .paused("无法建立鼠标监听。请检查辅助功能权限后重新开启。"); return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source else { releaseTap(); state = .paused("鼠标监听启动失败，请重新开启。"); return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else {
            releaseTap(); state = .paused("系统未启用鼠标监听，请重新开启。"); return
        }
        state = .running
        diagnostics.record("started")
    }

    func stop() {
        releaseTap()
        state = .stopped
        diagnostics.record("stopped")
    }

    func refreshHealth() {
        guard state.isRunning else { return }
        if !AXIsProcessTrusted() {
            releaseTap(); state = .permissionRequired
        } else if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            releaseTap(); state = .paused("系统已暂停鼠标监听，请手动重新开启。")
        }
    }

    private func releaseTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func process(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            diagnostics.record("tap_disabled", fields: ["type": String(type.rawValue)])
            releaseTap()
            state = .paused("系统已暂停鼠标监听。点击图标可重新开启。")
            return
        }
        guard state.isRunning else { return }
        let isDown = type == .leftMouseDown || type == .rightMouseDown
        guard isDown else { return }
        guard AXIsProcessTrusted() else { releaseTap(); state = .permissionRequired; return }
        guard isUnmodifiedMouseClick(event.flags) else { return }
        let started = DispatchTime.now().uptimeNanoseconds
        guard let target = WindowResolver.target(at: event.location),
              target.pid != getpid(), target.layer == 0,
              settings.allows(bundleID: target.bundleID, selfBundleID: ownBundleID) else { return }
        var fields = ["pid": String(target.pid), "bundle_id": target.bundleID ?? "",
                      "window": String(target.windowNumber), "type": String(type.rawValue),
                      "event_number": String(event.getIntegerValueField(.mouseEventNumber)),
                      "click_count": String(event.getIntegerValueField(.mouseEventClickState)),
                      "event_timestamp": String(event.timestamp)]
        // Same PID can contain another non-key window: never skip on foreground PID.
        ActivationSequence.run(window: {
            let result = A4Activation.window(at: event.location, expectedPID: target.pid)
            for (key, value) in result.fields { fields["window_" + key] = value }
            return result.success
        }, application: {
            let result = A4Activation.application(pid: target.pid)
            for (key, value) in result.fields { fields["application_" + key] = value }
        })
        fields["callback_work_ns"] = String(DispatchTime.now().uptimeNanoseconds - started)
        diagnostics.record("activation_request", fields: fields)
    }
}
