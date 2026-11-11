import CoreGraphics
import Testing
@testable import ClickThroughCore

@Test func externalScreenUsesActualBarHeightRatherThanPointerOrStatusItemHeight() throws {
    let placement = try #require(StatusMenuPlacement(
        click: CGPoint(x: 2_100, y: 1_268),
        screenFrame: CGRect(x: 0, y: 0, width: 2_272, height: 1_278),
        visibleFrame: CGRect(x: 0, y: 0, width: 2_272, height: 1_248),
        menuBarFrames: [CGRect(x: 0, y: 1_248, width: 2_272, height: 30)], fallbackMenuBarHeight: 22))
    #expect(placement.anchor == CGPoint(x: 2_100, y: 1_248))
    #expect(placement.confinement.maxY == 1_248)
}

@Test func rotatedExternalScreenReservesBarEvenWhenVisibleFrameIncludesIt() throws {
    let frame = CGRect(x: 2_272, y: -488, width: 1_080, height: 1_920)
    let placement = try #require(StatusMenuPlacement(
        click: CGPoint(x: 3_200, y: 1_420), screenFrame: frame, visibleFrame: frame,
        menuBarFrames: [CGRect(x: 0, y: 1_248, width: 2_272, height: 30),
                        CGRect(x: 2_272, y: 1_402, width: 1_080, height: 30)], fallbackMenuBarHeight: 22))
    #expect(placement.anchor == CGPoint(x: 3_200, y: 1_402))
    #expect(placement.confinement == CGRect(x: 2_272, y: -488, width: 1_080, height: 1_890))
}

@Test func builtInScreenWithNegativeOriginKeepsMenuBelowItsOwnBar() throws {
    let placement = try #require(StatusMenuPlacement(
        click: CGPoint(x: -100, y: 1_268),
        screenFrame: CGRect(x: -1_280, y: 446, width: 1_280, height: 832),
        visibleFrame: CGRect(x: -1_280, y: 446, width: 1_280, height: 804),
        menuBarFrames: [CGRect(x: -1_280, y: 1_249, width: 1_280, height: 29)], fallbackMenuBarHeight: 28))
    #expect(placement.anchor == CGPoint(x: -100, y: 1_249))
    #expect(placement.confinement.minX == -1_280)
}

@Test func missingBarMetadataUsesVisibleAreaAndFallbackHeight() throws {
    let placement = try #require(StatusMenuPlacement(
        click: CGPoint(x: 700, y: 590), screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
        visibleFrame: CGRect(x: 0, y: 48, width: 800, height: 552), menuBarFrames: [], fallbackMenuBarHeight: 24))
    #expect(placement.anchor.y == 576)
    #expect(placement.confinement.minY == 48)
    #expect(StatusMenuPlacement(click: .zero, screenFrame: .zero, visibleFrame: .zero,
                              menuBarFrames: [], fallbackMenuBarHeight: 24) == nil)
}
