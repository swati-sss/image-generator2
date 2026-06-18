//
//  StoreMapView+Extensions.swift
//  compass_sdk_ios
//
//  Created by p0a0595 on 8/28/25.
//
@preconcurrency import WebKit
import Combine
import LivingDesign
import UIKit

extension StoreMapView {
    func zoom(to rect: CGRect, isAnimated: Bool = true) {
        webView.scrollView.zoom(to: rect, animated: isAnimated)
        Log.debug("zoom webView with rect: \(rect)")
    }

    func zoomOut(with zoomScale: CGFloat?, _ completion: @escaping (() -> Void)) {
        let scale = zoomScale ?? webView.scrollView.minimumZoomScale
        Log.debug("zoom out with zoom scale: \(scale)")
        webView.scrollView.setZoomScale(scale, animated: true)

        // Slight delay to give the webview time to zoom back out properly
        DispatchQueue.main.asyncAfter(deadline: .now() + StoreMapConfig.zoomOutAnimationDelay) {
            completion()
        }
    }

    func zoomOnRegion(with rect: CGRect, zoomAnimationDelay: TimeInterval, completion: StoreMapsCompletion?) {
        Log.debug("Zooming to pins in rect: \(rect).")
        DispatchQueue.main.asyncAfter(deadline: .now() + zoomAnimationDelay) { [weak self] in
            self?.zoom(to: rect)
            completion?()
        }
    }

    func setZoomScale(to zoomScale: CGFloat, zoomType: ZoomActionType, _ completion: StoreMapsCompletion?) {
        Log.debug("Update Zoom Scale \(zoomScale)")
        webView.scrollView.setZoomScale(zoomScale, animated: true)
        // Slight delay to give the webview time to zoom back out smoothly
        DispatchQueue.main.asyncAfter(deadline: .now() + StoreMapConfig.zoomOutAnimationDelay) {
            completion?()
        }
    }

    func handleNavigationInterruption(for index: Int, status: NavigationStatus?) {
        if index != 0, status == .interrupted {
            isNavigationButtonClicked = false
            updateNavigationButton()
        }
    }

    func refreshNavigationButtonState(_ isVisible: Bool?) {
        if let isVisible, isVisible != lastNavigationButtonVisibility {
            lastNavigationButtonVisibility = isVisible
            updateNavigationButton()
            Log.debug("Navigation button updated with flag: \(isVisible)")
        }
    }
}

internal extension StoreMapView {
    func resetCenterButtonAndStatus() {
        isCenterButtonClicked = false
        isLocationStatusVisible = false
        updateMapCenterButton()
    }

    func updateMapCenterButton() {
        guard let currentIsPositionLocked, currentIsPositionLocked,
                sessionStorage.storeConfig.dynamicMapEnabledResolved else {
            mapCenterButton.isHidden = true
            return
        }

        let iconColor = isCenterButtonClicked ? MapButtonColor.blue : .black
        DispatchQueue.asyncOnMain { [weak self] in
            guard let self else { return }
            self.mapCenterButton.isHidden = false
            self.applyIconButtonStyle(
                self.mapCenterButton,
                image: Asset.Image.mapCenter.image,
                iconColor: iconColor,
                backgroundColor: .white
            )
            self.configureMapCenterButtonAccessibility()
        }
    }

    func updateNavigationButton() {
        guard sessionStorage.storeConfig.navigationConfigResolved.enabled == true,
              sessionStorage.storeConfig.navigationConfigResolved.isAutomaticNavigation == false,
              webViewLoaderViewModel?.canDisplayNavigationButton == true
        else {
            navigationButton.isHidden = true
            return
        }

        guard let isPositionLocked = currentIsPositionLocked, isPositionLocked else {
            navigationButton.isHidden = !isNavigationButtonClicked
            return
        }

        DispatchQueue.asyncOnMain { [weak self] in
            guard let self else { return }
            self.navigationButton.isHidden = false
            let iconColor = self.isNavigationButtonClicked ? UIColor.black : UIColor.white
            let backgroundColor = self.isNavigationButtonClicked ? UIColor.white : MapButtonColor.blue
            let image =
            self.isNavigationButtonClicked ? Asset.Image.routePreviewStop.image : Asset.Image.routePreviewStart.image
            self.applyIconButtonStyle(
                self.navigationButton,
                image: image,
                iconColor: iconColor,
                backgroundColor: backgroundColor
            )
            self.navigationButton.accessibilityIdentifier =
            self.isNavigationButtonClicked ? "routePreviewStop" : "routePreviewStart"
        }
    }

