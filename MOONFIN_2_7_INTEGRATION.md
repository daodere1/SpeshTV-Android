# Moonfin 2.7 Integration

Source: https://github.com/Moonfin-Client/Moonfin-Core/releases/tag/2.7.0

The upstream 2.6.0-to-2.7.0 delta was merged against the current SpeshTV
working files, not against an older SpeshTV checkpoint. Original affected
files are backed up in .toolchains/moonfin-27-integration/local. This
update does not modify the Jellyfin server, user mappings or watch history.

## Included Areas

- Mobile Dock, Split and Strip navigation and revised hub controls.
- Library order controls, per-category filter clearing and filter search.
- Per-device detail-section visibility and focus recovery.
- Multi-server search, server labels/artwork and nonblocking people results.
- Native live recovery budgets, stream-release protections and TV carousel.
- Playback/subtitle, bitrate detection, cast transport and offline-sync fixes.
- Android frame pacing, memory limits and previous-process crash diagnostics.
- Home image caching, seasonal rows/effects and achievement updates.
- Windows rendering/startup fixes and upstream platform source updates.

## Fork Adaptations

SpeshTV keeps its custom guide, filter navigation, preview/fullscreen handoff,
recent channel history and per-user playback explanations. Native recovery
is delegated to PlaybackManager; the web watchdog remains separate. The
carousel is reached with Up when the TV player controls are hidden. The
existing guide picker is retained.

Search retains incremental Local/VOD/Live sources and adds upstream's
multi-server support. The Android trailer resolution cap is retained while
using upstream's visitor handling and original-soundtrack selection.
Windows live streams do not inherit a movie resume offset. Announcements
remain an optional build variant and opt-in during use.

The upstream Microsoft Store publisher identity was not adopted. SpeshTV
store publishing still requires its own verified publisher configuration.
Upstream license notices and source attribution are preserved.

## Verification

- Version: 2.7.0+30000185; Android TV version code: 2000060.
- Focused SpeshTV integration suite: 855 tests passed. It covers native
  playback, release/recovery, trailers, subtitles, search, progress caching,
  catalog caching, carousel, bottom navigation, branding and guide controls.
- Final Dart analysis completed without errors (161 warnings/information
  diagnostics remain).
- Android TV and phone release APKs compiled and their SpeshTV labels/version
  codes were inspected. Windows x64 builds compiled with announcements enabled
  and disabled; runtime DLLs and attribution notices are included.
- Test packages and checksums are in build/2.7.0-speshtv-beta.
- The unfiltered upstream-mode run is not green (3893 passed, 48 failed,
  one skipped before the subsequent fixes). Some tests assume upstream guide
  layout/loading UI or omit the SpeshTV client define. Several search fixtures
  were corrected and rerun successfully in the focused suite. Remaining guide
  tests need adaptation/review; this is not a claim of full-suite approval.

Logs are under .native/moonfin-27-*. These are test candidates, not a public
release. Target-device playback/navigation testing is still required, and Apple
platform changes cannot be compiled on this Windows host. No client installation
or Jellyfin restart was performed.
