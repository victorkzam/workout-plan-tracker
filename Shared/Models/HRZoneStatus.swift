import Foundation

enum HRZoneStatus {
    case below, inZone, above, unknown

    var colorName: String {
        switch self {
        case .below:   return "cyan"
        case .inZone:  return "green"
        case .above:   return "red"
        case .unknown: return "gray"
        }
    }
}
