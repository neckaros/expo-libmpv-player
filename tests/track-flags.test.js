const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const test = require("node:test");

const read = (path) => readFileSync(path, "utf8");

test("track flags are exposed by the TypeScript API", () => {
  const types = read("src/MpvPlayer.types.ts");

  assert.equal(types.match(/default\?: boolean;/g)?.length, 2);
  assert.equal(types.match(/forced\?: boolean;/g)?.length, 2);
  assert.equal(types.match(/hearingImpaired\?: boolean;/g)?.length, 2);
});

test("Android and iOS read the track flags from mpv", () => {
  const android = read("android/src/main/java/expo/modules/mpvplayer/MPVLayerRenderer.kt");
  const ios = read("ios/MPVLayerRenderer.swift");

  assert.match(android, /row\["default"\] = mpv\?\.getPropertyBoolean\("track-list\/\$i\/default"\)/);
  assert.match(android, /row\["forced"\] = mpv\?\.getPropertyBoolean\("track-list\/\$i\/forced"\)/);
  assert.match(android, /row\["hearingImpaired"\] = mpv\?\.getPropertyBoolean\("track-list\/\$i\/hearing-impaired"\)/);
  assert.match(ios, /"track-list\/\\\(i\)\/default", MPV_FORMAT_FLAG, &isDefault\); row\["default"\]/);
  assert.match(ios, /"track-list\/\\\(i\)\/forced", MPV_FORMAT_FLAG, &forced\); row\["forced"\]/);
  assert.match(ios, /"track-list\/\\\(i\)\/hearing-impaired", MPV_FORMAT_FLAG, &hearingImpaired\); row\["hearingImpaired"\]/);
});
