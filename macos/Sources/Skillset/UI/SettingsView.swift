import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Agents", systemImage: "square.stack.3d.up") { AgentSettings() }
        }
        .frame(width: 480)
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .tint(.accentOrange)
    }
}

struct GeneralSettings: View {
    @Environment(Store.self) private var store
    @AppStorage("catalogURL") private var catalogURL = ""
    @AppStorage("checkOnLaunch") private var checkOnLaunch = true
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            Section {
                TextField("Address", text: $catalogURL, prompt: Text(CatalogClient.defaultURL.absoluteString))
                    .onSubmit { Task { await store.loadCatalog() } }
                Toggle("Check for updates on launch", isOn: $checkOnLaunch)
            } header: {
                Text("Catalogue")
            } footer: {
                if let error = store.lastCatalogError {
                    Text("\(error) Skillset kept the copy it already had.")
                }
            }

            Section {
                LabeledContent("Skills folder") {
                    HStack(spacing: 8) {
                        Text(Paths.skillsRoot.path.replacingOccurrences(of: Paths.home.path, with: "~"))
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                        Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([Paths.skillsRoot]) }
                            .controlSize(.small)
                    }
                }
            } footer: {
                Text("One copy lives here. Every agent gets a link to it.")
            }

            Section("First run") {
                LabeledContent("Welcome screens") {
                    Button("Show again") {
                        store.onboardingStep = 0
                        UserDefaults.standard.set(false, forKey: "didOnboard")
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 464)
    }
}

struct AgentSettings: View {
    @Environment(Store.self) private var store

    private var present: [Agent] { Agent.allCases.filter { $0 != .universal && $0.isPresent } }
    private var missing: [Agent] { Agent.allCases.filter { $0 != .universal && !$0.isPresent } }
    private var total: Int { store.rootSkills.count }

    var body: some View {
        Form {
            Section {
                ForEach(present) { agent in
                    let linked = store.linked(into: agent)
                    LabeledContent(agent.title) {
                        Text(linked == total ? "all \(total)" : "\(linked) of \(total)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                if !missing.isEmpty {
                    LabeledContent("Not installed") {
                        Text(missing.map(\.title).formatted(.list(type: .and, width: .narrow)))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if !store.unlinked.isEmpty {
                    Button("Link all skills into every agent") { Task { await store.linkEverywhere() } }
                }
            } header: {
                Text("Agents")
            } footer: {
                if store.unlinked.isEmpty {
                    Text("Every skill is reachable from every agent found here.")
                } else {
                    Text("A skill installed before an agent existed is not linked into it. Linking is safe and leaves your own links alone.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 416)
    }
}
