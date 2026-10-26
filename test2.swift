//
//  ZXingBarcodeDecoder.swift
//  Osiris
//
//  Created by Andres Vinueza on 9/28/23.

import Foundation
import Vision
import AVFoundation
import CoreVideo
import CoreImage
import ImageIO
import ZXingCpp

public final class ZXingBarcodeDecoder: BarcodeDecoder {

    // MARK: Properties

    public override var id: String {
        "ZXingBarcodeDecoder"
    }

    private static let enabledHintsKey = "enabledHints"

    public override var extras: BenchmarkResultOutputMetrics.Extras? {
        let enabledHints = BarcodeDecoderHint.allCases.filter { hint in
            switch hint {
            case .tryHarder: return latestDecoderHints.tryHarder
            case .tryRotate: return latestDecoderHints.tryRotate
            case .tryDiagonal: return latestDecoderHints.tryDiagonal
            case .tryDownscale: return latestDecoderHints.tryDownscale
            case .tryInvert: return latestDecoderHints.tryInvert
            case .tryRebalance: return latestDecoderHints.tryRebalance
            case .tryErosion: return latestDecoderHints.tryErosion
            case .tryCLAHE, .tryCLAHEAll: return latestDecoderHints.tryCLAHE != 0
            case .tryCode39ExtendedMode: return latestDecoderHints.tryCode39ExtendedMode
            case .validateCode39CheckSum: return latestDecoderHints.validateCode39CheckSum
            case .validateITFCheckSum: return latestDecoderHints.validateITFCheckSum
            case .enableDeblur: return latestDecoderHints.enableDeblur
            case .enableLaplacianVariance: return latestDecoderHints.enableLaplacianVariance
            case .enableObjectDetection: return latestDecoderHints.enableObjectDetection
            case .enableParallelPyramid: return latestDecoderHints.enableParallelPyramid
            case .enableAdaptiveFiltering: return latestDecoderHints.enableAdaptiveFiltering
            case .enableTemplateMatching: return latestDecoderHints.enableTemplateMatching
            //        case .enableVizpick: return latestDecoderHints.enableVizpick
            //        case .enableDebugging: return latestDecoderHints.enableDebugging
            //        case .enableModules: return latestDecoderHints.enableModules
            case .serialSmallAngleRotation: return latestDecoderHints.smallAngleRotation == 1
            case .parallelSmallAngleRotation: return latestDecoderHints.smallAngleRotation == 2
            }
        }.map { $0.rawValue }

        return [Self.enabledHintsKey: enabledHints]
    }

    internal var decoderHints: ZXIDecodeHints?
    private let zxiReader = ZXIBarcodeReader()

    // private lazy var locationManager: LocationManager = LocationManager()

    // MARK: Public

    override public func optionsDidLoad() {
        super.optionsDidLoad()
        updateDecoderHints()
    }

