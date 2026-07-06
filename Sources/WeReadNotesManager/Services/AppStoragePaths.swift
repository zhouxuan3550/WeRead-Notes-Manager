import Foundation

enum AppStoragePaths {
    static let appSupportFolderName = "树懒书摘"
    private static let legacyAppSupportFolderName = "书摘" + "温故"

    static var applicationSupportDirectory: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let current = base.appendingPathComponent(appSupportFolderName, isDirectory: true)
        let legacy = base.appendingPathComponent(legacyAppSupportFolderName, isDirectory: true)

        if !fm.fileExists(atPath: current.path), fm.fileExists(atPath: legacy.path) {
            try? fm.copyItem(at: legacy, to: current)
        }

        try? fm.createDirectory(at: current, withIntermediateDirectories: true)
        return current
    }

    static func file(_ name: String) -> URL {
        applicationSupportDirectory.appendingPathComponent(name)
    }

    static func directory(_ name: String) -> URL {
        let dir = applicationSupportDirectory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
