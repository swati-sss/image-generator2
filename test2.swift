//
//
//  BarcodeSingleScanViewController.swift
//  Diamond-sdk
//
//  Created by Andres Vinueza on 10/18/23.
//
//

import Osiris
import OsirisBarcode
import OsirisCamera
import OverlayContainer
import SwiftUI
import UIKit

class BarcodeSingleScanViewController: DiamondViewController<BarcodeSingleScanViewModel, BarcodeSingleScanView> {
    
    // MARK: Properties
    
    weak var delegate: OverlayContainerViewControllerDelegate?
    private let barcodeSessionVC = BarcodeSessionViewController()
    var scannerViewController: OsirisScannerViewController?
    private var isRunningBenchmarking = false
    private var forcedCycle: UIViewController?
    private var isShowingAlert = false
    private var barcodeSettings: [BarcodeValue: OsirisBoundingBoxConfig] = [:]

    private var hasLoggedBarcodeDetection = false

    private var boundingBoxOptions: BoundingBoxOptions = .defaultOptions

    private let hostBarcodeOverlay = DiamondHostBarcodeOverlay(frame: .zero)
    private var isScannerScreenVisible = false

    /// Number of image entries in the last completed export's zip, per the vendored OsirisBarcode
    /// pod's "diamond.capture.diagnostics" notification (step "imageCount"). The pod can't import
    /// the app target, so both sides agree on this raw notification/key contract instead of a
    /// shared type. `nil` until the first export of this session completes.
    private(set) var lastImageCount: Int?

    // MARK: Lifecycle

    override func viewDidLoad() {
        setupNavBar()
        super.viewDidLoad()
        setupUI()
        ui.viewModel = state

        scannerViewController?.viewModel.$fpsStatsDisplay
            .receive(on: DispatchQueue.main)
            .sink {[weak self] statsText in
                guard let view = self?.scannerViewController?.scannerView else { return }
                view.fpsStatsLabel.text = statsText
            }
            .store(in: &subscriptions)

        NotificationCenter.default.addObserver(self,
                                                selector: #selector(handleCaptureDiagnostics(_:)),
                                                name: Notification.Name("diamond.capture.diagnostics"),
                                                object: nil)
    }

    @objc private func handleCaptureDiagnostics(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              userInfo["step"] as? String == "imageCount",
              let detail = userInfo["detail"] as? String else { return }
        lastImageCount = Int(detail)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isScannerScreenVisible = true
        hostBarcodeOverlay.display([])
        disableTorch()
        // `scannedBarcodeValues` persists in UserDefaults with no expiry (see markAsScanned/
        // resetScannedBarcodes) — without clearing it here, any barcode scanned in a *previous*
        // session (or a previous app launch) is silently suppressed by didDetectBarcode's dedupe
        // check forever, making scanning look completely broken until the user manually taps Reset.
        barcodeSessionVC.barcodeListController.setDataSource([])
        state.resetScannedBarcodes()
        scannerViewController?.viewModel.resetFrameStats()
        Task { @MainActor in
            try await state.configureOsiris()
            boundingBoxOptions = try await state.fetchBoundingBoxSettings()
            barcodeSettings = [:] // reset settings
            scannerViewController?.startScanning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        isScannerScreenVisible = false
        hostBarcodeOverlay.display([])
        super.viewWillDisappear(animated)
    }

    override func setupUIEventBindings(for ui: BarcodeSingleScanView) {
        ui.flashButton.publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                do {
                    try self?.state.toggleTorch()
                } catch {
                    print("Failed to access torch")
                }
            }
            .store(in: &subscriptions)
        
        ui.toggleDirectionButton.publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    Logging.log("Toggling direction of camera")
                    do {
                        try await self?.state.toggleDirection()
                    } catch {
                        Logging.log("Toggling direction failed... \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &subscriptions)
        
        ui.cameraSettingsButton.publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                (self?.coordinator as? BarcodeSingleScanCoordinator)?.showDecodeSettings()
            }
            .store(in: &subscriptions)
        
        barcodeSessionVC.barcodeListController.barcodeResultList.resetButton.publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.barcodeSessionVC.barcodeListController.setDataSource([])
                self?.state.resetScannedBarcodes()
                self?.scannerViewController?.viewModel.resetFrameStats()
            }
            .store(in: &subscriptions)
    }
    
