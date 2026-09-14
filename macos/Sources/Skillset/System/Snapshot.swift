import AppKit

enum Snapshot {
    @MainActor
    static func run(store: Store) {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["SKILLSET_SNAPSHOT"] else { return }
        if env["SKILLSET_APPEARANCE"] == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
        if let size = env["SKILLSET_SIZE"] {
            let parts = size.split(separator: "x").compactMap { Double($0) }
            if parts.count == 2, let window = NSApp.windows.first {
                window.setContentSize(NSSize(width: parts[0], height: parts[1]))
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            while store.scanning || store.loadingCatalog { try? await Task.sleep(for: .milliseconds(100)) }
            if let step = env["SKILLSET_STEP"].flatMap(Int.init) { store.onboardingStep = step }
            let pane = env["SKILLSET_PANE"].flatMap(Pane.init(rawValue:)) ?? store.pane
            if let select = env["SKILLSET_SELECT"], !select.isEmpty { store.selection[pane] = select }
            store.pane = pane
            if let query = env["SKILLSET_QUERY"] { store.query = query }
            if env["SKILLSET_ACTION"] == "install" { Task { await store.actOnSelection() } }
            if env["SKILLSET_ACTION"] == "remove" { Task { await store.removeSelection() } }
            if env["SKILLSET_ACTION"] == "settings", let app = NSApp.mainMenu?.items.first?.submenu,
               let item = app.items.first(where: { $0.title.hasPrefix("Settings") }) {
                app.performActionForItem(at: app.index(of: item))
            }
            let waits = (env["SKILLSET_WAIT"] ?? "2.5").split(separator: ",").compactMap { Double($0) }
            for (index, wait) in waits.enumerated() {
                try? await Task.sleep(for: .seconds(wait))
                capture(to: waits.count == 1 ? path : path.replacingOccurrences(of: ".png", with: "-\(index + 1).png"))
            }
            NSApp.terminate(nil)
        }
    }

    @MainActor
    static func capture(to path: String) {
        NSApp.activate()
        guard let window = NSApp.orderedWindows.first(where: \.isVisible) ?? NSApp.windows.first else { return }
        guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        do {
            try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardError.write(Data("snapshot: \(error)\n".utf8))
        }
    }
}
