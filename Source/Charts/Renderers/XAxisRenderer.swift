//
//  XAxisRenderer.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif

@objc(ChartXAxisRenderer)
open class XAxisRenderer: AxisRendererBase
{
    @objc public init(viewPortHandler: ViewPortHandler, xAxis: XAxis?, transformer: Transformer?)
    {
        super.init(viewPortHandler: viewPortHandler, transformer: transformer, axis: xAxis)
    }
    
    open override func computeAxis(min: Double, max: Double, inverted: Bool)
    {
        var min = min, max = max
        
        if let transformer = self.transformer
        {
            // calculate the starting and entry point of the y-labels (depending on
            // zoom / contentrect bounds)
            if viewPortHandler.contentWidth > 10 && !viewPortHandler.isFullyZoomedOutX
            {
                let p1 = transformer.valueForTouchPoint(CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentTop))
                let p2 = transformer.valueForTouchPoint(CGPoint(x: viewPortHandler.contentRight, y: viewPortHandler.contentTop))
                
                if inverted
                {
                    min = Double(p2.x)
                    max = Double(p1.x)
                }
                else
                {
                    min = Double(p1.x)
                    max = Double(p2.x)
                }
            }
        }
        
        computeAxisValues(min: min, max: max)
    }
    
    open override func computeAxisValues(min: Double, max: Double)
    {
        super.computeAxisValues(min: min, max: max)
        
        computeSize()
    }
    
    @objc open func computeSize()
    {
        guard let
            xAxis = self.axis as? XAxis
            else { return }
        
        let longest = xAxis.getLongestLabel()
        
        let labelSize = longest.size(withAttributes: [.font: xAxis.labelFont])
        
        let labelWidth = labelSize.width
        let labelHeight = labelSize.height
        
        let labelRotatedSize = labelSize.rotatedBy(degrees: xAxis.labelRotationAngle)
        
        xAxis.labelWidth = labelWidth
        xAxis.labelHeight = labelHeight
        xAxis.labelRotatedWidth = labelRotatedSize.width
        xAxis.labelRotatedHeight = labelRotatedSize.height
    }
    
    open override func renderAxisLabels(context: CGContext)
    {
        guard let xAxis = self.axis as? XAxis else { return }
        
        if !xAxis.isEnabled || !xAxis.isDrawLabelsEnabled
        {
            return
        }
        
        let yOffset = xAxis.yOffset
        
        if xAxis.labelPosition == .top
        {
            drawLabels(context: context, pos: viewPortHandler.contentTop - yOffset, anchor: CGPoint(x: 0.5, y: 1.0))
        }
        else if xAxis.labelPosition == .topInside
        {
            drawLabels(context: context, pos: viewPortHandler.contentTop + yOffset + xAxis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 1.0))
        }
        else if xAxis.labelPosition == .bottom
        {
            drawLabels(context: context, pos: viewPortHandler.contentBottom + yOffset, anchor: CGPoint(x: 0.5, y: 0.0))
        }
        else if xAxis.labelPosition == .bottomInside
        {
            drawLabels(context: context, pos: viewPortHandler.contentBottom - yOffset - xAxis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 0.0))
        }
        else
        { // BOTH SIDED
            drawLabels(context: context, pos: viewPortHandler.contentTop - yOffset, anchor: CGPoint(x: 0.5, y: 1.0))
            drawLabels(context: context, pos: viewPortHandler.contentBottom + yOffset, anchor: CGPoint(x: 0.5, y: 0.0))
        }
    }
    
    private var _axisLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    open override func renderAxisLine(context: CGContext)
    {
        guard let xAxis = self.axis as? XAxis else { return }
        
        if !xAxis.isEnabled || !xAxis.isDrawAxisLineEnabled
        {
            return
        }
        
        context.saveGState()
        
        context.setStrokeColor(xAxis.axisLineColor.cgColor)
        context.setLineWidth(xAxis.axisLineWidth)
        if xAxis.axisLineDashLengths != nil
        {
            context.setLineDash(phase: xAxis.axisLineDashPhase, lengths: xAxis.axisLineDashLengths)
        }
        else
        {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        
        if xAxis.labelPosition == .top
            || xAxis.labelPosition == .topInside
            || xAxis.labelPosition == .bothSided
        {
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentTop
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentTop
            context.strokeLineSegments(between: _axisLineSegmentsBuffer)
        }
        
        if xAxis.labelPosition == .bottom
            || xAxis.labelPosition == .bottomInside
            || xAxis.labelPosition == .bothSided
        {
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentBottom
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
            context.strokeLineSegments(between: _axisLineSegmentsBuffer)
        }
        
        context.restoreGState()
    }
    
    /// draws the x-labels on the specified y-position
    @objc open func drawLabels(context: CGContext, pos: CGFloat, anchor: CGPoint)
    {
        guard
            let xAxis = self.axis as? XAxis,
            let transformer = self.transformer
            else { return }
        
        #if os(OSX)
            let paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        #else
            let paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        #endif
        paraStyle.alignment = .center
        
        let labelAttrs: [NSAttributedString.Key : Any] = [.font: xAxis.labelFont,
            .foregroundColor: xAxis.labelTextColor,
            .paragraphStyle: paraStyle]
        let labelRotationAngleRadians = xAxis.labelRotationAngle.DEG2RAD
        
        let centeringEnabled = xAxis.isCenterAxisLabelsEnabled

        let valueToPixelMatrix = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        var labelMaxSize = CGSize()
        
        if xAxis.isWordWrapEnabled
        {
            labelMaxSize.width = xAxis.wordWrapWidthPercent * valueToPixelMatrix.a
        }
        
        let entries = xAxis.entries
        
        for i in stride(from: 0, to: entries.count, by: 1)
        {
            if centeringEnabled
            {
                position.x = CGFloat(xAxis.centeredEntries[i])
            }
            else
            {
                position.x = CGFloat(entries[i])
            }
            
            position.y = 0.0
            position = position.applying(valueToPixelMatrix)
            
            if viewPortHandler.isInBoundsX(position.x)
            {
                let label = xAxis.valueFormatter?.stringForValue(xAxis.entries[i], axis: xAxis) ?? ""

                let labelns = label as NSString
                
                if xAxis.isAvoidFirstLastClippingEnabled
                {
                    // avoid clipping of the last
                    if i == xAxis.entryCount - 1 && xAxis.entryCount > 1
                    {
                        let width = labelns.boundingRect(with: labelMaxSize, options: .usesLineFragmentOrigin, attributes: labelAttrs, context: nil).size.width
                        
                        if width > viewPortHandler.offsetRight * 2.0
                            && position.x + width > viewPortHandler.chartWidth
                        {
                            position.x -= width / 2.0
                        }
                    }
                    else if i == 0
                    { // avoid clipping of the first
                        let width = labelns.boundingRect(with: labelMaxSize, options: .usesLineFragmentOrigin, attributes: labelAttrs, context: nil).size.width
                        position.x += width / 2.0
                    }
                }
                
                drawLabel(context: context,
                          formattedLabel: label,
                          x: position.x,
                          y: pos,
                          attributes: labelAttrs,
                          constrainedToSize: labelMaxSize,
                          anchor: anchor,
                          angleRadians: labelRotationAngleRadians)
            }
        }
    }
    
    @objc open func drawLabel(
        context: CGContext,
        formattedLabel: String,
        x: CGFloat,
        y: CGFloat,
        attributes: [NSAttributedString.Key : Any],
        constrainedToSize: CGSize,
        anchor: CGPoint,
        angleRadians: CGFloat)
    {
        ChartUtils.drawMultilineText(
            context: context,
            text: formattedLabel,
            point: CGPoint(x: x, y: y),
            attributes: attributes,
            constrainedToSize: constrainedToSize,
            anchor: anchor,
            angleRadians: angleRadians)
    }
    
    open override func renderGridLines(context: CGContext)
    {
        guard
            let xAxis = self.axis as? XAxis,
            let transformer = self.transformer
            else { return }
        
        if !xAxis.isDrawGridLinesEnabled || !xAxis.isEnabled
        {
            return
        }
        
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: self.gridClippingRect)
        
        context.setShouldAntialias(xAxis.gridAntialiasEnabled)
        context.setStrokeColor(xAxis.gridColor.cgColor)
        context.setLineWidth(xAxis.gridLineWidth)
        context.setLineCap(xAxis.gridLineCap)
        
        if xAxis.gridLineDashLengths != nil
        {
            context.setLineDash(phase: xAxis.gridLineDashPhase, lengths: xAxis.gridLineDashLengths)
        }
        else
        {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        
        let valueToPixelMatrix = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        let entries = xAxis.entries
        
        for i in stride(from: 0, to: entries.count, by: 1)
        {
            position.x = CGFloat(entries[i])
            position.y = position.x
            position = position.applying(valueToPixelMatrix)
            
            drawGridLine(context: context, x: position.x, y: position.y)
        }
    }
    
    @objc open var gridClippingRect: CGRect
    {
        var contentRect = viewPortHandler.contentRect
        let dx = self.axis?.gridLineWidth ?? 0.0
        contentRect.origin.x -= dx / 2.0
        contentRect.size.width += dx
        return contentRect
    }
    
    @objc open func drawGridLine(context: CGContext, x: CGFloat, y: CGFloat)
    {
        if x >= viewPortHandler.offsetLeft
            && x <= viewPortHandler.chartWidth
        {
            context.beginPath()
            context.move(to: CGPoint(x: x, y: viewPortHandler.contentTop))
            context.addLine(to: CGPoint(x: x, y: viewPortHandler.contentBottom))
            context.strokePath()
        }
    }

    open override func renderLimitLines(context: CGContext)
    {
        guard
            let xAxis = self.axis as? XAxis,
            let transformer = self.transformer
            else { return }

        var limitLines = xAxis.limitLines
        
        if limitLines.count == 0
        {
            return
        }
        
        let trans = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        for i in 0 ..< limitLines.count
        {
            let l = limitLines[i]
            
            if !l.isEnabled
            {
                continue
            }
            
            context.saveGState()
            defer { context.restoreGState() }
            
            var clippingRect = viewPortHandler.contentRect
            clippingRect.origin.x -= l.lineWidth / 2.0
            clippingRect.size.width += l.lineWidth
            context.clip(to: clippingRect)
            
            position.x = CGFloat(l.limit)
            position.y = 0.0
            position = position.applying(trans)
            
            renderLimitLineLine(context: context, limitLine: l, position: position)
            renderLimitLineLabel(context: context, limitLine: l, position: position, yOffset: 2.0 + l.yOffset)
        }
    }


    open func renderBlocks(context: CGContext) {
        guard
            let xAxis = self.axis as? XAxis
            else { return }
        for block in xAxis.blocks {
            renderBlock(context: context, start: block.start, length: block.length)
        }
    }

    open func renderBlock(context: CGContext, start: Double, length: Double) {
        guard
            let xAxis = self.axis as? XAxis,
            let transformer = self.transformer
            else { return }

        context.saveGState()
        defer { context.restoreGState() }

        let trans = transformer.valueToPixelMatrix
        let lineGap: CGFloat = 3.7
        let lineWidth: CGFloat = xAxis.blockStrokeWidth


        let origin = CGPoint(x: CGFloat(start), y: 0).applying(trans)

        let size = CGSize(width: transformer.pixelForValues(x: length, y: 0).x - transformer.pixelForValues(x: 0, y: 0).x,
                          height: viewPortHandler.contentBottom - viewPortHandler.contentTop + xAxis.axisLineWidth)

        context.setFillColor(xAxis.blocksFillColor)

        let fillRect = CGRect(origin: CGPoint(x: origin.x, y: 0),
                              size: size)

        let intersection = viewPortHandler.contentRect.intersection(fillRect)
        let clipBound = intersection.size == .zero ? CGRect.zero : intersection
        context.clip(to: CGRect(origin: clipBound.origin, size: size))
        context.fill(fillRect)

        context.beginPath()

        let bounds = fillRect
        let totalDistance = bounds.size.width + bounds.size.height

        for distance in stride(from: 0, through: totalDistance, by: (lineGap + lineWidth)) {

            let startPoint = CGPoint(x: distance < bounds.width ? bounds.origin.x + distance : bounds.origin.x + bounds.width,
                                     y: distance < bounds.width ? bounds.origin.y : distance - (bounds.width))

            let endPoint = CGPoint(x: distance < bounds.height ? bounds.origin.x : distance - (bounds.height - bounds.origin.x),
                                   y: distance < bounds.height ?
                                    bounds.origin.y + distance :
                                    bounds.origin.y + bounds.height)

            context.move(to: startPoint)
            context.addLine(to: endPoint)
        }

        context.setStrokeColor(xAxis.blocksStrokeColor)
        context.setLineWidth(lineWidth)
        context.strokePath()

        context.move(to: CGPoint(x: fillRect.origin.x, y: fillRect.height - xAxis.axisLineWidth))
        context.addLine(to: CGPoint(x: fillRect.origin.x + fillRect.width, y: fillRect.height - xAxis.axisLineWidth))
        context.setStrokeColor(xAxis.axisLineColor.cgColor)
        context.setLineWidth(xAxis.axisLineWidth)
        context.setLineDash(phase: 0, lengths: [2, 2])
        context.strokePath()
    }

    private func renderBlockGradient(context: CGContext, start: Double, length: Double) {
        guard
            let xAxis = self.axis as? XAxis,
            let transformer = self.transformer,
            CFArrayGetCount(xAxis.blockGradientColors) > 0
            else { return }

        context.saveGState()
        defer { context.restoreGState() }

        let trans = transformer.valueToPixelMatrix

        let origin = CGPoint(x: CGFloat(start), y: 0).applying(trans)

        let size = CGSize(width: transformer.pixelForValues(x: length, y: 0).x - transformer.pixelForValues(x: 0, y: 0).x + 1,
                          height: viewPortHandler.contentBottom - viewPortHandler.contentTop)

        let fillRect = CGRect(origin: CGPoint(x: origin.x, y: 0),
                              size: size)

        let intersection = viewPortHandler.contentRect.intersection(fillRect)
        let clipBound = intersection.size == .zero ? CGRect.zero : intersection
        context.clip(to: CGRect(origin: CGPoint(x: clipBound.origin.x - 1.5, y: clipBound.origin.y), size: CGSize(width: clipBound.width + 3, height: clipBound.height)))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace,
                                  colors: xAxis.blockGradientColors,
                                  locations: colorLocations)!

        let startPoint = CGPoint.zero
        let endPoint = CGPoint(x: 0, y: 100)

        context.drawLinearGradient(gradient,
                                   start: startPoint,
                                   end: endPoint,
                                   options: [])
    }

    open func renderBlockGradients(context: CGContext) {
        guard
            let xAxis = self.axis as? XAxis
            else { return }
        for block in xAxis.blocks {
            renderBlockGradient(context: context, start: block.start, length: block.length)
        }
    }
    
    @objc open func renderLimitLineLine(context: CGContext, limitLine: ChartLimitLine, position: CGPoint)
    {
        
        context.beginPath()
        context.move(to: CGPoint(x: position.x, y: viewPortHandler.contentTop))
        context.addLine(to: CGPoint(x: position.x, y: viewPortHandler.contentBottom))
        
        context.setStrokeColor(limitLine.lineColor.cgColor)
        context.setLineWidth(limitLine.lineWidth)
        if limitLine.lineDashLengths != nil
        {
            context.setLineDash(phase: limitLine.lineDashPhase, lengths: limitLine.lineDashLengths!)
        }
        else
        {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        
        context.strokePath()
        if limitLine.shouldRenderBlockGradient {
            renderBlockGradient(context: context, start: limitLine.limit, length: 0)
        }
        guard let transformer = self.transformer,
            let image = limitLine.image else { return }

        let size = limitLine.imageSize
        let xPosition: CGFloat
        let insect = limitLine.imageInsect
        let stickyLength = transformer.pixelForValues(x: limitLine.imageStickyLength, y: 0).x - transformer.pixelForValues(x: 0, y: 0).x

        let originX = viewPortHandler.contentRect.origin.x
        xPosition = max(min(originX + insect.left, position.x + stickyLength - size.width - insect.right), position.x + insect.left)
        let rect = CGRect(x: xPosition, y: viewPortHandler.contentBottom - size.height - limitLine.imageInsect.bottom, width: size.width, height: size.height)

        if let radialGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: limitLine.radialGradientColors, locations: [0, 1]) {
            let center = CGPoint(x: rect.origin.x + size.width / 2, y: rect.origin.y + size.height / 2)
            context.drawRadialGradient(radialGradient, startCenter: center, startRadius: size.width / 2, endCenter: center, endRadius: 1, options: [])
        }

        if let tintColor = limitLine.imageTint {
            tint(image: image, with: tintColor).draw(in: rect)
        } else {
            image.draw(in: rect)
        }
    }

    // Adapted from: https://gist.github.com/iamjason/a0a92845094f5b210cf8
    @objc private func tint(image: UIImage, with color: UIColor) -> UIImage {
        UIGraphicsBeginImageContext(image.size)
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        guard let cgImage = image.cgImage else { return image }

        // flip the image
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0.0, y: -image.size.height)

        // multiply blend mode
        context.setBlendMode(.multiply)

        let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        context.clip(to: rect, mask: cgImage)
        color.setFill()
        context.fill(rect)

        // create uiimage
        guard let tintedImage = UIGraphicsGetImageFromCurrentImageContext() else { return image }
        UIGraphicsEndImageContext()

        return tintedImage
    }
    
    @objc open func renderLimitLineLabel(context: CGContext, limitLine: ChartLimitLine, position: CGPoint, yOffset: CGFloat)
    {
        
        let label = limitLine.label
        
        // if drawing the limit-value label is enabled
        if limitLine.drawLabelEnabled && label.count > 0
        {
            let labelLineHeight = limitLine.valueFont.lineHeight
            
            let xOffset: CGFloat = limitLine.lineWidth + limitLine.xOffset
            
            if limitLine.labelPosition == .rightTop
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x + xOffset,
                        y: viewPortHandler.contentTop + yOffset),
                    align: .left,
                    attributes: [.font: limitLine.valueFont, .foregroundColor: limitLine.valueTextColor])
            }
            else if limitLine.labelPosition == .rightBottom
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x + xOffset,
                        y: viewPortHandler.contentBottom - labelLineHeight - yOffset),
                    align: .left,
                    attributes: [.font: limitLine.valueFont, .foregroundColor: limitLine.valueTextColor])
            }
            else if limitLine.labelPosition == .leftTop
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x - xOffset,
                        y: viewPortHandler.contentTop + yOffset),
                    align: .right,
                    attributes: [.font: limitLine.valueFont, .foregroundColor: limitLine.valueTextColor])
            }
            else
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x - xOffset,
                        y: viewPortHandler.contentBottom - labelLineHeight - yOffset),
                    align: .right,
                    attributes: [.font: limitLine.valueFont, .foregroundColor: limitLine.valueTextColor])
            }
        }
    }

}
