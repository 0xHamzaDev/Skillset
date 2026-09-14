import Foundation

enum Paths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let skillsRoot = Agent.universal.root
    static let lockFile = home.appending(path: ".agents/.skill-lock.json")
    static let pluginManifest = home.appending(path: ".claude/plugins/installed_plugins.json")
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Skillset")
    static let catalogCache = support.appending(path: "catalog.json")

    static func isDirectory(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }

    static func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    static func occupied(_ url: URL) -> Bool {
        exists(url) || isSymlink(url)
    }

    static func isSymlink(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType == .typeSymbolicLink
    }

    static func realPath(_ url: URL) -> URL { url.resolvingSymlinksInPath().standardizedFileURL }

    static func children(_ url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }

    static func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "skillset-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
