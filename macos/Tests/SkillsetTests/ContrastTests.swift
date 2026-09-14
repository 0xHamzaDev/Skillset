import AppKit
import SwiftUI
import XCTest
@testable import Skillset

@MainActor
final class ContrastTests: XCTestCase {
    private func luminance(_ color: NSColor) -> Double {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0 }
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(srgb.redComponent)
            + 0.7152 * channel(srgb.greenComponent)
            + 0.0722 * channel(srgb.blueComponent)
    }

    private func ratio(_ a: NSColor, _ b: NSColor) -> Double {
        let first = luminance(a)
        let second = luminance(b)
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func measure(_ appearance: NSAppearance.Name) -> (text: Double, surface: Double) {
        var text = 0.0
        var surface = 0.0
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            let accent = NSColor(Color.accentOrange)
            text = min(ratio(accent, .windowBackgroundColor), ratio(accent, NSColor(Color.canvas)))
            surface = min(ratio(accent, .controlBackgroundColor), ratio(accent, NSColor(Color.card)))
        }
        return (text, surface)
    }

    func testAccentIsReadableAsTextInBothAppearances() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let result = measure(appearance)
            XCTAssertGreaterThanOrEqual(
                result.text, 4.5,
                "accent on the window background fails AA in \(appearance.rawValue): \(String(format: "%.2f", result.text)):1"
            )
            XCTAssertGreaterThanOrEqual(
                result.surface, 4.5,
                "accent on a control background fails AA in \(appearance.rawValue): \(String(format: "%.2f", result.surface)):1"
            )
        }
    }

    func testProminentActionHasReadableWhiteText() {
        XCTAssertGreaterThanOrEqual(ratio(NSColor(Color.actionOrange), .white), 4.5)
    }

    func testAccentActuallyChangesBetweenAppearances() {
        var light = NSColor.black
        var dark = NSColor.black
        NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance { light = NSColor(Color.accentOrange).usingColorSpace(.sRGB)! }
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance { dark = NSColor(Color.accentOrange).usingColorSpace(.sRGB)! }
        XCTAssertNotEqual(light.redComponent, dark.redComponent, accuracy: 0.0001)
        XCTAssertGreaterThan(luminance(dark), luminance(light))
    }
}
