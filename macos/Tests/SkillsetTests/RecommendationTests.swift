import XCTest
@testable import Skillset

@MainActor
final class RecommendationTests: XCTestCase {
    private func skill(_ name: String, tags: [String] = [], source: Source? = nil) -> CatalogSkill {
        CatalogSkill(id: name, title: name, name: name, description: "", author: "", tags: tags,
                     source: source ?? Source(owner: "author", repo: "skills", ref: "main", path: name))
    }

    private func installed(_ name: String, origin: Origin = .manual, agents: [Agent] = [.universal]) -> InstalledSkill {
        InstalledSkill(name: name, frontmatterName: name, description: "", path: URL(fileURLWithPath: "/fixture/\(name)"),
                       agents: agents, origin: origin, hash: "")
    }

    private func bundle(_ ids: [String]) -> SkillBundle {
        let label = Localized(en: "Writing", ar: "")
        return SkillBundle(id: "writing", name: label, tagline: label, why: label, symbol: "", skills: ids, tags: [])
    }

    func testBundleGapsRankBeforeSharedTagsAndExplainTheirEvidence() {
        let store = Store()
        store.catalog = Catalog(version: 1, updatedAt: "", skills: [
            skill("unrelated"), skill("related", tags: ["documents"]),
            skill("missing"), skill("owned", tags: ["documents"]),
        ], bundles: [bundle(["owned", "missing"])])
        store.installed = [installed("owned"), installed("owned", origin: .plugin("sample"), agents: [.claude])]

        XCTAssertEqual(store.recommendations.map(\.id), ["missing", "related", "unrelated"])
        XCTAssertEqual(store.recommendations.map(\.reason), [
            "You have 1 of 2 skills in Writing.", "Shares documents with owned.", "A pick from the curated catalog.",
        ])
        XCTAssertEqual(store.recommendations.map(\.isPersonalized), [true, true, false])
    }

    func testEmptyAndUnrecognizedInstallationsGetHonestStableCuratedPicks() {
        let store = Store()
        store.catalog = Catalog(version: 1, updatedAt: "", skills: [skill("one"), skill("two"), skill("three"), skill("four")], bundles: [bundle(["one", "two"])])
        XCTAssertEqual(store.recommendations.map(\.id), ["one", "two", "three"])
        XCTAssertFalse(store.recommendations.contains(where: \.isPersonalized))
        XCTAssertEqual(store.recommendations.first?.reason, "Curated pick from Writing.")
        store.installed = [installed("unknown")]
        XCTAssertEqual(store.recommendations.map(\.id), ["one", "two", "three"])
        XCTAssertFalse(store.recommendations.contains(where: \.isPersonalized))
    }

    func testSourceIdentityWinsOverNamesAndSurvivesDifferentRefs() {
        let store = Store()
        let source = Source(owner: "author", repo: "skills", ref: "v1", path: "original")
        let local = installed("collision", origin: .managed(source))
        store.catalog = Catalog(version: 1, updatedAt: "", skills: [
            skill("collision", tags: ["unrelated"]),
            skill("original", tags: ["documents"]), skill("related", tags: ["documents"]),
        ], bundles: [])
        store.installed = [local]
        XCTAssertEqual(store.catalogSkill(for: local)?.id, "original")
        XCTAssertEqual(store.catalogSkill(id: local.path.path)?.id, "original")
        XCTAssertEqual(store.catalogSkill(id: "related")?.id, "related")
        XCTAssertEqual(store.recommendations.map(\.id), ["related"])
        XCTAssertEqual(store.recommendations.first?.reason, "Shares documents with original.")

        let unknown = installed("collision", origin: .managed(Source(owner: "other", repo: "skills", ref: "main", path: "original")))
        store.installed = [unknown]
        XCTAssertNil(store.catalogSkill(for: unknown))
        XCTAssertNil(store.catalogSkill(id: unknown.path.path))
        XCTAssertFalse(store.recommendations.contains(where: \.isPersonalized))
    }

    func testReadOnlyAgentSpecificBusyAndDuplicateSkillsAreNeverSuggested() {
        let store = Store()
        let sharedSource = Source(owner: "author", repo: "skills", ref: "main", path: "same")
        store.catalog = Catalog(version: 1, updatedAt: "", skills: [
            skill("plugin", tags: ["documents"]), skill("codex-only"), skill("busy"),
            skill("candidate", tags: ["documents"], source: sharedSource),
            skill("candidate", tags: ["documents"]), skill("alias", source: sharedSource),
        ], bundles: [])
        store.installed = [installed("plugin", origin: .plugin("sample"), agents: [.claude]), installed("codex-only", agents: [.codex])]
        store.transient["busy"] = .installing(.downloading)
        XCTAssertEqual(store.recommendations.map(\.id), ["candidate"])
        XCTAssertEqual(store.recommendations.first?.reason, "Shares documents with plugin.")
        XCTAssertTrue(store.pluginSkills.first?.isReadOnly == true)
        XCTAssertTrue(store.updatable.isEmpty)
        store.catalog.skills.remove(at: 4)
        store.installed.append(installed("candidate"))
        XCTAssertTrue(store.recommendations.isEmpty)
    }
}
