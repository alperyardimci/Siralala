import SwiftUI
import SwiftData

struct CreateQuestionView: View {
    let pool: Pool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var questionText: String = ""
    @State private var itemCount: Int = 10
    @State private var maxAttempts: Int = 1
    @State private var groups: [APIGroup] = []
    @State private var selectedGroupIds: Set<String> = []
    @State private var isSharing = false
    @State private var errorMessage: String?
    @State private var showCreateGroup = false
    @State private var isLoadingGroups = true
    @FocusState private var isFocused: Bool

    private var maxItems: Int { pool.itemCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Label
                    Text("YENI SORU \u{00B7} \(pool.name.uppercased())")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.dsMuted)
                        .padding(.top, 24)

                    // Hero
                    Text("Grubuna ne sormak\nistiyorsun?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.dsDeep)
                        .padding(.top, 8)

                    // Large input with bottom border
                    VStack(spacing: 0) {
                        TextField("Örn: En iyi futbolcu hangisi?", text: $questionText, axis: .vertical)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.dsDeep)
                            .padding(.vertical, 14)
                            .focused($isFocused)
                            .lineLimit(3...6)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Bitti") { isFocused = false }
                                        .fontWeight(.semibold)
                                }
                            }

                        Rectangle()
                            .fill(Color.dsDeep)
                            .frame(height: 2)
                    }
                    .padding(.top, 24)

                    // Item count section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KAÇ ÖĞE SIRALANSIN")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.dsMuted)

                        Text("Havuzda \(maxItems) öğe var")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsUltraMuted)

                        HStack(spacing: 24) {
                            Button {
                                if itemCount > 3 { itemCount -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(itemCount > 3 ? Color.dsDeep : Color.dsUltraMuted)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.dsSurfaceDim))
                            }
                            .disabled(itemCount <= 3)

                            Text("\(itemCount)")
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.dsDeep)
                                .frame(width: 60)
                                .multilineTextAlignment(.center)

                            Button {
                                if itemCount < maxItems { itemCount += 1 }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(itemCount < maxItems ? Color.dsDeep : Color.dsUltraMuted)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.dsSurfaceDim))
                            }
                            .disabled(itemCount >= maxItems)
                        }
                    }
                    .padding(.top, 28)

                    // Max attempts section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KAÇ KEZ YANITLANABİLİR")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.dsMuted)

                        Text("Her kullanıcı bu soruyu kaç kez sıralayabilir")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsUltraMuted)

                        HStack(spacing: 24) {
                            Button {
                                if maxAttempts > 1 { maxAttempts -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(maxAttempts > 1 ? Color.dsDeep : Color.dsUltraMuted)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.dsSurfaceDim))
                            }
                            .disabled(maxAttempts <= 1)

                            Text("\(maxAttempts)")
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.dsDeep)
                                .frame(width: 60)
                                .multilineTextAlignment(.center)

                            Button {
                                if maxAttempts < 10 { maxAttempts += 1 }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(maxAttempts < 10 ? Color.dsDeep : Color.dsUltraMuted)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.dsSurfaceDim))
                            }
                            .disabled(maxAttempts >= 10)
                        }
                    }
                    .padding(.top, 28)

                    // Group picker section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GÖNDERİLECEK GRUPLAR")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.dsMuted)

                        if isLoadingGroups {
                            ProgressView()
                                .padding(.vertical, 10)
                        } else if groups.isEmpty {
                            VStack(spacing: 10) {
                                Text("Soruyu paylaşmak için bir grubun olmalı")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.dsMuted)
                                Button {
                                    showCreateGroup = true
                                } label: {
                                    Text("Grup Oluştur")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.dsDeep, in: Capsule())
                                }
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(groups) { group in
                                        let isSelected = selectedGroupIds.contains(group.id.value)
                                        Button {
                                            if isSelected {
                                                selectedGroupIds.remove(group.id.value)
                                            } else {
                                                selectedGroupIds.insert(group.id.value)
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .bold))
                                                }
                                                Text(group.name)
                                                    .font(.system(size: 14, weight: .medium))
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule().fill(isSelected ? Color.dsDeep : Color.dsSurface)
                                            )
                                            .overlay(
                                                Capsule().strokeBorder(
                                                    isSelected ? Color.clear : Color.dsHairline,
                                                    lineWidth: 1
                                                )
                                            )
                                            .foregroundStyle(isSelected ? .white : Color.dsDeep)
                                        }
                                    }
                                }
                            }

                            if selectedGroupIds.count > 1 {
                                Text("\(selectedGroupIds.count) gruba gönderilecek")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.dsAccent)
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

                    Spacer().frame(height: 32)

                    // Bottom button
                    Button {
                        Task { await shareQuestion() }
                    } label: {
                        if isSharing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Soruyu gönder")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsAccent))
                    .foregroundStyle(.white)
                    .disabled(questionText.trimmingCharacters(in: .whitespaces).isEmpty || selectedGroupIds.isEmpty || isSharing)
                    .opacity((questionText.trimmingCharacters(in: .whitespaces).isEmpty || selectedGroupIds.isEmpty) ? 0.4 : 1)

                    Spacer().frame(height: 24)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Color.dsBg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(Color.dsDeep)
                }
            }
            .onAppear {
                itemCount = min(10, maxItems)
                isFocused = true
            }
            .task {
                groups = (try? await APIService.shared.getGroups()) ?? []
                isLoadingGroups = false
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView {
                    Task { groups = (try? await APIService.shared.getGroups()) ?? [] }
                }
            }
        }
    }

    private func shareQuestion() async {
        guard !selectedGroupIds.isEmpty else { return }
        isSharing = true
        errorMessage = nil

        let shareItems = (pool.items ?? []).map { item in
            ShareQuestionItem(
                name: item.name,
                imageData: item.imageData?.base64EncodedString()
            )
        }

        var failedGroups: [String] = []
        for groupId in selectedGroupIds {
            do {
                try await APIService.shared.shareQuestion(
                    groupId: groupId,
                    text: questionText.trimmingCharacters(in: .whitespaces),
                    poolName: pool.name,
                    items: shareItems,
                    itemCount: itemCount,
                    maxAttempts: maxAttempts
                )
            } catch {
                let name = groups.first(where: { $0.id.value == groupId })?.name ?? groupId
                failedGroups.append(name)
            }
        }

        if failedGroups.isEmpty {
            NotificationCenter.default.post(name: .feedNeedsRefresh, object: nil)
            dismiss()
        } else {
            errorMessage = "Gönderilemedi: \(failedGroups.joined(separator: ", "))"
        }

        isSharing = false
    }
}
