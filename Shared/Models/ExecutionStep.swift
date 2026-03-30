import Foundation

// MARK: - Execution step (flattened from Block × rounds × Exercise)

struct ExecutionStep: Identifiable {
    let id: UUID
    let exercise: Exercise
    let block: WorkoutBlock
    let round: Int           // 1-indexed
    let stepIndex: Int       // global index in the flattened array
    let isRest: Bool         // true = this is a rest between exercises in a circuit

    var durationSec: Int {
        if isRest { return block.restIntervalSec > 0 ? block.restIntervalSec : 15 }
        if block.hasIntervals { return block.workIntervalSec }
        return exercise.durationSec > 0 ? exercise.durationSec : 0
    }

    var isTimed: Bool { durationSec > 0 }
    var isGPS: Bool { exercise.exerciseType.requiresGPS && !isRest }

    // MARK: - Step flattening

    static func flattenSteps(session: WorkoutSession) -> [ExecutionStep] {
        var steps: [ExecutionStep] = []
        var globalIndex = 0

        let sortedBlocks = session.blocks.sorted { $0.sortOrder < $1.sortOrder }
        for block in sortedBlocks {
            let sortedExercises = block.exercises.sorted { $0.sortOrder < $1.sortOrder }
            for round in 1...max(1, block.rounds) {
                for (exerciseIdx, exercise) in sortedExercises.enumerated() {
                    steps.append(ExecutionStep(
                        id: UUID(),
                        exercise: exercise,
                        block: block,
                        round: round,
                        stepIndex: globalIndex,
                        isRest: false
                    ))
                    globalIndex += 1

                    let isLastExercise = exerciseIdx == sortedExercises.count - 1
                    if block.hasIntervals && !isLastExercise {
                        let restExercise = Exercise(
                            name: "Rest",
                            instructions: "Active recovery — breathe, shake out your limbs.",
                            exerciseType: .timed,
                            durationSec: block.restIntervalSec,
                            sortOrder: -1
                        )
                        steps.append(ExecutionStep(
                            id: UUID(),
                            exercise: restExercise,
                            block: block,
                            round: round,
                            stepIndex: globalIndex,
                            isRest: true
                        ))
                        globalIndex += 1
                    }
                }
            }
        }
        return steps
    }
}
