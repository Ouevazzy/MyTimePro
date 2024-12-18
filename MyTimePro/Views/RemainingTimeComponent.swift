import SwiftUI

struct RemainingTimeComponent: View {
    let time: TimeInterval
    
    var body: some View {
        Text(formatTime(time))
            .font(.system(.title2, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        let seconds = Int(roundedInterval) % 60
        return String(format: "%dh%02dmin %02d", hours, minutes, seconds)
    }
}
