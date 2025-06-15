import SwiftUI

struct StandardCardView<Content: View>: View {
    let content: Content

    // Style parameters with default values
    var paddingAmount: CGFloat = 16
    var cornerRadiusAmount: CGFloat = 15
    var backgroundColor: Color = Color(.systemBackground) // Adapts to light/dark mode
    var shadowColor: Color = Color.black.opacity(0.05)
    var shadowRadius: CGFloat = 5
    var shadowX: CGFloat = 0
    var shadowY: CGFloat = 2

    init(
        paddingAmount: CGFloat = 16,
        cornerRadiusAmount: CGFloat = 15,
        backgroundColor: Color = Color(.systemBackground),
        shadowColor: Color = Color.black.opacity(0.05),
        shadowRadius: CGFloat = 5,
        shadowX: CGFloat = 0,
        shadowY: CGFloat = 2,
        @ViewBuilder content: () -> Content
    ) {
        self.paddingAmount = paddingAmount
        self.cornerRadiusAmount = cornerRadiusAmount
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowX = shadowX
        self.shadowY = shadowY
        self.content = content()
    }

    var body: some View {
        content
            .padding(paddingAmount)
            .background(backgroundColor)
            .cornerRadius(cornerRadiusAmount)
            .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
    }
}

// Optional: Preview for StandardCardView
#if DEBUG
struct StandardCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StandardCardView {
                Text("This is a standard card with default styling.")
            }
            .padding()
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Default Card")

            StandardCardView(
                paddingAmount: 20,
                cornerRadiusAmount: 10,
                backgroundColor: Color(.secondarySystemGroupedBackground),
                shadowColor: Color.blue.opacity(0.3),
                shadowRadius: 10
            ) {
                VStack {
                    Text("Customized Card")
                    Image(systemName: "star.fill")
                }
            }
            .padding()
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Customized Card")

            StandardCardView {
                Text("Dark Mode Card")
            }
            .padding()
            .background(Color.black) // Simulate dark mode background for preview
            .environment(\.colorScheme, .dark)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Dark Mode Card")
        }
    }
}
#endif
