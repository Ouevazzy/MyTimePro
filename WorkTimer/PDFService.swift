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
        var useDecimalHours: Bool = UserSettings.shared.useDecimalHours // Format des heures pour l'export
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
        // Statistiques complètes de vacances avec report
        let vacationStats: (used: Double, remaining: Double, carryIn: Double, annual: Double)
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
            "pdf.title.annual".localized(String(calendar.component(.year, from: date))) :
            "pdf.title.monthly".localized(formatMonth(date))
        
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
            let stats = calculateStats(workDays, for: date, useDecimalHours: reportTheme.useDecimalHours)
            drawCoverPage(context, pageRect: pageRect, title: title, date: date, stats: stats, totalPages: annual ? 13 : 2, theme: reportTheme)
            
            if annual {
                let targetYear = calendar.component(.year, from: date)
                
                // Filtrer les workDays pour l'année cible (pour les graphiques et statistiques)
                let yearWorkDays = workDays.filter { workDay in
                    calendar.component(.year, from: workDay.date) == targetYear
                }
                
                // Ajout d'une page de synthèse annuelle avec graphiques
                if reportTheme.includeSummaryCharts {
                    context.beginPage()
                    drawAnnualSummaryPage(pageRect: pageRect, workDays: yearWorkDays, year: targetYear, theme: reportTheme)
                }
                
                // Générer une page par mois
                for month in 1...12 {
                    let monthWorkDays = workDays.filter { workDay in
                        let components = calendar.dateComponents([.year, .month], from: workDay.date)
                        return components.year == targetYear && components.month == month
                    }.sorted(by: { $0.date < $1.date })
                    
                    if !monthWorkDays.isEmpty {
                        context.beginPage()
                        let monthTitle = "\(monthName(month: month)) \(calendar.component(.year, from: date))"
                        drawMonthPage(context, pageRect: pageRect, title: monthTitle, workDays: monthWorkDays, pageNumber: month + 1, totalPages: 13, theme: reportTheme, date: date)
                    }
                }
            } else {
                // Rapport mensuel: filtrer les workDays pour le mois et l'année sélectionnés
                let targetYear = calendar.component(.year, from: date)
                let targetMonth = calendar.component(.month, from: date)
                let monthWorkDays = workDays.filter { workDay in
                    let components = calendar.dateComponents([.year, .month], from: workDay.date)
                    return components.year == targetYear && components.month == targetMonth
                }.sorted(by: { $0.date < $1.date })
                
                context.beginPage()
                drawMonthPage(context, pageRect: pageRect, title: title, workDays: monthWorkDays, pageNumber: 2, totalPages: 2, theme: reportTheme, date: date)
            }
        }
    }
    
    // MARK: - Drawing Methods
    
    func drawCoverPage(_ context: UIGraphicsPDFRendererContext, pageRect: CGRect, title: String, date: Date, stats: PDFStats, totalPages: Int, theme: PDFTheme) {
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
        dateFormatter.locale = reportLocale
        dateFormatter.dateStyle = .long
        drawCenteredText("pdf.generatedOn".localized(dateFormatter.string(from: Date())), rect: CGRect(x: 0, y: yPosition, width: pageRect.width, height: 20), font: theme.subtitleFont, color: theme.textColor.withAlphaComponent(0.7))
        yPosition += 60
        
        // Statistiques clés dans des boîtes
        let boxSize = CGSize(width: (contentRect.width - 40) / 3, height: 100)
        let boxSpacing: CGFloat = 20
        
        // Jours travaillés
        drawStatsBox(
            rect: CGRect(x: contentRect.minX, y: yPosition, width: boxSize.width, height: boxSize.height),
            title: "pdf.workedDays".localized,
            value: "\(stats.workDays)",
            icon: "📊",
            color: theme.primaryColor
        )
        
        // Heures totales
        drawStatsBox(
            rect: CGRect(x: contentRect.minX + boxSize.width + boxSpacing, y: yPosition, width: boxSize.width, height: boxSize.height),
            title: "pdf.totalHours".localized,
            value: stats.formattedTotalHours,
            icon: "⏱",
            color: theme.primaryColor
        )
        
        // Bonus
        drawStatsBox(
            rect: CGRect(x: contentRect.minX + (boxSize.width + boxSpacing) * 2, y: yPosition, width: boxSize.width, height: boxSize.height),
            title: "pdf.bonus".localized,
            value: UserSettings.shared.formatCurrency(stats.totalBonus),
            icon: "💰",
            color: theme.secondaryColor
        )
        
        yPosition += boxSize.height + 30
        
        // Section des statistiques détaillées
        drawSectionTitle("pdf.summary".localized, rect: CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 30), theme: theme)
        yPosition += 40
        
        let columnWidth = contentRect.width / 2
        let lineHeight: CGFloat = 25
        
        // Colonne 1
        var itemY = yPosition
        drawStatItem("pdf.summary.workedDays".localized, value: daysText(stats.workDays), x: contentRect.minX + 20, y: itemY, theme: theme)
        itemY += lineHeight
        
        // Statistiques détaillées de vacances avec report
        drawStatItem("pdf.summary.vacationUsed".localized, value: "pdf.days.decimal".localized(stats.vacationStats.used), x: contentRect.minX + 20, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("pdf.summary.vacationAnnual".localized, value: "pdf.days.decimal".localized(stats.vacationStats.annual), x: contentRect.minX + 20, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("pdf.summary.carryIn".localized, value: "pdf.days.decimal".localized(stats.vacationStats.carryIn), x: contentRect.minX + 20, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("pdf.summary.vacationRemaining".localized, value: "pdf.days.decimal".localized(stats.vacationStats.remaining), x: contentRect.minX + 20, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("pdf.summary.sickDays".localized, value: daysText(stats.sickDays), x: contentRect.minX + 20, y: itemY, theme: theme)
        
        // Colonne 2
        itemY = yPosition
        drawStatItem("pdf.summary.averageDaily".localized, value: String(format: "%.2f h", stats.averageDailyHours), x: contentRect.minX + columnWidth, y: itemY, theme: theme)
        itemY += lineHeight
        
        drawStatItem("pdf.summary.overtime".localized, value: stats.formattedOvertimeHours, x: contentRect.minX + columnWidth, y: itemY,
            color: stats.overtimeSeconds >= 0 ? theme.accentColor : theme.negativeColor, theme: theme)
        itemY += lineHeight
        
        drawStatItem("pdf.summary.totalBonus".localized, value: UserSettings.shared.formatCurrency(stats.totalBonus), x: contentRect.minX + columnWidth, y: itemY, theme: theme)
        
        // Pied de page
        drawFooter(pageRect: pageRect, pageNumber: 1, totalPages: totalPages, theme: theme)
    }
    
    func drawAnnualSummaryPage(pageRect: CGRect, workDays: [WorkDay], year: Int, theme: PDFTheme) {
        let margins = UIEdgeInsets(top: 50, left: 50, bottom: 60, right: 50)
        let contentRect = pageRect.inset(by: margins)
        
        // Titre de la page
        drawSectionTitle("pdf.chartsSummary".localized(year), rect: CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width, height: 30), theme: theme)
        
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
    
    func drawMonthPage(_ context: UIGraphicsPDFRendererContext, pageRect: CGRect, title: String, workDays: [WorkDay], pageNumber: Int, totalPages: Int, theme: PDFTheme, date: Date = Date()) {
        let margins = UIEdgeInsets(top: 50, left: 40, bottom: 60, right: 40)
        let contentRect = pageRect.inset(by: margins)
        
        // En-tête avec titre
        drawPageHeader(title: title, pageRect: pageRect, theme: theme)
        
        var yPosition = margins.top + 50
        
        // Statistiques du mois
        let monthStats = calculateStats(workDays, for: date, useDecimalHours: theme.useDecimalHours)
        drawMonthSummary(monthStats, rect: CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 60), theme: theme)
        
        yPosition += 80
        
        // Tableau des jours
        drawDetailedTable(workDays: workDays, startY: yPosition, contentRect: contentRect, context: context, theme: theme, useDecimalHours: theme.useDecimalHours)
        
        // Pied de page
        drawFooter(pageRect: pageRect, pageNumber: pageNumber, totalPages: totalPages, theme: theme)
    }
    
    func drawPageHeader(title: String, pageRect: CGRect, theme: PDFTheme) {
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
    
    func drawMonthSummary(_ stats: PDFStats, rect: CGRect, theme: PDFTheme) {
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
            title: "pdf.workedDays".localized,
            value: "\(stats.workDays)",
            theme: theme
        )
        
        // Heures totales
        drawSummaryItem(
            rect: CGRect(x: rect.minX + columnWidth + padding * 2, y: rect.minY + padding, width: columnWidth, height: rect.height - padding * 2),
            icon: "clock.fill",
            title: "pdf.totalHours".localized,
            value: stats.formattedTotalHours,
            theme: theme
        )
        
        // Heures supplémentaires
        let overtimeColor = stats.overtimeSeconds >= 0 ? theme.accentColor : theme.negativeColor
        drawSummaryItem(
            rect: CGRect(x: rect.minX + columnWidth * 2 + padding * 3, y: rect.minY + padding, width: columnWidth, height: rect.height - padding * 2),
            icon: stats.overtimeSeconds >= 0 ? "plus.circle.fill" : "minus.circle.fill",
            title: "pdf.overtimeShort".localized,
            value: stats.formattedOvertimeHours,
            valueColor: overtimeColor,
            theme: theme
        )
    }
    
    func drawDetailedTable(workDays: [WorkDay], startY: CGFloat, contentRect: CGRect, context: UIGraphicsPDFRendererContext, theme: PDFTheme, useDecimalHours: Bool = UserSettings.shared.useDecimalHours) {
        let headers = ["pdf.table.date", "pdf.table.type", "pdf.table.start", "pdf.table.end", "pdf.table.break",
                       "pdf.table.total", "pdf.table.overtime", "pdf.table.bonus", "pdf.table.note"].map(\.localized)
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
                    theme: theme,
                    useDecimalHours: useDecimalHours
                )
                
                // Nouvelle page
                context.beginPage()
                drawPageHeader(title: "pdf.table.continued".localized, pageRect: context.pdfContextBounds, theme: theme)
                
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
            drawCellText(workDay.type.localizedName, rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[1], height: rowHeight), alignment: .left, font: theme.bodyFont, color: getColorForWorkDayType(workDay.type, theme: theme))
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
            
            // Pause (toujours en format standard hh:mm pour la pause)
            drawCellText(WorkTimeCalculations.formattedTimeInterval(workDay.breakDuration), rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[4], height: rowHeight), alignment: .center, font: theme.bodyFont, color: theme.textColor)
            xPosition += tableWidth * columnWidths[4]
            
            // Total (utilise le format choisi pour l'export)
            drawCellText(formatHours(workDay.totalHours, useDecimal: useDecimalHours), rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[5], height: rowHeight), alignment: .center, font: theme.bodyFont, color: theme.primaryColor)
            xPosition += tableWidth * columnWidths[5]
            
            // Heures supp. (utilise le format choisi pour l'export)
            let overtimeColor = workDay.overtimeSeconds >= 0 ? theme.accentColor : theme.negativeColor
            drawCellText(formatSeconds(workDay.overtimeSeconds, useDecimal: useDecimalHours), rect: CGRect(x: xPosition, y: yPosition, width: tableWidth * columnWidths[6], height: rowHeight), alignment: .center, font: theme.bodyFont, color: overtimeColor)
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
            theme: theme,
            useDecimalHours: useDecimalHours
        )
    }
    
    func drawTableHeader(headers: [String], columnWidths: [CGFloat], rect: CGRect, theme: PDFTheme) {
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
    
    func drawTotalRow(totalHours: Double, totalOvertime: Int, totalBonus: Double, rect: CGRect, columnWidths: [CGFloat], theme: PDFTheme, useDecimalHours: Bool = UserSettings.shared.useDecimalHours) {
        // Arrière-plan
        theme.primaryColor.withAlphaComponent(0.1).setFill()
        UIBezierPath(rect: rect).fill()
        
        let tableWidth = rect.width
        let boldFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        
        // Texte "TOTAL"
        drawCellText("pdf.table.totalRow".localized, rect: CGRect(x: rect.minX, y: rect.minY, width: tableWidth * 0.5, height: rect.height), alignment: .right, font: boldFont, color: theme.primaryColor)
        
        // Total heures
        let totalHoursX = rect.minX + tableWidth * (columnWidths[0] + columnWidths[1] + columnWidths[2] + columnWidths[3] + columnWidths[4])
        drawCellText(
            formatHours(totalHours, useDecimal: useDecimalHours),
            rect: CGRect(x: totalHoursX, y: rect.minY, width: tableWidth * columnWidths[5], height: rect.height),
            alignment: .center, font: boldFont, color: theme.primaryColor
        )
        
        // Total heures supplémentaires
        _ = totalOvertime >= 0 ? theme.accentColor : theme.negativeColor
        let overtimeX = totalHoursX + tableWidth * columnWidths[5]
        drawCellText(
            formatSeconds(totalOvertime, useDecimal: useDecimalHours),
            rect: CGRect(x: overtimeX, y: rect.minY, width: tableWidth * columnWidths[6], height: rect.height),
            alignment: .center, font: boldFont, color: theme.secondaryColor
        )
        
        // Total bonus
        let bonusX = overtimeX + tableWidth * columnWidths[6]
        drawCellText(
            String(format: "%.2f", totalBonus),
            rect: CGRect(x: bonusX, y: rect.minY, width: tableWidth * columnWidths[7], height: rect.height),
            alignment: .center, font: boldFont, color: theme.secondaryColor
        )
    }
    
    func drawFooter(pageRect: CGRect, pageNumber: Int, totalPages: Int, theme: PDFTheme) {
        guard theme.showPageNumbers else { return }
        
        let footerRect = CGRect(x: 0, y: pageRect.height - 40, width: pageRect.width, height: 30)
        
        // Date de génération
        let dateFormatter = DateFormatter()
        dateFormatter.locale = reportLocale
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let generationDate = dateFormatter.string(from: Date())
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.smallFont,
            .foregroundColor: theme.textColor.withAlphaComponent(0.6)
        ]
        
        let generatedText = "pdf.generatedOn".localized(generationDate)
        generatedText.draw(at: CGPoint(x: 50, y: footerRect.minY + 10), withAttributes: attributes)
        
        // Numéro de page
        let pageText = "pdf.pageOf".localized(pageNumber, totalPages)
        let pageTextSize = pageText.size(withAttributes: attributes)
        pageText.draw(at: CGPoint(x: pageRect.width - 50 - pageTextSize.width, y: footerRect.minY + 10), withAttributes: attributes)
    }
}
