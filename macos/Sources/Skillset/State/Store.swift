import Foundation
import SwiftUI
import Observation

enum Pane: String, CaseIterable, Identifiable {
    case installed, discover, bundles, updates
    var id: String { rawValue }
}

struct Toast: Equatable {
    enum Kind { case info, success, failure }
    let kind: Kind
    let text: String
}

@MainActor
@Observable
final class Store {
    var installed: [InstalledSkill] = [] { didSet { reindex() } }
    var catalog = Catalog.empty { didSet { reindex() } }
    var catalogOrigin = CatalogOrigin.none
    var transient: [String: InstallState] = [:]
    var updates: Set<String> = []
    var lastUpdateCheck: Date?
    var lastUpdateError: String?
    var lastCatalogError: String?
    var scanning = false
    var loadingCatalog = false
    var checkingUpdates = false
    var updatingAll = false
    var pane = Pane(rawValue: UserDefaults.standard.string(forKey: "pane") ?? "") ?? .discover {
        didSet { UserDefaults.standard.set(pane.rawValue, forKey: "pane") }
    }
    var listFocused = false
    var selection: [Pane: String] = [:]
    var selectedSkill: String? {
        get { pane == .bundles ? nil : selection[pane] }
        set { selection[pane] = newValue }
    }
    var selectedBundle: String? {
        get { selection[.bundles] }
        set { selection[.bundles] = newValue }
    }
    var query = ""
    var toast: Toast?
    var focusSearch = 0
    var onboardingStep = 0
    var showInstructions = true
    private var pendingLink: URL?

    let installer = Installer()

    var busy: Bool { scanning || loadingCatalog || checkingUpdates }

    var subtitle: String {
        switch pane {
        case .installed: installed.count == 1 ? "1 skill" : "\(installed.count) skills"
        case .discover: "\(catalog.skills.count) skills"
        case .bundles: "\(catalog.bundles.count) bundles"
        case .updates: updatable.count == 1 ? "1 update" : "\(updatable.count) updates"
        }
    }

    var activity: LocalizedStringKey {
        if scanning { "Scanning this Mac" } else if loadingCatalog { "Loading catalogue" } else { "Checking for updates" }
    }

    private(set) var ownSkills: [InstalledSkill] = []
    private(set) var rootSkills: [InstalledSkill] = []
    private(set) var pluginSkills: [InstalledSkill] = []
    private(set) var managedNames: Set<String> = []
    private(set) var pluginIds: Set<String> = []
    private(set) var installedByName: [String: InstalledSkill] = [:]
    private(set) var installedById: [String: InstalledSkill] = [:]
    private(set) var catalogByName: [String: CatalogSkill] = [:]
    private(set) var catalogBySource: [Source: CatalogSkill] = [:]

