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
    @Query(sort: \WorkDay.date) private var workDays: [WorkDay]
    
    @State private var isGenerating = false
    @State private var generatedPDFData: Data?
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var includeCharts = true
    @State private var useDecimalHoursForExport: Bool = UserSettings.shared.useDecimalHours
    
    // Date actuelle basée sur la sélection
    private var currentDate: Date {
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // WorkDays filtrés pour la période sélectionnée
    private var filteredWorkDays: [WorkDay] {
        let calendar = Calendar.current
        
        if type == .monthly {
            guard let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth)),
                  let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return []
            }
            
            return workDays.filter {
                $0.date >= startOfMonth && $0.date < startOfNextMonth
            }
        } else { // Annual
            guard let startOfYear = calendar.date(from: DateComponents(year: selectedYear)),
                  let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return []
            }
            
            return workDays.filter {
                $0.date >= startOfYear && $0.date < startOfNextYear
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Options section
                Form {
                    // Format et période
                    Section(header: Text("OPTIONS")) {
                        // Choix du format des heures pour l'export
                        Picker("Format des heures", selection: $useDecimalHoursForExport) {
                            Text("Standard (8h30)").tag(false)
                            Text("Décimal (8.50 h)").tag(true)
                        }
                        
                        if format == .pdf {
                            Toggle("Inclure les graphiques", isOn: $includeCharts)
                                .disabled(type == .monthly)
                        }
                    }
                    
                    // Période
                    Section(header: Text("PÉRIODE")) {
                        if type == .annual {
                            Picker("Année", selection: $selectedYear) {
                                ForEach((Calendar.current.component(.year, from: Date())-5)...(Calendar.current.component(.year, from: Date())), id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.wheel)
                        } else {
                            // Year picker
                            Picker("Année", selection: $selectedYear) {
                                ForEach((Calendar.current.component(.year, from: Date())-5)...(Calendar.current.component(.year, from: Date())), id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            
                            // Month picker
                            Picker("Mois", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(monthName(month)).tag(month)
                                }
                            }
                        }
                    }
                    
                    // Entreprise
                    Section(header: Text("INFORMATIONS")) {
                        TextField("Nom de l'entreprise", text: $userCompany)
                    }
                    
                    // Génération
                    Section {
                        Button(action: {
                            Haptic.impact(.medium)
                            generateDocument()
                        }) {
                            HStack(spacing: 12) {
                                Spacer()
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: generatedPDFData == nil ? "doc.badge.plus" : "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text(generatedPDFData == nil ? "Générer le document" : "Regénérer")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: isGenerating ? [.gray, .gray.opacity(0.8)] : [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isGenerating)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .buttonStyle(.plain)
                    }
                }
                
                // Aperçu du PDF
                if let pdfData = generatedPDFData, format == .pdf {
                    Divider()
                    
                    PDFKitView(data: pdfData)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
                
                // Message si format CSV
                if format == .csv && generatedPDFData != nil {
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
                        Text("Fichier CSV généré")
                                .font(.title2)
                                .fontWeight(.bold)

                        Text("Utilisez le bouton Partager pour enregistrer ou envoyer le fichier")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                        }
                        
                        Button(action: {
                            Haptic.impact(.medium)
                            prepareShare()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Partager")
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .green.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(type == .monthly ? "Export Mensuel" : "Export Annuel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                if generatedPDFData != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            prepareShare()
                        }) {
                            Label("Partager", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                } else if let data = generatedPDFData {
                    ShareSheet(items: [data])
                } else {
                    Text("Aucun document à partager")
                }
            }
            .onDisappear {
                generatedPDFData = nil
            }
            .alert("Erreur", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Une erreur est survenue")
            }
        }
    }
    
    // Générer document (PDF ou CSV)
    private func generateDocument() {
        isGenerating = true
        
        // Configurer le thème PDF
        var theme = PDFService.PDFTheme()
        theme.companyName = userCompany
        theme.includeSummaryCharts = includeCharts
        theme.useDecimalHours = useDecimalHoursForExport
        
        Task {
            // Générer PDF
            if format == .pdf {
                // Passer tous les workDays pour permettre le calcul correct du report des vacances
                // PDFService fait son propre filtrage par année/mois pour les entrées du rapport
                if let data = PDFService.shared.generateReport(
                    for: currentDate,
                    workDays: workDays,
                    annual: type == .annual,
                    theme: theme
                ) {
                    await MainActor.run {
                        self.generatedPDFData = data
                        self.isGenerating = false
                    }
                } else {
                    await showError("Impossible de générer le PDF")
                }
            } else {
                // Générer CSV
                if let csvData = generateCSV() {
                    await MainActor.run {
                        self.generatedPDFData = csvData
                        self.isGenerating = false
                    }
                } else {
                    await showError("Impossible de générer le CSV")
                }
            }
        }
    }
    
    // Générer données CSV
    private func generateCSV() -> Data? {
        var csvString = "Date,Type,Début,Fin,Pause,Heures Totales,Heures Supp.,Bonus,Note\n"
        
        // Trier les workdays par date
        let sortedWorkDays = filteredWorkDays.sorted { $0.date < $1.date }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        for workDay in sortedWorkDays {
            let date = dateFormatter.string(from: workDay.date)
            let type = workDay.type.localizedName
            
            let startTime = workDay.startTime != nil ? timeFormatter.string(from: workDay.startTime!) : ""
            let endTime = workDay.endTime != nil ? timeFormatter.string(from: workDay.endTime!) : ""
            
            let breakDuration = WorkTimeCalculations.formattedTimeInterval(workDay.breakDuration)
            
            // Utiliser le format choisi pour l'export
            let totalHours: String
            let overtimeHours: String
            if useDecimalHoursForExport {
                totalHours = String(format: "%.2f", workDay.totalHours)
                overtimeHours = String(format: "%.2f", Double(workDay.overtimeSeconds) / 3600.0)
            } else {
                totalHours = WorkTimeCalculations.formattedTimeInterval(workDay.totalHours * 3600)
                overtimeHours = WorkTimeCalculations.formattedTimeInterval(Double(workDay.overtimeSeconds))
            }
            
            let bonus = String(format: "%.2f", workDay.bonusAmount)
            let note = workDay.note?.replacingOccurrences(of: ",", with: ";") ?? ""
            
            csvString.append("\(date),\(type),\(startTime),\(endTime),\(breakDuration),\(totalHours),\(overtimeHours),\(bonus),\(note)\n")
        }
        
        return csvString.data(using: .utf8)
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
        dateFormatter.locale = Locale(identifier: "fr_FR")
        return dateFormatter.monthSymbols[month - 1].capitalized
    }
    
    private func exportFileName() -> String {
        let year = selectedYear
        if type == .monthly {
            let m = String(format: "%02d", selectedMonth)
            return "WorkTimer-\(year)-\(m).pdf"
        } else {
            return "WorkTimer-\(year).pdf"
        }
    }

    private func prepareShare() {
        guard let data = generatedPDFData else { return }
        let fileName = exportFileName()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            self.shareURL = tempURL
        } catch {
            AppLogger.error("Failed to write PDF to temp file", category: AppLogger.general, error: error)
            ErrorManager.shared.handleExportError(error.localizedDescription)
            self.shareURL = nil
        }
        self.showingShareSheet = true
    }
}

// Vue pour afficher le PDF
struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            uiView.document = document
        }
    }
}
