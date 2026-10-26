//
//  OsirisAppConfigTests.swift
//  Osiris
//
//  Created by Ahmed Bekhit on 1/23/26.
//

import Foundation
import OsirisBarcode
import XCTest
@testable import Osiris
@testable import OsirisCamera
import Combine

/// Test spy that records every `OsirisEvent` fired by an `OsirisScannerViewController`,
/// so tests can assert on real lifecycle events instead of hand-rolled boolean flags.
private final class RecordingScannerDelegate: OsirisScannerDelegate {
    private(set) var firedEvents: [OsirisEvent] = []
    var onEvent: ((OsirisEvent) -> Void)?

    func didTapDetectedBarcodeBoundingBox(
        _ barcode: Barcode,
        setBoundingBoxSettings: @escaping (OsirisBoundingBoxConfig) -> Void
    ) {}

    func didDetectBarcodes(
        _ barcodes: [Barcode],
        setBoundingBoxesSettings: @escaping ([BarcodeValue: OsirisBoundingBoxConfig]) -> Void
    ) {}

    func didDetectBarcode(_ barcode: Barcode) {}

    func didFireEvent(_ event: OsirisEvent) {
        firedEvents.append(event)
        onEvent?(event)
    }

    func didReceiveError(_ error: Error) {}

    func cameraIdleDetected() {}
}
class OsirisAppConfigTests: XCTestCase {
    func testConfigureStoresConfigForContext() {
        let context = OsirisDataCaptureContext(id: "testContext1")
        let config = OsirisConfig(partnerID: "partner", userID: "user")
        OsirisApp.configure(withConfig: config, context: context)
        let storedConfig = OsirisApp.shared.getConfig(forContext: context)
        XCTAssertNotNil(storedConfig)
        XCTAssertEqual(storedConfig?.partnerID, "partner")
        XCTAssertEqual(storedConfig?.userID, "user")
    }

    func testBoundingBoxDisplayCanBeConfiguredIndependentlyForEachContext() {
        let hostDrawnContext = OsirisDataCaptureContext(id: "hostDrawnBoundingBoxes")
        let sdkDrawnContext = OsirisDataCaptureContext(id: "sdkDrawnBoundingBoxes")
        defer {
            OsirisApp.shared.removeConfig(forContext: hostDrawnContext)
            OsirisApp.shared.removeConfig(forContext: sdkDrawnContext)
        }

        OsirisApp.configure(
            withConfig: OsirisConfig(enableDisplayBoundingBox: false),
            context: hostDrawnContext)
        OsirisApp.configure(withConfig: OsirisConfig(), context: sdkDrawnContext)

        XCTAssertEqual(
            OsirisApp.shared.getConfig(forContext: hostDrawnContext)?.enableDisplayBoundingBox,
            false)
        XCTAssertEqual(
            OsirisApp.shared.getConfig(forContext: sdkDrawnContext)?.enableDisplayBoundingBox,
            true)

        OsirisApp.configure(
            withConfig: OsirisConfig(enableDisplayBoundingBox: true),
            context: hostDrawnContext)

        XCTAssertEqual(
            OsirisApp.shared.getConfig(forContext: hostDrawnContext)?.enableDisplayBoundingBox,
            true)
        XCTAssertEqual(
            OsirisApp.shared.getConfig(forContext: sdkDrawnContext)?.enableDisplayBoundingBox,
            true)
    }

    func testConfigureNotifiesOnlyTheConfiguredContext() {
        let configuredContext = OsirisDataCaptureContext(id: "configuredContext")
        let otherContext = OsirisDataCaptureContext(id: "otherContext")
        let config = OsirisConfig(partnerID: "partner", userID: "user")

        let expectation = expectation(forNotification: .osirisConfigDidUpdate, object: nil) {
            notification in
            guard
                let notifiedContext = notification.userInfo?[Notification.osirisConfigContextKey]
                    as? OsirisDataCaptureContext
            else {
                return false
            }
            XCTAssertNotEqual(notifiedContext, otherContext)
            return notifiedContext == configuredContext
        }

        OsirisApp.configure(withConfig: config, context: configuredContext)

        wait(for: [expectation], timeout: 1.0)
    }

