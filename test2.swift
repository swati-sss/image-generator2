import CoreImage
import CoreVideo
import Osiris
@testable import OsirisBarcode
import XCTest
import ZXingCpp

final class BarcodeGeometryTests: XCTestCase {
    func testCropTransformUsesOffCenterPreviewOriginWithoutScalingItAgain() {
        let decoder = makeDecoder(imageSize: CGSize(width: 640, height: 480),
                                  previewSize: CGSize(width: 320, height: 240))

        let result = decoder.transformRect(originalBounds: CGRect(x: 10, y: 20, width: 40, height: 30),
                                           from: decoder.pixelBufferSize,import XCTest
import UIKit
import Osiris
import OsirisBarcode
@testable import OsirisCamera

final class HostDrawnBoundingBoxTests: XCTestCase {
    @MainActor
    func testDisablingRenderingRemovesExistingBoxAndDecorationsWithoutHidingFocusView() throws {
        let overlay = BarcodeBoundingBoxes(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let box = makeBox(rect: CGRect(x: 20, y: 40, width: 100, height: 50))
        let icon = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let style = OsirisBoundingBoxConfig(
            centerIconImage: icon,
            titleBox: .init(title: "Product", titleColor: .white))

        overlay.updateBarcodes([box], customSettings: [box.barcode.value: style])

        XCTAssertTrue(overlay.isRenderingEnabled)
        let shape = try XCTUnwrap(shapeLayers(in: overlay).first)
        XCTAssertEqual(shape.sublayers?.count, 2, "Precondition: both a title and icon are drawn")
        let focusGesture = try XCTUnwrap(overlay.gestureRecognizers?.first)
        overlay.foundBarcodeBox = box
        overlay.foundBox = box.boundingBox

        overlay.isRenderingEnabled = false

        XCTAssertTrue(shapeLayers(in: overlay).isEmpty)
        XCTAssertNil(shape.superlayer, "Removing the parent removes its title and icon from display")
        XCTAssertNil(overlay.foundBarcodeBox)
        XCTAssertEqual(overlay.foundBox, .zero)
        XCTAssertFalse(overlay.isHidden)
        XCTAssertTrue(overlay.isUserInteractionEnabled)
        XCTAssertTrue(overlay.gestureRecognizers?.contains(where: { $0 === focusGesture }) == true)
        XCTAssertTrue(focusGesture.isEnabled)
    }

    @MainActor
    func testReenablingRenderingDrawsLatestGeometryReceivedWhileDisabled() throws {
        let overlay = BarcodeBoundingBoxes(frame: .zero)
        let initial = makeBox(rect: CGRect(x: 10, y: 20, width: 30, height: 40))
        let latest = makeBox(rect: CGRect(x: 90, y: 120, width: 50, height: 60))

        overlay.updateBarcodes([initial], customSettings: [:])
        overlay.isRenderingEnabled = false
        overlay.updateBarcodes([latest], customSettings: [:])
        XCTAssertTrue(shapeLayers(in: overlay).isEmpty)

        overlay.isRenderingEnabled = true

        let layers = shapeLayers(in: overlay)
        XCTAssertEqual(layers.count, 1)
        let shape = try XCTUnwrap(layers.first)
        XCTAssertEqual(shape.name, latest.barcode.value)
        XCTAssertEqual(shape.path?.boundingBoxOfPath, latest.boundingBox)
    }

    @MainActor
    func testEmptyResultWhileDisabledDoesNotRestoreAnOldBoxWhenReenabled() {
        let overlay = BarcodeBoundingBoxes(frame: .zero)
        overlay.updateBarcodes(
            [makeBox(rect: CGRect(x: 10, y: 20, width: 30, height: 40))], customSettings: [:])

        overlay.isRenderingEnabled = false
        overlay.updateBarcodes([], customSettings: [:])
        overlay.isRenderingEnabled = true

        XCTAssertTrue(shapeLayers(in: overlay).isEmpty)
    }

    @MainActor
    func testOverlayUsesDeliveredPreviewCornersWithoutProjectingThemAgain() throws {
        let overlay = BarcodeBoundingBoxes(frame: .zero)
        let previewCorners = [
            CGPoint(x: 20, y: 10), CGPoint(x: 80, y: 30),
            CGPoint(x: 70, y: 60), CGPoint(x: 10, y: 40)
        ]
        let rectangle = CGRect(x: 0, y: 0, width: 100, height: 100)
        let barcode = Barcode(
            format: .code128,
            boundingBoxInCameraPreview: rectangle,
            quadPoints: [],
            value: "preview-quad",
            quadPointsInCameraPreview: previewCorners)

        overlay.updateBarcodes([(barcode, rectangle)], customSettings: [:])

        let shape = try XCTUnwrap(shapeLayers(in: overlay).first)
        XCTAssertEqual(shape.path?.boundingBoxOfPath, CGRect(x: 10, y: 10, width: 70, height: 50))
        XCTAssertFalse(shape.path?.contains(CGPoint(x: 10, y: 10)) ?? true)
        XCTAssertTrue(shape.path?.contains(CGPoint(x: 45, y: 35)) ?? false)
    }

    @MainActor
    func testDisabledScannerDeliversGeometryAndEmptyUpdatesWithoutDrawingFromStyleCompletion() throws {
        let context = OsirisDataCaptureContext(id: "host-box-callback-\(UUID().uuidString)")
        OsirisApp.configure(
            withConfig: OsirisConfig(enableDisplayBoundingBox: false), context: context)
        let controller = OsirisScannerViewController(context: context)
        let delegate = BoundingBoxDelegateSpy()
        controller.delegate = delegate
        controller.loadViewIfNeeded()
        defer {
            controller.delegate = nil
            delegate.onDetection = nil
            OsirisApp.shared.removeConfig(forContext: context)
        }

        let overlay = try XCTUnwrap(controller.scannerView?.boundingBoxes)
        XCTAssertFalse(overlay.isRenderingEnabled)
        let box = makeBox(rect: CGRect(x: 30, y: 40, width: 90, height: 50))
        let detection = expectation(description: "Host receives barcode geometry with SDK drawing disabled")
        let clearing = expectation(description: "Host receives an empty result to remove its own boxes")
        var receivedDetection = false
        var expectingEmptyResult = false

        delegate.onDetection = { barcodes, styleCompletion in
            if let barcode = barcodes.first {
                XCTAssertFalse(receivedDetection)
                receivedDetection = true
                XCTAssertEqual(barcode.value, box.barcode.value)
                XCTAssertEqual(barcode.boundingBoxInCameraPreview, box.boundingBox)
                XCTAssertEqual(barcode.boundingBoxInPixelBuffer, box.barcode.boundingBoxInPixelBuffer)
                XCTAssertEqual(barcode.symbologyIdentifier, "]C1")
                XCTAssertTrue(self.shapeLayers(in: overlay).isEmpty)

                // A host may still call this existing callback even though it opted out of SDK drawing.
                styleCompletion([
                    barcode.value: OsirisBoundingBoxConfig(
                        borderColor: .red, titleBox: .init(title: "Custom", titleColor: .white))
                ])
                detection.fulfill()
            } else if expectingEmptyResult {
                expectingEmptyResult = false
                XCTAssertTrue(self.shapeLayers(in: overlay).isEmpty)
                clearing.fulfill()
            }
        }

        // Exercise the real Combine subscription without starting the camera or decoder.
        controller.viewModel.barcodeManager.barcodeBoundingBoxes = [box]
        wait(for: [detection], timeout: 1)
        XCTAssertTrue(shapeLayers(in: overlay).isEmpty)

        expectingEmptyResult = true
        controller.viewModel.barcodeManager.barcodeBoundingBoxes = []
        wait(for: [clearing], timeout: 1)
        XCTAssertTrue(shapeLayers(in: overlay).isEmpty)
    }

    @MainActor
    func testDelayedStyleCompletionAfterEmptyResultDoesNotRestoreAnOldBox() throws {
        let context = OsirisDataCaptureContext(id: "delayed-box-style-\(UUID().uuidString)")
        OsirisApp.configure(
            withConfig: OsirisConfig(enableDisplayBoundingBox: false), context: context)
        let controller = OsirisScannerViewController(context: context)
        let delegate = BoundingBoxDelegateSpy()
        controller.delegate = delegate
        controller.loadViewIfNeeded()
        defer {
            controller.delegate = nil
            delegate.onDetection = nil
            OsirisApp.shared.removeConfig(forContext: context)
        }

        let overlay = try XCTUnwrap(controller.scannerView?.boundingBoxes)
        let box = makeBox(rect: CGRect(x: 30, y: 40, width: 90, height: 50))
        let detection = expectation(description: "Host receives initial result")
        let clearing = expectation(description: "Host receives empty result")
        var delayedCompletion: (([BarcodeValue: OsirisBoundingBoxConfig]) -> Void)?
        var expectingEmptyResult = false
        delegate.onDetection = { barcodes, completion in
            if !barcodes.isEmpty {
                delayedCompletion = completion
                detection.fulfill()
            } else if expectingEmptyResult {
                expectingEmptyResult = false
                clearing.fulfill()
            }
        }

        controller.viewModel.barcodeManager.barcodeBoundingBoxes = [box]
        wait(for: [detection], timeout: 1)
        expectingEmptyResult = true
        controller.viewModel.barcodeManager.barcodeBoundingBoxes = []
        wait(for: [clearing], timeout: 1)

        let completion = try XCTUnwrap(delayedCompletion)
        let styles = [box.barcode.value: OsirisBoundingBoxConfig(borderColor: .red)]
        let styleApplied = expectation(description: "Background completion is applied on the main queue")
        DispatchQueue.global().async {
            completion(styles)
            DispatchQueue.main.async {
                styleApplied.fulfill()
            }
        }
        wait(for: [styleApplied], timeout: 1)

        // Re-enable only the view to inspect its stored results without restarting a camera session.
        overlay.isRenderingEnabled = true
        XCTAssertTrue(shapeLayers(in: overlay).isEmpty)
        XCTAssertEqual(controller.boundingBoxSettings[box.barcode.value]?.borderColor, .red)
    }

    private func makeBox(rect: CGRect) -> BarcodeBoundingBox {
        let barcode = Barcode(
            format: .code128,
            boundingBoxInCameraPreview: rect,
            boundingBoxInPixelBuffer: CGRect(x: 5, y: 6, width: 7, height: 8),
            quadPoints: [],
            value: "same-barcode",
            symbologyIdentifier: "]C1")
        return (barcode, rect)
    }

    @MainActor
    private func shapeLayers(in overlay: BarcodeBoundingBoxes) -> [CAShapeLayer] {
        overlay.layer.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
    }
}

private final class BoundingBoxDelegateSpy: OsirisScannerDelegate {
    var onDetection: (([Barcode], @escaping ([BarcodeValue: OsirisBoundingBoxConfig]) -> Void) -> Void)?

    func didDetectBarcodes(
        _ barcodes: [Barcode],
        setBoundingBoxesSettings: @escaping ([BarcodeValue: OsirisBoundingBoxConfig]) -> Void
    ) {
        onDetection?(barcodes, setBoundingBoxesSettings)
    }

    func didTapDetectedBarcodeBoundingBox(
        _ barcode: Barcode, setBoundingBoxSettings: @escaping (OsirisBoundingBoxConfig) -> Void
    ) {}

    func didDetectBarcode(_ barcode: Barcode) {}
    func didFireEvent(_ event: OsirisEvent) {}
    func didReceiveError(_ error: Error) {}
    func cameraIdleDetected() {}
}

                                           to: decoder.options.previewSize,
                                           originOffset: CGPoint(x: 50, y: 30),
                                           sizeOffset: CGSize(width: 80, height: 60))

        XCTAssertEqual(result, CGRect(x: 55, y: 40, width: 20, height: 15))
    }

    func testOffCenterCropKeepsDecoderRectangleLocalAndReturnsFullImageCorners() throws {
        let decoder = makeDecoder(imageSize: CGSize(width: 640, height: 480),
                                  previewSize: CGSize(width: 320, height: 240))
        let pixelBuffer = try makePixelBuffer(width: 640, height: 480)
        decoder.transformBarcodes(results: [makeResult()], pixelBuffer: pixelBuffer,
                                  cropOrigin: CGPoint(x: 100, y: 60))

        let barcode = try XCTUnwrap(decoder.detectedBarcodes.first)
        XCTAssertEqual(barcode.boundingBoxInPixelBuffer, CGRect(x: 10, y: 20, width: 40, height: 30))
        XCTAssertEqual(barcode.boundingBoxInCameraPreview, CGRect(x: 55, y: 40, width: 20, height: 15))
        XCTAssertEqual(barcode.quadPoints, [CGPoint(x: 110, y: 80), CGPoint(x: 150, y: 80),
                                           CGPoint(x: 150, y: 110), CGPoint(x: 110, y: 110)])
        XCTAssertEqual(barcode.quadPointsInCameraPreview,
                       [CGPoint(x: 55, y: 40), CGPoint(x: 75, y: 40),
                        CGPoint(x: 75, y: 55), CGPoint(x: 55, y: 55)])
        XCTAssertEqual(barcode.symbologyIdentifier, "]Q3")
    }

    func testUncroppedImageDoesNotApplyComputedROIOrigin() throws {
        let decoder = makeDecoder(imageSize: CGSize(width: 640, height: 480),
                                  previewSize: CGSize(width: 320, height: 180))
        decoder.options.reticle = false
        // The default ROI can be nonzero even though the entire frame is decoded.
        decoder.roiRect = CGRect(x: 0, y: 60, width: 640, height: 360)
        XCTAssertNil(decoder.decodingCropRect(in: decoder.pixelBufferSize))

        let pixelBuffer = try makePixelBuffer(width: 640, height: 480)
        decoder.transformBarcodes(results: [makeResult()], pixelBuffer: pixelBuffer)

        let barcode = try XCTUnwrap(decoder.detectedBarcodes.first)
        XCTAssertEqual(barcode.quadPoints.first, CGPoint(x: 10, y: 20))
        XCTAssertEqual(barcode.boundingBoxInCameraPreview, CGRect(x: 5, y: -20, width: 20, height: 15))
        XCTAssertEqual(barcode.quadPointsInCameraPreview.first, CGPoint(x: 5, y: -20))
    }

    func testPortraitAspectFillUsesAlreadyOrientedBufferWithoutAnotherRotation() throws {
        let decoder = makeDecoder(imageSize: CGSize(width: 480, height: 640),
                                  previewSize: CGSize(width: 180, height: 320))
        let pixelBuffer = try makePixelBuffer(width: 480, height: 640)
        decoder.transformBarcodes(results: [makeResult()], pixelBuffer: pixelBuffer,
                                  cropOrigin: CGPoint(x: 100, y: 60))

        let barcode = try XCTUnwrap(decoder.detectedBarcodes.first)
        XCTAssertEqual(barcode.boundingBoxInCameraPreview, CGRect(x: 25, y: 40, width: 20, height: 15))
        XCTAssertEqual(barcode.quadPointsInCameraPreview.first, CGPoint(x: 25, y: 40))
    }

    func testMirroredPreviewRectangleAndCornersUseSameTransform() throws {
        let decoder = makeDecoder(imageSize: CGSize(width: 640, height: 480),
                                  previewSize: CGSize(width: 320, height: 240))
        decoder.options.scanDirectionFront = true
        let pixelBuffer = try makePixelBuffer(width: 640, height: 480)
        decoder.transformBarcodes(results: [makeResult()], pixelBuffer: pixelBuffer,
                                  cropOrigin: CGPoint(x: 100, y: 60))

        let barcode = try XCTUnwrap(decoder.detectedBarcodes.first)
        XCTAssertEqual(barcode.boundingBoxInCameraPreview, CGRect(x: 245, y: 40, width: 20, height: 15))
        XCTAssertEqual(barcode.quadPointsInCameraPreview,
                       [CGPoint(x: 265, y: 40), CGPoint(x: 245, y: 40),
                        CGPoint(x: 245, y: 55), CGPoint(x: 265, y: 55)])
        XCTAssertEqual(barcode.quadPoints.first, CGPoint(x: 110, y: 80))
    }

    func testQuadOptOutStillReturnsPreviewRectangle() throws {
        let decoder = makeDecoder(imageSize: CGSize(width: 640, height: 480),
                                  previewSize: CGSize(width: 320, height: 240))
        decoder.isQuadliteralEnabled = false
        let pixelBuffer = try makePixelBuffer(width: 640, height: 480)
        decoder.transformBarcodes(results: [makeResult()], pixelBuffer: pixelBuffer)

        let barcode = try XCTUnwrap(decoder.detectedBarcodes.first)
        XCTAssertEqual(barcode.boundingBoxInCameraPreview, CGRect(x: 5, y: 10, width: 20, height: 15))
        XCTAssertTrue(barcode.quadPoints.isEmpty)
        XCTAssertTrue(barcode.quadPointsInCameraPreview.isEmpty)
    }

    func testAppliedCropMatchesIntegralCPUCopyAndRejectsInvalidROI() {
        let decoder = makeDecoder(imageSize: CGSize(width: 640, height: 480),
                                  previewSize: CGSize(width: 320, height: 240))
        decoder.options.reticle = false
        decoder.setROI(CGRect(x: 10.9, y: 20.8, width: 30.7, height: 40.6))
        XCTAssertEqual(decoder.decodingCropRect(in: decoder.pixelBufferSize),
                       CGRect(x: 10, y: 20, width: 30, height: 40))

        for invalidROI in [CGRect(x: -1, y: 0, width: 20, height: 20),
                           CGRect(x: 620, y: 0, width: 30, height: 20),
                           CGRect(x: 30, y: 20, width: -10, height: 20),
                           CGRect(x: 10, y: 20, width: 0.5, height: 20),
                           CGRect.zero] {
            decoder.setROI(invalidROI)
            XCTAssertNil(decoder.decodingCropRect(in: decoder.pixelBufferSize))
        }
    }

    func testGPUCropMatchesCPUPixelsForOffCenterNonSquareROI() throws {
        let decoder = makeDecoder(imageSize: CGSize(width: 8, height: 6),
                                  previewSize: CGSize(width: 8, height: 6))
        let pixelBuffer = try makePixelBuffer(width: 8, height: 6)
        try fillCoordinates(in: pixelBuffer)

        let roi = CGRect(x: 1, y: 1, width: 4, height: 2)
        let cpuCrop = try XCTUnwrap(pixelBuffer.crop(toRect: roi))
        let gpuCrop = decoder.cropForDecoding(CIImage(cvPixelBuffer: pixelBuffer), to: roi)
        XCTAssertEqual(gpuCrop.extent, CGRect(x: 1, y: 3, width: 4, height: 2))
        XCTAssertEqual(rgbaPixels(of: gpuCrop), rgbaPixels(of: CIImage(cvPixelBuffer: cpuCrop)))
    }

    func testZeroSizedContainerProducesFiniteEmptyRectangle() {
        let decoder = makeDecoder(imageSize: .zero, previewSize: CGSize(width: 320, height: 240))
        XCTAssertEqual(decoder.transformRect(originalBounds: CGRect(x: 10, y: 20, width: 30, height: 40),
                                             from: .zero,
                                             to: decoder.options.previewSize,
                                             originOffset: .zero,
                                             sizeOffset: .zero), .zero)
    }

    private func fillCoordinates(in pixelBuffer: CVPixelBuffer) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let bytes = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixelBuffer))
            .assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for y in 0..<6 {
            for x in 0..<8 {
                let index = y * bytesPerRow + x * 4
                bytes[index] = UInt8(x * 20)
                bytes[index + 1] = UInt8(y * 30)
                bytes[index + 2] = UInt8((x + y) * 10)
                bytes[index + 3] = 255
            }
        }
    }

    private func makeDecoder(imageSize: CGSize, previewSize: CGSize) -> ZXingBarcodeDecoder {
        var options = BarcodeDecoderOptions(decoderType: .zxing)
        options.previewSize = previewSize
        options.formats = [.qrcode]
        let decoder = ZXingBarcodeDecoder(options: options)
        decoder.pixelBufferSize = imageSize
        decoder.isQuadliteralEnabled = true
        return decoder
    }

    private func makeResult() -> ZXIResult {
        let position = ZXIPosition(topLeft: ZXIPoint(x: 10, y: 20),
                                   topRight: ZXIPoint(x: 50, y: 20),
                                   bottomRight: ZXIPoint(x: 50, y: 50),
                                   bottomLeft: ZXIPoint(x: 10, y: 50))
        return ZXIResult("GEOMETRY", format: .QR_CODE, bytes: Data(),
                         position: position, symbologyIdentifier: "]Q3")
    }

    private func makePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                        kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }

    private func rgbaPixels(of image: CIImage) -> [UInt8] {
        let bytesPerRow = Int(image.extent.width) * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * Int(image.extent.height))
        pixels.withUnsafeMutableBytes { buffer in
            CIContext().render(image, toBitmap: buffer.baseAddress!, rowBytes: bytesPerRow,
                               bounds: image.extent, format: .RGBA8,
                               colorSpace: CGColorSpaceCreateDeviceRGB())
        }
        return pixels
    }
}
