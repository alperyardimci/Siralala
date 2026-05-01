import SwiftUI
import SwiftData

struct PoolDetailView: View {
    let pool: Pool
    @Environment(\.modelContext) private var context
    @State private var viewModel = PoolViewModel()
    @State private var showCreateQuestion = false
    @State private var showSharePool = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("HAVUZ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.top, 8)

                Text(pool.name)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.dsDeep)
                    .padding(.top, 4)

                Text("\(pool.itemCount) öğe · Grupla paylaşmak için hazır")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.top, 4)

                // Two side-by-side buttons
                if pool.itemCount < 3 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                        Text("Soru oluşturmak için en az 3 öğe ekle.")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(Color.dsAccent)
                    .padding(.top, 16)
                }

                if pool.itemCount >= 3 {
                    HStack(spacing: 12) {
                        Button {
                            showCreateQuestion = true
                        } label: {
                            Text("Soru oluştur")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsDeep))
                        }

                        Button {
                            showSharePool = true
                        } label: {
                            Text("Gruba paylaş")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.dsDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.dsSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.dsHairline, lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.top, 20)
                }

                // Items section
                HStack {
                    Text("ÖĞELER")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.dsMuted)
                    Spacer()
                    Text("\(pool.itemCount)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dsMuted)
                }
                .padding(.top, 28)

                // Add item row (dashed border card)
                AddItemRow(viewModel: viewModel, pool: pool)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundStyle(Color.dsHairline)
                    )
                    .padding(.top, 12)

                // Item rows
                VStack(spacing: 0) {
                    ForEach(Array((pool.items ?? []).enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 14) {
                            // Avatar
                            if let data = item.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.dsSurfaceDim)
                                        .frame(width: 40, height: 40)
                                    Text(item.name.prefix(1).uppercased())
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.dsDeep)
                                }
                            }

                            Text(item.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.dsDeep)

                            Spacer()
                        }
                        .padding(.vertical, 12)

                        if index < (pool.items ?? []).count - 1 {
                            Divider().background(Color.dsHairline)
                        }
                    }
                }
                .padding(.top, 8)

                // Delete pool button
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("Havuzu Sil")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.red.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .padding(.top, 32)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dsBg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateQuestion) {
            CreateQuestionView(pool: pool)
        }
        .sheet(isPresented: $showSharePool) {
            SharePoolSheet(pool: pool)
        }
        .alert("Havuzu silmek istediğine emin misin?", isPresented: $showDeleteConfirm) {
            Button("Sil", role: .destructive) {
                viewModel.deletePool(pool, context: context)
                dismiss()
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Bu işlem geri alınamaz. Havuzdaki tüm öğeler silinecek.")
        }
    }
}

struct SharePoolSheet: View {
    let pool: Pool
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [APIGroup] = []
    @State private var selectedGroupIds: Set<String> = []
    @State private var isSharing = false
    @State private var showCreateGroup = false
    @State private var errorMessage: String?
    @State private var isLoadingGroups = true
    @State private var groupLoadError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                SiralalaMarkView(size: 50, color: .dsInk)

                VStack(spacing: 8) {
                    Text("Havuzu Paylaş")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.dsDeep)
                    Text("\(pool.name) · \(pool.itemCount) öğe")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                }

                VStack(spacing: 8) {
                    Text("Hangi gruplara paylaşılsın?")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)

                    if isLoadingGroups {
                        ProgressView()
                            .padding(.vertical, 10)
                    } else if groupLoadError {
                        VStack(spacing: 10) {
                            Text("Gruplar yüklenemedi")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Button {
                                Task { await loadGroups() }
                            } label: {
                                Label("Tekrar Dene", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.dsInk, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    } else if groups.isEmpty {
                        VStack(spacing: 10) {
                            Text("Paylaşmak için bir grubun olmalı")
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                            Button {
                                showCreateGroup = true
                            } label: {
                                Label("Grup Oluştur", systemImage: "person.3.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.dsInk, in: Capsule())
                                    .foregroundStyle(.white)
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
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(isSelected ? Color.dsInk : Color.dsSurfaceDim)
                                        )
                                        .foregroundStyle(isSelected ? .white : Color.dsDeep)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                        }

                        if selectedGroupIds.count > 1 {
                            Text("\(selectedGroupIds.count) gruba paylaşılacak")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dsAccent)
                        }
                    }
                }

                Button {
                    Task { await sharePool() }
                } label: {
                    if isSharing {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else {
                        Text("Paylaş")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(Color.dsDeep, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .disabled(selectedGroupIds.isEmpty || isSharing)
                .opacity(selectedGroupIds.isEmpty ? 0.4 : 1)
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .background(Color.dsBg.ignoresSafeArea())
            .navigationTitle("Havuzu Paylaş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
            .task { await loadGroups() }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView {
                    Task { await loadGroups() }
                }
            }
        }
    }

    private func loadGroups() async {
        isLoadingGroups = true
        groupLoadError = false
        do {
            groups = try await APIService.shared.getGroups()
        } catch {
            groupLoadError = true
        }
        isLoadingGroups = false
    }

    private func sharePool() async {
        guard !selectedGroupIds.isEmpty else { return }
        isSharing = true
        errorMessage = nil

        let items = (pool.items ?? []).map { item in
            ShareQuestionItem(name: item.name, imageData: item.imageData?.base64EncodedString())
        }

        var failedGroups: [String] = []
        for groupId in selectedGroupIds {
            do {
                try await APIService.shared.sharePool(groupId: groupId, name: pool.name, items: items)
            } catch {
                let name = groups.first(where: { $0.id.value == groupId })?.name ?? groupId
                failedGroups.append(name)
            }
        }

        if failedGroups.isEmpty {
            dismiss()
        } else {
            errorMessage = "Gönderilemedi: \(failedGroups.joined(separator: ", "))"
        }
        isSharing = false
    }
}