    func createButton(type: ButtonModel.ActionType) -> CustomButton {
        let model = ButtonModel(type: type, backgroundColor: .clear, highlightedBackgroundColor: .clear, image: nil)
        let button = CustomButton(with: model) { [weak self] type in
            switch type {
            case let .zoom(direction):
                Log.debug("Zoom Button Tapped for direction \(direction)")
                self?.resetCenterButtonAndStatus()
                self?.webViewLoaderViewModel?.onStoreMapZoomChange(zoomType: direction, nil)
            case let .floor(level):
                Log.debug("Floor Button Tapped for level \(level)")
                self?.floorOneButton.isSelected = level == .floorOne
                self?.floorTwoButton.isSelected = level == .floorTwo
                self?.webViewLoaderViewModel?.onStoreMapFloorChange(levelType: level, nil)
                Analytics.floorSelection(payload: FloorSelectionAnalytics(floorValue: level == .floorOne ? "1" : "2"))
            }
        }

        let colors = LivingDesign.LDToken.Colors.self
        let normalTextColor = UIColor.optional(colors.textOnfill, traits: traitCollection) ?? .black
        let selectedTextColor = UIColor.optional(colors.textInverse, traits: traitCollection) ?? .white
        let normalBackgroundColor = UIColor.optional(colors.background, traits: traitCollection) ?? .white
        let selectedBackgroundColor = UIColor.optional(colors.fillBrand, traits: traitCollection) ?? MapButtonColor.blue

        let buttonText: String
        let textStyle: LDToken.LDText.Style
        let selectedTextStyle: LDToken.LDText.Style

        switch type {
        case let .zoom(direction):
            buttonText = direction == .zoomIn ? "＋" : "―"
            textStyle = .bodyMonoLarge
            selectedTextStyle = .bodyMonoLargeAlt
        case let .floor(level):
            buttonText = level == .floorOne ? "1" : "2"
            textStyle = .bodyMedium
            selectedTextStyle = .bodyMediumAlt
        }

        button.applyButtonStyle(
            CustomButton.Style(
                text: buttonText,
                normalTextColor: normalTextColor,
                selectedTextColor: selectedTextColor,
                normalBackgroundColor: normalBackgroundColor,
                selectedBackgroundColor: selectedBackgroundColor,
                tokenBundle: Bundle(for: LDRootViewController.self),
                traitCollection: traitCollection,
                textStyle: textStyle,
                selectedTextStyle: selectedTextStyle,
            )
        )
        configureAccessibility(for: button, type: type)
        return button
    }

    func configureMapCenterButtonAccessibility() {
        mapCenterButton.isAccessibilityElement = true
        mapCenterButton.accessibilityLabel = LocalizedKey.centerMapContentDescription.localized
        mapCenterButton.accessibilityTraits.insert(.button)
        mapCenterButton.accessibilityTraits.remove(.selected)
    }

    func configureLocationStatusAccessibility() {
        locationStatusContainer.isAccessibilityElement = true
        locationStatusContainer.accessibilityTraits = [.staticText, .updatesFrequently]
        locationStatusContainer.accessibilityLabel = locationStatusLabel.text
        locationStatusLabel.isAccessibilityElement = false
        locationActivityIndicator.isAccessibilityElement = false
    }

    private func configureAccessibility(for button: CustomButton, type: ButtonModel.ActionType) {
        button.isAccessibilityElement = true
        button.accessibilityTraits.insert(.button)

        switch type {
        case let .zoom(direction):
            if direction == .zoomIn {
                button.accessibilityLabel = LocalizedKey.zoomInContentDescription.localized
            } else {
                button.accessibilityLabel = LocalizedKey.zoomOutContentDescription.localized
            }
            button.accessibilityTraits.remove(.selected)
        case let .floor(level):
            if level == .floorOne {
                button.accessibilityLabel = LocalizedKey.floorOneContentDescription.localized
            } else {
                button.accessibilityLabel = LocalizedKey.floorTwoContentDescription.localized
            }
        }
    }

    private func updateLocationStatusAccessibility(text: String, shouldAnnounce: Bool) {
        locationStatusContainer.accessibilityLabel = text

        guard shouldAnnounce else { return }
        postAccessibilityAnnouncement(text)
    }

