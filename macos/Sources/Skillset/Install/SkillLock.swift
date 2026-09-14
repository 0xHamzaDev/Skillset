import Foundation

struct SkillLock: Codable, Sendable {
    struct Entry: Codable, Sendable {
        var source: String
        var sourceType: String
        var sourceUrl: String
        var skillPath: String
        var skillFolderHash: String
        var installedAt: String
        var updatedAt: String
        var ref: String?

        init(source: Source, hash: String, installedAt: String? = nil) {
            let now = SkillLock.timestamp()
            self.source = source.slug
            sourceType = "github"
            sourceUrl = source.repoURL.absoluteString + ".git"
            skillPath = source.path + "/SKILL.md"
            skillFolderHash = hash
            self.installedAt = installedAt ?? now
            updatedAt = now
            ref = source.ref
        }

        var resolvedSource: Source? {
            guard sourceType == "github" else { return nil }
            let parts = source.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            let path = (skillPath as NSString).deletingLastPathComponent
            return Source(owner: parts[0], repo: parts[1], ref: ref ?? "main", path: path)
        }

    }

    var version = 3
    var entries: [String: Entry] = [:]

    private enum CodingKeys: String, CodingKey { case version, entries = "skills" }

    private static let gate = NSLock()

    static func update(at url: URL = Paths.lockFile, _ body: (inout SkillLock) -> Void) throws {
        gate.lock()
        defer { gate.unlock() }
        var lock = load(from: url)
        body(&lock)
        try lock.save(to: url)
    }

    static func load(from url: URL = Paths.lockFile) -> SkillLock {
        guard let data = try? Data(contentsOf: url), let lock = try? JSONDecoder().decode(SkillLock.self, from: data) else {
            return SkillLock()
        }
        return lock
    }

    func save(to url: URL = Paths.lockFile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    static func timestamp() -> String {
        Date().formatted(.iso8601.year().month().day().dateTimeSeparator(.standard).time(includingFractionalSeconds: true).timeZone(separator: .omitted))
    }
}
