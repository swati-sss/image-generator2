import AVFoundation
import Combine
import Osiris
import OsirisBarcode
import OsirisCamera
import PluginAPIs
import UIKit
import WalmartPlatform
import WalmartUI

final class OsirisPOCViewController: WalmartUI.BaseViewController {
    private let scanHandler: ScanHandler
    private let onProduct: (ScanProduct) -> Void
    private let context = OsirisDataCaptureContext()

    private var scanner: OsirisScannerViewController?
    private var lookup: AnyCancellable?
    private var attemptID: UUID?
    private var lastValue = ""
    private var pendingNotice: (title: String, message: String)?
    private var pendingProduct: ScanProduct?

    private var isVisible = false
    private var isPaused = false
    private var isBusy = false
    private var isFinished = false
    private var isRequestingPermission = false

    init(
        scanHandler: ScanHandler,
        onProduct: @escaping (ScanProduct) -> Void
    ) {
        self.scanHandler = scanHandler
        self.onProduct = onProduct
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = true
    }

    override func constructView() {
        super.constructView()

        title = "Osiris Scanner"
        view.backgroundColor = .black

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Retry",
            style: .plain,
            target: self,
            action: #selector(retryTapped)
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        continueIfPossible()
    }

    override func viewWillDisappear(_ animated: Bool) {
        isVisible = false
        scanner?.stopScanning()
        super.viewWillDisappear(animated)
    }

    deinit {
        lookup?.cancel()
        NotificationCenter.default.removeObserver(self)
        OsirisApp.shared.removeConfig(forContext: context)
    }

    @objc private func appWillResignActive() {
        scanner?.stopScanning()
    }

    @objc private func appDidBecomeActive() {
        continueIfPossible()
    }

    private func continueIfPossible() {
        guard isVisible,
              !isFinished,
              UIApplication.shared.applicationState == .active,
              presentedViewController == nil
        else {
            return
        }

        if let product = pendingProduct {
            pendingProduct = nil
            finish(with: product)
            return
        }

        if let notice = pendingNotice {
            pendingNotice = nil

            let alert = UIAlertController(
                title: notice.title,
                message: notice.message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        guard !isPaused, !isBusy, !isRequestingPermission else {
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            if scanner == nil {
                guard AVCaptureDevice.default(for: .video) != nil else {
                    showNotice(
                        "Camera unavailable",
                        "Use an iPhone with a camera."
                    )
                    return
                }
                makeScanner()
            }

            if let scanner, !scanner.scannerIsRunning {
                scanner.startScanning()
            }

        case .notDetermined:
            isRequestingPermission = true

            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, !self.isFinished else { return }
                    self.isRequestingPermission = false
                    self.continueIfPossible()
                }
            }

        case .denied:
            showPermissionAlert(canOpenSettings: true)

        case .restricted:
            showPermissionAlert(canOpenSettings: false)

        @unknown default:
            showNotice(
                "Camera unavailable",
                "Camera authorization is unavailable."
            )
        }
    }

    private func makeScanner() {
        let config = OsirisConfig(
            partnerID: "GlassPOC",
            userID: "",
            symbologyGroup: .basic,
            hintGroup: .basic,
            scanActionType: .single,
            extras: [
                OsirisBarcodeKey.multiScanEnabled.rawValue: false,
                OsirisBarcodeKey.allowBenchmarking.rawValue: false,
                OsirisBarcodeKey.fpsStatsEnabled.rawValue: false
            ]
        )

        OsirisApp.configure(withConfig: config, context: context)

        let child = OsirisScannerViewController(context: context)
        child.delegate = self
        scanner = child

        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        child.view.constraints(pinningTo: view.safeAreaLayoutGuide).activate()
        child.didMove(toParent: self)
        view.layoutIfNeeded()
    }

    private func showPermissionAlert(canOpenSettings: Bool) {
        isPaused = true

        let alert = UIAlertController(
            title: "Camera access required",
            message: canOpenSettings
                ? "Enable Camera access for this app in Settings, then return."
                : "Camera access is restricted on this device.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .cancel))

        if canOpenSettings {
            alert.addAction(
                UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
                    guard let self,
                          let url = URL(string: UIApplication.openSettingsURLString)
                    else {
                        return
                    }

                    self.isPaused = false
                    UIApplication.shared.open(url)
                }
            )
        }

        present(alert, animated: true)
    }

    @objc private func retryTapped() {
        guard !isFinished,
              !isRequestingPermission,
              presentedViewController == nil
        else {
            return
        }

        cancelLookup()
        pendingNotice = nil
        pendingProduct = nil
        lastValue = ""
        isPaused = false
        title = "Osiris Scanner"
        continueIfPossible()
    }

