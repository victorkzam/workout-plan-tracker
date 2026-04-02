import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {

    private let modelContainer = ModelContainerFactory.create()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
