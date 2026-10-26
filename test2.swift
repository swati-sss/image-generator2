//
//
//  BarcodeSingleScanViewModel.swift
//  Diamond-sdk
//
//  Created by Andres Vinueza on 10/18/23.
//
//

import AVFoundation
import Foundation
import Osiris
import OsirisBarcode
import OsirisCamera

class BarcodeSingleScanViewModel: ObservableObject {

    // Temporary sample-app controls for testing the host-drawn bounding-box API.
    enum BoundingBoxTestMode {
        case sdk     // Osiris draws its normal boxes.
        case hidden  // Detection continues, but neither app nor SDK draws boxes.
        case host    // Diamond draws blue boxes using SDK-provided geometry.
    }

    // Change this one value to .hidden or .host, then run Diamond again.
    let boundingBoxTestMode: BoundingBoxTestMode = .sdk
    
    // MARK: Properties
    
    @Published private(set) var torchEnabled = false
    let context: OsirisDataCaptureContext = .init()
    private(set) var scannedBarcodeValues: Set<String> = UserDefaults.standard.scannedBarcodes

    // MARK: API
    
    func toggleTorch() throws {
        try setEnableTorch(!torchEnabled)
    }
    
    func toggleDirection() async throws {
        var settings = try await BarcodeSettingsService.shared.fetchCameraSettings()

        guard let oldDevice = settings.selectedCaptureDevice else {
            return
        }
        
        let newPosition: AVCaptureDevice.Position = oldDevice.position == .back ? .front : .back
        
        guard let newDevice = CameraManager.discoverVideoCaptureDevices(position: newPosition).first else {
            Logging.log("Unable to toggle direction...")
            Logging.log("No devices found for position: \(newPosition)")
            return
        }
        
        settings.selectedCaptureDevice = newDevice
        try await BarcodeSettingsService.shared.saveCameraSettings(settings)
        try await configureOsiris()
    }
    
    func setEnableTorch(_ enabled: Bool) throws {
        self.torchEnabled = enabled
        try OsirisApp.setEnableTorch(torchEnabled, context: context)
    }

    func configureOsiris() async throws {
        let config = try await fetchOsirisConfig()
        OsirisApp.configure(withConfig: config, context: context)
    }
    
    func fetchBoundingBoxSettings() async throws -> BoundingBoxOptions {
        return try await BarcodeSettingsService.shared.fetchBoundingBoxSettings()
    }

    func markAsScanned(_ value: String) {
        scannedBarcodeValues.insert(value)
        UserDefaults.standard.scannedBarcodes = scannedBarcodeValues
    }

    func resetScannedBarcodes() {
        scannedBarcodeValues.removeAll()
        UserDefaults.standard.scannedBarcodes = []
    }

    // MARK: Private
    
