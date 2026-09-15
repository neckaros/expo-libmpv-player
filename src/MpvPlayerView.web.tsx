import * as React from "react";
import { Text, View } from "react-native";
import type { MpvPlayerViewProps } from "./MpvPlayer.types";

export default function MpvPlayerView(props: MpvPlayerViewProps) {
  return (
    <View style={props.style}>
      <Text>expo-libmpv-player is available on iOS, tvOS, and Android only.</Text>
    </View>
  );
}
