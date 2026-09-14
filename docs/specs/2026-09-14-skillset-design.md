# Skillset — a macOS manager for agent skills

Date: 2026-09-14. Historical implementation notes. Visual and language decisions are superseded
by [the September 15 redesign](2026-09-15-skillset-redesign.md).

## What it is

A native macOS app (Swift, SwiftUI, macOS 26+) that finds every agent skill installed on the
machine, lets the user browse a curated catalogue, installs and removes individual skills,
updates them, and installs bundles (curated sets of skills) in one action. The website is the
discovery and distribution layer, editorial where the app is compact, and built on the same
neutral surfaces and single copper accent: it serves the catalogue as JSON and links every skill
and bundle straight into the app.

## What a skill is

A directory holding a `SKILL.md` with YAML frontmatter (`name`, `description`) — the open Agent
Skills format shared by Claude Code, Codex, Cursor, OpenCode, Kiro, Gemini CLI and others.

## Where skills live on a Mac

Canonical install root: `~/.agents/skills/<name>` (the same root the `npx skills` CLI uses).
Each agent that is present on the machine gets a symlink `~/.<agent>/skills/<name>` pointing
at the canonical directory. Provenance is recorded in `~/.agents/.skill-lock.json` (version 3,
the CLI's own format), so the app and the CLI see each other's installs.

Detection scans these roots, resolves symlinks and de-duplicates by real path:

| Agent | Root |
|---|---|
| Universal | `~/.agents/skills` |
| Claude Code | `~/.claude/skills`, plus plugin skills under `~/.claude/plugins/cache/*/*/*/skills` (read-only) |
| Codex | `~/.codex/skills` |
| Cursor | `~/.cursor/skills` |
| OpenCode | `~/.config/opencode/skills` |
| Kiro | `~/.kiro/skills` |
| Gemini CLI | `~/.gemini/skills` |
| Copilot | `~/.copilot/skills` |

## Sources

`catalog/catalog.json` is the single source of truth. Every skill names a source. Today the
only source kind is `github` (`owner`, `repo`, `ref`, `path`). The source is an enum with one
case; adding `git`, `http` archive or a registry later means adding a case and a download
branch, nothing else changes.

Install flow: download `https://codeload.github.com/{owner}/{repo}/tar.gz/{ref}` (no rate
limit), extract with `/usr/bin/tar`, copy `path` into a staging directory, validate that it has
a `SKILL.md`, then move it into place atomically and link it into every agent root that exists.
A bundle install fetches each distinct repo once.

Update check: the folder's git tree SHA from the GitHub contents API is stored as
`skillFolderHash` at install time; a differing SHA upstream means an update is available.

## App architecture (one target, folders by responsibility)

```
macos/Sources/Skillset/
  App/        entry point, window, menu commands, URL scheme handling
  State/      Store — the one @Observable object; install states keyed by skill id
  Models/     CatalogSkill, Bundle, Source, InstalledSkill, InstallState
  Discovery/  AgentRoots, SkillScanner, Frontmatter
  Catalog/    CatalogClient (remote first, cached, bundled fallback)
  Install/    GitHub, Installer, SkillLock
  Bundles/    BundleInstaller (fan-out over Installer, aggregate progress)
  System/     Shell (Process wrapper), Paths
  UI/         views, glass modifiers, empty/error states
```

Networking is `URLSession`. Concurrency is Swift async/await; the Store is `@MainActor`.
No third-party dependencies.

## UI

Three-column `NavigationSplitView`: sidebar (Installed, Discover, Bundles, Updates), a list
with a Raycast-style search field pinned at the top, and a detail pane. Arrow keys move the
selection, Return installs, ⌘⌫ removes, ⌘F focuses search, ⌘R rescans. Liquid Glass is used
where the platform uses it — the search field, the primary action, floating status — and
nowhere else. Accent is a copper that clears WCAG AA against the window and control backgrounds
in both appearances; a test measures it, and the website's palette is measured by a check that
fails its build.

States per skill: `available`, `installing(progress)`, `installed`, `updateAvailable`,
`updating`, `removing`, `failed(message)`. Every list and pane has an empty, loading and error
state. `Store.updatable` is the one answer to "what can Skillset update" — the skills it manages,
that carry a source, whose folder hash came back changed — and the Updates rows, the counts, the
sidebar badge and Update all all read from it.

The app registers `skillset://skill/<id>` and `skillset://bundle/<id>`; the website's install
buttons open the app on that item.

## Website

Astro site, unchanged shell. Pages: home (hero, how it works, bundles, skills browser, get the
app), `/skills/<id>`, `/bundles/<id>`, `/catalog.json`. Arabic first, English at `/en/`.

## Changes since the first draft

Bundles became persona collections (Developer, AI Engineer, Front-end, Research, Writing, Office
files, Ship it), each carrying a localized `why` line shown before installing. Per-bundle accent
colours are gone from both surfaces and from the catalogue: one copper accent carries the whole
product. List rows carry no icon, because every skill resolved to the same fallback glyph and the
result read as a wall of identical tiles.

The first run opens a window sized to the onboarding itself, not the app's full frame, and the
window grows to the app's own minimum once onboarding finishes.

The Installed pane groups by what Skillset can act on: skills it installed, skills the user put
there by hand, and read-only plugin skills. Linking a skill into every agent covers only the
skills in `~/.agents/skills`; a skill that lives inside one agent's folder stays there.

`macos/Sources/Skillset/System/Snapshot.swift` is an environment-gated screenshot harness used to
review the app during development. It renders the window offscreen with `cacheDisplay`, which
cannot reproduce macOS vibrancy: captures are reliable in light appearance and wrong in dark. Dark
appearance is verified by keeping every colour semantic or adaptive rather than by screenshot.

## Design system

Type comes from the macOS ramp and nowhere else: `title` for a detail heading, `title3` for the
onboarding lede, `headline` for a row title, `body` for prose, `callout` for secondary prose and
inline controls, `subheadline` for row subtitles and monospaced paths, `caption`/`caption2` for
badges and glyphs. Only two decorative SF Symbols carry a numeric size, because those are
dimensions rather than text. A fixed point size would also ignore the system text-size setting.

Three corner radii: `radiusChip` 5 for chips, badges and key caps, `radiusControl` 8 for controls
and code blocks, `radiusPanel` 12 for panels. `GlyphTile` scales its own radius with its size.

Glass is used on nine surfaces, all functional: the search field, the primary and secondary
buttons, the overflow menu, and the toast.

A skill's frontmatter description is written for an agent's router, not for a person. Both
surfaces show its first sentence and put the rest behind a disclosure, unless the description is
one sentence or the remainder is under a line — the same rule in `String.condensed` and the
site's `lede()`.

## Known issues

SwiftUI's sidebar occasionally logs "Application performed a reentrant operation in its
NSTableView delegate" while the installed list mutates, and once wrote a stale pane back through
`List(selection: $store.pane)`, moving the window to another pane mid-install. It is intermittent,
inside SwiftUI's own AppKit bridge, and two attempts to serialise around it (`await Task.yield()`
and `DispatchQueue.main.async`) changed nothing and were reverted. Not worth chasing again without
a reliable reproduction.

## Performance

The store keeps one derived index, rebuilt when `installed` or `catalog` changes, rather than
recomputing sets and dictionaries inside `state(_:)` and the row builders. Before that, every row
render filtered 120 installed skills and rebuilt a set of their names, so one pass over the list
cost roughly eleven thousand string insertions.

## Out of scope for this iteration

Project-local skills (`./.claude/skills`), a GitHub token, a self-updating app, code signing
with a Developer ID, and a web registry beyond the static catalogue.
