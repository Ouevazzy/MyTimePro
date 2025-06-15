import Foundation
import PDFKit
import UIKit
import Charts

class PDFService {
    static let shared = PDFService()
    
    // Structure pour gérer les options visuelles du PDF
    struct PDFTheme {
        var primaryColor: UIColor = UIColor(red: 0.0, green: 0.48, blue: 0.8, alpha: 1.0) // Bleu
        var secondaryColor: UIColor = UIColor(red: 0.95, green: 0.67, blue: 0.0, alpha: 1.0) // Orange
        var backgroundColor: UIColor = UIColor.white
        var textColor: UIColor = UIColor.black
        var accentColor: UIColor = UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0) // Vert
        var negativeColor: UIColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0) // Rouge
        var headerFont: UIFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        var subtitleFont: UIFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        var bodyFont: UIFont = UIFont.systemFont(ofSize: 11)
        var smallFont: UIFont = UIFont.systemFont(ofSize: 9)
        var logo: UIImage? = nil
        var companyName: String = "WorkTimer"
        var showPageNumbers: Bool = true
        var includeSummaryCharts: Bool = true
    }
    
    // Structure contenant les statistiques pour les rapports
    struct PDFStats {
        let workDays: Int
        let vacationDays: Double
        let sickDays: Int
        let totalHours: Double
        let formattedTotalHours: String
        let overtimeSeconds: Int
        let formattedOvertimeHours: String
        let totalBonus: Double
        let averageDailyHours: Double
    }
    
    private var theme: PDFTheme = PDFTheme()
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(theme: PDFTheme) {
        self.theme = theme
    }
    
    // MARK: - Public Methods
    
    func generateReport(for date: Date, workDays: [WorkDay], annual: Bool = false, theme: PDFTheme? = nil) -> Data? {
        // Utilise le thème fourni ou celui par défaut
        let reportTheme = theme ?? self.theme
        let calendar = Calendar.current
        
        let title = annual ?
            "Rapport Annuel \(calendar.component(.year, from: date))" :
            "Rapport Mensuel \(formatMonth(date))"
        
        let pdfMetaData = [
            kCGPDFContextCreator: reportTheme.companyName,
            kCGPDFContextAuthor: reportTheme.companyName,
            kCGPDFContextTitle: title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // Format A4
        let pageWidth = 8.27 * 72.0
        let pageHeight = 11.69 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            // Page de titre et résumé
            context.beginPage()
            let stats = calculateStats(workDays)
            drawCoverPage(context, pageRect: pageRect, title: title, date: date, stats: stats, theme: reportTheme)
            
            if annual {
                // Ajout d'une page de synthèse annuelle avec graphiques
                if reportTheme.includeSummaryCharts {
                    context.beginPage()
                    drawAnnualSummaryPage(pageRect: pageRect, workDays: workDays, year: calendar.component(.year, from: date), theme: reportTheme)
                }
                
                // Générer une page par mois
                for month in 1...12 {
                    let monthWorkDays = workDays.filter { workDay in
                        let components = calendar.dateComponents([.year, .month], from: workDay.date)
                        return components.month == month
                    }.sorted(by: { $0.date < $1.date })
                    
                    if !monthWorkDays.isEmpty {
                        context.beginPage()
                        let monthTitle = "\(monthName(month: month)) \(calendar.component(.year, from: date))"
                        drawMonthPage(context, pageRect: pageRect, title: monthTitle, workDays: monthWorkDays, pageNumber: month + 1, totalPages: 13, theme: reportTheme)
                    }
                }
            } else {
                // Rapport mensuel: une seule page avec les détails
                context.beginPage()
                drawMonthPage(context, pageRect: pageRect, title: title, workDays: workDays.sorted(by: { $0.date < $1.date }), pageNumber: 2, totalPages: 2, theme: reportTheme)
            }
        }
    }
    
    // MARK: - Drawing Methods
    
    private func drawCoverPage(_ context: UIGraphicsPDFRendererContext, pageRect: CGRect, title: String, date: Date, stats: PDFStats, theme: PDFTheme) {
        let margins = UIEdgeInsets(top: 50, left: 50, bottom: 60, right: 50)
        let contentRect = pageRect.inset(by: margins)
        
        // Arrière-plan
        context.cgContext.saveGState()
        drawGradientBackground(pageRect: pageRect, theme: theme)
        context.cgContext.restoreGState()
        
        // Logo de l'entreprise
        var yPosition: CGFloat = margins.top + 40
        
        if let logo = theme.logo {
            let logoSize: CGFloat = 60
            let logoRect = CGRect(x: (pageRect.width - logoSize) / 2, y: yPosition, width: logoSize, height: logoSize)
            logo.draw(in: logoRect)
            yPosition += logoSize + 30
        } else {
            // Afficher le nom de l'entreprise si pas de logo
            drawCenteredText(theme.companyName, rect: CGRect(x: 0, y: yPosition, width: pageRect.width, height: 30), font: theme.headerFont, color: theme.primaryColor)
            yPosition += 50
        }
        
        // Titre du rapport
        drawCenteredText(title, rect: CGRect(x: 0, y: yPosition, width: pageRect.width, height: 40), font: theme.headerFont, color: theme.textColor)
        yPosition += 50
        
        // Date du rapport
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        drawCenteredText("Généré le \(dateFormatter.string(from: Date()))", rect: CGRect(x: 0, y: yPosition, width: pageRect.width, height: 20), font: theme.subtitleFont, color: theme.textColor.withAlphaComponent(0.7))
        yPosition += 60
        
        // Statistiques clés dans des boîtes
        let boxSize = CGSize(width: (contentRect.width - 40) / 3, height: 100)
        let boxSpacing: CGFloat = 20
        
        // Jours travaillés
        drawStatsBox(
            rect: CGRect(x: contentRect.minX, y: yPosition, width: boxSize.width, height: boxSize.height),
            title: "Jours travaillés",
            value: "\(stats.workDays)",
            icon: "📊",
            color: theme.primaryColor
        )
        
        // Heures totales
        drawStatsBox(
            rect: CGRect(x: contentRect.minX + boxSize.width + boxSpacing, y: yPosition, width: boxSize.width, height: boxSize.height),
            title: "Heures totales",
            value: stats.formattedTotalHours,
            icon: "⏱",
            color: theme.primaryColor
        )
        
        // Bonus
        drawStatsBox(
            rect: CGRect(x: contentRect.minX + (boxSize.width + boxSpacing) * 2, y: yPosition, width: boxSize.width, height: boxSize.height),
            title: "Bonus",
            value: String(format: "%.2f CHF", stats.totalBonus),
            icon: "💰",
            color: theme.secondaryColor
        )
        
        yPosition += boxSize.height + 30
        
        // Section des statistiques détaillées
        drawSectionTitle("Résumé", rect: CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 30), theme: theme)
        yPosition += 40
        
        let columnWidth = contentRect.width / 2
        let lineHeight: CGFloat = 25
        
        // Colonne 1
        var itemY = yPosition
        drawStatItem("Jours travaillés:", value: "\(stats.workDays) jours", x: contentRect.minX + 20, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("Jours de congés:", value: String(format: "%.1f jours", stats.vacationDays), x: contentRect.minX + 20, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("Jours de maladie:", value: "\(stats.sickDays) jours", x: contentRect.minX + 20, y: itemY, theme: theme)
        
        // Colonne 2
        itemY = yPosition
        drawStatItem("Heures moyennes/jour:", value: String(format: "%.2f h", stats.averageDailyHours), x: contentRect.minX + columnWidth, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("Heures supplémentaires:", value: stats.formattedOvertimeHours, x: contentRect.minX + columnWidth, y: itemY,
            color: stats.overtimeSeconds >= 0 ? theme.accentColor : theme.negativeColor, theme: theme)
        itemY += lineHeight
        
        drawStatItem("Total bonus:", value: String(format: "%.2f CHF", stats.totalBonus), x: contentRect.minX + columnWidth, y: itemY, theme: theme)
        
        // Pied de page
        drawFooter(pageRect: pageRect, pageNumber: 1, totalPages: title.contains("Annuel") ? 13 : 2, theme: theme)
    }
    
    private func drawAnnualSummaryPage(pageRect: CGRect, workDays: [WorkDay], year: Int, theme: PDFTheme) {
        let margins = UIEdgeInsets(top: 50, left: 50, bottom: 60, right: 50)
        let contentRect = pageRect.inset(by: margins)
        
        // Titre de la page
        drawSectionTitle("Synthèse Graphique - \(year)", rect: CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width, height: 30), theme: theme)
        
        var yPosition = contentRect.minY + 40
        
        // Graphique de répartition des heures par mois
        drawMonthlyHoursChart(workDays: workDays, rect: CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 200), theme: theme)
        
        yPosition += 220
        
        // Graphique de répartition par type d'activité
        drawWorkTypeDistributionChart(workDays: workDays, rect: CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 180), theme: theme)
        
        yPosition += 200
        
        // Tendance des heures supplémentaires par mois
        drawOvertimeChart(workDays: workDays, rect: CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 180), theme: theme)
        
        // Pied de page
        drawFooter(pageRect: pageRect, pageNumber: 2, totalPages: 13, theme: theme)
    }
    
    private func drawMonthPage(_ context: UIGraphicsPDFRendererContext, pageRect: CGRect, title: String, workDays: [WorkDay], pageNumber: Int, totalPages: Int, theme: PDFTheme) {
        let margins = UIEdgeInsets(top: 50, left: 40, bottom: 60, right: 40)
        let contentRect = pageRect.inset(by: margins)
        
        // En-tête avec titre
        drawPageHeader(title: title, pageRect: pageRect, theme: theme)
        
        var yPosition = margins.top + 50
        
        // Statistiques du mois
        let monthStats = calculateStats(workDays)
        drawMonthSummary(monthStats, rect: CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 60), theme: theme)
        
        yPosition += 80
        
        // Tableau des jours
        drawDetailedTable(workDays: workDays, startY: yPosition, contentRect: contentRect, context: context, theme: theme)
        
        // Pied de page
        drawFooter(pageRect: pageRect, pageNumber: pageNumber, totalPages: totalPages, theme: theme)
    }
    
    private func drawPageHeader(title: String, pageRect: CGRect, theme: PDFTheme) {
        // Bande colorée en haut de page
        let headerHeight: CGFloat = 40
        let headerRect = CGRect(x: 0, y: 0, width: pageRect.width, height: headerHeight)
        
        theme.primaryColor.setFill()
        UIBezierPath(rect: headerRect).fill()
        
        // Titre
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.subtitleFont,
            .foregroundColor: UIColor.white
        ]
        
        let titleRect = CGRect(x: 50, y: 5, width: pageRect.width - 100, height: headerHeight - 10)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Logo ou nom de l'entreprise
        if let logo = theme.logo {
            let logoSize: CGFloat = 24
            let logoRect = CGRect(x: pageRect.width - 50 - logoSize, y: (headerHeight - logoSize) / 2, width: logoSize, height: logoSize)
            logo.draw(in: logoRect)
        } else {
            let companyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let companyRect = CGRect(x: pageRect.width - 150, y: 5, width: 100, height: headerHeight - 10)
            theme.companyName.draw(in: companyRect, withAttributes: companyAttributes)
        }
    }
    
    private func drawMonthSummary(_ stats: PDFStats, rect: CGRect, theme: PDFTheme) {
        // Arrière-plan
        let backgroundPath = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        theme.backgroundColor.withAlphaComponent(0.1).setFill()
        backgroundPath.fill()
        
        let padding: CGFloat = 15
        let columnWidth = (rect.width - padding * 3) / 3
        
        // Jours travaillés
        drawSummaryItem(
            rect: CGRect(x: rect.minX + padding, y: rect.minY + padding, width: columnWidth, height: rect.height - padding * 2),
            icon: "briefcase.fill",
            title: "Jours travaillés",
            value: "\(stats.workDays)",
            theme: theme
        )
        
        // Heures totales
        drawSummaryItem(
            rect: CGRect(x: rect.minX + columnWidth + padding * 2, y: rect.minY + padding, width: columnWidth, height: rect.height - padding * 2),
            icon: "clock.fill",
            title: "Heures totales",
            value: stats.formattedTotalHours,
            theme: theme
        )
        
        // Heures supplémentaires
        let overtimeColor = stats.overtimeSeconds >= 0 ? theme.accentColor : theme.negativeColor
        drawSummaryItem(
            rect: CGRect(x: rect.minX + columnWidth * 2 + padding * 3, y: rect.minY + padding, width: columnWidth, height: rect.height - padding * 2),
            icon: stats.overtimeSeconds >= 0 ? "plus.circle.fill" : "minus.circle.fill",
            title: "Heures supp.",
            value: stats.formattedOvertimeHours,
            valueColor: overtimeColor,
            theme: theme
        )
    }
    
    private func drawDetailedTable(workDays: [WorkDay], startY: CGFloat, contentRect: CGRect, context: UIGraphicsPDFRendererContext, theme: PDFTheme) {
        let headers = ["Date", "Type", "Début", "Fin", "Pause", "Total", "Supp.", "Bonus", "Note"]
        let columnWidths: [CGFloat] = [0.15, 0.15, 0.1, 0.1, 0.1, 0.12, 0.12, 0.08, 0.08]
        
        let tableWidth = contentRect.width
        let rowHeight: CGFloat = 28
        var yPosition = startY
        
        // En-tête du tableau
        drawTableHeader(headers: headers, columnWidths: columnWidths, rect: CGRect(x: contentRect.minX, y: yPosition, width: tableWidth, height: rowHeight), theme: theme)
        yPosition += rowHeight
        
        var rowIndex = 0
        var totalHours: Double = 0
        var totalOvertime: Int = 0
        var totalBonus: Double = 0
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        // Lignes du tableau
        for workDay in workDays {
            // Vérifier si on a besoin d'une nouvelle page
            if yPosition > contentRect.maxY - rowHeight * 3 {
                // Dessiner ligne totale sur la page courante
                drawTotalRow(
                    totalHours: totalHours,
                    totalOvertime: totalOvertime,
                    totalBonus: totalBonus,
                    rect: CGRect(x: contentRect.minX, y: yPosition, width: tableWidth, height: rowHeight),
                    columnWidths: columnWidths,
                    theme: theme
                )
                
                // Nouvelle page
                context.beginPage()
                drawPageHeader(title: "Suite du tableau", pageRect: context.pdfContextBounds, theme: theme)
                
                // Réinitialiser yPosition
                yPosition = startY
                
                // Redessiner l'en-tête
                drawTableHeader(headers: headers, columnWidths: columnWidths, rect: CGRect(x: contentRect.minX, y: yPosition, width: tableWidth, height: rowHeight), theme: theme)
                yPosition += rowHeight
            }
            
            // Couleur de fond alternée
            if rowIndex % 2 == 0 {
                let rowRect = CGRect(x: contentRect.minX, y: yPosition, width: tableWidth, height: rowHeight)
                theme.primaryColor.withAlphaComponent(0.05).setFill()
                UIBezierPath(rect: rowRect).fill()
            }
            
            // Date
            var xPosition = contentRect.minX
            let date = dateFormatter.string(from: workDay.date)
            drawCellText(date, rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[0], height: rowHeight), alignment: .left, font: theme.bodyFont, color: theme.textColor)
            xPosition += tableWidth * columnWidths[0]
            
            // Type
            drawCellText(workDay.type.rawValue, rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[1], height: rowHeight), alignment: .left, font: theme.bodyFont, color: getColorForWorkDayType(workDay.type, theme: theme))
            xPosition += tableWidth * columnWidths[1]
            
            // Début
            if let startTime = workDay.startTime {
                drawCellText(timeFormatter.string(from: startTime), rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[2], height: rowHeight), alignment: .center, font: theme.bodyFont, color: theme.textColor)
            }
            xPosition += tableWidth * columnWidths[2]
            
            // Fin
            if let endTime = workDay.endTime {
                drawCellText(timeFormatter.string(from: endTime), rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[3], height: rowHeight), alignment: .center, font: theme.bodyFont, color: theme.textColor)
            }
            xPosition += tableWidth * columnWidths[3]
            
            // Pause
            drawCellText(WorkTimeCalculations.formattedTimeInterval(workDay.breakDuration), rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[4], height: rowHeight), alignment: .center, font: theme.bodyFont, color: theme.textColor)
            xPosition += tableWidth * columnWidths[4]
            
            // Total
            drawCellText(workDay.formattedTotalHours, rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[5], height: rowHeight), alignment: .center, font: theme.bodyFont, color: theme.primaryColor)
            xPosition += tableWidth * columnWidths[5]
            
            // Heures supp.
            let overtimeColor = workDay.overtimeSeconds >= 0 ? theme.accentColor : theme.negativeColor
            drawCellText(workDay.formattedOvertimeHours, rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[6], height: rowHeight), alignment: .center, font: theme.bodyFont, color: overtimeColor)
            xPosition += tableWidth * columnWidths[6]
            
            // Bonus
            if workDay.bonusAmount > 0 {
                drawCellText(String(format: "%.2f", workDay.bonusAmount), rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[7], height: rowHeight), alignment: .center, font: theme.bodyFont, color: theme.secondaryColor)
            }
            xPosition += tableWidth * columnWidths[7]
            
            // Note
            if let note = workDay.note, !note.isEmpty {
                drawCellText(note, rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[8], height: rowHeight), alignment: .left, font: theme.smallFont, color: theme.textColor)
            }
            
            // Mettre à jour les totaux
            if workDay.type == .work {
                totalHours += workDay.totalHours
                totalBonus += workDay.bonusAmount
            }
            totalOvertime += workDay.overtimeSeconds
            
            yPosition += rowHeight
            rowIndex += 1
        }
        
        // Ligne de total à la fin du tableau
        drawTotalRow(
            totalHours: totalHours,
            totalOvertime: totalOvertime,
            totalBonus: totalBonus,
            rect: CGRect(x: contentRect.minX, y: yPosition, width: tableWidth, height: rowHeight),
            columnWidths: columnWidths,
            theme: theme
        )
    }
    
    private func drawTableHeader(headers: [String], columnWidths: [CGFloat], rect: CGRect, theme: PDFTheme) {
        // Arrière-plan de l'en-tête
        theme.primaryColor.setFill()
        UIBezierPath(rect: rect).fill()
        
        var xPosition = rect.minX
        let tableWidth = rect.width
        
        for (index, header) in headers.enumerated() {
            let columnWidth = tableWidth * columnWidths[index]
            let headerRect = CGRect(x: xPosition, y: rect.minY, width: columnWidth, height: rect.height)
            
            // Texte de l'en-tête
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            
            let textRect = headerRect.insetBy(dx: 5, dy: 0)
            let textAlignment = index < 2 ? NSTextAlignment.left : NSTextAlignment.center
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlignment
            var finalAttributes = attributes
            finalAttributes[.paragraphStyle] = paragraphStyle
            
            header.draw(in: textRect, withAttributes: finalAttributes)
            
            xPosition += columnWidth
        }
    }
    
    private func drawTotalRow(totalHours: Double, totalOvertime: Int, totalBonus: Double, rect: CGRect, columnWidths: [CGFloat], theme: PDFTheme) {
        // Arrière-plan
        theme.primaryColor.withAlphaComponent(0.1).setFill()
        UIBezierPath(rect: rect).fill()
        
        let tableWidth = rect.width
        let boldFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        
        // Texte "TOTAL"
        drawCellText("TOTAL", rect: CGRect(x: rect.minX, y: rect.minY, width: tableWidth * 0.5, height: rect.height), alignment: .right, font: boldFont, color: theme.primaryColor)
        
        // Total heures
        let totalHoursX = rect.minX + tableWidth * (columnWidths[0] + columnWidths[1] + columnWidths[2] + columnWidths[3] + columnWidths[4])
        drawCellText(
            WorkTimeCalculations.formattedTimeInterval(totalHours * 3600),
            rect: CGRect(x: totalHoursX, y: rect.minY, width: tableWidth * columnWidths[5], height: rect.height),
            alignment: .center, font: boldFont, color: theme.primaryColor
        )
        
        // Total heures supplémentaires
        let overtimeColor = totalOvertime >= 0 ? theme.accentColor : theme.negativeColor
        let overtimeX = totalHoursX + tableWidth * columnWidths[5]
        drawCellText(
            WorkTimeCalculations.formattedTimeInterval(Double(totalOvertime)),
            rect: CGRect(x: overtimeX, y: rect.minY, width: tableWidth * columnWidths[6], height: rect.height),
            alignment: .center, font: boldFont, color: overtimeColor
        )
        
        // Total bonus
        let bonusX = overtimeX + tableWidth * columnWidths[6]
        drawCellText(
            String(format: "%.2f", totalBonus),
            rect: CGRect(x: bonusX, y: rect.minY, width: tableWidth * columnWidths[7], height: rect.height),
            alignment: .center, font: boldFont, color: theme.secondaryColor
        )
    }
    
    private func drawFooter(pageRect: CGRect, pageNumber: Int, totalPages: Int, theme: PDFTheme) {
        guard theme.showPageNumbers else { return }
        
        let footerRect = CGRect(x: 0, y: pageRect.height - 40, width: pageRect.width, height: 30)
        
        // Date de génération
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        let generationDate = dateFormatter.string(from: Date())
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.smallFont,
            .foregroundColor: theme.textColor.withAlphaComponent(0.6)
        ]
        
        let generatedText = "Généré le \(generationDate)"
        generatedText.draw(at: CGPoint(x: 50, y: footerRect.minY + 10), withAttributes: attributes)
        
        // Numéro de page
        let pageText = "Page \(pageNumber) sur \(totalPages)"
        let pageTextSize = pageText.size(withAttributes: attributes)
        pageText.draw(at: CGPoint(x: pageRect.width - 50 - pageTextSize.width, y: footerRect.minY + 10), withAttributes: attributes)
    }
    
    // MARK: - Drawing Charts
    
    private func drawMonthlyHoursChart(workDays: [WorkDay], rect: CGRect, theme: PDFTheme) {
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
    
    private func drawWorkTypeDistributionChart(workDays: [WorkDay], rect: CGRect, theme: PDFTheme) {
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
    
    private func drawOvertimeChart(workDays: [WorkDay], rect: CGRect, theme: PDFTheme) {
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
    
    // MARK: - Helper Drawing Methods
    
    private func drawGradientBackground(pageRect: CGRect, theme: PDFTheme) {
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
    
    private func drawCenteredText(_ text: String, rect: CGRect, font: UIFont, color: UIColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        text.draw(in: rect, withAttributes: attributes)
    }
    
    private func drawStatsBox(rect: CGRect, title: String, value: String, icon: String, color: UIColor) {
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
    
    private func drawSectionTitle(_ title: String, rect: CGRect, theme: PDFTheme) {
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
    
    private func drawStatItem(_ label: String, value: String, x: CGFloat, y: CGFloat, color: UIColor? = nil, theme: PDFTheme) {
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
    
    private func drawCellText(_ text: String, rect: CGRect, alignment: NSTextAlignment, font: UIFont, color: UIColor) {
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
    
    private func drawSummaryItem(rect: CGRect, icon: String, title: String, value: String, valueColor: UIColor? = nil, theme: PDFTheme) {
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
    
    private func drawYAxis(rect: CGRect, maxValue: Double, steps: Int, title: String, theme: PDFTheme) {
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
    
    private func drawYAxisWithRange(rect: CGRect, minValue: Double, maxValue: Double, steps: Int, title: String, theme: PDFTheme) {
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
    
    private func drawBarWithGradient(rect: CGRect, startColor: UIColor, endColor: UIColor) {
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
    
    private func drawLegendItem(text: String, x: CGFloat, y: CGFloat, color: UIColor, theme: PDFTheme) {
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
    
    private func drawNoDataMessage(rect: CGRect, theme: PDFTheme) {
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
    
    // MARK: - Data Processing
    
    private func getColorForWorkDayType(_ type: WorkDayType, theme: PDFTheme) -> UIColor {
        switch type {
        case .work:
            return theme.primaryColor
        case .vacation, .halfDayVacation:
            return theme.secondaryColor
        case .sickLeave:
            return theme.negativeColor
        case .compensatory:
            return theme.accentColor
        default:
            return theme.textColor
        }
    }
    
    private func getColorForIndex(_ index: Int, _ count: Int, theme: PDFTheme) -> UIColor {
        let colors: [UIColor] = [
            theme.primaryColor,
            theme.secondaryColor,
            theme.accentColor,
            theme.negativeColor,
            theme.primaryColor.withAlphaComponent(0.7),
            theme.secondaryColor.withAlphaComponent(0.7),
            theme.accentColor.withAlphaComponent(0.7)
        ]
        
        return colors[index % colors.count]
    }
    
    private func calculateStats(_ workDays: [WorkDay]) -> PDFStats {
        let workDaysCount = workDays.filter { $0.type == .work }.count
        let vacationDays = workDays.reduce(0.0) { total, day in
            if day.type == .vacation {
                return total + 1
            } else if day.type == .halfDayVacation {
                return total + 0.5
            }
            return total
        }
        let sickDays = workDays.filter { $0.type == .sickLeave }.count
        
        var totalHours: Double = 0
        var totalOvertime: Int = 0
        let totalBonus = workDays.reduce(0.0) { $0 + $1.bonusAmount }
        
        for day in workDays {
            if day.type == .work {
                totalHours += day.totalHours
            }
            totalOvertime += day.overtimeSeconds
        }
        
        let averageDailyHours = workDaysCount > 0 ? totalHours / Double(workDaysCount) : 0
        
        return PDFStats(
            workDays: workDaysCount,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            formattedTotalHours: WorkTimeCalculations.formattedTimeInterval(totalHours * 3600),
            overtimeSeconds: totalOvertime,
            formattedOvertimeHours: WorkTimeCalculations.formattedTimeInterval(Double(totalOvertime)),
            totalBonus: totalBonus,
            averageDailyHours: averageDailyHours
        )
    }
    
    private func getMonthlyHoursData(workDays: [WorkDay]) -> [MonthData] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        var monthlyHours: [Int: Double] = [:]
        
        for workDay in workDays where workDay.type == .work {
            let month = calendar.component(.month, from: workDay.date)
            monthlyHours[month, default: 0] += workDay.totalHours
        }
        
        var result: [MonthData] = []
        
        for month in 1...12 {
            let date = calendar.date(from: DateComponents(year: 2023, month: month, day: 1))!
            result.append(MonthData(
                month: month,
                name: dateFormatter.string(from: date),
                shortName: dateFormatter.string(from: date),
                hours: monthlyHours[month, default: 0],
                overtime: 0
            ))
        }
        
        return result
    }
    
    private func getMonthlyOvertimeData(workDays: [WorkDay]) -> [MonthData] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        var monthlyOvertime: [Int: Double] = [:]
        
        for workDay in workDays {
            let month = calendar.component(.month, from: workDay.date)
            monthlyOvertime[month, default: 0] += Double(workDay.overtimeSeconds) / 3600.0
        }
        
        var result: [MonthData] = []
        
        for month in 1...12 {
            let date = calendar.date(from: DateComponents(year: 2023, month: month, day: 1))!
            result.append(MonthData(
                month: month,
                name: dateFormatter.string(from: date),
                shortName: dateFormatter.string(from: date),
                hours: 0,
                overtime: monthlyOvertime[month, default: 0]
            ))
        }
        
        return result
    }
    
    private func getWorkTypeDistribution(workDays: [WorkDay]) -> [TypeDistribution] {
        var typeCount: [WorkDayType: Int] = [:]
        
        for workDay in workDays {
            typeCount[workDay.type, default: 0] += 1
        }
        
        let totalDays = workDays.count
        
        var result: [TypeDistribution] = []
        
        for (type, count) in typeCount where count > 0 {
            result.append(TypeDistribution(
                type: type,
                name: type.rawValue,
                count: count,
                percentage: Double(count) / Double(totalDays)
            ))
        }
        
        return result.sorted { $0.count > $1.count }
    }
    
    // MARK: - Formatting Utils
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    private func monthName(month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.monthSymbols[month - 1].capitalized
    }
    
    // MARK: - Supporting Structs
    
    private struct MonthData {
        let month: Int
        let name: String
        let shortName: String
        let hours: Double
        let overtime: Double
    }
    
    private struct TypeDistribution {
        let type: WorkDayType
        let name: String
        let count: Int
        let percentage: Double
    }
}
