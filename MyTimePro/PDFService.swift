import Foundation
import PDFKit
import UIKit

class PDFService {
    static let shared = PDFService()
    
    private init() {}
    
    struct PDFStats {
        let workDays: Int
        let vacationDays: Double
        let sickDays: Int
        let totalHours: String
        let overtimeHours: String
        let totalBonus: Double
    }
    
    func generateReport(for date: Date, workDays: [WorkDay], annual: Bool = false) -> Data? {
        let calendar = Calendar.current
        let title = annual ?
            "Rapport Annuel \(calendar.component(.year, from: date))" :
            "Rapport Mensuel \(formatMonth(date))"
        
        let pdfMetaData = [
            kCGPDFContextCreator: "WorkTime",
            kCGPDFContextAuthor: "WorkTime App",
            kCGPDFContextTitle: title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.27 * 72.0
        let pageHeight = 11.69 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            // Première page avec le résumé
            context.beginPage()
            drawHeader(pageRect: pageRect, title: title)
            
            var yPosition: CGFloat = 120.0
            let stats = calculateStats(workDays)
            drawSummary(pageRect: pageRect, stats: stats, yPosition: &yPosition)
            
            if annual {
                // Une page par mois qui a des entrées
                for month in 1...12 {
                    let monthWorkDays = workDays.filter { workDay in
                        let components = calendar.dateComponents([.year, .month], from: workDay.date)
                        return components.month == month
                    }.sorted(by: { $0.date < $1.date })
                    
                    if !monthWorkDays.isEmpty {
                        context.beginPage()
                        drawHeader(pageRect: pageRect, title: monthName(month: month))
                        var monthYPosition: CGFloat = 120.0
                        drawMonthDetails(pageRect: pageRect, workDays: monthWorkDays, yPosition: &monthYPosition, context: context)
                    }
                }
            } else {
                // Détails du mois sélectionné
                drawMonthDetails(pageRect: pageRect, workDays: workDays.sorted(by: { $0.date < $1.date }), yPosition: &yPosition, context: context)
            }
        }
    }
    
    private func drawHeader(pageRect: CGRect, title: String) {
        let titleFont = UIFont.boldSystemFont(ofSize: 24.0)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (pageRect.width - titleSize.width) / 2.0,
            y: 50,
            width: titleSize.width,
            height: titleSize.height
        )
        
