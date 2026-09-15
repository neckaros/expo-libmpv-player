const {
  withAndroidManifest,
  withGradleProperties,
  withInfoPlist,
  withPodfile,
} = require("expo/config-plugins");

const DEFAULT_MPVKIT_PODSPEC =
  "https://raw.githubusercontent.com/streamyfin/MPVKit/0.41.0-av5/MPVKit.podspec";

// dev.jdtech.mpv:libmpv:1.0.0 is built against a newer libc++; Expo's
// older default NDK can crash at load time on __from_chars_floating_point.
const DEFAULT_ANDROID_NDK_VERSION = "29.0.14206865";

function withMpvKitPod(config, options = {}) {
  const podspecUrl = options.mpvKitPodspecUrl || options.podspecUrl || DEFAULT_MPVKIT_PODSPEC;
  return withPodfile(config, (mod) => {
    const podName = options.mpvKitPodName || options.podName || "MPVKit";
    const podLine = `  pod '${podName}', :podspec => '${podspecUrl}'`;
    const escapedName = podName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const existingPod = new RegExp(
      `^[ \\t]*pod ['\"]${escapedName}['\"].*$\\n?`,
      "gm",
    );
    const contents = mod.modResults.contents.replace(existingPod, "");

    if (!contents.includes("use_expo_modules!")) {
      throw new Error(
        "expo-libmpv-player: could not find use_expo_modules! in the iOS Podfile",
      );
    }

    mod.modResults.contents = contents.replace(
      "use_expo_modules!",
      `use_expo_modules!\n${podLine}`,
    );
    return mod;
  });
}

function withAndroidNdk(config, options = {}) {
  const ndkVersion = options.androidNdkVersion || DEFAULT_ANDROID_NDK_VERSION;
  return withGradleProperties(config, (mod) => {
    const props = mod.modResults;
    const index = props.findIndex(
      (item) => item.type === "property" && item.key === "ndkVersion",
    );
    const property = { type: "property", key: "ndkVersion", value: ndkVersion };
    if (index >= 0) props.splice(index, 1, property);
    else props.push(property);
    return mod;
  });
}

function withIosBackgroundAudio(config, options = {}) {
  if (options.enablePictureInPicture === false) return config;
  return withInfoPlist(config, (mod) => {
    const modes = Array.isArray(mod.modResults.UIBackgroundModes)
      ? [...mod.modResults.UIBackgroundModes]
      : [];
    if (!modes.includes("audio")) modes.push("audio");
    mod.modResults.UIBackgroundModes = modes;
    return mod;
  });
}

function withAndroidPip(config, options = {}) {
  if (options.enablePictureInPicture === false) return config;
  return withAndroidManifest(config, (mod) => {
    const application = mod.modResults.manifest.application?.[0];
    if (!application) return mod;
    if (!application.activity) application.activity = [];

    const mainActivity = application.activity.find((activity) => {
      const name = activity.$?.["android:name"];
      return name === ".MainActivity" || name?.endsWith(".MainActivity");
    });

    if (mainActivity?.$) {
      mainActivity.$["android:supportsPictureInPicture"] = "true";
    }
    return mod;
  });
}

module.exports = function withLibmpv(config, options = {}) {
  config = withAndroidNdk(config, options);
  config = withMpvKitPod(config, options);
  config = withIosBackgroundAudio(config, options);
  config = withAndroidPip(config, options);
  return config;
};

module.exports.DEFAULT_MPVKIT_PODSPEC = DEFAULT_MPVKIT_PODSPEC;
module.exports.DEFAULT_ANDROID_NDK_VERSION = DEFAULT_ANDROID_NDK_VERSION;