    override public func recognizeBarcodes(_ pixelBuffer: CVImageBuffer) -> CVPixelBuffer {
        pixelBufferSize = CVImageBufferGetDisplaySize(pixelBuffer)
        if !isROIManuallySet {
            roiRect = calculateROI(
                with: pixelBuffer,
                canvasSize: previewSize,
                reticleRect: reticleRect,
                reticleEnabled: reticleEnabled)
        }
        var bufferResult: CVPixelBuffer?
        var results: [ZXIResult] = []
        var appliedCropOrigin: CGPoint = .zero

        func applyFiltersAndRead(imageBuffer: CVImageBuffer) {
            let image = CIImage(cvImageBuffer: imageBuffer)
            let frameAttributes = self.createZXIAttributes(from: imageBuffer)
            appleFiltersAndRead(image: image, frameAttribute: frameAttributes)

            //            print("""
            //            tryHarder: \(latestDecoderHints.tryHarder)
            //            tryRotate: \(latestDecoderHints.tryRotate)
            //            tryDiagonal: \(latestDecoderHints.tryDiagonal)
            //            tryDownscale: \(latestDecoderHints.tryDownscale)
            //            maxNumberOfSymbols: \(latestDecoderHints.maxNumberOfSymbols)
            //            tryCLAHE: \(latestDecoderHints.tryCLAHE)
            //            tryInvert: \(latestDecoderHints.tryInvert)
            //            tryRebalance: \(latestDecoderHints.tryRebalance)
            //            tryErosion: \(latestDecoderHints.tryErosion)
            //            tryCode39ExtendedMode: \(latestDecoderHints.tryCode39ExtendedMode)
            //            validateCode39CheckSum: \(latestDecoderHints.validateCode39CheckSum)
            //            validateITFCheckSum: \(latestDecoderHints.validateITFCheckSum)
            //            enableDeblur: \(latestDecoderHints.enableDeblur)
            //            enableLaplacianVariance: \(latestDecoderHints.enableLaplacianVariance)
            //            enableObjectDetection: \(latestDecoderHints.enableObjectDetection)
            //            enableParallelPyramid: \(latestDecoderHints.enableParallelPyramid)
            //            enableAdaptiveFiltering: \(latestDecoderHints.enableAdaptiveFiltering)
            //            enableVizpick: \(latestDecoderHints.enableVizpick)
            //            enableDebugging: \(latestDecoderHints.enableDebugging)
            //            enableModules: \(latestDecoderHints.enableModules)
            //            smallAngleRotation: \(latestDecoderHints.smallAngleRotation)
            //            downscaleFactor: \(latestDecoderHints.downscaleFactor)
            //            downscaleThreshold: \(latestDecoderHints.downscaleThreshold)
            //            formats: \(latestDecoderHints.formats)
            //            """)
        }

        func appleFiltersAndRead(image: CIImage, frameAttribute: ZXIFrameAttributes) {
            results = zxiReader.read(
                image, decoderHints: latestDecoderHints, frameAttributes: frameAttribute)
            //            print("Scanned results: \(results)")
        }

        // Record the crop that actually reached the decoder. A computed ROI does
        // not imply a crop was applied (for example, with the reticle disabled).
        if let cropRect = decodingCropRect(in: pixelBufferSize) {
            if gpuAccelerationEnabled {
                let croppedImage = cropForDecoding(CIImage(cvImageBuffer: pixelBuffer), to: cropRect)
                appliedCropOrigin = cropRect.origin
                let frameAttributes = self.createZXIAttributes(from: pixelBuffer)
                appleFiltersAndRead(image: croppedImage, frameAttribute: frameAttributes)
            } else if let croppedBuffer = pixelBuffer.crop(toRect: cropRect) {
                appliedCropOrigin = cropRect.origin
                applyFiltersAndRead(imageBuffer: croppedBuffer)
            } else {
                applyFiltersAndRead(imageBuffer: pixelBuffer)
            }

        } else {
            applyFiltersAndRead(imageBuffer: pixelBuffer)
        }
        transformBarcodes(results: results, pixelBuffer: pixelBuffer, cropOrigin: appliedCropOrigin)
        guard !results.isEmpty else {
            // detectedBarcodes = []
            return bufferResult ?? pixelBuffer
        }

        return bufferResult ?? pixelBuffer
    }

    internal func applyFilters(toCIImage image: CIImage) -> CIImage {
        let filteredImage = image
        return filteredImage
    }

    /// The CPU crop copies integral rows/columns from a top-left-origin image.
    /// Use the same rectangle for both paths, and reject invalid crops before
    /// attributing any offset to the resulting barcode coordinates.
    internal func decodingCropRect(in imageSize: CGSize) -> CGRect? {
        guard reticleEnabled || isROIManuallySet,
              roiRect.isValid(), roiRect.origin.x >= 0, roiRect.origin.y >= 0,
              roiRect.size.width > 0, roiRect.size.height > 0,
              roiRect.maxX <= imageSize.width, roiRect.maxY <= imageSize.height else {
            return nil
        }
        let rect = CGRect(x: roiRect.origin.x.rounded(.towardZero),
                          y: roiRect.origin.y.rounded(.towardZero),
                          width: roiRect.width.rounded(.towardZero),
                          height: roiRect.height.rounded(.towardZero))
        return rect.isEmpty ? nil : rect
    }

    /// Core Image uses a bottom-left origin, while the pixel-buffer crop and
    /// ZXing result positions use a top-left origin. Keep width/height intact.
    internal func cropForDecoding(_ image: CIImage, to topLeftRect: CGRect) -> CIImage {
        let imageRect = CGRect(x: image.extent.minX + topLeftRect.minX,
                               y: image.extent.maxY - topLeftRect.maxY,
                               width: topLeftRect.width,
                               height: topLeftRect.height)
        return image.cropped(to: imageRect)
    }

    // MARK: Private

