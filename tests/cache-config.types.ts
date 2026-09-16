import type { VideoSource } from "../index";

const source = {
  url: "https://example.com/video.mkv",
  cacheConfig: {
    enabled: "yes",
    cacheSeconds: 30,
    maxBytes: 200,
    maxBackBytes: 10,
    pause: true,
    pauseInitial: true,
    pauseWaitSeconds: 5,
  },
} satisfies VideoSource;

void source;
