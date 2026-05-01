import SwiftUI
import SwiftData

struct PoolListView: View {
    @Query(sort: \Pool.createdAt, order: .reverse)
    private var pools: [Pool]
    @Environment(\.modelContext) private var context
    @State private var showCreatePool = false
    @State private var viewModel = PoolViewModel()
    @State private var sharedPools: [APISharedPool] = []
    @State private var groups: [APIGroup] = []
    @State private var poolToDelete: Pool?
    @State private var sharedPoolToDelete: APISharedPool?
    @State private var isLoadingShared = true

    private var totalItems: Int {
        pools.reduce(0) { $0 + $1.itemCount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("HAVUZLAR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Color.dsDeep)
                        Spacer()
                        Button {
                            showCreatePool = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.dsDeep))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Hero stat
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(pools.count) havuz,")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.dsDeep)
                        Text("\(totalItems) öğe.")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.dsMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                    if pools.isEmpty && sharedPools.isEmpty {
                        EmptyStateView(
                            icon: "square.stack",
                            title: "Henüz havuz yok",
                            description: "Sıralamak istediğin öğeleri\nbir havuzda topla.",
                            buttonLabel: "Havuz Oluştur",
                            onAction: { showCreatePool = true }
                        )
                    } else {
                        VStack(spacing: 10) {
                            // My pools
                            if !pools.isEmpty {
                                ForEach(pools) { pool in
                                    HStack(spacing: 10) {
                                        NavigationLink(destination: PoolDetailView(pool: pool)) {
                                            PoolRow(pool: pool)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            poolToDelete = pool
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.red.opacity(0.65))
                                                .frame(width: 36, height: 36)
                                                .background(Circle().fill(Color.dsSurfaceDim))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Shared pools
                        if isLoadingShared {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                            .padding(.top, 28)
                        } else if !sharedPools.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("PAYLAŞILAN HAVUZLAR")
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(1)
                                    .foregroundStyle(Color.dsDeep)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 28)

                                VStack(spacing: 10) {
                                    ForEach(sharedPools) { pool in
                                        HStack(spacing: 10) {
                                            NavigationLink {
                                                if let gid = pool.groupId, let group = groups.first(where: { $0.id == gid }) {
                                                    SharedPoolQuestionView(pool: pool, group: group)
                                                }
                                            } label: {
                                                SharedPoolRow(pool: pool)
                                            }
                                            .buttonStyle(.plain)

                                            if pool.creatorName == APIService.shared.currentUser?.displayName {
                                                Button {
                                                    sharedPoolToDelete = pool
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 13, weight: .medium))
                                                        .foregroundStyle(.red.opacity(0.65))
                                                        .frame(width: 36, height: 36)
                                                        .background(Circle().fill(Color.dsSurfaceDim))
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer().frame(height: 40)
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .background(Color.dsBg.ignoresSafeArea())
            .sheet(isPresented: $showCreatePool) {
                CreatePoolView()
            }
            .task { await loadSharedPools() }
            .refreshable { await loadSharedPools() }
            .alert("Havuzu silmek istediğine emin misin?", isPresented: .init(
                get: { poolToDelete != nil },
                set: { if !$0 { poolToDelete = nil } }
            )) {
                Button("Sil", role: .destructive) {
                    if let pool = poolToDelete {
                        viewModel.deletePool(pool, context: context)
                        poolToDelete = nil
                    }
                }
                Button("Vazgeç", role: .cancel) { poolToDelete = nil }
            } message: {
                Text("Bu işlem geri alınamaz. Havuzdaki tüm öğeler silinecek.")
            }
            .alert("Paylaşılan havuzu silmek istediğine emin misin?", isPresented: .init(
                get: { sharedPoolToDelete != nil },
                set: { if !$0 { sharedPoolToDelete = nil } }
            )) {
                Button("Sil", role: .destructive) {
                    if let pool = sharedPoolToDelete {
                        Task {
                            try? await APIService.shared.deleteSharedPool(id: pool.id.value)
                            sharedPools.removeAll { $0.id == pool.id }
                        }
                        sharedPoolToDelete = nil
                    }
                }
                Button("Vazgeç", role: .cancel) { sharedPoolToDelete = nil }
            } message: {
                Text("Bu havuz gruptan da kaldırılacak.")
            }
        }
    }

    private func loadSharedPools() async {
        async let p = APIService.shared.getAllSharedPools()
        async let g = APIService.shared.getGroups()
        sharedPools = (try? await p) ?? []
        groups = (try? await g) ?? []
        isLoadingShared = false
    }
}

struct PoolRow: View {
    let pool: Pool

    var body: some View {
        HStack(spacing: 14) {
            // Count tile
            VStack(spacing: 2) {
                Text("\(pool.itemCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.dsDeep)
                Text("öğe")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dsMuted)
            }
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsSurfaceDim))

            VStack(alignment: .leading, spacing: 4) {
                Text(pool.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.dsDeep)
                Text(pool.itemCount >= 3 ? "\(pool.itemCount) aktif öğe" : "Henüz soru yok")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dsUltraMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.dsHairline, lineWidth: 1)
                )
        )
    }
}

struct SharedPoolRow: View {
    let pool: APISharedPool

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("\(pool.itemCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.dsInk)
                Text("öğe")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dsInk.opacity(0.6))
            }
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsInkSoft))

            VStack(alignment: .leading, spacing: 4) {
                Text(pool.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.dsDeep)
                HStack(spacing: 4) {
                    Text(pool.creatorName)
                    Text("·")
                    Text(pool.groupName ?? "")
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.dsMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dsUltraMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.dsHairline, lineWidth: 1)
                )
        )
    }
}
