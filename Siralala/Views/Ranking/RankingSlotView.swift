import SwiftUI

struct RankingSlotView: View {
    let rank: Int
    let item: PoolItem?
    let isHighlighted: Bool
    let isOccupied: Bool

    var body: some View {
        HStack(spacing: 12) {
            RankChip(number: rank, style: isOccupied ? .accent : .soft)

            if let item = item {
                HStack(spacing: 8) {
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.dsDeep)
                        .lineLimit(1)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                if isHighlighted {
                    Text("BURAYA BIRAK")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.dsAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 32)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsUltraMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 32)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isHighlighted ? Color.dsAccentSoft :
                    Color.dsSurface
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHighlighted ? Color.dsAccent : Color.dsHairline,
                    style: isHighlighted ? StrokeStyle(lineWidth: 2, dash: [6]) : StrokeStyle(lineWidth: 1),
                    antialiased: true
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .animation(.spring(response: 0.35), value: isOccupied)
    }
}
