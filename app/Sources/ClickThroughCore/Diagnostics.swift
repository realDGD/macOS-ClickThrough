import Foundation

@MainActor
public final class Diagnostics {
    public var enabled = false
    public var detailedEnabled = false
    public var recordsDetailed: Bool { enabled && detailedEnabled }
    public let directory: URL
    nonisolated static let maximumFileBytes = 2 * 1_024 * 1_024
    nonisolated static let maximumTotalBytes = 20 * 1_024 * 1_024
    nonisolated static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60
    private let queue = DispatchQueue(label: "local.clickthrough.diagnostics", qos: .utility)
    private let filename = "session-\(UUID().uuidString).jsonl"

    public init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/ClickThrough")) {
        self.directory = directory
        // Retention also applies at startup when recording is disabled.
        queue.async { try? Self.clean(directory: directory) }
    }

    public func record(_ kind: String, fields: [String: String] = [:], detailed: Bool = false) {
        guard enabled, !detailed || detailedEnabled else { return }
        let time = Date().timeIntervalSince1970
        let directory = directory
        let file = directory.appendingPathComponent(filename)
        queue.async {
            do {
                let row: [String: Any] = ["time": time, "kind": kind, "fields": fields]
                var data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
                data.append(0x0A)
                guard data.count <= Self.maximumFileBytes else { return }
                let manager = FileManager.default
                try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
                if manager.fileExists(atPath: file.path) {
                    let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    if size + data.count > Self.maximumFileBytes {
                        let archive = directory.appendingPathComponent("session-\(UUID().uuidString).jsonl")
                        try manager.moveItem(at: file, to: archive)
                    }
                }
                try Self.clean(directory: directory, preserving: file, reserving: data.count)
                if !manager.fileExists(atPath: file.path) {
                    guard manager.createFile(atPath: file.path, contents: nil,
                                             attributes: [.posixPermissions: 0o600]) else { return }
                }
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch { /* Diagnostics must never disrupt input. */ }
        }
    }

    public func flush() { queue.sync {} }

    private nonisolated static func clean(directory: URL, preserving active: URL? = nil,
                                         reserving bytes: Int = 0) throws {
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey,
                                         .fileSizeKey, .contentModificationDateKey]
        let urls = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys),
                                                  options: [.skipsHiddenFiles])
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        var files: [(url: URL, size: Int, modified: Date)] = []
        for url in urls where url.lastPathComponent.hasPrefix("session-") && url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate, let size = values.fileSize else { continue }
            if modified < cutoff {
                try manager.removeItem(at: url)
            } else {
                files.append((url, size, modified))
            }
        }
        var total = files.reduce(bytes) { $0 + $1.size }
        for file in files.sorted(by: { $0.modified < $1.modified }) {
            guard total > maximumTotalBytes else { break }
            guard file.url != active else { continue }
            try manager.removeItem(at: file.url)
            total -= file.size
        }
        guard total <= maximumTotalBytes else { throw CocoaError(.fileWriteOutOfSpace) }
    }
}