    private func postAccessibilityAnnouncement(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    @objc func mapCenterButtonTapped() {
        Log.debug("Map Center Button Tapped")
        isCenterButtonClicked.toggle()
        updateMapCenterButton()
        let payload = MapInteractionAnalytics(interactionType: .mapCenter, interactionValue: isCenterButtonClicked)
        Analytics.mapInteraction(payload: payload)
    }

    @objc func navigationButtonTapped() {
        Log.debug("Navigation button tapped")
        if let isNavigationActive = webViewLoaderViewModel?.setNavigation(enabled: &isNavigationButtonClicked),
           isNavigationActive {
            updateNavigationButton()
        } else if sessionStorage.storeConfig.mapUiConfigResolved.snackBarEnabled {
            let model = LDSnackbar.Model(message: LocalizedKey.selectPinBeforeRoute.localized, duration: 3.5)
            let snackBar = LDSnackbar(dataModel: model)
            snackBar.showSnackbar(in: self, constraints: { [weak self] snackBar in
                guard let self else { return [] }
                return [
                    snackBar.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
                    snackBar.centerXAnchor.constraint(equalTo: self.centerXAnchor)
                ]
            })
            snackBar.onDismiss = {
                snackBar.isHidden = true
            }
        }
    }

    func handleError(_ error: StoreMapError) {
        webViewLoaderViewModel?.handleError()
        var errorString = "MapLoad failed"
        switch error {
        case .invalidStatusCode(let statusCode):
            setMapState(.error)
            errorString = "\(errorString) with \(statusCode)"
        case .failedToLoadContent(let error):
            setMapState(.error)
            errorString = "\(errorString) \(error.localizedDescription)"
        case .invalidResponse:
            setMapState(.error)
            errorString = "\(errorString) with invalid HTTPURLResponse or empty response"
        case .mapLoadTimedOut:
            setMapState(.error)
            errorString = "\(errorString): operation time out."
        case .noInternetConnection(let error):
            setMapState(.warning)
            errorString = "\(errorString) \(error.localizedDescription)"
        }

        Log.error(errorString)
    }
}

extension StoreMapView: UIScrollViewDelegate {
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // For Holiday release, StoreMaps would be loading Level 3 map
        // And there wont be requests to change the map levels
        Log.debug("scrollViewDidEndZooming with scale: \(scale) and with content size: \(scrollView.contentSize)")
        webViewLoaderViewModel?.updateZoomLevel(with: scale)

        // Update zoom button enabled state based on current zoom scale
        let isAtMinZoom = scale <= scrollView.minimumZoomScale + 0.01
        let isAtMaxZoom = scale >= scrollView.maximumZoomScale - 0.01

        zoomOutButton.isEnabled = !isAtMinZoom
        zoomOutButton.alpha = isAtMinZoom ? 0.5 : 1.0

        zoomInButton.isEnabled = !isAtMaxZoom
        zoomInButton.alpha = isAtMaxZoom ? 0.5 : 1.0
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        Log.debug("scrollViewWillBeginDragging")

        // Remove the blue dot focus if there is any interaction
        // with the map, such as dragging or pinching the web view.
        self.resetCenterButtonAndStatus()
        self.hideLocationStatusLabel = true
    }
}

extension StoreMapView: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let policy: WKNavigationResponsePolicy

#if DEBUG
        if let url = navigationResponse.response.url, url.isFileURL {
            decisionHandler(.allow)
            return
        }
#endif

        guard let response = navigationResponse.response as? HTTPURLResponse else {
            policy = .cancel
            handleError(.invalidResponse)
            decisionHandler(policy)
            return
        }

        if response.statusCode < 200 || response.statusCode >= 300 {
            policy = .cancel
            handleError(.invalidStatusCode(response.statusCode))
        } else {
            policy = .allow
        }

        decisionHandler(policy)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Analytics.telemetry(payload: TelemetryAnalytics(
            isError: true,
            event: DisplayMap.DISPLAY_MAP_ERROR_INVALID_CONTAINER.rawValue
        ))
        webViewLoadResultSubject.send(.failure(error))
        guard let error = error as NSError?, error.domain == NSURLErrorDomain else {
            handleError(.failedToLoadContent(error))
            return
        }

        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            handleError(.noInternetConnection(error))
        case NSURLErrorTimedOut:
            handleError(.mapLoadTimedOut)
        default:
            handleError(.failedToLoadContent(error))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isWebViewLoaded = true
        webViewLoadResultSubject.send(.mapLoaded)
        setMapState(.loading(false))
        webViewLoaderViewModel?.didLoadWebView()
        disableTextSelection()
        Analytics.telemetry(payload: TelemetryAnalytics(event: DisplayMap.DISPLAY_MAP_WEB_VIEW_LOADED.rawValue))
    }
}

internal extension StoreMapView {
    func setMapState(_ state: StoreMapState) {
        switch state {
        case .loading(let isLoading) where sessionStorage.storeConfig.spinnerEnabledResolved:
            mapState = state
            Log.debug("Dynamic Map State is loading with: \(isLoading)")
        case .warning where sessionStorage.storeConfig.errorScreensEnabledResolved:
            mapState = state
            Log.debug("Dynamic Map State is warning")
        case .error where sessionStorage.storeConfig.errorScreensEnabledResolved:
            mapState = state
            Log.debug("Dynamic Map State is error")
        default:
            break
        }
    }

