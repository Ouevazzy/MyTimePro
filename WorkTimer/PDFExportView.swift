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
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var includeCharts = true
    
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
                        Button(action: generateDocument) {
                            HStack {
                                Spacer()
                                if isGenerating {
                                    ProgressView()
                                        .padding(.trailing, 5)
                                }
                                Text(generatedPDFData == nil ? "Générer le document" : "Regénérer")
                                Spacer()
                            }
                        }
                        .disabled(isGenerating)
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
                    
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Fichier CSV généré")
                            .font(.headline)
                        
                        Text("Utilisez le bouton Partager pour enregistrer ou envoyer le fichier")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
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
                            showingShareSheet = true
                        }) {
                            Label("Partager", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = generatedPDFData {
                    ShareSheet(items: [data])
                }
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
        
        Task {
            // Générer PDF
            if format == .pdf {
                if let data = PDFService.shared.generateReport(
                    for: currentDate,
                    workDays: filteredWorkDays,
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
            let type = workDay.type.rawValue
            
            let startTime = workDay.startTime != nil ? timeFormatter.string(from: workDay.startTime!) : ""
            let endTime = workDay.endTime != nil ? timeFormatter.string(from: workDay.endTime!) : ""
            
            let breakDuration = WorkTimeCalculations.formattedTimeInterval(workDay.breakDuration)
            let totalHours = workDay.formattedTotalHours
            let overtimeHours = workDay.formattedOvertimeHours
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