    func testConfigureOnlyNotifiesMatchingScannerContext() {
        let scannerA = OsirisDataCaptureContext(id: "scannerA")
        let scannerB = OsirisDataCaptureContext(id: "scannerB")
        var scannerARestarted = false
        var scannerBRestarted = false

        let subscriptionA = NotificationCenter.default.publisher(for: .osirisConfigDidUpdate)
            .sink { notification in
                if (notification.userInfo?[Notification.osirisConfigContextKey]
                    as? OsirisDataCaptureContext) == scannerA
                {
                    scannerARestarted = true
                }
            }
        let subscriptionB = NotificationCenter.default.publisher(for: .osirisConfigDidUpdate)
            .sink { notification in
                if (notification.userInfo?[Notification.osirisConfigContextKey]
                    as? OsirisDataCaptureContext) == scannerB
                {
                    scannerBRestarted = true
                }
            }

        OsirisApp.configure(withConfig: OsirisConfig(), context: scannerA)

        let exp = XCTestExpectation(description: "notification delivered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(scannerARestarted, "Scanner A's context matched - it should react")
        XCTAssertFalse(scannerBRestarted, "Scanner B's context didn't match - it must not react")

        subscriptionA.cancel()
        subscriptionB.cancel()
    }

    /// Regression test: a config update for one scanner context must not stop, restart, or
    /// otherwise interrupt an unrelated, actively-scanning `OsirisScannerViewController`
    /// instance. Uses two real scanner instances and real production state
    /// (`cameraIsRunning`/`scannerIsRunning`/`OsirisEvent` delegate callbacks) rather than
    /// booleans set manually inside a test-only notification subscriber.
    func testConfigureOnlyAffectsTargetedActiveScannerInstance() throws {
        let scannerA = OsirisScannerViewController(
            context: OsirisDataCaptureContext(id: "activeScannerA"))
        let scannerB = OsirisScannerViewController(
            context: OsirisDataCaptureContext(id: "activeScannerB"))

        let delegateA = RecordingScannerDelegate()
        let delegateB = RecordingScannerDelegate()
        scannerA.delegate = delegateA
        scannerB.delegate = delegateB

        // Arms each scanner's REAL `setupOsirisConfigSubscription()` — the actual production
        // notification subscriber under test, not a stand-in.
        scannerA.loadViewIfNeeded()
        scannerB.loadViewIfNeeded()

        let initialConfig = OsirisConfig(partnerID: "initial-partner", userID: "initial-user")
        OsirisApp.configure(withConfig: initialConfig, context: scannerA.context)
        OsirisApp.configure(withConfig: initialConfig, context: scannerB.context)

        waitForSubscriptionsToSettle()

        // Put both scanners into a genuinely active scanning state using real, software-only
        // production state. (CameraManager's session start routes through a permission-gated
        // serial queue that never resolves in a headless test host, so camera-level state is
        // intentionally not used here — scannerIsRunning has no such dependency.)
        try scannerA.viewModel.startScanning()
        try scannerB.viewModel.startScanning()

        XCTAssertTrue(
            scannerA.scannerIsRunning, "Precondition: scanner A must be actively scanning")
        XCTAssertTrue(
            scannerB.scannerIsRunning, "Precondition: scanner B must be actively scanning")
        XCTAssertEqual(scannerA.viewModel.config?.partnerID, "initial-partner")
        XCTAssertEqual(scannerB.viewModel.config?.partnerID, "initial-partner")

        // Reconfigure ONLY scanner A's context.
        let updatedConfig = OsirisConfig(partnerID: "updated-partner", userID: "updated-user")
        OsirisApp.configure(withConfig: updatedConfig, context: scannerA.context)

        waitForSubscriptionsToSettle()

        // Scanner A's real subscription handler must have applied the new config to itself.
        XCTAssertEqual(
            scannerA.viewModel.config?.partnerID, "updated-partner",
            "Scanner A's matching context must receive the update")

        // Scanner B — the unrelated, still-active instance — must be completely untouched:
        // still scanning, config unchanged, zero lifecycle events.
        XCTAssertTrue(
            scannerB.scannerIsRunning,
            "Unrelated scanner B's scanner must keep scanning uninterrupted")
        XCTAssertEqual(
            scannerB.viewModel.config?.partnerID, "initial-partner",
            "Unrelated scanner B's config must not change")
        XCTAssertTrue(
            delegateB.firedEvents.isEmpty,
            "Unrelated scanner B must not receive any lifecycle events for scanner A's context update"
        )

        // The config change itself must be scoped to the intended instance only.
        XCTAssertEqual(
            OsirisApp.shared.getConfig(forContext: scannerA.context)?.partnerID, "updated-partner")
        XCTAssertNotEqual(
            OsirisApp.shared.getConfig(forContext: scannerB.context)?.partnerID, "updated-partner")
    }

    private func waitForSubscriptionsToSettle() {
        let exp = XCTestExpectation(description: "config subscription handler settles")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }

    private func waitUntilCameraIsRunning(
        _ controller: OsirisScannerViewController, timeout: TimeInterval = 2.0
    ) {
        let exp = expectation(description: "camera status becomes running")
        var cancellable: AnyCancellable?
        cancellable = controller.viewModel.cameraManager.$status
            .filter { $0 == .running }
            .first()
            .sink { _ in exp.fulfill() }
        wait(for: [exp], timeout: timeout)
        cancellable?.cancel()
    }

    func testGetConfigReturnsNilForUnknownContext() {
        let unknownContext = OsirisDataCaptureContext(id: "unknown")
        let config = OsirisApp.shared.getConfig(forContext: unknownContext)
        XCTAssertNil(config)
    }

    func testRemoveConfigRemovesConfig() {
        let context = OsirisDataCaptureContext(id: "testContext2")
        let config = OsirisConfig(partnerID: "p2", userID: "u2")
        OsirisApp.configure(withConfig: config, context: context)
        let removed = OsirisApp.shared.removeConfig(forContext: context)
        XCTAssertNotNil(removed)
        XCTAssertNil(OsirisApp.shared.getConfig(forContext: context))
    }

    func testConfigureOverridesExistingConfig() {
        let context = OsirisDataCaptureContext(id: "testContext3")
        let config1 = OsirisConfig(partnerID: "p1", userID: "u1")
        let config2 = OsirisConfig(partnerID: "p2", userID: "u2")
        OsirisApp.configure(withConfig: config1, context: context)
        OsirisApp.configure(withConfig: config2, context: context)
        let storedConfig = OsirisApp.shared.getConfig(forContext: context)
        XCTAssertEqual(storedConfig?.partnerID, "p2")
        XCTAssertEqual(storedConfig?.userID, "u2")
    }

    func testOsirisConfigDefaultValues() {
        let config = OsirisConfig()
        XCTAssertEqual(config.partnerID, "")
        XCTAssertEqual(config.userID, "")
        XCTAssertNotNil(config.symbologyGroup)
        XCTAssertNotNil(config.hintGroup)
        XCTAssertNotNil(config.scanActionType)
        XCTAssertNotNil(config.reticleConfig)
        XCTAssertNotNil(config.cameraConfig)
        XCTAssertNotNil(config.feedbackConfig)
        XCTAssertNotNil(config.dynamicConfig)
        XCTAssertNotNil(config.boundingBoxConfig)
        XCTAssertTrue(config.enableDisplayBoundingBox)
        XCTAssertTrue(config.extras.isEmpty)
    }
}
