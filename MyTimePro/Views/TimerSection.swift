import SwiftUI

struct TimerSection: View {
    @ObservedObject var timerManager: WorkTimerManager
    
    private var buttonText: String {
        switch timerManager.state {
        case .notStarted: return "Démarrer"
        case .running: return "Pause"
        case .paused: return "Reprendre"
        case .finished: return "Nouvelle"
        }
    }
    
    private var buttonColor: Color {
        switch timerManager.state {
        case .notStarted: return .blue
        case .running: return .orange
        case .paused: return .green
        case .finished: return .blue
        }
    }
    
    private var timerStatusColor: Color {
        switch timerManager.state {
        case .notStarted: return .secondary
        case .running: return .green
        case .paused: return .orange
        case .finished: return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Journée de travail")
                    .font(.headline)
                Spacer()
                Text("Restant")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TimerDisplayComponent(
                    time: timerManager.elapsedTime,
                    statusColor: timerStatusColor
                )
                
                Spacer()
                
                RemainingTimeComponent(time: timerManager.remainingTime)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    timerManager.toggleTimer()
                }) {
                    Text(buttonText)
                        .foregroundColor(.white)
                        .padding()
                        .background(buttonColor)
                        .cornerRadius(8)
                }
                
                if timerManager.state == .running || timerManager.state == .paused {
                    Button(action: {
                        Task {
                            await timerManager.attemptEndDay()
                        }
                    }) {
                        Text("Terminer")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Terminer la journée", isPresented: $timerManager.showEndDayAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Terminer", role: .destructive) {
                Task {
                    await timerManager.endDay()
                }
            }
        } message: {
            if let pauseTime = timerManager.pauseTime {
                Text("La journée sera enregistrée avec comme heure de fin \(pauseTime.formatted(date: .omitted, time: .shortened))")
            }
        }
    }
}