    @objc private func closeTapped() {
        finish(with: nil)
    }

    private func cancelLookup() {
        attemptID = nil
        lookup?.cancel()
        lookup = nil
        isBusy = false
    }

    private func showNotice(_ heading: String, _ message: String) {
        guard !isFinished else { return }

        cancelLookup()
        isPaused = true
        scanner?.stopScanning()
        title = "Tap Retry to scan again"

        let details = lastValue.isEmpty ? message : """
        Decoded: \(lastValue)

        \(message)
        """

        pendingNotice = (heading, details)
        continueIfPossible()
    }

    private func finish(with product: ScanProduct?) {
        guard !isFinished else { return }

        isFinished = true
        isPaused = true
        cancelLookup()
        pendingNotice = nil
        pendingProduct = nil
        navigationItem.rightBarButtonItem?.isEnabled = false
        scanner?.stopCamera()
        scanner?.delegate = nil

        let completion = onProduct
        dismiss(animated: true) {
            if let product {
                completion(product)
            }
        }
    }

    private func handleBarcode(_ barcode: OsirisBarcode.Barcode) {
        guard isVisible,
              !isFinished,
              !isBusy,
              !isPaused,
              UIApplication.shared.applicationState == .active,
              presentedViewController == nil
        else {
            return
        }

        isPaused = true
        scanner?.stopScanning()
        lastValue = barcode.value

        let symbology: ScannerSymbology
        switch barcode.format {
        case .upca:
            symbology = .upca
        case .upce:
            symbology = .upce
        case .ean8:
            symbology = .ean8
        case .ean13:
            symbology = .ean13
        default:
            showNotice(
                "Barcode decoded",
                """
                Format: \(barcode.format.rawValue).
                This POC looks up products only for UPC-A, UPC-E, EAN-8 and EAN-13.
                """
            )
            return
        }

        let detection = ScannerDetection(
            payload: barcode.value,
            symbology: symbology
        )
        let scan = GlobalScan(detection: detection, source: .scanner)

        guard scanHandler.canHandle(scan) else {
            showNotice(
                "Lookup unavailable",
                "Glass cannot look up this barcode."
            )
            return
        }

        isBusy = true
        title = "Looking up product…"

        let id = UUID()
        attemptID = id

        lookup = scanHandler.dataSource.publisher(for: scan)
            .first()
            .bufferReceive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self,
                          !self.isFinished,
                          self.attemptID == id
                    else {
                        return
                    }

                    switch completion {
                    case .finished:
                        self.showNotice(
                            "No product",
                            "The lookup returned no product."
                        )

                    case .failure(let error):
                        switch error {
                        case .notFound, .notFoundSimilarItems:
                            self.showNotice(
                                "Product not found",
                                "Glass did not find an exact product for this barcode."
                            )

                        case .invalid:
                            self.showNotice(
                                "Product unavailable",
                                "Glass returned a product that cannot be shown by this POC."
                            )

                        case .service(let serviceError):
                            self.showNotice(
                                "Lookup failed",
                                serviceError.localizedDescription
                            )
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self,
                          !self.isFinished,
                          self.attemptID == id
                    else {
                        return
                    }

                    let product = response.product
                    guard product.canShowProductDetails,
                          !product.usItemID.rawValue.isEmpty
                    else {
                        self.showNotice(
                            "Product unavailable",
                            "This product cannot open an item details page."
                        )
                        return
                    }

                    self.cancelLookup()
                    self.pendingProduct = product
                    self.continueIfPossible()
                }
            )
    }
}

extension OsirisPOCViewController: OsirisScannerDelegate {
    func didDetectBarcode(_ barcode: OsirisBarcode.Barcode) {
        handleBarcode(barcode)
    }

    func didTapDetectedBarcodeBoundingBox(
        _ barcode: OsirisBarcode.Barcode,
        setBoundingBoxSettings: @escaping (OsirisBoundingBoxConfig) -> Void
    ) {}

    func didDetectBarcodes(
        _ barcodes: [OsirisBarcode.Barcode],
        setBoundingBoxesSettings:
            @escaping ([OsirisCamera.BarcodeValue: OsirisBoundingBoxConfig]) -> Void
    ) {}

    func didFireEvent(_ event: OsirisCamera.OsirisEvent) {}

    func didReceiveError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !self.isFinished,
                  !self.isBusy,
                  !self.isPaused,
                  self.isVisible
            else {
                return
            }

            self.showNotice("Scanner error", error.localizedDescription)
        }
    }

    func cameraIdleDetected() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !self.isFinished,
                  !self.isBusy,
                  !self.isPaused,
                  self.isVisible
            else {
                return
            }

            self.showNotice(
                "Camera paused",
                "Tap Retry to continue scanning."
            )
        }
    }
}
