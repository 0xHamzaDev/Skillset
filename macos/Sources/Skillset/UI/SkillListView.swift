import SwiftUI

struct SkillRow: Identifiable, Hashable {
    let id: String
    let name: String
    let title: String
    let subtitle: String
    let description: String
    let symbol: String
    let tags: [String]
}

struct SkillListView: View {
    @Environment(Store.self) private var store
    let pane: Pane
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool

    var body: some View {
        @Bindable var store = store
        let rows = rows
        let groups = groups(of: rows)
        let suggestions = pane == .discover && store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? store.recommendations : []
        VStack(spacing: 0) {
            SearchField(text: $store.query, placeholder: placeholder, focused: $searchFocused) {
                listFocused = true
                syncSelection()
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if !suggestions.isEmpty {
                recommendations(suggestions)
            }

            if pane == .updates, !store.updatable.isEmpty {
                UpdateAllBar()
            }

            if rows.isEmpty {
                emptyState.frame(maxHeight: .infinity)
            } else {
                List(selection: $store.selectedSkill) {
                    if groups.count == 1, groups[0].name.isEmpty {
                        rowViews(groups[0].rows)
                    } else {
                        ForEach(groups, id: \.name) { group in
                            Section { rowViews(group.rows, hideSubtitle: pane != .installed) } header: { FieldLabel(text: "\(group.name)") }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .focused($listFocused)
                .onKeyPress(.return) {
                    Task { await store.actOnSelection() }
                    return .handled
                }
            }
        }
        .safeAreaInset(edge: .bottom) { HintBar(hints: hints) }
        .task(id: pane) {
            store.listFocused = listFocused
            syncSelection()
        }
        .onChange(of: store.installed.count) { syncSelection() }
        .onChange(of: store.catalog.skills.count) { syncSelection() }
        .onChange(of: store.query) { syncSelection(startOver: true) }
        .onChange(of: listFocused) { store.listFocused = listFocused }
        .onChange(of: store.focusSearch) { searchFocused = true }
        .onChange(of: pane) {
            store.query = ""
            store.listFocused = false
        }
        .onAppear { searchFocused = true }
    }

    private func recommendations(_ suggestions: [SkillRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Color.accentOrange)
                Text(suggestions.contains(where: \.isPersonalized) ? "Made for your setup" : "A good place to start")
                    .font(.callout.weight(.semibold))
            }
            ForEach(suggestions) { recommendation in
                Button {
                    store.selectedSkill = recommendation.skill.name
                } label: {
                    HStack(alignment: .top, spacing: 9) {
                        GlyphTile(symbol: Glyph.symbol(for: recommendation.skill.tags), size: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(recommendation.skill.title).font(.callout.weight(.semibold))
                            Text(recommendation.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.card, in: .rect(cornerRadius: 12))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.accentOrange.opacity(0.06), in: .rect(cornerRadius: 18))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func authorGroups(_ rows: [SkillRow]) -> [(name: String, rows: [SkillRow])] {
        var order: [String] = []
        var grouped: [String: [SkillRow]] = [:]
        for row in rows {
            if grouped[row.subtitle] == nil { order.append(row.subtitle) }
            grouped[row.subtitle, default: []].append(row)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    private func rowViews(_ rows: [SkillRow], hideSubtitle: Bool = false) -> some View {
        ForEach(rows) { row in
            SkillRowView(row: row, state: store.state(row.name), quiet: pane == .installed, hideSubtitle: hideSubtitle)
                .tag(row.id)
                .contextMenu { menu(for: row) }
        }
    }

    @ViewBuilder
    private func menu(for row: SkillRow) -> some View {
        let state = store.state(row.name)
        let installed = store.installedSkill(id: row.id)
        if let skill = store.catalogSkill(id: row.id), installed?.isReadOnly != true {
            if !state.isInstalled {
                Button("Install", systemImage: "arrow.down.circle") { Task { await store.install(skill) } }
            } else if state == .updateAvailable {
                Button("Update", systemImage: "arrow.up.circle") { Task { await store.install(skill) } }
            }
            Button("Copy install command", systemImage: "terminal") { store.copy(skill.source.installCommand) }
            Link(destination: skill.source.webURL) { Label("Open on GitHub", systemImage: "arrow.up.right.square") }
        } else if let installed, let source = installed.source, !installed.isReadOnly {
            if state == .updateAvailable {
                Button("Update", systemImage: "arrow.up.circle") { Task { await store.update(installed) } }
            }
            Button("Copy install command", systemImage: "terminal") { store.copy(source.installCommand) }
            Link(destination: source.webURL) { Label("Open on GitHub", systemImage: "arrow.up.right.square") }
        }
        if let installed {
            Divider()
            Button("Show in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([installed.path]) }
            if !installed.isReadOnly {
                Button("Remove", systemImage: "trash", role: .destructive) { Task { await store.remove(installed) } }
            }
        }
    }

    private var hints: [(String, [String])] {
        guard let id = store.selectedSkill else { return [("Search", ["⌘", "F"])] }
        let installed = store.installedSkill(id: id)
        guard installed?.isReadOnly != true else { return [("Search", ["⌘", "F"])] }
        let name = store.rowName(for: id)
        var hints: [(String, [String])] = []
        switch store.state(name) {
        case .available, .failed:
            if store.catalogByName[name] != nil { hints.append(("Install", ["↵"])) }
        case .updateAvailable:
            hints.append(("Update", ["↵"]))
        default:
            break
        }
        if installed != nil { hints.append(("Remove", ["⌘", "⌫"])) }
        hints.append(("Search", ["⌘", "F"]))
        return hints
    }

    private func syncSelection(startOver: Bool = false) {
        store.keepSelection(pane, among: groups(of: rows).flatMap { $0.rows.map(\.id) }, startOver: startOver)
    }

    private func groups(of rows: [SkillRow]) -> [(name: String, rows: [SkillRow])] {
        if pane == .installed, store.query.isEmpty { return originGroups(rows) }
        if pane == .discover, store.query.trimmingCharacters(in: .whitespaces).isEmpty { return authorGroups(rows) }
        return [(name: "", rows: rows)]
    }

    private func originGroups(_ rows: [SkillRow]) -> [(name: String, rows: [SkillRow])] {
        let grouped = Dictionary(grouping: rows) { row in
            switch store.installedSkill(id: row.id)?.origin {
            case .managed: "Managed by Skillset"
            case .plugin: "From plugins"
            default: "Installed by hand"
            }
        }
        return ["Managed by Skillset", "Installed by hand", "From plugins"]
            .compactMap { name in grouped[name].map { (name, $0) } }
    }

    private var placeholder: LocalizedStringKey {
        switch pane {
        case .installed: "Search installed"
        case .updates: "Search updates"
        default: "Search skills"
        }
    }

    private var rows: [SkillRow] {
        let all: [SkillRow] = switch pane {
        case .installed: store.installed.map(row(for:))
        case .updates: store.updatable.map(row(for:))
        default: store.catalog.skills.map { skill in
            SkillRow(id: skill.name, name: skill.name, title: skill.title, subtitle: skill.author, description: skill.description, symbol: Glyph.symbol(for: skill.tags), tags: skill.tags)
        }
        }
        return Search.rank(all, query: store.query)
    }

    private func row(for skill: InstalledSkill) -> SkillRow {
        let catalogSkill = store.catalogSkill(for: skill)
        return SkillRow(
            id: skill.path.path,
            name: skill.name,
            title: catalogSkill?.title ?? skill.frontmatterName,
            subtitle: skill.originTitle,
            description: skill.description,
            symbol: Glyph.symbol(for: catalogSkill?.tags ?? []),
            tags: catalogSkill?.tags ?? []
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.query.isEmpty {
            ContentUnavailableView.search(text: store.query)
        } else {
            switch pane {
            case .installed:
                if store.scanning {
                    ProgressView("Scanning this Mac")
                } else {
                    ContentUnavailableView {
                        Label("Nothing installed yet", systemImage: "tray")
                    } description: {
                        Text("Skills land in ~/.agents/skills and are linked into every agent on this Mac.")
                    } actions: {
                        Button("Browse skills") { store.pane = .discover }
                    }
                }
            case .updates:
                if let error = store.lastUpdateError {
                    ContentUnavailableView {
                        Label("Could not check for updates", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try again") { Task { await store.checkUpdates() } }
                            .disabled(store.checkingUpdates)
                    }
                } else {
                    ContentUnavailableView {
                        Label("Everything is current", systemImage: "checkmark.seal")
                    } description: {
                        if let date = store.lastUpdateCheck {
                            Text("Checked \(date, format: .relative(presentation: .named)).")
                        } else {
                            Text("Skillset checks GitHub for newer versions on launch.")
                        }
                    } actions: {
                        Button("Check now") { Task { await store.checkUpdates() } }
                            .disabled(store.checkingUpdates)
                    }
                }
            default:
                if store.loadingCatalog {
                    ProgressView("Loading catalogue")
                } else {
                    ContentUnavailableView {
                        Label("Catalogue unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Could not reach the catalogue and there is no cached copy.")
                    } actions: {
                        Button("Retry") { Task { await store.loadCatalog() } }
                    }
                }
            }
        }
    }
}

struct UpdateAllBar: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            Text(store.updatable.count == 1 ? "1 skill has a newer version" : "\(store.updatable.count) skills have a newer version")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Button {
                Task { await store.updateAll() }
            } label: {
                Text("Update all")
            }
            .buttonStyle(.glassProminent)
            .tint(.actionOrange)
            .controlSize(.small)
            .disabled(store.updatingAll)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

struct SkillRowView: View {
    let row: SkillRow
    let state: InstallState
    var quiet = false
    var hideSubtitle = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            GlyphTile(symbol: row.symbol, size: 34, accent: quiet ? .secondary : .accentOrange)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title).font(.headline).lineLimit(1)
                if !hideSubtitle {
                    Text(row.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(row.description.isEmpty ? "No description" : row.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            if !(quiet && state == .installed) {
                StatusBadge(state: state, compact: true).padding(.top, 1)
            }
        }
        .padding(.vertical, 9)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: LocalizedStringKey
    var focused: FocusState<Bool>.Binding
    var onDown: () -> Void = {}

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.callout.weight(.medium))
                .foregroundStyle(focused.wrappedValue ? Color.accentOrange : .secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused(focused)
                .onKeyPress(.downArrow) { onDown(); return .handled }
                .onKeyPress(.escape) {
                    guard !text.isEmpty else { return .ignored }
                    text = ""
                    return .handled
                }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear the search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .rect(cornerRadius: Metric.radiusControl))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.radiusControl)
                .strokeBorder(focused.wrappedValue ? Color.accentOrange.opacity(0.5) : .clear, lineWidth: Metric.hairline)
        }
        .animation(Motion.tap, value: focused.wrappedValue)
        .animation(Motion.tap, value: text.isEmpty)
    }
}

struct HintBar: View {
    let hints: [(String, [String])]

    var body: some View {
        HStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                row(hints[...])
                row(hints.dropLast())
                row(hints.dropLast(2))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func row(_ items: ArraySlice<(String, [String])>) -> some View {
        HStack(spacing: 12) {
            ForEach(items, id: \.0) { hint in
                HStack(spacing: 5) {
                    Text(hint.0).font(.subheadline).foregroundStyle(.secondary).fixedSize()
                    KeyHint(keys: hint.1)
                }
            }
        }
    }
}

enum Search {
    static func rank(_ rows: [SkillRow], query: String) -> [SkillRow] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.compactMap { row -> (SkillRow, Int)? in
            let title = row.title.lowercased()
            let name = row.name.lowercased()
            if title.hasPrefix(q) || name.hasPrefix(q) { return (row, 0) }
            if title.contains(q) || name.contains(q) { return (row, 1) }
            if row.tags.contains(where: { $0.contains(q) }) { return (row, 2) }
            if row.subtitle.lowercased().contains(q) { return (row, 3) }
            if row.description.lowercased().contains(q) { return (row, 4) }
            return nil
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }
}

extension InstalledSkill {
    var originTitle: String {
        switch origin {
        case .managed(let source): source.slug
        case .plugin(let plugin): plugin
        case .manual: agents.contains(.universal) ? "local" : agents.map(\.title).formatted(.list(type: .and, width: .narrow))
        }
    }
}
