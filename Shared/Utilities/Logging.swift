import os

extension Logger {
    static let healthKit = Logger(subsystem: "com.victorkzam.WorkoutTracker", category: "HealthKit")
    static let location = Logger(subsystem: "com.victorkzam.WorkoutTracker", category: "Location")
    static let parser = Logger(subsystem: "com.victorkzam.WorkoutTracker", category: "Parser")
    static let connectivity = Logger(subsystem: "com.victorkzam.WorkoutTracker", category: "Connectivity")
    static let workout = Logger(subsystem: "com.victorkzam.WorkoutTracker", category: "Workout")
}
