# Android Moonfin 2.8 integration

Targets: SpeshTV mobile 2.8.0+30000198 and Android TV 2.8.0+2000063.
Upstream tag: 2.8.0, commit d9f4bf241d6dfddf54338f21dcdfde05e75fafc8.
The earlier Windows/common integration remains intact. Android platform files
were applied individually from the staged three-way merge; no directory was
replaced wholesale. Originals are in `.native/before-android-28`.

Preserved: SpeshTV flavors/identities/icons/themes, upload-signing configuration,
AGP compatibility switches, R8/resource shrinking and keep rules, constrained
playback buffers, software-decoder/MediaTek safeguards, native resume/cleanup,
custom guide/filter/focus behavior, local-first deduplication, fast search,
progress caches, and artwork scheduling.

Applied: new Android Application renderer selection, codec/audio capability
updates, Cast lifecycle and external-player changes, native game bridge updates,
notification icon keep rules, and the matching Android build toolchain.
AGP 9.1.0 uses Gradle 9.3.1; Kotlin and Compose compiler use 2.4.0 consistently.
Shield/Amazon and unrecognized GPUs are excluded from automatic TV Impeller.

## Final Validation (2026-10-30)

- Mobile release APK compiled successfully: 2.8.0 / 30000198.
- TV release APK compiled successfully: 2.8.0 / 2000063.
- Both APK signatures verify; package is dev.speshmedia.moonfin and label is
  SpeshTV. Both include ARM64, 32-bit ARM and x86-64 native libraries.
- Native release unit tests: mobile 141, TV 141, native-video 282; zero
  failures, errors or skips. Evidence: .native/android28-native-tests.log.
- Shared Flutter helper batches: 200 passed. Activity ordering: 3 passed.
  Evidence: .native/android28-shared-tests.log and android28-activity-tests.log.
- Progress-cache tests were aligned with the existing activity-v2 cache key
  and activity-date ordering. No stale-cache assertions were removed.
- Direct Gradle unit tests now first generate release-only plugin registration
  using Flutter --config-only, excluding the test-only integration_test plugin.
- R8 mappings exist for both flavors. Both APKs contain two DEX files,
  totaling 8,289,568 uncompressed bytes, and 54 native libraries.
- Packaged APKs are in .native/release-candidates/android-2.8.0/.
  They are test candidates, not fully hardware-validated releases.
- No APK installation, store upload, Jellyfin changes or watch-history changes
  were performed. The guide failures described below remain unresolved.

## Remaining Caveats

- Source analysis reports no errors and 169 warning/information items. The
  Windows PowerShell 5 wrapper treats its stderr summary as a command error;
  native build commands use PowerShell 7 instead.
- Existing SpeshTV guide/filter fixtures pass. The combined upstream guide
  navigation batch has 11 failures against the retained custom layout. That
  suite expects genre-rail/window-bar controls absent from this implementation.
  Its failures are not counted as passes; complete screen-level SpeshTV guide
  coverage and hardware validation remain required.
- The customized guide is not replaced by upstream's redesigned guide; do not
  promise all upstream DVR/rewind UI behavior solely from this source update.
- FFmpeg audio extension and Media3 runtime compatibility require device tests.
- No device installation, server changes, or store submission is authorized by
  this document. Record final build results separately when compilation ends.
