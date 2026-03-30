import SwiftUI

struct PaceDisplay: View {
    let currentPaceSecPerKm: Double
    let targetMin: Double           // min/km lower bound (faster)
    let targetMax: Double           // min/km upper bound (slower)

    private var currentMinPerKm: Double { currentPaceSecPerKm / 60 }

    var body: some View {
        VStack(spacing: 2) {
            Text(currentPaceString)
                .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(paceColor)
            Text("current pace")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if hasTarget {
                Text("target \(targetPaceString)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentPaceString: String {
        guard currentPaceSecPerKm > 0 else { return "--:--" }
        let m = Int(currentPaceSecPerKm) / 60
        let s = Int(currentPaceSecPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    private var targetPaceString: String {
        let lo = targetMin > 0 ? formatMinPerKm(targetMin) : nil
        let hi = targetMax > 0 ? formatMinPerKm(targetMax) : nil
        switch (lo, hi) {
        case let (l?, h?): return "\(l)–\(h)/km"
        case let (l?, nil): return "\(l)/km"
        case let (nil, h?): return "\(h)/km"
        default: return ""
        }
    }

    private var hasTarget: Bool { targetMin > 0 || targetMax > 0 }

    private var paceColor: Color {
        guard hasTarget, currentMinPerKm > 0 else { return .primary }
        if targetMin > 0 && currentMinPerKm < targetMin { return .orange }  // too fast
        if targetMax > 0 && currentMinPerKm > targetMax { return .red }     // too slow
        return .green
    }

    private func formatMinPerKm(_ m: Double) -> String {
        let total = Int(m * 60)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Compact distance display

struct DistanceDisplay: View {
    let meters: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(displayString)
                .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
            Text("distance")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var displayString: String {
        meters >= 1000
            ? String(format: "%.2f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }
}
