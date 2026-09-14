import SwiftUI

struct OnboardingView: View {
    @Environment(Store.self) private var store
    let done: () -> Void
    @State private var revealed = 0

    private var step: Int { store.onboardingStep }

    private var agents: [Agent] { Agent.allCases.filter { $0 != .universal } }
    private var starters: [SkillBundle] { Array(store.catalog.bundles.prefix(3)) }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Ellipse()
                .fill(Color.accentOrange.opacity(0.12))
                .frame(width: 440, height: 260)
                .blur(radius: 70)
                .offset(y: -190)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer(minLength: 12)
                content
                    .frame(maxWidth: 440)
                    .animation(Motion.move, value: step)
                Spacer(minLength: 12)
                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbarVisibility(.hidden, for: .windowToolbar)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: reach
        default: starter
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            BrandMark(size: 82)
                .padding(26)
                .glassEffect(.regular, in: .rect(cornerRadius: 34))
                .shadow(color: Color.accentOrange.opacity(0.12), radius: 28, y: 14)
            VStack(spacing: 10) {
                Text("A home for your\nagent skills.")
                    .font(.system(size: 39, weight: .bold, design: .rounded))
                    .tracking(-1.4)
                    .multilineTextAlignment(.center)
                Text("Find your favorites. Give your agents new talents.\nKeep everything together with Skillset.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(promises, id: \.symbol) { promise in
                    VStack(spacing: 10) {
                        Image(systemName: promise.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.accentOrange)
                        Text(promise.text)
                            .font(.callout.weight(.medium))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.card, in: .rect(cornerRadius: 18))
                }
            }
        }
    }

    private var promises: [(symbol: String, text: String)] {
        [
            ("magnifyingglass", "Find your\nnext skill"),
            ("shippingbox", "Build your\ntoolkit"),
            ("arrow.trianglehead.2.clockwise", "Stay up\nto date"),
        ]
    }

    private var reach: some View {
        let here = agents.filter(\.isPresent)
        return VStack(spacing: 14) {
            Text(here.isEmpty ? "Ready for your first agent" : "Found on this Mac")
                .font(.title.bold())
            Text(here.isEmpty
                ? "Install a supported agent, then refresh Skillset to connect your skills."
                : "Your skills live in one place. Skillset connects them to the agents you already use.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Panel {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(agents.enumerated()), id: \.element) { index, agent in
                        let found = agent.isPresent
                        HStack(spacing: 8) {
                            Image(systemName: found ? "checkmark.circle.fill" : "circle.dotted")
                                .foregroundStyle(found ? AnyShapeStyle(Color.accentOrange) : AnyShapeStyle(.quaternary))
                            Text(agent.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(found ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                            Spacer()
                            Text(agent.root.path.replacingOccurrences(of: Paths.home.path, with: "~"))
                                .font(.subheadline.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        .opacity(index < revealed ? 1 : 0)
                        .offset(y: index < revealed ? 0 : 6)
                    }
                }
            }
            .task {
                for index in agents.indices {
                    try? await Task.sleep(for: .milliseconds(70))
                    withAnimation(Motion.move) { revealed = index + 1 }
                }
            }

            if !store.installed.isEmpty {
                Text("\(store.installed.count) skills are already installed here. Skillset picked them up.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var starter: some View {
        VStack(spacing: 14) {
            Text("Good together.")
                .font(.title.bold())
            Text("Handpicked skills that work as a set. Install a bundle now, or explore at your own pace.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Array(starters.enumerated()), id: \.element.id) { index, bundle in
                    Button {
                        store.selection[.bundles] = bundle.id
                        store.pane = .bundles
                        done()
                        Task { await store.install(bundle: bundle) }
                    } label: {
                        HStack(spacing: 10) {
                            GlyphTile(symbol: bundle.symbol, size: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Text(bundle.name.current).font(.headline)
                                    Text("\(bundle.skills.count) skills")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                                Text(store.catalog.skills(in: bundle).map(\.title).formatted(.list(type: .and)))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 6)
                            KeyHint(keys: ["\(index + 1)"])
                        }
                        .padding(11)
                        .contentShape(.rect)
                    }
                    .buttonStyle(StarterButtonStyle())
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index == step ? Color.accentOrange : Color.secondary.opacity(0.25))
                        .frame(width: index == step ? 16 : 5, height: 5)
                }
            }
            .animation(Motion.move, value: step)

            Spacer()

            Button(step == 2 ? "Not now" : "Skip") { done() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)

            if step < 2 {
                Button {
                    withAnimation(Motion.move) { store.onboardingStep += 1 }
                } label: {
                    Text(step == 0 ? "Make yourself at home" : "Continue").frame(minWidth: 58)
                }
                .buttonStyle(.glassProminent)
                .tint(.actionOrange)
                .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .frame(maxWidth: 460)
    }
}

struct StarterButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hovering ? AnyShapeStyle(.background.tertiary) : AnyShapeStyle(.background.secondary), in: .rect(cornerRadius: Metric.radiusPanel))
            .overlay {
                RoundedRectangle(cornerRadius: Metric.radiusPanel)
                    .strokeBorder(hovering ? Color.accentOrange.opacity(0.4) : Color(nsColor: .separatorColor), lineWidth: Metric.hairline)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .onHover { hovering = $0 }
            .animation(Motion.tap, value: hovering)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}
