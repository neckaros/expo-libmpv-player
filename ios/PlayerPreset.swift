import Foundation

struct PlayerPreset: Identifiable, Hashable {
    enum Identifier: String, CaseIterable { case sdrRec709, hdr10, dolbyVisionP5, dolbyVisionP8 }
    let id: Identifier
    let title: String
    let summary: String
    let commands: [[String]]
}