    func getCameraMetadata(device: CameraDeviceProtocol) -> [String: Any] {
        var metadata: [String: Any] = [:]
        // Aperture (f-number)
        if device.isExposureModeSupported(.continuousAutoExposure) {
            metadata["ApertureValue"] = device.lensAperture
        }

        // Exposure time (shutter speed)
        metadata["ExposureTime"] = device.exposureDuration.seconds

        // ISO (sensitivity)
        metadata["ISO"] = device.iso

        // Focal length
        metadata["FocalLength"] = device.lensPosition

        // Exposure Bias (Not directly available, but can be estimated)
        metadata["ExposureBiasValue"] = "0.0"

        // Exposure Mode
        metadata["ExposureMode"] = device.exposureMode == .autoExpose ? "Auto" : "Manual"

        return metadata
    }

    func createZXIAttributes(from imageBuffer: CVImageBuffer, device: CameraDeviceProtocol? = nil)
        -> ZXIFrameAttributes
    {
        guard let device = currentCaptureDevice ?? device else {
            return ZXIFrameAttributes()
        }

        let cameraMetadata = getCameraMetadata(device: device)
        let gpsMetadata: [String: String] = [:]  // locationManager.getGPSMetadata()

        return ZXIFrameAttributes(
            attributes: 0,
            orientationFlipVertical: 0,
            orientationNormal: 1,
            orientationRotate180: 0,
            orientationRotate270: 0,
            orientationRotate90: 0,
            orientationTranspose: 0,
            orientationTransverse: 0,
            orientationUndefined: 0,
            tagAperture: "\(cameraMetadata["ApertureValue"] ?? "N/A")",
            tagApertureValue: "\(cameraMetadata["ApertureValue"] ?? "N/A")",
            tagExifVersion: "220",
            tagExposureBiasValue: "\(cameraMetadata["ExposureBiasValue"] ?? "N/A")",
            tagExposureMode: "\(cameraMetadata["ExposureMode"] ?? "N/A")",
            tagExposureProgram: "Normal",
            tagExposureTime: "\(cameraMetadata["ExposureTime"] ?? "N/A")",
            tagFocalLength: "\(cameraMetadata["FocalLength"] ?? "N/A")",
            tagFocalLengthIn35mmFilm: "N/A",
            tagFocalPlaneResolutionUnit: "2",
            tagFocalPlaneXResolution: "\(CVPixelBufferGetWidth(imageBuffer))",
            tagFocalPlaneYResolution: "\(CVPixelBufferGetHeight(imageBuffer))",
            tagGpsDestLatitude: "\(gpsMetadata["Latitude"] ?? "N/A")",
            tagGpsDestLatitudeRef: "\(gpsMetadata["LatitudeRef"] ?? "N/A")",
            tagGpsDestLongitude: "\(gpsMetadata["Longitude"] ?? "N/A")",
            tagGpsDestLongitudeRef: "\(gpsMetadata["LongitudeRef"] ?? "N/A")",
            tagGpsTimestamp: "\(gpsMetadata["Timestamp"] ?? "N/A")",
            tagImageLength: "\(CVPixelBufferGetHeight(imageBuffer))",
            tagImageWidth: "\(CVPixelBufferGetWidth(imageBuffer))",
            tagSubjectDistance: "N/A",
            tagSubjectDistanceRange: "N/A",
            tagSubjectLocation: "N/A",
            tagXResolution: "300",
            tagYResolution: "300"
        )
    }

    internal var effectiveReticleRect: CGRect {
        guard isROIManuallySet, roiRect != .zero else {
            if reticleEnabled {
                return reticleRect
            }
            return .zero
        }
        let canvasSize =
            previewSize.width > 0 && previewSize.height > 0 ? previewSize : pixelBufferSize
        guard canvasSize.width > 0, canvasSize.height > 0,
            pixelBufferSize.width > 0, pixelBufferSize.height > 0
        else {
            return .zero
        }
        let scale = min(
            pixelBufferSize.width / canvasSize.width, pixelBufferSize.height / canvasSize.height)
        guard scale > 0 else { return .zero }
        let origin = CGPoint(
            x: (roiRect.origin.x - (pixelBufferSize.width - canvasSize.width * scale) / 2) / scale,
            y: (roiRect.origin.y - (pixelBufferSize.height - canvasSize.height * scale) / 2) / scale
        )
        let size = CGSize(width: roiRect.width / scale, height: roiRect.height / scale)
        return CGRect(origin: origin, size: size)
    }

