import Foundation

enum CatalogOrigin: Sendable { case remote, cached, bundled, none }

struct CatalogClient: Sendable {
    enum Failure: LocalizedError {
        case http(Int)
        case malformed

        var errorDescription: String? {
            switch self {
            case .http(let code): "The catalogue address answered with HTTP \(code)."
            case .malformed: "The catalogue address did not return a catalogue."
            }
        }
    }

    static let defaultURL = URL(string: "https://skillset.app/catalog.json")!

    var remote: URL = {
        let stored = UserDefaults.standard.string(forKey: "catalogURL") ?? ""
        return URL(string: stored) ?? defaultURL
    }()

    func load() async -> (Catalog, CatalogOrigin, String?) {
        if let override = ProcessInfo.processInfo.environment["SKILLSET_CATALOG"],
           let catalog = decode(URL(fileURLWithPath: override)) { return (catalog, .bundled, nil) }
        var failure: String?
        do {
            return (try await fetchRemote(), .remote, nil)
        } catch {
            failure = error.localizedDescription
        }
        if let catalog = decode(Paths.catalogCache) { return (catalog, .cached, failure) }
        if let catalog = bundled() { return (catalog, .bundled, failure) }
        return (.empty, .none, failure)
    }

    private func fetchRemote() async throws -> Catalog {
        var request = URLRequest(url: remote, timeoutInterval: 8)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let code = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) {
            throw Failure.http(code)
        }
        guard let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else { throw Failure.malformed }
        try? FileManager.default.createDirectory(at: Paths.support, withIntermediateDirectories: true)
        try? data.write(to: Paths.catalogCache, options: .atomic)
        return catalog
    }

    private func bundled() -> Catalog? {
        Bundle.main.url(forResource: "catalog", withExtension: "json").flatMap(decode)
    }

    private func decode(_ url: URL) -> Catalog? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Catalog.self, from: data)
    }
}
