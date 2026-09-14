import SwiftUI

struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Block.parse(text).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let level, let line):
            inline(line)
                .font(level == 1 ? .title2.weight(.bold) : level == 2 ? .title3.weight(.semibold) : .headline)
                .padding(.top, 6)
        case .paragraph(let line):
            inline(line)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.tertiary)
                        inline(item)
                    }
                }
            }
        case .code(let code):
            Text(code)
                .font(.callout.monospaced())
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: Metric.radiusControl))
        case .table(let rows):
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            inline(cell)
                                .font(index == 0 ? .callout.weight(.semibold) : .callout)
                                .foregroundStyle(index == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if index == 0 { Divider().gridCellUnsizedAxes(.horizontal) }
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: Metric.radiusControl))
        case .quote(let line):
            inline(line)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) { Rectangle().fill(.quaternary).frame(width: 2) }
        }
    }

    private func inline(_ line: String) -> Text {
        if let attributed = try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            Text(line)
        }
    }

    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case bullets([String])
        case code(String)
        case quote(String)
        case table([[String]])

        static func parse(_ text: String) -> [Block] {
            var blocks: [Block] = []
            var paragraph: [String] = []
            var bullets: [String] = []
            var table: [[String]] = []
            var code: [String]?
            func flush() {
                if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
                if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
                if !table.isEmpty { blocks.append(.table(table)); table = [] }
            }
            for raw in text.components(separatedBy: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("```") {
                    if let open = code { blocks.append(.code(open.joined(separator: "\n"))); code = nil } else { flush(); code = [] }
                    continue
                }
                if code != nil { code?.append(raw); continue }
                if line.isEmpty { flush(); continue }

                if line.hasPrefix("#") {
                    flush()
                    let level = line.prefix { $0 == "#" }.count
                    blocks.append(.heading(min(level, 3), line.dropFirst(level).trimmingCharacters(in: .whitespaces)))
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                    if !paragraph.isEmpty { flush() }
                    let marker = line.firstIndex(of: " ")!
                    bullets.append(String(line[line.index(after: marker)...]))
                } else if line.hasPrefix(">") {
                    flush()
                    blocks.append(.quote(line.dropFirst().trimmingCharacters(in: .whitespaces)))
                } else if line.hasPrefix("|") {
                    if !paragraph.isEmpty || !bullets.isEmpty { flush() }
                    let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                        .dropFirst()
                        .dropLast(line.hasSuffix("|") ? 1 : 0)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    if !cells.allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } && !$0.isEmpty }) {
                        table.append(cells)
                    }
                } else if !bullets.isEmpty, raw.hasPrefix("  ") {
                    bullets[bullets.count - 1] += " " + line
                } else {
                    if !bullets.isEmpty { flush() }
                    paragraph.append(line)
                }
            }
            if let code { blocks.append(.code(code.joined(separator: "\n"))) }
            flush()
            return blocks
        }
    }
}
