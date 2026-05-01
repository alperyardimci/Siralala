import SwiftUI

struct SharedPoolQuestionView: View {
    let pool: APISharedPool
    let group: APIGroup
    @Environment(\.dismiss) private var dismiss
    @State private var items: [APIQuestionItem] = []
    @State private var questionText: String = ""
    @State private var itemCount: Int = 10
    @State private var isSharing = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.top, 100)
                    } else {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YENİ SORU · \(pool.name.uppercased())")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(Color.dsMuted)

                            Text("Grubuna ne sormak\nistiyorsun?")
                                .font(.system(size: 30, weight: .bold))
                                .tracking(-0.8)
                                .foregroundStyle(Color.dsDeep)
                                .lineSpacing(2)
                        }
                        .padding(.top, 8)

                        // Question input
                        TextField("Örn: En iyi futbolcu hangisi?", text: $questionText, axis: .vertical)
                            .font(.system(size: 22, weight: .medium))
                            .tracking(-0.3)
                            .foregroundStyle(Color.dsDeep)
                            .lineLimit(3...6)
                            .focused($isFocused)
                            .padding(.vertical, 10)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Bitti") { isFocused = false }
                                        .fontWeight(.semibold)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.dsDeep).frame(height: 2)
                            }
                            .padding(.top, 28)

                        // Item count
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KAÇ ÖĞE SIRALANSIN")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(Color.dsMuted)
                            Text("Havuzda \(items.count) öğe var")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dsMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .trailing) {
                            HStack(spacing: 14) {
                                Button {
                                    if itemCount > 3 { itemCount -= 1 }
                                } label: {
                                    Circle()
                                        .strokeBorder(Color.dsHairline, lineWidth: 1.5)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Rectangle().fill(Color.dsDeep).frame(width: 12, height: 2)
                                                .clipShape(RoundedRectangle(cornerRadius: 1))
                                        )
                                }
                                .disabled(itemCount <= 3)
                                .opacity(itemCount <= 3 ? 0.3 : 1)

                                Text("\(itemCount)")
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.dsDeep)
                                    .frame(width: 45, alignment: .center)

                                Button {
                                    if itemCount < items.count { itemCount += 1 }
                                } label: {
                                    Circle()
                                        .fill(Color.dsDeep)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        )
                                }
                                .disabled(itemCount >= items.count)
                                .opacity(itemCount >= items.count ? 0.3 : 1)
                            }
                        }
                        .padding(.top, 28)

                        // Items preview
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ÖĞELER")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(Color.dsMuted)
                                .padding(.bottom, 10)

                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 14) {
                                    if let img = item.uiImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.dsSurfaceDim)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Text(item.name.prefix(1).uppercased())
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(Color.dsDeep)
                                            )
                                    }
                                    Text(item.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.dsDeep)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .overlay(alignment: .bottom) {
                                    if index < items.count - 1 {
                                        Rectangle().fill(Color.dsHairline).frame(height: 1)
                                    }
                                }
                            }
                        }
                        .padding(.top, 28)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.top, 12)
                        }

                        Spacer().frame(height: 100)
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }

            // Bottom button
            if !isLoading {
                Button {
                    Task { await shareQuestion() }
                } label: {
                    if isSharing {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Soruyu gönder")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(questionText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.dsDeep.opacity(0.3) : Color.dsAccent)
                )
                .disabled(questionText.trimmingCharacters(in: .whitespaces).isEmpty || isSharing)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color.dsBg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            items = (try? await APIService.shared.getPoolItems(poolId: pool.id.value)) ?? []
            itemCount = min(10, items.count)
            isLoading = false
            isFocused = true
        }
    }

    private func shareQuestion() async {
        isSharing = true
        errorMessage = nil

        let shareItems = items.map { item in
            ShareQuestionItem(name: item.name, imageData: item.imageData)
        }

        do {
            try await APIService.shared.shareQuestion(
                groupId: group.id.value,
                text: questionText.trimmingCharacters(in: .whitespaces),
                poolName: pool.name,
                items: shareItems,
                itemCount: itemCount
            )
            NotificationCenter.default.post(name: .feedNeedsRefresh, object: nil)
            dismiss()
        } catch {
            errorMessage = "Paylaşılamadı: \(error.localizedDescription)"
        }
        isSharing = false
    }
}
