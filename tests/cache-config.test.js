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

test("Android parses cache pause options and resets omissions to renderer defaults", () => {
  const module = read("android/src/main/java/expo/modules/mpvplayer/MpvPlayerModule.kt");
  const config = read("android/src/main/java/expo/modules/mpvplayer/nativeplayer/engine/PlayerEngine.kt");
  const renderer = read("android/src/main/java/expo/modules/mpvplayer/MPVLayerRenderer.kt");

  assert.match(module, /cachePause = cache\?\.get\("pause"\) as\? Boolean/);
  assert.match(module, /cachePauseInitial = cache\?\.get\("pauseInitial"\) as\? Boolean/);
  assert.match(module, /cachePauseWaitSeconds = \(cache\?\.get\("pauseWaitSeconds"\) as\? Number\)\?\.toDouble\(\)/);
  assert.match(config, /val cachePause: Boolean\? = null/);
  assert.match(config, /val cachePauseInitial: Boolean\? = null/);
  assert.match(config, /val cachePauseWaitSeconds: Double\? = null/);
  assert.match(renderer, /DEFAULT_CACHE_PAUSE = true/);
  assert.match(renderer, /DEFAULT_CACHE_PAUSE_INITIAL = true/);
  assert.match(renderer, /DEFAULT_CACHE_PAUSE_WAIT_SECONDS = 1\.0/);
  assert.match(renderer, /"cache-pause", if \(config\.cachePause \?: DEFAULT_CACHE_PAUSE\) "yes" else "no"/);
  assert.match(renderer, /"cache-pause-initial", if \(config\.cachePauseInitial \?: DEFAULT_CACHE_PAUSE_INITIAL\) "yes" else "no"/);
  assert.match(renderer, /"cache-pause-wait", \(config\.cachePauseWaitSeconds \?: DEFAULT_CACHE_PAUSE_WAIT_SECONDS\)\.toString\(\)/);
});

test("iOS parses cache pause options and resets omissions to mpv defaults", () => {
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
  assert.match(renderer, /defaultCachePause = true/);
  assert.match(renderer, /defaultCachePauseInitial = false/);
  assert.match(renderer, /defaultCachePauseWaitSeconds = 1\.0/);
  assert.match(renderer, /"cache-pause", \(cachePause \?\? Self\.defaultCachePause\) \? "yes" : "no"/);
  assert.match(renderer, /"cache-pause-initial", \(cachePauseInitial \?\? Self\.defaultCachePauseInitial\) \? "yes" : "no"/);
  assert.match(renderer, /"cache-pause-wait", String\(cachePauseWaitSeconds \?\? Self\.defaultCachePauseWaitSeconds\)/);
});
