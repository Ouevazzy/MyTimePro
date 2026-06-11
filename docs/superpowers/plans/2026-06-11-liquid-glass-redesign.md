# Refonte Liquid Glass iOS 26 — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopter le langage Liquid Glass natif iOS 26 de façon cohérente sur tous les écrans de WorkTimer, avec un Accueil héro et un bouton flottant de saisie rapide.

**Architecture:** On renforce d'abord le design system (`DS` + modificateurs verre), puis on refond les écrans un par un dans l'ordre de visibilité : Accueil → Journées → Calendrier → Stats → Charts → Réglages/Paywall. Aucune logique métier ni modèle de données ne change. Chaque tâche se termine par un build vert + capture simulateur + tests existants au vert.

**Tech Stack:** SwiftUI iOS 26 (`glassEffect`, `GlassEffectContainer`, `glassEffectID`, `.buttonStyle(.glass)`, `tabBarMinimizeBehavior`), SwiftData, Swift Charts.

**Vérification standard (chaque tâche):**
- Build : `mcp build_sim` (zéro erreur, zéro warning)
- Visuel : `mcp build_run_sim` + `screenshot`
- Tests : `mcp test_sim` au moins en fin de phase

---

### Task 1: DesignSystem — verre natif par défaut + nouvelles primitives

**Files:**
- Modify: `WorkTimer/DesignSystem.swift`

- [ ] **Step 1: `dsGlassSurface` passe au verre natif par défaut**

Dans `DSGlassSurfaceModifier`, le verre natif devient le rendu standard (le paramètre `nativeGlass:` est conservé pour compat mais ignoré ; un nouveau paramètre `tint:` permet le verre teinté sémantique) :

```swift
func dsGlassSurface(
    cornerRadius: CGFloat = DS.Radius.card,
    tint: Color? = nil,
    interactive: Bool = false
) -> some View {
    modifier(DSGlassSurfaceModifier(
        cornerRadius: cornerRadius,
        tint: tint,
        interactive: interactive
    ))
}

private struct DSGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background {
                    shape.fill(Color(.secondarySystemGroupedBackground))
                    if let tint {
                        shape.fill(tint.opacity(DS.Background.tintedCard))
                    }
                }
                .clipShape(shape)
        } else {
            content
                .glassEffect(glass, in: shape)
        }
    }

    private var glass: Glass {
        var g: Glass = .regular
        if let tint { g = g.tint(tint.opacity(DS.Glass.tintStrength)) }
        if interactive { g = g.interactive() }
        return g
    }
}
```

Ajouter dans `DS.Glass` : `static let tintStrength: Double = 0.35`.
Supprimer les appels existants `opacity:`/`nativeGlass:` dans tout le projet (grep `dsGlassSurface(`).

- [ ] **Step 2: fond d'écran teinté `dsScreenBackground`**

```swift
extension View {
    /// Couche 1 de la hiérarchie de profondeur : fond dégradé subtil teinté.
    func dsScreenBackground(_ tint: Color = .blue) -> some View {
        background {
            LinearGradient(
                colors: [
                    tint.opacity(0.10),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}
```

- [ ] **Step 3: build + commit**

Run: build_sim → SUCCEEDED. Corriger tous les sites d'appel cassés par la nouvelle signature.
Commit : `git commit -m "DS: verre natif par défaut, surfaces teintées, fond d'écran dégradé"`

---

### Task 2: Accueil — dashboard héro en verre

**Files:**
- Modify: `WorkTimer/HomeTabView.swift`

- [ ] **Step 1: restructurer en ScrollView + cartes verre groupées**

Remplacer la `List` par un `ScrollView` + `dsGlassEffectGroup`. Ajouter une carte héro en tête : solde d'heures supp. annuel en `DS.Font.statDisplay`, `.rounded`, vert/rouge, `contentTransition(.numericText())`. Les sections Année/Mois/Semaine deviennent des `CardView` en verre avec leurs `SectionHeader` au-dessus. La section Congés devient une carte verre teintée orange avec la jauge.

- [ ] **Step 2: fond teinté + apparition étagée**

`dsScreenBackground(.blue)` sur le ScrollView ; les cartes apparaissent avec `DS.Animation.appear` décalée (`.delay(Double(index) * 0.05)`), désactivée si `reduceMotion`.

- [ ] **Step 3: build + screenshot + commit**

---

### Task 3: Bouton flottant « + » de saisie rapide

