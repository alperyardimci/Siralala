import SwiftUI
import SwiftData

struct CreateQuestionView: View {
    let pool: Pool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var questionText: String = ""
    @State private var itemCount: Int = 10
    @State private var groups: [APIGroup] = []
    @State private var selectedGroupId: Int?
    @State private var isSharing = false
    @State private var errorMessage: String?
    @State private var showCreateGroup = false
    @FocusState private var isFocused: Bool

    private var maxItems: Int { pool.itemCount }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange.gradient)

                VStack(spacing: 8) {
                    Text("Soruyu Yaz")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Havuz: \(pool.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

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
                                .foregroundStyle(itemCount > 3 ? .orange : .gray)
                        }
                        .disabled(itemCount <= 3)

                        Text("\(itemCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .frame(width: 50)

                        Button {
                            if itemCount < maxItems { itemCount += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(itemCount < maxItems ? .orange : .gray)
                        }
                        .disabled(itemCount >= maxItems)
                    }
                }

                // Group picker
                VStack(spacing: 8) {
                    Text("Hangi gruba gönderilsin?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if groups.isEmpty {
                        VStack(spacing: 10) {
                            Text("Soruyu paylaşmak için bir grubun olmalı")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                showCreateGroup = true
                            } label: {
                                Label("Grup Oluştur", systemImage: "person.3.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(.orange.gradient, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(groups) { group in
                                    Button {
                                        selectedGroupId = group.id
                                    } label: {
                                        Text(group.name)
                                            .font(.subheadline)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule().fill(selectedGroupId == group.id ? .orange : .gray.opacity(0.15))
                                            )
                                            .foregroundStyle(selectedGroupId == group.id ? .white : .primary)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                        }
                    }
                }

                Button {
                    Task { await shareQuestion() }
                } label: {
                    if isSharing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Soruyu Paylaş")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .disabled(questionText.trimmingCharacters(in: .whitespaces).isEmpty || selectedGroupId == nil || isSharing)
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .navigationTitle("Yeni Soru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
            .onAppear {
                itemCount = min(10, maxItems)
                isFocused = true
            }
            .task {
                groups = (try? await APIService.shared.getGroups()) ?? []
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView {
                    Task { groups = (try? await APIService.shared.getGroups()) ?? [] }
                }
            }
        }
    }

    private func shareQuestion() async {
        guard let groupId = selectedGroupId else { return }
        isSharing = true
        errorMessage = nil

        let shareItems = (pool.items ?? []).map { item in
            ShareQuestionItem(
                name: item.name,
                imageData: item.imageData?.base64EncodedString()
            )
        }

        do {
            try await APIService.shared.shareQuestion(
                groupId: groupId,
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
