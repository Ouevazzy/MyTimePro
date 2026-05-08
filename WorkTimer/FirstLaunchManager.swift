import SwiftUI

@Observable
class FirstLaunchManager {
    var showFirstSyncInfo = false
    
    init() {
        // Vérifier si c'est une première installation ou réinstallation
        let hasCompletedFirstSync = UserDefaults.standard.bool(forKey: "hasCompletedFirstSync")
        let isReinstallation = UserDefaults.standard.bool(forKey: "isReinstallation")
        
        if !hasCompletedFirstSync || isReinstallation {
            showFirstSyncInfo = true

            // Note: CloudKit initialization flag is now managed exclusively by WorkTimerApp
            // to prevent interference with cloud service initialization
        }
    }
    
    func markFirstSyncCompleted() {
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstSync")
        UserDefaults.standard.set(false, forKey: "isReinstallation")
        showFirstSyncInfo = false
    }
}

struct FirstLaunchInfoView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var animateIcon = false
    @Environment(\.colorScheme) var colorScheme
    
    private let features: [(icon: String, title: String, description: String, colors: [Color])] = [
        ("clock.badge.checkmark", "Suivi du temps", "Enregistrez facilement vos heures de travail, pauses et heures supplémentaires", [.blue, .cyan]),
        ("calendar.badge.clock", "Gestion des congés", "Suivez vos congés, RTT et absences en un coup d'œil", [.orange, .yellow]),
        ("icloud.fill", "Synchronisation iCloud", "Vos données sont synchronisées et sécurisées sur tous vos appareils", [.purple, .pink]),
        ("chart.bar.fill", "Statistiques détaillées", "Analysez vos heures avec des graphiques et rapports exportables", [.green, .mint])
    ]
    
    var body: some View {
        ZStack {
            // Fond avec gradient
            LinearGradient(
                colors: [
                    features[currentPage].colors[0].opacity(0.1),
                    features[currentPage].colors[1].opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(DS.Animation.navigation, value: currentPage)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button("Passer") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }
                
                Spacer()
                
                // Contenu principal
                TabView(selection: $currentPage) {
                    ForEach(0..<features.count, id: \.self) { index in
                        featureCard(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                
                // Indicateurs de page
                HStack(spacing: 8) {
                    ForEach(0..<features.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? features[currentPage].colors[0] : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 30)
                
                // Bouton principal
                Button(action: {
                    if currentPage < features.count - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    } else {
                        Haptic.notification(.success)
                    isPresented = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(currentPage < features.count - 1 ? "Suivant" : "Commencer")
                            .fontWeight(.semibold)
                        
                        Image(systemName: currentPage < features.count - 1 ? "arrow.right" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: features[currentPage].colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: features[currentPage].colors[0].opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    @ViewBuilder
    private func featureCard(for index: Int) -> some View {
        let feature = features[index]
        
        VStack(spacing: 24) {
            // Icône avec effet de cercle
            ZStack {
                // Fond arrondi animé
                RoundedRectangle(cornerRadius: 36)
                    .fill(
                        LinearGradient(
                            colors: [feature.colors[0].opacity(0.2), feature.colors[1].opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .scaleEffect(animateIcon && currentPage == index ? 1.05 : 1.0)
                    .animation(.spring(response: 1.8, dampingFraction: 0.5).repeatForever(autoreverses: true), value: animateIcon)

                // Icône principale
                Image(systemName: feature.icon)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: feature.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: currentPage)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 20)

            // Titre
            Text(feature.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            // Description
            Text(feature.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .onAppear {
            animateIcon = true
        }
    }
}

#Preview {
    FirstLaunchInfoView(isPresented: .constant(true))
} 
