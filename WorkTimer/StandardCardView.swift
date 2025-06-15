import SwiftUI

struct StandardCardView<Content: View>: View {
    let content: Content

    // Style parameters with default values
    var paddingAmount: CGFloat = 16
    var cornerRadiusAmount: CGFloat = 15
    var backgroundColor: Color = Color(.systemBackground) // Adapts to light/dark mode
    var shadowColor: Color = Color.black.opacity(0.08) // Default shadow opacity adjusted
    var shadowRadius: CGFloat = 8 // Default shadow radius adjusted
    var shadowX: CGFloat = 0
    var shadowY: CGFloat = 2
    let backgroundMaterial: Material? // New property for material background
    let strokeColor: Color? // New property for stroke color
    let strokeWidth: CGFloat // New property for stroke width

    init(
        paddingAmount: CGFloat = 16,
        cornerRadiusAmount: CGFloat = 15,
        backgroundColor: Color = Color(.systemBackground),
        shadowColor: Color = Color.black.opacity(0.08), // Adjusted default
        shadowRadius: CGFloat = 8, // Adjusted default
        shadowX: CGFloat = 0,
        shadowY: CGFloat = 2,
        backgroundMaterial: Material? = nil, // New parameter
        strokeColor: Color? = nil, // New parameter
        strokeWidth: CGFloat = 1, // New parameter
        @ViewBuilder content: () -> Content
    ) {
        self.paddingAmount = paddingAmount
        self.cornerRadiusAmount = cornerRadiusAmount
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowX = shadowX
        self.shadowY = shadowY
        self.backgroundMaterial = backgroundMaterial
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.content = content()
    }

    var body: some View {
        content
            .padding(paddingAmount)
            .background {
                if let material = backgroundMaterial {
                    RoundedRectangle(cornerRadius: cornerRadiusAmount)
                        .fill(material)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadiusAmount)
                        .fill(backgroundColor)
                }
            }
            .overlay {
                if let strokeColor = strokeColor {
                    RoundedRectangle(cornerRadius: cornerRadiusAmount)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                }
            }
            .cornerRadius(cornerRadiusAmount) // This clips the content to the rounded rectangle
            .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
    }
}

// Optional: Preview for StandardCardView
#if DEBUG
struct StandardCardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView { // Added ScrollView to see different card types better
            VStack(spacing: 20) {
                StandardCardView {
                    Text("This is a standard card with new default styling.")
                }
                .previewDisplayName("Default Card")

                StandardCardView(
                    paddingAmount: 20,
                    cornerRadiusAmount: 10,
                    backgroundColor: Color.orange.opacity(0.2),
                    shadowColor: Color.orange.opacity(0.5),
                    shadowRadius: 5,
                    strokeColor: Color.orange,
                    strokeWidth: 2
                ) {
                    VStack {
                        Text("Customized Card with Stroke")
                        Image(systemName: "star.fill")
                    }
                }
                .previewDisplayName("Customized Card with Stroke")

                StandardCardView(
                    backgroundMaterial: .ultraThinMaterial
                ) {
                    Text("Card with Ultra Thin Material")
                        .padding(.vertical, 20) // Add padding to see material effect
                }
                .previewDisplayName("Ultra Thin Material Card")

                StandardCardView(
                    backgroundMaterial: .thickMaterial,
                    strokeColor: .gray.opacity(0.5)
                ) {
                    Text("Card with Thick Material & Stroke")
                        .padding(.vertical, 20)
                }
                .previewDisplayName("Thick Material Card with Stroke")

                StandardCardView {
                    Text("Dark Mode Default Card")
                }
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode Default Card")

                StandardCardView(
                    backgroundMaterial: .regularMaterial,
                    strokeColor: Color.white.opacity(0.7)
                ) {
                    Text("Dark Mode Material Card")
                        .padding(.vertical, 20)
                }
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode Material Card")

            }
            .padding() // Padding for the VStack containing all cards
            .background(Color.gray.opacity(0.1)) // Background for the ScrollView content
        }
        .previewLayout(.sizeThatFits) // Adjust layout to fit content or a reasonable size
    }
}
#endif