    // MARK: Private Helpers
    
    private func setupUI() {
        setupScanner()
        setupOverlay()
    }
    
    private func setupNavBar() {
        leadingBarItems.append(.back)
        trailingBarItems.append(.custom(ui.cameraSettingsButton))
        trailingBarItems.append(.custom(ui.flashButton))
        trailingBarItems.append(.custom(ui.toggleDirectionButton))
    }
    
    private func setupOverlay() {
        let overlayController = OverlayContainerViewController()
        overlayController.delegate = self
        overlayController.viewControllers = [barcodeSessionVC]
        barcodeSessionVC.onCloseTap = {
            overlayController.moveOverlay(toNotchAt: OverlayNotch.minimum.rawValue, animated: true)
        }
        addChild(overlayController)
        view.addSubview(overlayController.view)
    }
    
    private func setupScanner() {
        let scannerVC = OsirisScannerViewController(context: state.context)
        scannerVC.delegate = self
        addChild(scannerVC)
        scannerVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scannerVC.view)
        NSLayoutConstraint.activate([
            scannerVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            scannerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scannerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scannerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        scannerVC.didMove(toParent: self)
        self.scannerViewController = scannerVC

        guard state.boundingBoxTestMode == .host,
              let preview = scannerVC.scannerView?.videoContainerView else { return }
        // SDK geometry is already in this view's coordinates. Do not scale it again.
        hostBarcodeOverlay.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(hostBarcodeOverlay)
        NSLayoutConstraint.activate([
            hostBarcodeOverlay.topAnchor.constraint(equalTo: preview.topAnchor),
            hostBarcodeOverlay.leadingAnchor.constraint(equalTo: preview.leadingAnchor),
            hostBarcodeOverlay.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
            hostBarcodeOverlay.bottomAnchor.constraint(equalTo: preview.bottomAnchor)
        ])
    }
    
    private func setShowLoadingView(isLoading: Bool, animated: Bool = true) {
        /// Have to retain self so we can finish the loading view dismissal
        self.forcedCycle = isLoading ? self : nil
        if isLoading {
            self.coordinator?.showLoadingView()
        } else {
            self.coordinator?.hideLoadingView(animated: animated)
        }
    }
    
    private func disableTorch() {
        do {
            try self.state.setEnableTorch(false)
        } catch {
            Logging.log("Failed... \(error.localizedDescription)")
        }
    }
    
    deinit {
        Logging.log("...")
        NotificationCenter.default.removeObserver(self)
        OsirisApp.shared.removeConfig(forContext: state.context)
    }
    
}

extension BarcodeSingleScanViewController: OsirisScannerDelegate {
    func cameraIdleDetected() {
        // Need it to confirm to Protocol
    }
    
    func didTapDetectedBarcodeBoundingBox(
        _ barcode: Barcode,
        setBoundingBoxSettings: @escaping (OsirisBoundingBoxConfig) -> Void
    ) {
        guard boundingBoxOptions.isMarkerStyleBoundingBoxEnabled else {
            return
        }
        
        guard let icon = UIImage(named: "check_white_icon") else {
            return
        }
        
        let positioning: OsirisBoundingBoxConfig.TitleBox.Positioning = boundingBoxOptions.pickedMarkerStyle.isTop ? .top : .left
        
        let settings: OsirisBoundingBoxConfig = .init(
            borderColor: boundingBoxOptions.pickedMarkerStyle.color.withAlphaComponent(1.0),
            backgroundColor: boundingBoxOptions.pickedMarkerStyle.color.withAlphaComponent(0.4), borderThickness: 6,
            borderCornerRadius: 4,
            centerIconImage: icon,
            
            titleBox: .init(title: "Selected", titleColor: .black, titleFont: .bogleBold(size: 14), positioning: positioning, backgroundColor: .white, backgroundCornerRadius: 4)
        )
        
        barcodeSettings[barcode.value] = settings
        setBoundingBoxSettings(settings)
    }
    