    func configurePinErrorBanner() {
        let message = NSAttributedString(string: LocalizedKey.pinErrorMessage.localized)
        let dismissTitle = LocalizedKey.dismissButtonTitle.localized

        pinErrorBanner.dataModel = LivingDesign.LDAlert.Model(
            message: message,
            messageType: .warning,
            detailsButtonTitle: dismissTitle
        )
        pinErrorBanner.isHidden = true
        pinErrorBanner.onTapAlert = { [weak self] in
            self?.pinErrorBanner.isHidden = true
        }
    }

    func displayPinErrorBanner(_ enabled: Bool) {
        guard sessionStorage.storeConfig.mapUiConfigResolved.pinLocationUnavailableBannerEnabled else { return }
        pinErrorBanner.isHidden = !enabled
    }
}

// MARK: - UI Configuration
extension StoreMapView {
    func togglePositioningStatusLabel(shouldShow: Bool) {
        guard !hideLocationStatusLabel else { return }

        if shouldShow {
            if isLocationStatusVisible {
                return
            }
            let text = LocalizedKey.findingLocation.localized
            locationStatusLabel.text = text
            isLocationStatusVisible = true
            updateLocationStatusAccessibility(text: text, shouldAnnounce: true)
            locationActivityIndicator.startAnimating()
            Log.debug("Spinner started animating with status label text: \(text)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self, self.isLocationStatusVisible else { return }
                let updatedText = LocalizedKey.keepHeading.localized
                self.locationStatusLabel.text = updatedText
                self.updateLocationStatusAccessibility(text: updatedText, shouldAnnounce: true)
                Log.debug("Spinner started animating with status label text: \(updatedText)")
            }
        } else {
            hideLocationStatusLabel = true
            isLocationStatusVisible = false
            locationActivityIndicator.stopAnimating()
            Log.debug("Spinner stopped animating")
        }
    }

    func constructFloorControlConstraints() {
        NSLayoutConstraint.activate([
            floorControlStackView.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -LDSpacing.space16
            ),
            floorControlStackView.topAnchor.constraint(
                equalTo: zoomControlStackView.bottomAnchor,
                constant: LDSpacing.space8
            ),
            floorControlStackView.widthAnchor.constraint(equalToConstant: LDSpacing.space40),
            floorControlStackView.heightAnchor.constraint(equalToConstant: LDSpacing.space40 * 2)
        ])
    }

    func constructZoomControlConstraints() {
        NSLayoutConstraint.activate([
            zoomControlStackView.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -LDSpacing.space16
            ),
            zoomControlStackView.topAnchor.constraint(
                equalTo: safeAreaLayoutGuide.topAnchor,
                constant: LDSpacing.space16
            ),
            zoomControlStackView.widthAnchor.constraint(equalToConstant: LDSpacing.space40),
            zoomControlStackView.heightAnchor.constraint(equalToConstant: (LDSpacing.space40 * 2) + 1)
        ])
    }

    internal func constructButtonStackViewConstraints() {
        NSLayoutConstraint.activate([
            mapCenterButton.widthAnchor.constraint(equalToConstant: LDSpacing.space40),
            mapCenterButton.heightAnchor.constraint(equalToConstant: LDSpacing.space40),
            navigationButton.widthAnchor.constraint(equalToConstant: LDSpacing.space40),
            navigationButton.heightAnchor.constraint(equalToConstant: LDSpacing.space40),
            buttonStackView.trailingAnchor.constraint(
                equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -LDSpacing.space16
            ),
            buttonStackView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -LDSpacing.space16
            ),
            buttonStackView.widthAnchor.constraint(equalToConstant: LDSpacing.space40)
        ])
    }

    func constructWebViewConstraints() {
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            webView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func disableTextSelection() {
        if #available(iOS 14.5, *) {
            webView.configuration.preferences.isTextInteractionEnabled = false
        } else {
            let selectionScript = WKUserScript(source: """
                document.body.style.webkitTouchCallout='none';
                document.body.style.webkitUserSelect='none';
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(selectionScript)
        }
    }
}

extension UIColor {
    static func optional(_ color: LDToken.Colors, traits: UITraitCollection) -> UIColor? {
        let ldBundle = Bundle(for: LDRootViewController.self)
        return UIColor.optionalColor(with: color, in: ldBundle, with: traits)
    }
}
