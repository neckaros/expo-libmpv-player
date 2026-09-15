# Upstream provenance

This repository is a standalone derivative of the MPV Expo module in **Streamyfin**.

- Upstream repository: `streamyfin/streamyfin`
- Upstream path: `modules/mpv-player`
- Snapshot commit: `4faddc5fd6b0aaa3aef2a6a0ed1640180ededa5d`
- Snapshot date: 2026-09-12
- Upstream license: Mozilla Public License 2.0 (`LICENSE.txt`)

The architecture, native bridge/API shape, MPV/AVFoundation integration, PiP approach,
track/subtitle handling and platform-specific playback configuration are derived from
Streamyfin's module. This standalone extraction intentionally modifies the upstream
code rather than being a byte-for-byte copy.

## Standalone changes

- Removed `NativePlayerModule` and Streamyfin's presented/native player UI.
- Removed Android Jetpack Compose, Media3/ExoPlayer and Jellyfin-specific dependencies.
- Retained only the small Android player-engine/ownership abstractions needed by the MPV view.
- Simplified some Streamyfin recovery/diagnostic code while preserving the public MPV view API.
- Removed Streamyfin-specific bundled subtitle-font handling; standard mpv/libass font fallback is used.
- Added a standalone package manifest and Expo config plugin.
- Added automatic Android `MainActivity` PiP configuration.
- Added iOS `audio` background mode configuration.
- Pinned the same Streamyfin MPVKit fork used by the upstream app (`0.41.0-av5`) through the config plugin.
- Added a dependency-free web fallback that reports that libmpv is unavailable on web.

When updating this project from Streamyfin, compare the upstream module at the commit
above (or a newer commit) before applying changes, especially around MPVKit, PiP,
AVSampleBufferDisplayLayer, VideoToolbox and Android libmpv lifecycle management.

## Dependency licenses

The MPL-2.0 license in this repository covers the Streamyfin-derived source files and
this derivative's modifications. Native dependencies are separate works with their own
licenses. The default Streamyfin MPVKit `0.41.0-av5` podspec declares GPL-3.0. The Android
`dev.jdtech.mpv:libmpv:1.0.0` project metadata declares MIT for its wrapper, while bundled
native mpv/FFmpeg components may carry additional obligations. Review the exact binaries
before distributing an application binary. See `NOTICE.md`.
