import SwiftUI
import UIKit

// MARK: - Haptic Feedback Extensions
extension View {
    /// Ajoute un retour haptique lors d'un tap
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        )
    }
    
    /// Modifieur pour ajouter un tap avec retour haptique
    func hapticOnTap(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
            action()
        }) {
            self
        }
        .buttonStyle(.plain)
    }
    
    /// Déclenche un retour haptique de notification
    func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Haptic Helper
struct Haptic {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Animated Button
struct AnimatedButton<Content: View>: View {
    let action: () -> Void
    let content: () -> Content
    @State private var isPressed = false
    
    init(action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        content()
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .onTapGesture {
                isPressed = true
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    isPressed = false
                    action()
                }
            }
    }
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Content Surface Card
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.large))
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var iconColors: [Color] = [.blue, .purple]
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Fond arrondi avec gradient
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [iconColors[0].opacity(0.15), iconColors[1].opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DS.IconSize.illustration, height: DS.IconSize.illustration)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.spring(response: 1.8, dampingFraction: 0.5).repeatForever(autoreverses: true), value: isAnimating)

                Image(systemName: icon)
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: isAnimating)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if let actionTitle, let action {
                Button(action: {
                    action()
                }) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: iconColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: iconColors[0].opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation {
                isAnimating = true
            }
        }
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Bounce Animation
extension View {
    func bounceOnAppear(delay: Double = 0) -> some View {
        self.modifier(BounceOnAppearModifier(delay: delay))
    }
}

struct BounceOnAppearModifier: ViewModifier {
    let delay: Double
    @State private var animate = false
    
    func body(content: Content) -> some View {
        content
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
            .scaleEffect(animate ? 1 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: animate)
            .onAppear {
                animate = true
            }
    }
}

// MARK: - Slide Transition
extension AnyTransition {
    static var slideFromBottom: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    static var slideFromTop: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }
}

// MARK: - Conditional Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview
#Preview("Empty State") {
    EmptyStateView(
        icon: "calendar.badge.plus",
        title: "Aucune journée",
        subtitle: "Commencez par ajouter votre première journée de travail",
        actionTitle: "Ajouter une journée",
        action: { print("Tapped") }
    )
}

#Preview("Content Surface Card") {
    VStack(spacing: 20) {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Année 2025")
                        .font(.headline)
                }
                Divider()
                Text("Exemple de contenu")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}














