import SwiftUI
import RocoContent

extension SkillCategory {
    var displayName: String {
        switch self {
        case .physicalAttack: "物理攻击"
        case .magicAttack: "魔法攻击"
        case .status: "变化"
        case .defense: "防御"
        case .unknown: "未分类"
        }
    }
    // Native semantic symbols; these are not claimed to be game category assets.
    var symbolName: String {
        switch self {
        case .physicalAttack: "burst.fill"
        case .magicAttack: "sparkles"
        case .status: "arrow.trianglehead.2.clockwise.rotate.90"
        case .defense: "shield.lefthalf.filled"
        case .unknown: "questionmark.circle"
        }
    }
    var tint: Color {
        switch self {
        case .physicalAttack: .orange
        case .magicAttack: .purple
        case .status: .teal
        case .defense: .blue
        case .unknown: .secondary
        }
    }
}