    func didDetectBarcodes(
        _ barcodes: [Barcode],
        setBoundingBoxesSettings: @escaping ([BarcodeValue: OsirisBoundingBoxConfig]) -> Void
    ) {
        // Handle empty results too, so an old host outline disappears.
        if state.boundingBoxTestMode == .host {
            hostBarcodeOverlay.display(isScannerScreenVisible ? barcodes : [])
            return
        }
        guard state.boundingBoxTestMode == .sdk else { return }
        guard !barcodes.isEmpty else { return }
        if !hasLoggedBarcodeDetection {
            hasLoggedBarcodeDetection = true
            Logging.log("Zoom test - Barcodes detected: \(barcodes) at \(Date()), thread is \(Thread.isMainThread)", logLevel: .debug)
        }

        guard boundingBoxOptions.isMarkerStyleBoundingBoxEnabled else {
            let newSettings: [BarcodeValue: OsirisBoundingBoxConfig] = barcodes.reduce(into: [:]) {
                result, barcode in

                result[barcode.value] = OsirisBoundingBoxConfig(
                    borderColor: .yellow,
                    backgroundColor: .clear,
                    borderThickness: 2,
                    borderCornerRadius: 4,
                    centerIconImage: nil
                )
            }
            DispatchQueue.main.async {
                setBoundingBoxesSettings(newSettings)
            }
            return
        }
        
        let iconName = boundingBoxOptions.markerStyle == .blueWithPlusIcon ? "plus_white_icon" : "question_icon"
        
        guard let icon = UIImage(named: iconName) else {
            return
        }
        
        let newSettings: [BarcodeValue: OsirisBoundingBoxConfig] = barcodes.reduce(into: [:]) {
            settings, barcode in
            
            if barcodeSettings[barcode.value] == nil {
                barcodeSettings[barcode.value] = OsirisBoundingBoxConfig(
                    borderColor: boundingBoxOptions.markerStyle ==
                        .blueWithPlusIcon ? .blueBrand.withAlphaComponent(1.0) : .yellow100.withAlphaComponent(1.0),
                    backgroundColor: boundingBoxOptions.markerStyle ==
                        .blueWithPlusIcon ? .blueBrand.withAlphaComponent(0.4) : .yellow100.withAlphaComponent(0.4), borderThickness: 6,
                    borderCornerRadius: 4,
                    centerIconImage: icon )
            }
            settings[barcode.value] = barcodeSettings[barcode.value]
        }
        DispatchQueue.main.async {
            setBoundingBoxesSettings(newSettings)
        }
    }
    
    func didDetectBarcodes(_ barcodes: [Barcode]) {
        Logging.log("detected barcodes \(barcodes)", logLevel: .info)
    }
    
