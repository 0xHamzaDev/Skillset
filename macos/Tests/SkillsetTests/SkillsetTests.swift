import XCTest
@testable import Skillset

final class FrontmatterTests: XCTestCase {
    func testPlainQuotedAndFoldedScalars() {
        let text = """
        ---
        name: vercel-composition-patterns
        description:
          React composition patterns that scale. Use when refactoring
          components with boolean props.
        license: "MIT"
        ---
        # Title
        Body here.
        """
        let fm = Frontmatter.parse(text)
        XCTAssertEqual(fm.name, "vercel-composition-patterns")
        XCTAssertEqual(fm.description, "React composition patterns that scale. Use when refactoring components with boolean props.")
        XCTAssertEqual(fm.fields["license"], "MIT")
        XCTAssertEqual(fm.body.trimmingCharacters(in: .whitespacesAndNewlines), "# Title\nBody here.")
    }

    func testNoFrontmatter() {
        let fm = Frontmatter.parse("# Just markdown")
        XCTAssertNil(fm.name)
        XCTAssertEqual(fm.body, "# Just markdown")
    }
}

final class SearchTests: XCTestCase {
    func testPrefixBeatsContainsBeatsDescription() {
        let rows = [
            SkillRow(id: "a", name: "a", title: "Deploy", subtitle: "", description: "docx helper", symbol: "", tags: []),
            SkillRow(id: "docx", name: "docx", title: "Word", subtitle: "", description: "", symbol: "", tags: []),
            SkillRow(id: "b", name: "b", title: "My docx tools", subtitle: "", description: "", symbol: "", tags: ["react"]),
        ]
        XCTAssertEqual(Search.rank(rows, query: "doc").map(\.name), ["docx", "b", "a"])
        XCTAssertEqual(Search.rank(rows, query: "react").map(\.name), ["b"])
        XCTAssertEqual(Search.rank(rows, query: "").count, 3)
        XCTAssertEqual(Search.rank(rows, query: "zzz").count, 0)
    }
}

final class MarkdownTests: XCTestCase {
    func testBlocks() {
        let blocks = MarkdownView.Block.parse("# H1\n\nPara one\nstill one\n\n- a\n- b\n\n```\ncode\n```\n> q")
        guard blocks.count == 5 else { return XCTFail("got \(blocks.count) blocks") }
        if case .heading(1, "H1") = blocks[0] {} else { XCTFail("\(blocks[0])") }
        if case .paragraph("Para one still one") = blocks[1] {} else { XCTFail("\(blocks[1])") }
        if case .bullets(["a", "b"]) = blocks[2] {} else { XCTFail("\(blocks[2])") }
        if case .code("code") = blocks[3] {} else { XCTFail("\(blocks[3])") }
        if case .quote("q") = blocks[4] {} else { XCTFail("\(blocks[4])") }
    }
}

final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URL?

    var value: URL? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func record(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        stored = url
    }
}

final class SafeNameTests: XCTestCase {
    func testRejectsEscapesAndAcceptsOrdinaryNames() {
        XCTAssertEqual(Installer.safeName("better-ui"), "better-ui")
        XCTAssertEqual(Installer.safeName("  claude_api.v2  "), "claude_api.v2")
        for bad in ["../../.ssh", "a/b", "..", ".hidden", "", "name with space", "sk\u{0000}ill", String(repeating: "x", count: 129)] {
            XCTAssertNil(Installer.safeName(bad), "expected \(bad) to be rejected")
        }
    }
}

@MainActor
final class StoreIndexTests: XCTestCase {
    private func skill(_ name: String, path: String, readOnly: Bool) -> InstalledSkill {
        InstalledSkill(
            name: name, frontmatterName: name, description: "", path: URL(fileURLWithPath: path),
            agents: [.universal], origin: readOnly ? .plugin("p") : .manual, hash: ""
        )
    }

    func testAPluginCopyCountsAsPresentWithoutBeingManaged() {
        let store = Store()
        store.installed = [
            skill("brainstorming", path: "/plugins/brainstorming", readOnly: true),
            skill("better-ui", path: "/agents/better-ui", readOnly: false),
        ]
        XCTAssertEqual(store.state("better-ui"), .installed)
        XCTAssertEqual(store.state("brainstorming"), .installed)
        XCTAssertEqual(store.installedSkill(id: "/plugins/brainstorming")?.isReadOnly, true)
        XCTAssertEqual(store.rowName(for: "/agents/better-ui"), "better-ui")
        XCTAssertEqual(store.ownSkills.count, 1)

        store.installed.removeAll { $0.name == "better-ui" }
        XCTAssertEqual(store.state("better-ui"), .available)
        XCTAssertTrue(store.ownSkills.isEmpty)
        XCTAssertNil(store.installedSkill(id: "/agents/better-ui"))
    }

