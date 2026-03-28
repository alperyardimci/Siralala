import SwiftUI

struct ItemRevealCard: View {
    let item: PoolItem
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 12) {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.orange.gradient)
                        .frame(width: 100, height: 100)
                    Text(item.name.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(item.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(20)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(
                    color: isDragging ? .orange.opacity(0.3) : .black.opacity(0.1),
                    radius: isDragging ? 16 : 8,
                    y: isDragging ? 8 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.orange.opacity(isDragging ? 0.5 : 0), lineWidth: 2)
        )
    }
}
