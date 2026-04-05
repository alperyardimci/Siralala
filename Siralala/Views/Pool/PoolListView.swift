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

    var body: some View {
        NavigationStack {
            List {
                if !pools.isEmpty {
                    Section("Havuzlarım") {
                        ForEach(pools) { pool in
                            NavigationLink(destination: PoolDetailView(pool: pool)) {
                                PoolRow(pool: pool)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deletePool(pools[index], context: context)
                            }
                        }
                    }
                }

                if !sharedPools.isEmpty {
                    Section("Paylaşılan Havuzlar") {
                        ForEach(sharedPools) { pool in
                            NavigationLink {
                                if let group = groups.first(where: { $0.id == pool.groupId }) {
                                    SharedPoolQuestionView(pool: pool, group: group)
                                }
                            } label: {
                                SharedPoolRow(pool: pool)
                            }
                        }
                    }
                }

                if pools.isEmpty && sharedPools.isEmpty {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 40)
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange.opacity(0.5))
                        Text("Henüz havuz yok")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("İlk havuzunu oluştur!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Havuzlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreatePool = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreatePool) {
                CreatePoolView()
            }
            .task { await loadSharedPools() }
            .onAppear { Task { await loadSharedPools() } }
        }
    }

    private func loadSharedPools() async {
        async let p = APIService.shared.getAllSharedPools()
        async let g = APIService.shared.getGroups()
        sharedPools = (try? await p) ?? []
        groups = (try? await g) ?? []
    }
}

struct PoolRow: View {
    let pool: Pool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange.gradient)
                    .frame(width: 48, height: 48)
                Text("\(pool.itemCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pool.name)
                    .font(.headline)
                Text("\(pool.itemCount) öğe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SharedPoolRow: View {
    let pool: APISharedPool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.purple.gradient)
                    .frame(width: 48, height: 48)
                Text("\(pool.itemCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pool.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(pool.creatorName)
                    Text("·")
                    Text(pool.groupName ?? "")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
