//
//  PDFService+Drawing.swift
//  WorkTimer
//
//  Primitives de dessin partagées par les pages du PDF.
//

import UIKit

extension PDFService {
    // MARK: - Helper Drawing Methods
    
    func drawGradientBackground(pageRect: CGRect, theme: PDFTheme) {
        let context = UIGraphicsGetCurrentContext()!
        let colors = [
            theme.backgroundColor.cgColor,
            theme.backgroundColor.withAlphaComponent(0.8).cgColor
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 1.0]
        
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: colorLocations
        )!
        
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(x: 0, y: pageRect.height)
        
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
    }
    
    func drawCenteredText(_ text: String, rect: CGRect, font: UIFont, color: UIColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        text.draw(in: rect, withAttributes: attributes)
    }
    
    func drawStatsBox(rect: CGRect, title: String, value: String, icon: String, color: UIColor) {
        // Arrière-plan du cadre
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        UIColor.white.setFill()
        path.fill()
        
        // Ombre
        color.withAlphaComponent(0.1).setFill()
        let shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        shadowPath.fill()
        
        // Bordure
        color.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 1
        path.stroke()
        
        // Icône
        let _: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24),
            .foregroundColor: color
        ]
        drawCenteredText(icon, rect: CGRect(x: rect.minX, y: rect.minY + 15, width: rect.width, height: 30), font: UIFont.systemFont(ofSize: 24), color: color)
        
        // Valeur
        drawCenteredText(value, rect: CGRect(x: rect.minX, y: rect.minY + 45, width: rect.width, height: 30), font: UIFont.systemFont(ofSize: 20, weight: .bold), color: color)
        
        // Titre
        drawCenteredText(title, rect: CGRect(x: rect.minX, y: rect.minY + 70, width: rect.width, height: 20), font: UIFont.systemFont(ofSize: 12), color: UIColor.gray)
    }
    
    func drawSectionTitle(_ title: String, rect: CGRect, theme: PDFTheme) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: theme.primaryColor
        ]
        
        title.draw(in: rect, withAttributes: attributes)
        
        // Ligne sous le titre
        let lineRect = CGRect(x: rect.minX, y: rect.maxY - 5, width: rect.width, height: 1)
        theme.primaryColor.withAlphaComponent(0.3).setFill()
        UIBezierPath(rect: lineRect).fill()
    }
    
    func drawStatItem(_ label: String, value: String, x: CGFloat, y: CGFloat, color: UIColor? = nil, theme: PDFTheme) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: theme.textColor
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color ?? theme.primaryColor
        ]
        
        label.draw(at: CGPoint(x: x, y: y), withAttributes: labelAttributes)
        value.draw(at: CGPoint(x: x + 140, y: y), withAttributes: valueAttributes)
    }
    
    func drawCellText(_ text: String, rect: CGRect, alignment: NSTextAlignment, font: UIFont, color: UIColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let insetRect = rect.insetBy(dx: 5, dy: 0)
        text.draw(in: insetRect, withAttributes: attributes)
    }
    
    func drawSummaryItem(rect: CGRect, icon: String, title: String, value: String, valueColor: UIColor? = nil, theme: PDFTheme) {
        // Icône
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        if let image = UIImage(systemName: icon, withConfiguration: configuration) {
            let iconRect = CGRect(x: rect.minX, y: rect.minY, width: 20, height: 20)
            image.draw(in: iconRect, blendMode: .normal, alpha: 1.0)
        }
        
        // Titre
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textColor.withAlphaComponent(0.7)
        ]
        
        title.draw(at: CGPoint(x: rect.minX + 25, y: rect.minY), withAttributes: titleAttributes)
        
        // Valeur
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: valueColor ?? theme.primaryColor
        ]
        
        value.draw(at: CGPoint(x: rect.minX + 25, y: rect.minY + 15), withAttributes: valueAttributes)
    }
    
    func drawYAxis(rect: CGRect, maxValue: Double, steps: Int, title: String, theme: PDFTheme) {
        let axisX = rect.minX + 40
        let axisTop = rect.minY + 10
        let axisBottom = rect.maxY - 20
        let axisHeight = axisBottom - axisTop
        
        // Axe vertical
        let axisPath = UIBezierPath()
        axisPath.move(to: CGPoint(x: axisX, y: axisTop))
        axisPath.addLine(to: CGPoint(x: axisX, y: axisBottom))
        theme.textColor.withAlphaComponent(0.3).setStroke()
        axisPath.lineWidth = 1
        axisPath.stroke()
        
        // Titre de l'axe
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.smallFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        title.draw(in: CGRect(x: 0, y: axisTop, width: axisX - 5, height: 20), withAttributes: titleAttributes)
        
        // Graduations
        for i in 0...steps {
            let value = maxValue * Double(i) / Double(steps)
            let y = axisBottom - (CGFloat(i) / CGFloat(steps)) * axisHeight
            
            // Ligne de graduation
            let tickPath = UIBezierPath()
            tickPath.move(to: CGPoint(x: axisX - 5, y: y))
            tickPath.addLine(to: CGPoint(x: axisX, y: y))
            theme.textColor.withAlphaComponent(0.3).setStroke()
            tickPath.lineWidth = 1
            tickPath.stroke()
            
            // Valeur de graduation
            let valueText = String(format: "%.0f", value)
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: theme.textColor.withAlphaComponent(0.7),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .right
                    return style
                }()
            ]
            
            valueText.draw(in: CGRect(x: axisX - 35, y: y - 5, width: 30, height: 10), withAttributes: valueAttributes)
            
            // Ligne horizontale
            if i > 0 {
                let gridPath = UIBezierPath()
                gridPath.move(to: CGPoint(x: axisX, y: y))
                gridPath.addLine(to: CGPoint(x: rect.maxX, y: y))
                theme.textColor.withAlphaComponent(0.1).setStroke()
                gridPath.lineWidth = 0.5
                gridPath.stroke()
            }
        }
    }
    
    func drawYAxisWithRange(rect: CGRect, minValue: Double, maxValue: Double, steps: Int, title: String, theme: PDFTheme) {
        let range = maxValue - minValue
        let axisX = rect.minX + 40
        let axisTop = rect.minY + 10
        let axisBottom = rect.maxY - 20
        let axisHeight = axisBottom - axisTop
        
        // Axe vertical
        let axisPath = UIBezierPath()
        axisPath.move(to: CGPoint(x: axisX, y: axisTop))
        axisPath.addLine(to: CGPoint(x: axisX, y: axisBottom))
        theme.textColor.withAlphaComponent(0.3).setStroke()
        axisPath.lineWidth = 1
        axisPath.stroke()
        
        // Titre de l'axe
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.smallFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        title.draw(in: CGRect(x: 0, y: axisTop, width: axisX - 5, height: 20), withAttributes: titleAttributes)
        
        // Position zéro
        _ = axisTop + (axisHeight * (maxValue / range))
        
        // Graduations
        for i in 0...steps {
            let ratio = Double(i) / Double(steps)
            let value = minValue + range * ratio
            let y = axisTop + CGFloat(ratio) * axisHeight
            
            // Ligne de graduation
            let tickPath = UIBezierPath()
            tickPath.move(to: CGPoint(x: axisX - 5, y: y))
            tickPath.addLine(to: CGPoint(x: axisX, y: y))
            theme.textColor.withAlphaComponent(0.3).setStroke()
            tickPath.lineWidth = 1
            tickPath.stroke()
            
            // Valeur de graduation
            let valueText = String(format: "%.1f", value)
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: theme.textColor.withAlphaComponent(0.7),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .right
                    return style
                }()
            ]
            
            valueText.draw(in: CGRect(x: axisX - 35, y: y - 5, width: 30, height: 10), withAttributes: valueAttributes)
            
            // Ligne horizontale
            let gridPath = UIBezierPath()
            gridPath.move(to: CGPoint(x: axisX, y: y))
            gridPath.addLine(to: CGPoint(x: rect.maxX, y: y))
            theme.textColor.withAlphaComponent(0.1).setStroke()
            gridPath.lineWidth = 0.5
            gridPath.stroke()
        }
    }
    
    func drawBarWithGradient(rect: CGRect, startColor: UIColor, endColor: UIColor) {
        let context = UIGraphicsGetCurrentContext()!
        let colors = [startColor.cgColor, endColor.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 1.0]
        
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: colorLocations
        )!
        
        let startPoint = CGPoint(x: rect.midX, y: rect.minY)
        let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
        
        context.saveGState()
        context.addRect(rect)
        context.clip()
        
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
        
        context.restoreGState()
    }
    
    func drawLegendItem(text: String, x: CGFloat, y: CGFloat, color: UIColor, theme: PDFTheme) {
        // Carré de couleur
        let squareSize: CGFloat = 10
        let squareRect = CGRect(x: x, y: y + 2, width: squareSize, height: squareSize)
        color.setFill()
        UIBezierPath(rect: squareRect).fill()
        
        // Texte de légende
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.smallFont,
            .foregroundColor: theme.textColor
        ]
        
        text.draw(at: CGPoint(x: x + squareSize + 5, y: y), withAttributes: attributes)
    }
    
    func drawNoDataMessage(rect: CGRect, theme: PDFTheme) {
        let messageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: theme.textColor.withAlphaComponent(0.5),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let message = "Aucune donnée disponible pour cette période"
        message.draw(in: CGRect(x: rect.minX, y: rect.midY - 10, width: rect.width, height: 20), withAttributes: messageAttributes)
    }
}