    func testCatalogIndexResolvesBySourceWhenNamesDiffer() {
        let store = Store()
        let source = Source(owner: "vercel-labs", repo: "agent-skills", ref: "main", path: "skills/composition-patterns")
        store.catalog = Catalog(
            version: 1, updatedAt: "",
            skills: [CatalogSkill(id: "composition-patterns", title: "Composition patterns", name: "vercel-composition-patterns", description: "", author: "Vercel", tags: [], source: source)],
            bundles: []
        )
        let local = InstalledSkill(
            name: "vercel-composition-patterns", frontmatterName: "vercel-composition-patterns", description: "",
            path: URL(fileURLWithPath: "/agents/x"), agents: [.universal], origin: .managed(source), hash: ""
        )
        XCTAssertEqual(store.catalogSkill(for: local)?.title, "Composition patterns")
    }
}

final class MarkdownTableTests: XCTestCase {
    func testTableRowsParseAndSeparatorIsDropped() {
        let blocks = MarkdownView.Block.parse("Intro\n\n| Quality | Good |\n|---------|------|\n| **Minimal** | One thing |\n\nAfter")
        guard blocks.count == 3 else { return XCTFail("got \(blocks.count): \(blocks)") }
        if case .paragraph("Intro") = blocks[0] {} else { XCTFail("\(blocks[0])") }
        if case .table(let rows) = blocks[1] {
            XCTAssertEqual(rows, [["Quality", "Good"], ["**Minimal**", "One thing"]])
        } else {
            XCTFail("\(blocks[1])")
        }
        if case .paragraph("After") = blocks[2] {} else { XCTFail("\(blocks[2])") }
    }

    func testTableEndingWithoutBlankLine() {
        let blocks = MarkdownView.Block.parse("| a | b |\n|---|---|\n| 1 | 2 |")
        if case .table(let rows) = blocks.last {
            XCTAssertEqual(rows, [["a", "b"], ["1", "2"]])
        } else {
            XCTFail("\(blocks)")
        }
    }
}

final class LockAndInstallTests: XCTestCase {
    let source = Source(owner: "acme", repo: "skills", ref: "main", path: "skills/hello")
    var temp: URL!