**Files:**
- Create: `WorkTimer/QuickAddButton.swift`
- Modify: `WorkTimer/HomeTabView.swift`, `WorkTimer/WorkDaysListView.swift`, `WorkTimer/CalendarView.swift`

- [ ] **Step 1: composant**

```swift
import SwiftUI

/// Bouton flottant en verre interactif pour la saisie rapide d'une journée.
/// Posé en safeAreaInset bas-droit au-dessus de la tab bar.
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
        }
        .buttonStyle(.glass)
        .clipShape(Circle())
        .accessibilityLabel("action.addWorkDay".localized)
        .sheet(isPresented: $showAddSheet) {
            AddEditWorkDayView(workDay: nil)
        }
    }
}

extension View {
    func quickAddOverlay() -> some View {
        overlay(alignment: .bottomTrailing) {
            QuickAddButton()
                .padding(.trailing, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.sm)
        }
    }
}
```

(Adapter l'init `AddEditWorkDayView` et la clé de localisation au réel — vérifier avant.)

- [ ] **Step 2: intégrer sur Accueil, Journées, Calendrier** via `.quickAddOverlay()` sur la racine de chaque vue.

- [ ] **Step 3: build + screenshot + commit**

---

### Task 4: Journées (WorkDaysListView)

**Files:**
- Modify: `WorkTimer/WorkDaysListView.swift`

- [ ] **Step 1:** lignes en cartes verre : `listRowBackground(Color.clear)` + contenu `.dsGlassSurface(cornerRadius: DS.Radius.medium)`, `scrollContentBackground(.hidden)`, `dsScreenBackground(.blue)`. En-têtes de mois : pill verre (`dsGlassSurface(cornerRadius: DS.Radius.small)`). Swipe actions et navigation inchangées.
- [ ] **Step 2:** build + screenshot + commit.

---

### Task 5: Calendrier (CalendarView)

**Files:**
- Modify: `WorkTimer/CalendarView.swift`

- [ ] **Step 1:** conteneur de grille en carte verre ; cellules de jour avec pastille `dsGlassSurface(tint:)` selon `DS.Colors` du type de jour ; sélection : anneau + `matchedGeometryEffect` (ou `glassEffectID` si conteneur commun). Fond `dsScreenBackground(.purple)`. Fiche du jour : sheet avec `presentationDetents([.medium, .large])` + fond verre.
- [ ] **Step 2:** build + screenshot + commit.

---

### Task 6: Statistiques (StatsView + StatsSubviews)

**Files:**
- Modify: `WorkTimer/StatsView.swift`, `WorkTimer/StatsSubviews.swift`

- [ ] **Step 1:** la grille de StatCards passe dans un `dsGlassEffectGroup` (fusion des surfaces) ; sélecteur d'année en pill verre interactif ; fond `dsScreenBackground(.blue)` ; cartes mensuelles en verre (déjà partiellement fait — harmoniser sur la nouvelle signature).
- [ ] **Step 2:** build + screenshot + commit.

---

### Task 7: Graphiques (ChartsView/ChartsSubviews)

**Files:**
- Modify: `WorkTimer/ChartsView.swift`, `WorkTimer/ChartsSubviews.swift`

- [ ] **Step 1:** cartes graphiques en verre, dégradés `LinearGradient` sous les courbes/barres (`.foregroundStyle(gradient)`), fond teinté. Sélection scrub si déjà présente, sinon hors périmètre.
- [ ] **Step 2:** build + screenshot + commit.

---

### Task 8: Réglages + Paywall — alignement

**Files:**
- Modify: `WorkTimer/SettingsView.swift`, `WorkTimer/SettingsComponents.swift`, `WorkTimer/PaywallView.swift`

- [ ] **Step 1:** harmoniser tous les appels `dsGlassSurface` sur la nouvelle signature ; fond `dsScreenBackground(.gray)` sur Réglages ; Paywall : uniquement adapter les appels cassés, pas de redesign.
- [ ] **Step 2:** build + screenshot + commit.

---

### Task 9: Vérification finale

- [ ] **Step 1:** `test_sim` — tous les tests existants passent.
- [ ] **Step 2:** captures de chaque onglet (clair) pour validation visuelle par Jordan.
- [ ] **Step 3:** vérifier `reduceTransparency`/`reduceMotion` (le fallback opaque de `dsGlassSurface` couvre le premier).
- [ ] **Step 4:** commit final éventuel + résumé.