    func didFireEvent(_ event: OsirisCamera.OsirisEvent) {
        /// Need to capture self here to make sure the coordinator stays until the dismissal
        Logging.log("... \(event)", logLevel: .warning)
        DispatchQueue.main.async {
            switch event {
            case .didStartScanning:
                Logging.log("...", logLevel: .warning)
                self.title = "\(self.scannerViewController?.decoderID ?? "?")"// Scan Barcodes"
            case .didFinishScanning:
                self.hostBarcodeOverlay.display([])
            case .didStartRunningBenchmarking:
                self.isRunningBenchmarking = true
            case .didFinishRunningBenchmarking:
                self.isRunningBenchmarking = false
                Task { @MainActor in
                    await self.incrementSessionCount()
                }
            case .didStartBenchmarkExport:
                self.setShowLoadingView(isLoading: true)
            case .didFinishBenchmarkExport(let error):
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.setShowLoadingView(isLoading: false, animated: error == nil)
                    if let error = error, !self.isShowingAlert {
                        self.isShowingAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.coordinator?.showAlert(.init(title: "Failed to Export!",
                                                              message: error.localizedDescription,
                                                              primaryCTA: "OK")) { _ in
                                self.isShowingAlert = false

                                self.scannerViewController?.viewModel.resetFrameStats()
                            }
                        }
                    } else if error == nil, !self.isShowingAlert {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if self.lastImageCount == 0 {
                                self.coordinator?.showAlert(.init(title: "Exported, But No Images!",
                                                                  message: "Session data uploaded successfully, but 0 images " +
                                                                           "were captured. Check Diagnostics > Capture Lifecycle " +
                                                                           "and Last Session JSON to see why.",
                                                                  primaryCTA: "OK")) { _ in
                                    self.isShowingAlert = false

                                    self.scannerViewController?.viewModel.resetFrameStats()
                                }
                            } else {
                                self.coordinator?.showAlert(.init(title: "Exported Successfully!",
                                                                  message: "Session Data has been exported successfully!",
                                                                  primaryCTA: "Perfect! 🎉")) { _ in
                                    self.isShowingAlert = false

                                    self.scannerViewController?.viewModel.resetFrameStats()
                                }
                            }
                        }
                    }
                }
            case .didEnableAllowBenchmarking, .didDisableAllowBenchmarking:
                break
            case .didStartCamera, .didShutDownCamera:
                break
            case .didFreezeCameraAfterSingleScan:
                self.scannerViewController?.scannerView?.showTapToResumeOverlay { [weak self] in
                    Logging.log("Zoom test - Showing Tap to Resume Overlay at \(Date()), thread is \(Thread.isMainThread)", logLevel: .debug)
                    guard let self else { return }
                    DispatchQueue.main.async {
                        self.scannerViewController?.startScanning()
                    }
                }
            }
        }
    }
    
    func didReceiveError(_ error: Error) {
        Logging.log("Received Error  \(error)", logLevel: .warning)
    }
    
    func didDetectBarcode(_ barcode: Barcode) {
        guard !state.scannedBarcodeValues.contains(barcode.value) else { return }
        state.markAsScanned(barcode.value)
        DispatchQueue.main.async {
            self.barcodeSessionVC.barcodeListController.addDataSource(.init(barcode: barcode,
                                                  hasBenchmarkingData: self.isRunningBenchmarking))
        }
        Logging.log("detected barcode \(barcode)", logLevel: .warning)
    }
    
    private func incrementSessionCount() async {
        await self.barcodeSessionVC.incrementSessionCount()
    }
    
}

extension BarcodeSingleScanViewController: OverlayContainerViewControllerDelegate {
    enum OverlayNotch: Int, CaseIterable {
        case minimum, maximum
    }
    
    func numberOfNotches(in containerViewController: OverlayContainerViewController) -> Int {
        return OverlayNotch.allCases.count
    }
    
    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        heightForNotchAt index: Int,
                                        availableSpace: CGFloat) -> CGFloat {
        switch OverlayNotch.allCases[index] {
        case .maximum:
            return availableSpace * 0.5
        case .minimum:
            return availableSpace * 0.2
        }
    }
    
    func overlayContainerViewController(_ containerViewController: OverlayContainerViewController,
                                        willMoveOverlay overlayViewController: UIViewController,
                                        toNotchAt index: Int) {
        let isVisible = OverlayNotch.maximum.rawValue == index
        barcodeSessionVC.toggleCloseButton(with: isVisible)
    }
}

// Temporary host renderer for exercising the SDK geometry from the Diamond app.
// Kept in this existing file so no new Xcode target membership is necessary.
private final class DiamondHostBarcodeOverlay: UIView {
    private let outlineLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = true
        outlineLayer.fillColor = UIColor.clear.cgColor
        outlineLayer.strokeColor = UIColor.systemBlue.cgColor
        outlineLayer.lineWidth = 3
        layer.addSublayer(outlineLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if outlineLayer.bounds.size != bounds.size {
            // Wait for fresh geometry after a preview resize or rotation.
            outlineLayer.path = nil
        }
        outlineLayer.frame = bounds
        CATransaction.commit()
    }

    func display(_ barcodes: [Barcode]) {
        let path = UIBezierPath()
        for barcode in barcodes {
            let corners = barcode.quadPointsInCameraPreview
            if corners.count == 4 {
                path.move(to: corners[0])
                for corner in corners.dropFirst() {
                    path.addLine(to: corner)
                }
                path.close()
            } else if let rectangle = barcode.boundingBoxInCameraPreview {
                path.append(UIBezierPath(rect: rectangle))
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outlineLayer.path = path.cgPath
        CATransaction.commit()
    }
}