        title.draw(in: titleRect, withAttributes: titleAttributes)
    }
    
    private func drawSummary(pageRect: CGRect, stats: PDFStats, yPosition: inout CGFloat) {
        let leftMargin: CGFloat = 50.0
        let rightMargin: CGFloat = pageRect.width - 50.0
        
        drawStatsBlock(
            title: "Statistiques Générales",
            stats: [
                "Jours travaillés": "\(stats.workDays) jours",
                "Jours de congés": String(format: "%.1f jours", stats.vacationDays),
                "Jours de maladie": "\(stats.sickDays) jours"
            ],
            startY: &yPosition,
            leftMargin: leftMargin,
            rightMargin: rightMargin
        )
        
        drawStatsBlock(
            title: "Heures de Travail",
            stats: [
                "Total des heures": stats.totalHours,
                "Heures supplémentaires": stats.overtimeHours,
                "Total bonus": String(format: "%.2f CHF", stats.totalBonus)
            ],
            startY: &yPosition,
            leftMargin: leftMargin,
            rightMargin: rightMargin
        )
    }
    private func drawMonthDetails(pageRect: CGRect, workDays: [WorkDay], yPosition: inout CGFloat, context: UIGraphicsPDFRendererContext) {
            let leftMargin: CGFloat = 30.0
            let rightMargin: CGFloat = pageRect.width - 30.0
            
            let headers = ["Date", "Type", "Début", "Fin", "Pause", "Total", "Supp.", "Bonus", "Note"]
            let headerFont = UIFont.boldSystemFont(ofSize: 10.0)
            let contentFont = UIFont.systemFont(ofSize: 10.0)
            let lineHeight: CGFloat = 20.0
            let columnWidth = (rightMargin - leftMargin) / CGFloat(headers.count)
            
            // En-têtes
            var x = leftMargin
            for header in headers {
                let headerRect = CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight)
                header.draw(in: headerRect, withAttributes: [.font: headerFont])
                x += columnWidth
            }
            yPosition += lineHeight * 1.5
            
            // Pour les totaux
            var totalHours: Double = 0
            var totalOvertime: Int = 0
            var totalBonus: Double = 0
            
            // Contenu
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            for entry in workDays {
                // Nouvelle page si nécessaire
                if yPosition > pageRect.height - lineHeight * 3 {
                    drawTotalRow(
                        leftMargin: leftMargin,
                        columnWidth: columnWidth,
                        yPosition: pageRect.height - lineHeight * 2,
                        totalHours: totalHours,
                        totalOvertime: totalOvertime,
                        totalBonus: totalBonus,
                        font: headerFont
                    )
                    
                    context.beginPage()
                    yPosition = 50
                    
                    // Redessiner les en-têtes sur la nouvelle page
                    x = leftMargin
                    for header in headers {
                        let headerRect = CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight)
                        header.draw(in: headerRect, withAttributes: [.font: headerFont])
                        x += columnWidth
                    }
                    yPosition += lineHeight * 1.5
                }
                
                x = leftMargin
                
                // Date
                dateFormatter.string(from: entry.date)
                    .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                          withAttributes: [.font: contentFont])
                x += columnWidth
                
                // Type
                entry.type.rawValue
                    .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                          withAttributes: [.font: contentFont])
                x += columnWidth
                
                // Heure de début
                if let startTime = entry.startTime {
                    timeFormatter.string(from: startTime)
                        .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                              withAttributes: [.font: contentFont])
                }
                x += columnWidth
                
                // Heure de fin
                if let endTime = entry.endTime {
                    timeFormatter.string(from: endTime)
                        .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                              withAttributes: [.font: contentFont])
                }
                x += columnWidth
                
                // Temps de pause
                WorkTimeCalculations.formattedTimeInterval(entry.breakDuration)
                    .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                          withAttributes: [.font: contentFont])
                x += columnWidth
                
                // Mise à jour des totaux
                if entry.type == .work {
                    totalHours += entry.totalHours
                    totalBonus += entry.bonusAmount
                }
                // Calculer les heures supplémentaires pour tous les types de journées
                totalOvertime += entry.overtimeSeconds
                
                // Total heures
                entry.formattedTotalHours
                    .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                          withAttributes: [.font: contentFont])
                x += columnWidth
                
                // Heures supplémentaires
                let overtimeColor = entry.overtimeSeconds >= 0 ? UIColor.systemGreen : UIColor.systemRed
                entry.formattedOvertimeHours
                    .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                          withAttributes: [.font: contentFont, .foregroundColor: overtimeColor])
                x += columnWidth
                
                // Bonus
                if entry.bonusAmount > 0 {
                    String(format: "%.2f", entry.bonusAmount)
                        .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                              withAttributes: [.font: contentFont])
                }
                x += columnWidth
                
                // Note
                entry.note?
                    .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: lineHeight),
                          withAttributes: [.font: contentFont])
                
                yPosition += lineHeight
            }
            
            // Dessiner la ligne de total à la fin
            yPosition += lineHeight
            drawTotalRow(
                leftMargin: leftMargin,
                columnWidth: columnWidth,
                yPosition: yPosition,
                totalHours: totalHours,
                totalOvertime: totalOvertime,
                totalBonus: totalBonus,
                font: headerFont
            )
        }
        
        private func drawTotalRow(leftMargin: CGFloat, columnWidth: CGFloat, yPosition: CGFloat, totalHours: Double, totalOvertime: Int, totalBonus: Double, font: UIFont) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]
            
            var x = leftMargin + columnWidth * 5 // Position pour la colonne "Total"
            
            // Total des heures
            WorkTimeCalculations.formattedTimeInterval(totalHours * 3600)
                .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: 20),
                      withAttributes: attributes)
            x += columnWidth
            
            // Total des heures supplémentaires
            WorkTimeCalculations.formattedTimeInterval(Double(totalOvertime))
                .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: 20),
                      withAttributes: attributes)
            x += columnWidth
            
            // Total des bonus
            String(format: "%.2f", totalBonus)
                .draw(in: CGRect(x: x, y: yPosition, width: columnWidth, height: 20),
                      withAttributes: attributes)
        }
        
        private func drawStatsBlock(title: String, stats: [String: String], startY: inout CGFloat, leftMargin: CGFloat, rightMargin: CGFloat) {
            let titleFont = UIFont.boldSystemFont(ofSize: 16.0)
            let contentFont = UIFont.systemFont(ofSize: 14.0)
            let lineHeight: CGFloat = 25.0
            
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
            title.draw(at: CGPoint(x: leftMargin, y: startY), withAttributes: titleAttributes)
            startY += lineHeight
            
            let contentAttributes: [NSAttributedString.Key: Any] = [.font: contentFont]
            for (key, value) in stats {
                let keyRect = CGRect(x: leftMargin + 20, y: startY, width: 200, height: lineHeight)
                let valueRect = CGRect(x: rightMargin - 200, y: startY, width: 180, height: lineHeight)
                
                key.draw(in: keyRect, withAttributes: contentAttributes)
                value.draw(in: valueRect, withAttributes: contentAttributes)
                
                startY += lineHeight
            }
            
            startY += 10
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
            
            // Calcul des heures et des heures supplémentaires
            for day in workDays {
                if day.type == .work {
                    totalHours += day.totalHours
                }
                // Inclure les heures supplémentaires pour tous les types de journées
                totalOvertime += day.overtimeSeconds
            }
            
            return PDFStats(
                workDays: workDaysCount,
                vacationDays: vacationDays,
                sickDays: sickDays,
                totalHours: WorkTimeCalculations.formattedTimeInterval(totalHours * 3600),
                overtimeHours: WorkTimeCalculations.formattedTimeInterval(Double(totalOvertime)),
                totalBonus: totalBonus
            )
        }
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
    }

    // Extension pour aider au formatage des dates et des nombres
    extension DateFormatter {
        static let mediumDate: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "fr_FR")
            return formatter
        }()
        
        static let timeOnly: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter
        }()
    }
