import { requireNativeView } from "expo";
import * as React from "react";
import { useImperativeHandle, useRef } from "react";

import type {
  MpvPlayerViewProps,
  MpvPlayerViewRef,
  SubtitleStyleConfig,
} from "./MpvPlayer.types";

const NativeView: React.ComponentType<MpvPlayerViewProps & { ref?: any }> =
  requireNativeView("MpvPlayer");

export default React.forwardRef<MpvPlayerViewRef, MpvPlayerViewProps>(
  function MpvPlayerView(props, ref) {
    const nativeRef = useRef<any>(null);

    useImperativeHandle(ref, () => ({
      play: async () => nativeRef.current?.play(),
      pause: async () => nativeRef.current?.pause(),
      destroy: async () => nativeRef.current?.destroy(),
      seekTo: async (position: number) => nativeRef.current?.seekTo(position),
      seekBy: async (offset: number) => nativeRef.current?.seekBy(offset),
      setSpeed: async (speed: number) => nativeRef.current?.setSpeed(speed),
      getSpeed: async () => nativeRef.current?.getSpeed(),
      setMute: async (muted: boolean) => nativeRef.current?.setMute(muted),
      isPaused: async () => nativeRef.current?.isPaused(),
      getCurrentPosition: async () => nativeRef.current?.getCurrentPosition(),
      getDuration: async () => nativeRef.current?.getDuration(),
      startPictureInPicture: async () => nativeRef.current?.startPictureInPicture(),
      stopPictureInPicture: async () => nativeRef.current?.stopPictureInPicture(),
      isPictureInPictureSupported: async () => nativeRef.current?.isPictureInPictureSupported(),
      isPictureInPictureActive: async () => nativeRef.current?.isPictureInPictureActive(),
      getSubtitleTracks: async () => nativeRef.current?.getSubtitleTracks(),
      setSubtitleTrack: async (trackId: number) => nativeRef.current?.setSubtitleTrack(trackId),
      disableSubtitles: async () => nativeRef.current?.disableSubtitles(),
      getCurrentSubtitleTrack: async () => nativeRef.current?.getCurrentSubtitleTrack(),
      addSubtitleFile: async (url: string, select = true) => nativeRef.current?.addSubtitleFile(url, select),
      setSubtitlePosition: async (position: number) => nativeRef.current?.setSubtitlePosition(position),
      setSubtitleScale: async (scale: number) => nativeRef.current?.setSubtitleScale(scale),
      setSubtitleDelay: async (seconds: number) => nativeRef.current?.setSubtitleDelay(seconds),
      setSubtitleMarginY: async (margin: number) => nativeRef.current?.setSubtitleMarginY(margin),
      setSubtitleAlignX: async (alignment: "left" | "center" | "right") => nativeRef.current?.setSubtitleAlignX(alignment),
      setSubtitleAlignY: async (alignment: "top" | "center" | "bottom") => nativeRef.current?.setSubtitleAlignY(alignment),
      setSubtitleFontSize: async (size: number) => nativeRef.current?.setSubtitleFontSize(size),
      setSubtitleStyle: async (style: SubtitleStyleConfig) => nativeRef.current?.setSubtitleStyle(style),
      setSubtitleBackgroundColor: async (color: string) => nativeRef.current?.setSubtitleBackgroundColor(color),
      setSubtitleBorderStyle: async (style: "outline-and-shadow" | "background-box") => nativeRef.current?.setSubtitleBorderStyle(style),
      setSubtitleAssOverride: async (mode: "no" | "force") => nativeRef.current?.setSubtitleAssOverride(mode),
      getAudioTracks: async () => nativeRef.current?.getAudioTracks(),
      setAudioTrack: async (trackId: number) => nativeRef.current?.setAudioTrack(trackId),
      getCurrentAudioTrack: async () => nativeRef.current?.getCurrentAudioTrack(),
      setZoomedToFill: async (zoomed: boolean) => nativeRef.current?.setZoomedToFill(zoomed),
      isZoomedToFill: async () => nativeRef.current?.isZoomedToFill(),
      getTechnicalInfo: async () => nativeRef.current?.getTechnicalInfo(),
    }));

    return <NativeView ref={nativeRef} {...props} />;
  },
);
