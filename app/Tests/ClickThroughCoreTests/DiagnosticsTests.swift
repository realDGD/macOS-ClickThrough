import Foundation
import Testing
@testable import ClickThroughCore

private func temporaryLogs() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func logFiles(in directory: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("session-") && $0.pathExtension == "jsonl" }
}

@MainActor @Test func detailedLoggingRequiresBothSwitchesAndCanReturnToBasic() throws {
    let directory = try temporaryLogs()
    defer { try? FileManager.default.removeItem(at: directory) }
    let diagnostics = Diagnostics(directory: directory)
    diagnostics.detailedEnabled = true
    #expect(!diagnostics.recordsDetailed)
    diagnostics.record("disabled")
    diagnostics.record("disabled_detail", detailed: true)
    diagnostics.enabled = true
    #expect(diagnostics.recordsDetailed)
    diagnostics.record("mouse_down", fields: ["event_number": "42"], detailed: true)
    diagnostics.record("activation_request", fields: ["event_number": "42"])
    diagnostics.detailedEnabled = false
    diagnostics.record("hidden_detail", detailed: true)
    diagnostics.record("basic_after_detail")
    diagnostics.flush()
    let file = try #require(logFiles(in: directory).first)
    let rows = try String(contentsOf: file, encoding: .utf8).split(separator: "\n").map {
        try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
    }
    #expect(rows.compactMap { $0["kind"] as? String } == ["mouse_down", "activation_request", "basic_after_detail"])
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@MainActor @Test func fullLogRotatesAndKeepsRecording() throws {
    let directory = try temporaryLogs()
    defer { try? FileManager.default.removeItem(at: directory) }
    let diagnostics = Diagnostics(directory: directory)
    diagnostics.enabled = true
    diagnostics.record("before_rotation", fields: ["padding": String(repeating: "x", count: Diagnostics.maximumFileBytes - 512)])
    diagnostics.record("after_rotation", fields: ["padding": String(repeating: "y", count: 1_024)])
    diagnostics.flush()
    let files = try logFiles(in: directory)
    #expect(files.count == 2)
    var kinds: [String] = []
    for file in files {
        let data = try Data(contentsOf: file)
        #expect(data.count <= Diagnostics.maximumFileBytes)
        let row = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        kinds.append(try #require(row["kind"] as? String))
    }
    #expect(Set(kinds) == ["before_rotation", "after_rotation"])
}

@MainActor @Test func startupCleansExpiredAppLogsEvenWhenLoggingIsOff() throws {
    let directory = try temporaryLogs()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stale = directory.appendingPathComponent("session-old.jsonl")
    let recent = directory.appendingPathComponent("session-recent.jsonl")
    let unrelated = directory.appendingPathComponent("notes.txt")
    let link = directory.appendingPathComponent("session-link.jsonl")
    for file in [stale, recent, unrelated] { try Data("preserved".utf8).write(to: file) }
    let oldDate = Date().addingTimeInterval(-Diagnostics.retentionInterval - 60)
    for file in [stale, unrelated] {
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
    }
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: unrelated)
    let diagnostics = Diagnostics(directory: directory)
    #expect(!diagnostics.enabled)
    diagnostics.flush()
    #expect(!FileManager.default.fileExists(atPath: stale.path))
    #expect(try Data(contentsOf: recent) == Data("preserved".utf8))
    #expect(try Data(contentsOf: unrelated) == Data("preserved".utf8))
    #expect(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
}

@MainActor @Test func totalLimitEvictsOldestLogsAndKeepsNewEvents() throws {
    let directory = try temporaryLogs()
    defer { try? FileManager.default.removeItem(at: directory) }
    let manager = FileManager.default
    let now = Date()
    for index in 0..<10 {
        let file = directory.appendingPathComponent("session-\(index).jsonl")
        try Data(repeating: 0x20, count: Diagnostics.maximumFileBytes).write(to: file)
        try manager.setAttributes([.modificationDate: now.addingTimeInterval(Double(index - 20))], ofItemAtPath: file.path)
    }
    let diagnostics = Diagnostics(directory: directory)
    diagnostics.enabled = true
    diagnostics.record("new_event")
    diagnostics.flush()
    let files = try logFiles(in: directory)
    let total = try files.reduce(0) { $0 + (try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    #expect(total <= Diagnostics.maximumTotalBytes)
    #expect(!manager.fileExists(atPath: directory.appendingPathComponent("session-0.jsonl").path))
    #expect(manager.fileExists(atPath: directory.appendingPathComponent("session-9.jsonl").path))
    #expect(try files.contains { try String(contentsOf: $0, encoding: .utf8).contains("new_event") })
}

@MainActor @Test func oversizedRecordDoesNotPreventFollowingRecords() throws {
    let directory = try temporaryLogs()
    defer { try? FileManager.default.removeItem(at: directory) }
    let diagnostics = Diagnostics(directory: directory)
    diagnostics.enabled = true
    diagnostics.record("oversized", fields: ["padding": String(repeating: "x", count: Diagnostics.maximumFileBytes)])
    diagnostics.record("still_recording")
    diagnostics.flush()
    let file = try #require(logFiles(in: directory).first)
    let row = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    #expect(row["kind"] as? String == "still_recording")
}
