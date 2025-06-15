import SwiftUI
import SwiftData
import PDFKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var settings = UserSettings.shared
    private var cloudService = ModernCloudService.shared
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    
    // MARK: - State Properties
    @State private var weeklyHours: Double = 41.0
    @State private var showingHoursPicker = false
    @State private var selectedHours: Double = 8.0
    @State private var showResetAlert = false
    @State private var showVacationDetails = false
    @State private var showRestoreAlert = false
    @State private var selectedTheme: AppTheme = .system
    @State private var activeSection: SettingsSection? = nil
    @State private var showConfetti = false
    
    // MARK: - Export Properties
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    @State private var exportType: ExportType?
    @State private var exportFormat: ExportFormat = .pdf
    @AppStorage("userProfile.name") private var userName = ""
    @AppStorage("userProfile.company") private var userCompany = ""
    
    // MARK: - Animation Properties
    @State private var animateWorkHours = false
    @State private var animateAnnualDays = false
    
    // MARK: - Constants
    private let weekDays = [
        "Lundi", "Mardi", "Mercredi", "Jeudi",
        "Vendredi", "Samedi", "Dimanche"
    ]
    
    private let currentYear = Calendar.current.component(.year, from: Date())
    
    // MARK: - Computed Properties
    private var calculatedDailyHours: Double {
        let workingDaysCount = settings.workingDays.filter { $0 }.count
        guard workingDaysCount > 0 else { return 0 }
        return (settings.weeklyHours / Double(workingDaysCount)).rounded(to: 2)
    }
    
    private var yearlyVacationStats: (used: Double, remaining: Double) {
        let currentYear = Calendar.current.component(.year, from: Date())
        let thisYearWorkDays = workDays.filter {
            Calendar.current.component(.year, from: $0.date) == currentYear
        }
        
        let vacationDays = thisYearWorkDays.reduce(0.0) { total, day in
            if day.type == .vacation {
                return total + 1
            } else if day.type == .halfDayVacation {
                return total + 0.5
            }
            return total
        }
        
        return (
            used: vacationDays,
            remaining: Double(settings.annualVacationDays) - vacationDays
        )
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(999)
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader
                        
                        // Cards pour chaque section
                        workTimeCard
                        appearanceCard // displayCard is now part of appearanceCard
                        exportCard
                        aboutCard
                        resetCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $showingHoursPicker) {
                NavigationStack {
                    ImprovedWeeklyHoursPickerView(
                        hours: $weeklyHours,
                        isPresented: $showingHoursPicker,
                        onSave: saveWeeklyHours
                    )
                }
            }
            .sheet(isPresented: $showVacationDetails) {
                VacationsView()
            }
            .sheet(item: $exportType) { type in
                PDFExportView(
                    type: type,
                    format: $exportFormat,
                    selectedYear: $selectedYear,
                    selectedMonth: $selectedMonth,
                    userCompany: $userCompany
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
            .alert("Réinitialiser les données", isPresented: $showResetAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Réinitialiser", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("Cette action réinitialisera tous les paramètres à leurs valeurs par défaut. Cette action est irréversible.")
            }
            .alert("Restaurer depuis iCloud ?", isPresented: $showRestoreAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Restaurer", role: .destructive) {
                    Task {
                        await cloudService.restoreFromCloud()
                    }
                }
            } message: {
                Text("Cette action va télécharger toutes les données disponibles sur iCloud. Les données existantes seront fusionnées avec celles d'iCloud.")
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring) {
                        animateWorkHours = true
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.spring) {
                        animateAnnualDays = true
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var profileHeader: some View {
        VStack(spacing: 15) {
            // Icône et informations utilisateur
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Profil")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Votre nom", text: $userName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    TextField("Entreprise", text: $userCompany)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Circle()
                    .fill(LinearGradient( // Keeping gradient for profile picture
                        colors: [ThemeManager.shared.currentAccentColor, .purple], // Using accent color in gradient
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(userName.isEmpty ? "?" : String(userName.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .padding(.trailing)
            }
            // Icône et informations utilisateur - Wrapped in StandardCardView
            StandardCardView(backgroundMaterial: .thinMaterial) { // Added paddingAmount to match original vertical padding
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Profil")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        TextField("Votre nom", text: $userName)
                            .font(.title2)
                            .fontWeight(.bold)

                        TextField("Entreprise", text: $userCompany)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    // .padding(.horizontal) // StandardCardView handles horizontal padding

                    Spacer()

                    Circle()
                        .fill(LinearGradient(
                            colors: [ThemeManager.shared.currentAccentColor, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(userName.isEmpty ? "?" : String(userName.prefix(1)))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        // .padding(.trailing) // StandardCardView handles padding
                }
                // Removed .padding(.horizontal) and .padding(.vertical, 10) as StandardCardView handles it
            }
            
            // Statistiques simples
            HStack(spacing: 15) {
                StatisticCard(
                    title: "Heures Hebdo",
                    value: String(format: "%.1f", settings.weeklyHours) + "h",
                    icon: "clock.fill",
                    color: ThemeManager.shared.currentAccentColor, // Updated
                    iconBackground: ThemeManager.shared.currentAccentColor.opacity(0.2), // Updated
                    animate: animateWorkHours
                )
                
                StatisticCard(
                    title: "Congés Annuels",
                    value: String(format: "%d", settings.annualVacationDays) + " jours",
                    icon: "sun.max.fill",
                    color: .orange,
                    iconBackground: .orange.opacity(0.2),
                    animate: animateAnnualDays
                )
            }
            .padding(.horizontal, 5)
        }
        .padding(.vertical, 10)
    }
    
    private var workTimeCard: some View {
        SettingsCard(
            title: "Horaires de travail",
            icon: "clock.fill",
            color: ThemeManager.shared.currentAccentColor, // Updated
            isExpanded: activeSection == .workTime,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .workTime ? nil : .workTime
                }
            }
        ) {
            VStack(spacing: 20) {
                // Heures par semaine
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heures par semaine")
                        .font(.headline)
                    
                    Button(action: {
                        weeklyHours = settings.weeklyHours
                        showingHoursPicker = true
                    }) {
                        HStack {
                            Text(String(format: "%.1f", settings.weeklyHours) + "h")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(ThemeManager.shared.currentAccentColor) // Updated
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ThemeManager.shared.currentAccentColor.opacity(0.1)) // Updated
                        )
                    }
                    .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                }
                
                // Jours travaillés
                VStack(alignment: .leading, spacing: 10) {
                    Text("Jours travaillés")
                        .font(.headline)
                    
                    VStack(spacing: 6) {
                        ForEach(weekDays.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: index < 5 ? "briefcase.fill" : "house.fill")
                                    .foregroundColor(index < 5 ? ThemeManager.shared.currentAccentColor : .orange) // Updated
                                    .frame(width: 22)
                                
                                Text(weekDays[index])
                                
                                Spacer()
                                
                                Toggle("", isOn: $settings.workingDays[index])
                                    .tint(index < 5 ? ThemeManager.shared.currentAccentColor : .orange) // Updated
                                    .onChange(of: settings.workingDays[index]) { _, _ in
                                        updateDailyHours()
                                    }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(settings.workingDays[index] ?
                                          (index < 5 ? ThemeManager.shared.currentAccentColor.opacity(0.1) : Color.orange.opacity(0.1)) : // Updated
                                          Color(.systemGray6))
                            )
                        }
                    }
                }
                
                // Calcul des heures par jour
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heures par jour")
                        .font(.headline)
                    
                    HStack {
                        Text(String(format: "%.2f", calculatedDailyHours) + "h")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("(calculé automatiquement)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Jours de congé
                VStack(alignment: .leading, spacing: 12) {
                    Text("Jours de congé annuels")
                        .font(.headline)
                    
                    HStack(spacing: 15) {
                        VStack(alignment: .center) {
                            Text("\(settings.annualVacationDays)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 60)
                        
                        Spacer()
                        
                        Button(action: {
                            if settings.annualVacationDays > 0 {
                                settings.annualVacationDays -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                        
                        Button(action: {
                            if settings.annualVacationDays < 50 {
                                settings.annualVacationDays += 1
                                if settings.annualVacationDays == 50 {
                                    withAnimation {
                                        showConfetti = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation {
                                            showConfetti = false
                                        }
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                    
                    // Progression des congés
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Congés utilisés: ")
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", yearlyVacationStats.used) + " sur \(settings.annualVacationDays)")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1f", yearlyVacationStats.remaining) + " restants")
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        
                        ProgressView(value: yearlyVacationStats.used, total: Double(settings.annualVacationDays))
                            .tint(.orange)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        
                        Button(action: { showVacationDetails = true }) {
                            Text("Voir les détails des congés")
                                .font(.subheadline)
                                .foregroundColor(ThemeManager.shared.currentAccentColor) // Updated
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(ThemeManager.shared.currentAccentColor, lineWidth: 1) // Updated
                                )
                        }
                        .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                    }
                }
            }
            .padding()
        }
    }
    
    // displayCard's content is merged into appearanceCard
    // private var displayCard: some View { ... } // This is removed or commented out

    private var appearanceCard: some View {
        SettingsCard(
            title: "Apparence et Affichage", // Updated title
            icon: "paintbrush.fill", // New icon
            color: ThemeManager.shared.currentAccentColor, // Dynamic color
            isExpanded: activeSection == .appearance,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .appearance ? nil : .appearance
                }
            }
        ) {
            VStack(spacing: 20) { // Increased spacing for better layout
                // Accent Color Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couleur d'accentuation")
                        .font(.headline)

                    Picker("Couleur", selection: $settings.accentColorName) {
                        ForEach(UserSettings.AccentColor.allCases) { colorCase in
                            HStack {
                                Circle()
                                    .fill(colorCase.color)
                                    .frame(width: 20, height: 20)
                                Text(colorCase.localizedName).tag(colorCase.rawValue)
                            }
                        }
                    }
                    .pickerStyle(.navigationLink) // Provides a new view for selection, good for many options
                    .tint(ThemeManager.shared.currentAccentColor) // Tints the picker chevron/selection
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ThemeManager.shared.currentAccentColor.opacity(0.1))
                )

                // Timer dans l'accueil (moved from displayCard)
                Toggle("Afficher le minuteur sur l'accueil", isOn: $settings.showTimerInHome)
                    .tint(ThemeManager.shared.currentAccentColor)
                
                // Format des heures (moved from displayCard)
                Toggle("Utiliser le format décimal pour les heures (ex: 7.50h)", isOn: $settings.useDecimalHours)
                    .tint(ThemeManager.shared.currentAccentColor)
            }
            .padding() // Add padding to the content of the card
        }
    }
    
    private var exportCard: some View {
        SettingsCard(
            title: "Exportation",
            icon: "square.and.arrow.up",
            color: .green,
            isExpanded: activeSection == .export,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .export ? nil : .export
                }
            }
        ) {
            VStack(spacing: 20) {
                // Format d'export
                VStack(alignment: .leading, spacing: 8) {
                    Text("Format d'export")
                        .font(.headline)
                    
                    Picker("Format", selection: $exportFormat) {
                        Text("PDF").tag(ExportFormat.pdf)
                        Text("CSV").tag(ExportFormat.csv)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 5)
                }
                
                // Options d'export
                HStack(spacing: 15) {
                    // Export mensuel
                    Button(action: {
                        exportType = .monthly
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.green)
                                )
                            
                            Text("Export mensuel")
                                .font(.headline)
                            
                            Text("Données détaillées pour un mois spécifique")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                    
                    // Export annuel
                    Button(action: {
                        exportType = .annual
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.green)
                                )
                            
                            Text("Export annuel")
                                .font(.headline)
                            
                            Text("Résumé complet de l'année avec graphiques")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                }
                
                // Personnalisation des exports
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personnalisation")
                        .font(.headline)
                    
                    HStack {
                        Text("Nom de l'entreprise:")
                            .foregroundColor(.secondary)
                        
                        TextField("Nom à afficher", text: $userCompany)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Text("Ce nom sera affiché sur les documents exportés")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .padding()
        }
    }
    
    private var aboutCard: some View {
        // Refactored aboutCard to use StandardCardView as its base
        StandardCardView(backgroundMaterial: .thinMaterial) {
            VStack(alignment: .leading, spacing: 10) {
                Text("À propos")
                    .font(.headline)
                    .padding(.bottom, 5)
            
            // Synchronisation
            VStack(alignment: .leading, spacing: 10) {
                ModernCloudStatusView()
                
                NavigationLink(destination: SyncDetailsView()) {
                    Text("Options de synchronisation avancées")
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.currentAccentColor) // Updated
                }
                .padding(.top, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            
            // Version
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6)) // Keep inner styling for these sub-items
            )
            // Removed .padding() and .background() as StandardCardView handles these
            }
        }
    }
    
    private var resetCard: some View {
        SettingsCard(
            title: "Réinitialisation",
            icon: "arrow.counterclockwise",
            color: .red,
            isExpanded: activeSection == .reset,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .reset ? nil : .reset
                }
            }
        ) {
            VStack(spacing: 15) {
                warningMessage
                
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Réinitialiser les paramètres")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .foregroundColor(.red)
                }
                .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
            }
            .padding()
        }
    }
    
    private var warningMessage: some View {
        HStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Attention")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("Cette action réinitialisera tous vos paramètres à leurs valeurs par défaut. Vos données ne seront pas supprimées, mais tous vos réglages personnalisés seront perdus.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    // MARK: - Helper Methods
    private func updateDailyHours() {
        settings.standardDailyHours = calculatedDailyHours
    }
    
    private func saveWeeklyHours(_ newValue: Double) {
        settings.weeklyHours = newValue
        updateDailyHours()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types
enum SettingsSection {
    case workTime, appearance, export, about, reset // Replaced display with appearance
}

enum AppTheme: String, CaseIterable, Identifiable { // This is for Light/Dark mode, not accent color
    case system, light, dark
    var id: String { self.rawValue }
}

enum ExportType: Identifiable {
    case monthly, annual
    var id: Int {
        switch self {
        case .monthly: return 1
        case .annual: return 2
        }
    }
}

enum ExportFormat {
    case pdf, csv
}

// MARK: - Custom Components
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: Content
    
    init(
        title: String,
        icon: String,
        color: Color,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content()
    }
    
    var body: some View {
        StandardCardView(paddingAmount: 0, backgroundMaterial: .thinMaterial) { // Added backgroundMaterial
            VStack(spacing: 0) {
                // Header
                Button(action: onToggle) {
                    HStack {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(color)
                            .cornerRadius(10)

                        Text(title)
                            .font(.headline)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                    .padding() // Padding for the button itself inside the card
                    // .background(Color(.systemBackground)) // Background provided by StandardCardView
                }
                .buttonStyle(PlainButtonStyle())

                // Content
                if isExpanded {
                    content
                        // .padding() // Content specific padding, if StandardCardView's isn't enough
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        // .clipShape(RoundedRectangle(cornerRadius: 15)) // Handled by StandardCardView
        // .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2) // Handled by StandardCardView
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let iconBackground: Color
    let animate: Bool
    
    var body: some View {
        StandardCardView(backgroundMaterial: .thinMaterial) { // Added backgroundMaterial
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .background(iconBackground)
                        .cornerRadius(8)

                    Spacer()

                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .scaleEffect(animate ? 1.0 : 0.7)
                    .opacity(animate ? 1.0 : 0.5)
            }
            .frame(maxWidth: .infinity) // Ensure VStack takes full width inside card
        }
    }
}

struct FormatPreviewView: View {
    let useDecimalHours: Bool
    
    private let examples = [
        (hours: 7.5, minutes: 30),
        (hours: 8.0, minutes: 0),
        (hours: 9.75, minutes: 45)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(examples, id: \.hours) { example in
                HStack {
                    Text("Exemple:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if useDecimalHours {
                        Text(String(format: "%.2f", example.hours) + "h")
                            .fontWeight(.medium)
                    } else {
                        Text("\(Int(example.hours))h\(String(format: "%02d", example.minutes))")
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
}

struct ImprovedWeeklyHoursPickerView: View {
    @Binding var hours: Double
    @Binding var isPresented: Bool
    let onSave: (Double) -> Void
    
    @State private var animateSlider = false
    @State private var selectedPreset: Double?
    
    let presets: [(label: String, value: Double)] = [
        ("35h (Légal FR)", 35.0),
        ("37.5h", 37.5),
        ("39h", 39.0),
        ("40h", 40.0),
        ("42h", 42.0)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête
            Text("Heures hebdomadaires")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Valeur actuelle
            Text(String(format: "%.1f", hours) + "h")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.shared.currentAccentColor) // Updated
                .padding(.top, 20)
            
            // Slider
            VStack(spacing: 8) {
                HStack {
                    Text("0h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("80h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $hours, in: 0...80, step: 0.5)
                    .tint(ThemeManager.shared.currentAccentColor) // Updated
                    .scaleEffect(x: animateSlider ? 1.0 : 0.9, y: 1.0)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5).delay(0.3)) {
                            animateSlider = true
                        }
                    }
            }
            .padding(.vertical, 20)
            
            // Préréglages
            VStack(alignment: .leading, spacing: 10) {
                Text("Préréglages communs")
                    .font(.headline)
                
                HStack {
                    ForEach(presets, id: \.value) { preset in
                        Button(action: {
                            withAnimation {
                                hours = preset.value
                                selectedPreset = preset.value
                            }
                        }) {
                            Text(preset.label)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedPreset == preset.value ? ThemeManager.shared.currentAccentColor : Color(.systemGray5)) // Updated
                                )
                                .foregroundColor(selectedPreset == preset.value ? .white : .primary)
                        }
                        .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                    }
                }
                .padding(.vertical, 10)
            }
            
            // Ajustement précis
            VStack(alignment: .leading, spacing: 5) {
                Text("Ajustement précis")
                    .font(.headline)
                
                HStack {
                    Button(action: {
                        if hours > 0 {
                            hours -= 0.5
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                        .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                    
                    Spacer()
                    
                    Button(action: {
                        hours = 40.0
                    }) {
                        Text("Standard 40h")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(ThemeManager.shared.currentAccentColor, lineWidth: 1) // Updated
                            )
                            .foregroundColor(ThemeManager.shared.currentAccentColor) // Updated
                    }
                    .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                    
                    Spacer()
                    
                    Button(action: {
                        if hours < 80 {
                            hours += 0.5
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                        .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                }
                .padding(.vertical, 10)
            }
            
            Spacer()
            
            // Boutons d'action
            HStack(spacing: 20) {
                Button(action: {
                    isPresented = false
                }) {
                    Text("Annuler")
                        .fontWeight(.medium)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ThemeManager.shared.currentAccentColor, lineWidth: 1) // Updated
                        )
                        .foregroundColor(ThemeManager.shared.currentAccentColor) // Updated
                }
                .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
                
                Button(action: {
                    onSave(hours)
                    isPresented = false
                }) {
                    Text("Enregistrer")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ThemeManager.shared.currentAccentColor) // Updated
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(AppButtonStyle()) // Applied AppButtonStyle
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

// MARK: - Animations
struct ConfettiView: View {
    @State private var confetti: [ConfettiPiece] = []
    
    struct ConfettiPiece: Identifiable {
        let id = UUID()
        let color: Color
        let position: CGPoint
        let rotation: Double
        let size: CGFloat
        let animationDelay: Double
    }
    
    var body: some View {
        ZStack {
            ForEach(confetti) { piece in
                Circle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .position(piece.position)
                    .rotationEffect(.degrees(piece.rotation))
                    .opacity(0)
                    .animation(
                        Animation
                            .easeOut(duration: 2)
                            .delay(piece.animationDelay)
                            .speed(0.7),
                        value: piece.id
                    )
            }
        }
        .onAppear {
            generateConfetti()
        }
    }
    
    private func generateConfetti() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
        confetti = (0..<100).map { _ in
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            
            return ConfettiPiece(
                color: colors.randomElement()!,
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: -100...screenHeight/2)
                ),
                rotation: Double.random(in: 0...360),
                size: CGFloat.random(in: 5...12),
                animationDelay: Double.random(in: 0...0.5)
            )
        }
    }
}

// MARK: - Extensions
extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}

// MARK: - Custom ButtonStyle
struct AppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1.0) // Slightly more noticeable opacity change
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0) // Slightly more noticeable scale
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
