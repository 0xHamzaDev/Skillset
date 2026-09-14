import Foundation

final class Output: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data.suffix(4096), as: UTF8.self)
    }
}

enum Shell {
    struct Failure: LocalizedError {
        let command: String
        let status: Int32
        let output: String
        var errorDescription: String? { "\(command) exited with \(status): \(output.trimmingCharacters(in: .whitespacesAndNewlines))" }
    }

    static func run(_ executable: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        let collected = Output()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                collected.append(chunk)
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { p in
                pipe.fileHandleForReading.readabilityHandler = nil
                if p.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Failure(command: executable, status: p.terminationStatus, output: collected.text))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
