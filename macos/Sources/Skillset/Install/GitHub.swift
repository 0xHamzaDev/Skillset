import Foundation

enum GitHub {
    enum Failure: LocalizedError {
        case rateLimited(Date?)
        case status(Int, URL)
        case notFound(String)

        var errorDescription: String? {
            switch self {
            case .rateLimited(let reset):
                if let reset {
                    "GitHub is rate limiting anonymous requests. Update checks resume \(reset.formatted(.relative(presentation: .named)))."
                } else {
                    "GitHub is rate limiting anonymous requests. Try again in a few minutes."
                }
            case .status(let code, let url): "GitHub returned \(code) for \(url.lastPathComponent)."
            case .notFound(let path): "\(path) was not found in the repository."
            }
        }
    }

    static var session: URLSession { .shared }

    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("skillset-mac", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }

    static func download(_ url: URL, to destination: URL) async throws {
        let (temp, response) = try await session.download(for: request(url))
        try check(response, url)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    static func text(_ url: URL) async throws -> String {
        let (data, response) = try await session.data(for: request(url))
        try check(response, url)
        return String(decoding: data, as: UTF8.self)
    }

    static func folderHashes(_ contentsAPI: URL) async throws -> [String: String] {
        struct Entry: Decodable { let name: String; let sha: String; let type: String }
        let (data, response) = try await session.data(for: request(contentsAPI))
        try check(response, contentsAPI)
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        return Dictionary(entries.filter { $0.type == "dir" }.map { ($0.name, $0.sha) }, uniquingKeysWith: { a, _ in a })
    }

    static func folderHash(_ source: Source) async throws -> String {
        guard let sha = try await folderHashes(source.contentsAPI)[source.folder] else { throw Failure.notFound(source.path) }
        return sha
    }

    private static func check(_ response: URLResponse, _ url: URL) throws {
        guard let http = response as? HTTPURLResponse else { return }
        let exhausted = http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0"
        if http.statusCode == 429 || (http.statusCode == 403 && exhausted) {
            let reset = (http.value(forHTTPHeaderField: "x-ratelimit-reset")).flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }
            throw Failure.rateLimited(reset)
        }
        guard (200..<300).contains(http.statusCode) else { throw Failure.status(http.statusCode, url) }
    }
}