    private func reindex() {
        ownSkills = installed.filter { !$0.isReadOnly }
        rootSkills = ownSkills.filter { $0.agents.contains(.universal) }
        pluginSkills = installed.filter(\.isReadOnly)
        managedNames = Set((rootSkills + pluginSkills).flatMap { [$0.name, $0.frontmatterName] })
        pluginIds = Set(pluginSkills.map(\.path.path))
        installedByName = Dictionary((ownSkills + pluginSkills).map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        installedById = Dictionary(installed.map { ($0.path.path, $0) }, uniquingKeysWith: { a, _ in a })
        catalogByName = Dictionary(catalog.skills.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        catalogBySource = Dictionary(catalog.skills.map { ($0.source, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var documents: [URL: String] = [:]

    func document(at url: URL) async throws -> String {
        if let cached = documents[url] { return cached }
        let text = try await GitHub.text(url)
        documents[url] = text
        return text
    }

    func keepSelection(_ pane: Pane, among ids: [String], startOver: Bool = false) {
        guard let first = ids.first else { return selection[pane] = nil }
        if !startOver, let current = selection[pane], ids.contains(current) { return }
        selection[pane] = first
    }

    func installedSkill(id: String) -> InstalledSkill? {
        installedById[id] ?? installedByName[id]
    }

    func rowName(for id: String) -> String {
        installedById[id]?.name ?? id
    }

    func state(_ name: String) -> InstallState {
        if let t = transient[name] { return t }
        if managedNames.contains(name) { return updates.contains(name) ? .updateAvailable : .installed }
        return .available
    }

    func installedSkill(named name: String) -> InstalledSkill? {
        installedByName[name] ?? installed.first { $0.frontmatterName == name }
    }

    func catalogSkill(id: String) -> CatalogSkill? {
        if let installed = installedById[id] { return catalogSkill(for: installed) }
        return catalogByName[id]
    }

    func catalogSkill(for installed: InstalledSkill) -> CatalogSkill? {
        if let source = installed.source {
            return catalogBySource[source] ?? catalog.skills.first { $0.source.skillKey == source.skillKey }
        }
        let matches = catalog.skills.filter { $0.name == installed.name || $0.name == installed.frontmatterName }
        return matches.count == 1 ? matches[0] : nil
    }

    var recommendations: [SkillRecommendation] {
        let knownIds = Set(installed.compactMap(catalogSkill(for:)).map(\.id))
        let known = catalog.skills.filter { knownIds.contains($0.id) }
        let installedNames = Set(installed.flatMap { [$0.name, $0.frontmatterName] })
        let installedSources = Set(installed.compactMap { $0.source?.skillKey } + known.map { $0.source.skillKey })
        var seenIds = Set<String>()
        var seenNames = Set<String>()
        var seenSources = Set<String>()
        return catalog.skills.enumerated().compactMap { index, skill -> (SkillRecommendation, Int, Int, Int)? in
            guard !knownIds.contains(skill.id), !installedNames.contains(skill.name),
                  !installedSources.contains(skill.source.skillKey), !state(skill.name).isBusy,
                  seenIds.insert(skill.id).inserted, seenNames.insert(skill.name).inserted,
                  seenSources.insert(skill.source.skillKey).inserted else { return nil }
            let bundle = catalog.bundles.filter { $0.skills.contains(skill.id) }
                .max { Set($0.skills).intersection(knownIds).count < Set($1.skills).intersection(knownIds).count }
            if let bundle {
                let count = Set(bundle.skills).intersection(knownIds).count
                if count > 0 {
                    return (SkillRecommendation(skill: skill, reason: "You have \(count) of \(Set(bundle.skills).count) skills in \(bundle.name.en).", isPersonalized: true), 2, count, index)
                }
            }
            let related = known.map { ($0, Set($0.tags).intersection(skill.tags).sorted()) }
                .filter { !$0.1.isEmpty }.max { $0.1.count < $1.1.count }
            if let (installed, tags) = related {
                return (SkillRecommendation(skill: skill, reason: "Shares \(tags.joined(separator: ", ")) with \(installed.title).", isPersonalized: true), 1, tags.count, index)
            }
            let reason = bundle.map { "Curated pick from \($0.name.en)." } ?? "A pick from the curated catalog."
            return (SkillRecommendation(skill: skill, reason: reason, isPersonalized: false), 0, 0, index)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.3 < $1.3
        }
        .prefix(3).map(\.0)
    }

    func bootstrap() async {
        async let scan: Void = rescan()
        async let load: Void = loadCatalog()
        _ = await (scan, load)
        if UserDefaults.standard.object(forKey: "checkOnLaunch") as? Bool ?? true { await checkUpdates(quiet: true) }
    }

    func refresh() async {
        async let scan: Void = rescan()
        async let load: Void = loadCatalog()
        _ = await (scan, load)
        await checkUpdates()
    }

    func rescan() async {
        scanning = true
        installed = await Task.detached { SkillScanner.scan() }.value
        transient = transient.filter { $0.value.isBusy }
        scanning = false
    }

    func loadCatalog() async {
        loadingCatalog = true
        (catalog, catalogOrigin, lastCatalogError) = await CatalogClient().load()
        loadingCatalog = false
        if let link = pendingLink {
            pendingLink = nil
            open(link)
        }
    }

    func install(_ skill: CatalogSkill) async {
        await install(name: skill.name, source: skill.source, title: skill.title)
    }

    func update(_ skill: InstalledSkill) async {
        guard let source = skill.source else { return }
        await install(name: skill.name, source: source, title: skill.frontmatterName)
    }

    private func install(name: String, source: Source, title: String) async {
        guard !state(name).isBusy else { return }
        let updating = state(name).isInstalled
        transient[name] = updating ? .updating(.downloading) : .installing(.downloading)
        do {
            let result = try await installer.install(name: name, source: source) { stage in
                Task { @MainActor in self.transient[name] = updating ? .updating(stage) : .installing(stage) }
            }
            installed.removeAll { $0.path == result.path }
            installed.append(result)
            installed.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            updates.remove(name)
            transient[name] = nil
            toast = Toast(kind: .success, text: updating ? "\(title) updated" : "\(title) installed")
        } catch {
            transient[name] = .failed(error.localizedDescription)
            toast = Toast(kind: .failure, text: error.localizedDescription)
        }
    }

    func remove(_ skill: InstalledSkill) async {
        guard !state(skill.name).isBusy else { return }
        transient[skill.name] = .removing
        do {
            let installer = installer
            try await Task.detached { try installer.remove(skill) }.value
            if selection[.installed] == skill.path.path { selection[.installed] = nil }
            if selection[.updates] == skill.path.path { selection[.updates] = nil }
            installed.removeAll { $0.path == skill.path }
            updates.remove(skill.name)
            transient[skill.name] = nil
            toast = Toast(kind: .info, text: "\(skill.name) moved to the Trash")
        } catch {
            transient[skill.name] = .failed(error.localizedDescription)
            toast = Toast(kind: .failure, text: error.localizedDescription)
        }
    }

    func install(bundle: SkillBundle) async {
        let skills = catalog.skills(in: bundle).filter { !state($0.name).isInstalled && !state($0.name).isBusy }
        guard !skills.isEmpty else { return }
        for skill in skills { transient[skill.name] = .installing(.downloading) }
        let results = await BundleInstaller(installer: installer).install(skills) { skill, state in
            Task { @MainActor in
                self.transient[skill.name] = state == .installed ? nil : state
                if case .failed = state { self.transient[skill.name] = state }
            }
        }
        for result in results {
            installed.removeAll { $0.path == result.path }
            installed.append(result)
        }
        installed.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let failed = skills.count - results.count
        toast = failed == 0
            ? Toast(kind: .success, text: "\(bundle.name.current): \(results.count) installed")
            : Toast(kind: .failure, text: "\(results.count) installed, \(failed) failed")
    }

    var updatable: [InstalledSkill] { ownSkills.filter { $0.source != nil && updates.contains($0.name) } }

    func checkUpdates(quiet: Bool = false) async {
        guard !checkingUpdates else { return }
        checkingUpdates = true
        let managed = ownSkills.compactMap { skill in skill.source.map { (skill, $0) } }
        var hashes: [URL: [String: String]] = [:]
        var failure: Error?
        await withTaskGroup(of: (URL, Result<[String: String], Error>).self) { group in
            for url in Set(managed.map(\.1.contentsAPI)) {
                group.addTask { (url, await Result { try await GitHub.folderHashes(url) }) }
            }
            for await (url, result) in group {
                switch result {
                case .success(let map): hashes[url] = map
                case .failure(let error): failure = error
                }
            }
        }
        var found: Set<String> = []
        for (skill, source) in managed {
            guard let remote = hashes[source.contentsAPI]?[source.folder] else { continue }
            if skill.hash.isEmpty || remote != skill.hash { found.insert(skill.name) }
        }
        updates = found
        lastUpdateCheck = failure == nil ? Date() : lastUpdateCheck
        checkingUpdates = false
        lastUpdateError = failure?.localizedDescription
        if let failure {
            toast = Toast(kind: .failure, text: failure.localizedDescription)
        } else if !quiet {
            toast = Toast(kind: .info, text: updatable.isEmpty ? "Everything is up to date" : updatable.count == 1 ? "1 update available" : "\(updatable.count) updates available")
        }
    }

    func updateAll() async {
        guard !updatingAll else { return }
        updatingAll = true
        let targets = updatable
        var failures = 0
        for skill in targets {
            if let listed = catalogSkill(for: skill) { await install(listed) } else { await update(skill) }
            if case .failed = state(skill.name) { failures += 1 }
        }
        updatingAll = false
        guard failures == 0 else { return }
        toast = Toast(kind: .success, text: targets.count == 1 ? "1 skill updated" : "\(targets.count) skills updated")
    }

    func actOnSelection() async {
        if pane == .bundles {
            guard let bundle = selectedBundle.flatMap(catalog.bundle(id:)) else { return }
            if progress(for: bundle).failed.isEmpty { await install(bundle: bundle) } else { await retryFailed(in: bundle) }
            return
        }
        guard let id = selectedSkill else { return }
        let name = rowName(for: id)
        guard installedSkill(id: id)?.isReadOnly != true else { return }
        switch state(name) {
        case .available, .updateAvailable, .failed:
            if let skill = catalogSkill(id: id) {
                await install(skill)
            } else if let installed = installedSkill(id: id) {
                await update(installed)
            }
        default: break
        }
    }

    func removeSelection() async {
        guard pane != .bundles, let id = selectedSkill, let skill = installedSkill(id: id), !skill.isReadOnly else { return }
        await remove(skill)
    }

    func linked(into agent: Agent) -> Int {
        rootSkills.count { $0.agents.contains(agent) }
    }

    var unlinked: [Agent] {
        Agent.present.filter { linked(into: $0) < rootSkills.count }
    }

    func linkEverywhere() async {
        let linked = rootSkills.count { !installer.link(name: $0.name, to: $0.path).isEmpty }
        await rescan()
        toast = linked == 0
            ? Toast(kind: .info, text: "Every skill was already linked")
            : Toast(kind: .success, text: linked == 1 ? "Linked 1 skill into every agent" : "Linked \(linked) skills into every agent")
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        toast = Toast(kind: .info, text: "Copied to the clipboard")
    }

    private func missing(_ id: String) {
        toast = Toast(kind: .failure, text: "\(id) is not in this catalogue. Refresh and try the link again.")
    }

    func open(_ url: URL) {
        guard url.scheme == "skillset" else { return }
        guard !catalog.skills.isEmpty else {
            pendingLink = url
            return
        }
        let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch url.host {
        case "skill":
            guard let skill = catalog.skill(id: id) else { return missing(id) }
            selection[.discover] = skill.name
            query = ""
            pane = .discover
        case "bundle":
            guard catalog.bundle(id: id) != nil else { return missing(id) }
            selection[.bundles] = id
            pane = .bundles
        default: break
        }
    }
}
