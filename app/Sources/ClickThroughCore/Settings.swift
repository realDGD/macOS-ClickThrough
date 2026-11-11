import Foundation

public enum RuleMode: String, Codable, CaseIterable, Sendable {
    case blacklist, whitelist
}

public struct ApplicationRule: Codable, Equatable, Identifiable, Sendable {
    public var bundleID: String
    public var name: String
    public var id: String { bundleID }

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

public enum LaunchContext: Sendable { case manual, login }

public struct AppSettings: Codable, Equatable, Sendable {
    public var wantedEnabled = false
    public var showMenuBarIcon = true
    public var statusMenuFollowsClickedScreen = true
    public var diagnosticsEnabled = false
    public var detailedDiagnosticsEnabled = false
    public var ruleMode: RuleMode = .blacklist
    public var blacklist: [ApplicationRule] = []
    public var whitelist: [ApplicationRule] = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case wantedEnabled, showMenuBarIcon, diagnosticsEnabled, detailedDiagnosticsEnabled
        case statusMenuFollowsClickedScreen
        case ruleMode, blacklist, whitelist
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        wantedEnabled = try values.decode(Bool.self, forKey: .wantedEnabled)
        showMenuBarIcon = try values.decode(Bool.self, forKey: .showMenuBarIcon)
        statusMenuFollowsClickedScreen = try values.decodeIfPresent(Bool.self, forKey: .statusMenuFollowsClickedScreen) ?? true
        diagnosticsEnabled = try values.decode(Bool.self, forKey: .diagnosticsEnabled)
        detailedDiagnosticsEnabled = try values.decodeIfPresent(Bool.self, forKey: .detailedDiagnosticsEnabled) ?? false
        ruleMode = try values.decode(RuleMode.self, forKey: .ruleMode)
        blacklist = try values.decode([ApplicationRule].self, forKey: .blacklist)
        whitelist = try values.decode([ApplicationRule].self, forKey: .whitelist)
    }

    public func allows(bundleID: String?, selfBundleID: String) -> Bool {
        guard bundleID != selfBundleID else { return false }
        switch ruleMode {
        case .blacklist:
            return !blacklist.contains { $0.bundleID == bundleID }
        case .whitelist:
            guard let bundleID, !bundleID.isEmpty else { return false }
            return whitelist.contains { $0.bundleID == bundleID }
        }
    }

    public mutating func handleLaunch(_ context: LaunchContext) {
        if context == .manual { showMenuBarIcon = true }
    }
}
