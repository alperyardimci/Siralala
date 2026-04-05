import SwiftUI
import SwiftData

struct PoolDetailView: View {
    let pool: Pool
    @Environment(\.modelContext) private var context
    @State private var viewModel = PoolViewModel()
    @State private var showCreateQuestion = false
    @State private var showSharePool = false

    var body: some View {
        List {
            Section {
                AddItemRow(viewModel: viewModel, pool: pool)

                if pool.itemCount >= 3 {
                    Button {
                        showCreateQuestion = true
                    } label: {
                        Label("Soru Oluştur", systemImage: "paperplane.fill")
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }

                    Button {
                        showSharePool = true
                    } label: {
                        Label("Havuzu Gruba Paylaş", systemImage: "person.3.fill")
                            .foregroundStyle(.purple)
                            .fontWeight(.semibold)
                    }
                }
            }

            Section {
                ForEach(pool.items ?? []) { item in
                    ItemRow(item: item)
                }
                .onDelete { indexSet in
                    let items = pool.items ?? []
                    for index in indexSet {
                        viewModel.deleteItem(items[index], from: pool, context: context)
                    }
                }
            } header: {
                Text("\(pool.itemCount) öğe")
            }
        }
        .navigationTitle(pool.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateQuestion) {
            CreateQuestionView(pool: pool)
        }
        .sheet(isPresented: $showSharePool) {
            SharePoolSheet(pool: pool)
        }
    }
}

struct SharePoolSheet: View {
    let pool: Pool
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [APIGroup] = []
    @State private var selectedGroupId: Int?
    @State private var isSharing = false
    @State private var showCreateGroup = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.purple.gradient)

                VStack(spacing: 8) {
                    Text("Havuzu Paylaş")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(pool.name) · \(pool.itemCount) öğe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Text("Hangi gruba paylaşılsın?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if groups.isEmpty {
                        VStack(spacing: 10) {
                            Text("Paylaşmak için bir grubun olmalı")
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
                                    .background(.purple.gradient, in: Capsule())
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
                                                Capsule().fill(selectedGroupId == group.id ? .purple : .gray.opacity(0.15))
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
                    Task { await sharePool() }
                } label: {
                    if isSharing {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else {
                        Text("Paylaş")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(.purple.gradient, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .disabled(selectedGroupId == nil || isSharing)
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .navigationTitle("Havuzu Paylaş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
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

    private func sharePool() async {
        guard let groupId = selectedGroupId else { return }
        isSharing = true
        errorMessage = nil

        let items = (pool.items ?? []).map { item in
            ShareQuestionItem(name: item.name, imageData: item.imageData?.base64EncodedString())
        }

        do {
            try await APIService.shared.sharePool(groupId: groupId, name: pool.name, items: items)
            dismiss()
        } catch {
            errorMessage = "Paylaşılamadı: \(error.localizedDescription)"
        }
        isSharing = false
    }
}
