import SwiftUI

struct BundleProgress {
    let total: Int
    let installed: Int
    let failed: [String]
    let busy: Bool

    var remaining: Int { total - installed }
    var complete: Bool { installed == total && total > 0 }
    var fraction: Double { total == 0 ? 0 : Double(installed) / Double(total) }
}

extension Store {
    func progress(for bundle: SkillBundle) -> BundleProgress {
        let skills = catalog.skills(in: bundle)
        return BundleProgress(
            total: skills.count,
            installed: skills.filter { state($0.name).isInstalled }.count,
            failed: skills.filter { if case .failed = state($0.name) { true } else { false } }.map(\.name),
            busy: skills.contains { state($0.name).isBusy }
        )
    }

    func retryFailed(in bundle: SkillBundle) async {
        let skills = catalog.skills(in: bundle).filter { if case .failed = state($0.name) { true } else { false } }
        for skill in skills { transient[skill.name] = nil }
        await install(bundle: bundle)
    }
}

struct BundleListView: View {
    @Environment(Store.self) private var store
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            SearchField(text: $store.query, placeholder: "Search bundles", focused: $searchFocused) {
                listFocused = true
                store.keepSelection(.bundles, among: bundles.map(\.id))
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if bundles.isEmpty {
                Group {
                    if !store.query.isEmpty {
                        ContentUnavailableView.search(text: store.query)
                    } else if store.loadingCatalog {
                        ProgressView("Loading catalogue")
                    } else {
                        ContentUnavailableView("No bundles", systemImage: "shippingbox", description: Text("The catalogue has no bundles yet."))
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $store.selectedBundle) {
                    ForEach(bundles) { bundle in
                        BundleRowView(bundle: bundle, progress: store.progress(for: bundle))
                            .tag(bundle.id)
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
        .safeAreaInset(edge: .bottom) {
            HintBar(hints: hints)
        }
        .task(id: store.pane) {
            store.listFocused = listFocused
            store.keepSelection(.bundles, among: bundles.map(\.id))
        }
        .onChange(of: bundles.first?.id) { store.keepSelection(.bundles, among: bundles.map(\.id)) }
        .onChange(of: store.query) { store.keepSelection(.bundles, among: bundles.map(\.id), startOver: true) }
        .onChange(of: listFocused) { store.listFocused = listFocused }
        .onChange(of: store.focusSearch) { searchFocused = true }
        .onAppear { searchFocused = true }
    }

    private var hints: [(String, [String])] {
        guard let bundle = store.selectedBundle.flatMap(store.catalog.bundle(id:)) else { return [("Search", ["⌘", "F"])] }
        let progress = store.progress(for: bundle)
        if !progress.failed.isEmpty { return [("Retry failed", ["↵"]), ("Search", ["⌘", "F"])] }
        return progress.complete ? [("Search", ["⌘", "F"])] : [("Install bundle", ["↵"]), ("Search", ["⌘", "F"])]
    }

    private var bundles: [SkillBundle] {
        let q = store.query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.catalog.bundles }
        return store.catalog.bundles.filter { bundle in
            bundle.name.current.lowercased().contains(q) || bundle.tagline.current.lowercased().contains(q)
                || bundle.tags.contains { $0.contains(q) } || bundle.skills.contains { $0.contains(q) }
        }
    }
}

struct BundleRowView: View {
    let bundle: SkillBundle
    let progress: BundleProgress

    var body: some View {
        HStack(spacing: 10) {
            GlyphTile(symbol: bundle.symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(bundle.name.current).font(.headline)
                Text(bundle.tagline.current)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                BundleMeter(bundle: bundle, progress: progress)
                    .padding(.top, 2)
            }
            Spacer(minLength: 6)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

struct BundleMeter: View {
    let bundle: SkillBundle
    let progress: BundleProgress

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<max(progress.total, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < progress.installed ? Color.accentOrange : Color.secondary.opacity(0.22))
                        .frame(width: 12, height: 3)
                }
            }
            Text(progress.complete ? "Complete" : "\(progress.installed)/\(progress.total)")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(progress.complete ? AnyShapeStyle(Color.accentOrange) : AnyShapeStyle(.tertiary))
        }
        .animation(Motion.move, value: progress.installed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progress.installed) of \(progress.total) skills installed")
    }
}

struct BundleDetailView: View {
    @Environment(Store.self) private var store
    let bundle: SkillBundle

    private var skills: [CatalogSkill] { store.catalog.skills(in: bundle) }
    private var progress: BundleProgress { store.progress(for: bundle) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metric.stack) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    action
                }
                .padding(22)
                .background(Color.card, in: .rect(cornerRadius: 24))
                Panel {
                    Text(bundle.why.current)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                contents
            }
            .padding(Metric.gutter)
            .frame(maxWidth: Metric.detailWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            GlyphTile(symbol: bundle.symbol, size: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(bundle.name.current).font(.system(size: 26, weight: .bold, design: .rounded))
                Text(bundle.tagline.current)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var action: some View {
        HStack(spacing: 10) {
            if progress.busy {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .tint(Color.accentOrange)
                    .frame(maxWidth: 200)
                Text("Installing \(progress.installed) of \(progress.total)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if !progress.failed.isEmpty {
                Button {
                    Task { await store.retryFailed(in: bundle) }
                } label: {
                    Label("Retry \(progress.failed.count) failed", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glassProminent)
                .tint(.actionOrange)
                .keyboardShortcut(.defaultAction)
                Text("\(progress.installed) of \(progress.total) installed")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if progress.complete {
                Label("All \(progress.total) skills installed", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.accentOrange)
            } else {
                Button {
                    Task { await store.install(bundle: bundle) }
                } label: {
                    Label(progress.installed == 0 ? "Install bundle" : "Install remaining \(progress.remaining)", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.glassProminent)
                .tint(.actionOrange)
                .keyboardShortcut(.defaultAction)
                if progress.installed > 0 {
                    Text("\(progress.installed) already installed")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .controlSize(.large)
        .animation(Motion.move, value: progress.installed)
        .animation(Motion.move, value: progress.busy)
    }

    private var contents: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FieldLabel(text: "Contains")
                Spacer()
                Text("\(progress.total) skills")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Panel(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(skills) { skill in
                        BundleSkillRow(skill: skill, state: store.state(skill.name))
                        if skill.id != skills.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
            if skills.count != bundle.skills.count {
                Text("\(bundle.skills.count - skills.count) skills in this bundle are missing from the catalogue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BundleSkillRow: View {
    @Environment(Store.self) private var store
    let skill: CatalogSkill
    let state: InstallState
    @State private var hovering = false

    var body: some View {
        Button {
            store.selection[.discover] = skill.name
            store.query = ""
            store.pane = .discover
        } label: {
            HStack(spacing: 10) {
                GlyphTile(symbol: Glyph.symbol(for: skill.tags), size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.title).font(.callout.weight(.medium))
                    if case .failed(let message) = state {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(skill.source.slug).font(.subheadline.monospaced()).foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 6)
                StatusBadge(state: state)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hovering ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hovering ? AnyShapeStyle(.quaternary.opacity(0.45)) : AnyShapeStyle(.clear))
            .contentShape(.rect)
            .onHover { hovering = $0 }
            .animation(Motion.tap, value: hovering)
        }
        .buttonStyle(.plain)
        .help("Open \(skill.title)")
    }
}
