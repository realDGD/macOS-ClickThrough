import CoreGraphics

func isUnmodifiedMouseClick(_ flags: CGEventFlags) -> Bool {
    let keyboard: CGEventFlags = [.maskAlphaShift, .maskShift, .maskControl,
                                 .maskAlternate, .maskCommand, .maskNumericPad,
                                 .maskHelp, .maskSecondaryFn]
    return flags.intersection(keyboard).isEmpty
}
