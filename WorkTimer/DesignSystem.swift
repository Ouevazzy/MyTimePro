import SwiftUI

// MARK: - Design System
// Constantes centralisées pour garantir la cohérence visuelle de l'app.
// Toute nouvelle vue doit utiliser ces valeurs au lieu de hardcoder.

enum DS {

    // MARK: - Corner Radius
    enum Radius {
        /// Petits éléments : badges, tags, barres de progression (6pt)
        static let small: CGFloat = 8
        /// Éléments moyens : boutons, champs, cellules de liste (12pt)
        static let medium: CGFloat = 12
        /// Cartes et sections (16pt)
        static let card: CGFloat = 16
        /// Grands conteneurs, sheets, modales (20pt)
        static let large: CGFloat = 20
    }

    // MARK: - Spacing
    enum Spacing {
        /// Micro-espace entre éléments très proches (4pt)
        static let xs: CGFloat = 4
        /// Petit espace : entre label et valeur (8pt)
        static let sm: CGFloat = 8
        /// Espace standard : entre éléments dans une carte (12pt)
        static let md: CGFloat = 12
        /// Espace de section : entre groupes d'éléments (16pt)
        static let lg: CGFloat = 16
        /// Grand espace : entre cartes/sections principales (20pt)
        static let xl: CGFloat = 20
    }

    // MARK: - Shadows
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        /// Ombre subtile pour les éléments secondaires (boutons, badges)
        static func subtle(_ colorScheme: ColorScheme) -> Shadow {
            Shadow(
                color: .black.opacity(colorScheme == .dark ? 0.15 : 0.06),
                radius: 4, x: 0, y: 2
            )
        }

        /// Ombre standard pour les cartes
        static func card(_ colorScheme: ColorScheme) -> Shadow {
            Shadow(
                color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08),
                radius: 8, x: 0, y: 4
            )
        }

        /// Ombre forte pour les éléments flottants (modales, popovers)
        static func elevated(_ colorScheme: ColorScheme) -> Shadow {
            Shadow(
                color: .black.opacity(colorScheme == .dark ? 0.3 : 0.12),
                radius: 12, x: 0, y: 6
            )
        }
    }

    // MARK: - Colors
    enum Colors {
        // Couleurs sémantiques par fonctionnalité
        static let work = Color.blue
        static let vacation = Color.orange
        static let sickLeave = Color.red
        static let holiday = Color.purple
        static let training = Color.teal
        static let compensatory = Color.pink
        static let halfDayVacation = Color.mint

        // Couleurs d'état
        static let positive = Color.green
        static let negative = Color.red
        static let neutral = Color.secondary

        // Opacités standardisées pour les backgrounds
        static let backgroundOpacity: Double = 0.12
        static let hoverOpacity: Double = 0.08
        static let borderOpacity: Double = 0.15
    }

    // MARK: - Animations
    // Spring sans durée fixe : SwiftUI utilise le taux de rafraîchissement natif
    // de l'écran (jusqu'à 120Hz sur ProMotion) pour interpoler chaque frame.
    enum Animation {
        /// Micro-interactions : sélection, toggle, tap feedback
        static let micro = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.82)
        /// Interactions standard : boutons, transitions courtes
        static let interactive = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.75)
        /// Ouverture/fermeture de cartes et sections
        static let cardToggle = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        /// Apparition d'éléments (fade in + scale)
        static let appear = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.72)
        /// Navigation (changement de mois/année/écran)
        static let navigation = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        /// Animations de données (barres de progression, compteurs)
        static let progress = SwiftUI.Animation.spring(response: 0.7, dampingFraction: 0.72)
    }

    // MARK: - Touch Targets
    enum Touch {
        /// Taille minimale Apple HIG pour les cibles tactiles
        static let minSize: CGFloat = 44
    }

    // MARK: - Icon Sizes
    enum IconSize {
        /// Icônes inline dans les section headers (30pt)
        static let sectionHeader: CGFloat = 30
        /// Icônes inline : stat cards, badges (32pt)
        static let inline: CGFloat = 32
        /// Icônes dans les composants Settings (36pt)
        static let settings: CGFloat = 36
        /// Icônes de navigation, boutons d'action (44pt)
        static let navigation: CGFloat = 44
        /// Grandes icônes : empty states, illustrations (100pt)
        static let illustration: CGFloat = 100
    }

    // MARK: - Icon Corner Radius
    enum IconRadius {
        /// Section headers (7pt)
        static let sectionHeader: CGFloat = 7
        /// Stat cards, inline icons (8pt)
        static let inline: CGFloat = 8
        /// Settings cards (10pt)
        static let settings: CGFloat = 10
    }

    // MARK: - Font
    enum Font {
        /// Grands chiffres / statistiques (40pt)
        static let statDisplay: CGFloat = 40
        /// Icônes illustratives (42pt)
        static let iconLarge: CGFloat = 42
        /// Taille d'icône dans les section headers (14pt)
        static let iconSmall: CGFloat = 14
        /// Sous-titres dans les cartes (18pt)
        static let cardSubtitle: CGFloat = 18
    }

    // MARK: - Backgrounds
    enum Background {
        /// Opacité pour les fonds de cartes colorées
        static let tintedCard: Double = 0.05
        /// Opacité pour les fonds de sections
        static let tintedSection: Double = 0.1
        /// Opacité pour les bordures subtiles
        static let tintedBorder: Double = 0.3
    }

    // MARK: - Surfaces
    enum Glass {
        /// Intensité de la teinte sémantique appliquée au verre.
        static let tintStrength: Double = 0.35
        /// Distance de fusion entre plusieurs surfaces Liquid Glass proches.
        static let groupSpacing: CGFloat = 20
    }
}

// MARK: - View Modifier : Ombre standardisée
extension View {
    func dsShadow(_ shadow: DS.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Couche 2 de la hiérarchie de profondeur : carte de contenu en verre natif.
    /// `tint` applique une teinte sémantique (type de jour, état) au verre.
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

    /// Couche 1 de la hiérarchie de profondeur : fond d'écran dégradé subtil.
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
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea()
        }
    }

    func dsGlassEffectGroup(spacing: CGFloat? = DS.Glass.groupSpacing) -> some View {
        DSGlassEffectGroup(spacing: spacing) {
            self
        }
    }
}

struct DSGlassEffectGroup<Content: View>: View {
    let spacing: CGFloat?
    let content: Content

    init(spacing: CGFloat? = DS.Glass.groupSpacing, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
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
        var glass: Glass = .regular
        if let tint {
            glass = glass.tint(tint.opacity(DS.Glass.tintStrength))
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
}
