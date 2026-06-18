//
//  StoreMapStatesView.swift
//  compass_sdk_ios
//
//  Created by Rakesh Shetty on 11/5/24.
//

import Combine
import UIKit
import LivingDesign

enum StoreMapState {
    case loading(Bool) // Indicates if the map is loading.
    case warning       // Represents a warning state.
    case error         // Represents an error state
}

struct MapStateModel {
    // Warning State Properties
    var warningImage: UIImage?
    var warningText: String
    var warningTryAgainText: String
    var warningButtonIcon: LDIconValue
    var warningButtonText: String

    // Error State Properties
    var errorImage: UIImage?
    var errorText: String
    var errorTryAgainText: String
    var errorButtonText: String

    init(warningImage: UIImage? = Asset.Image.mapWarning.image,
         warningText: String = LocalizedKey.mapNotAvailableCheckInternet.localized,
         warningTryAgainText: String = LocalizedKey.mapNotAvailable.localized,
         warningButtonIcon: LDIconValue = .primitive(.refresh),
         warningButtonText: String = LocalizedKey.reload.localized,
         errorImage: UIImage? = Asset.Image.mapError.image,
         errorText: String = LocalizedKey.errorLoadingMap.localized,
         errorTryAgainText: String = LocalizedKey.errorLoadingMapTryAgain.localized,
         errorButtonText: String = LocalizedKey.reloadMap.localized) {
        self.warningImage = warningImage
        self.warningText = warningText
        self.warningTryAgainText = warningTryAgainText
        self.warningButtonIcon = warningButtonIcon
        self.warningButtonText = warningButtonText
        self.errorImage = errorImage
        self.errorText = errorText
        self.errorTryAgainText = errorTryAgainText
        self.errorButtonText = errorButtonText
    }
}

protocol StoreMapReloadDelegate: AnyObject {
    /// Called when map reload is requested
    func reloadStoreMap()
}

final class StoreMapStatesView: LDRootView {
    weak var storeMapReloadDelegate: StoreMapReloadDelegate?

    private var mapStateModel: MapStateModel
    private var warningStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = LDSpacing.space12 + LDSpacing.space2
        return stackView
    }()
    private var warningImageView: UIImageView = UIImageView()
    private var warningTitleLabel: LDLabel = LDLabel(style: .bodySmall)
    private let warningButton: LDLinkButton = {
        let button = LDLinkButton(dataModel: LDLinkButton.Model(size: .large))
        return button
    }()
    private let errorAlert: LDAlert = {
        let alert = LDAlert(
            dataModel: LDAlert.Model(message: NSAttributedString(string: ""),
                                     messageType: .error)
        )
        return alert
    }()
    private var errorMapImageView: UIImageView = UIImageView()
    private lazy var spinner: LDSpinner = {
        let spinner = LDSpinner(style: .neutral, size: .small)
        spinner.hidesWhenStopped = true
        spinner.isUserInteractionEnabled = false
        spinner.stopAnimating()
        return spinner
    }()
    // Change attempts to internal for test access
    var attempts = 0

    init(mapStateModel: MapStateModel) {
        self.mapStateModel = mapStateModel
        super.init(frame: .zero)

        applyMapStateModel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func constructView() {
        super.constructView()

        warningButton.addTarget(self, action: #selector(reloadMapButtonTapped), for: .primaryActionTriggered)
    }

    override func constructSubviewLayoutConstraints() {
        super.constructSubviewLayoutConstraints()

        spinner.translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = .white
        addAutoLayoutSubview(spinner)
        bringSubviewToFront(spinner)
        addAutoLayoutSubview(warningStackView)
        addAutoLayoutSubview(errorAlert)
        addAutoLayoutSubview(errorMapImageView)

        warningStackView.addArrangedSubview(warningImageView)
        warningStackView.addArrangedSubview(warningTitleLabel)
        warningStackView.addArrangedSubview(warningButton)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: LDSpacing.space40),
            spinner.heightAnchor.constraint(equalToConstant: LDSpacing.space40),
            warningStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            warningStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            warningStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LDSpacing.space24),
            warningStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LDSpacing.space24),
            warningImageView.widthAnchor.constraint(equalToConstant: LDSpacing.space40+LDSpacing.space2),
            warningImageView.heightAnchor.constraint(equalToConstant: LDSpacing.space32+LDSpacing.space4),
            warningButton.heightAnchor.constraint(equalToConstant: LDSpacing.space32+LDSpacing.space4),
            errorAlert.topAnchor.constraint(equalTo: topAnchor, constant: LDSpacing.space16),
            errorAlert.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LDSpacing.space8),
            errorAlert.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LDSpacing.space8),
            errorMapImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorMapImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorMapImageView.widthAnchor.constraint(equalToConstant: LDSpacing.space32),
            errorMapImageView.heightAnchor.constraint(equalToConstant: LDSpacing.space32)
        ])
    }

    func updateMapDisplayForState(state: StoreMapState) {
        switch state {
        case .loading(let show):
            Log.info("Map State loading with value \(show)")
            spinner.isHidden = !show
            toggleLoadingSpinner()
            warningStackView.isHidden = true
            errorMapImageView.isHidden = true
            errorAlert.isHidden = true
            isHidden = !show
            updateLoadingAccessibility(isLoading: show)
        case .warning:
            Log.warning("Map State warning")
            spinner.isHidden = true
            toggleLoadingSpinner()
            warningStackView.isHidden = false
            errorMapImageView.isHidden = true
            errorAlert.isHidden = true
            isHidden = false
            updateWarningAccessibility(text: mapStateModel.warningText, shouldAnnounce: true)
        case .error:
            Log.warning("Map State error")
            spinner.isHidden = true
            toggleLoadingSpinner()
            warningStackView.isHidden = true
            errorMapImageView.isHidden = false
            errorAlert.isHidden = false
            isHidden = false
            updateErrorAccessibility(text: mapStateModel.errorText, shouldAnnounce: true)
        }
    }

    @objc func reloadMapButtonTapped() {
        Log.info("Reloading Map")
        let maxAttempts = 5
        attempts += 1
        if attempts > maxAttempts {
            startCooldown()
        } else {
            storeMapReloadDelegate?.reloadStoreMap()
        }
    }
}

