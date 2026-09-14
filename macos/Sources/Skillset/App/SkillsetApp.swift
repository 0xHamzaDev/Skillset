import SwiftUI

@main
struct SkillsetApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup("Skillset") {
            RootView()
                .environment(store)
                .task { await store.bootstrap() }
                .onAppear { Snapshot.run(store: store) }
                .onOpenURL { store.open($0) }
        }
        .defaultSize(width: 1120, height: 720)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { AppCommands(store: store) }

        Settings {
            SettingsView().environment(store)
        }
    }
}

struct AppCommands: Commands {
    let store: Store

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandMenu("Skill") {
            Button("Install or Update") { Task { await store.actOnSelection() } }
                .keyboardShortcut("i")
            Button("Remove") { Task { await store.removeSelection() } }
                .keyboardShortcut(.delete)
                .disabled(!store.listFocused)
            Divider()
            Button("Refresh") { Task { await store.refresh() } }
                .keyboardShortcut("r")
            Divider()
            Button("Reveal Skills Folder in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Paths.skillsRoot]) }
        }
        CommandGroup(after: .toolbar) {
            Button("Search", systemImage: "magnifyingglass") { store.focusSearch += 1 }
                .keyboardShortcut("f")
            Divider()
            ForEach(Array(Pane.allCases.enumerated()), id: \.element) { index, pane in
                Button(pane.title, systemImage: pane.symbol) { store.pane = pane }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
            }
        }
    }
}
