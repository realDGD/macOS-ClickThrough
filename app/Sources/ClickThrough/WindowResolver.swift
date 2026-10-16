import AppKit

struct WindowTarget {
    let pid: pid_t
    let windowNumber: Int
    let layer: Int
    let bundleID: String?
}

@MainActor
enum WindowResolver {
    static func target(at point: CGPoint) -> WindowTarget? {
        guard let primary = NSScreen.screens.first else { return nil }
        let appKitPoint = NSPoint(x: point.x, y: primary.frame.maxY - point.y)
        let number = NSWindow.windowNumber(at: appKitPoint, belowWindowWithWindowNumber: 0)
        guard number > 0,
              let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number)) as? [[String: Any]],
              let info = list.first,
              let owner = info[kCGWindowOwnerPID as String] as? NSNumber else { return nil }
        let pid = owner.int32Value
        return WindowTarget(pid: pid, windowNumber: number,
                            layer: (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1,
                            bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
    }
}
