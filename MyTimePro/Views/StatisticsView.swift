import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedPeriod: StatisticsPeriod = .week
    
    var body: some View {
        List {
            Section(header: Text("Période")) {
                Picker("Période", selection: $selectedPeriod) {
                    ForEach(StatisticsPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPeriod) { _ in
                    Task {
                        await viewModel.loadStatistics(for: selectedPeriod)
                    }
                }
            }
            
            if viewModel.isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            } else {
                workingSummarySection
                chartSection
                weekdayDistributionSection
            }
        }
        .navigationTitle("Statistiques")
        .onAppear {
            Task {
                await viewModel.loadStatistics(for: selectedPeriod)
            }
        }
        .alert("Erreur", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue")
        }
    }
    
    private var workingSummarySection: some View {
        Section(header: Text("Résumé")) {
            HStack {
                Text("Heures totales")
                Spacer()
                Text(viewModel.totalHours)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Moyenne quotidienne")
                Spacer()
                Text(viewModel.averageHoursPerDay)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Jours travaillés")
                Spacer()
                Text(viewModel.workedDaysCount)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var chartSection: some View {
        Section(header: Text("Graphique")) {
            if #available(iOS 16.0, *) {
                Chart(viewModel.chartData) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Heures", item.hours)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .frame(height: 200)
                .padding(.vertical)
            } else {
                Text("Graphique disponible sur iOS 16 et supérieur")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var weekdayDistributionSection: some View {
        Section(header: Text("Distribution par jour")) {
            ForEach(viewModel.weekdayDistribution.sorted(by: { $0.key < $1.key }), id: \.key) { weekday, hours in
                HStack {
                    Text(Calendar.current.weekdaySymbols[weekday - 1])
                    Spacer()
                    Text(String(format: "%.1f h", hours))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}