import SwiftUI

struct HRZoneTag: View {
    let exercise: Exercise
    var currentHR: Double = 0

    var body: some View {
        guard exercise.hasHRZone else { return AnyView(EmptyView()) }

        let status = hrStatus
        return AnyView(
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                Text(hrLabel)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(statusColor(status).opacity(0.12))
            .clipShape(Capsule())
        )
    }

    private var hrLabel: String {
        let zone = exercise.hrZoneName.isEmpty ? "" : "\(exercise.hrZoneName) · "
        let range = "\(exercise.hrZoneMin)–\(exercise.hrZoneMax) bpm"
        return zone + range
    }

    private var hrStatus: HRZoneStatus {
        guard currentHR > 0 else { return .unknown }
        if currentHR < Double(exercise.hrZoneMin) { return .below }
        if currentHR > Double(exercise.hrZoneMax) { return .above }
        return .inZone
    }

    private func statusColor(_ status: HRZoneStatus) -> Color {
        switch status {
        case .below:   return .cyan
        case .inZone:  return .green
        case .above:   return .red
        case .unknown: return .secondary
        }
    }
}

// MARK: - Block type badge

struct BlockTypeBadge: View {
    let blockType: BlockType

    var body: some View {
        Image(systemName: iconName)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var iconName: String {
        switch blockType {
        case .warmup:   return "thermometer.sun"
        case .run:      return "figure.run"
        case .cycle:    return "figure.outdoor.cycle"
        case .circuit:  return "dumbbell"
        case .posture:  return "figure.stand"
        case .core:     return "figure.core.training"
        case .stretch:  return "figure.flexibility"
        case .cooldown: return "snowflake"
        }
    }

    private var badgeColor: Color {
        switch blockType {
        case .warmup:   return .orange
        case .run:      return .green
        case .cycle:    return .cyan
        case .circuit:  return .red
        case .posture:  return .purple
        case .core:     return .indigo
        case .stretch:  return .teal
        case .cooldown: return .blue
        }
    }
}
