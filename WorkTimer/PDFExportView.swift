import SwiftUI
import SwiftData
import PDFKit

struct PDFExportView: View {
    // Type d'exportation et format
    let type: ExportType
    @Binding var format: ExportFormat
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    @Binding var userCompany: String
    
    // Environnement et état
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // ✅ Plus de @Query global : la base complète n'est chargée qu'au moment
    // de la génération (le @Query observait tous les WorkDay et ré-évaluait
    // la vue à chaque frappe dans le champ entreprise).

    @State private var isGenerating = false
    @State private var generatedDocumentData: Data?
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var includeCharts = true
    @State private var useDecimalHoursForExport: Bool = UserSettings.shared.useDecimalHours
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case company
    }
    
    // Date actuelle basée sur la sélection
    private var currentDate: Date {
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }

    private var exportConfigurationSignature: String {
        [
            type.id,
            format == .pdf ? 0 : 1,
            selectedYear,
            selectedMonth,
            includeCharts ? 1 : 0,
            useDecimalHoursForExport ? 1 : 0,
            userCompany.hashValue
        ]
        .map(String.init)
        .joined(separator: ":")
    }
    
    // ✅ Bornes de la période sélectionnée (le fetch se fait dans ExportDataActor,
    // hors du main thread).
    private func periodRange() -> (start: Date, end: Date)? {
        let calendar = Calendar.current

        if type == .monthly {
            guard let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)),
                  let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return nil
            }
            return (startOfMonth, startOfNextMonth)
        } else { // Annual
            guard let startOfYear = calendar.date(from: DateComponents(year: selectedYear)),
                  let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return nil
            }
            return (startOfYear, startOfNextYear)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Options section
                Form {
                    // Format et période
                    Section(header: Text("export.section.options".localized)) {
                        // Choix du format des heures pour l'export
                        Picker("export.hourFormat.label".localized, selection: $useDecimalHoursForExport) {
                            Text("export.hourFormat.standard".localized).tag(false)
                            Text("export.hourFormat.decimal".localized).tag(true)
                        }
                        
                        if format == .pdf {
                            Toggle("export.includeCharts".localized, isOn: $includeCharts)
                                .disabled(type == .monthly)
                        }
                    }
                    
                    // Période
                    Section(header: Text("export.section.period".localized)) {
                        if type == .annual {
                            Picker("export.year.label".localized, selection: $selectedYear) {
                                ForEach(availableYears, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.wheel)
                        } else {
                            // Year picker
                            Picker("export.year.label".localized, selection: $selectedYear) {
                                ForEach(availableYears, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            
                            // Month picker
                            Picker("export.month.label".localized, selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(monthName(month)).tag(month)
                                }
                            }
                        }
                    }
                    
                    // Entreprise
                    Section(header: Text("export.section.info".localized)) {
                        TextField("export.company.placeholder".localized, text: $userCompany)
                            .focused($focusedField, equals: .company)
                            .submitLabel(.done)
                            .onSubmit {
                                focusedField = nil
                            }
                    }
                    
                    // Génération
                    Section {
                        Button(action: {
                            focusedField = nil
                            Haptic.impact(.medium)
                            generateDocument()
                        }) {
                            HStack(spacing: 12) {
                                Spacer()
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: generatedDocumentData == nil ? "doc.badge.plus" : "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text(generatedDocumentData == nil ? "export.generate.button".localized : "export.regenerate.button".localized)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: isGenerating ? [.gray, .gray.opacity(0.8)] : [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: DS.Radius.medium)
                            )
                        }
                        .disabled(isGenerating)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .buttonStyle(.plain)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Aperçu du PDF
                if let pdfData = generatedDocumentData, format == .pdf {
                    Divider()
                    
                    PDFKitView(data: pdfData)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
                
                // Message si format CSV
                if format == .csv && generatedDocumentData != nil {
                    Divider()
                    
                    VStack(spacing: 24) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.15), .green.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .accessibilityHidden(true)
                        }

                        VStack(spacing: 8) {
                        Text("export.csv.generated.title".localized)
                                .font(.title2)
                                .fontWeight(.bold)

                        Text("export.csv.generated.help".localized)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                                .padding(.horizontal, 40)
                        }
                        
                        if let shareURL {
                            ShareLink(item: shareURL) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("export.share.button".localized)
                                }
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.medium)
                                )
                                .shadow(color: .green.opacity(0.15), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(type == .monthly ? "export.monthly.title".localized : "export.annual.title".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel".localized) {
                        focusedField = nil
                        dismiss()
                    }
                }
                
                if let shareURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: shareURL) {
                            Label("export.share.button".localized, systemImage: "square.and.arrow.up")
                        }
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("action.done".localized) {
                        focusedField = nil
                    }
                }
            }
            .onDisappear {
                resetGeneratedDocument()
            }
            .onChange(of: exportConfigurationSignature) { _, _ in
                resetGeneratedDocument()
            }
            .alert("error.title".localized, isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "error.generic".localized)
            }
        }
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...currentYear)
    }
    
    // Générer document (PDF ou CSV)
    // ✅ Fetch + rendu délégués à ExportDataActor (arrière-plan) : l'UI ne gèle
    // plus pendant la génération d'un rapport annuel avec graphiques.
    private func generateDocument() {
        isGenerating = true

        let exporter = ExportDataActor(modelContainer: modelContext.container)
        let exportDate = currentDate
        let isAnnual = type == .annual
        let company = userCompany
        let charts = includeCharts
        let decimalHours = useDecimalHoursForExport

        Task {
            // Générer PDF
            if format == .pdf {
                if let data = await exporter.generatePDFReport(
                    for: exportDate,
                    annual: isAnnual,
                    companyName: company,
                    includeCharts: charts,
                    useDecimalHours: decimalHours
                ) {
                    finishGeneratedDocument(data)
                } else {
                    await showError("export.error.pdf".localized)
                }
            } else {
                // Générer CSV
                if let range = periodRange(),
                   let csvData = await exporter.generateCSVExport(
                    start: range.start,
                    end: range.end,
                    useDecimalHours: decimalHours
                   ) {
                    finishGeneratedDocument(csvData)
                } else {
                    await showError("export.error.csv".localized)
                }
            }
        }
    }
    
    // Afficher message d'erreur
    private func showError(_ message: String) async {
        await MainActor.run {
            errorMessage = message
            showingErrorAlert = true
            isGenerating = false
        }
    }
    
    // Obtenir le nom du mois à partir du numéro
    private func monthName(_ month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .autoupdatingCurrent
        return dateFormatter.monthSymbols[month - 1].capitalized
    }
    
    private func exportFileName() -> String {
        let year = selectedYear
        let fileExtension = format == .csv ? "csv" : "pdf"
        if type == .monthly {
            let m = String(format: "%02d", selectedMonth)
            return "WorkTimer-\(year)-\(m).\(fileExtension)"
        } else {
            return "WorkTimer-\(year).\(fileExtension)"
        }
    }

    private func finishGeneratedDocument(_ data: Data) {
        generatedDocumentData = data
        shareURL = writeGeneratedDocument(data)
        isGenerating = false
    }

    private func resetGeneratedDocument() {
        generatedDocumentData = nil
        shareURL = nil
    }

    private func writeGeneratedDocument(_ data: Data) -> URL? {
        let fileName = exportFileName()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            AppLogger.error("Failed to write PDF to temp file", category: AppLogger.general, error: error)
            ErrorManager.shared.handleExportError(error.localizedDescription)
            return nil
        }
    }
}

