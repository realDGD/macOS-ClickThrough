import AppKit
import ClickThroughCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private var menuConfinement = NSRect.zero
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
        if NSApp.currentEvent?.type == .rightMouseUp { openMenu(at: NSEvent.mouseLocation) }
        else { model.toggle() }
    }

    private func openMenu(at location: NSPoint) {
        model.refreshSystemState()
        guard let item, let button = item.button else { return }
        let menu = NSMenu()
        let status = menu.addItem(withTitle: "ClickThrough · \(model.state.label)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "设置…", action: #selector(settingsClicked), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 ClickThrough", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        if model.settings.statusMenuFollowsClickedScreen, let placement = menuPlacement(at: location) {
            menu.delegate = self
            menuConfinement = placement.confinement
            defer { menuConfinement = .zero }
            menu.popUp(positioning: nil, at: placement.anchor, in: nil)
        } else {
            item.menu = menu
            defer { item.menu = nil }
            button.performClick(nil)
        }
    }

    func confinementRect(for menu: NSMenu, on screen: NSScreen?) -> NSRect { menuConfinement }

    private func menuPlacement(at location: NSPoint) -> StatusMenuPlacement? {
        let screens = NSScreen.screens
        guard let primary = screens.first,
              let screen = screens.first(where: { $0.frame.contains(location) }) else { return nil }
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        // Status bar thickness can differ from the actual menu-bar window height on this display.
        let bars = windows.compactMap { info -> CGRect? in
            guard info[kCGWindowLayer as String] as? Int == menuLevel,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY,
                          width: frame.width, height: frame.height)
        }
        return StatusMenuPlacement(click: location, screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                   menuBarFrames: bars,
                                   fallbackMenuBarHeight: max(NSStatusBar.system.thickness, screen.safeAreaInsets.top))
    }

    @objc private func settingsClicked() { showSettings() }
    @objc private func quitClicked() { NSApp.terminate(nil) }
}
