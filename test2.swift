//
//  OsirisConfig.swift
//  Osiris
//
//  Created by Kyle McGinnis on 2/20/24.
//

import Foundation

/// `OsirisConfig` specifies all the settings for the Osiris barcode scanner.  Default values will work fine, but more fine-tuned control is possible - specifying regions of interest via the ReticleConfig, HintGroups ( image pre-processing strategies for better accuracy), and different SymbologyGroups (for a wider range of barcode decoding types).  `Extras` can be used for more specific and unconventional settings, sometimes reserved for embedding Apps with more permissions.
public class OsirisConfig: ObservableObject, CustomStringConvertible {
    
    // MARK: Properties
    
    @Published public internal(set) var partnerID: String
    @Published public internal(set) var userID: String
    @Published public internal(set) var symbologyGroup: SymbologyGroup
    @Published public internal(set) var hintGroup: HintGroup
    @Published public internal(set) var scanActionType: ScanActionType
    @Published public internal(set) var reticleConfig: OsirisReticleConfig
    @Published public internal(set) var cameraConfig: OsirisCameraConfig
    @Published public internal(set) var feedbackConfig: OsirisFeedbackConfig
    @Published public internal(set) var dynamicConfig: OsirisDynamicConfig
    @Published public internal(set) var boundingBoxConfig: OsirisBoundingBoxConfig

    /// Whether the SDK draws detected barcode boxes, including their labels and icons.
    /// Defaults to `true`. Set to `false` when the host app draws its own boxes using
    /// the geometry delivered by scanner callbacks. Detection and callbacks remain enabled;
    /// the aiming reticle is configured separately through `reticleConfig`.
    @Published public internal(set) var enableDisplayBoundingBox: Bool

    /// Dictionary containing  properties that may or may not be available based on Partner Permissions
    /// - Parameter hintsAdded: String Array - Hints to add to the enabled Hints, if permissions allow
    /// - Parameter hintsRemoved: String Array -  Hints to remove from the enabled Hints
    /// - Parameter symbologiesAdded: String Array -  Symbologies to add to the enabled Symbologies, if permissions allow
    /// - Parameter symbologiesRemoved: String Array - Symbologies to remove from the enabled Symbologies
    /// - Parameter allowBenchmarking: Bool - Turn on Benchmarking Output, if permissions allow
    /// - Parameter benchmarkingOutputType: String - Type of output for Benchmarking - disk, gcs, other
    /// - Parameter decoderType: String - Change Underlying Barcode Decoder, if permissions allow
    /// - Parameter gpuAccelerationEnabled: Bool - GPU cropping of camera pixelbuffer
    /// - Parameter multiScanEnabled: Bool - enabling multi-barcode scanning. Needed for ARUCO and VizPick support
    @Published public internal(set) var extras: [String: Any]

    // MARK: Lifecycle
    
    /// `init` for OsirisConfig
    /// - Parameter partnerID: String - ID of the App embedding Osiris - for analytics and permissions
    /// - Parameter userID: String - ID of the user currently running Osiris - for analytics
    /// - Parameter symbologyGroup: SymbologyGroup - maps to different numbers of symbologies to attempt to decode ( more advanced = more cpu )
    /// - Parameter hintGroup: HintGroup - maps to different numbers of hints ( image processing strategies ) to allow for better readability of barcodes ( more advanced = more cpu )
    /// - Parameter scanActionType: ScanActionType - Single scan ( 1 barcode read and decoding stops ) or continuous scan ( keep scanning )
    /// - Parameter reticleConfig: OsirisReticleConfig - the Reticle configuration setup for barcode scanner
    /// - Parameter cameraConfig: OsirisCameraConfig - the Camera configuration setup for barcode scanner
    /// - Parameter feedbackConfig: OsirisFeedbackConfig - maps different FeedbackEvents to sound/haptic feedback
    /// - Parameter dynamicConfig: OsirisDynamicConfig - allows properties to be changed while the Scanner is running
    /// - Parameter extras: [String: Any] - Dictionary containing  properties that may or may not be available based on Partner Permissions
    /// - Parameter enableDisplayBoundingBox: Whether the SDK draws detected barcode boxes. Defaults to `true`; disabling it preserves detection and geometry callbacks.
    public init(partnerID: String = "",
                userID: String = "",
                symbologyGroup: SymbologyGroup = .basic,
                hintGroup: HintGroup = .basic,
                scanActionType: ScanActionType = .single,
                reticleConfig: OsirisReticleConfig = .init(),
                cameraConfig: OsirisCameraConfig = .init(),
                feedbackConfig: OsirisFeedbackConfig = .init(),
                dynamicConfig: OsirisDynamicConfig = .init(),
                boundingBoxConfig: OsirisBoundingBoxConfig = .init(),
                extras: [String: Any] = [:],
                enableDisplayBoundingBox: Bool = true) {
        self.partnerID = partnerID
        self.userID = userID
        self.symbologyGroup = symbologyGroup
        self.hintGroup = hintGroup
        self.scanActionType = scanActionType
        self.reticleConfig = reticleConfig
        self.cameraConfig = cameraConfig
        self.feedbackConfig = feedbackConfig
        self.dynamicConfig = dynamicConfig
        self.boundingBoxConfig = boundingBoxConfig
        self.extras = extras
        self.enableDisplayBoundingBox = enableDisplayBoundingBox
    }
    
    public var description: String {
        let result: String = "\nOsirisConfig:\n" +
        "   partnerID: \(partnerID)\n" +
        "   userID: \(userID)\n" +
        "   symbologyGroup: \(symbologyGroup)\n" +
        "   hintGroup: \(hintGroup)\n" +
        "   scanActionType: \(scanActionType)\n" +
        "   reticleConfig: \(reticleConfig)\n" +
        "   cameraConfig: \(cameraConfig)\n" +
        "   feedbackConfig: \(feedbackConfig)\n" +
        "   dynamicConfig: \(dynamicConfig)\n" +
        "   enableDisplayBoundingBox: \(enableDisplayBoundingBox)\n" +
        "   extras: \(extras)\n"
        return result
    }
    
    // MARK: Public API
    
    /// This will return an Array with Unique items - used for quick extras processing of Enums
    /// - Parameter addedExtrasKey: `String` - This key maps to the [String] rawValues of the added items in the `extras`
    /// - Parameter removedExtrasKey: `String` - This key maps to the [String] rawValues of the removed items in the `extras`
    /// - Parameter initialItems: `[T]` -  This generic array of enums sets the type of the return value
    /// - Returns: `[T]` - Returns the filtered items after adding and removing enums, where `T` is the type of `initialItems`
    public func getFilteredExtras<T: RawRepresentable & Hashable>(addedExtrasKey: String,
                                                                  removedExtrasKey: String,
                                                                  initialItems: [T]) -> [T] where T.RawValue == String {
        var filteredItems = initialItems
        if let addedItems = self.extras[addedExtrasKey] as? [String] {
            for itemName in addedItems {
                if let item = T(rawValue: itemName) {
                    filteredItems.append(item)
                }
            }
        }
        if let removedItems = self.extras[removedExtrasKey] as? [String] {
            for itemName in removedItems {
                if let item = T(rawValue: itemName) {
                    filteredItems = filteredItems.filter { $0 != item }
                }
            }
        }
        return Array(Set(filteredItems)).sorted { $0.rawValue < $1.rawValue }
    }
}
