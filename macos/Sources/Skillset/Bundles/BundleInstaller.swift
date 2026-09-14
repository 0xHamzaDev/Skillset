import Foundation

struct BundleInstaller: Sendable {
    var installer = Installer()

    func install(
        _ skills: [CatalogSkill],
        state: @Sendable @escaping (CatalogSkill, InstallState) -> Void
    ) async -> [InstalledSkill] {
        var installed: [InstalledSkill] = []
        let groups = Dictionary(grouping: skills, by: \.source.repoKey)
        for group in groups.values.sorted(by: { $0[0].source.repoKey < $1[0].source.repoKey }) {
            for skill in group { state(skill, .installing(.downloading)) }
            let tree: URL
            do {
                tree = try await installer.fetchTree(group[0].source) { stage in
                    for skill in group { state(skill, .installing(stage)) }
                }
            } catch {
                for skill in group { state(skill, .failed(error.localizedDescription)) }
                continue
            }
            defer { try? FileManager.default.removeItem(at: tree.deletingLastPathComponent()) }
            var hashes: [URL: [String: String]] = [:]
            for skill in group {
                state(skill, .installing(.linking))
                let api = skill.source.contentsAPI
                if hashes[api] == nil { hashes[api] = (try? await GitHub.folderHashes(api)) ?? [:] }
                do {
                    installed.append(try installer.install(name: skill.name, source: skill.source, tree: tree, hash: hashes[api]?[skill.source.folder] ?? ""))
                    state(skill, .installed)
                } catch {
                    state(skill, .failed(error.localizedDescription))
                }
            }
        }
        return installed
    }
}