    override func setUpWithError() throws {
        temp = try Paths.tempDirectory()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temp)
    }

    func testLockRoundTripKeepsCLIShape() throws {
        var lock = SkillLock()
        lock.entries["hello"] = SkillLock.Entry(source: source, hash: "abc")
        let file = temp.appending(path: "lock.json")
        try lock.save(to: file)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        XCTAssertEqual(json["version"] as? Int, 3)
        let entry = (json["skills"] as! [String: Any])["hello"] as! [String: String]
        XCTAssertEqual(entry["source"], "acme/skills")
        XCTAssertEqual(entry["sourceType"], "github")
        XCTAssertEqual(entry["sourceUrl"], "https://github.com/acme/skills.git")
        XCTAssertEqual(entry["skillPath"], "skills/hello/SKILL.md")
        XCTAssertEqual(entry["skillFolderHash"], "abc")
        XCTAssertTrue(entry["installedAt"]!.hasSuffix("Z"))
        let loaded = SkillLock.load(from: file)
        XCTAssertEqual(loaded.entries["hello"]?.resolvedSource, source)
    }

    func testInstallFromTreeThenRemove() async throws {
        let tree = temp.appending(path: "tree")
        let folder = tree.appending(path: "skills/hello")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "---\nname: hello-world\ndescription: Says hi\n---\n# Hi".write(to: folder.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)
        let root = temp.appending(path: "root")
        let lockFile = temp.appending(path: "lock.json")
        let installer = Installer(root: root, lockFile: lockFile, agents: [])
        let skill = CatalogSkill(id: "hello", title: "Hello", name: "hello", description: "", author: "", tags: [], source: source)

        let installed = try installer.install(name: skill.name, source: skill.source, tree: tree, hash: "h1")
        XCTAssertEqual(installed.name, "hello-world")
        XCTAssertEqual(installed.description, "Says hi")
        XCTAssertTrue(Paths.exists(root.appending(path: "hello-world/SKILL.md")))
        XCTAssertEqual(SkillLock.load(from: lockFile).entries["hello-world"]?.skillFolderHash, "h1")

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "---\nname: hello-world\n---\nv2".write(to: folder.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)
        let updated = try installer.install(name: skill.name, source: skill.source, tree: tree, hash: "h2")
        XCTAssertEqual(try String(contentsOf: updated.path.appending(path: "SKILL.md"), encoding: .utf8), "---\nname: hello-world\n---\nv2")
        let entry = SkillLock.load(from: lockFile).entries["hello-world"]
        XCTAssertEqual(entry?.skillFolderHash, "h2")
        XCTAssertEqual(entry?.installedAt, SkillLock.load(from: lockFile).entries["hello-world"]?.installedAt)

        XCTAssertThrowsError(try installer.install(name: "x", source: Source(owner: "a", repo: "b", ref: "main", path: "skills/missing"), tree: tree, hash: ""))
    }

    func testRemoveTrashesTheSkillFolder() throws {
        let tree = temp.appending(path: "tree3")
        let folder = tree.appending(path: "skills/hello")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "---\nname: linked\n---\nx".write(to: folder.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)

        let root = temp.appending(path: "root3")
        let agentRoot = temp.appending(path: "agent3/skills")
        try FileManager.default.createDirectory(at: agentRoot, withIntermediateDirectories: true)

        var installer = Installer(root: root, lockFile: temp.appending(path: "lock3.json"), agents: [])
        let skill = CatalogSkill(id: "hello", title: "", name: "hello", description: "", author: "", tags: [], source: source)
        let installed = try installer.install(name: skill.name, source: skill.source, tree: tree, hash: "h")

        let link = agentRoot.appending(path: "linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: installed.path)
        XCTAssertTrue(Paths.isSymlink(link))

        let trashed = Recorder()
        installer.trash = { trashed.record($0) }
        try installer.remove(installed)
        XCTAssertEqual(trashed.value?.lastPathComponent, "linked")
        XCTAssertFalse(Paths.isDirectory(installed.path))
        XCTAssertNil(SkillLock.load(from: temp.appending(path: "lock3.json")).entries["linked"])
    }

    func testHandInstalledFolderIsTrashedNotDeleted() throws {
        let tree = temp.appending(path: "tree")
        let folder = tree.appending(path: "skills/hello")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "---\nname: mine\n---\nnew".write(to: folder.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)

        let root = temp.appending(path: "root")
        let existing = root.appending(path: "mine")
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        try "keep me".write(to: existing.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)

        let trashed = Recorder()
        let installer = Installer(root: root, lockFile: temp.appending(path: "lock.json"), agents: [], trash: { trashed.record($0) })
        let result = try installer.install(name: "hello", source: source, tree: tree, hash: "h")
        XCTAssertEqual(trashed.value?.lastPathComponent, "mine")
        XCTAssertEqual(try String(contentsOf: result.path.appending(path: "SKILL.md"), encoding: .utf8), "---\nname: mine\n---\nnew")
    }

    func testDanglingSymlinkAtDestinationDoesNotBlockInstall() throws {
        let tree = temp.appending(path: "tree2")
        let folder = tree.appending(path: "skills/hello")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "---\nname: ghost\n---\nx".write(to: folder.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)

        let root = temp.appending(path: "root2")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "ghost"), withDestinationURL: temp.appending(path: "gone"))

        let installer = Installer(root: root, lockFile: temp.appending(path: "lock2.json"), agents: [])
        let result = try installer.install(name: "hello", source: source, tree: tree, hash: "h")
        XCTAssertTrue(Paths.isDirectory(result.path))
    }

    func testLinkingLeavesSomeoneElsesSymlinkAlone() throws {
        let mine = temp.appending(path: "canonical/hello")
        let theirs = temp.appending(path: "elsewhere/hello")
        try FileManager.default.createDirectory(at: mine, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: theirs, withIntermediateDirectories: true)
        let agentRoot = temp.appending(path: "agent")
        try FileManager.default.createDirectory(at: agentRoot, withIntermediateDirectories: true)

        let link = agentRoot.appending(path: "hello")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: theirs)
        XCTAssertFalse(Installer.claim(link, for: mine))
        XCTAssertEqual(Paths.realPath(link), Paths.realPath(theirs))

        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: mine)
        XCTAssertTrue(Installer.claim(link, for: mine))
        XCTAssertFalse(Paths.occupied(link))

        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: temp.appending(path: "gone"))
        XCTAssertTrue(Installer.claim(link, for: mine))

        let real = agentRoot.appending(path: "real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        XCTAssertFalse(Installer.claim(real, for: mine))
    }

    func testTarExtractsWithStrippedRoot() async throws {
        let repo = temp.appending(path: "acme-main/skills/hello")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try "x".write(to: repo.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)
        let archive = temp.appending(path: "repo.tar.gz")
        try await Shell.run("/usr/bin/tar", ["-czf", archive.path, "-C", temp.path, "acme-main"])
        let out = temp.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try await Shell.run("/usr/bin/tar", ["-xzf", archive.path, "-C", out.path, "--strip-components=1"])
        XCTAssertTrue(Paths.exists(out.appending(path: "skills/hello/SKILL.md")))
        await XCTAssertThrowsErrorAsync(try await Shell.run("/usr/bin/tar", ["-xzf", "/nonexistent.tgz"]))
    }
}

func XCTAssertThrowsErrorAsync(_ expression: @autoclosure () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do {
        try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {}
}

final class CondensedTests: XCTestCase {
    func testALongDescriptionKeepsOnlyItsFirstSentence() {
        let whole = "Use this skill whenever the user wants to create, read, edit, or manipulate Word documents (.docx files) or Word templates (.dotx files). Triggers include: any mention of 'Word doc', 'word document', '.docx', '.dotx', or requests to produce professional documents with formatting like tables of contents, headings, page numbers, or letterheads."
        XCTAssertEqual(whole.condensed, "Use this skill whenever the user wants to create, read, edit, or manipulate Word documents (.docx files) or Word templates (.dotx files).")
    }

    func testAShortDescriptionIsLeftWhole() {
        let whole = "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes"
        XCTAssertEqual(whole.condensed, whole)
    }

    func testASecondSentenceTooShortToHideIsLeftWhole() {
        let whole = "Toolkit for styling artifacts with a theme. These can be slides or docs."
        XCTAssertEqual(whole.condensed, whole)
    }
}
