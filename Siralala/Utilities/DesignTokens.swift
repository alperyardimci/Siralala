import SwiftUI

// MARK: - Design Tokens

extension Color {
    /// Warm white background — #FBF8F3
    static let dsBg = Color(red: 251/255, green: 248/255, blue: 243/255)
    /// Pure white surface — #FFFFFF
    static let dsSurface = Color.white
    /// Dim surface — #F4EFE7
    static let dsSurfaceDim = Color(red: 244/255, green: 239/255, blue: 231/255)
    /// Espresso text — #1A1613
    static let dsDeep = Color(red: 26/255, green: 22/255, blue: 19/255)
    /// Muted text — rgba(26,22,19,0.55)
    static let dsMuted = Color(red: 26/255, green: 22/255, blue: 19/255).opacity(0.55)
    /// Ultra muted — rgba(26,22,19,0.35)
    static let dsUltraMuted = Color(red: 26/255, green: 22/255, blue: 19/255).opacity(0.35)
    /// Hairline — rgba(26,22,19,0.08)
    static let dsHairline = Color(red: 26/255, green: 22/255, blue: 19/255).opacity(0.08)
    /// Coral orange accent — #E8824A
    static let dsAccent = Color(red: 232/255, green: 130/255, blue: 74/255)
    /// Accent soft — #FBE9DA
    static let dsAccentSoft = Color(red: 251/255, green: 233/255, blue: 218/255)
    /// Ink blue secondary — #4A5FB8
    static let dsInk = Color(red: 74/255, green: 95/255, blue: 184/255)
    /// Ink soft — #E4E7F5
    static let dsInkSoft = Color(red: 228/255, green: 231/255, blue: 245/255)
}

// MARK: - Sıralala Mark (3 ascending bars)

struct SiralalaMarkView: View {
    var size: CGFloat = 22
    var color: Color = .dsDeep

    var body: some View {
        HStack(spacing: size * 0.1) {
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(color)
                .frame(width: size * 0.21, height: size * 0.33)
                .frame(height: size, alignment: .bottom)
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(color)
                .frame(width: size * 0.21, height: size * 0.54)
                .frame(height: size, alignment: .bottom)
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(color)
                .frame(width: size * 0.21, height: size * 0.75)
                .frame(height: size, alignment: .bottom)
        }
    }
}

// MARK: - RankChip (reusable numbered circle)

struct RankChip: View {
    let number: Int
    var style: RankChipStyle = .standard

    enum RankChipStyle {
        case standard   // dsDeep bg, white text
        case accent     // dsAccent bg, white text
        case soft       // dsSurfaceDim bg, dsDeep text
    }

    private var bgColor: Color {
        switch style {
        case .standard: return .dsDeep
        case .accent: return .dsAccent
        case .soft: return .dsSurfaceDim
        }
    }

    private var fgColor: Color {
        switch style {
        case .standard, .accent: return .white
        case .soft: return .dsDeep
        }
    }

    var body: some View {
        Text("\(number)")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(fgColor)
            .frame(width: 28, height: 28)
            .background(Circle().fill(bgColor))
    }
}

// MARK: - Wordmark header

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var buttonLabel: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)

            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.dsUltraMuted)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.dsSurfaceDim))
                .padding(.bottom, 20)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.dsDeep)
                .padding(.bottom, 6)

            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(Color.dsMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)

            if let buttonLabel, let onAction {
                Button {
                    onAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text(buttonLabel)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.dsDeep))
                }
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

struct SiralalaWordmark: View {
    var body: some View {
        HStack(spacing: 6) {
            SiralalaMarkView(size: 18)
            Text("SIRALALA")
                .font(.system(size: 13, weight: .bold, design: .default))
                .tracking(2)
                .foregroundStyle(Color.dsDeep)
        }
    }
}