    internal func transformBarcodes(
        results: [ZXIResult], pixelBuffer: CVPixelBuffer, deblurredPixelBuffer: CVPixelBuffer? = nil,
        cropOrigin: CGPoint = .zero
    ) {

        for result in results {
            let format = convertToBarcodeFormat(with: result.format)

            // To do: Remove guard now that formats passed to ZXing?
            guard options.formats.contains(format) else {
                continue
            }

            let newRect =
                previewSize.width > 0 && previewSize.height > 0
                ? previewSize : pixelBuffer.rect().size
            let topLeft = result.position.topLeft
            let topRight = result.position.topRight
            let bottomLeft = result.position.bottomLeft
            let bottomRight = result.position.bottomRight
            let minX = min(topLeft.x, bottomLeft.x, topRight.x, bottomRight.x)
            let minY = min(topLeft.y, bottomLeft.y, topRight.y, bottomRight.y)
            let maxX = max(topLeft.x, bottomLeft.x, topRight.x, bottomRight.x)
            let maxY = max(topLeft.y, bottomLeft.y, topRight.y, bottomRight.y)
            let boundingBoxInPixelBuffer = CGRect(
                x: minX, y: minY, width: maxX - minX, height: maxY - minY)

            let fullImageBounds = boundingBoxInPixelBuffer.offsetBy(dx: cropOrigin.x, dy: cropOrigin.y)
            let bb = transformRect(originalBounds: fullImageBounds,
                       from: pixelBufferSize,
                       to: newRect,
                       originOffset: .zero,
                       sizeOffset: .zero,
                       flipHorizontally: self.options.scanDirectionFront)

            let quadPoints: [CGPoint] =
                isQuadliteralEnabled
                ? [
                    CGPoint(x: topLeft.x, y: topLeft.y),
                    CGPoint(x: topRight.x, y: topRight.y),
                    CGPoint(x: bottomRight.x, y: bottomRight.y),
                    CGPoint(x: bottomLeft.x, y: bottomLeft.y),
                ] : []

            let finalQuadPoints: [CGPoint] = quadPoints.map {
                CGPoint(
                    x: $0.x + cropOrigin.x,
                    y: $0.y + cropOrigin.y
                )
            }

            // The captured buffer is already oriented by the camera output.
            // Rectangles and quadrilaterals share the same preview transform.
            let previewQuadPoints = finalQuadPoints.map { point in
                transformRect(originalBounds: CGRect(origin: point, size: .zero),
                              from: pixelBufferSize,
                              to: newRect,
                              originOffset: .zero,
                              sizeOffset: .zero,
                              flipHorizontally: self.options.scanDirectionFront).origin
            }

            let barcode = Barcode(
                format: format,
                boundingBoxInCameraPreview: bb,
                boundingBoxInPixelBuffer: boundingBoxInPixelBuffer,
                quadPoints: finalQuadPoints,
                value: result.text,
                symbologyIdentifier: result.symbologyIdentifier,
                quadPointsInCameraPreview: previewQuadPoints)
            detectedBarcodes.append(barcode)
            guard isMultiple else {
                break
            }

        }

    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func convertToBarcodeFormat(with zxiFormat: ZXIFormat) -> BarcodeFormat {
        switch zxiFormat {
        case .CODABAR:
            return .codabar
        case .CODE_39:
            return .code39
        case .CODE_93:
            return .code93
        case .CODE_128:
            return .code128
        case .DATA_BAR:
            return .gs1databar
        case .DATA_BAR_EXPANDED:
            return .gs1databarexpanded
        case .DATA_MATRIX:
            return .datamatrix
        case .EAN_8:
            return .ean8
        case .EAN_13:
            return .ean13
        case .ITF:
            return .itf14
        case .QR_CODE:
            return .qrcode
        case .UPC_A:
            return .upca
        case .UPC_E:
            return .upce
        case .NONE:
            return .notfound
        case .AZTEC:
            return .aztec
        case .MAXICODE:
            return .maxicode
        case .PDF_417:
            return .pdf417
        case .MICRO_QR_CODE:
            return .microqr
        case .LINEAR_CODES:
            return .notfound
        case .MATRIX_CODES:
            return .notfound
        case .ANY:
            return .notfound
        case .ARUCO:
            return .aruco
        case .LUCKY7:
            return .lucky7
        case .VIZPICK:
            return .vizpick
        @unknown default:
            return .notfound
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    internal func convertToZXIFormat(withBarcodeFormat format: BarcodeFormat) -> ZXIFormat {
        switch format {
        case .aztec:
            return .AZTEC
        case .codabar:
            return .CODABAR
        case .code39:
            return .CODE_39
        case .code93:
            return .CODE_93
        case .code128:
            return .CODE_128
        case .datamatrix:
            return .DATA_MATRIX
        case .ean8:
            return .EAN_8
        case .ean13:
            return .EAN_13
        case .gs1databar:
            return .DATA_BAR
        case .gs1databarexpanded:
            return .DATA_BAR_EXPANDED
        case .gs1databarlimited:
            return .NONE
        case .itf14:
            return .ITF
        case .lucky7:
            return .NONE
        case .maxicode:
            return .MAXICODE
        case .microqr:
            return .MICRO_QR_CODE
        case .pdf417:
            return .PDF_417
        case .qrcode:
            return .QR_CODE
        case .upca:
            return .UPC_A
        case .upce:
            return .UPC_E
        case .notfound:
            return .NONE
        case .aruco:
            return .ARUCO
        case .vizpick:
            return .VIZPICK
        }
    }

    var latestDecoderHints: ZXIDecodeHints {
        let selectedFormats = options.formats
        let shouldEnableVizpick = selectedFormats.contains { $0 == .vizpick }
        let formats = selectedFormats.compactMap {
            NSNumber(value: convertToZXIFormat(withBarcodeFormat: $0).rawValue)
        }

        let selectedHints = options.hints
        var decoderHintsDict: [BarcodeDecoderHint: Bool] = [:]
        BarcodeDecoderHint.allCases.forEach { hint in
            decoderHintsDict[hint] = selectedHints.contains(hint)
        }

        let serialSmallAngleRotationEnabled = decoderHintsDict[.serialSmallAngleRotation] ?? false
        let parallelSmallAngleRotationEnabled =
            decoderHintsDict[.parallelSmallAngleRotation] ?? false

        let smallAngleRotation = BarcodeDecoderHint.getSmallAngleRotation(
            serialSmallAngleRotation: serialSmallAngleRotationEnabled,
            parallelSmallAngleRotation: parallelSmallAngleRotationEnabled
        ).rawValue
        let tryCLAHEEnabled = decoderHintsDict[.tryCLAHE] ?? false
        let tryCLAHEAllEnabled = decoderHintsDict[.tryCLAHEAll] ?? false
        let tryCLAHE = BarcodeDecoderHint.getTryCLAHEType(
            tryCLAHEEnabled: tryCLAHEEnabled,
            tryCLAHEALLEnabled: tryCLAHEAllEnabled
        ).rawValue

        return ZXIDecodeHints.init(
            tryHarder: decoderHintsDict[.tryHarder] ?? true,
            tryRotate: decoderHintsDict[.tryRotate] ?? true,
            tryDiagonal: decoderHintsDict[.tryDiagonal] ?? true,
            tryDownscale: decoderHintsDict[.tryDownscale] ?? true,
            maxNumberOfSymbols: 200,
            tryCLAHE: tryCLAHE,
            tryInvert: decoderHintsDict[.tryInvert] ?? true,
            tryRebalance: decoderHintsDict[.tryRebalance] ?? true,
            tryErosion: decoderHintsDict[.tryErosion] ?? true,
            tryCode39ExtendedMode: decoderHintsDict[.tryCode39ExtendedMode] ?? true,
            validateCode39CheckSum: decoderHintsDict[.validateCode39CheckSum] ?? true,
            validateITFCheckSum: decoderHintsDict[.validateITFCheckSum] ?? true,
            enableDeblur: decoderHintsDict[.enableDeblur] ?? false,
            enableLaplacianVariance: decoderHintsDict[.enableLaplacianVariance] ?? true,
            enableObjectDetection: decoderHintsDict[.enableObjectDetection] ?? false,
            enableTemplateMatching: decoderHintsDict[.enableTemplateMatching] ?? false,
            enableParallelPyramid: decoderHintsDict[.enableParallelPyramid] ?? false,
            enableAdaptiveFiltering: decoderHintsDict[.enableAdaptiveFiltering] ?? true,
            enableVizpick: shouldEnableVizpick,
            enableDebugging: false,
            enableModules: true,
            smallAngleRotation: smallAngleRotation,
            downscaleFactor: 3,
            downscaleThreshold: 500,
            formats: formats
        )
    }

    internal func updateDecoderHints() {
        self.decoderHints = latestDecoderHints
    }

}

public protocol CameraDeviceProtocol {
    var lensAperture: Float { get }
    var exposureDuration: CMTime { get }
    var iso: Float { get }
    var lensPosition: Float { get }
    var exposureMode: AVCaptureDevice.ExposureMode { get }
    func isExposureModeSupported(_ mode: AVCaptureDevice.ExposureMode) -> Bool
}

extension AVCaptureDevice: CameraDeviceProtocol {}
