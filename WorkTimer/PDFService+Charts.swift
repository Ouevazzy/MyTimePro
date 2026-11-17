//
//  PDFService+Charts.swift
//  WorkTimer
//
//  Graphiques dessinés dans les rapports PDF.
//

import UIKit

extension PDFService {
    // MARK: - Drawing Charts
    
    func drawMonthlyHoursChart(workDays: [WorkDay], rect: CGRect, theme: PDFTheme) {
        drawSectionTitle("Heures travaillées par mois", rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 20), theme: theme)
        
        let months = getMonthlyHoursData(workDays: workDays)
        let chartRect = CGRect(x: rect.minX, y: rect.minY + 30, width: rect.width, height: rect.height - 30)
        
        if months.isEmpty {
            drawNoDataMessage(rect: chartRect, theme: theme)
            return
        }
        
        // Trouver le maximum pour l'échelle
        let maxHours = months.map { $0.hours }.max() ?? 0
        let roundedMax = ceil(maxHours / 10) * 10
        
        // Configuration des barres
        let barWidth: CGFloat = min(40, (chartRect.width - 60) / CGFloat(months.count))
        let barSpacing: CGFloat = min(20, barWidth * 0.5)
        let chartWidth = CGFloat(months.count) * (barWidth + barSpacing) - barSpacing
        let chartStartX = chartRect.minX + (chartRect.width - chartWidth) / 2
        
        // Dessiner l'axe Y
        drawYAxis(rect: chartRect, maxValue: roundedMax, steps: 5, title: "Heures", theme: theme)
        
        // Dessiner chaque barre
        for (index, month) in months.enumerated() {
            let barHeight = (month.hours / roundedMax) * (chartRect.height - 40)
            let barX = chartStartX + CGFloat(index) * (barWidth + barSpacing)
            let barY = chartRect.maxY - 20 - barHeight
            
            let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
            
            // Dessiner la barre avec un dégradé
            drawBarWithGradient(rect: barRect, startColor: theme.primaryColor, endColor: theme.primaryColor.withAlphaComponent(0.7))
            
            // Étiquette du mois
            let monthLabel = month.shortName
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: theme.smallFont,
                .foregroundColor: theme.textColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            monthLabel.draw(in: CGRect(x: barX, y: chartRect.maxY - 15, width: barWidth, height: 15), withAttributes: labelAttributes)
            
            // Valeur au-dessus de la barre
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: theme.primaryColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let valueText = String(format: "%.1f", month.hours)
            valueText.draw(in: CGRect(x: barX, y: barY - 15, width: barWidth, height: 12), withAttributes: valueAttributes)
        }
    }
    
    func drawWorkTypeDistributionChart(workDays: [WorkDay], rect: CGRect, theme: PDFTheme) {
        drawSectionTitle("Répartition par type d'activité", rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 20), theme: theme)
        
        let distribution = getWorkTypeDistribution(workDays: workDays)
        let chartRect = CGRect(x: rect.minX, y: rect.minY + 30, width: rect.width, height: rect.height - 30)
        
        if distribution.isEmpty {
            drawNoDataMessage(rect: chartRect, theme: theme)
            return
        }
        
        // Dessiner un graphique en secteurs
        let centerX = chartRect.minX + chartRect.width * 0.3
        let centerY = chartRect.minY + (chartRect.height - 30) / 2
        let radius: CGFloat = min(chartRect.width * 0.25, (chartRect.height - 30) / 2)
        
        var startAngle: CGFloat = 0
        var legendY = chartRect.minY
        
        for (index, item) in distribution.enumerated() {
            // Calculer l'angle
            let angle = CGFloat(item.percentage) * 2 * .pi
            
            // Dessiner le secteur
            let path = UIBezierPath()
            path.move(to: CGPoint(x: centerX, y: centerY))
            path.addArc(withCenter: CGPoint(x: centerX, y: centerY), radius: radius, startAngle: startAngle, endAngle: startAngle + angle, clockwise: true)
            path.close()
            
            // Couleur du secteur
            let itemColor = getColorForIndex(index, distribution.count, theme: theme)
            itemColor.setFill()
            path.fill()
            
            // Légendee
            drawLegendItem(
                text: "\(item.name): \(item.count) jour\(item.count > 1 ? "s" : "") (\(Int(item.percentage * 100))%)",
                x: chartRect.minX + chartRect.width * 0.6,
                y: legendY,
                color: itemColor,
                theme: theme
            )
            legendY += 20
            
            startAngle += angle
        }
    }
    
    func drawOvertimeChart(workDays: [WorkDay], rect: CGRect, theme: PDFTheme) {
        drawSectionTitle("Évolution des heures supplémentaires", rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 20), theme: theme)
        
        let months = getMonthlyOvertimeData(workDays: workDays)
        let chartRect = CGRect(x: rect.minX, y: rect.minY + 30, width: rect.width, height: rect.height - 30)
        
        if months.isEmpty {
            drawNoDataMessage(rect: chartRect, theme: theme)
            return
        }
        
        // Trouver le min et max pour l'échelle
        let values = months.map { $0.overtime }
        let maxOvertime = max(values.max() ?? 0, 0)
        let minOvertime = min(values.min() ?? 0, 0)
        let range = max(maxOvertime - minOvertime, 5)
        
        // Configuration du graphique en courbe
        let plotWidth = chartRect.width - 60
        let plotHeight = chartRect.height - 40
        let plotStartX = chartRect.minX + 40
        let plotStartY = chartRect.minY + 10
        let zeroY = plotStartY + plotHeight * (maxOvertime / range)
        
        // Dessiner l'axe Y
        drawYAxisWithRange(rect: chartRect, minValue: minOvertime, maxValue: maxOvertime, steps: 5, title: "Heures supp.", theme: theme)
        
        // Ligne zéro
        let zeroPath = UIBezierPath()
        zeroPath.move(to: CGPoint(x: plotStartX, y: zeroY))
        zeroPath.addLine(to: CGPoint(x: plotStartX + plotWidth, y: zeroY))
        theme.textColor.withAlphaComponent(0.3).setStroke()
        zeroPath.lineWidth = 0.5
        zeroPath.stroke()
        
        // Dessiner la courbe
        let path = UIBezierPath()
        let pointSpacing = plotWidth / CGFloat(months.count - 1)
        
        for (index, month) in months.enumerated() {
            let x = plotStartX + CGFloat(index) * pointSpacing
            let normalizedValue = month.overtime / range
            let y = zeroY - normalizedValue * plotHeight
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Point sur la courbe
            let pointColor = month.overtime >= 0 ? theme.accentColor : theme.negativeColor
            pointColor.setFill()
            let pointRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
            UIBezierPath(ovalIn: pointRect).fill()
            
            // Étiquette du mois
            let monthLabel = month.shortName
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: theme.smallFont,
                .foregroundColor: theme.textColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            monthLabel.draw(in: CGRect(x: x - 15, y: chartRect.maxY - 15, width: 30, height: 15), withAttributes: labelAttributes)
            
            // Valeur au-dessus/dessous du point
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: pointColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let valueText = String(format: "%.1f", month.overtime)
            let valueY = month.overtime >= 0 ? y - 15 : y + 5
            valueText.draw(in: CGRect(x: x - 15, y: valueY, width: 30, height: 12), withAttributes: valueAttributes)
        }
        
        // Tracer la courbe
        theme.primaryColor.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
