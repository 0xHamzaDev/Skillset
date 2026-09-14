import SwiftUI

struct SkillDetailView: View {
    @Environment(Store.self) private var store
    let id: String
    @State private var document: Result<String, Error>?
    @State private var wholeSummary = false

    private var name: String { store.rowName(for: id) }
    private var installed: InstalledSkill? { store.installedSkill(id: id) }
    private var catalogSkill: CatalogSkill? { store.catalogSkill(id: id) }
    private var state: InstallState { store.state(name) }
    private var source: Source? { catalogSkill?.source ?? installed?.source }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.stack) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    action
                }
                .padding(22)
                .background(Color.card, in: .rect(cornerRadius: 24))
                if case .failed(let message) = state { failure(message) }
                summary
                if let installed { placement(installed) }
                if let source, installed == nil { sourcePanel(source) }
                documentSection
            }
            .padding(Metric.gutter)
            .frame(maxWidth: Metric.detailWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: id) {
            wholeSummary = false
            await loadDocument()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            GlyphTile(symbol: Glyph.symbol(for: catalogSkill?.tags ?? []), size: 54, accent: state.isInstalled ? .secondary : .accentOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(catalogSkill?.title ?? installed?.frontmatterName ?? name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                HStack(spacing: 5) {
                    if let author = catalogSkill?.author { Text(author) }
                    if let source {
                        if catalogSkill != nil { Text("·").foregroundStyle(.quaternary) }
                        Link(source.slug, destination: source.webURL)
                            .foregroundStyle(.secondary)
                    } else if let installed {
                        Text(installed.originTitle)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if state.isInstalled { StatusBadge(state: .installed) }
        }
    }

    @ViewBuilder
    private var action: some View {
        HStack(spacing: 8) {
            switch state {
            case .available, .failed:
                if let skill = catalogSkill, installed?.isReadOnly != true {
                    Button {
                        Task { await store.install(skill) }
                    } label: {
                        Label(state == .available ? "Install" : "Try again", systemImage: state == .available ? "arrow.down.circle" : "arrow.clockwise")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.actionOrange)
                    .keyboardShortcut(.defaultAction)
                }
                if let installed, !installed.isReadOnly { removeButton(installed) }
            case .installing(let stage), .updating(let stage):
                ProgressView().controlSize(.small)
                Text(stage.title).foregroundStyle(.secondary).font(.callout)
            case .removing:
                ProgressView().controlSize(.small)
                Text("Moving to the Trash").foregroundStyle(.secondary).font(.callout)
            case .installed, .updateAvailable:
                if state == .updateAvailable, catalogSkill != nil || installed?.source != nil {
                    Button {
                        Task {
                            if let skill = catalogSkill { await store.install(skill) } else if let installed { await store.update(installed) }
                        }
                    } label: {
                        Label("Update", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.actionOrange)
                    .keyboardShortcut(.defaultAction)
                }
                if let installed, !installed.isReadOnly { removeButton(installed) }
            }
            Spacer(minLength: 0)
            overflow
        }
        .controlSize(.large)
        .animation(Motion.move, value: state)
    }

    @ViewBuilder
    private var overflow: some View {
        if source != nil || installed != nil {
            Menu {
                if let installed {
                    Button("Show in Finder", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([installed.path])
                    }
                    Button("Copy path", systemImage: "doc.on.doc") { store.copy(installed.path.path) }
                }
                if let source {
                    Button("Copy install command", systemImage: "terminal") { store.copy(source.installCommand) }
                    Link(destination: source.webURL) { Label("Open on GitHub", systemImage: "arrow.up.right.square") }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More actions")
            .menuIndicator(.hidden)
            .buttonStyle(.glass)
            .fixedSize()
        }
    }

    private func removeButton(_ installed: InstalledSkill) -> some View {
        Button(role: .destructive) {
            Task { await store.remove(installed) }
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .buttonStyle(.glass)
        .disabled(installed.isReadOnly)
        .help(installed.isReadOnly ? "Managed by a Claude Code plugin" : "Move this skill to the Trash")
    }

    private func failure(_ message: String) -> some View {
        Panel(tint: .red) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summary: some View {
        let whole = catalogSkill?.description ?? installed?.description ?? "This skill has no description."
        let condensed = whole.condensed
        return VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "What it does")
            Text(wholeSummary ? whole : condensed)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if condensed != whole {
                Button(wholeSummary ? "Show less" : "Show more") {
                    withAnimation(Motion.move) { wholeSummary.toggle() }
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.accentOrange)
                .pointerStyle(.link)
            }
            if let tags = catalogSkill?.tags, !tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 5) { ForEach(tags, id: \.self) { Chip(text: $0) } }
                }
                .scrollIndicators(.hidden)
            }
            if !bundles.isEmpty {
                HStack(spacing: 5) {
                    Text("In bundles").font(.caption).foregroundStyle(.tertiary)
                    ForEach(bundles) { bundle in
                        Button(bundle.name.current) {
                            store.selection[.bundles] = bundle.id
                            store.pane = .bundles
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentOrange)
                    }
                }
            }
        }
    }

    private var bundles: [SkillBundle] {
        guard let id = catalogSkill?.id else { return [] }
        return store.catalog.bundles.filter { $0.skills.contains(id) }
    }

    private func placement(_ installed: InstalledSkill) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    FieldLabel(text: "Available to")
                    Spacer()
                    if installed.isReadOnly { Chip(text: "read-only") }
                }
                Text(installed.agents.map(\.title).formatted(.list(type: .and)))
                    .font(.callout)
                Text(installed.path.path.replacingOccurrences(of: Paths.home.path, with: "~"))
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private func sourcePanel(_ source: Source) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 7) {
                FieldLabel(text: "Source")
                Link(destination: source.webURL) {
                    HStack(spacing: 4) {
                        Text(source.slug).font(.callout.weight(.medium))
                        Image(systemName: "arrow.up.right").font(.caption2.weight(.semibold))
                    }
                }
                HStack(spacing: 8) {
                    Text(source.installCommand)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button {
                        store.copy(source.installCommand)
                    } label: {
                        Image(systemName: "doc.on.doc").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Copy the command")
                    .help("Copy the command")
                }
            }
        }
    }

    @ViewBuilder
    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Button {
                withAnimation(Motion.move) { store.showInstructions.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(store.showInstructions ? 90 : 0))
                    Text("Full instructions").font(.callout.weight(.semibold))
                    Text("SKILL.md").font(.subheadline.monospaced()).foregroundStyle(.tertiary)
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)

            if store.showInstructions {
                switch document {
                case nil:
                    HStack(spacing: 7) {
                        ProgressView().controlSize(.small)
                        Text("Loading").font(.callout).foregroundStyle(.secondary)
                    }
                case .failure(let error):
                    Label(error.localizedDescription, systemImage: "doc.questionmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                case .success(let text):
                    MarkdownView(text: Frontmatter.parse(text).body)
                        .transition(.opacity)
                }
            }
        }
    }

    private func loadDocument() async {
        document = nil
        if let installed, let text = try? String(contentsOf: installed.path.appending(path: "SKILL.md"), encoding: .utf8) {
            document = .success(text)
            return
        }
        guard let source else {
            document = .failure(GitHub.Failure.notFound("SKILL.md"))
            return
        }
        do { document = .success(try await store.document(at: source.rawSkillURL)) } catch { document = .failure(error) }
    }
}

extension String {
    var condensed: String {
        var first = ""
        enumerateSubstrings(in: startIndex..., options: .bySentences) { _, range, _, stop in
            first = self[range].trimmingCharacters(in: .whitespacesAndNewlines)
            stop = true
        }
        return count - first.count > 120 ? first : self
    }
}