private extension StoreMapStatesView {
    func applyMapStateModel() {
        spinner.isHidden = true
        spinner.isAccessibilityElement = true
        spinner.accessibilityLabel = LocalizedKey.loadingContentDescription.localized
        spinner.accessibilityTraits = [.updatesFrequently]

        warningStackView.distribution = .equalCentering
        warningStackView.isHidden = true
        warningStackView.isAccessibilityElement = false

        warningImageView.image = mapStateModel.warningImage
        warningImageView.contentMode = .scaleAspectFit
        warningImageView.isAccessibilityElement = false

        warningTitleLabel.text = mapStateModel.warningText
        warningTitleLabel.textAlignment = .center
        warningTitleLabel.numberOfLines = 0
        warningTitleLabel.textColor = UIColor(
            red: 0.18, green: 0.184, blue: 0.196, alpha: 1
        )
        warningTitleLabel.accessibilityLabel = mapStateModel.warningText
        warningTitleLabel.accessibilityTraits = [.staticText]

        warningButton.dataModel = LDLinkButton.Model(
            size: .small,
            text: mapStateModel.warningButtonText,
            variant: .subtle,
            leadingImage: resolveIcon(mapStateModel.warningButtonIcon)
        )
        warningButton.accessibilityLabel = mapStateModel.warningButtonText
        warningButton.addTarget(self, action: #selector(reloadMapButtonTapped), for: .primaryActionTriggered)

        let errorAlertAttributed = NSAttributedString(string: mapStateModel.errorText)
        errorAlert.dataModel =  LivingDesign.LDAlert.Model(
            message: errorAlertAttributed,
            messageType: .error,
            detailsButtonTitle: mapStateModel.errorButtonText)
        errorAlert.isHidden = true
        errorAlert.accessibilityLabel = mapStateModel.errorText
        errorAlert.onTapAlert = { [weak self] in
            self?.reloadMapButtonTapped()
        }

        errorMapImageView.image = mapStateModel.errorImage
        errorMapImageView.contentMode = .scaleAspectFit
        errorMapImageView.isAccessibilityElement = false
        errorMapImageView.isHidden = true
    }

    func toggleLoadingSpinner() {
        guard spinner.isHidden else {
            spinner.startAnimating()
            return
        }

        spinner.stopAnimating()
    }

    func startCooldown() {
        // 5 minutes cool down for warning state view
        // 3 minutes cool down for error state view
        let cooldownPeriod: TimeInterval =  errorAlert.isHidden ? (5 * 60) : (3 * 60)
        setReloadMap(isHidden: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + cooldownPeriod) { [weak self] in
            self?.attempts = 0
            self?.setReloadMap(isHidden: true)
        }
    }

    func setReloadMap(isHidden: Bool) {
        let warningText = mapStateModel.warningText
        let warningTryAgainText = mapStateModel.warningTryAgainText

        let errorText = mapStateModel.errorText
        let errorTryAgainText = mapStateModel.errorTryAgainText
        let errorButtonText = mapStateModel.errorButtonText

        warningTitleLabel.text = isHidden ? warningText : warningTryAgainText
        updateWarningAccessibility(text: warningTitleLabel.text ?? "", shouldAnnounce: !warningStackView.isHidden)
        warningButton.isEnabled = isHidden

        let currentErrorText = isHidden ? errorText : errorTryAgainText
        let errorAlertAttributed = NSAttributedString(string: currentErrorText)
        errorAlert.dataModel =  LivingDesign.LDAlert.Model(
            message: errorAlertAttributed,
            messageType: .error,
            detailsButtonTitle: isHidden ? errorButtonText : ""
        )
        updateErrorAccessibility(text: currentErrorText, shouldAnnounce: !errorAlert.isHidden)
    }

    func updateLoadingAccessibility(isLoading: Bool) {
        spinner.accessibilityLabel = LocalizedKey.loadingContentDescription.localized

        guard isLoading else { return }
        postAccessibilityAnnouncement(LocalizedKey.loadingContentDescription.localized)
    }

    func updateWarningAccessibility(text: String, shouldAnnounce: Bool) {
        warningTitleLabel.accessibilityLabel = text

        guard shouldAnnounce, !text.isEmpty else { return }
        postAccessibilityAnnouncement(text)
    }

    func updateErrorAccessibility(text: String, shouldAnnounce: Bool) {
        errorAlert.accessibilityLabel = text

        guard shouldAnnounce, !text.isEmpty else { return }
        postAccessibilityAnnouncement(text)
    }

    func postAccessibilityAnnouncement(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func resolveIcon(_ icon: LDIconValue) -> UIImage {
        var tokens = LivingDesign.LDToken(
            in: Bundle(for: LDRootViewController.self),
            for: "LDToken"
        )
        tokens.update(with: traitCollection)
        return icon.resolve(with: tokens)
    }
}
