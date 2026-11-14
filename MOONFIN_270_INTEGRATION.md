# Moonfin 2.7.0 Integration

Target: official tag 2.7.0, commit 36ed696f. Base: official 2.6.0.

This is an in-progress integration, not a completed 2.7 release.
Source conflicts have been resolved in the shared checkout by the active
Windows Desktop Client integration. The older staged conflict manifest is
historical, not the current live source state. No conflict markers remain
in lib, packages or Android source. Full analysis reports no errors, with
163 warnings/style notices; the full regression suite still has failures
under investigation. Do not treat selected test passes as full upstream parity.
Android test candidates are now available: mobile 30000185 and TV 2000060,
both version 2.7.0. Both release builds and signature/package-label verification
passed. A focused Android suite passed 34 tests for progress, Spotlight,
intro resume, skip-overlay dismissal, 360p stream selection and guide remote
navigation. The shared SpeshTV-selected suite also passed 855 tests. Device
playback, HDR, trailer fallback and remote navigation still need confirmation.
The installed Shield app remains build 2000059. No partial upgrade is deployed.

## Integrated Source

- Android DLNA scans use separate multicast locks.
- Native volume-boost audio-server calls move off the main thread.
- Subtitle parsing only holds the libass lock for ASS parsing.
- Upstream subtitle-parser regression tests.

Native subtitle-parser tests passed with :moonfin_native_video:testDebugUnitTest
on 2026-10-09. This is not full app/build verification. The build fell back
from the Kotlin daemon to compilation without it and completed successfully.

## Staged Merge

Run tools/stage-moonfin-upgrade.ps1 to recreate the comparison. It writes only
to .native/upstream-2.7.0, never replacing live app files. The manifest lists
471 clean merges, five deletions and 34 conflicted files after line-ending
normalization. Counts include translations and generated localization files.

Resolve translation resources structurally, then regenerate localization code;
do not manually merge generated Dart translations.

Originally conflicted files cover MainActivity, row loading, YouTube resolver,
search, media-kit playback, genres, details, Home, Live TV player, trailers,
video player, playback manager and release version/build numbers. These are
now resolved in live source; do not copy the stale staged versions over them.

Preserve SpeshTV identity, 360p trailer fallback, local-first progress,
session-fresh cold progress, nonblocking Spotlight focus, intro-resume fix,
guide remote navigation and existing native playback optimizations.

## Release Gate

- Resolve all source conflicts and check merged APIs together.
- Review newly introduced user-visible branding.
- Run localization generation and full analysis.
- Run relevant upstream and SpeshTV regression suites.
- Build and verify signed mobile and TV APKs with new unique build numbers.
- Install only the verified TV build and validate on the Shield.
