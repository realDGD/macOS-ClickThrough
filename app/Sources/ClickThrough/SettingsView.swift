import SwiftUI
import ServiceManagement
import ClickThroughCore

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: model.state.symbolName)
                        .font(.system(size: 26)).frame(width: 38)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.state.label).font(.headline)
                        Text(model.state.explanation).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.state.isRunning ? "关闭" : "开启") { model.toggle() }
                        .buttonStyle(.borderedProminent)
                    if model.state.canCancelPendingEnable(wantedEnabled: model.settings.wantedEnabled) {
                        Button("保持关闭") { model.setEnabled(false) }
                    }
                }
                if model.state == .permissionRequired {
                    Button("打开辅助功能设置…") { model.openAccessibilitySettings() }
                    Text("授权后点击“开启”。只需辅助功能权限。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("首次点击") }

            Section("通用") {
                Toggle("显示菜单栏图标", isOn: binding(\.showMenuBarIcon))
                Text("隐藏后，从 Spotlight 或“应用程序”重新打开 ClickThrough 即可恢复图标。功能开关保持原状。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("登录时启动", isOn: Binding(
                    get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval },
                    set: { model.setLoginEnabled($0) }))
                if model.loginStatus == .requiresApproval {
                    HStack {
                        Text("等待在系统设置中允许登录启动。")
                        Button("打开登录项设置…") { LoginItemController.openSettings() }
                    }.font(.caption)
                } else if model.loginStatus == .notFound {
                    Text("当前应用无法注册登录项。请将应用放在固定位置后重试。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("应用规则") {
                Picker("处理范围", selection: Binding(get: { model.settings.ruleMode }, set: { value in
                    model.updateSettings { $0.ruleMode = value }
                })) {
                    Text("黑名单：忽略所列应用").tag(RuleMode.blacklist)
                    Text("白名单：只处理所列应用").tag(RuleMode.whitelist)
                }
                if model.selectedRules.isEmpty {
                    Text(model.settings.ruleMode == .blacklist ? "列表为空，处理所有符合条件的应用。" : "列表为空，不处理任何应用。")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.selectedRules) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name)
                            Text(rule.bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.removeApplication(rule.id) } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.borderless).help("移除 \(rule.name)")
                            .accessibilityLabel("移除 \(rule.name)")
                    }
                }
                Button("添加应用…") { model.addApplications() }
            }

            Section("诊断") {
                Toggle("记录诊断日志", isOn: binding(\.diagnosticsEnabled))
                Text("用于排查启停与点击请求，不记录键盘输入、剪贴板、网页内容或窗口标题。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("打开日志文件夹…") { model.showLogs() }
            }
            Text("ClickThrough \(appVersion) · macOS 14+")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .formStyle(.grouped)
        .frame(minWidth: 540, idealWidth: 570, minHeight: 640, idealHeight: 680)
        .alert("ClickThrough", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("好") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知版本"
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { model.settings[keyPath: keyPath] }, set: { value in
            model.updateSettings { $0[keyPath: keyPath] = value }
        })
    }
}
