private func displayScanner() {
    guard navigationController.presentedViewController == nil else {
        return
    }

    guard let searchAPI = container.getIfRegistered(SearchAPI.self),
          let handler = searchAPI.productScanHandler() as? ScanHandler,
          let itemDetailsAPI = container.getIfRegistered(ItemDetailsAPI.self)
    else {
        let alert = UIAlertController(
            title: "POC setup incomplete",
            message: "The Glass product lookup or item-details component is unavailable.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        navigationController.present(alert, animated: true)
        return
    }

    let scanner = OsirisPOCViewController(
        scanHandler: handler,
        onProduct: { [weak self] product in
            guard let self else { return }

            let coordinator = itemDetailsAPI.presentItemDetailPage(
                in: self.navigationController,
                with: ItemDetailsContext(
                    itemID: product.usItemID.rawValue,
                    source: .searchScan
                ),
                completionHandler: nil
            )
            self.addChild(coordinator: coordinator)
        }
    )

    let modal = GlassNavigationController(rootViewController: scanner)
    modal.modalPresentationStyle = .fullScreen

    scanAnalytics.trackUSGLCO6267S1T1(
        pageName: UIApplication.shared.pageName ?? .homePage
    )

    navigationController.present(modal, animated: true)
}
