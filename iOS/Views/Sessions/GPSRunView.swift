import SwiftUI
import MapKit
import CoreLocation

struct GPSRunView: View {

    let exercise: Exercise
    let locationService: LocationService
    let healthKitService: HealthKitService
    var onEnd: () -> Void

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var polylineCoords: [CLLocationCoordinate2D] = []
    @State private var isPaused = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mapView
            metricsOverlay
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: locationService.route.count) { _, _ in
            updatePolyline()
        }
        .task {
            await healthKitService.requestAuthorization()
            let activity: HKWorkoutActivityType = exercise.exerciseType == .gpsCycle
                ? .cycling : .running
            await healthKitService.startWorkoutSession(activityType: activity)
        }
        .onDisappear {
            Task { await healthKitService.stopWorkoutSession() }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            if polylineCoords.count > 1 {
                MapPolyline(coordinates: polylineCoords)
                    .stroke(.green, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    // MARK: - Metrics overlay

    private var metricsOverlay: some View {
        VStack(spacing: 0) {
            // Target info bar
            if exercise.hasPaceTarget || exercise.hasHRZone {
                targetBar
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // Main metrics grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(title: "Pace", icon: "speedometer") {
                    PaceDisplay(
                        currentPaceSecPerKm: locationService.currentPaceSecPerKm,
                        targetMin: exercise.paceMinPerKmMin,
                        targetMax: exercise.paceMinPerKmMax
                    )
                }
                MetricCard(title: "Distance", icon: "location.fill") {
                    DistanceDisplay(meters: locationService.totalDistanceMeters)
                }
                MetricCard(title: "Time", icon: "clock") {
                    Text(elapsedString)
                        .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                }
                MetricCard(title: "Heart Rate", icon: "heart.fill") {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(hrString)
                            .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(hrColor)
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            // Controls
            HStack(spacing: 20) {
                Button {
                    isPaused.toggle()
                    isPaused ? locationService.pause() : locationService.resume()
                } label: {
                    Label(isPaused ? "Resume" : "Pause",
                          systemImage: isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.yellow)

                Button {
                    locationService.stop()
                    onEnd()
                } label: {
                    Label("End Run", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var targetBar: some View {
        HStack {
            if let pace = exercise.paceDisplayString {
                Label("Target: \(pace)", systemImage: "speedometer")
            }
            Spacer()
            HRZoneTag(exercise: exercise,
                      currentHR: healthKitService.currentHeartRate)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func updatePolyline() {
        polylineCoords = locationService.route.map { $0.coordinate }
    }

    private var elapsedString: String {
        let t = Int(locationService.elapsedSeconds)
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private var hrString: String {
        healthKitService.currentHeartRate > 0
            ? String(Int(healthKitService.currentHeartRate))
            : "--"
    }

    private var hrColor: Color {
        let status = healthKitService.hrZoneStatus(exercise: exercise)
        switch status {
        case .inZone:  return .green
        case .above:   return .red
        case .below:   return .cyan
        case .unknown: return .primary
        }
    }
}

// MARK: - Metric card

private struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - HKWorkoutActivityType import shim

import HealthKit
