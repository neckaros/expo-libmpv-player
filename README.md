# expo-libmpv-player

Standalone Expo / React Native libmpv player extracted and adapted from Streamyfin's `modules/mpv-player` implementation, with selected stability and playback improvements synchronized from `@lunarr/mpv-player` 1.1.1.

The goal is a reusable native video engine for Expo apps that need broader media support
than the platform players alone: MKV and other containers, AV1 where the device/build can
decode it, audio/subtitle track selection, external subtitles, Picture in Picture, HDR-aware
output paths, hardware decoding and technical playback information.

> **Status:** standalone native module (`0.2.1`). The source has been separated from Streamyfin, merged with selected Lunarr hardening, and statically checked, but this repository has not yet been compiled in a full Xcode/Gradle device build in this environment. Treat it as a testable native-module repo rather than a production-certified player.

## Platforms

| Platform | Native engine | Minimum | Notes |
| --- | --- | ---: | --- |
| iOS | MPVKit / libmpv + AVSampleBufferDisplayLayer | iOS 15.1 | PiP; VideoToolbox; EDR requested on iOS 17+ |
| tvOS | MPVKit / libmpv + AVSampleBufferDisplayLayer | tvOS 15.1 | HDR display criteria path on tvOS 17+ |
| Android | `dev.jdtech.mpv:libmpv:1.0.0` | API 26 | MediaCodec hardware decode path; PiP |
| Web | no libmpv | — | Explicit unsupported fallback |

## Installation

Install the package from npm:

```bash
npm install expo-libmpv-player
```

Add the config plugin to your Expo config:

```json
{
  "expo": {
    "plugins": ["expo-libmpv-player"]
  }
}
```

The plugin configures the native dependencies and PiP requirements that the source module cannot express by itself:

1. Adds Streamyfin's MPVKit `0.41.0-av5` podspec to the iOS Podfile by default.
2. Enables the iOS `audio` background mode used by playback/PiP.
3. Sets `android:supportsPictureInPicture="true"` on Android `MainActivity`.
4. Pins Android NDK `29.0.14206865` for compatibility with `dev.jdtech.mpv:libmpv:1.0.0`.

Then generate/rebuild native projects:

```bash
npx expo prebuild --clean
npx expo run:ios
# or
npx expo run:android
```

This **will not work in Expo Go** because it contains native code. Use an Expo development
build, EAS build, or local native build.

### Custom MPVKit fork

By default the plugin injects:

```text
https://raw.githubusercontent.com/streamyfin/MPVKit/0.41.0-av5/MPVKit.podspec
```

You can override it:

```json
{
  "expo": {
    "plugins": [
      [
        "expo-libmpv-player",
        {
          "mpvKitPodspecUrl": "https://example.com/your/MPVKit.podspec",
          "androidNdkVersion": "29.0.14206865",
          "enablePictureInPicture": true
        }
      ]
    ]
  }
}
```

## Basic usage

```tsx
import { useRef } from "react";
import { Button, View } from "react-native";
import {
  MpvPlayerView,
  type MpvPlayerViewRef,
} from "expo-libmpv-player";

export function PlayerScreen() {
  const player = useRef<MpvPlayerViewRef>(null);

  return (
    <View style={{ flex: 1, backgroundColor: "black" }}>
      <MpvPlayerView
        ref={player}
        style={{ flex: 1 }}
        source={{
          url: "https://example.com/video.mkv",
          autoplay: true,
          cacheConfig: {
            enabled: "yes",
            cacheSeconds: 30,
            maxBytes: 200,
            maxBackBytes: 10,
            pause: true,
            pauseInitial: true,
            pauseWaitSeconds: 5,
          },
        }}
        onProgress={({ nativeEvent }) => {
          console.log(nativeEvent.position, nativeEvent.duration);
        }}
        onError={({ nativeEvent }) => {
          console.error(nativeEvent.error);
        }}
      />

      <Button
        title="Picture in Picture"
        onPress={() => player.current?.startPictureInPicture()}
      />
    </View>
  );
}
```

`cacheSeconds` controls the read-ahead target, while `pause`, `pauseInitial`, and
`pauseWaitSeconds` map to mpv's `cache-pause`, `cache-pause-initial`, and
`cache-pause-wait` options. The configuration above buffers approximately five seconds
before starting or resuming and permits up to 30 seconds of read-ahead. All cache fields
are optional. When omitted, `pause` resets to `true` and `pauseWaitSeconds` to `1` on
both platforms; `pauseInitial` resets to mpv's `false` default on iOS and the player's
existing `true` default on Android.

## Tracks and subtitles

```ts
const audioTracks = await player.current?.getAudioTracks();
const subtitleTracks = await player.current?.getSubtitleTracks();

await player.current?.setAudioTrack(audioTracks?.[0]?.id ?? 1);
await player.current?.setSubtitleTrack(subtitleTracks?.[0]?.id ?? 1);
await player.current?.addSubtitleFile("https://example.com/subtitles.srt", true);
```

