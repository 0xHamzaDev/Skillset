import Foundation

struct Frontmatter: Sendable {
    var fields: [String: String] = [:]
    var body: String = ""

    var name: String? { fields["name"] }
    var description: String { fields["description"] ?? "" }

    static func parse(_ text: String) -> Frontmatter {
        var result = Frontmatter(body: text)
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else { return result }
        result.body = lines[(end + 1)...].joined(separator: "\n")
        var key: String?
        var block: [String]?
        func flush() {
            if let key, let block {
                result.fields[key] = block.filter { !$0.isEmpty }.joined(separator: " ")
            }
            block = nil
        }
        for line in lines[1..<end] {
            if block != nil, line.hasPrefix(" ") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                block?.append(line.trimmingCharacters(in: .whitespaces))
                continue
            }
            flush()
            guard let colon = line.firstIndex(of: ":"), !line.hasPrefix(" ") else { continue }
            key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if ["", ">", ">-", "|", "|-"].contains(value) {
                block = []
            } else {
                result.fields[key!] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        flush()
        return result
    }

    static func load(_ directory: URL) -> Frontmatter? {
        guard let handle = try? FileHandle(forReadingFrom: directory.appending(path: "SKILL.md")),
              let data = try? handle.read(upToCount: 16_384) else { return nil }
        return parse(String(decoding: data, as: UTF8.self))
    }
}
