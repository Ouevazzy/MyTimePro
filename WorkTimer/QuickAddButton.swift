//
//  QuickAddButton.swift
//  WorkTimer
//
//  Commande de saisie rapide dans la barre de navigation.
//

import SwiftUI

struct QuickAddButton: View {
    @State private var showAddSheet = false
    @State private var bounce = 0

    var body: some View {
        Button {
            Haptic.impact(.medium)
            bounce += 1
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: DS.Touch.minSize, height: DS.Touch.minSize)
                .contentShape(Circle())
                .symbolEffect(.bounce, value: bounce)
        }
        .buttonStyle(.glassProminent)
        .clipShape(Circle())
        .accessibilityLabel("action.add".localized)
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddEditWorkDayView(workDay: WorkDay(
                    date: Calendar.current.startOfDay(for: Date()),
                    type: .work
                ))
            }
        }
    }
}

extension View {
    /// Une commande de navigation ne recouvre pas les données des cartes.
    func quickAddToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                QuickAddButton()
            }
        }
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .quickAddToolbar()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