The view also exposes subtitle positioning/style, playback speed, mute, seeking, zoom-to-fill, audio delay/boost/mono/dialogue controls, PiP state, genuine-EOF `onEnd`, and `getTechnicalInfo()`.

## Lunarr 1.1.1 hardening merged in 0.2.0

This fork selectively incorporates the useful native fixes from Lunarr rather than replacing the module wholesale. The merge includes Android TV `mediacodec-copy`, NDK 29 pinning, improved PiP/surface recovery, genuine EOF signaling, ASS/SSA bidi handling, safer dialogue/volume filters, tvOS AVFoundation audio fallback, and bounded Apple display-layer decoder recovery. Our existing loop, mute and richer subtitle-style API remain available.

## AV1

The native module exposes:

```ts
import MpvPlayer from "expo-libmpv-player";

const hasHardwareAv1 = MpvPlayer.supportsAv1HardwareDecode();
```

On Apple platforms this asks VideoToolbox directly. On Android it checks available AV1
MediaCodec decoders and, on Android 10+, whether a matching decoder reports hardware
acceleration.

A `false` result does **not** mean libmpv cannot decode AV1 at all: software decoding may
still work, but high-resolution AV1 can be too expensive for a mobile/TV device.

## HDR

This extraction keeps Streamyfin's HDR-oriented Apple playback path:

- `AVSampleBufferDisplayLayer`
- Extended Dynamic Range requested on iOS 17+
- BT.2020 / PQ / HLG inspection through mpv properties
- tvOS 17+ `AVDisplayCriteria` switching
- Streamyfin's customized MPVKit fork

HDR should be considered **device- and stream-dependent**. “The file plays” and “the display
is receiving correct HDR output” are not the same test. Validate HDR10/HLG/Dolby Vision on
the actual devices you intend to support.

## MKV and codecs

MKV is a container, not a codec. libmpv/FFmpeg gives this player broad container/codec support,
but actual direct playback depends on the codecs present in the file, the native libmpv build,
and available hardware/software decoders.

For production, keep a small test corpus covering the combinations you care about, for example:

- MKV + H.264 + AAC
- MKV + HEVC Main10 + E-AC-3
- MKV + AV1 10-bit + Opus
- HDR10 HEVC
- HLG
- Dolby Vision profiles you intend to accept
- embedded ASS/SSA and SRT subtitles
- external subtitle URLs
- PiP while subtitles are active

## Public API

`MpvPlayerViewRef` currently exposes:

- play / pause / destroy
- absolute and relative seek
- speed and mute
- current position and duration
- PiP start / stop / support / active state
- audio track enumeration and selection
- audio delay, soft-volume boost, dialogue EQ and mono downmix
- subtitle track enumeration and selection
- external subtitle loading
- subtitle scale, position, delay, alignment and style
- fit/fill zoom
- technical playback information
- genuine EOF `onEnd` event

`VideoSource` supports HTTP headers, external subtitles, start position, autoplay, loop,
initial audio/subtitle tracks, cache settings and Android MPV VO selection.

## Publishing

Publishing is automated by `.github/workflows/publish.yml`. On every push to `main`, the
workflow checks the package name and version in `package.json`. It publishes only when that
exact version is not already present on npm.

The workflow uses npm Trusted Publishing with GitHub Actions OIDC and does not require an
`NPM_TOKEN` repository secret. Configure the package's Trusted Publisher on npm with:

- Organization or user: `neckaros`
- Repository: `expo-libmpv-player`
- Workflow filename: `publish.yml`
- Allowed action: `npm publish`

For a new release, update `version` in `package.json` and merge the change into `main`.
The first package version must be published manually before npm allows a Trusted Publisher
to be attached to the package.

## Licensing

The Streamyfin-derived source in this repository remains under **MPL-2.0**. See
[`LICENSE.txt`](./LICENSE.txt) and [`UPSTREAM.md`](./UPSTREAM.md).

The default iOS dependency is Streamyfin's `MPVKit 0.41.0-av5` fork. Its podspec explicitly
declares **GPL-3.0**. That is free/open-source software, but GPL distribution obligations can
matter for the application that links and ships the static framework. If you need a different
license profile, point `mpvKitPodspecUrl` at a compatible build/fork and verify that it still
contains the `vo_avfoundation` functionality this module expects.

The Android `dev.jdtech.mpv:libmpv:1.0.0` Maven artifact declares an MIT license for its
wrapper/project metadata, while its bundled native mpv/FFmpeg components can carry their own
license obligations. Review the exact binaries you distribute. See [`NOTICE.md`](./NOTICE.md).

## Upstream

The original extraction is based on Streamyfin commit:

```text
4faddc5fd6b0aaa3aef2a6a0ed1640180ededa5d
```

Version 0.2.0 also imports selected fixes from `lunarr-app/mpv-player` / `@lunarr/mpv-player` 1.1.1 while retaining this fork's extra API. See `UPSTREAM.md` and `CHANGELOG.md` for provenance and the exact synchronization scope.
