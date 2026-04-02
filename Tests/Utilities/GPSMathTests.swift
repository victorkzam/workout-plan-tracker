import XCTest
@testable import WorkoutTracker

final class GPSMathTests: XCTestCase {

    // MARK: - formatPace

    func test_formatPace_validInput_returnsFormattedString() {
        // 330 seconds/km = 5 minutes 30 seconds
        let result = GPSMath.formatPace(secondsPerKm: 330)
        XCTAssertEqual(result, "5:30 /km")
    }

    func test_formatPace_exactMinute_returnsFormattedString() {
        // 300 seconds/km = 5:00
        let result = GPSMath.formatPace(secondsPerKm: 300)
        XCTAssertEqual(result, "5:00 /km")
    }

    func test_formatPace_zeroInput_returnsDashes() {
        let result = GPSMath.formatPace(secondsPerKm: 0)
        XCTAssertEqual(result, "--:--")
    }

    func test_formatPace_negativeInput_returnsDashes() {
        let result = GPSMath.formatPace(secondsPerKm: -100)
        XCTAssertEqual(result, "--:--")
    }

    // MARK: - formatDistance

    func test_formatDistance_metersRange_formatsAsMeters() {
        let result = GPSMath.formatDistance(meters: 750)
        XCTAssertEqual(result, "750 m")
    }

    func test_formatDistance_kilometersRange_formatsAsKilometers() {
        let result = GPSMath.formatDistance(meters: 5280)
        XCTAssertEqual(result, "5.28 km")
    }

    func test_formatDistance_exactlyOneKilometer_formatsAsKilometers() {
        let result = GPSMath.formatDistance(meters: 1000)
        XCTAssertEqual(result, "1.00 km")
    }

    func test_formatDistance_belowOneKilometer_formatsAsMeters() {
        let result = GPSMath.formatDistance(meters: 999)
        XCTAssertEqual(result, "999 m")
    }

    func test_formatDistance_zero_formatsAsMeters() {
        let result = GPSMath.formatDistance(meters: 0)
        XCTAssertEqual(result, "0 m")
    }

    // MARK: - smoothSpeed

    func test_smoothSpeed_multipleValues_returnsAverage() {
        let speeds = [2.0, 4.0, 6.0]
        let result = GPSMath.smoothSpeed(recentSpeeds: speeds)
        XCTAssertEqual(result, 4.0, accuracy: 0.001)
    }

    func test_smoothSpeed_singleValue_returnsThatValue() {
        let result = GPSMath.smoothSpeed(recentSpeeds: [3.5])
        XCTAssertEqual(result, 3.5, accuracy: 0.001)
    }

    func test_smoothSpeed_emptyArray_returnsZero() {
        let result = GPSMath.smoothSpeed(recentSpeeds: [])
        XCTAssertEqual(result, 0)
    }

    // MARK: - paceFromSpeed

    func test_paceFromSpeed_validSpeed_returnsCorrectPace() {
        // 1000 m/km / 3.0 m/s = 333.33 sec/km
        let result = GPSMath.paceFromSpeed(3.0)
        XCTAssertEqual(result, 333.333, accuracy: 0.01)
    }

    func test_paceFromSpeed_zeroSpeed_returnsZero() {
        let result = GPSMath.paceFromSpeed(0)
        XCTAssertEqual(result, 0)
    }

    func test_paceFromSpeed_negativeSpeed_returnsZero() {
        let result = GPSMath.paceFromSpeed(-2.0)
        XCTAssertEqual(result, 0)
    }

    func test_paceFromSpeed_veryFast_returnsSmallPace() {
        // 10 m/s = 100 sec/km
        let result = GPSMath.paceFromSpeed(10.0)
        XCTAssertEqual(result, 100.0, accuracy: 0.01)
    }
}
