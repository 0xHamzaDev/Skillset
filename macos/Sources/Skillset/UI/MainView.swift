import SwiftUI

struct RootView: View {
    @Environment(Store.self) private var store
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        ZStack {
            if didOnboard {
                MainView().transition(.opacity)
            } else {
                OnboardingView { withAnimation(Motion.enter) { didOnboard = true } }
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .frame(
            minWidth: didOnboard ? 880 : Metric.onboarding.width,
            maxWidth: didOnboard ? .infinity : Metric.onboarding.width,
            minHeight: didOnboard ? 600 : Metric.onboarding.height,
            maxHeight: didOnboard ? .infinity : Metric.onboarding.height
        )
    }
}

struct MainView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(Metric.sidebar)
        } content: {
            Group {
                switch store.pane {
                case .bundles: BundleListView()
                default: SkillListView(pane: store.pane)
                }
            }
            .transition(.opacity)
            .animation(Motion.tap, value: store.pane)
            .navigationSplitViewColumnWidth(min: Metric.listMin, ideal: Metric.listIdeal, max: 460)
            .navigationTitle(store.pane.title)
            .navigationSubtitle(store.subtitle)
            .background(Color.canvas.opacity(0.55))
        } detail: {
            DetailColumn()
                .background(Color.canvas)
                .navigationSplitViewColumnWidth(min: 400, ideal: 560)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(store.busy)
                        .help("Rescan this Mac, reload the catalogue, check for updates")
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(3.4))
                        if store.toast == toast { store.toast = nil }
                    }
            }
        }
        .animation(Motion.move, value: store.toast)
        .tint(.accentOrange)
    }
}

struct DetailColumn: View {
    @Environment(Store.self) private var store

    var body: some View {
        if store.pane == .bundles {
            if let bundle = store.selectedBundle.flatMap(store.catalog.bundle(id:)) {
                BundleDetailView(bundle: bundle)
                    .id(bundle.id)
            } else {
                Placeholder(title: "Pick a bundle", message: "A bundle installs a curated set of skills in one action.")
            }
        } else if let id = store.selectedSkill {
            SkillDetailView(id: id)
                .id(id)
        } else if store.pane == .discover {
            Placeholder(title: "Pick a skill", message: "Search, then press Return to install.")
        } else {
            Placeholder(title: "Pick a skill", message: "See what it does, where it lives, and which agents can reach it.")
        }
    }
}

struct Placeholder: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 18) {
            BrandMark(size: 72)
                .padding(28)
                .glassEffect(.regular, in: .rect(cornerRadius: 34))
            Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SidebarView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.pane) {
            ForEach(Pane.allCases) { pane in
                Label(pane.title, systemImage: pane.symbol)
                    .badge(badge(for: pane) ?? 0)
                    .tag(pane)
                    .padding(.vertical, 5)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 10) {
                    BrandMark(size: 29)
                    Text("Skillset").font(.system(size: 20, weight: .bold, design: .rounded))
                }
                Text("YOUR WORKSPACE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            SidebarFooter()
        }
    }

    private func badge(for pane: Pane) -> Int? {
        switch pane {
        case .installed: store.installed.isEmpty ? nil : store.installed.count
        case .updates: store.updatable.isEmpty ? nil : store.updatable.count
        default: nil
        }
    }
}

struct SidebarFooter: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Made for your agents", systemImage: "sparkles")
                    .font(.callout.weight(.medium))
                Text("One home. Every skill.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: 14))
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
            HStack(spacing: 6) {
                if store.busy {
                    ProgressView().controlSize(.mini)
                    Text(store.activity)
                } else if store.lastUpdateError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentOrange)
                    Text("Update check failed")
                } else {
                    Circle()
                        .fill(store.catalogOrigin == .remote ? Color.green : Color.secondary)
                        .frame(width: 5, height: 5)
                    Text(store.catalogOrigin.label)
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .animation(Motion.move, value: store.busy)
    }
}

extension CatalogOrigin {
    var label: LocalizedStringKey {
        switch self {
        case .remote: "Catalogue up to date"
        case .cached: "Offline copy"
        case .bundled: "Built-in copy"
        case .none: "No catalogue"
        }
    }
}
