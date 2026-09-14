import Foundation

struct Installer: Sendable {
    enum Failure: LocalizedError {
        case noSkill(String)
        case readOnly
        case unsafeName(String)

        var errorDescription: String? {
            switch self {
            case .noSkill(let path): "No SKILL.md at \(path) in the downloaded archive."
            case .readOnly: "This skill is managed by a plugin. Remove it from the plugin instead."
            case .unsafeName(let name): "The downloaded skill declares an unusable name: \(name)"
            }
        }
    }

    static let nameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")

    static func safeName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 128, !name.hasPrefix("."),
              name.unicodeScalars.allSatisfy(nameCharacters.contains)
        else { return nil }
        return name
    }

    var root = Paths.skillsRoot
    var lockFile = Paths.lockFile
    var agents: [Agent]?
    var trash: (@Sendable (URL) throws -> Void)?

    func fetchTree(_ source: Source, stage: @Sendable (InstallState.Stage) -> Void = { _ in }) async throws -> URL {
        let temp = try Paths.tempDirectory()
        let archive = temp.appending(path: "repo.tar.gz")
        stage(.downloading)
        try await GitHub.download(source.tarballURL, to: archive)
        stage(.extracting)
        let tree = temp.appending(path: "tree")
        try FileManager.default.createDirectory(at: tree, withIntermediateDirectories: true)
        try await Shell.run("/usr/bin/tar", ["-xzf", archive.path, "-C", tree.path, "--strip-components=1"])
        try? FileManager.default.removeItem(at: archive)
        return tree
    }

    func install(name fallback: String, source: Source, tree: URL, hash: String) throws -> InstalledSkill {
        let folder = tree.appending(path: source.path)
        guard let fm = Frontmatter.load(folder) else { throw Failure.noSkill(source.path) }
        let declared = fm.name ?? fallback
        guard let name = Self.safeName(declared) else { throw Failure.unsafeName(declared) }
        let destination = root.appending(path: name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try clear(destination, named: name)
        try FileManager.default.moveItem(at: folder, to: destination)
        let linked = link(name: name, to: destination)
        try SkillLock.update(at: lockFile) { lock in
            lock.entries[name] = SkillLock.Entry(source: source, hash: hash, installedAt: lock.entries[name]?.installedAt)
        }
        return InstalledSkill(
            name: name, frontmatterName: name, description: fm.description, path: destination,
            agents: [.universal] + linked, origin: .managed(source), hash: hash
        )
    }

    private func clear(_ destination: URL, named name: String) throws {
        guard Paths.occupied(destination) else { return }
        if Paths.isSymlink(destination) || !Paths.isDirectory(destination) {
            try FileManager.default.removeItem(at: destination)
            return
        }
        if SkillLock.load(from: lockFile).entries[name] != nil {
            try FileManager.default.removeItem(at: destination)
        } else if let trash {
            try trash(destination)
            try? FileManager.default.removeItem(at: destination)
        } else {
            try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
        }
    }

    func install(name: String, source: Source, stage: @Sendable (InstallState.Stage) -> Void = { _ in }) async throws -> InstalledSkill {
        let tree = try await fetchTree(source, stage: stage)
        defer { try? FileManager.default.removeItem(at: tree.deletingLastPathComponent()) }
        let hash = (try? await GitHub.folderHash(source)) ?? ""
        stage(.linking)
        return try install(name: name, source: source, tree: tree, hash: hash)
    }

    func remove(_ skill: InstalledSkill) throws {
        guard !skill.isReadOnly else { throw Failure.readOnly }
        let target = Paths.realPath(skill.path).standardizedFileURL.path
        for agent in Agent.allCases where agent != .universal {
            let link = agent.root.appending(path: skill.name)
            if Paths.isSymlink(link), Paths.realPath(link).standardizedFileURL.path == target {
                try FileManager.default.removeItem(at: link)
            }
        }
        if let trash {
            try trash(skill.path)
            try FileManager.default.removeItem(at: skill.path)
        } else {
            try FileManager.default.trashItem(at: skill.path, resultingItemURL: nil)
        }
        try SkillLock.update(at: lockFile) { $0.entries.removeValue(forKey: skill.name) }
    }

    static func claim(_ link: URL, for destination: URL) -> Bool {
        guard Paths.occupied(link) else { return true }
        guard Paths.isSymlink(link),
              !Paths.exists(link) || Paths.realPath(link) == Paths.realPath(destination)
        else { return false }
        try? FileManager.default.removeItem(at: link)
        return true
    }

    func link(name: String, to destination: URL) -> [Agent] {
        (agents ?? Agent.present).filter { agent in
            let link = agent.root.appending(path: name)
            guard Self.claim(link, for: destination) else { return false }
            try? FileManager.default.createDirectory(at: agent.root, withIntermediateDirectories: true)
            return (try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)) != nil
        }
    }
}
