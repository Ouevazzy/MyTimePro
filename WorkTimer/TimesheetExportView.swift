//
//  TimesheetExportView.swift
//  WorkTimer
//
//  Choix de la période, aperçu et partage de la feuille d'heures (Pro).
//

import SwiftData
import SwiftUI

struct TimesheetExportView: View {
    @Binding var format: ExportFormat

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userProfile.name") private var userName = ""
    @AppStorage("userProfile.company") private var userCompany = ""
    @AppStorage("timesheet.period") private var period: Timesheet.Period = .week
    @State private var date = Date()
    @State private var useDecimalHours = UserSettings.shared.useDecimalHours
    @State private var includeNotes = false
    @State private var document: TimesheetDocument?
    @State private var showPreview = false
    @FocusState private var isEditing: Bool

    /// Tout ce qui change le document : un nouveau rendu est nécessaire.
    private struct Request: Hashable {
        let period: Timesheet.Period
        let start: Date
        let isPDF, decimal, notes: Bool
        let name, company: String
    }

    private var request: Request {
        Request(
            period: period, start: Timesheet.interval(period, containing: date).start,
            isPDF: format == .pdf, decimal: useDecimalHours, notes: includeNotes,
            name: userName.trimmingCharacters(in: .whitespaces),
            company: userCompany.trimmingCharacters(in: .whitespaces)
        )
    }

    private var title: String {
        Timesheet(period: period, containing: date, workDays: []).title(locale: .current)
    }

    var body: some View {
        Form {
            Section("export.section.period".localized) {
                Picker("export.section.period".localized, selection: $period) {
                    ForEach(Timesheet.Period.allCases) {
                        Text("timesheet.period.\($0.rawValue)".localized).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    stepButton(-1, icon: "chevron.left", label: "timesheet.previous")
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("timesheet.period.title")
                    stepButton(1, icon: "chevron.right", label: "timesheet.next")
                }
            }

            Section("export.section.info".localized) {
                TextField("settings.profile.name".localized, text: $userName)
                    .focused($isEditing)
                TextField("export.company.placeholder".localized, text: $userCompany)
                    .focused($isEditing)
            }

            Section {
                Picker("settings.export.format".localized, selection: $format) {
                    Text("PDF").tag(ExportFormat.pdf)
                    Text("CSV").tag(ExportFormat.csv)
                }
                .pickerStyle(.segmented)
                Picker("export.hourFormat.label".localized, selection: $useDecimalHours) {
                    Text("export.hourFormat.standard".localized).tag(false)
                    Text("export.hourFormat.decimal".localized).tag(true)
                }
                Toggle("timesheet.includeNotes".localized, isOn: $includeNotes)
            } header: {
                Text("export.section.options".localized)
            } footer: {
                Text("timesheet.privacy".localized)
            }

            Section {
                if let document {
                    if format == .pdf {
                        Button {
                            showPreview = true
                        } label: {
                            Label("timesheet.preview".localized, systemImage: "doc.text.magnifyingglass")
                        }
                        .accessibilityIdentifier("timesheet.preview")
                    }
                    ShareLink(item: document.url) {
                        Label("export.share.button".localized, systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("timesheet.share")
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            } footer: {
                if document?.isEmpty == true {
                    Text("timesheet.empty".localized)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("timesheet.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action.close".localized) { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("action.done".localized) { isEditing = false }
            }
        }
        .task(id: request) { await generate() }
        .sheet(isPresented: $showPreview) {
            if let document {
                NavigationStack {
                    PDFKitView(data: document.data)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("timesheet.preview".localized)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("action.close".localized) { showPreview = false }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                ShareLink(item: document.url)
                            }
                        }
                }
            }
        }
        .withErrorHandling()
    }

    private func stepButton(_ offset: Int, icon: String, label: String) -> some View {
        Button {
            let component: Calendar.Component = period == .week ? .weekOfYear : .month
            date = Timesheet.calendar.date(byAdding: component, value: offset, to: date) ?? date
        } label: {
            Image(systemName: icon)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label.localized)
        .accessibilityIdentifier(label)
    }

    private func generate() async {
        document = nil
        // Laisse finir la frappe avant de refaire le document.
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        let options = Timesheet.Options(
            employee: request.name, company: request.company,
            useDecimalHours: useDecimalHours, includeNotes: includeNotes,
            locale: .current // langue de l'app et région du téléphone
        )
        let exporter = ExportDataActor(modelContainer: modelContext.container)
        do {
            let result = try await exporter.generateTimesheet(
                period: period, containing: date, options: options, asPDF: format == .pdf)
            guard !Task.isCancelled else { return }
            document = result
        } catch {
            guard !Task.isCancelled else { return }
            ErrorManager.shared.handleExportError(error.localizedDescription)
        }
    }
}

struct TimesheetDocument {
    let url: URL
    let data: Data
    let isEmpty: Bool
}

extension ExportDataActor {
    func generateTimesheet(
        period: Timesheet.Period, containing date: Date, options: Timesheet.Options, asPDF: Bool
    ) throws -> TimesheetDocument {
        let interval = Timesheet.interval(period, containing: date)
        let start = interval.start, end = interval.end
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate { $0.date >= start && $0.date < end && !$0.isDeleted },
            sortBy: [SortDescriptor(\.date)]
        )
        let sheet = Timesheet(period: period, containing: date, workDays: try modelContext.fetch(descriptor))
        let data = asPDF
            ? PDFService.shared.generateTimesheet(sheet, options: options)
            : Data(("\u{FEFF}" + sheet.csv(options: options)).utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sheet.fileName).\(asPDF ? "pdf" : "csv")")
        try data.write(to: url, options: .atomic)
        return TimesheetDocument(url: url, data: data, isEmpty: sheet.isEmpty)
    }
}

#Preview {
    NavigationStack { TimesheetExportView(format: .constant(.pdf)) }
        .modelContainer(for: WorkDay.self, inMemory: true)
}
