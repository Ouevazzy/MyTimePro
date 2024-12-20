import SwiftUI
import PDFKit
import SwiftData

struct PDFExportView: View {
    @Environment(\\.modelContext) private var modelContext
    @Query(sort: \\WorkDay.date) private var workDays: [WorkDay]
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?
    
    var body: some View {
        VStack {
            Button("Générer le PDF") {
                generateAndSharePDF()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
        }
        .navigationTitle("Export PDF")
    }
    
    private func generateAndSharePDF() {
        let pdfData = PDFService.generatePDF(from: workDays)
        
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let pdfURL = temporaryDirectoryURL.appendingPathComponent("MyTimePro_Export.pdf")
        
        do {
            try pdfData.write(to: pdfURL)
            self.pdfURL = pdfURL
            showingShareSheet = true
        } catch {
            print("Erreur lors de l'écriture du PDF: \\(error)")
        }
    }
}