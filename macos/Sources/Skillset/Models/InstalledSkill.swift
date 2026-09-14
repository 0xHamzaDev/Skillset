import Foundation

enum Agent: String, CaseIterable, Identifiable, Sendable {
    case universal, claude, codex, cursor, opencode, kiro, gemini, copilot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .universal: "Universal"
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .opencode: "OpenCode"
        case .kiro: "Kiro"
        case .gemini: "Gemini CLI"
        case .copilot: "Copilot"
        }
    }

    var root: URL {
        switch self {
        case .universal: Paths.home.appending(path: ".agents/skills")
        case .claude: Paths.home.appending(path: ".claude/skills")
        case .codex: Paths.home.appending(path: ".codex/skills")
        case .cursor: Paths.home.appending(path: ".cursor/skills")
        case .opencode: Paths.home.appending(path: ".config/opencode/skills")
        case .kiro: Paths.home.appending(path: ".kiro/skills")
        case .gemini: Paths.home.appending(path: ".gemini/skills")
        case .copilot: Paths.home.appending(path: ".copilot/skills")
        }
    }

    var isPresent: Bool { Paths.isDirectory(root.deletingLastPathComponent()) }

    static var present: [Agent] { allCases.filter { $0 != .universal && $0.isPresent } }
}

enum Origin: Hashable, Sendable {
    case managed(Source)
    case manual
    case plugin(String)
}

struct InstalledSkill: Identifiable, Hashable, Sendable {
    let name: String
    let frontmatterName: String
    let description: String
    let path: URL
    let agents: [Agent]
    let origin: Origin
    let hash: String

    var id: String { name }
    var isReadOnly: Bool { if case .plugin = origin { true } else { false } }
    var source: Source? { if case .managed(let s) = origin { s } else { nil } }
}

enum InstallState: Hashable, Sendable {
    enum Stage: Sendable { case downloading, extracting, linking }

    case available
    case installing(Stage)
    case installed
    case updateAvailable
    case updating(Stage)
    case removing
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .installing, .updating, .removing: true
        default: false
        }
    }

    var isInstalled: Bool {
        switch self {
        case .installed, .updateAvailable, .updating: true
        default: false
        }
    }
}
