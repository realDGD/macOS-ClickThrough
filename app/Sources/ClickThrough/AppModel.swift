import AppKit
@preconcurrency import ApplicationServices
import ClickThroughCore
import Observation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor @Observable
final class AppModel {
    private(set) var settings: AppSettings
    private(set) var state: RuntimeState = .stopped
    private(set) var loginStatus = LoginItemController.status
    var message: String?
    @ObservationIgnored var onPresentationChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let diagnostics: Diagnostics
    @ObservationIgnored private let engine: EventTapEngine
    private static let settingsKey = "settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = saved
        } else { settings = AppSettings() }
        let diagnostics = Diagnostics()
        self.diagnostics = diagnostics
        engine = EventTapEngine(diagnostics: diagnostics)
        engine.settings = settings
        diagnostics.enabled = settings.diagnosticsEnabled
        engine.onStateChange = { [weak self] state in
            self?.state = state
            self?.onPresentationChange?()
        }
    }

    func launch(_ context: LaunchContext) {
        updateSettings { $0.handleLaunch(context) }
        if settings.wantedEnabled { engine.start() }
    }

    func reopen() { updateSettings { $0.handleLaunch(.manual) } }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.settingsKey) }
        engine.settings = settings
        diagnostics.enabled = settings.diagnosticsEnabled
        onPresentationChange?()
    }

    func toggle() { setEnabled(!state.isRunning) }

    func setEnabled(_ enabled: Bool) {
        updateSettings { $0.wantedEnabled = enabled }
        if enabled { engine.start() } else { engine.stop() }
    }

    func refreshSystemState() {
        loginStatus = LoginItemController.status
        engine.refreshHealth()
    }

    func setLoginEnabled(_ enabled: Bool) {
        do { try LoginItemController.setEnabled(enabled) }
        catch { message = "无法更新登录项：\(error.localizedDescription)" }
        refreshSystemState()
    }

    func openAccessibilitySettings() {
        // Only an explicit user action asks macOS to present an authorization prompt.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    var selectedRules: [ApplicationRule] {
        settings.ruleMode == .blacklist ? settings.blacklist : settings.whitelist
    }

    func addApplications() {
        let panel = NSOpenPanel()
        panel.title = "添加应用"
        panel.message = "选择要加入当前列表的应用。"
        panel.prompt = "添加"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        var rules = selectedRules
        var invalid: [String] = []
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, !id.isEmpty else {
                invalid.append(url.deletingPathExtension().lastPathComponent); continue
            }
            guard id != Bundle.main.bundleIdentifier, !rules.contains(where: { $0.bundleID == id }) else { continue }
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            rules.append(.init(bundleID: id, name: name))
        }
        rules.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        updateSettings {
            if $0.ruleMode == .blacklist { $0.blacklist = rules } else { $0.whitelist = rules }
        }
        if !invalid.isEmpty { message = "以下应用没有可用的 bundle ID，未添加：\(invalid.joined(separator: "、"))" }
    }

    func removeApplication(_ id: String) {
        updateSettings {
            if $0.ruleMode == .blacklist { $0.blacklist.removeAll { $0.bundleID == id } }
            else { $0.whitelist.removeAll { $0.bundleID == id } }
        }
    }

    func showLogs() {
        try? FileManager.default.createDirectory(at: diagnostics.directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(diagnostics.directory)
    }

    func terminate() { engine.stop(); diagnostics.flush() }
}
