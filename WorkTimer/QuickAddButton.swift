//
//  QuickAddButton.swift
//  WorkTimer
//
//  Bouton flottant en verre interactif pour la saisie rapide d'une journée.
//  Posé au-dessus de la tab bar sur Accueil, Journées et Calendrier.
//

import SwiftUI

struct QuickAddButton: View {
    @State private var showAddSheet = false

    var body: some View {
        Button {
            Haptic.impact(.medium)
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 56, height: 56)
                .contentShape(Circle())
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
    /// Superpose le bouton flottant de saisie rapide en bas à droite,
    /// au-dessus de la tab bar.
    func quickAddOverlay() -> some View {
        overlay(alignment: .bottomTrailing) {
            QuickAddButton()
                .padding(.trailing, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.sm)
        }
    }
}

#Preview {
    Color.clear
        .quickAddOverlay()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
