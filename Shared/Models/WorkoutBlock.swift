import Foundation
import SwiftData

enum BlockType: String, Codable, CaseIterable {
    case warmup   = "warmup"
    case run      = "run"
    case cycle    = "cycle"
    case circuit  = "circuit"
    case posture  = "posture"
    case core     = "core"
    case stretch  = "stretch"
    case cooldown = "cooldown"

    var displayName: String {
        switch self {
        case .warmup:   return "Warm-Up"
        case .run:      return "Run"
        case .cycle:    return "Cycle"
        case .circuit:  return "Circuit"
        case .posture:  return "Posture"
        case .core:     return "Core"
        case .stretch:  return "Stretch"
        case .cooldown: return "Cool-Down"
        }
    }

    var accentColor: String {
        switch self {
        case .warmup:   return "orange"
        case .run:      return "green"
        case .cycle:    return "cyan"
        case .circuit:  return "red"
        case .posture:  return "purple"
        case .core:     return "indigo"
        case .stretch:  return "teal"
        case .cooldown: return "blue"
        }
    }

    var isGPS: Bool { self == .run || self == .cycle }
}

@Model
final class WorkoutBlock {
    var id: UUID = UUID()
    var name: String = ""
    var blockTypeRaw: String = BlockType.circuit.rawValue
    var rounds: Int = 1
    var workIntervalSec: Int = 0       // 0 = not applicable
    var restIntervalSec: Int = 0       // 0 = not applicable
    var sortOrder: Int = 0

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise]?

    var blockType: BlockType {
        get { BlockType(rawValue: blockTypeRaw) ?? .circuit }
        set { blockTypeRaw = newValue.rawValue }
    }

    var hasIntervals: Bool { workIntervalSec > 0 }
    var isGPS: Bool { blockType.isGPS }

    init(name: String, blockType: BlockType, rounds: Int = 1,
         workIntervalSec: Int = 0, restIntervalSec: Int = 0, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.blockTypeRaw = blockType.rawValue
        self.rounds = rounds
        self.workIntervalSec = workIntervalSec
        self.restIntervalSec = restIntervalSec
        self.sortOrder = sortOrder
        self.exercises = []
    }
}
