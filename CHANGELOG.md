# Changelog

## 0.2.0 - 2026-09-15

### Added

- `onEnd`, emitted only for genuine end-of-file rather than stop/reload teardown.
- Public audio controls for delay, volume boost, dialogue boost, and mono downmix.
- Android NDK 29 pinning in the Expo config plugin for `dev.jdtech.mpv:libmpv:1.0.0`.
- Lunarr provenance and synchronization notes.

### Changed

- Imported selected hardening from `@lunarr/mpv-player` 1.1.1 while preserving this fork's extra API.
- Android TV uses `mediacodec-copy` rather than zero-copy `mediacodec`.
- Android PiP/surface size synchronization and TV resume recovery are more defensive.
- ASS/SSA subtitle selection applies the bidi `Encoding=-1` override on Android and Apple platforms.
- Dialogue boost uses a labeled mpv audio filter so it does not replace other active filters.
- Volume boost restores mpv's normal `volume-max` when returning to 100%.
- tvOS prefers `avfoundation,audiounit` for audio output.
- Apple display-layer failures get bounded VideoToolbox decoder recovery.
- Apple teardown drains mpv events before native destruction.

### Licensing

- The module source remains MPL-2.0.
- The default Apple MPVKit dependency remains Streamyfin `0.41.0-av5`, whose podspec declares GPL-3.0. The plugin still supports a custom compatible podspec.
