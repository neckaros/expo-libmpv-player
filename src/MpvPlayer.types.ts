import type { StyleProp, ViewStyle } from "react-native";

export type OnLoadEventPayload = { url: string };
export type OnPlaybackStateChangePayload = {
  isPaused?: boolean;
  isPlaying?: boolean;
  isLoading?: boolean;
  isReadyToSeek?: boolean;
};
export type OnProgressEventPayload = {
  position: number;
  duration: number;
  progress: number;
  /** Seconds of video buffered ahead of current position. */
  cacheSeconds: number;
};
export type OnErrorEventPayload = { error: string };
export type OnTracksReadyEventPayload = Record<string, never>;
export type OnPictureInPictureChangePayload = { isActive: boolean };
export type OnEndEventPayload = Record<string, never>;

export type NowPlayingMetadata = {
  title?: string;
  artist?: string;
  albumTitle?: string;
  artworkUri?: string;
  artworkHeaders?: Record<string, string>;
};

export type MpvPlayerModuleEvents = {
  onChange: (params: ChangeEventPayload) => void;
  onNativeLog: (params: NativeLogEventPayload) => void;
};
export type ChangeEventPayload = { value: string };
export type NativeLogEventPayload = { message: string; type: string };

export type VideoSource = {
  url: string;
  headers?: Record<string, string>;
  externalSubtitles?: string[];
  startPosition?: number;
  autoplay?: boolean;
  loop?: boolean;
  initialSubtitleId?: number;
  initialAudioId?: number;
  cacheConfig?: {
    enabled?: "auto" | "yes" | "no";
    cacheSeconds?: number;
    maxBytes?: number;
    maxBackBytes?: number;
    pause?: boolean;
    pauseInitial?: boolean;
    pauseWaitSeconds?: number;
  };
  /** MPV video output driver (Android only). */
  voDriver?: "gpu-next" | "gpu";
};

export type MpvPlayerViewProps = {
  source?: VideoSource;
  style?: StyleProp<ViewStyle>;
  nowPlayingMetadata?: NowPlayingMetadata;
  onLoad?: (event: { nativeEvent: OnLoadEventPayload }) => void;
  onPlaybackStateChange?: (event: { nativeEvent: OnPlaybackStateChangePayload }) => void;
  onProgress?: (event: { nativeEvent: OnProgressEventPayload }) => void;
  onError?: (event: { nativeEvent: OnErrorEventPayload }) => void;
  onTracksReady?: (event: { nativeEvent: OnTracksReadyEventPayload }) => void;
  onPictureInPictureChange?: (event: { nativeEvent: OnPictureInPictureChangePayload }) => void;
  /** Fired only when playback reaches a genuine end-of-file, not on stop/reload. */
  onEnd?: (event: { nativeEvent: OnEndEventPayload }) => void;
};

export interface SubtitleStyleConfig {
  fontSize?: number;
  color?: string;
  font?: string;
  background?: string;
  backgroundPadding?: number;
}

export interface MpvPlayerViewRef {
  play: () => Promise<void>;
  pause: () => Promise<void>;
  destroy: () => Promise<void>;
  seekTo: (position: number) => Promise<void>;
  seekBy: (offset: number) => Promise<void>;
  setSpeed: (speed: number) => Promise<void>;
  getSpeed: () => Promise<number>;
  setMute: (muted: boolean) => Promise<void>;
  isPaused: () => Promise<boolean>;
  getCurrentPosition: () => Promise<number>;
  getDuration: () => Promise<number>;
  startPictureInPicture: () => Promise<void>;
  stopPictureInPicture: () => Promise<void>;
  isPictureInPictureSupported: () => Promise<boolean>;
  isPictureInPictureActive: () => Promise<boolean>;
  getSubtitleTracks: () => Promise<SubtitleTrack[]>;
  setSubtitleTrack: (trackId: number) => Promise<void>;
  disableSubtitles: () => Promise<void>;
  getCurrentSubtitleTrack: () => Promise<number>;
  addSubtitleFile: (url: string, select?: boolean) => Promise<void>;
  setSubtitlePosition: (position: number) => Promise<void>;
  setSubtitleScale: (scale: number) => Promise<void>;
  setSubtitleDelay: (seconds: number) => Promise<void>;
  setSubtitleMarginY: (margin: number) => Promise<void>;
  setSubtitleAlignX: (alignment: "left" | "center" | "right") => Promise<void>;
  setSubtitleAlignY: (alignment: "top" | "center" | "bottom") => Promise<void>;
  setSubtitleStyle: (style: SubtitleStyleConfig) => Promise<void>;
  setSubtitleFontSize: (size: number) => Promise<void>;
  setSubtitleBackgroundColor: (color: string) => Promise<void>;
  setSubtitleBorderStyle: (style: "outline-and-shadow" | "background-box") => Promise<void>;
  setSubtitleAssOverride: (mode: "no" | "force") => Promise<void>;
  getAudioTracks: () => Promise<AudioTrack[]>;
  setAudioTrack: (trackId: number) => Promise<void>;
  getCurrentAudioTrack: () => Promise<number>;
  setAudioDelay: (seconds: number) => Promise<void>;
  /** Soft-volume percentage. 100 = neutral; values above 100 boost volume. */
  setVolumeBoost: (percent: number) => Promise<void>;
  /** Enables a speech-presence EQ without replacing mpv's other audio filters. */
  setDialogueBoost: (enabled: boolean) => Promise<void>;
  setMonoDownmix: (enabled: boolean) => Promise<void>;
  setZoomedToFill: (zoomed: boolean) => Promise<void>;
  isZoomedToFill: () => Promise<boolean>;
  getTechnicalInfo: () => Promise<TechnicalInfo>;
}

export type SubtitleTrack = {
  id: number;
  title?: string;
  lang?: string;
  codec?: string;
  external?: boolean;
  externalFilename?: string;
  ffIndex?: number;
  selected?: boolean;
};

export type AudioTrack = {
  id: number;
  title?: string;
  lang?: string;
  codec?: string;
  channels?: number;
  selected?: boolean;
};

export type TechnicalInfo = {
  videoWidth?: number;
  videoHeight?: number;
  videoCodec?: string;
  audioCodec?: string;
  fps?: number;
  videoBitrate?: number;
  audioBitrate?: number;
  cacheSeconds?: number;
  demuxerMaxBytes?: number;
  demuxerMaxBackBytes?: number;
  cacheSecsLimit?: number;
  droppedFrames?: number;
  voDriver?: string;
  hwdec?: string;
  estimatedVfFps?: number;
  hdrFormat?: string;
  colorSpace?: string;
  colorRange?: string;
  colorTransfer?: string;
  decoderType?: string;
  decoderName?: string;
  audioChannels?: number;
  audioSampleRate?: number;
  videoCodecs?: string;
  /** Raw mpv color metadata returned by Android. */
  gamma?: string;
  primaries?: string;
  colormatrix?: string;
  colorlevels?: string;
  pixelformat?: string;
};
