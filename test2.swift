![Alamofire: Elegant Networking in Swift](https://gecgithub01.walmart.com/storage/user/87060/files/8a578191-4d59-46f9-b24e-d3a068bbf075)
[![Sonar](https://img.shields.io/badge/Sonar-Dashboard-blue)](https://sonar.prod.walmartlabs.com/dashboard?id=diamond.osiris.ios)
[![Build Status](https://ci.walmart.com/buildStatus/icon?=job/project-diamond/job/diamond-apps/job/osiris-ios)](https://ci.walmart.com/job/project-diamond/job/diamond-apps/job/osiris-ios/)
[![Version](https://img.shields.io/badge/version-2026.09.17.1-blue.svg)](https://gecgithub01.walmart.com/Project-Diamond/osiris-ios/releases)
[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://ci.walmart.com/job/project-diamond/job/diamond-apps/job/osiris-ios/)
[![Swift](https://img.shields.io/badge/Swift-5.3-orange.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-orange?style=flat-square)](https://img.shields.io/badge/SPM-compatible-orange?style=flat-square)
[![CocoaPod](https://img.shields.io/badge/CocoaPod-compatible-red?style=flat-square)](https://img.shields.io/badge/CocoaPod-compatible-red?style=flat-square)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://gecgithub01.walmart.com/Project-Diamond/osiris-ios/blob/main/LICENSE)

# Osiris SDK

Our **Osiris SDK** leverages the power of computer vision to enable advanced barcode scanning, item recognition, and object detection capabilities, offering a comprehensive solution for developers aiming to enhance retail applications

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Releasing a New Version](#releasing-a-new-version)
- [Updating OD (Object Detection) model](#updating-od-object-detection-model)
- [Contributing](#contributing)
- [License](#license)
- [Maintainers](#maintainers)
- [Acknowledgements](#acknowledgements)

## Features

###  🚧 Currently in Alpha 🚧

| Private/Internal | Library Name | Public/External | Library Name |
| --- | --- | --- | --- |
| Core | Osiris | Barcode | OsirisBarcode |
| Camera | OsirisCamera | | |
| Machine Learning | OsirisVision | | |

## Requirements

- iOS 15.1+
- Xcode 26.3+
- Swift 5.3+

> **Known limitation:** the bundled `zxing-cpp` xcframework is built with Xcode 26 and is binary-incompatible below iOS 26 - `.zxing` is currently the **only** `BarcodeDecoderType`, and `BarcodeDecoderManager.buildDecoder(forType: .zxing, ...)` crashes at runtime on iOS 15.1-18.x despite the 15.1 deployment target compiling and installing cleanly (see [PR #365](https://gecgithub01.walmart.com/Project-Diamond/osiris-ios/pull/365) for background - CI only ever runs tests on an iOS 26 simulator, so this is unvalidated by CI either way). **If your app needs to support iOS below 26, do not ship barcode decoding with this SDK version until this is resolved upstream.**

## Installation

### Swift Package Manager

You can use [The Swift Package Manager](https://swift.org/package-manager/) to install `Osiris` by adding the proper description to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "git@gecgithub01.walmart.com:Project-Diamond/osiris-ios.git", from: "2026.09.17.1")
]
```
or 

Through Xcode by adding the package in _Package Dependencies_, using our repository URL, and selecting the specific Osiris libraries you would like to include to your project target.

### CocoaPods

You can use [CocoaPods](https://cocoapods.org/) to install `Osiris` by specifiying the library via your `Podfile`:

```ruby
source 'git@gecgithub01.walmart.com:Project-Diamond/cocoapods-specs.git'
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '15.1'
use_frameworks!

target '<Your Target Name>' do
    pod 'Osiris', "2026.09.17.1"
    pod 'OsirisBarcode', "2026.09.17.1"
    pod 'OsirisCamera', "2026.09.17.1"
    pod 'OsirisDigitalLocks', "2026.09.17.1"
end
```

Then, run the following command:

```bash
$ pod install
```

**Note**: Our library is distributed through a [private podspec repo](https://guides.cocoapods.org/making/private-cocoapods.html) so adding `source 'git@gecgithub01.walmart.com:Project-Diamond/cocoapods-specs.git'` is essential to be able to successfully download the dependency.

#### Using a branch (unreleased/unpublished changes)

To consume osiris-ios straight from a git branch instead of a published version — e.g. to test a feature branch in a consumer app before it's released — point each pod at `:git`/`:branch` instead of a version string:

```ruby
target '<Your Target Name>' do
    pod 'Osiris', :git => 'git@gecgithub01.walmart.com:Project-Diamond/osiris-ios.git', :branch => 'feature/BPD-12345-my-change'
    pod 'OsirisBarcode', :git => 'git@gecgithub01.walmart.com:Project-Diamond/osiris-ios.git', :branch => 'feature/BPD-12345-my-change'
    pod 'OsirisCamera', :git => 'git@gecgithub01.walmart.com:Project-Diamond/osiris-ios.git', :branch => 'feature/BPD-12345-my-change'
    pod 'OsirisDigitalLocks', :git => 'git@gecgithub01.walmart.com:Project-Diamond/osiris-ios.git', :branch => 'feature/BPD-12345-my-change'
end
```

This reads the podspecs committed on that branch directly — it bypasses the private spec repo entirely, so you get whatever `spec.version`/zxing dependency is in that branch's podspecs, not what's published. Run `pod install` to fetch; `pod update Osiris OsirisBarcode OsirisCamera OsirisDigitalLocks` to pull in new commits pushed to the branch afterward.

#### Using a local checkout (iterating on osiris-ios itself)

To test local, possibly-uncommitted osiris-ios changes against a consumer app (e.g. diamond-ios-sdk) without pushing anything, point each pod at `:path` instead:

```ruby
target '<Your Target Name>' do
    pod 'Osiris', :path => '../osiris-ios'
    pod 'OsirisBarcode', :path => '../osiris-ios'
    pod 'OsirisCamera', :path => '../osiris-ios'
    pod 'OsirisDigitalLocks', :path => '../osiris-ios'
end
```

`:path` is relative to the `Podfile`'s location and must point at the local osiris-ios checkout's root (where the `.podspec` files live). CocoaPods symlinks the pod directly to that working tree, so any edit you make locally is picked up on the next `pod install` — no commit/push needed, which makes this the fastest loop for iterating on osiris-ios changes while validating them against a real consumer app. Revert the `Podfile` and re-run `pod install` once you're done to go back to the published version.

### Direct XCFramework (e.g. Glass)

For native integrations that don't want CocoaPods/SPM, a single static `OsirisKit.xcframework` - combining `Osiris` + `OsirisBarcode` + `OsirisCamera` (device + simulator slices, resource bundles embedded) - is published to Artifactory on every release:

```
https://generic.ci.artifacts.walmart.com/artifactory/project-diamond-generic/osiris-ios/xcframework-iOS-OsirisKit-<version>.zip
```

Since this ships as a static-framework-style xcframework (not a plain `.a` + headers), Xcode's native "Frameworks, Libraries, and Embedded Content" UI doesn't cleanly auto-resolve the 3 bundled Swift modules on its own (it only reliably handles a single primary module matching the framework's name). Add these per-SDK-conditioned build settings instead (confirmed against a real external sample app with a live `OsirisCamera` scanner screen):

| Setting | iOS device (`sdk=iphoneos*`) | iOS Simulator (`sdk=iphonesimulator*`) |
|---|---|---|
| `SWIFT_INCLUDE_PATHS` | `.../OsirisKit.xcframework/ios-arm64/OsirisKit.framework/Modules` | `.../OsirisKit.xcframework/ios-arm64_x86_64-simulator/OsirisKit.framework/Modules` |
| `FRAMEWORK_SEARCH_PATHS` | `$(inherited) .../OsirisKit.xcframework/ios-arm64` | `$(inherited) .../OsirisKit.xcframework/ios-arm64_x86_64-simulator` |
| `OTHER_LDFLAGS` | `-lc++ -lz -framework OsirisKit` | `-lc++ -lz -framework OsirisKit` |

`-lc++`/`-lz`: the bundled zxing-cpp/OpenCV code needs the C++ stdlib and zlib explicitly - a pure-Swift app target doesn't pull them in automatically. Fonts/colors/images/sound resolve automatically once these are set - no separate resource bundle wiring needed.

## Usage

### Host-app-drawn bounding boxes

Set `OsirisConfig(enableDisplayBoundingBox: false)` to let the host app draw barcode
outlines. The default is `true`, preserving SDK drawing. Barcode detection and
geometry callbacks continue in either mode. Disabling SDK drawing removes its
barcode boxes, labels, and icons. The aiming reticle is configured separately.

The following instructions add host drawing to an existing scanner screen. Keep
the host's existing camera-permission, scanner embedding, and start/stop setup.
The screen should already conform to `OsirisScannerDelegate`.

#### 1. Configure the scanner

Add `enableDisplayBoundingBox: false` to the host's existing configuration,
preserving its other settings. For example:

```swift
import UIKit
import Osiris
import OsirisBarcode
import OsirisCamera

let context = OsirisDataCaptureContext()
let config = OsirisConfig(enableDisplayBoundingBox: false)
OsirisApp.configure(withConfig: config, context: context)

let scanner = OsirisScannerViewController(context: context)
scanner.delegate = self // The existing host screen implementing OsirisScannerDelegate.
```

Set the delegate immediately after creating the scanner. To receive four corners
as well as a rectangle, use the following configuration instead, retaining any
existing entries in the host's `extras` dictionary:

```swift
var extras: [String: Any] = [:]
extras[OsirisBarcodeKey.quadrilateralBoundingBoxEnabled.rawValue] = true
let config = OsirisConfig(extras: extras, enableDisplayBoundingBox: false)
OsirisApp.configure(withConfig: config, context: context)
```

Rectangle drawing works without the quadrilateral option.

#### 2. Use preview coordinates

| Property | Coordinate space |
| --- | --- |
| `boundingBoxInCameraPreview` | Axis-aligned rectangle in points, relative to the top-left of `scanner.scannerView?.videoContainerView`. |
| `quadPointsInCameraPreview` | Four ordered corners in the same preview-local points, when available. |
| `boundingBoxInPixelBuffer` | Rectangle in pixels of the decoder's input image; if that image was cropped, these coordinates are local to the crop. |
| `quadPoints` | Corners in pixels of the full captured image, including any applied crop offset. |

Use the first two properties for drawing over the preview. Crop offsets,
aspect-fill scaling, and front-camera mirroring are already applied; do not apply
them again. Corner arrays are empty when quadrilateral output is disabled.
Preview coordinates are not screen coordinates. If drawing in another view,
convert the points or rectangle from `videoContainerView` into that view first.

#### 3. Add a host overlay view

This example draws a closed outline from the preview corners, falling back to a
rectangle. The overlay does not intercept touches, so the scanner's controls and
tap-to-focus remain accessible. Clipping keeps outlines inside the visible preview.

```swift
final class HostBarcodeOverlay: UIView {
    private let outlineLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        outlineLayer.fillColor = UIColor.clear.cgColor
        outlineLayer.strokeColor = UIColor.systemBlue.cgColor
        outlineLayer.lineWidth = 2
        layer.addSublayer(outlineLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        outlineLayer.frame = bounds
    }

    func display(_ barcodes: [Barcode]) {
        let path = UIBezierPath()
        for barcode in barcodes {
            let corners = barcode.quadPointsInCameraPreview
            if corners.count == 4 {
                path.move(to: corners[0])
                for point in corners.dropFirst() {
                    path.addLine(to: point)
                }
                path.close()
            } else if let rect = barcode.boundingBoxInCameraPreview {
                path.append(UIBezierPath(rect: rect))
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outlineLayer.path = path.cgPath
        CATransaction.commit()
    }
}
```

In the existing host screen, retain an overlay and install it once after creating
the scanner. Pin it to the preview so its local coordinates and size match:

```swift
private let barcodeOverlay = HostBarcodeOverlay(frame: .zero)

private func installBarcodeOverlay(on scanner: OsirisScannerViewController) {
    scanner.loadViewIfNeeded()
    guard let preview = scanner.scannerView?.videoContainerView else { return }

    barcodeOverlay.translatesAutoresizingMaskIntoConstraints = false
    preview.addSubview(barcodeOverlay)
    NSLayoutConstraint.activate([
        barcodeOverlay.leadingAnchor.constraint(equalTo: preview.leadingAnchor),
        barcodeOverlay.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
        barcodeOverlay.topAnchor.constraint(equalTo: preview.topAnchor),
        barcodeOverlay.bottomAnchor.constraint(equalTo: preview.bottomAnchor)
    ])
}
```

Call `installBarcodeOverlay(on: scanner)` during the host screen's setup, after
setting the scanner delegate and before starting scanning.

#### 4. Draw each result update

Implement this method in the host's existing `OsirisScannerDelegate` conformance:

```swift
func didDetectBarcodes(
    _ barcodes: [Barcode],
    setBoundingBoxesSettings: @escaping ([BarcodeValue: OsirisBoundingBoxConfig]) -> Void
) {
    barcodeOverlay.display(barcodes)
}
```

This callback is delivered on the main queue, including when SDK drawing is
disabled. Its settings completion customizes SDK artwork; a host drawing its own
outlines does not need to call it. Change the host overlay's stroke, fill, or other
drawing properties to apply the host's design. Host-box taps or other custom
interactions must also be handled by the host.

#### 5. Clear old outlines

Always pass empty result arrays to `display` too: the example replaces the path
with an empty one, removing previous outlines. Callback timing and existing
empty-frame filtering are unchanged; callbacks are not guaranteed for every
camera frame. Also call `barcodeOverlay.display([])` on the main queue when the
host stops scanning or leaves the scanner screen, so it does not depend on a
further detection callback to clear its artwork.

### OsirisBarcode
```swift
import OsirisBarcode

/// Build decoder to process any pixelBuffer
let decoder = BarcodeDecoderManager.buildDecoder(forType: .zxing, options: .defaultOptions)
let barcode =  decoder.decode(pixelBuffer)

```

### Osiris

```swift
import Osiris

/// Create OsirisDataCaptureContext to allow for configuring one or multiple scanners with different IDs/app locations
let context: OsirisDataCaptureContext = .init()

/// Fine-Tuned Configuration of SDK
let config = try await fetchOsirisConfig()
OsirisApp.configure(withConfig: config, context: context)

private func fetchOsirisConfig() async throws -> OsirisConfig {
    /// EXAMPLE Settings to contain properties for Configs
    let cameraSettings = try await EXAMPLEBarcodeSettingsService.shared.fetchCameraSettings()
    let decoderSettings = try await EXAMPLEBarcodeSettingsService.shared.fetchDecoderSettings()
    let benchmarkSettings = try await EXAMPLEBarcodeSettingsService.shared.fetchBenchmarkSettings()
    
    /// PartnerID - the ID of the app embedding the SDK, for permissions/analytics
    let partnerID = "EXAMPLEPartnerID"
        
    /// UserID - the ID of the current user of the App embedding the SDK, for permissions/analytics
    let userID = "EXAMPLEUserID"
    
    /// SymbologyGroup - Group signifying increasing amounts of barcode symbologies able to be decoded
    let symbologyGroup: SymbologyGroup = .intermediate
    
    /// HintGroup - Group signifying increasing complexity of methods used to adjust the image to be more readable for the decoder
    let hintGroup: HintGroup = .basic

    /// OsirisReticleConfig setup 
    let reticleType: ReticleType = .rectangle
    let reticleConfig: OsirisReticleConfig = .init(reticleType: reticleType, scanArea: .center)
    
    /// OsirisCameraConfig setup
    let cameraConfig: OsirisCameraConfig = .init(resolution: cameraSettings.selectedCaptureSessionPreset,
                                                 deviceType: cameraSettings.selectedCaptureDeviceType)
    
    /// OsirisFeedbackConfig setup
    let feedbackURL: URL? = EXAMPLELocalURLforAudioFile
    let feedbackConfig: OsirisFeedbackConfig = .init(eventFeedback: [.success: .init(vibration: .medium, sound: feedbackURL)])

    /// OsirisDynamicConfig setup
    let dynamicConfig: OsirisDynamicConfig = .init(throttleBetweenSameBarcodeValuesMillis: 2000,
                                                   zoomPercentage: 25,
                                                   readDistanceMode: .fullRange,
                                                   enableTorch: false,
                                                   enableLogging: false)
    
    /// Extras dictionary setup - fine-tuned detail properties that may or may not be available to the embedding app
    var extras: [String: Any] = [:]
    // For custom Symbologies and Hints - otherwise just use the symbologyGroup and hintGroup properties
    let symbologies: [String] = decoderSettings.enabledBarcodeFormats.map { $0.rawValue }
    let hints: [String] = decoderSettings.enabledBarcodeDecoderHints.map { $0.rawValue }
    let symbologiesRemoved: [String] = []
    let hintsRemoved: [String] = []
    extras[OsirisBarcodeKey.symbologiesAdded.rawValue] = symbologies
    extras[OsirisBarcodeKey.symbologiesRemoved.rawValue] = symbologiesRemoved
    extras[OsirisBarcodeKey.hintsAdded.rawValue] = hints
    extras[OsirisBarcodeKey.hintsRemoved.rawValue] = hintsRemoved
    extras[OsirisBarcodeKey.allowBenchmarking.rawValue] = benchmarkSettings.allowBenchmarking
    extras[OsirisBarcodeKey.benchmarkingOutputType.rawValue] = benchmarkSettings.isDiskOutputEnabled ? "disk" : "gcs"
    extras[OsirisBarcodeKey.decoderType.rawValue] = decoderSettings.enabledDecoderType.rawValue
    extras[OsirisBarcodeKey.gpuAccelerationEnabled.rawValue] = decoderSettings.gpuAccelerationEnabled
    
    return OsirisConfig(partnerID: partnerID,
                        userID: userID,
                        symbologyGroup: symbologyGroup,
                        hintGroup: hintGroup,
                        scanActionType: decoderSettings.enabledScanActionType,
                        reticleConfig: reticleConfig,
                        cameraConfig: cameraConfig,
                        feedbackConfig: feedbackConfig,
                        dynamicConfig: dynamicConfig,
                        extras: extras)
}

/// Simple Configuration of SDK
OsirisApp.configure(context: context)

/// Get config associated with a context
let config = OsirisApp.shared.getConfig(forContext: context)

/// Remove config associated with a context
OsirisApp.shared.removeConfig(forContext: context)

// Dynamic Configuration - able to be changed during the same scanning session without needing a scanner restart

/// Enable/Disable Torch
let torchEnabled = true
try OsirisApp.setEnableTorch(torchEnabled, context: context)

/// Adjust throttling between same barcode values dynamically
try OsirisApp.setThrottleBetweenSameBarcodeValuesMillis(1000, context: context)
    
/// Adjust max cpu percentage allowed by the embedding app before automatic throttling is attempted ( NOT CURRENTLY WORKING )
try OsirisApp.setMaxCPUPercentage(80, context: context)

/// Adjust zoom percentage for the active camera in the scanner
try OsirisApp.setZoomPercentage(25, context: context)

/// Adjust read distance mode to allow more accurate reads from desired distance ( NOT CURRENTLY WORKING )
try OsirisApp.setReadDistanceMode(.fullRange, context: context)

/// Enabled/disable logging of detailed lifecycle events in the SDK ( NOT CURRENTLY WORKING )
try OsirisApp.setEnableLogging(true, context: context)

/// Adjust dynamic extras dictionary while scanner is in progress - fine-tuned properties that may or may not be available to the embedding app.
var dynamicExtras = config.dynamicConfig.extras
dynamicExtras[OsirisBarcodeKey.benchmarkingIsRunning.rawValue] = isRecording
try OsirisApp.setDynamicExtras(dynamicExtras, context: context)

```

### OsirisCamera

```swift
import OsirisCamera

/// Create OsirisScannerViewController
let scannerVC = OsirisScannerViewController(context: state.context)

/// Setup OsirisScannerViewController delegate
scannerVC.delegate = self

/// Before Scanning - First Configure Osiris with the context for this scanner
OsirisApp.configure(withConfig: config, context: context)

/// Start Scanning - also starts camera automatically
scannerVC.startScanning()

/// Stop Scanning ( not required to call - automatically handled by ScanActionType ( single vs continuous ), but this allows more control )
scannerVC.stopScanning()

/// start Camera ( not required to call - automatically called by startScanning )
scannerVC.startCamera()

/// stop Camera ( not required to call - automatically called during viewWillDisappear )
scannerVC.stopCamera()

/// Get the decoder ID of the scanner in use
scannerVC.decoderID

/// Is the camera currently running
scannerVC.cameraIsRunning

/// Is the scanner currently running
scannerVC.scannerIsRunning

/// OsirisScannerDelegate Methods
extension EXAMPLEViewController: OsirisScannerDelegate {
    
    func didFireEvent(_ event: OsirisCamera.OsirisEvent) {
        // Process OsirisCamera.OsirisEvents
    }
    
    func didReceiveError(_ error: Error) {
        // Process Errors
    }
    
    func didDetectBarcode(_ barcode: Barcode) {
        // Process successful Barcode detection
    }
    
}

/// Cleanup Config after this controller is done
deinit {
    OsirisApp.shared.removeConfig(forContext: context)
}

```

#### Extracting GS1 Data (GTIN, batch/lot, expiry, serial, etc.)

`Barcode.gs1Data` is `nil` for non-GS1 barcodes; for GS1 data carriers it returns a `GS1Data` with each Application Identifier extracted independently. `gtinResult` carries the GTIN-specific outcome (normalized value, or why it wasn't extracted/normalized) since GTIN is the only AI with a checkable checksum - the other AIs are plain optional strings, `nil` only if that AI wasn't present.

```swift
extension EXAMPLEViewController: OsirisScannerDelegate {

    func didDetectBarcode(_ barcode: Barcode) {
        guard let gs1 = barcode.gs1Data else {
            // Not GS1 - handle as a plain 1D/2D scan, same as before this feature existed
            handlePlainScan(barcode.value, format: barcode.format)
            return
        }

        switch gs1.gtinResult {
        case .success(let gtin, let warning):
            if warning == .cannotNormalize {
                // Rare: GTIN-14 with a non-zero indicator digit, couldn't collapse to UPC-A/EAN-13
                Logging.log("Uncollapsed GTIN-14: \(gtin)", logLevel: .warning)
            }
            lookupProduct(byGTIN: gtin)

        case .error(.noGTIN):
            showScanError("GS1 barcode has no product identifier (AI 01).")

        case .error(.invalidCheckDigit):
            showScanError("Scan failed validation - please rescan.")
        }

        // Independent of whether GTIN succeeded - these are separate AIs
        if let lot = gs1.lotNumber { applyBatchInfo(lot) }
        if let expiry = gs1.expirationDate { applyExpiration(expiry) }
    }
}
```

## Releasing a New Version

Versions follow the format `YYYY.MM.SS.BB` (Year · Month · Sprint · Build, e.g. `2026.09.16.2`).

There are two ways to cut a release: the **automated** scripts below (recommended for routine releases), or the **manual** steps they wrap, if you need to deviate from what the scripts do or they're unavailable.

### CHANGELOG entry format

Referenced by both the automated and manual processes below.

```markdown
## [2026.09.16.2](https://gecgithub01.walmart.com/Project-Diamond/osiris-ios/releases/tag/2026.09.16.2)

Released on 2026-09-10

#### Added

- Short description of what changed
```

### Automated process (recommended)

#### Release scripts

`release-non-ml.sh` and `release-ml.sh` take no flags — run either with no arguments and they prompt for everything up front, one item at a time (osiris version, zxing version, ticket, then commit message, PR title, PR description - defaults provided for the last three, just press enter to accept each). After that, they run unattended: create the `release/VERSION` branch, bump every file below, run tests + a device archive, stage everything, then show a **final review screen** with every value you entered plus a `y/n` gate before touching git.

Both scripts behave identically at this point — **both** commit, push `release/<version>`, and open a **draft** PR to `main` (`gh pr create --draft`) using the standard template. The draft PR is for visibility/review only: it's never auto-merged, and ML work specifically must never merge to `main` — the branch push is what actually drives the release (see below), the PR is just a reviewable record of it.

Answering anything but `y`/`Y` at the final prompt leaves everything staged and prints the exact commands to finish manually.

```bash
./release-non-ml.sh
# Osiris version (e.g. 2026.09.18.1): 2026.09.16.2
# Zxing version (e.g. 2026.09.18.3): 2026.09.16.21
# Ticket (e.g. BPD-12345): BPD-12345
# ... commit message / PR title / PR description prompts ...

./release-ml.sh
# Osiris version (e.g. 2026.09.18.2-ml): 2026.09.16.3-ml
# Zxing version (e.g. 2026.09.18.4): 2026.09.16.22
# Ticket (e.g. BPD-12345): BPD-12345
# ... commit message / PR title / PR description prompts ...
```

The ticket is used in the commit message and PR title/body — it does **not** go in the branch name, which stays `release/<version>`.

> **Before you confirm:** the final review screen warns you that pushing `release/<version>` **automatically triggers Looper's `updateSpecs` job** — it publishes the podspecs to the private CocoaPods spec repo **and** builds + publishes `OsirisKit.xcframework` to Artifactory, unconditionally, with no separate manual step and no undo. Answering `y` is a real, production-affecting action, not a dry run — double-check every value shown (not just the ones you typed last) before confirming.

| File | Non-ML | ML |
|---|---|---|
| `Osiris/OsirisBarcode/OsirisCamera/OsirisDigitalLocks.podspec` | ✅ | ✅ |
| `Sources/Osiris/OsirisBuildInfo.swift` | ✅ | ✅ |
| `CHANGELOG.md` | ✅ (skeleton entry — edit the bullet if this is more than a routine zxing bump) | ✅ |
| `Package.swift` | ✅ | ❌ stays on the stable non-ML xcframework — see [ML releases](#ml-releases) |
| `README.md` version badge + SPM/CocoaPods install snippets | ✅ | ❌ |

> **Note:** `BluetoothPlatform.podspec` is maintained separately by `@iot-bt-devs`. Both scripts touch it (the underlying version bump is shared across all 5 podspecs) and then revert it automatically — it is never left modified or published by the standard release lane.

Both scripts are thin wrappers around `podspec-util.sh`, which can also be run standalone for a one-off change:

| `podspec-util.sh` flag | Updates |
|---|---|
| `--version VERSION` | `spec.version` in all 5 podspecs + `osirisPodVersion` in `OsirisBuildInfo.swift` |
| `--zxing VERSION` | `spec.dependency 'zxing-cpp'` in `OsirisBarcode.podspec` (the only podspec that declares it) + `zxingCppVersion` in `OsirisBuildInfo.swift` |
| `--deployment-target [VERSION]` | `spec.platform`/`spec.ios.deployment_target` in the 4 lockstep podspecs + `Package.swift`'s platform — omit the value to apply `build-config.env`'s `IOS_DEPLOYMENT_TARGET` |
| `--package-swift-zxing VERSION` | Downloads the zxing-cpp xcframework zip, computes its SHA-256, and updates `Package.swift`'s `url`/`checksum` — **non-ML only**, see below |
| `--lint PODSPEC` / `--push` | Lints / publishes podspecs to the private spec repo |

`build-config.env` holds settings that are stable across releases (deployment target, the Artifactory base URL, the private pod repo name) — not the osiris/zxing version numbers themselves, which change on every release and are always passed as arguments instead of being persisted.

#### Non-ML releases

Non-ML releases are the default, standard production release — the version used by most consumers (both SPM and CocoaPods). `release-non-ml.sh` enforces this: it **rejects** any version you enter that ends in `-ml` (use `release-ml.sh` instead). It consumes a non-ML zxing-cpp build (odd last digit, e.g. `2026.09.16.33` — the intelligence team's upstream convention) and updates **both** `Package.swift` and the `README.md` version badge/SPM/CocoaPods install snippets, in addition to the podspecs/`OsirisBuildInfo.swift`/`CHANGELOG.md` every release touches. Unlike ML releases, the draft PR this script opens to `main` is meant to actually be merged once CI passes — it's a normal release PR, not a visibility-only artifact.

#### ML releases

ML releases consume an ML-tagged zxing-cpp build (`spec.dependency 'zxing-cpp', '<version>'` in `OsirisBarcode.podspec`) but **`Package.swift` stays on the last stable non-ML xcframework**. SPM consumers never get ML this way — only CocoaPods consumers who pin the `-ml` osiris version explicitly do. Only re-point `Package.swift` at an ML zxing build after re-validating it doesn't have the `_kai_*`/`onnx_non_quantized_model` symbol issues that affected ML builds before `.36` (device archive of the `OsirisBarcode`/`OsirisCamera` schemes + a CocoaPods build against diamond-ios-sdk).

#### Automated release steps

1. Run the release script from an up-to-date `main` (no flags — it prompts for everything):
   ```bash
   # VERSION format: YYYY.MM.SS.BB  (Year · Month · Sprint · Build)
   git checkout main && git pull
   ./release-non-ml.sh
   ```

2. Answer the prompts in order (defaults shown in brackets — press enter to accept):
   ```
   Osiris version (e.g. 2026.09.18.1): 2026.09.16.2
   Zxing version (e.g. 2026.09.18.3): 2026.09.16.21
   Ticket (e.g. BPD-12345): BPD-12345
   Commit message [[BPD-12345] Release 2026.09.16.2: update zxing-cpp to 2026.09.16.21]:
   PR title [[BPD-12345] Release 2026.09.16.2: update zxing-cpp to 2026.09.16.21]:
   PR description (what changed/why, beyond the routine zxing bump - blank is fine):
   ```
   The script then runs unattended — bumps files, runs tests, builds a device archive, stages everything — and shows you the staged diff. Edit `CHANGELOG.md`'s bullet now if needed, then review the **final review screen** (every value you entered, plus a warning about what pushing does) and confirm `y`.

   Confirming commits, pushes `release/<version>`, and opens a **draft** PR to `main` using the standard template.

   Pushing `release/<version>` **automatically triggers the `updateSpecs` Looper flow**, which publishes the podspecs to the private CocoaPods spec repo **and** builds + publishes `OsirisKit.xcframework` to Artifactory — no merge to `main` is needed first, and the draft PR has no effect on this (the push is what triggers it, not the PR). If the branch doesn't show up as a Looper build within a few minutes, push an empty commit to retry: `git commit --allow-empty -m retry && git push`.

3. Verify the podspecs landed (see [Verifying the release](#verifying-the-release)), then wrap the auto-created tag in a GitHub release at `https://gecgithub01.walmart.com/Project-Diamond/osiris-ios/releases/new`:
   - Tag: select the existing tag (e.g. `2026.09.16.2`) — **do not create a new one**
   - Title: `2026.09.16.2`
   - Description: paste the CHANGELOG entry for this version

**ML releases never merge to `main`** — the `release/*` branch push is the entire release mechanism, same as above. `release-ml.sh` opens a draft PR too (for visibility only, same as non-ML), but it must never be marked ready for review or merged — only CI's `updateSpecs` flow is allowed to act on an ML release branch, and it creates the version tag itself (same push-triggers-CI behavior as step 2 above).

### Manual process

The scripts above are a convenience wrapper around these same steps — use this if you need to deviate from what they do (e.g. a one-off fix) or they're unavailable. These steps describe a non-ML release; for an ML (`-ml`) release, skip the `Package.swift` update and see [ML releases](#ml-releases) above.

#### Files to update before releasing

| File | What to change |
|---|---|
| `Osiris.podspec` | `spec.version` |
| `OsirisBarcode.podspec` | `spec.version` and `spec.dependency 'zxing-cpp', '<version>'` if zxing-cpp changed |
| `OsirisCamera.podspec` | `spec.version` |
| `OsirisDigitalLocks.podspec` | `spec.version` |
| `Sources/Osiris/OsirisBuildInfo.swift` | `osirisPodVersion` and `zxingCppVersion` (if zxing-cpp changed) |
| `CHANGELOG.md` | Add new entry at the top (see [format above](#changelog-entry-format)) |
| `Package.swift` | `url` and `checksum` for the `ZXingCpp` binary target (only if zxing-cpp changed) |

> **Note:** `BluetoothPlatform.podspec` is maintained separately by `@iot-bt-devs` and is **not** published by the standard release lane.

#### Updating zxing-cpp

When bumping the `zxing-cpp` dependency version in `OsirisBarcode.podspec`:

1. Confirm the new version is published to the private CocoaPods spec repo:
   ```bash
   pod repo update walmart-project-diamond-cocoapods-specs
   ls ~/.cocoapods/repos/walmart-project-diamond-cocoapods-specs/zxing-cpp/<new-version>/
   ```
2. Update `spec.dependency 'zxing-cpp', '<new-version>'` in `OsirisBarcode.podspec`
3. Update `zxingCppVersion` in `OsirisBuildInfo.swift`
4. Update the `ZXingCpp` binary target URL in `Package.swift` and compute the new SHA256 checksum:
   ```bash
   curl -fsSL -u "USER:PASS" \
     "https://generic.ci.artifacts.walmart.com:443/artifactory/project-diamond-generic/zxing-cpp/xcframework-iOS-<new-version>.zip" \
     -o /tmp/zxing.zip && shasum -a 256 /tmp/zxing.zip | awk '{print $1}'
   ```

#### Manual release steps

1. Make all file updates above on a feature branch (e.g. `feature/bump-2026.09.16.2`) and open a PR to `main`
2. Once the PR is merged to `main`, CI runs tests automatically
3. Create a `release/<version>` branch **from the merge commit** and push it — this **automatically triggers the `updateSpecs` Looper flow**, which publishes all 4 podspecs to the private CocoaPods spec repo and creates the version tag:
   ```bash
   # VERSION format: YYYY.MM.SS.BB  (Year · Month · Sprint · Build)
   # Example: 2026.09.16.2 = year 2026, month 09, sprint 16, build 2
   VERSION=2026.09.16.2
   git checkout main && git pull
   git checkout -b release/$VERSION
   git push origin release/$VERSION
   ```
   > CI creates and pushes the git tag `$VERSION` automatically after a successful publish. You do **not** need to tag manually.
4. Verify the podspecs landed (see [Verifying the release](#verifying-the-release)), then wrap the auto-created tag in a GitHub release at `https://gecgithub01.walmart.com/Project-Diamond/osiris-ios/releases/new`:
   - Tag: select the existing tag (e.g. `2026.09.16.2`) — **do not create a new one**
   - Title: `2026.09.16.2`
   - Description: paste the CHANGELOG entry for this version
5. Open a PR to merge `release/<version>` → `main` to bring any CI fixes back into the main branch

### Verifying the release

After the `updateSpecs` CI build succeeds, confirm the podspecs landed in the private spec repo:
```bash
pod repo update walmart-project-diamond-cocoapods-specs
pod spec which OsirisBarcode --version=2026.09.16.2
```

## Updating OD (Object Detection) model

To update to a newer version of the OD model, you need to delete the old model and drag and drop the new one to our project in Xcode. After you added the new model on our project structure, you will need to manually run this command in the terminal directly on the model file:

```
xcrun coremlcompiler compile OsirisBarcodeModel.mlmodel .
```

This will generate a `mlmodelc` file that its needed to run the model on other projects.

## Privacy Manifest

Osiris bundles a `PrivacyInfo.xcprivacy` file at the package root and in each target (`Osiris`, `OsirisBarcode`, `OsirisCamera`, `BluetoothPlatform`), declaring the required-reason APIs and data collection practices per [Apple's privacy manifest requirements](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

### Running locally

The vendored gems target Ruby 3.2.0, managed via [rbenv](https://github.com/rbenv/rbenv) (same as CI). If your shell's default `ruby -v` resolves to a different version, load rbenv first:

```sh
eval "$(rbenv init -)"
ruby -v   # should report 3.2.0
```

Then install dependencies and run the lane from the repo root:

```sh
bundle install
bundle exec fastlane ios privacy_manifest_check
```

This lane:

- Lints every `PrivacyInfo.xcprivacy` file with `plutil -lint` - the same check App Store Connect runs on upload
- Validates required-reason API entries and tracking domains against Apple's documented rules (e.g. no empty reasons arrays, no tracking domains missing when `NSPrivacyTracking` is `true`)
- Writes an aggregate report to `fastlane/PrivacyReport/privacy_report.json` and `fastlane/PrivacyReport/privacy_report.html`

Open the HTML report in a browser to review it:

```sh
open fastlane/PrivacyReport/privacy_report.html
```

The lane fails with the offending file and reason if any manifest is malformed or incomplete.


## Contributing

Any contributions you make are **greatly appreciated** so we welcome any PRs with enhancements.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Osiris is released under the MIT license. [See LICENSE](https://gecgithub01.walmart.com/Project-Diamond/osiris-ios/blob/main/LICENSE) for details.

## Maintainers

### [Constellation Engineering](https://confluence.walmart.com/pages/viewpage.action?pageId=1342945244)

Links: 
- [Email](diamond-engineering@wal-mart.com)
- [Confluence Overview](https://confluence.walmart.com/pages/viewpage.action?pageId=1974239109)

## Acknowledgements
- [CocoaPods](https://cocoapods.org/)
- [Core ML Tools](https://apple.github.io/coremltools/docs-guides/)


