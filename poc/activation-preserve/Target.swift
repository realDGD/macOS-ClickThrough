import AppKit

// Independent AppKit witness. Counters are driven by delivered target events,
// never by the probe's activation logs or return values.

@MainActor
final class ClickTarget: NSView {
    let acceptsInitial: Bool
    let label: String
    private var pressed = false
    private var dragged = false
    private var leftCount = 0
    private var rightCount = 0
    private var menuCount = 0
    let log: (String, [String: Any]) -> Void

    init(frame: NSRect, acceptsInitial: Bool, label: String, log: @escaping (String, [String: Any]) -> Void) {
        self.acceptsInitial = acceptsInitial; self.label = label; self.log = log
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel(label)
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        log("accepts_first_mouse", ["accepts": acceptsInitial, "event": event?.type.rawValue ?? 0])
        return acceptsInitial
    }
    override func mouseDown(with event: NSEvent) {
        pressed = true; dragged = false
        log("left_down", ["click_count": event.clickCount, "flags": event.modifierFlags.rawValue,
                          "window_key": window?.isKeyWindow ?? false])
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) { dragged = true }
    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        let action = pressed && !dragged && inside
        if action { leftCount += 1 }
        log("left_up", ["action_executed": action, "count": leftCount,
                        "had_down": pressed, "dragged": dragged, "inside": inside,
                        "click_count": event.clickCount])
        pressed = false; dragged = false; needsDisplay = true
    }
    override func rightMouseDown(with event: NSEvent) {
        rightCount += 1; needsDisplay = true
        log("right_menu_open", ["count": rightCount, "window_key": window?.isKeyWindow ?? false])
        let menu = NSMenu()
        let item = NSMenuItem(title: "记录菜单操作", action: #selector(recordMenuAction), keyEquivalent: "")
        item.target = self; menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func recordMenuAction() {
        menuCount += 1; needsDisplay = true; log("menu_action", ["count": menuCount])
    }
    override func draw(_ dirtyRect: NSRect) {
        (pressed ? NSColor.selectedControlColor : NSColor.controlBackgroundColor).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12).fill()
        let text = "\(label)\nacceptsFirstMouse = \(acceptsInitial)\n\n左键实际操作：\(leftCount)\n右键菜单打开：\(rightCount)\n菜单选项执行：\(menuCount)"
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 5
        (text as NSString).draw(in: bounds.insetBy(dx: 20, dy: 20), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 17, weight: .medium),
            .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
    }
}

@MainActor
final class TargetDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let handle: FileHandle
    init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("target-events.jsonl")
        if !FileManager.default.fileExists(atPath: file.path) { FileManager.default.createFile(atPath: file.path, contents: nil) }
        handle = try FileHandle(forWritingTo: file); try handle.seekToEnd()
    }
    func record(_ target: String, _ kind: String, _ values: [String: Any]) {
        var row = values; row["target"] = target; row["kind"] = kind
        row["uptime_ns"] = DispatchTime.now().uptimeNanoseconds
        row["application_active"] = NSApp.isActive
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: .sortedKeys) else { return }
        data.append(10); try? handle.write(contentsOf: data)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出靶标", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 340),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "FirstClickTarget — 独立原生操作计数"
        window.isReleasedWhenClosed = false
        let view = NSView(frame: window.contentView!.bounds); window.contentView = view
        let text = NSTextField(wrappingLabelWithString: "先点击另一个应用，让此窗口处于后台，再真实点击测试区域。窗口激活不算成功；只有下方操作计数增加才算。右键后可选择菜单项。")
        text.frame = NSRect(x: 20, y: 275, width: 660, height: 50); view.addSubview(text)
        for (index, accepts) in [false, true].enumerated() {
            let name = accepts ? "原生正对照" : "默认拒绝首次点击"
            let target = ClickTarget(frame: NSRect(x: CGFloat(20 + index * 340), y: 20, width: 320, height: 240),
                                     acceptsInitial: accepts, label: name) { [weak self] kind, values in
                self?.record(accepts ? "accept" : "reject", kind, values)
            }
            view.addSubview(target)
        }
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate()
        record("session", "start", ["pid": getpid(), "bundle": Bundle.main.bundleIdentifier ?? ""])
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@MainActor
func launch() throws {
    let args = CommandLine.arguments
    let i = args.firstIndex(of: "--run-dir")
    let directory = (i != nil && i! + 1 < args.count) ? URL(fileURLWithPath: args[i! + 1]) : Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("runs")
    let app = NSApplication.shared; app.setActivationPolicy(.regular)
    let delegate = try TargetDelegate(directory: directory); app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
do { try launch() } catch { fputs("FirstClickTarget: \(error)\n", stderr); exit(1) }
