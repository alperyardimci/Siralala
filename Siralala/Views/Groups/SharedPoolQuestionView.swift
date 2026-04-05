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
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Pool info
                        VStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.purple.gradient)
                            Text(pool.name)
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(pool.creatorName) tarafından · \(items.count) öğe")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)

                        // Items preview
                        VStack(spacing: 6) {
                            ForEach(items) { item in
                                HStack(spacing: 10) {
                                    if let img = item.uiImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.purple.opacity(0.12))
                                                .frame(width: 32, height: 32)
                                            Text(item.name.prefix(1).uppercased())
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.purple)
                                        }
                                    }
                                    Text(item.name)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)

                        Divider().padding(.horizontal, 32)

                        // Question creation
                        VStack(spacing: 16) {
                            Text("Soru Oluştur")
                                .font(.headline)

                            TextField("Örn: En iyi futbolcu hangisi?", text: $questionText)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal, 32)
                                .focused($isFocused)

                            VStack(spacing: 8) {
                                Text("Kaç öğe sıralansın?")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 20) {
                                    Button {
                                        if itemCount > 3 { itemCount -= 1 }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(itemCount > 3 ? .purple : .gray)
                                    }
                                    .disabled(itemCount <= 3)

                                    Text("\(itemCount)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .monospacedDigit()
                                        .frame(width: 50)

                                    Button {
                                        if itemCount < items.count { itemCount += 1 }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(itemCount < items.count ? .purple : .gray)
                                    }
                                    .disabled(itemCount >= items.count)
                                }
                            }

                            Button {
                                Task { await shareQuestion() }
                            } label: {
                                if isSharing {
                                    ProgressView().frame(maxWidth: .infinity).padding()
                                } else {
                                    Text("Soruyu Gruba Gönder")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                            .background(.purple.gradient, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                            .disabled(questionText.trimmingCharacters(in: .whitespaces).isEmpty || isSharing)
                            .padding(.horizontal, 32)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Havuzdan Soru")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            items = (try? await APIService.shared.getPoolItems(poolId: pool.id)) ?? []
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
                groupId: group.id,
                text: questionText.trimmingCharacters(in: .whitespaces),
                poolName: pool.name,
                items: shareItems,
                itemCount: itemCount
            )
            dismiss()
        } catch {
            errorMessage = "Paylaşılamadı: \(error.localizedDescription)"
        }
        isSharing = false
    }
}
