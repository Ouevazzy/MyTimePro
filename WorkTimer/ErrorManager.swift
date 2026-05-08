import SwiftUI
import os.log

// MARK: - Error Types
enum AppError: LocalizedError {
    case networkError(String)
    case dataError(String)
    case cloudKitError(String)
    case validationError(String)
    case exportError(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Erreur réseau : \(message)"
        case .dataError(let message):
            return "Erreur de données : \(message)"
        case .cloudKitError(let message):
            return "Erreur iCloud : \(message)"
        case .validationError(let message):
            return "Erreur de validation : \(message)"
        case .exportError(let message):
            return "Erreur d'export : \(message)"
        case .unknown(let error):
            return "Erreur : \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Vérifiez votre connexion internet et réessayez."
        case .dataError:
            return "Essayez de redémarrer l'application."
        case .cloudKitError:
            return "Vérifiez votre connexion iCloud dans les Réglages."
        case .validationError:
            return "Vérifiez les informations saisies."
        case .exportError:
            return "Vérifiez l'espace disponible et réessayez."
        case .unknown:
            return "Si le problème persiste, contactez le support."
        }
    }
    
    var icon: String {
        switch self {
        case .networkError:
            return "wifi.exclamationmark"
        case .dataError:
            return "exclamationmark.triangle"
        case .cloudKitError:
            return "icloud.slash"
        case .validationError:
            return "xmark.circle"
        case .exportError:
            return "doc.badge.ellipsis"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .networkError:
            return .orange
        case .dataError, .validationError:
            return .red
        case .cloudKitError:
            return .purple
        case .exportError:
            return .yellow
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Error Manager
@MainActor
@Observable
final class ErrorManager {
    static let shared = ErrorManager()

    var currentError: AppError?
    var showError = false
    var errorHistory: [ErrorEntry] = []
    
    struct ErrorEntry: Identifiable {
        let id = UUID()
        let error: AppError
        let timestamp: Date
    }
    
    private init() {}
    
    func handle(_ error: Error, context: String = "") {
        let appError: AppError
        
        if let appErr = error as? AppError {
            appError = appErr
        } else {
            appError = .unknown(error)
        }
        
        // Log l'erreur
        AppLogger.error("[\(context)] \(appError.errorDescription ?? "Unknown error")", category: AppLogger.general)
        
        // Crash Reporting
        CrashReporting.shared.recordError(error, userInfo: ["context": context])
        
        // Analytics
        Analytics.shared.logError(context.isEmpty ? "unknown" : context, error: error)
        
        // Stocker dans l'historique
        errorHistory.append(ErrorEntry(error: appError, timestamp: Date()))
        
        // Limiter l'historique à 50 entrées
        while errorHistory.count > 50 {
            errorHistory.removeFirst()
        }
        
        // Afficher l'erreur
        currentError = appError
        showError = true
        
        // Feedback haptique
        Haptic.notification(.error)
    }
    
    func handleNetworkError(_ message: String) {
        handle(AppError.networkError(message), context: "Network")
    }
    
    func handleDataError(_ message: String) {
        handle(AppError.dataError(message), context: "Data")
    }
    
    func handleCloudKitError(_ message: String) {
        handle(AppError.cloudKitError(message), context: "CloudKit")
    }
    
    func handleValidationError(_ message: String) {
        handle(AppError.validationError(message), context: "Validation")
    }
    
    func handleExportError(_ message: String) {
        handle(AppError.exportError(message), context: "Export")
    }
    
    func dismiss() {
        showError = false
        currentError = nil
    }
    
    func clearHistory() {
        errorHistory.removeAll()
    }
}

// MARK: - Error Alert View Modifier
struct ErrorAlertModifier: ViewModifier {
    @Bindable var errorManager = ErrorManager.shared

    func body(content: Content) -> some View {
        content
            .alert("error.title".localized, isPresented: $errorManager.showError) {
                Button("OK", role: .cancel) {
                    errorManager.dismiss()
                }

                if errorManager.currentError?.recoverySuggestion != nil {
                    Button("action.retry".localized) {
                        errorManager.dismiss()
                        // L'action de réessai peut être gérée par la vue appelante
                    }
                }
            } message: {
                if let error = errorManager.currentError {
                    VStack {
                        Text(error.errorDescription ?? "error.generic".localized)
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                        }
                    }
                }
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - Error Toast View
struct ErrorToast: View {
    let error: AppError
    let onDismiss: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .font(.title3)
                .foregroundColor(error.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "Erreur")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
            
            // Auto-dismiss après 5 secondes
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation(DS.Animation.micro) {
                    isVisible = false
                }
                try? await Task.sleep(for: .milliseconds(300))
                onDismiss()
            }
        }
    }
}

// MARK: - Preview
#Preview("Error Toast") {
    VStack {
        Spacer()
        ErrorToast(error: .networkError("Connexion impossible"), onDismiss: {})
        Spacer()
    }
}

