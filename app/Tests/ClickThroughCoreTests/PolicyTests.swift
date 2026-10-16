import CoreGraphics
import Foundation
import Testing
@testable import ClickThroughCore

private let ownID = "local.clickthrough.app"

@Test func blacklistExcludesIdentityRatherThanName() {
    var settings = AppSettings()
    #expect(settings.allows(bundleID: "example.a", selfBundleID: ownID))
    #expect(settings.allows(bundleID: nil, selfBundleID: ownID))
    settings.blacklist = [.init(bundleID: "example.a", name: "Editor")]
    #expect(!settings.allows(bundleID: "example.a", selfBundleID: ownID))
    #expect(settings.allows(bundleID: "example.b", selfBundleID: ownID))
    #expect(!settings.allows(bundleID: ownID, selfBundleID: ownID))
}

@Test func whitelistIsExplicitIncludingUnknownApplications() {
    var settings = AppSettings()
    settings.ruleMode = .whitelist
    #expect(!settings.allows(bundleID: "example.a", selfBundleID: ownID))
    #expect(!settings.allows(bundleID: nil, selfBundleID: ownID))
    settings.whitelist = [.init(bundleID: "example.a", name: "Editor"), .init(bundleID: ownID, name: "Self")]
    #expect(settings.allows(bundleID: "example.a", selfBundleID: ownID))
    #expect(!settings.allows(bundleID: ownID, selfBundleID: ownID))
}

@Test func ruleModeSwitchAndPersistenceKeepBothLists() throws {
    var settings = AppSettings()
    settings.blacklist = [.init(bundleID: "example.a", name: "A")]
    settings.ruleMode = .whitelist
    settings.whitelist = [.init(bundleID: "example.b", name: "B")]
    let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
    #expect(restored == settings)
    settings.ruleMode = .blacklist
    #expect(settings.blacklist.count == 1)
    #expect(settings.whitelist.count == 1)
}

@Test(arguments: [false, true]) func manualOpenRestoresOnlyIcon(wantedEnabled: Bool) {
    var settings = AppSettings()
    settings.showMenuBarIcon = false
    settings.wantedEnabled = wantedEnabled
    settings.handleLaunch(.manual)
    #expect(settings.showMenuBarIcon)
    #expect(settings.wantedEnabled == wantedEnabled)
}

@Test func loginLaunchKeepsHiddenIcon() {
    var settings = AppSettings()
    settings.showMenuBarIcon = false
    settings.wantedEnabled = true
    settings.handleLaunch(.login)
    #expect(!settings.showMenuBarIcon)
    #expect(settings.wantedEnabled)
}

@Test func modifiedClicksPassThroughButNonCoalescedFlagIsNotKeyboardInput() {
    let keyboard: [CGEventFlags] = [.maskAlphaShift, .maskShift, .maskControl, .maskAlternate,
                                  .maskCommand, .maskNumericPad, .maskHelp, .maskSecondaryFn]
    for flag in keyboard { #expect(!isUnmodifiedMouseClick(flag)) }
    #expect(isUnmodifiedMouseClick([]))
    #expect(isUnmodifiedMouseClick(.maskNonCoalesced))
}

@Test func onlyActualRunningStateUsesEnabledSymbol() {
    #expect(RuntimeState.running.symbolName == "cursorarrow.click.2")
    for state in [RuntimeState.stopped, .permissionRequired, .paused("tap failed")] {
        #expect(!state.isRunning)
        #expect(state.symbolName == "cursorarrow.click")
    }
}

@Test func failedEnableIntentCanBeCancelledWithoutRestartingEngine() {
    for state in [RuntimeState.stopped, .permissionRequired, .paused("tap failed")] {
        #expect(state.canCancelPendingEnable(wantedEnabled: true))
        #expect(!state.canCancelPendingEnable(wantedEnabled: false))
    }
    #expect(!RuntimeState.running.canCancelPendingEnable(wantedEnabled: true))
}
