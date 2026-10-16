import CoreGraphics

// Catches treating system delivery flags as held keyboard modifiers, which
// would silently skip genuine plain clicks. Expected cases are explicit.
let cases: [(String, CGEventFlags, Bool)] = [
    ("plain click", [], true),
    ("non-coalesced plain click", .maskNonCoalesced, true),
    ("Command click passes through without activation", .maskCommand, false),
    ("Shift click passes through without activation", .maskShift, false),
    ("Control click passes through without activation", .maskControl, false),
    ("Option click passes through without activation", .maskAlternate, false),
    ("Fn click passes through without activation", .maskSecondaryFn, false),
    ("CapsLock state is outside initial probe", .maskAlphaShift, false),
    ("system flag does not hide Command", [.maskNonCoalesced, .maskCommand], false)
]
var failures = 0
for (name, flags, expected) in cases {
    let actual = isUnmodifiedMouseClick(flags)
    if actual != expected { print("FAIL \(name): expected \(expected), got \(actual)"); failures += 1 }
}
print("\(cases.count - failures)/\(cases.count) activation eligibility cases passed")
if failures != 0 { exit(1) }
