import AppKit

@MainActor
final class StatusItemController: NSObject {
    private var item: NSStatusItem?
    private let model: AppModel
    private let showSettings: () -> Void

    init(model: AppModel, showSettings: @escaping () -> Void) {
        self.model = model
        self.showSettings = showSettings
        super.init()
    }

    func refresh() {
        guard model.settings.showMenuBarIcon else {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        if item == nil {
            let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            created.button?.target = self
            created.button?.action = #selector(clicked)
            created.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            item = created
        }
        let description = "ClickThrough，\(model.state.label)"
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: model.state.symbolName, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        item?.button?.image = image
        item?.button?.toolTip = "\(description)\n左键：开启／关闭；右键：菜单"
        item?.button?.setAccessibilityLabel(description)
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { openMenu() }
        else { model.toggle() }
    }

    private func openMenu() {
        model.refreshSystemState()
        guard let button = item?.button else { return }
        let menu = NSMenu()
        let status = menu.addItem(withTitle: "ClickThrough · \(model.state.label)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "设置…", action: #selector(settingsClicked), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 ClickThrough", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    @objc private func settingsClicked() { showSettings() }
    @objc private func quitClicked() { NSApp.terminate(nil) }
}
