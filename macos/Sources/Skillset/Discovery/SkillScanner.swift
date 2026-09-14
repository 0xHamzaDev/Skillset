import Foundation

enum SkillScanner {
    static func scan(lock: SkillLock = SkillLock.load()) -> [InstalledSkill] {
        var found: [URL: (name: String, agents: [Agent])] = [:]
        var order: [URL] = []
        for agent in Agent.allCases where Paths.isDirectory(agent.root) {
            for entry in Paths.children(agent.root) where isSkill(entry) {
                let real = Paths.realPath(entry)
                if found[real] == nil {
                    found[real] = (entry.lastPathComponent, [])
                    order.append(real)
                }
                found[real]?.agents.append(agent)
            }
        }
        var skills = order.map { real -> InstalledSkill in
            let (name, agents) = found[real]!
            let fm = Frontmatter.load(real)
            let entry = real.deletingLastPathComponent().path == Paths.skillsRoot.path ? lock.entries[name] : nil
            return InstalledSkill(
                name: name,
                frontmatterName: fm?.name ?? name,
                description: fm?.description ?? "",
                path: real,
                agents: agents,
                origin: entry?.resolvedSource.map(Origin.managed) ?? .manual,
                hash: entry?.skillFolderHash ?? ""
            )
        }
        skills += pluginSkills().filter { plugin in !skills.contains { $0.path == plugin.path } }
        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func isSkill(_ url: URL) -> Bool {
        !url.lastPathComponent.hasPrefix(".") && Paths.exists(url.appending(path: "SKILL.md"))
    }

    private static func pluginSkills() -> [InstalledSkill] {
        struct Manifest: Decodable { let plugins: [String: [Install]] }
        struct Install: Decodable { let installPath: String }
        guard let data = try? Data(contentsOf: Paths.pluginManifest),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return [] }
        return manifest.plugins.flatMap { key, installs in
            let plugin = key.split(separator: "@").first.map(String.init) ?? key
            return installs.flatMap { install in
                Paths.children(URL(fileURLWithPath: install.installPath).appending(path: "skills")).filter(isSkill).map { dir in
                    let fm = Frontmatter.load(dir)
                    return InstalledSkill(
                        name: dir.lastPathComponent,
                        frontmatterName: fm?.name ?? dir.lastPathComponent,
                        description: fm?.description ?? "",
                        path: dir,
                        agents: [.claude],
                        origin: .plugin(plugin),
                        hash: ""
                    )
                }
            }
        }
    }
}
