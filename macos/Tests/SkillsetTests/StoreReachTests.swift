import XCTest
@testable import Skillset

@MainActor
final class StoreReachTests: XCTestCase {
    private func skill(_ name: String, _ agents: [Agent], origin: Origin = .manual) -> InstalledSkill {
        InstalledSkill(
            name: name,
            frontmatterName: name,
            description: "",
            path: Paths.skillsRoot.appending(path: name),
            agents: agents,
            origin: origin,
            hash: ""
        )
    }

    func testOnlyTheCopySkillsetCanFetchIsOfferedTheUpdate() {
        let source = Source(owner: "vercel-labs", repo: "skills", ref: "main", path: "find-skills")
        let store = Store()
        store.installed = [
            skill("find-skills", [.universal], origin: .managed(source)),
            skill("find-skills", [.claude]),
            skill("find-skills", [.claude], origin: .plugin("Claude Code")),
        ]
        store.updates = ["find-skills"]

        XCTAssertEqual(store.updatable.map(\.origin), [.managed(source)])
        XCTAssertEqual(store.updatable.count, store.updates.count)
    }

    func testALinkToAnUnknownSkillSaysSoInsteadOfDoingNothing() {
        let store = Store()
        store.catalog = Catalog(
            version: 1,
            updatedAt: "",
            skills: [CatalogSkill(id: "pdf", title: "PDF", name: "pdf", description: "", author: "", tags: [], source: Source(owner: "a", repo: "b", ref: "main", path: "pdf"))],
            bundles: []
        )

        store.open(URL(string: "skillset://skill/pdf")!)
        XCTAssertEqual(store.pane, .discover)
        XCTAssertEqual(store.selection[.discover], "pdf")

        store.open(URL(string: "skillset://skill/nope")!)
        XCTAssertEqual(store.toast?.kind, .failure)
    }

    func testOnlySkillsInTheSkillsetFolderCountTowardsReach() {
        let store = Store()
        store.installed = [
            skill("shared", [.universal, .claude]),
            skill("codex-only", [.codex]),
        ]

        XCTAssertEqual(store.rootSkills.map(\.name), ["shared"])
        XCTAssertEqual(store.linked(into: .claude), 1)
        XCTAssertEqual(store.linked(into: .codex), 0)
    }
}
