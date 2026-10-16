import AppKit
@preconcurrency import ApplicationServices

// Disposable Phase 1 capability probe. No activation, event posting or retry.
@MainActor
final class BackgroundButtonProbe: NSObject, NSApplicationDelegate {
    let directory: URL
    let oldProbeState: URL
    let handle: FileHandle
    var window: NSWindow!
    let pidField = NSTextField()
    let status = NSTextField(wrappingLabelWithString: "尚未准备。")
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var gate = ButtonGate()
    var targetPID: pid_t
    var trial = 0
    var phase = "stopped"
    var point = CGPoint.zero
    var capturedWindow = 0
    var dragSamples = 0
    var workspaceObserver: NSObjectProtocol?

    init(directory: URL, targetPID: pid_t, oldProbeState: URL) throws {
        self.directory = directory; self.targetPID = targetPID; self.oldProbeState = oldProbeState
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("probe-events.jsonl")
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: file); try handle.seekToEnd()
    }

    func record(_ kind: String, _ values: [String: Any] = [:]) {
        var row = values
        row["kind"] = kind; row["trial"] = trial
        row["uptime_ns"] = DispatchTime.now().uptimeNanoseconds
        row["wall_time"] = ISO8601DateFormatter().string(from: Date())
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: .sortedKeys) else { return }
        data.append(10); try? handle.write(contentsOf: data)
    }

    func writeState() {
        let row: [String: Any] = ["pid": getpid(), "phase": phase, "trial": trial,
            "target_pid": targetPID, "ax_trusted": AXIsProcessTrusted(),
            "tap_enabled": tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false,
            "run_directory": directory.path]
        if let data = try? JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("probe-state.json"), options: .atomic)
        }
    }

    func snapshot(_ label: String) {
        let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
        let ordered = rows.compactMap { row -> [String: Int]? in
            guard row[kCGWindowLayer as String] as? Int == 0,
                  let id = row[kCGWindowNumber as String] as? Int,
                  let pid = row[kCGWindowOwnerPID as String] as? Int else { return nil }
            return ["window": id, "pid": pid]
        }
        record("window_snapshot", ["label": label, "frontmost_pid": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0,
            "target_window": capturedWindow, "ordered_normal_windows": ordered])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出后台按钮探针", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 350),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "BackgroundButtonProbe — AX 后台按钮（一次性实验）"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: window.contentView!.bounds); window.contentView = content
        let intro = NSTextField(wrappingLabelWithString: "仅验证后台普通按钮：不激活、不 raise、不补击。准备后捕获指定 PID 的一次无修饰键左键；松开后监听自动停止。其他应用点击照常通过。")
        intro.frame = NSRect(x: 20, y: 270, width: 580, height: 60); content.addSubview(intro)
        let label = NSTextField(labelWithString: "本次目标 PID：")
        label.frame = NSRect(x: 20, y: 235, width: 120, height: 25); content.addSubview(label)
        pidField.frame = NSRect(x: 145, y: 235, width: 110, height: 25)
        pidField.stringValue = String(targetPID); content.addSubview(pidField)
        for (title, action, x, width) in [
            ("准备一次 AXPress", #selector(arm), 20.0, 170.0),
            ("停止", #selector(stop), 200.0, 90.0),
            ("辅助功能授权", #selector(permission), 300.0, 160.0),
            ("退出", #selector(quit), 470.0, 100.0)] {
            let button = NSButton(title: title, target: self, action: action)
            button.frame = NSRect(x: x, y: 185, width: width, height: 32); content.addSubview(button)
        }
        status.frame = NSRect(x: 20, y: 20, width: 580, height: 145)
        status.font = .monospacedSystemFont(ofSize: 13, weight: .regular); content.addSubview(status)
        status.stringValue = "已停止。AX 授权：\(AXIsProcessTrusted())\n先暂停原 A4，再准备一次。\n日志：\(directory.path)"
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let pid = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier ?? 0
            MainActor.assumeIsolated { self?.record("application_activated", ["pid": pid]) }
        }
        record("session", ["pid": getpid(), "minimum_system": "27.0", "revision": "background-ax-one-shot-1",
            "ax_trusted": AXIsProcessTrusted(), "old_probe_state": oldProbeState.path])
        writeState(); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate()
    }

    @objc func permission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        status.stringValue = "本探针 AX 授权：\(trusted)。新 app 需要独立授权；授权后再点击准备。"
        record("permission_check", ["trusted": trusted]); writeState()
    }

    @objc func arm() {
        guard !gate.held else { status.stringValue = "请先松开已捕获的左键。"; return }
        guard AXIsProcessTrusted() else { permission(); return }
        guard let pid = Int32(pidField.stringValue), pid > 0, pid != getpid(),
              NSRunningApplication(processIdentifier: pid) != nil else {
            status.stringValue = "请输入仍在运行的目标 PID。"; return
        }
        guard let data = try? Data(contentsOf: oldProbeState),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              state["tap_enabled"] as? Bool == false else {
            status.stringValue = "原 FirstClickProbe 仍在运行，或无法确认其状态。请先点击原探针的停止。"
            record("arm_blocked", ["reason": "old_probe_not_confirmed_stopped"]); return
        }
        removeTap(); targetPID = pid
        guard gate.arm(pid: pid) else { return }
        let mask = [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, user in
            guard let user else { return Unmanaged.passUnretained(event) }
            let consume = MainActor.assumeIsolated {
                Unmanaged<BackgroundButtonProbe>.fromOpaque(user).takeUnretainedValue().process(type, event)
            }
            return consume ? nil : Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            _ = gate.stop(); status.stringValue = "事件 tap 创建失败，本次未开始。"; writeState(); return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        phase = "armed"
        status.stringValue = "已准备：PID \(pid)。\n先点击其他应用，再单击目标后台普通按钮一次。松开后自动停止。\n不支持 AXPress 时，本次点击只记录，不执行也不回退。"
        record("armed", ["target_pid": pid]); writeState()
    }

    func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }
    @objc func stop() {
        let drain = gate.stop()
        if !drain { removeTap(); phase = "stopped" }
        status.stringValue = drain ? "已取消；请松开左键，配对释放后停止。" : "已停止；鼠标正常通过系统。"
        record("stop", ["draining_release": drain]); writeState()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        removeTap(); phase = "stopped"; writeState(); record("quit"); try? handle.synchronize()
    }

    func unmodified(_ event: CGEvent) -> Bool {
        let keyboard: CGEventFlags = [.maskAlphaShift, .maskShift, .maskControl, .maskAlternate,
            .maskCommand, .maskNumericPad, .maskHelp, .maskSecondaryFn]
        return event.flags.intersection(keyboard).isEmpty
    }
    func hit(_ point: CGPoint) -> (pid: pid_t, window: Int, layer: Int)? {
        let appPoint = CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
        let number = NSWindow.windowNumber(at: appPoint, belowWindowWithWindowNumber: 0)
        guard number > 0,
              let rows = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number)) as? [[String: Any]],
              let row = rows.first,
              let pid = row[kCGWindowOwnerPID as String] as? Int32,
              let layer = row[kCGWindowLayer as String] as? Int else { return nil }
        return (pid, number, layer)
    }
    func process(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            record("tap_disabled", ["type": type.rawValue]); removeTap(); gate = ButtonGate()
            phase = "stopped"; status.stringValue = "系统禁用了 tap；本次作废，已停止。"; writeState()
            return true
        }
        let position = event.location
        if type == .leftMouseDown {
            if gate.held { return true }
            guard let target = hit(position) else { return false }
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            let eligible = target.layer == 0 && front != target.pid && unmodified(event)
                && event.getIntegerValueField(.mouseEventClickState) == 1
            if gate.down(pid: target.pid, eligible: eligible, x: position.x, y: position.y) == .consume {
                trial += 1; point = position; capturedWindow = target.window; dragSamples = 0
                phase = "held"
                snapshot("before_capture")
                record("captured_down", ["target_pid": target.pid, "window": target.window,
                    "event_number": event.getIntegerValueField(.mouseEventNumber), "frontmost_pid": front])
                writeState(); return true
            }
        } else if type == .leftMouseDragged, gate.held {
            dragSamples += 1; _ = gate.drag(x: position.x, y: position.y); return true
        } else if type == .leftMouseUp, gate.held {
            let target = hit(position)
            let eligible = unmodified(event) && target?.window == capturedWindow && target?.pid == targetPID
            let decision = gate.up(eligible: eligible)
            removeTap(); phase = "stopped"
            record("captured_up", ["decision": decision == .press ? "press" : "canceled",
                "drag_samples": dragSamples, "event_number": event.getIntegerValueField(.mouseEventNumber)])
            writeState()
            if decision == .press {
                DispatchQueue.main.async { [weak self] in self?.performPress() }
            } else { status.stringValue = "本次取消，未调用 AXPress；监听已停止。" }
            return true
        }
        return false
    }

    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    func performPress() {
        phase = "inspecting"; writeState()
        defer {
            phase = "stopped"; writeState(); snapshot("after_action")
            let capturedTrial = trial
            for delay in [0.2, 0.8] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.trial == capturedTrial else { return }
                    self.snapshot("after_\(delay)s")
                }
            }
        }
        guard hit(point)?.window == capturedWindow else {
            status.stringValue = "目标窗口命中已改变；未执行。"; record("action_skipped", ["reason": "window_changed"]); return
        }
        let system = AXUIElementCreateSystemWide()
        let timeout = AXUIElementSetMessagingTimeout(system, 0.25)
        var found: AXUIElement?
        let hitResult = AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &found)
        record("ax_hit", ["code": hitResult.rawValue, "timeout_code": timeout.rawValue])
        guard hitResult == .success, var element = found else {
            status.stringValue = "AX 命中失败 \(hitResult.rawValue)；未执行，无回退。"; return
        }
        for depth in 0..<6 {
            var pid: pid_t = 0; let pidResult = AXUIElementGetPid(element, &pid)
            guard pidResult == .success, pid == targetPID else {
                status.stringValue = "AX 元素 PID 不匹配；未执行。"; return
            }
            let role = attribute(element, kAXRoleAttribute) as? String ?? "unknown"
            var actions: CFArray?
            let actionResult = AXUIElementCopyActionNames(element, &actions)
            let names = actions as? [String] ?? []
            record("ax_inspection", ["depth": depth, "role": role, "actions_code": actionResult.rawValue, "actions": names])
            if role == kAXButtonRole, actionResult == .success, names.contains(kAXPressAction) {
                if let enabled = attribute(element, kAXEnabledAttribute),
                   CFGetTypeID(enabled) == CFBooleanGetTypeID(),
                   !CFBooleanGetValue(unsafeDowncast(enabled, to: CFBoolean.self)) {
                    status.stringValue = "按钮已禁用；未执行。"; record("action_skipped", ["reason": "disabled"]); return
                }
                record("ax_action_requested", ["action": kAXPressAction])
                let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
                record("ax_action_result", ["code": result.rawValue])
                status.stringValue = "试次 \(trial)：AXPress 返回 \(result.rawValue)。监听已停止。\n请确认按钮是否恰好 +1，原前台应用与窗口顺序是否不变。\n返回成功不等于业务通过；超时也不重试。"
                return
            }
            if role == kAXWindowRole || role == kAXApplicationRole { break }
            guard let parent = attribute(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            element = unsafeDowncast(parent, to: AXUIElement.self)
        }
        status.stringValue = "试次 \(trial)：未找到支持 AXPress 的普通按钮。\n本次点击已拦截但未执行，无激活、无补击，监听已停止。"
        record("action_skipped", ["reason": "no_press_button"])
    }
}

@main struct Entry {
    @MainActor static func main() {
        let args = CommandLine.arguments
        func argument(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        let root = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        let activeFile = root.appendingPathComponent("runs/active-run.txt")
        let savedRun = try? String(contentsOf: activeFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let run = argument("--run-dir") ?? savedRun else {
            fputs("No prepared run directory\n", stderr); exit(2)
        }
        let old = argument("--old-probe-state") ?? root.deletingLastPathComponent()
            .appendingPathComponent("activation-preserve/build/runs/probe-state.json").path
        do {
            let app = NSApplication.shared; app.setActivationPolicy(.regular)
            let delegate = try BackgroundButtonProbe(directory: URL(fileURLWithPath: run),
                targetPID: Int32(argument("--target-pid") ?? "0") ?? 0, oldProbeState: URL(fileURLWithPath: old))
            app.delegate = delegate
            withExtendedLifetime(delegate) { app.run() }
        } catch { fputs("BackgroundButtonProbe: \(error)\n", stderr); exit(1) }
    }
}
