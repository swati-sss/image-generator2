//
//  Barcode.swift
//  Osiris
//
//  Created by Andres Vinueza on 9/12/23.
//

import Foundation

public typealias BarcodeBoundingBox = (barcode: Barcode, boundingBox: CGRect)

/// `Barcode` is the object containing decoded barcode information, including the value read from this barcode, it's symbology ( format of barcode ) and the bounds of the region of the screen that contains the barcode - both within the camera view itself and within the actual cropped image within the camera view.
public struct Barcode {
    /// This is the symbology of the barcode
    public let format: BarcodeFormat
    /// Axis-aligned bounds in camera-preview points, relative to the top-left of
    /// `OsirisScannerView.videoContainerView` (not the screen or its safe area).
    /// Crop offsets, aspect-fill scaling and front-camera mirroring are already applied.
    public var boundingBoxInCameraPreview: CGRect?
    /// This is the bounding box of the barcode within the Image fed to the decoder - these images may be cropped to a reticle, or may be at lower resolutions not matching the Camera Preview
    public let boundingBoxInPixelBuffer: CGRect?
    /// Corner points in full captured-image pixels, with a top-left origin.
    /// The applied decoder crop offset is included. Empty when quadrilateral output is disabled.
    public let quadPoints: [CGPoint]
    /// The same ordered corners in camera-preview points, ready for a host overlay.
    /// Uses the same space as `boundingBoxInCameraPreview`; empty when unavailable.
    /// Existing `quadPoints` continues to provide captured-image pixels.
    public let quadPointsInCameraPreview: [CGPoint]
    /// The decoded string value of the detected barcode
    public let value: String
    /// AIM/ISO-15424 symbology identifier reported by the decoder (e.g. "]C1", "]e0"). Empty string if unavailable.
    ///
    /// Structure: `]` + code character + modifier character, e.g. `]C1`:
    /// - `]` - fixed flag character. Signals "a symbology identifier follows", distinguishing it
    ///   from actual decoded barcode content. Chosen because `]` essentially never appears as the
    ///   first character of real scanned data, making it an unambiguous sentinel.
    /// - Code character (`C` above) - identifies the symbology family, e.g. `C` = Code 128,
    ///   `e` = GS1 DataBar, `d` = Data Matrix, `Q` = QR Code, `z` = Aztec, `A` = Code 39.
    /// - Modifier character (`1` above) - meaning is symbology-specific (e.g. whether a check
    ///   digit was validated, whether the symbol started with the FNC1 character, concatenation
    ///   mode). For several symbologies a specific modifier value flags GS1 data - see
    ///   `isGs1DataCarrier`.
    public let symbologyIdentifier: String

    /// `init` for Barcode
    /// - Parameter format: BarcodeFormat - the symbology of the barcode
    /// - Parameter boundingBoxInCameraPreview: CGRect? - the bounding box of the barcode within the Full Camera Preview  view that is visible to the User
    /// - Parameter boundingBoxInPixelBuffer: CGRect? -  the bounding box of the barcode within the Image fed to the decoder
    /// - Parameter value: String - the decoded string value of the detected barcode
    /// - Parameter symbologyIdentifier: String - AIM/ISO-15424 symbology identifier reported by the decoder
    /// - Parameter quadPointsInCameraPreview: Ordered corners in preview points, or an empty array when unavailable.
    public init(format: BarcodeFormat,
                boundingBoxInCameraPreview: CGRect? = nil,
                boundingBoxInPixelBuffer: CGRect? = nil,
                quadPoints: [CGPoint],
                value: String,
                symbologyIdentifier: String = "",
                quadPointsInCameraPreview: [CGPoint] = []) {
        self.format = format
        self.boundingBoxInCameraPreview = boundingBoxInCameraPreview
        self.boundingBoxInPixelBuffer = boundingBoxInPixelBuffer
        self.quadPoints = quadPoints
        self.quadPointsInCameraPreview = quadPointsInCameraPreview
        self.value = value
        self.symbologyIdentifier = symbologyIdentifier
    }

