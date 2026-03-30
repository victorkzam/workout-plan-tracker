import SwiftUI

struct ExerciseStepView: View {

    let step: ExecutionStep
    let timeRemaining: Int
    let currentHR: Double
    let isRunning: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                blockHeader
                exerciseTitle
                timerOrMetricRow
                metaBadges
                instructionsCard
            }
            .padding()
        }
    }

    // MARK: - Sub-views

    private var blockHeader: some View {
        HStack {
            BlockTypeBadge(blockType: step.block.blockType)
            Text(step.block.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if step.block.rounds > 1 {
                Text("Round \(step.round) of \(step.block.rounds)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var exerciseTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step.isRest ? "Rest" : step.exercise.name)
                .font(.system(size: 32, weight: .bold))
            if !step.exercise.sideNote.isEmpty {
                Text(step.exercise.sideNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timerOrMetricRow: some View {
        Group {
            if step.isTimed && !step.isGPS {
                TimerRingView(
                    timeRemaining: timeRemaining,
                    totalTime: step.durationSec,
                    isRest: step.isRest
                )
                .frame(height: 160)
            } else if step.isGPS {
                HStack {
                    Image(systemName: "location.fill").foregroundStyle(.green)
                    Text("GPS active — use full screen run view")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var metaBadges: some View {
        FlowLayout(spacing: 8) {
            if step.exercise.hasReps {
                MetaBadge(icon: "repeat", text: "\(step.exercise.reps) reps")
            }
            HRZoneTag(exercise: step.exercise, currentHR: currentHR)
            if let pace = step.exercise.paceDisplayString {
                MetaBadge(icon: "speedometer", text: pace)
            }
            if step.exercise.hasRPE {
                MetaBadge(icon: "gauge.with.dots.needle.bottom.50percent",
                          text: "RPE \(String(format: "%.0f", step.exercise.rpeTarget))/10")
            }
        }
    }

    private var instructionsCard: some View {
        Group {
            if !step.exercise.instructions.isEmpty && !step.isRest {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Instructions", systemImage: "list.bullet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(step.exercise.instructions)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: - Timer ring

struct TimerRingView: View {
    let timeRemaining: Int
    let totalTime: Int
    let isRest: Bool

    private var fraction: Double {
        totalTime > 0 ? Double(timeRemaining) / Double(totalTime) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 12)
                .foregroundStyle(isRest ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(isRest ? Color.blue : Color.green,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
            VStack(spacing: 2) {
                Text(timeString)
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                Text(isRest ? "rest" : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private var timeString: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)"
    }
}

// MARK: - Meta badge

private struct MetaBadge: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
    }
}

// MARK: - Simple flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.size.height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            for item in row {
                item.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private struct Item { let view: LayoutSubview; let size: CGSize }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Item]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Item]] = [[]]
        var rowWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if rowWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(Item(view: view, size: size))
            rowWidth += size.width + spacing
        }
        return rows
    }
}
