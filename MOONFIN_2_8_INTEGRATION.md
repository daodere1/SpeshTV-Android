# Moonfin 2.8 Integration Status

Status: Windows/common source integrated. Version 2.8.0+30000196;
MSIX identity version 2.8.0.0. Compilation and packaging results are recorded
below. No Store upload, installation or device playback verification was
performed as part of this integration.

## Source

- Upstream: https://github.com/Moonfin-Client/Moonfin-Core
- Target tag: 2.8.0
- Target commit: d9f4bf241d6dfddf54338f21dcdfde05e75fafc8
- Three-way base: official 2.7.0; local side is the current working source,
  not the older committed SpeshTV checkpoint.
- Staging: .native/upstream-2.8.0/
- Machine-readable results: .native/upstream-2.8.0/manifest.json
- Log: .native/moonfin-28-staging.log

The staged results were applied with scripts/apply-moonfin-28-stage.ps1 and
then reconciled in the working source. Original affected files are retained
in .native/before-moonfin-28; renamed originals are in its legacy-renames
directory. application-audit.json records the initial application decisions.
Source archives and conflicted staging outputs are retained for reference;
they are not deployable files. Localization outputs were regenerated.

## Preflight Results

1,334 upstream changed paths: 1,215 clean, 12 upstream deletions,
106 merge conflicts and one local-deletion conflict. These counts include
generated translations, tests and platforms outside the Windows request.

Handwritten conflicts include the media bar/cache, progress enrichment,
details/library view models, custom guide and live player, playback backend,
router, trailers, Home, dependency configuration and regression tests.

## Integration Decisions

- The deeply customized SpeshTV guide/view model/player were retained and
  adapted to the new APIs. This does not replace them with upstream's rebuilt
  guide or promise parity with all upstream DVR/rewind UI changes.
- Playback incorporates the new desktop HDR presentation, mini-player and
  dual-subtitle APIs while retaining live no-seek opening, native resume,
  session ownership checks and release-before-stop-report cleanup.
- Home retains local-first activity deduplication, progress caching and
  websocket/reconnect refresh. The new upstream section-refresh controls,
  external Spotlight sources and deferred section loading are integrated.
- Library/details retain combined-library provider-ID deduplication,
  bounded metadata requests, image scheduling and incremental search.
- Settings/book source renames were reconciled; obsolete duplicate files
  were backed up and removed. SpeshTV themes, translated display branding,
  embedded Windows trailer support and optional announcements are retained.
- Store publisher, package name and speshtv protocol remain SpeshTV's.
- Android/iOS/native TV platform-specific upgrades and builds are outside
  this Windows integration. Server plugins/settings were not changed.

## Verification

- Static analysis: no errors (179 warnings/information items; nonfatal).
- Focused branding, fast-search, Spotlight and guide focus/filter tests:
  29 passed.
- Playback/progress/guide/library/Home/subtitle regression batch: 256 passed.
- Jellyfin API package: 74 passed; 22 opt-in live/container tests skipped.
- Native Windows runner visibility test: passed (CTest, Release).
- Native Windows Release compilation: passed for announcements enabled and
  disabled. Both executables report 2.8.0+30000196; their compiled Dart
  payloads have distinct hashes, confirming separate variant builds.
- Inno Setup installer compilation: passed for both variants. Installers,
  payload inventories and SHA256SUMS.txt are in
  build/windows/distribution/2.8.0+30000196-moonfin-28-announce-unsigned-candidate/
  and the corresponding moonfin-28-no-announce-unsigned-candidate directory.
- Both installers are unsigned test candidates. Actual device playback,
  clean-machine installation and Store certification remain unverified.
- Final artifact check: all 192 inventoried payload files match their hashes
  in each variant. Evidence: .native/moonfin-28-artifact-verification.json.
- MakeAppx packaging/manifest validation passed for the no-announcements
  Store-review package build/windows/store/2.8.0.0-review/SpeshTV-2.8.0.0-x64.msix.
  Package name, publisher and version were read back from the archive and
  verified. This unsigned archive was not uploaded or installed.

## Preserved Requirements

- Preserve SpeshTV branding, SpeshCaster.SpeshTV Store identity, publisher,
  speshtv protocol, standalone installer identity and optional announcements.
- Preserve local-first deduplication, activity ordering, progress caching,
  Home refresh coordinator, artwork scheduling and fast incremental search.
- Preserve independent live-stream cleanup/recovery and custom guide facets,
  navigation and preview/fullscreen handoff while adapting upstream APIs.
- Resolve dual-subtitle/backend and desktop mini-player changes together;
  accepting only one side of an overlapping conflict is not sufficient.
- Reconcile ARB resources structurally; regenerate localization Dart outputs.
- Resolve pubspec dependencies and regenerate the lockfile with Flutter 3.47.2.
- Inspect Windows native changes, packaged-process handling, playback libraries
  and Store-safe update behavior. Never import upstream's publisher identity.
- Keep unrelated existing user edits; snapshot affected files before applying.
- Run analysis, upstream feature tests and SpeshTV regressions, then compile
  and package both Windows variants. Do not label a staged merge as a release.
- Bump the separate MSIX version before any replacement Store submission;
  the existing 2.7.0.0 package/draft is untouched by this integration.

No server plugin, credentials, mappings, watch history or running service was
changed. The upstream notes recommend Moonbase plugin 2.5.0 for synchronization
of new settings; server updates are a separate operation, not performed here.
