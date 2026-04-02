import Foundation
import CoreLocation

/// Protocol abstracting location tracking for testability.
@MainActor
protocol LocationServiceProtocol: AnyObject, Observable {
    var route: [CLLocation] { get }
    var totalDistanceMeters: Double { get }
    var currentPaceSecPerKm: Double { get }
    var elapsedSeconds: Double { get }

    var paceDisplayString: String { get }
    var distanceDisplayString: String { get }
    var avgPaceSecPerKm: Double { get }

    func start()
    func stop()
    func pause()
    func resume()
}
