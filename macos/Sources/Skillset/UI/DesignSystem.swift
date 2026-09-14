import SwiftUI

enum Metric {
    static let onboarding = CGSize(width: 600, height: 600)
    static let hairline: CGFloat = 1
    static let gutter: CGFloat = 28
    static let stack: CGFloat = 24

    static let radiusChip: CGFloat = 6
    static let radiusControl: CGFloat = 12
    static let radiusPanel: CGFloat = 18

    static let detailWidth: CGFloat = 680
    static let listMin: CGFloat = 300
    static let listIdeal: CGFloat = 372
    static let sidebar: CGFloat = 208
}

enum Motion {
    private static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static var tap: Animation { reduced ? .linear(duration: 0.01) : .snappy(duration: 0.16, extraBounce: 0) }
    static var move: Animation { reduced ? .linear(duration: 0.01) : .snappy(duration: 0.24, extraBounce: 0.02) }
    static var enter: Animation { reduced ? .linear(duration: 0.01) : .smooth(duration: 0.32) }
}

extension Color {
    static let actionOrange = Color(red: 0.70, green: 0.23, blue: 0.05)
    static let accentOrange = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1, green: 0.592, blue: 0.365, alpha: 1)
            : NSColor(srgbRed: 0.76, green: 0.26, blue: 0.075, alpha: 1)
    })
    static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.105, green: 0.102, blue: 0.098, alpha: 1)
            : NSColor(srgbRed: 0.98, green: 0.97, blue: 0.95, alpha: 1)
    })
    static let card = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.145, green: 0.141, blue: 0.137, alpha: 1)
            : NSColor.white
    })
}

struct BrandMark: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: size * 0.16)
                    .fill(Color.accentOrange.opacity([0.3, 0.6, 1][index]))
                    .frame(width: size * 0.64, height: size * 0.78)
                    .rotationEffect(.degrees(Double(index - 1) * 14))
                    .offset(x: CGFloat(index - 1) * size * 0.16, y: index == 1 ? -size * 0.05 : 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct Panel<Content: View>: View {
    var padding: CGFloat = 18
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.map { AnyShapeStyle($0.opacity(0.08)) } ?? AnyShapeStyle(Color.card), in: .rect(cornerRadius: Metric.radiusPanel))
            .overlay {
                RoundedRectangle(cornerRadius: Metric.radiusPanel)
                    .strokeBorder(tint.map { AnyShapeStyle($0.opacity(0.25)) } ?? AnyShapeStyle(Color.primary.opacity(0.07)), lineWidth: Metric.hairline)
            }
    }
}

struct FieldLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

struct Chip: View {
    let text: String
    var accent: Color?

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(accent ?? .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((accent ?? .secondary).opacity(0.1), in: .rect(cornerRadius: Metric.radiusChip))
    }
}

struct GlyphTile: View {
    let symbol: String
    var size: CGFloat = 30
    var accent: Color = .accentOrange

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(accent.opacity(0.12), in: .rect(cornerRadius: size * 0.3))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3)
                    .strokeBorder(accent.opacity(0.16), lineWidth: Metric.hairline)
            }
            .accessibilityHidden(true)
    }
}

extension Pane {
    var title: LocalizedStringKey {
        switch self {
        case .installed: "Installed"
        case .discover: "Discover"
        case .bundles: "Bundles"
        case .updates: "Updates"
        }
    }

    var symbol: String {
        switch self {
        case .installed: "checkmark.circle"
        case .discover: "square.grid.2x2"
        case .bundles: "shippingbox"
        case .updates: "arrow.trianglehead.2.clockwise"
        }
    }
}

enum Glyph {
    private static let byTag: [String: String] = [
        "documents": "doc.text", "office": "doc.text",
        "react": "atom", "frontend": "rectangle.3.group", "react-native": "iphone",
        "design": "paintbrush.pointed", "visual": "paintbrush.pointed",
        "process": "list.bullet.clipboard", "planning": "list.bullet.clipboard",
        "testing": "checkmark.shield", "review": "text.magnifyingglass",
        "obsidian": "square.stack", "notes": "note.text",
        "database": "cylinder.split.1x2", "supabase": "cylinder.split.1x2", "backend": "server.rack",
        "agents": "sparkles", "tooling": "wrench.adjustable", "api": "chevron.left.forwardslash.chevron.right",
        "deploy": "arrow.up.forward.square", "vercel": "triangle",
        "writing": "text.alignleft", "git": "arrow.triangle.branch",
        "animation": "waveform.path", "performance": "gauge.with.needle",
        "creative": "wand.and.stars", "debugging": "ladybug",
        "accessibility": "figure.arms.open", "web": "globe", "mobile": "iphone", "data": "tablecells",
    ]

    static func symbol(for tags: [String]) -> String {
        tags.lazy.compactMap { byTag[$0] }.first ?? "puzzlepiece.extension"
    }
}

extension InstallState.Stage {
    var title: LocalizedStringKey {
        switch self {
        case .downloading: "Downloading"
        case .extracting: "Extracting"
        case .linking: "Linking"
        }
    }
}

struct StatusBadge: View {
    let state: InstallState
    var compact = false

    var body: some View {
        content
            .transition(.opacity.combined(with: .scale(scale: 0.82)))
            .animation(Motion.tap, value: state)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .available:
            EmptyView()
        case .installed:
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
                .accessibilityLabel("Installed")
        case .updateAvailable:
            Badge(text: "Update", symbol: "arrow.up", color: .accentOrange, compact: compact)
        case .installing(let stage), .updating(let stage):
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                if !compact { Text(stage.title) }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        case .removing:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                if !compact { Text("Removing") }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        case .failed:
            Badge(text: "Failed", symbol: "exclamationmark", color: .red, compact: compact)
        }
    }
}

struct Badge: View {
    let text: LocalizedStringKey
    let symbol: String
    let color: Color
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            if !compact { Text(text) }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: .rect(cornerRadius: Metric.radiusChip))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

struct KeyHint: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .frame(minWidth: 15, minHeight: 15)
                    .padding(.horizontal, 2)
                    .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: Metric.radiusChip))
            }
        }
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(toast.text).lineLimit(2)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: 460)
    }

    private var symbol: String {
        switch toast.kind {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch toast.kind {
        case .info: .secondary
        case .success: .green
        case .failure: .red
        }
    }
}
