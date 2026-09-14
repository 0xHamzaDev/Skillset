# Skillset redesign

Date: September 15, 2026. Current design direction, replacing the visual and language decisions in the September 14 notes.

## Purpose

A home for your agent skills: see what is installed, find a useful addition, and understand what an install will change. The Mac app manages local files. The website helps people discover the catalog and get the app. Both surfaces are English-only.

## Identity and surfaces

Three overlapping rounded tabs form the Skillset mark. System sans typography, warm paper, charcoal, apricot highlights and an adaptive orange accent connect the surfaces.

The website follows Alcove's generous centered composition: a large headline, one apricot highlight, a dark primary action, and a dominant interactive Mac-style demonstration. The demonstration uses real catalog entries and is explicitly a preview; it cannot inspect a visitor's Mac. Skill and bundle pages retain their source links, terminal commands and app deep links.

The app follows native macOS conventions: a material sidebar, glass controls, compact navigation and solid adaptive reading surfaces. The welcome flow introduces the same tab mark. Installed, Discover, Bundles and Updates retain their keyboard commands and loading, error and empty states. Plugin skills remain read-only. Both appearances must remain readable; reduced motion and reduced transparency use platform preferences.

## Useful discovery

Discover shows up to three explained suggestions. The order is:

1. Missing skills from a curated bundle that contains recognized installed skills.
2. Skills sharing catalog tags with a recognized installed skill.
3. Honest curated picks when there is no stronger evidence.

Every personalized suggestion names its evidence. Recognition prefers repository and path identity for managed skills; unambiguous names identify manual or plugin copies. Installed names and source identities are excluded, and repeated catalog entries do not produce duplicate suggestions. Busy installations are excluded. Ranking is local and deterministic, with catalog order breaking equal scores. No model, account or paid API is involved.

The catalog does not declare agent compatibility. Suggestions therefore make no new compatibility claims and use the existing installation and agent-linking behavior. A shared tag indicates related subject matter, not a guarantee of quality or usefulness. Read-only plugin copies may inform suggestions but cannot be updated or removed through Skillset.

## Simplicity and checks

Keep Astro and native SwiftUI; no new production dependencies. `catalog/catalog.json` remains the shared source of truth. Legacy `/en` routes render English and declare root URLs as canonical. The website offers an explicit appearance toggle and uses system preference initially. The Mac app offers System, Light and Dark in Settings.

Run website type, build and contrast checks, Swift tests and a release build. Smoke-test actual catalog filters, detail and bundle navigation, appearance switching, native search/navigation and onboarding. Use isolated fixtures for install/update/remove tests. Capture the native app on screen for dark-mode review: the existing offscreen `Snapshot` harness cannot reproduce macOS vibrancy faithfully.

## Distribution boundary

The repository's existing release URL is not a published download yet. Do not imply a release exists or fabricate an active download. Publishing, Developer ID signing and notarization remain separate work. No push is authorized by this redesign task.
