import SwiftData

enum ModelContainerFactory {
    static func create() -> ModelContainer {
        let schema = Schema([
            WorkoutPlan.self,
            WorkoutSession.self,
            WorkoutBlock.self,
            Exercise.self,
            SessionExecution.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.victorkzam.WorkoutTracker")
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fallback to local-only storage if CloudKit is unavailable
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
    }
}
