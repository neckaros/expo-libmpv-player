import { NativeModule, registerWebModule } from "expo";
import type { ChangeEventPayload } from "./MpvPlayer.types";

type MpvPlayerModuleEvents = {
  onChange: (params: ChangeEventPayload) => void;
};

class MpvPlayerModule extends NativeModule<MpvPlayerModuleEvents> {
  async setValueAsync(value: string): Promise<void> {
    this.emit("onChange", { value });
  }
  hello() {
    return "libmpv is unavailable on web";
  }
  supportsAv1HardwareDecode() {
    return false;
  }
}

export default registerWebModule(MpvPlayerModule, "MpvPlayer");
