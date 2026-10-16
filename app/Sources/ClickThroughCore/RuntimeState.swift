public enum RuntimeState: Equatable, Sendable {
    case stopped
    case permissionRequired
    case running
    case paused(String)

    public var isRunning: Bool { self == .running }
    // Pre-26 names remain aliases on newer systems and work on macOS 14.
    public var symbolName: String { isRunning ? "cursorarrow.click.2" : "cursorarrow.click" }
    public func canCancelPendingEnable(wantedEnabled: Bool) -> Bool {
        wantedEnabled && !isRunning
    }
    public var label: String {
        switch self {
        case .stopped: "已关闭"
        case .permissionRequired: "需要辅助功能权限"
        case .running: "已开启"
        case .paused: "已暂停"
        }
    }
    public var explanation: String {
        switch self {
        case .stopped: "左键点击菜单栏图标即可开启。"
        case .permissionRequired: "请为 ClickThrough 开启辅助功能权限，再点击开启。"
        case .running: "后台窗口的首次点击使用 A4 路径处理。"
        case .paused(let reason): reason
        }
    }
}
