import XCTest
import Vision
import CoreVideo
@testable import Nether

// MARK: - Mock

final class MockPoseDetector: PoseDetectorProtocol {
    var stubbedObservations: [VNHumanBodyPoseObservation] = []
    var stubbedError: Error?

    func detectPose(
        in buffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<[VNHumanBodyPoseObservation], Error>) -> Void
    ) {
        if let error = stubbedError {
            completion(.failure(error))
        } else {
            completion(.success(stubbedObservations))
        }
    }
}

// MARK: - Helpers

/// Creates a minimal 1×1 CVPixelBuffer suitable for passing to processFrame in tests.
private func makePixelBuffer() -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        1, 1,
        kCVPixelFormatType_32BGRA,
        nil,
        &buffer
    )
    return buffer!
}

// MARK: - Tests

final class DetectionManagerTests: XCTestCase {

    // MARK: No detections → isHumanDetected stays false

    func testNoObservations_humanNotDetected() {
        let mock = MockPoseDetector()
        mock.stubbedObservations = []          // empty — no pose found

        let manager = DetectionManager(poseDetector: mock)
        let buffer = makePixelBuffer()

        let expectation = XCTestExpectation(description: "isHumanDetected updated")

        // Observe the published property
        var cancellable: Any?
        cancellable = manager.$isHumanDetected.dropFirst().sink { detected in
            XCTAssertFalse(detected, "Should not detect a human when no observations are returned")
            expectation.fulfill()
        }

        manager.processFrame(buffer, orientation: .up)

        wait(for: [expectation], timeout: 1.0)
        _ = cancellable  // retain until done
    }

    // MARK: Detection error → isHumanDetected stays false

    func testDetectionError_humanNotDetected() {
        let mock = MockPoseDetector()
        mock.stubbedError = NSError(
            domain: "MockPoseDetector",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Simulated detection failure"]
        )

        let manager = DetectionManager(poseDetector: mock)
        let buffer = makePixelBuffer()

        // processFrame logs the error and does NOT update isHumanDetected on the main queue.
        // Give it a moment and assert the default value is unchanged.
        manager.processFrame(buffer, orientation: .up)

        let deadline = DispatchTime.now() + .milliseconds(200)
        let sema = DispatchSemaphore(value: 0)
        DispatchQueue.main.asyncAfter(deadline: deadline) { sema.signal() }
        sema.wait()

        XCTAssertFalse(
            manager.isHumanDetected,
            "isHumanDetected should remain false when detection throws an error"
        )
    }

    // MARK: Default detection zone shape

    func testDefaultDetectionZone_isNarrowVerticalStrip() {
        let manager = DetectionManager(poseDetector: MockPoseDetector())
        let zone = manager.detectionZone

        // The default zone is a narrow vertical strip in the center
        XCTAssertEqual(zone.width, 0.16, accuracy: 0.001)
        XCTAssertEqual(zone.height, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(zone.minX, 0.3)
        XCTAssertLessThan(zone.maxX, 0.7)
    }
}
