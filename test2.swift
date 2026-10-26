//
//  BarcodeBoundingBoxes.swift
//  Diamond-sdk
//
//  Created by Andres Vinueza on 9/14/23.
//

import Combine
import UIKit
import Osiris
import OsirisBarcode

@available(iOS 13.0, *)
final class BarcodeBoundingBoxes: UIView {
    @Published var foundBox: CGRect = .zero
    @Published var foundBarcodeBox: BarcodeBoundingBox?
    
    var isReticleEnabled: Bool = false
    var reticlePoint: CGPoint?
    
    var context: OsirisDataCaptureContext?
    var config: OsirisConfig? {
        guard let context else {
            return nil
        }
        
        return OsirisApp.shared.getConfig(forContext: context)
    }
    
    var didTapOnEmptyArea: ((_ gesture: UITapGestureRecognizer) -> Void)?

    /// Suppress SDK artwork without hiding the view that also handles tap-to-focus.
    var isRenderingEnabled = true {
        didSet {
            guard oldValue != isRenderingEnabled else { return }
            if isRenderingEnabled {
                drawBox(with: bBoundingBoxes)
            } else {
                clearRenderedBoxes()
            }
        }
    }

    private var displayUpdateTimer:Timer?
    
    private func scheduledDisplayUpdate() {
        displayUpdateTimer?.invalidate()
        guard isRenderingEnabled else { return }
        displayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { [weak self] _ in
            self?.setNeedsDisplay()
        })
    }
    
    private var boundingBoxSettings: [BarcodeValue: OsirisBoundingBoxConfig] = [:]
    private var barcodeNamesToBeRemoved: Set<String> = []
    private var bBoundingBoxes: [BarcodeBoundingBox] = [] {
        didSet {
            self.drawBox(with: bBoundingBoxes)
            scheduledDisplayUpdate()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        addGestureRecognizer(tapGesture)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateBarcodes(_ barcodeBoxes: [BarcodeBoundingBox], customSettings: [BarcodeValue: OsirisBoundingBoxConfig]) {
        // Step 0: Clear out `barcodeBoundingBoxesToBeRemoved`
        barcodeNamesToBeRemoved = []
        
        // Step 1: Create a dictionary from the new array for quick lookups
        var newBarcodeDict = [String: BarcodeBoundingBox]()
        for barcodeBox in barcodeBoxes {
            newBarcodeDict[barcodeBox.barcode.value] = barcodeBox
        }
        
        // Step 2: Update existing entries and prepare for removal
        var updatedBoundingBoxes = [BarcodeBoundingBox]()
        for (barcode, _) in bBoundingBoxes {
            if let newValues = newBarcodeDict[barcode.value] {
                // Coordinates are already in preview space. Preserve the complete latest
                // result, including corner points and GS1 metadata, for tap callbacks.
                updatedBoundingBoxes.append(newValues)
                newBarcodeDict.removeValue(forKey: barcode.value)
            } else {
                // Existing entry is not in the new array, so it will be removed
                barcodeNamesToBeRemoved.insert(barcode.value)
            }
        }
        
        // Step 3: Append new entries that were not present before
        for barcodeBox in newBarcodeDict.values {
            updatedBoundingBoxes.append(barcodeBox)
        }
        
        boundingBoxSettings = customSettings
        
        // Update the barcodeBoundingBoxes with the updated list
        bBoundingBoxes = updatedBoundingBoxes
        
        // Redraw the view
        scheduledDisplayUpdate()
    }
    
    private func drawBox(with barcodeBoxes: [BarcodeBoundingBox]) {
        guard isRenderingEnabled else {
            clearRenderedBoxes()
            return
        }
        var boxesToAdd = barcodeBoxes
        
        // 1. Remove old layers
        removeOldLayers()

        // 2. Update existing layers
        layer.sublayers?.forEach { layer in
            guard
                let name = layer.name,
                let barcodeBoxIndex = boxesToAdd.firstIndex(where: { $0.barcode.value == name }),
                let existingShapeLayer = layer as? CAShapeLayer
            else {
                return
            }

            let barcodeBox = boxesToAdd[barcodeBoxIndex]
            let currentConfig = boundingBoxSettings[barcodeBox.barcode.value] ?? config?.boundingBoxConfig
            
            let adjustedBoundingBox = barcodeBox.boundingBox

            // Update the main shape layer (path, stroke, fill)
            updateShapeLayer(existingShapeLayer, with: barcodeBox, config: currentConfig)

            // Update title and icon layers
            updateOrAddTitleLayer(to: existingShapeLayer, adjustedBoundingBox: adjustedBoundingBox, titleBox: currentConfig?.titleBox)
            updateOrAddIconLayer(to: existingShapeLayer, adjustedBoundingBox: adjustedBoundingBox, iconImage: currentConfig?.centerIconImage)

            boxesToAdd.remove(at: barcodeBoxIndex)
        }

        // 3. Add new bounding boxes for any remaining barcodes
        addNewBarcodes(boxesToAdd)
    }

    // MARK: - Helper Methods

    private func clearRenderedBoxes() {
        displayUpdateTimer?.invalidate()
        displayUpdateTimer = nil
        // Titles and icons are children of these shape layers and disappear with them.
        layer.sublayers?.compactMap { $0 as? CAShapeLayer }.forEach {
            $0.removeAllAnimations()
            $0.removeFromSuperlayer()
        }
        foundBarcodeBox = nil
        foundBox = .zero
    }

    private func removeOldLayers() {
        layer.sublayers?.forEach { layer in
            if let name = layer.name, barcodeNamesToBeRemoved.contains(name) {
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.3)
                CATransaction.setCompletionBlock { [weak layer] in
                    layer?.removeFromSuperlayer()
                }
                
                layer.opacity = 0
                CATransaction.commit()
                
                barcodeNamesToBeRemoved.remove(name)
            }
        }
    }

    private func updateShapeLayer(_ existingShapeLayer: CAShapeLayer, with barcodeBox: BarcodeBoundingBox, config: OsirisBoundingBoxConfig?) {
        let adjustedBoundingBox = barcodeBox.boundingBox
        let newPath: CGPath = {
            if barcodeBox.barcode.quadPointsInCameraPreview.count == 4 {
                return UIBezierPath.path(for: barcodeBox.barcode.quadPointsInCameraPreview).cgPath
            } else {
                return UIBezierPath(
                    roundedRect: adjustedBoundingBox,
                    cornerRadius: config?.borderCornerRadius ?? 0
                ).cgPath
            }
        }()

        if existingShapeLayer.path != newPath {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = existingShapeLayer.path
            anim.toValue = newPath
            anim.duration = 0.2
            existingShapeLayer.add(anim, forKey: "pathAnimation")
            existingShapeLayer.path = newPath
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        existingShapeLayer.fillColor = config?.backgroundColor?.cgColor
        existingShapeLayer.strokeColor = config?.borderColor.cgColor ?? UIColor.yellow100.cgColor
        existingShapeLayer.lineWidth = config?.borderThickness ?? 3
        CATransaction.commit()
        
    }

    private func updateOrAddTitleLayer(to shapeLayer: CAShapeLayer, adjustedBoundingBox: CGRect, titleBox: OsirisBoundingBoxConfig.TitleBox?) {
        
        // Find existing title layer if any
        let titleLayer = shapeLayer.sublayers?.compactMap { $0 as? CenterTextLayer }.first

        if let titleBox = titleBox {
            // If we have a title configuration
            let titleFrame = calculateTitleFrame(for: titleBox.positioning, in: adjustedBoundingBox, text: titleBox.title, font: titleBox.titleFont)

            if let existingTitleLayer = titleLayer {
                // Update existing title layer
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                existingTitleLayer.frame = titleFrame
                existingTitleLayer.string = titleBox.title
                existingTitleLayer.fontSize = titleBox.titleFont.pointSize
                existingTitleLayer.font = titleBox.titleFont
                existingTitleLayer.foregroundColor = titleBox.titleColor.cgColor
                
                if let bgColor = titleBox.backgroundColor {
                    existingTitleLayer.backgroundColor = bgColor.cgColor
                    existingTitleLayer.cornerRadius = titleBox.backgroundCornerRadius
                } else {
                    existingTitleLayer.backgroundColor = nil
                    existingTitleLayer.cornerRadius = 0
                }
                
                CATransaction.commit()
                
            } else {
                // Add a new title layer
                let newTitleLayer = CenterTextLayer()
                newTitleLayer.contentsScale = UIScreen.main.scale
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                newTitleLayer.frame = titleFrame
                newTitleLayer.string = titleBox.title
                newTitleLayer.fontSize = titleBox.titleFont.pointSize
                newTitleLayer.font = titleBox.titleFont
                newTitleLayer.foregroundColor = titleBox.titleColor.cgColor
                
                if let bgColor = titleBox.backgroundColor
                {
                    newTitleLayer.backgroundColor = bgColor.cgColor
                    newTitleLayer.cornerRadius = titleBox.backgroundCornerRadius
                }
                newTitleLayer.alignmentMode = .center
                shapeLayer.addSublayer(newTitleLayer)
                CATransaction.commit()
            }
            
        } else {
            // No titleBox, remove title layer if any
            titleLayer?.removeFromSuperlayer()
        }
    }

    private func updateOrAddIconLayer(to shapeLayer: CAShapeLayer, adjustedBoundingBox: CGRect, iconImage: UIImage?) {
        
        // Find an existing icon layer if any. We assume here that the icon layer is distinct and not a CenterTextLayer.
        let iconLayer = shapeLayer.sublayers?.first(where: { sublayer in
            guard let sub = sublayer as? CALayer, !(sub is CenterTextLayer) else { return false }
            return true
            
        }) as? CALayer

        if let iconImage = iconImage {
            // Calculate icon size and frame
            let imageAspectRatio = iconImage.size.width / iconImage.size.height
            let targetWidth = adjustedBoundingBox.width * 0.5
            let targetHeight = adjustedBoundingBox.height * 0.5
            var iconSize = CGSize(width: targetWidth, height: targetHeight)
            
            if imageAspectRatio > 1
            {
                iconSize.height = iconSize.width / imageAspectRatio
            }
            else {
                iconSize.width = iconSize.height * imageAspectRatio
            }

            let iconFrame = CGRect(
                x: adjustedBoundingBox.midX - iconSize.width / 2,
                y: adjustedBoundingBox.midY - iconSize.height / 2,
                width: iconSize.width,
                height: iconSize.height
            )

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if let existingIconLayer = iconLayer
            {
                existingIconLayer.frame = iconFrame
                existingIconLayer.contents = iconImage.cgImage
            }
            else
            {
                let newIconLayer = CALayer()
                newIconLayer.frame = iconFrame
                newIconLayer.contents = iconImage.cgImage
                shapeLayer.addSublayer(newIconLayer)
            }
            CATransaction.commit()
        }
        else
        {
            // No icon image provided, remove icon layer if present
            iconLayer?.removeFromSuperlayer()
        }
    }

    private func addNewBarcodes(_ boxes: [BarcodeBoundingBox]) {
       
        for barcodeBox in boxes {
            let adjustedBoundingBox = barcodeBox.boundingBox
            let shapeLayer = CAShapeLayer()
            let currentConfig = boundingBoxSettings[barcodeBox.barcode.value] ?? config?.boundingBoxConfig
            
            if barcodeBox.barcode.quadPointsInCameraPreview.count == 4 {
                shapeLayer.path = UIBezierPath.path(for: barcodeBox.barcode.quadPointsInCameraPreview).cgPath
            } else {
                shapeLayer.path = UIBezierPath(roundedRect: adjustedBoundingBox, cornerRadius: currentConfig?.borderCornerRadius ?? 0).cgPath
            }
            
            shapeLayer.fillColor = currentConfig?.backgroundColor?.cgColor
            shapeLayer.strokeColor = currentConfig?.borderColor.cgColor ?? UIColor.yellow100.cgColor
            shapeLayer.lineWidth = currentConfig?.borderThickness ?? 3
            shapeLayer.name = barcodeBox.barcode.value
            layer.addSublayer(shapeLayer)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // Add Title if needed
            if let titleBox = currentConfig?.titleBox
            {
                updateOrAddTitleLayer(to: shapeLayer, adjustedBoundingBox: adjustedBoundingBox, titleBox: titleBox)
            }

            // Add Icon if needed
            if let iconImage = currentConfig?.centerIconImage
            {
                updateOrAddIconLayer(to: shapeLayer, adjustedBoundingBox: adjustedBoundingBox, iconImage: iconImage)
            }
            CATransaction.commit()
        }
    }
    
    // Function to calculate the title frame based on the text content and position
    private func calculateTitleFrame(
        for position: OsirisBoundingBoxConfig.TitleBox.Positioning,
        in boundingBox: CGRect,
        text: String?,
        font: UIFont
    ) -> CGRect {
        guard let text = text else { return .zero }
        
        // Calculate the title size based on the text content and font size
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let titleSize = (text as NSString).size(withAttributes: attributes)
        
        let adjustedBoundingBox = boundingBox
        
        // Calculate width and height as needed
        let width = max(titleSize.width, adjustedBoundingBox.width) + 6
        let height = max(titleSize.height, adjustedBoundingBox.height)
        
        // Determine the frame based on positioning
        switch position {
        case .top:
            return CGRect(
                x: adjustedBoundingBox.midX - width / 2,
                y: adjustedBoundingBox.minY - titleSize.height - 4,
                width: width,
                height: titleSize.height
            )
        case .left:
            return CGRect(
                x: adjustedBoundingBox.minX - titleSize.width - 6 - 4,
                y: adjustedBoundingBox.midY - height / 2,
                width: titleSize.width + 6,
                height: height
            )
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isRenderingEnabled, gesture.state == .ended, !bBoundingBoxes.isEmpty else {
            didTapOnEmptyArea?(gesture)
            return
        }
        
        let tapPoint = gesture.location(in: self)
        let boundingBoxIndex = bBoundingBoxes.firstIndex { $0.boundingBox.contains(tapPoint) }
        
        guard let foundBoxIndex = boundingBoxIndex else {
            return
        }
        
        self.foundBarcodeBox = bBoundingBoxes[foundBoxIndex]
    }
    
}

private extension UIBezierPath {
    static func path(for points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.close()
        return path
    }
}
