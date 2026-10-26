//
//  CanvasTransforming.swift
//  Osiris
//
//  Created by Kyle McGinnis on 1/5/24.
//

import Foundation
import Vision

public protocol CanvasTransforming {
    
    func calculateROI(with pixelBuffer: CVImageBuffer,
                      canvasSize: CGSize,
                      reticleRect: CGRect,
                      reticleEnabled: Bool) -> CGRect
    
    func transformRect(originalBounds: CGRect,
                       from oldContainerSize: CGSize,
                       to newContainerSize: CGSize,
                       originOffset offset: CGPoint,
                       sizeOffset: CGSize,
                       flipHorizontally shouldFlipHorizontally: Bool) -> CGRect
    
    func transformRectOrigin(_ rect: CGRect,
                             to newOrigin: CGPoint) -> CGRect
    
    func transformRect(fromNormalizedRect fromRect: CGRect,
                       toSize size: CGSize) -> CGRect
    
    func normalizedRect(for rect: CGRect, withinFrame frame: CGRect) -> CGRect
    
}

public extension CanvasTransforming {
    
    func calculateROI(with pixelBuffer: CVImageBuffer,
                      canvasSize: CGSize,
                      reticleRect: CGRect,
                      reticleEnabled: Bool) -> CGRect {
        let roiSize = canvasSize.width > 0 && canvasSize.height > 0 ? canvasSize : pixelBuffer.rect().size
        let pixelBufferSize = pixelBuffer.rect().size

        let reticleIsValid = reticleRect.width > 0 && reticleRect.height > 0 && reticleEnabled

        if reticleEnabled && reticleIsValid {
            // Use the minimum scale to preserve aspect ratio
            let scale = min(pixelBufferSize.width / roiSize.width, pixelBufferSize.height / roiSize.height)
            let scaledReticleSize = CGSize(width: reticleRect.width * scale, height: reticleRect.height * scale)
            let scaledReticleOrigin = CGPoint(
                x: (reticleRect.origin.x * scale) + (pixelBufferSize.width - roiSize.width * scale) / 2,
                y: (reticleRect.origin.y * scale) + (pixelBufferSize.height - roiSize.height * scale) / 2
            )
            return CGRect(origin: scaledReticleOrigin, size: scaledReticleSize)
        } else {
           // Reticle disabled
           let scale = min(pixelBufferSize.width / roiSize.width, pixelBufferSize.height / roiSize.height)
           let scaledROISize = CGSize (
               width: pixelBufferSize.width, height: ceil(roiSize.height * scale) )

           let scaledROIOrigin = CGPoint(
               x: 0,
               y: floor((pixelBufferSize.height - scaledROISize.height) / 2)
           )

           return CGRect(origin: scaledROIOrigin, size: scaledROISize)
        }
    }
    
    func transformRect(originalBounds: CGRect,
                       from oldContainerSize: CGSize,
                       to newContainerSize: CGSize,
                       originOffset offset: CGPoint,
                       sizeOffset: CGSize,
                       flipHorizontally shouldFlipHorizontally: Bool = false) -> CGRect {
        guard oldContainerSize.width > 0, oldContainerSize.height > 0,
              newContainerSize.width > 0, newContainerSize.height > 0 else {
            return .zero
        }

        // Calculate scaling factors for width and height
        let scaleX = newContainerSize.width / oldContainerSize.width
        let scaleY = newContainerSize.height / oldContainerSize.height

        // Use the larger scaling factor to preserve aspect ratio
        let uniformScaleFactor = max(scaleX, scaleY)

        // Scale the original bounds uniformly
        let scaledWidth = originalBounds.width * uniformScaleFactor
        let scaledHeight = originalBounds.height * uniformScaleFactor

        let scaledOriginX = originalBounds.origin.x * uniformScaleFactor
        let scaledOriginY = originalBounds.origin.y * uniformScaleFactor
        
        // Cropped-image coordinates begin at the crop's origin in the preview,
        // which may be off-center. Without a crop, center the aspect-fill image.
        // `offset` is already in preview points; it must not be scaled again.
        let offsetX = sizeOffset == .zero
            ? (newContainerSize.width - oldContainerSize.width * uniformScaleFactor) / 2
            : offset.x
        let offsetY = sizeOffset == .zero
            ? (newContainerSize.height - oldContainerSize.height * uniformScaleFactor) / 2
            : offset.y
        
        // Create and return the transformed rectangle
        let result = CGRect(x: scaledOriginX + offsetX, y: scaledOriginY + offsetY, width: scaledWidth, height: scaledHeight)
        
        if shouldFlipHorizontally {
            let flippedOriginX = newContainerSize.width - result.origin.x - result.size.width
            let flippedBB = CGRect(x: flippedOriginX, y: result.origin.y, width: result.size.width, height: result.size.height)
            
            // If result isn't valid no rectangle is displayed
            return flippedBB.isValid() ? flippedBB : .zero
        }
        
        // If result isn't valid no rectangle is displayed
        return result.isValid() ? result : .zero
    }
    
    func transformRectOrigin(_ rect: CGRect, to newOrigin: CGPoint) -> CGRect {
        let offsetX = newOrigin.x - rect.origin.x
        let offsetY = newOrigin.y - rect.origin.y

        return rect.offsetBy(dx: offsetX, dy: offsetY)
    }
    
    // To do: Replace this with a simple function that doesn't require Vision
    func normalizedRect(for rect: CGRect, withinFrame frame: CGRect) -> CGRect {
        VNNormalizedRectForImageRect(rect, Int(frame.width), Int(frame.height))
    }
}
