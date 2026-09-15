# Dependency and license notice

This repository contains Streamyfin-derived source code under **MPL-2.0**. See
`LICENSE.txt` and `UPSTREAM.md`.

## Default Apple dependency

The Expo config plugin defaults to Streamyfin's MPVKit `0.41.0-av5` podspec:

```text
https://raw.githubusercontent.com/streamyfin/MPVKit/0.41.0-av5/MPVKit.podspec
```

That podspec declares **GPL-3.0** and distributes MPVKit as a static framework. GPL-3.0 is
free and open source, but it carries copyleft obligations that can affect distribution of
an application linking the framework. This repository does not provide legal advice.

The config plugin accepts `mpvKitPodspecUrl` so an application can select another compatible
MPVKit build. Compatibility requires the AVFoundation video-output functionality used here
(`vo=avfoundation`) plus the related PiP/display-layer behavior.

## Default Android dependency

The Android module resolves:

```text
dev.jdtech.mpv:libmpv:1.0.0
```

The Maven project metadata declares the libmpv-android wrapper under the MIT license. The AAR
contains native media components (mpv/FFmpeg and related libraries), whose licensing depends
on how that binary was built. Check the dependency's source/build configuration and notices
for the exact version you ship.

## Application distribution

Before publishing an App Store, Play Store, enterprise, or other binary distribution, review
the licenses and notices for every native artifact actually bundled in that build.
