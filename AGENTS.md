# Repository Guidelines

## Project overview

This repository contains `expo-libmpv-player`, an Expo/React Native native module for
libmpv playback. The public TypeScript API lives in `src/` and `index.ts`; native
implementations live in `android/` and `ios/`; Expo prebuild configuration lives in
`plugin/` and `app.plugin.js`.

The module cannot run in Expo Go. Native behavior must be tested in a development build,
an EAS build, or a locally compiled native app.

## Validation

Install dependencies and run the standard checks with:

```bash
npm ci
npm run typecheck
npm run pack:check
```

When changing native code, also validate the affected platform with an appropriate
Xcode/Gradle device or simulator build whenever the environment supports it.

## Releases

Publishing is handled by `.github/workflows/publish.yml`. The workflow publishes from
`main` when the version in `package.json` does not already exist on npm.

Keep release versions synchronized across `package.json`, `ios/MpvPlayer.podspec`, and
`android/build.gradle`. Update `CHANGELOG.md` for every release.

If a release changes anything in `ios/`, `android/`, the Expo config plugin, or another
part of the native integration, its changelog entry must prominently include:

> **Native rebuild required:** This release changes iOS/Android native code and cannot be
> delivered through an OTA update alone.

Use that notice even when the JavaScript or TypeScript API remains compatible. Release
notes should explain that development clients and production apps need a new native build.
Recommend `npx expo prebuild --clean` only for projects whose native directories are
generated; bare or manually maintained native projects should update their native
dependencies and rebuild without discarding local native changes.

## Licensing and provenance

Preserve the attribution and licensing information in `LICENSE.txt`, `NOTICE.md`, and
`UPSTREAM.md`. When importing upstream native changes, record their source and scope in
`UPSTREAM.md` and the changelog.
