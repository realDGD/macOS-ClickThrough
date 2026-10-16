import AppKit
// Swift 6 interop for the SDK's unannotated C global permission key.
@preconcurrency import ApplicationServices
import CoreGraphics

// Phase 1 disposable probe. Every physical mouse event is returned unchanged.
// This is an experiment, not the product engine or a replay implementation.

final class EventLog: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.clickthrough.probe.log")
    private let handle: FileHandle
    let directory: URL

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("probe-events.jsonl")
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
    }

    func record(_ values: [String: Any]) {
        var row = values
        row["wall_time"] = ISO8601DateFormatter().string(from: Date())
        row["uptime_ns"] = DispatchTime.now().uptimeNanoseconds
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
        data.append(10)
        queue.async { [self, data] in try? handle.write(contentsOf: data) }
    }

    func flush() { queue.sync { try? handle.synchronize() } }
}

enum ProbeMode: String, CaseIterable {
    case observe, activateApp, axMainThenActivate, axFrontmost, axMainThenFrontmost
    var label: String {
        switch self {
        case .observe: "基线：只记录原事件"
        case .activateApp: "A1：仅 NSRunningApplication.activate"
        case .axMainThenActivate: "A2：AXMain → 应用激活"
        case .axFrontmost: "A3：仅 AXFrontmost（应用前台属性）"
        case .axMainThenFrontmost: "A4：AXMain → AXFrontmost（窗口 + 应用）"
        }
    }
}

struct EventFingerprint: Equatable {
    let type: UInt32
    let timestamp: UInt64
    let x: Double
    let y: Double
    let flags: UInt64
    let eventNumber: Int64
    let clickState: Int64
    let sourcePID: Int64
    let targetPID: Int64
    let userData: Int64
    init(_ event: CGEvent) {
        type = event.type.rawValue
        timestamp = event.timestamp
        x = event.location.x
        y = event.location.y
        flags = event.flags.rawValue
        eventNumber = event.getIntegerValueField(.mouseEventNumber)
        clickState = event.getIntegerValueField(.mouseEventClickState)
        sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
        targetPID = event.getIntegerValueField(.eventTargetUnixProcessID)
        userData = event.getIntegerValueField(.eventSourceUserData)
    }
}