    private func fetchOsirisConfig(userDefaults: UserDefaults = .standard,
                                   bundle: Bundle = Bundle(for: BarcodeSingleScanViewModel.self)) async throws -> OsirisConfig {
        let boundingBoxSettings = try await BarcodeSettingsService.shared.fetchBoundingBoxSettings()
        let cameraSettings = try await BarcodeSettingsService.shared.fetchCameraSettings()
        let decoderSettings = try await BarcodeSettingsService.shared.fetchDecoderSettings()
        let benchmarkSettings = try await BarcodeSettingsService.shared.fetchBenchmarkSettings()
        
        /// Reticle
        let reticleType: ReticleType = decoderSettings.reticleEnabled ? .rectangle : .none
        let scanArea: ScanArea = decoderSettings.scanArea
        let reticleConfig: OsirisReticleConfig = .init(reticleType: reticleType, scanArea: scanArea)
        
        /// Camera
        let cameraConfig: OsirisCameraConfig = .init(resolution: cameraSettings.selectedCaptureSessionPreset,
                                                     device: cameraSettings.selectedCaptureDevice,
                                                     macroModeEnabled: cameraSettings.macroModeEnabled.isOn,
                                                     autoFocusEnabled: cameraSettings.autoFocusEnabled.isOn,
                                                     autoISOEnabled: cameraSettings.autoISOEnabled.isOn,
                                                     autoExposureEnabled: cameraSettings.autoExposureEnabled.isOn,
                                                     autoWhiteBalanceEnabled: cameraSettings.autoWhiteBalanceEnabled.isContinuous,
                                                     manualISOValue: cameraSettings.autoISOEnabled.value,
                                                     manualExposureValue: cameraSettings.autoExposureEnabled.value,
                                                     manualWhiteBalanceValue: (cameraSettings.autoWhiteBalanceEnabled.temperature,
                                                                               cameraSettings.autoWhiteBalanceEnabled.tint)
        )
        
        /// Feedback
        let feedbackURL: URL? = getFeedbackAudioURL(forBundle: bundle)
        print("Haptic feedback type: \(cameraSettings.hapticFeedbackType)")
        let vibration = cameraSettings.hapticFeedbackType.asVibrationType
        print("Vibration type: \(vibration)")
        let feedbackConfig: OsirisFeedbackConfig = .init(eventFeedback: [.success: .init(vibration: vibration, sound: feedbackURL)])
        
        /// Scan Threshold
        let throttleBetweenSameBarcodeValuesMillis = Double(decoderSettings.scanThresholdInMS) ?? 0.0

        /// Dynamic
        ///
        let dynamicConfig: OsirisDynamicConfig = .init(throttleBetweenSameBarcodeValuesMillis: throttleBetweenSameBarcodeValuesMillis,
                                                       maxCPUPercentage: 100,
                                                       zoomPercentage: 1.5,
                                                       readDistanceMode: .fullRange,
                                                       enableTorch: false,
                                                       enableLogging: true)
        
        /// Extras
        var extras: [String: Any] = [:]
        // For now just add all formats and hints in extras instead of through the groups which aren't visible in the SettingsUI yet
        let symbologies: [String] = decoderSettings.enabledBarcodeFormats.map { $0.rawValue }
        let hints: [String] = decoderSettings.enabledBarcodeDecoderHints.map { $0.rawValue }
        extras[OsirisBarcodeKey.multiScanEnabled.rawValue] = decoderSettings.multiScanEnabled
        extras[OsirisBarcodeKey.symbologiesAdded.rawValue] = symbologies
        extras[OsirisBarcodeKey.hintsAdded.rawValue] = hints
        extras[OsirisBarcodeKey.decoderType.rawValue] = decoderSettings.enabledDecoderType.rawValue
        extras[OsirisBarcodeKey.gpuAccelerationEnabled.rawValue] = decoderSettings.gpuAccelerationEnabled
        extras[OsirisBarcodeKey.quadrilateralBoundingBoxEnabled.rawValue] = boundingBoxSettings.isQuadrilateralEnabled
        
        /// Benchmark Settings
        extras[OsirisBarcodeKey.allowBenchmarking.rawValue] = benchmarkSettings.allowBenchmarking
        extras[OsirisBarcodeKey.benchmarkingOutputType.rawValue] = benchmarkSettings.benchmarkingOutputType
        
        let boundingBoxConfig: OsirisBoundingBoxConfig = boundingBoxSettings.defaultStyle == .yellow ? .init() : .init(borderColor: .white, backgroundColor: UIColor.white.withAlphaComponent(0.3), borderCornerRadius: 4)

        let userName = userDefaults.currentWalmartUser?.preferredUsername ?? "UnknownUser"
        return OsirisConfig(partnerID: "Diamond",
                            userID: userName,
                            symbologyGroup: .none,
                            hintGroup: .none,
                            scanActionType: decoderSettings.enabledScanActionType,
                            reticleConfig: reticleConfig,
                            cameraConfig: cameraConfig,
                            feedbackConfig: feedbackConfig,
                            dynamicConfig: dynamicConfig,
                            boundingBoxConfig: boundingBoxConfig,
                            extras: extras,
                            enableDisplayBoundingBox: boundingBoxTestMode == .sdk)
    }
    
    private func getFeedbackAudioURL(forBundle bundle: Bundle, 
                                     withName name: String = "scanbeep",
                                     extensionType: String = "wav") -> URL? {
        bundle.url(forResource: name, withExtension: extensionType)
    }
    
    deinit {
        Logging.log("...")
    }
}
