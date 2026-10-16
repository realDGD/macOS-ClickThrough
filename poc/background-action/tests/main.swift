import Foundation

var failures = 0
@MainActor func check(_ name: String, _ block: () -> Bool) {
    let ok = block()
    print("\(ok ? "PASS" : "FAIL") \(name)")
    if !ok { failures += 1 }
}

check("an unrelated application click passes and leaves the intended target ready") {
    var gate = ButtonGate()
    guard gate.arm(pid: 42), gate.down(pid: 7, eligible: true, x: 10, y: 10) == .pass else { return false }
    return gate.down(pid: 42, eligible: true, x: 10, y: 10) == .consume
}
check("one captured click requests exactly one action after release") {
    var gate = ButtonGate()
    guard gate.arm(pid: 42), gate.down(pid: 42, eligible: true, x: 10, y: 10) == .consume else { return false }
    return gate.up(eligible: true) == .press && gate.up(eligible: true) == .pass
        && gate.down(pid: 42, eligible: true, x: 10, y: 10) == .pass
}
check("a drag cancels the action while consuming the captured release") {
    var gate = ButtonGate()
    guard gate.arm(pid: 42), gate.down(pid: 42, eligible: true, x: 10, y: 10) == .consume else { return false }
    return gate.drag(x: 30, y: 10) == .consume && gate.up(eligible: true) == .release
}
check("stop while held drains the paired release without an action") {
    var gate = ButtonGate()
    guard gate.arm(pid: 42), gate.down(pid: 42, eligible: true, x: 10, y: 10) == .consume else { return false }
    return gate.stop() && gate.up(eligible: true) == .release && !gate.held
}
check("a changed window or modifier cancels rather than forwarding an orphan release") {
    var gate = ButtonGate()
    guard gate.arm(pid: 42), gate.down(pid: 42, eligible: true, x: 10, y: 10) == .consume else { return false }
    return gate.up(eligible: false) == .release && !gate.held
}
exit(failures == 0 ? 0 : 1)
