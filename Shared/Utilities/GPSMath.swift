import Foundation

/// Shared GPS math utilities used by both iOS LocationService and Watch WorkoutSessionManager.
enum GPSMath {

    /// Formats a pace value (seconds per kilometer) into a human-readable "M:SS /km" string.
    static func formatPace(secondsPerKm: Double) -> String {
        guard secondsPerKm > 0 else { return "--:--" }
        let m = Int(secondsPerKm) / 60
        let s = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    /// Formats a distance in meters into a human-readable string (meters or kilometers).
    static func formatDistance(meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.2f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    /// Smooths speed using a rolling average of recent speed samples.
    /// - Parameter recentSpeeds: Array of recent speed values in m/s.
    /// - Returns: The smoothed speed in m/s, or 0 if the array is empty.
    static func smoothSpeed(recentSpeeds: [Double]) -> Double {
        guard !recentSpeeds.isEmpty else { return 0 }
        return recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
    }

    /// Converts a smoothed speed (m/s) to pace (seconds per kilometer).
    /// - Parameter speedMps: Speed in meters per second.
    /// - Returns: Pace in seconds per kilometer, or 0 if speed is non-positive.
    static func paceFromSpeed(_ speedMps: Double) -> Double {
        guard speedMps > 0 else { return 0 }
        return 1000 / speedMps
    }
}
