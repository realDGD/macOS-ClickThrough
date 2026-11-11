import CoreGraphics

public struct StatusMenuPlacement {
    public let anchor: CGPoint
    public let confinement: CGRect

    public init?(click: CGPoint, screenFrame: CGRect, visibleFrame: CGRect,
                 menuBarFrames: [CGRect], fallbackMenuBarHeight: CGFloat) {
        guard screenFrame.contains(click) else { return nil }
        let visible = screenFrame.intersection(visibleFrame)
        let barBottom = menuBarFrames.first(where: { $0.contains(click) })?.minY
            ?? (screenFrame.maxY - max(0, fallbackMenuBarHeight))
        let top = min(visible.maxY, barBottom)
        guard !visible.isNull, visible.width > 0, top > visible.minY else { return nil }
        confinement = CGRect(x: visible.minX, y: visible.minY, width: visible.width,
                             height: top - visible.minY)
        anchor = CGPoint(x: click.x, y: top)
    }
}
