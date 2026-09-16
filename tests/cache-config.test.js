const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const test = require("node:test");

const read = (path) => readFileSync(path, "utf8");

test("cache pause options are exposed by the TypeScript API", () => {
  const types = read("src/MpvPlayer.types.ts");

  assert.match(types, /pause\?: boolean;/);
  assert.match(types, /pauseInitial\?: boolean;/);
  assert.match(types, /pauseWaitSeconds\?: number;/);
});

test("Android parses and applies every cache pause option", () => {
  const module = read("android/src/main/java/expo/modules/mpvplayer/MpvPlayerModule.kt");
  const config = read("android/src/main/java/expo/modules/mpvplayer/nativeplayer/engine/PlayerEngine.kt");
  const renderer = read("android/src/main/java/expo/modules/mpvplayer/MPVLayerRenderer.kt");

  assert.match(module, /cachePause = cache\?\.get\("pause"\) as\? Boolean/);
  assert.match(module, /cachePauseInitial = cache\?\.get\("pauseInitial"\) as\? Boolean/);
  assert.match(module, /cachePauseWaitSeconds = \(cache\?\.get\("pauseWaitSeconds"\) as\? Number\)\?\.toDouble\(\)/);
  assert.match(config, /val cachePause: Boolean\? = null/);
  assert.match(config, /val cachePauseInitial: Boolean\? = null/);
  assert.match(config, /val cachePauseWaitSeconds: Double\? = null/);
  assert.match(renderer, /config\.cachePause\?\.let \{ mpv\?\.setPropertyString\("cache-pause", if \(it\) "yes" else "no"\) \}/);
  assert.match(renderer, /config\.cachePauseInitial\?\.let \{ mpv\?\.setPropertyString\("cache-pause-initial", if \(it\) "yes" else "no"\) \}/);
  assert.match(renderer, /config\.cachePauseWaitSeconds\?\.let \{ mpv\?\.setPropertyString\("cache-pause-wait", it\.toString\(\)\) \}/);
});

test("iOS parses and applies every cache pause option", () => {
  const module = read("ios/MpvPlayerModule.swift");
  const config = read("ios/MpvPlayerView.swift");
  const engine = read("ios/PlayerEngine.swift");
  const renderer = read("ios/MPVLayerRenderer.swift");

  assert.match(module, /cachePause: cache\?\["pause"\] as\? Bool/);
  assert.match(module, /cachePauseInitial: cache\?\["pauseInitial"\] as\? Bool/);
  assert.match(module, /cachePauseWaitSeconds: cache\?\["pauseWaitSeconds"\] as\? Double/);
  assert.match(config, /var cachePause: Bool\?/);
  assert.match(config, /var cachePauseInitial: Bool\?/);
  assert.match(config, /var cachePauseWaitSeconds: Double\?/);
  assert.match(engine, /cachePause: config\.cachePause/);
  assert.match(engine, /cachePauseInitial: config\.cachePauseInitial/);
  assert.match(engine, /cachePauseWaitSeconds: config\.cachePauseWaitSeconds/);
  assert.match(renderer, /"cache-pause", value \? "yes" : "no"/);
  assert.match(renderer, /"cache-pause-initial", value \? "yes" : "no"/);
  assert.match(renderer, /"cache-pause-wait", String\(value\)/);
});
