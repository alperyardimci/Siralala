import SwiftUI

struct RankingSlotView: View {
    let rank: Int
    let item: PoolItem?
    let isHighlighted: Bool
    let isOccupied: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(isOccupied ? .white : .orange)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isOccupied ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Color.orange.opacity(0.15)))
                )

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
                        .lineLimit(1)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isHighlighted ? .orange : .gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1, dash: [6])
                    )
                    .frame(height: 32)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isHighlighted ? .orange.opacity(0.15) :
                    isOccupied ? .green.opacity(0.08) :
                    Color(.secondarySystemGroupedBackground)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHighlighted ? .orange : .clear,
                    lineWidth: 2
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .animation(.spring(response: 0.35), value: isOccupied)
    }
}