// Vue pour afficher le PDF
struct PDFKitView: UIViewRepresentable {
    let data: Data

    final class Coordinator {
        var loadedData: Data?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
            context.coordinator.loadedData = data
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        guard context.coordinator.loadedData != data else { return }

        if let document = PDFDocument(data: data) {
            uiView.document = document
            context.coordinator.loadedData = data
        }
    }
}

// MARK: - Acteur d'export en arrière-plan

/// ✅ Fetch et rendu PDF/CSV hors du MainActor.
/// @ModelActor fournit un ModelContext dédié sur un executor d'arrière-plan :
/// les WorkDay ne traversent jamais de frontière d'acteur (fetch et rendu
/// dans le même contexte), et UIGraphicsPDFRenderer est utilisable hors main.
@ModelActor
actor ExportDataActor {

    func generatePDFReport(
        for date: Date,
        annual: Bool,
        companyName: String,
        includeCharts: Bool,
        useDecimalHours: Bool
    ) -> Data? {
        // Base complète (hors supprimés) : nécessaire au calcul multi-année
        // du report des vacances. PDFService filtre ensuite par période.
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { !$0.isDeleted },
            sortBy: [SortDescriptor(\.date)]
        )
        guard let workDays = try? modelContext.fetch(descriptor) else { return nil }

        var theme = PDFService.PDFTheme()
        theme.companyName = companyName
        theme.includeSummaryCharts = includeCharts
        theme.useDecimalHours = useDecimalHours

        return PDFService.shared.generateReport(
            for: date,
            workDays: workDays,
            annual: annual,
            theme: theme
        )
    }

    func generateCSVExport(start: Date, end: Date, useDecimalHours: Bool) -> Data? {
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> {
                $0.date >= start && $0.date < end && !$0.isDeleted
            },
            sortBy: [SortDescriptor(\.date)]
        )
        guard let workDays = try? modelContext.fetch(descriptor) else { return nil }

        let csvString = CSVService.shared.generateDetailedExport(
            workDays: workDays,
            useDecimalHours: useDecimalHours
        )
        return CSVService.shared.csvData(content: csvString)
    }
}
