enum GateStep: Equatable {
    case pass, consume, release, press
}

struct ButtonGate {
    private(set) var held = false
    private var armedPID: Int32?
    private var canceled = false
    private var startX = 0.0
    private var startY = 0.0

    mutating func arm(pid: Int32) -> Bool {
        guard !held, pid > 0 else { return false }
        armedPID = pid
        return true
    }
    mutating func down(pid: Int32, eligible: Bool, x: Double, y: Double) -> GateStep {
        guard !held else { return .consume }
        guard eligible, armedPID == pid else { return .pass }
        armedPID = nil; held = true; canceled = false
        startX = x; startY = y
        return .consume
    }
    mutating func drag(x: Double, y: Double) -> GateStep {
        guard held else { return .pass }
        if hypot(x - startX, y - startY) > 4 { canceled = true }
        return .consume
    }
    mutating func up(eligible: Bool) -> GateStep {
        guard held else { return .pass }
        held = false
        return eligible && !canceled ? .press : .release
    }
    mutating func stop() -> Bool {
        armedPID = nil; canceled = true
        return held
    }
}
import Foundation

