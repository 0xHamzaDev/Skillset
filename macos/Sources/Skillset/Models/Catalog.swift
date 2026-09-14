import Foundation

struct Catalog: Codable, Sendable {
    var version: Int
    var updatedAt: String
    var skills: [CatalogSkill]
    var bundles: [SkillBundle]

    static let empty = Catalog(version: 0, updatedAt: "", skills: [], bundles: [])

    func skill(id: String) -> CatalogSkill? { skills.first { $0.id == id } }
    func skill(named name: String) -> CatalogSkill? { skills.first { $0.name == name } }
    func bundle(id: String) -> SkillBundle? { bundles.first { $0.id == id } }
    func skills(in bundle: SkillBundle) -> [CatalogSkill] { bundle.skills.compactMap(skill(id:)) }
}

struct CatalogSkill: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let name: String
    let description: String
    let author: String
    let tags: [String]
    let source: Source
}

struct SkillBundle: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: Localized
    let tagline: Localized
    let why: Localized
    let symbol: String
    let skills: [String]
    let tags: [String]
}

struct SkillRecommendation: Identifiable {
    let skill: CatalogSkill
    let reason: String
    let isPersonalized: Bool

    var id: String { skill.id }
}

struct Localized: Codable, Hashable, Sendable {
    let en: String
    let ar: String

    var current: String { en }
}

struct Source: Codable, Hashable, Sendable {
    let owner: String
    let repo: String
    let ref: String
    let path: String

    var slug: String { "\(owner)/\(repo)" }
    var skillKey: String { "\(slug.lowercased())/\(path)" }
    var repoKey: String { "\(owner)/\(repo)@\(ref)" }
    var folder: String { (path as NSString).lastPathComponent }
    var parent: String { (path as NSString).deletingLastPathComponent }
    var tarballURL: URL { URL(string: "https://codeload.github.com/\(owner)/\(repo)/tar.gz/\(ref)")! }
    var repoURL: URL { URL(string: "https://github.com/\(owner)/\(repo)")! }
    var webURL: URL { URL(string: "https://github.com/\(owner)/\(repo)/tree/\(ref)/\(path)")! }
    var rawSkillURL: URL { URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(ref)/\(path)/SKILL.md")! }
    var contentsAPI: URL { URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(parent)?ref=\(ref)")! }
    var installCommand: String { "npx skills add \(slug) --skill \(folder)" }
}
