import Foundation

@MainActor
final class Diagnostics {
    var enabled = false
    let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/ClickThrough")
    private let queue = DispatchQueue(label: "local.clickthrough.diagnostics", qos: .utility)
    private let filename = "session-\(UUID().uuidString).jsonl"

    func record(_ kind: String, fields: [String: String] = [:]) {
        guard enabled else { return }
        let row: [String: Any] = ["time": Date().timeIntervalSince1970, "kind": kind, "fields": fields]
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
        data.append(0x0A)
        let payload = data
        let file = directory.appendingPathComponent(filename)
        queue.async {
            do {
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: file.path) {
                    FileManager.default.createFile(atPath: file.path, contents: nil,
                                                   attributes: [.posixPermissions: 0o600])
                }
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                // Bound optional diagnostics to 2 MiB per process; preserve existing logs.
                guard try handle.seekToEnd() + UInt64(payload.count) <= 2 * 1_024 * 1_024 else { return }
                try handle.write(contentsOf: payload)
            } catch { /* Diagnostics must never disrupt input. */ }
        }
    }

    func flush() { queue.sync {} }
}
