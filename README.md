# SpeshTV for Android and Android TV

SpeshTV is a customized media client for Jellyfin, built on Moonfin-Core.
This repository contains the shared source used for our Android mobile/tablet,
Android TV, Google TV and Fire TV builds. Other platform source is retained
because the application and its vendored packages share Flutter code.

## Features

- SpeshTV branding and STV app artwork.
- Cinematic black/charcoal interface, gold actions and blue remote/keyboard focus.
- Local-first search and deduplicated Continue Watching / Next Up.
- Cached home content and Spotlight with background refresh and recovery.
- Live TV preview, full-screen playback, channel switching and recovery.
- Country, sports-package and tag filters; numeric channel entry.
- Remote-friendly guide navigation and hold-Select channel actions.
- Framed series/season/episode browsing, watched counts, episode filters and resume controls.
- Studios/service discovery and a Today-forward Eastern-time calendar.
- Platform-specific playback capabilities and HDR handling.

The client connects to servers you configure. It does not include a media
subscription, provider credentials, channels or a hosted content service.

## Build

Use Flutter 3.47.2 / Dart 3.13, Java 17, Android SDK 36 and NDK 28.2.13676358.
The Android project uses AGP 9.1 and Gradle 9.3.1. See the checked-in Gradle
configuration for exact versions.

```sh
flutter pub get
flutter build apk --release --flavor mobile --dart-define=SPESHMEDIA_CLIENT=true
flutter build apk --release --flavor androidTv --dart-define=SPESHMEDIA_CLIENT=true
```

On Windows, `build-speshmedia.ps1 -Release` builds mobile and
`build-speshmedia.ps1 -Release -AndroidTv` builds TV. Signing keys and private
configuration are deliberately excluded. Configure your own signing before
distributing release builds; see [release signing](RELEASE_SIGNING.md).

## Project links

- [Source and issues](https://github.com/daodere1/SpeshTV-Android)
- [Releases](https://github.com/daodere1/SpeshTV-Android/releases)
- [Customization notes](FORK.md)
- [Privacy](PRIVACY_POLICY.md)

Existing application IDs, platform channels, preference keys and internal
Moonfin package names are retained for installed-app compatibility. They are
implementation identifiers, not the displayed product brand.

## Credits and license

SpeshTV is an independent fork, not an official Moonfin release. Thanks to
[Moonfin-Core](https://github.com/Moonfin-Client/Moonfin-Core), Jellyfin,
Flutter and the authors of the included dependencies. Upstream attribution and
third-party notices remain in their source files. The license accompanying this
customized source is preserved in [LICENSE](LICENSE); vendored packages retain
their own licenses.