    /// Whether this barcode carries GS1 Application Identifier data (e.g. GTIN, expiration date,
    /// batch/lot, serial number) rather than a plain, non-GS1 payload of the same symbology.
    ///
    /// Determined by matching `symbologyIdentifier` against the AIM/ISO-15424 symbology identifiers
    /// that the GS1 General Specifications define as GS1 data carriers:
    /// - `]d2` - GS1 DataMatrix (Data Matrix that starts with the FNC1 character)
    /// - `]Q3` - GS1 QR Code (QR Code with FNC1 in the first position)
    /// - `]C1` - GS1-128 (Code 128 that starts with the FNC1 character)
    /// - `]e0` - GS1 DataBar (RSS) - this family only ever carries GS1 data
    ///
    /// `false` for any other symbology identifier, including non-GS1 reads of the same symbologies
    /// above (e.g. a plain Code 128 barcode reports `]C0`, not `]C1`) and for an empty/unavailable
    /// `symbologyIdentifier` - except for the GS1 DataBar family (see below). Note this does not
    /// parse out individual Application Identifiers (GTIN, expiration, batch, serial, etc.) from the
    /// value - it only flags that the barcode is a GS1 data carrier.
    ///
    /// GS1 DataBar (`.gs1databar`, `.gs1databarexpanded`, `.gs1databarlimited`) is always treated as
    /// a GS1 data carrier regardless of `symbologyIdentifier`, since that format family never
    /// carries non-GS1 content - this is a safety net in case the decoder omits the identifier.
    public var isGs1DataCarrier: Bool {
        Self.gs1DataBarFormats.contains(format) || Self.knownGs1SymbologyIdentifiers.contains(symbologyIdentifier)
    }

    /// The common retail Application Identifiers extracted from this barcode's GS1 data: AI (01)
    /// GTIN (via `gtinResult`), AI (10) batch/lot number, AI (17) expiration date, AI (21) serial
    /// number, AI (30) count of items, and AI (37) count of trade items in a logistic unit. This is
    /// the single place to read any of these values - there is no separate GTIN-only accessor.
    ///
    /// `nil` when this barcode is not a GS1 data carrier (see `isGs1DataCarrier`). Otherwise, each
    /// of the non-GTIN fields on the returned `GS1Data` is independently `nil` if that AI is absent
    /// from `value` - `gs1Data` is never `nil` itself just because, say, no batch/lot number was
    /// present. See `GS1Data.gtinResult`/`GS1Result` for the GTIN outcome, including why it may not
    /// have been extracted or may be an uncollapsed GTIN-14.
    public var gs1Data: GS1Data? {
        guard isGs1DataCarrier else { return nil }
        return GS1Parser.extractGS1Data(value)
    }

    /// Fixed reference table of AIM/ISO-15424 symbology identifiers that the GS1 General
    /// Specifications define as GS1 data carriers. This is NOT populated from zxing at runtime -
    /// it's a hardcoded allowlist, known ahead of time from the GS1/AIM spec, that the dynamic,
    /// per-scan `symbologyIdentifier` is checked against in `isGs1DataCarrier`.
    private static let knownGs1SymbologyIdentifiers: Set<String> = ["]d2", "]Q3", "]C1", "]e0"]

    /// GS1 DataBar formats always carry GS1 Application Identifier data by definition - see
    /// `isGs1DataCarrier`.
    private static let gs1DataBarFormats: Set<BarcodeFormat> = [.gs1databar, .gs1databarexpanded, .gs1databarlimited]
}

extension Barcode: Equatable {
    public static func == (lhs: Barcode, rhs: Barcode) -> Bool {
        lhs.value == rhs.value && lhs.format == rhs.format
    }
}

extension Barcode: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}
