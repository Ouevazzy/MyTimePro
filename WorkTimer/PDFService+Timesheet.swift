//
//  PDFService+Timesheet.swift
//  WorkTimer
//
//  Feuille d'heures A4 : sobre, lisible en noir et blanc, avec signatures.
//

import UIKit

extension PDFService {
    private enum TimesheetBlock {
        case header, row(TimesheetRow), weekTotal(Timesheet.Week), summary

        var height: CGFloat {
            switch self {
            case .header: 18
            case .row: 13
            case .weekTotal: 15
            case .summary: 128
            }
        }
    }

    private struct TimesheetRow {
        let cells: [String]
        let isWeekend: Bool
    }

    private static let timesheetColumns: [CGFloat] = [0.19, 0.09, 0.13, 0.09, 0.11, 0.11, 0.28]

    func generateTimesheet(_ sheet: Timesheet, options: Timesheet.Options) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let content = page.inset(by: UIEdgeInsets(top: 32, left: 40, bottom: 44, right: 40))
        let titleHeight: CGFloat = 86
        let pages = paginate(
            timesheetBlocks(sheet, options: options),
            first: content.height - titleHeight,
            next: content.height - 26
        )

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle: "timesheet.title".localized,
            kCGPDFContextAuthor: options.employee
        ] as [String: Any]

        return UIGraphicsPDFRenderer(bounds: page, format: format).pdfData { context in
            for (index, blocks) in pages.enumerated() {
                context.beginPage()
                var y = content.minY
                if index == 0 {
                    drawTimesheetTitle(sheet, options: options, rect: CGRect(x: content.minX, y: y, width: content.width, height: titleHeight))
                    y += titleHeight
                } else {
                    let reminder = [options.employee, sheet.title(locale: options.locale)].filter { !$0.isEmpty }
                    text(reminder.joined(separator: " – "), CGRect(x: content.minX, y: y, width: content.width, height: 14), size: 9, color: .darkGray)
                    y += 26
                }
                for block in blocks {
                    let rect = CGRect(x: content.minX, y: y, width: content.width, height: block.height)
                    draw(block, sheet: sheet, options: options, rect: rect)
                    y += block.height
                }
                drawFooter(pageRect: page, pageNumber: index + 1, totalPages: pages.count, theme: PDFTheme())
            }
        }
    }

    // MARK: - Mise en page

    private func timesheetBlocks(_ sheet: Timesheet, options: Timesheet.Options) -> [TimesheetBlock] {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Timesheet.calendar
        dateFormatter.locale = options.locale
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEddMM")

        var blocks: [TimesheetBlock] = [.header]
        for week in sheet.weeks {
            for day in week.days {
                let label = dateFormatter.string(from: day.date)
                let weekend = Timesheet.calendar.isDateInWeekend(day.date)
                let entries: [Timesheet.Entry?] = day.entries.isEmpty ? [nil] : day.entries
                for (index, entry) in entries.enumerated() {
                    blocks.append(.row(TimesheetRow(
                        cells: cells(entry, day: day, dayLabel: index == 0 ? label : "",
                                     isLast: index == entries.count - 1, options: options),
                        isWeekend: weekend
                    )))
                }
            }
            blocks.append(.weekTotal(week))
        }
        blocks.append(.summary)
        return blocks
    }

    private func cells(
        _ entry: Timesheet.Entry?, day: Timesheet.Day, dayLabel: String, isLast: Bool, options: Timesheet.Options
    ) -> [String] {
        guard let entry else { return [dayLabel, "", "", "", "", "", ""] }
        let decimal = options.useDecimalHours
        let works = Timesheet.countsAsWork(entry.type)
        var remarks: [String] = []
        if entry.type != .work { remarks.append(entry.type.localizedName) }
        // Plusieurs plages le même jour : le total du jour suit la dernière.
        if isLast && day.entries.filter({ Timesheet.countsAsWork($0.type) }).count > 1 {
            remarks.append("timesheet.dayTotal".localized(Timesheet.duration(day.workedMinutes, decimal: decimal)))
        }
        if options.includeNotes && !entry.note.isEmpty { remarks.append(entry.note) }
        return [
            dayLabel,
            Timesheet.time(entry.start),
            Timesheet.time(entry.end) + (entry.endsNextDay ? " (+1)" : ""),
            works && entry.start != nil ? Timesheet.duration(entry.breakMinutes, decimal: decimal) : "",
            works ? Timesheet.duration(entry.workedMinutes, decimal: decimal) : "",
            isLast ? Timesheet.balance(day.balanceMinutes, decimal: decimal) : "",
            remarks.joined(separator: " · ").replacingOccurrences(of: "\n", with: " ")
        ]
    }

    private func paginate(_ blocks: [TimesheetBlock], first: CGFloat, next: CGFloat) -> [[TimesheetBlock]] {
        var pages: [[TimesheetBlock]] = [[]]
        var remaining = first
        for block in blocks {
            if block.height > remaining, !pages[pages.count - 1].isEmpty {
                // L'en-tête du tableau se répète, sauf devant le seul récapitulatif.
                if case .summary = block { pages.append([]) } else { pages.append([.header]) }
                remaining = next - pages[pages.count - 1].reduce(0) { $0 + $1.height }
            }
            pages[pages.count - 1].append(block)
            remaining -= block.height
        }
        return pages
    }

    // MARK: - Dessin

    private func drawTimesheetTitle(_ sheet: Timesheet, options: Timesheet.Options, rect: CGRect) {
        text("timesheet.title".localized, CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 28), size: 20, weight: .bold)
        text(sheet.title(locale: options.locale), CGRect(x: rect.minX, y: rect.minY + 28, width: rect.width, height: 18), size: 12, color: .darkGray)
        let lines = [("timesheet.employee", options.employee), ("timesheet.company", options.company)]
        for (index, line) in lines.enumerated() {
            let y = rect.minY + 47 + CGFloat(index) * 16
            text(line.0.localized, CGRect(x: rect.minX, y: y, width: 110, height: 14), size: 10, color: .darkGray)
            text(line.1.isEmpty ? "……………………………………" : line.1, CGRect(x: rect.minX + 110, y: y, width: rect.width - 110, height: 14), size: 10, weight: .semibold)
        }
    }

    private func draw(_ block: TimesheetBlock, sheet: Timesheet, options: Timesheet.Options, rect: CGRect) {
        let decimal = options.useDecimalHours
        switch block {
        case .header:
            fill(rect, UIColor(white: 0.2, alpha: 1))
            let titles = ["date", "start", "end", "break", "worked", "balance", "remark"].map { "timesheet.column.\($0)".localized }
            drawCells(titles, rect: rect, size: 9, weight: .semibold, color: .white)
        case .row(let row):
            if row.isWeekend { fill(rect, UIColor(white: 0.965, alpha: 1)) }
            drawCells(row.cells, rect: rect, size: 8.5)
            line(from: CGPoint(x: rect.minX, y: rect.maxY), to: CGPoint(x: rect.maxX, y: rect.maxY), color: UIColor(white: 0.85, alpha: 1))
        case .weekTotal(let week):
            let label = (week.isPartial ? "timesheet.weekTotal.partial" : "timesheet.weekTotal").localized(week.number)
            fill(rect, UIColor(white: 0.93, alpha: 1))
            drawTotals(label, worked: week.workedMinutes, balance: week.balanceMinutes, rect: rect, decimal: decimal)
            line(from: CGPoint(x: rect.minX, y: rect.maxY), to: CGPoint(x: rect.maxX, y: rect.maxY), color: .darkGray)
        case .summary:
            drawSummary(sheet, options: options, rect: rect)
        }
    }

    private func drawSummary(_ sheet: Timesheet, options: Timesheet.Options, rect: CGRect) {
        let totalRect = CGRect(x: rect.minX, y: rect.minY + 5, width: rect.width, height: 18)
        fill(totalRect, UIColor(white: 0.88, alpha: 1))
        drawTotals("timesheet.total".localized, worked: sheet.workedMinutes, balance: sheet.balanceMinutes,
                   rect: totalRect, decimal: options.useDecimalHours)

        let absences = sheet.absences.map { "\($0.type.localizedName) : \(daysText($0.days))" }
        if !absences.isEmpty {
            text("timesheet.absences".localized(absences.joined(separator: ", ")),
                 CGRect(x: rect.minX + 4, y: rect.minY + 30, width: rect.width - 8, height: 24), size: 9, lines: 2)
        }

        let width = (rect.width - 40) / 2
        for (index, key) in ["timesheet.signature.employee", "timesheet.signature.employer"].enumerated() {
            let x = rect.minX + CGFloat(index) * (width + 40)
            text(key.localized, CGRect(x: x, y: rect.minY + 56, width: width, height: 13), size: 9, weight: .semibold)
            line(from: CGPoint(x: x, y: rect.minY + 104), to: CGPoint(x: x + width, y: rect.minY + 104), color: .darkGray)
            text("timesheet.signature.date".localized, CGRect(x: x, y: rect.minY + 107, width: width, height: 13), size: 8, color: .darkGray)
        }
    }

    private func drawTotals(_ label: String, worked: Int, balance: Int, rect: CGRect, decimal: Bool) {
        drawCells(["", "", "", "", Timesheet.duration(worked, decimal: decimal), Timesheet.balance(balance, decimal: decimal), ""],
                  rect: rect, size: 9, weight: .bold)
        let width = Self.timesheetColumns.prefix(4).reduce(0, +) * rect.width
        text(label, CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height).insetBy(dx: 4, dy: 2), size: 9, weight: .bold)
    }

    private func drawCells(_ cells: [String], rect: CGRect, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .black) {
        var x = rect.minX
        for (index, cell) in cells.enumerated() {
            let width = Self.timesheetColumns[index] * rect.width
            let alignment: NSTextAlignment = (index == 0 || index == cells.count - 1) ? .left : .right
            text(cell, CGRect(x: x, y: rect.minY, width: width, height: rect.height).insetBy(dx: 4, dy: 1.5),
                 size: size, weight: weight, color: color, alignment: alignment)
            x += width
        }
    }

    private func text(
        _ value: String, _ rect: CGRect, size: CGFloat, weight: UIFont.Weight = .regular,
        color: UIColor = .black, alignment: NSTextAlignment = .left, lines: Int = 1
    ) {
        guard !value.isEmpty else { return }
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = lines == 1 ? .byTruncatingTail : .byWordWrapping
        // Chiffres à chasse fixe : les durées s'alignent en colonne.
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        NSString(string: value).draw(
            with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(rect.height, font.lineHeight)),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style],
            context: nil
        )
    }

    private func fill(_ rect: CGRect, _ color: UIColor) {
        color.setFill()
        UIBezierPath(rect: rect).fill()
    }

    private func line(from start: CGPoint, to end: CGPoint, color: UIColor) {
        color.setStroke()
        let path = UIBezierPath()
        path.lineWidth = 0.5
        path.move(to: start)
        path.addLine(to: end)
        path.stroke()
    }
}