@MainActor
final class ProbeController: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var status: NSTextField!
    private var selector: NSPopUpButton!
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var mode = ProbeMode.observe
    private var sequence = 0
    private let log: EventLog

    init(log: EventLog) { self.log = log }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出实验", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let root = NSMenuItem(); root.submenu = appMenu; menu.addItem(root)
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 275),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "FirstClickProbe — Phase 1（默认不激活）"
        window.isReleasedWhenClosed = false
        let view = NSView(frame: window.contentView!.bounds); window.contentView = view
        let intro = NSTextField(wrappingLabelWithString: "只研究公开 API 提前激活。真实 down / up / drag 原样放行；不模拟或补发点击。先完成基线，再单独启用 A1、A2、A3 或 A4。")
        intro.frame = NSRect(x: 20, y: 203, width: 580, height: 50); view.addSubview(intro)
        selector = NSPopUpButton(frame: NSRect(x: 20, y: 155, width: 580, height: 32))
        selector.addItems(withTitles: ProbeMode.allCases.map(\.label)); view.addSubview(selector)
        let actions: [(String, Selector, CGFloat, CGFloat)] = [
            ("开始 / 切换实验", #selector(start), 20, 185),
            ("停止", #selector(stop), 215, 80),
            ("辅助功能授权", #selector(requestPermission), 305, 145),
            ("退出", #selector(quit), 460, 80)
        ]
        for (title, action, x, width) in actions {
            let button = NSButton(title: title, target: self, action: action)
            button.frame = NSRect(x: x, y: 105, width: width, height: 32); view.addSubview(button)
        }
        status = NSTextField(wrappingLabelWithString: "停止；尚未收集运行试次。")
        status.frame = NSRect(x: 20, y: 20, width: 580, height: 70); view.addSubview(status)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate()
        log.record(["kind": "session", "pid": getpid(), "bundle": Bundle.main.bundleIdentifier ?? "",
                    "probe_revision": "phase1-a4-main-frontmost",
                    "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
                    "minimum_system": "27.0", "mode": "stopped", "run_directory": log.directory.path])
        writeState()
    }

    private func capabilities() -> [String: Any] {
        ["ax_trusted": AXIsProcessTrusted(), "listen_preflight": CGPreflightListenEventAccess(),
         "post_preflight": CGPreflightPostEventAccess()]
    }

    private func writeState() {
        var state = capabilities()
        state["mode"] = tap == nil ? "stopped" : mode.rawValue
        state["tap_enabled"] = tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        state["pid"] = getpid(); state["sequence"] = sequence
        state["run_directory"] = log.directory.path
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: log.directory.appendingPathComponent("probe-state.json"), options: .atomic)
        }
    }

    @objc private func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        log.record(["kind": "permission_request", "ax_trusted": trusted])
        if !trusted {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        status.stringValue = trusted ? "辅助功能已授权；可点击开始。" : "请在系统辅助功能列表中添加 / 开启 FirstClickProbe，然后点击开始。"
        writeState()
    }

    @objc private func start() {
        stopTap()
        mode = ProbeMode.allCases[max(0, selector.indexOfSelectedItem)]
        guard AXIsProcessTrusted() else {
            status.stringValue = "需要本实验应用的辅助功能权限。点击“辅助功能授权”，授权后再开始。"
            log.record(["kind": "start_blocked", "reason": "ax_not_trusted", "capabilities": capabilities()])
            writeState(); return
        }
        let mask = [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged,
                    .rightMouseDown, .rightMouseUp, .rightMouseDragged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, user in
            guard let user else { return Unmanaged.passUnretained(event) }
            MainActor.assumeIsolated {
                let controller = Unmanaged<ProbeController>.fromOpaque(user).takeUnretainedValue()
                controller.process(type: type, event: event)
            }
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { return nil }
            return Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                               options: .defaultTap, eventsOfInterest: mask, callback: callback,
                               userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            status.stringValue = "Session tap 创建失败；未开始实验。权限状态写入日志。"
            log.record(["kind": "start_blocked", "reason": "tap_create_failed", "capabilities": capabilities()])
            writeState(); return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source else { stopTap(); writeState(); return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        status.stringValue = "运行中：\(mode.label)\n日志：\(log.directory.path)"
        log.record(["kind": "mode", "mode": mode.rawValue, "capabilities": capabilities()]); writeState()
    }

    @objc private func stop() {
        stopTap(); status.stringValue = "已停止；鼠标流正常通过系统。"
        log.record(["kind": "mode", "mode": "stopped"]); writeState(); log.flush()
    }

    private func stopTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { stopTap(); writeState(); log.flush() }

    private func target(at point: CGPoint) -> [String: Any]? {
        guard let primary = NSScreen.screens.first else { return nil }
        let appKitPoint = NSPoint(x: point.x, y: primary.frame.maxY - point.y)
        let number = NSWindow.windowNumber(at: appKitPoint, belowWindowWithWindowNumber: 0)
        guard number > 0,
              let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number)) as? [[String: Any]],
              let info = list.first,
              let owner = info[kCGWindowOwnerPID as String] as? NSNumber else { return nil }
        return ["window": number, "pid": owner.int32Value,
                "layer": (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1]
    }

    private func axMain(at point: CGPoint, expectedPID: pid_t) -> [String: Any] {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.025)
        var element: AXUIElement?
        let hit = AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element)
        guard hit == .success, let element else { return ["ax_hit": hit.rawValue] }
        var pid: pid_t = 0; AXUIElementGetPid(element, &pid)
        guard pid == expectedPID else { return ["ax_skip": "pid_mismatch", "ax_pid": pid] }
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return ["ax_window": result.rawValue, "ax_skip": "no_public_window_attribute"]
        }
        let axWindow = unsafeDowncast(value, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(axWindow, 0.025)
        var settable = DarwinBoolean(false)
        let writable = AXUIElementIsAttributeSettable(axWindow, kAXMainAttribute as CFString, &settable)
        guard writable == .success, settable.boolValue else {
            return ["ax_main_settable": writable.rawValue, "ax_skip": "main_not_writable"]
        }
        let set = AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        return ["ax_hit": hit.rawValue, "ax_main_set": set.rawValue]
    }

    private func axFrontmost(forPID pid: pid_t) -> [String: Any] {
        let application = AXUIElementCreateApplication(pid)
        let timeout = AXUIElementSetMessagingTimeout(application, 0.025)
        var row: [String: Any] = ["ax_timeout_set": timeout.rawValue]
        guard timeout == .success else { row["ax_skip"] = "timeout_setup_failed"; return row }
        var settable = DarwinBoolean(false)
        let writable = AXUIElementIsAttributeSettable(application, kAXFrontmostAttribute as CFString, &settable)
        row["ax_frontmost_settable"] = writable.rawValue
        row["ax_frontmost_writable"] = settable.boolValue
        guard writable == .success, settable.boolValue else {
            row["ax_skip"] = "frontmost_not_writable"; return row
        }
        let result = AXUIElementSetAttributeValue(application, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        row["ax_frontmost_set"] = result.rawValue
        guard result == .success else { return row }
        var value: CFTypeRef?
        let read = AXUIElementCopyAttributeValue(application, kAXFrontmostAttribute as CFString, &value)
        row["ax_frontmost_read"] = read.rawValue
        if read == .success, let value, CFGetTypeID(value) == CFBooleanGetTypeID() {
            row["ax_frontmost_after"] = CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self))
        }
        return row
    }

    private func process(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            log.record(["kind": "tap_disabled", "event_type": type.rawValue, "mode": mode.rawValue])
            status.stringValue = "系统禁用了 tap。已停止实验处理，请查看日志后手动重启。"
            // Never automatically keep retrying a callback that may be too slow.
            writeState(); return
        }
        let started = DispatchTime.now().uptimeNanoseconds
        let before = EventFingerprint(event)
        let isDown = type == .leftMouseDown || type == .rightMouseDown
        if isDown { sequence += 1 }
        var row: [String: Any] = ["kind": "mouse", "sequence": sequence, "mode": mode.rawValue,
                                 "type": type.rawValue, "event_timestamp": before.timestamp,
                                 "x": before.x, "y": before.y, "flags": before.flags,
                                 "event_number": before.eventNumber, "click_state": before.clickState,
                                 "source_pid": before.sourcePID, "annotated_target_pid": before.targetPID]
        if isDown {
            let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            row["frontmost_pid_before_request"] = frontmost
            row["requester_active_before_request"] = NSApp.isActive
            if let target = target(at: event.location), let pid = target["pid"] as? pid_t {
                row["hit"] = target
                row["target_bundle"] = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
                let layer = target["layer"] as? Int ?? -1
                if pid == getpid() { row["skip"] = "probe_control_window" }
                else if layer != 0 { row["skip"] = "non_normal_window_layer" }
                else if mode == .observe { row["action"] = "observe_only" }
                else if !isUnmodifiedMouseClick(event.flags) { row["skip"] = "modified_click_not_in_initial_probe" }
                else if (mode == .activateApp || mode == .axFrontmost) && pid == frontmost { row["skip"] = "app_already_frontmost" }
                else if mode == .axFrontmost {
                    row["ax"] = axFrontmost(forPID: pid)
                    row["action"] = mode.rawValue
                    row["frontmost_pid_after_ax"] = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
                }
                else if mode == .axMainThenFrontmost {
                    let ax = axMain(at: event.location, expectedPID: pid)
                    row["ax_window_step"] = ax
                    if ax["ax_main_set"] as? Int32 == AXError.success.rawValue {
                        row["ax_application_step"] = axFrontmost(forPID: pid)
                        row["action"] = mode.rawValue
                        row["frontmost_pid_after_ax"] = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
                    } else { row["skip"] = "ax_main_step_failed_no_fallback" }
                }
                else if let app = NSRunningApplication(processIdentifier: pid) {
                    if mode == .axMainThenActivate {
                        let ax = axMain(at: event.location, expectedPID: pid)
                        row["ax"] = ax
                        if ax["ax_main_set"] as? Int32 == AXError.success.rawValue {
                            row["activation_request_sent"] = app.activate(options: [])
                            row["action"] = mode.rawValue
                        } else { row["skip"] = "ax_main_step_failed_no_fallback" }
                    } else {
                        row["activation_request_sent"] = app.activate(options: [])
                        row["action"] = mode.rawValue
                    }
                }
            } else { row["skip"] = "no_public_window_hit" }
        }
        row["original_event_fields_unchanged"] = before == EventFingerprint(event)
        row["callback_work_ns"] = DispatchTime.now().uptimeNanoseconds - started
        log.record(row)
        // The C callback returns the same event after this observation.
    }
}

@MainActor
func launch() throws {
    let args = CommandLine.arguments
    let directory: URL
    if let i = args.firstIndex(of: "--run-dir"), i + 1 < args.count {
        directory = URL(fileURLWithPath: args[i + 1], isDirectory: true)
    } else {
        directory = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("runs")
    }
    let log = try EventLog(directory: directory)
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    let delegate = ProbeController(log: log)
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}

@main
struct ProbeMain {
    @MainActor static func main() {
        do { try launch() }
        catch { FileHandle.standardError.write(Data("FirstClickProbe: \(error)\n".utf8)); exit(1) }
    }
}
