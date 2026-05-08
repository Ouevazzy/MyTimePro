import SwiftUI

struct SyncDetailsView: View {
    @Environment(ModernCloudService.self) private var cloudService
    @State private var showingResetAlert = false

    private func friendlyErrorMessage(from error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("network") || description.contains("connection") {
            return "sync.error.network".localized
        } else if description.contains("account") || description.contains("icloud") {
            return "sync.error.account".localized
        } else if description.contains("quota") || description.contains("space") {
            return "sync.error.quota".localized
        } else {
            return "sync.error.generic".localized
        }
    }

    var body: some View {
        List {
            Section {
                ModernCloudStatusView()
            }
            
            Section("sync.section.detailed".localized) {
                HStack {
                    Text("sync.lastSync.label".localized)
                    Spacer()
                    if let lastSync = cloudService.lastSyncDate {
                        Text(lastSync.formatted(.relative(presentation: .named)))
                            .foregroundColor(.secondary)
                    } else {
                        Text("sync.lastSync.never".localized)
                            .foregroundColor(.secondary)
                    }
                }
                
                if case .failed(let error) = cloudService.syncStatus {
                    HStack {
                        Text("sync.error.label".localized)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(friendlyErrorMessage(from: error))
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(error.localizedDescription)
                                .foregroundColor(.secondary)
                                .font(.caption2)
                        }
                    }
                }
            }
            
            Section("sync.section.actions".localized) {
                Button(action: {
                    Task {
                        try? await cloudService.sendChanges()
                    }
                }) {
                    Label("sync.syncNow".localized, systemImage: "arrow.triangle.2.circlepath")
                }

                Button(action: {
                    showingResetAlert = true
                }) {
                    Label("sync.reset".localized, systemImage: "arrow.counterclockwise")
                        .foregroundColor(.red)
                }
            }
            
            Section("sync.section.about".localized) {
                Text("sync.about.description".localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("sync.title".localized)
        .alert("sync.reset.title".localized, isPresented: $showingResetAlert) {
            Button("action.cancel".localized, role: .cancel) { }
            Button("sync.reset.confirm".localized, role: .destructive) {
                Task {
                    cloudService.initialize()
                }
            }
        } message: {
            Text("sync.reset.message".localized)
        }
    }
}

struct SyncDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SyncDetailsView()
                .environment(ModernCloudService.shared)
        }
    }
} 