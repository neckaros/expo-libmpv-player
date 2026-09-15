import { NativeModule, requireNativeModule } from "expo";
import type { MpvPlayerModuleEvents } from "./MpvPlayer.types";

declare class MpvPlayerModule extends NativeModule<MpvPlayerModuleEvents> {
  hello(): string;
  setValueAsync(value: string): Promise<void>;
  /** Whether the platform reports a hardware AV1 decoder (VideoToolbox on Apple, MediaCodec on Android). */
  supportsAv1HardwareDecode(): boolean;
}

export default requireNativeModule<MpvPlayerModule>("MpvPlayer");
