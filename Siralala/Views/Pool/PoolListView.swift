import SwiftUI
import SwiftData

struct PoolListView: View {
    @Query(sort: \Pool.createdAt, order: .reverse)
    private var pools: [Pool]
    @Environment(\.modelContext) private var context
    @State private var showCreatePool = false
    @State private var viewModel = PoolViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if pools.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange.opacity(0.5))
                        Text("Henüz havuz yok")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("İlk havuzunu oluştur!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List {
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
            }
            .navigationTitle("Havuzlar")
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
        }
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
