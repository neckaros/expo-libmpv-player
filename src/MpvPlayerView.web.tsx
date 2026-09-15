import * as React from "react";
import { Text, View } from "react-native";
import type { MpvPlayerViewProps, MpvPlayerViewRef, TechnicalInfo } from "./MpvPlayer.types";

const unsupported = () => Promise.resolve();

export default React.forwardRef<MpvPlayerViewRef, MpvPlayerViewProps>(function MpvPlayerView(props, ref) {
  React.useImperativeHandle(ref, () => ({
    play: unsupported,
    pause: unsupported,
    destroy: unsupported,
    seekTo: async () => {},
    seekBy: async () => {},
    setSpeed: async () => {},
    getSpeed: async () => 1,
    setMute: async () => {},
    isPaused: async () => true,
    getCurrentPosition: async () => 0,
    getDuration: async () => 0,
    startPictureInPicture: unsupported,
    stopPictureInPicture: unsupported,
    isPictureInPictureSupported: async () => false,
    isPictureInPictureActive: async () => false,
    getSubtitleTracks: async () => [],
    setSubtitleTrack: async () => {},
    disableSubtitles: unsupported,
    getCurrentSubtitleTrack: async () => 0,
    addSubtitleFile: async () => {},
    setSubtitlePosition: async () => {},
    setSubtitleScale: async () => {},
    setSubtitleDelay: async () => {},
    setSubtitleMarginY: async () => {},
    setSubtitleAlignX: async () => {},
    setSubtitleAlignY: async () => {},
    setSubtitleStyle: async () => {},
    setSubtitleFontSize: async () => {},
    setSubtitleBackgroundColor: async () => {},
    setSubtitleBorderStyle: async () => {},
    setSubtitleAssOverride: async () => {},
    getAudioTracks: async () => [],
    setAudioTrack: async () => {},
    getCurrentAudioTrack: async () => 0,
    setAudioDelay: async () => {},
    setVolumeBoost: async () => {},
    setDialogueBoost: async () => {},
    setMonoDownmix: async () => {},
    setZoomedToFill: async () => {},
    isZoomedToFill: async () => false,
    getTechnicalInfo: async (): Promise<TechnicalInfo> => ({}),
  }));

  return (
    <View style={props.style}>
      <Text>expo-libmpv-player is available on iOS, tvOS, and Android only.</Text>
    </View>
  );
});
